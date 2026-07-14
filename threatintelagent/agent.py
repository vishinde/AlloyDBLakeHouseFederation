import asyncio
import warnings
import os
from dotenv import load_dotenv
import time
import datetime
import psycopg
from google.adk.agents import Agent
from google.adk.runners import Runner
from google.adk.sessions import InMemorySessionService
from google.genai import types
from toolbox_core import ToolboxSyncClient
from google.adk.tools import FunctionTool


load_dotenv()

# --- 1. Environment & Telemetry ---
PROJECT_ID = os.getenv("PROJECT_ID")
REGION = os.getenv("REGION")
os.environ["GOOGLE_CLOUD_PROJECT"] = PROJECT_ID
os.environ["GOOGLE_CLOUD_LOCATION"] = REGION
os.environ["GOOGLE_GENAI_USE_VERTEXAI"] = "True"

LOG_CONN_STRING = os.getenv("LOG_CONN_STRING")

if not LOG_CONN_STRING:
    raise ValueError("CRITICAL: LOG_CONN_STRING environment variable is not set!")

PROJECT_NAME = f"projects/{PROJECT_ID}"

async def _insert_log_to_alloydb(payload: dict) -> None:
    """Handles the async database write logic exclusively."""
    async with await psycopg.AsyncConnection.connect(LOG_CONN_STRING) as conn:
        async with conn.cursor() as cur:
            await cur.execute("""
                INSERT INTO public.federation_circuit_breaker_logs 
                (tenant_id, failed_tool, inferred_root_cause, execution_duration_seconds, raw_error_message, bigquery_debug_query)
                VALUES (%s, %s, %s, %s, %s, %s);
            """, (
                payload["tenant_id"], payload["failed_tool"], payload["inferred_root_cause"],
                payload["duration_seconds"], payload["raw_error_message"], payload["debug_playbook"]
            ))
            await conn.commit()

# --- 2. Unified Master Agent Tool ---

async def triage_and_log_federation_timeout(tenant_id: str, failed_tool_name: str, raw_error: str) -> str:
    """
    Logs a federated query timeout incident to the primary AlloyDB server and fires 
    a custom metric alert to Google Cloud Monitoring for engineering triage.
    Always invoke this tool immediately if an upstream database query times out or fails.
    """
    execution_timestamp = datetime.datetime.now(datetime.UTC).isoformat() + "Z"
    
    debug_playbook = (
        f"SELECT query, total_bytes_billed, total_slot_ms FROM `region-us`.INFORMATION_SCHEMA.JOBS_BY_PROJECT "
        f"WHERE creation_time BETWEEN '{execution_timestamp}' AND "
        f"TIMESTAMP_ADD(TIMESTAMP '{execution_timestamp}', INTERVAL 1 MINUTE) "
        f"ORDER BY creation_time ASC;"
    )
    
    log_payload = {
        "tenant_id": tenant_id,
        "failed_tool": failed_tool_name,
        "inferred_root_cause": "federated_query_timeout",
        "duration_seconds": 0.0,
        "raw_error_message": raw_error[:500],
        "debug_playbook": debug_playbook
    }

    # Execute both helper tasks in parallel or independently with clear error boundaries
    try:
        await _insert_log_to_alloydb(log_payload)
        db_status = "Success"
    except Exception as e:
        db_status = f"Failed ({str(e)})"

    return (
        f"Triage complete. [AlloyDB Write: {db_status}]. "
        f"Diagnostic playbook query compiled for execution timestamp {execution_timestamp}."
    )

# --- 2. Agent Orchestration ---

report_instruction = (
    "You are a Senior Security Analyst. Your mission is to analyze and report on tenant findings "
    "using clear, data-backed recommendations.\n\n"
    "CRITICAL EXECUTION STRATEGY:\n"
    "1. PRIMARY DATA ACQUISITION: Always attempt to gather comprehensive security analytics by calling "
    "'get_tenant_security_events' first.\n\n"
    "2. TIMEOUT TRIAGE PROTOCOL: If 'get_tenant_security_events' returns an error, a timeout, a 57014 code, "
    "or an empty response implying data layer unavailability, you MUST immediately call the "
    "'triage_and_log_federation_timeout' tool before proceeding to anything else. "
    "Pass the active tenant_id ('sk_prod_88'), specify 'get_tenant_security_events' as the failed_tool_name, "
    "and provide a short description of the failure as the raw_error parameter.\n\n"
    "3. LOCAL CACHE FALLBACK: Immediately after executing 'triage_and_log_federation_timeout', you must call "
    "'get_tenant_security_events_fallback' to retrieve the local replica data.\n\n"
    "4. FINAL REPORT REQUIREMENTS: Compile your report. You must explicitly include a system notice at the top "
    "stating that comprehensive threat intelligence was unavailable due to a federated query timeout, and confirm "
    "the incident has been logged using the triage tool."
)

async def main():
    toolbox = ToolboxSyncClient("http://127.0.0.1:5000")

    try:
        lakehouse_tools = toolbox.load_toolset('tenant_security_events_toolset')
        
        # Inject our custom telemetry and circuit-breaker diagnostics wrapper
        #mcp_triage_tool = FunctionTool.from_defaults(fn=triage_and_log_federation_timeout)

        all_agent_tools = [*lakehouse_tools, triage_and_log_federation_timeout]

        agent = Agent(
            name="security_strategist", 
            model="gemini-2.5-flash", 
            instruction=report_instruction, 
            tools=all_agent_tools
        )

        session_service = InMemorySessionService()
        user_id = "user_123"
        session_id = "session_final"
        app_name = "SecurityAnalyst"

        await session_service.create_session(
            app_name=app_name, 
            user_id=user_id, 
            session_id=session_id
        )
        
        runner = Runner(app_name=app_name, agent=agent, session_service=session_service)

        prompt = "Generate a security report for tenant sk_prod_88. What is your analysis?"
        content = types.Content(role='user', parts=[types.Part(text=prompt)])

        async for event in runner.run_async(
            new_message=content, 
            user_id=user_id, 
            session_id=session_id
        ):
            if event.is_final_response():
                final_text = event.content.parts[0].text
                print(f"\n[Security Strategist]:\n{final_text}")
            elif event.content and event.content.parts:
                for part in event.content.parts:
                    if part.function_call:
                        print(f"🛠️  Agent calling toolbox: {part.function_call.name}...")

    finally:
        # 1. Cleanly close the toolbox connection
        toolbox.close()

if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        print("\nAgent stopped by user.")
