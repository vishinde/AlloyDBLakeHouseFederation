# AlloyDB Lakehouse Federation & Agentic SOC Threat Intelligence Platform

This repository provides a production-ready, resilient blueprint for **Lakehouse Federation** between Google Cloud’s **AlloyDB** and **BigQuery**. It showcases how to design and build an **Agentic SOC** security analyzer using Model Context Protocol (MCP) to query high-volume threat data, handle query timeouts, fall back on a local replica cache, and log diagnostic playbooks when circuit breakers trip.

---

## Architecture Overview

The platform uses a split-plane execution design:

* **The Primary Path:** The Security Analyst Agent uses the MCP Toolbox to request federated threat intelligence from BigQuery via AlloyDB read pools.
* **The Fallback Path:** If a query times out or breaks, a local Python circuit breaker pattern trips, shifts the agent to fetch local cached data from the read only pool in AlloyDB and writes execution failure logs to AlloyDB's primary database for troubleshooting.

---

## Setup & Deployment Sequence

Follow the setup steps below in order to ensure the database resources, permissions, schemas, and automation jobs are linked correctly.

```text
Step 1: BigQuery Setup
       │
       ▼
Step 2: AlloyDB Instance & Schema Setup
       │
       ▼
Step 3: Insert Historical Seed Data
       │
       ▼
Step 4: Configure pg_cron Ingestion Automation
       │
       ▼
Step 5: Define Lakehouse Federation Views
       │
       ▼
Step 6: Deploy Agentic SOC Workspace (threatintelagent)

```

---

## Step 1: BigQuery Setup

BigQuery serves as our high-scale analytical threat ledger. Before configuring federated access, you must establish the BigQuery datasets and seed schemas.

1. **Create the Dataset:** Create a dataset in your Google Cloud Project (e.g., in `us-central1` to match your AlloyDB resources).
2. **Define Threat Table Schema:** Run the initial schema scripts to create tables representing massive volumes of security events (e.g., `threat_logs`).
3. **IAM Permissions:** Make sure the service account or principal that AlloyDB will use to query BigQuery has the **BigQuery Connection User** and **BigQuery Data Viewer** roles on the target dataset.

---

## Step 2: AlloyDB Setup

Once the BigQuery side of the lakehouse boundary is ready, switch your database environment context to AlloyDB.

1. Connect to your AlloyDB primary instance using your preferred PostgreSQL client (e.g., `psql` or pgAdmin).
2. Create your core threat intelligence and logging tables:
```sql
-- Create the audit and fallback circuit breaker telemetry logging table
CREATE TABLE public.federation_circuit_breaker_logs (
    log_id SERIAL PRIMARY KEY,
    tenant_id VARCHAR(50) NOT NULL,
    failed_tool VARCHAR(100) NOT NULL,
    inferred_root_cause VARCHAR(100) NOT NULL,
    execution_duration_seconds NUMERIC(6,3),
    raw_error_message TEXT,
    bigquery_debug_query TEXT,
    logged_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

```



---

## Step 3: Insert Initial Data

Populate local lookup and seed values inside your AlloyDB databases. These local cache structures provide the baseline fallback data when the agent loses connection to BigQuery.

1. Run your insert scripts (e.g., `insert.sql` or equivalent) to populate local threat lookup mapping tables and warm your local buffer cache.
2. Confirm that your local data schemas align precisely with the fields declared in your BigQuery analytical warehouse to prevent schema mismatch failures during fallbacks.

---

## Step 4: Configure `pg_cron` Ingestion

To keep the local replica cache fresh without manually executing scripts, we automate the pipeline using the PostgreSQL `pg_cron` extension inside AlloyDB.

1. **Enable pg_cron:** Ensure `pg_cron` is added to your AlloyDB shared libraries under your instance's database flags.
2. **Register the Cron Job:** Run the `pgcron_ingest` script to schedule regular local cache updates:
```sql
-- Example scheduling script
SELECT cron.schedule('sync-local-threat-cache', '*/30 * * * *', $$
    -- Insert sync query logic here to refresh AlloyDB replica tables
$$);

```



---

## Step 5: Define Lakehouse Federation Views

With both datasets populated and structured, create the external links and views that allow AlloyDB to run queries directly against BigQuery without moving physical data blocks.

1. Run the `alloydbfederated.sql` script.
2. **Define Connection:** This script establishes the Google Cloud connection parameter mapping.
3. **Expose BigQuery as Foreign Tables:** Exposes the BigQuery target datasets to your local PG query planner using the `external_query()` wrapper or Foreign Data Wrappers (FDW).

---

## Step 6: Deploy the Agentic SOC (`threatintelagent/`)

The `threatintelagent` folder houses the core Agentic SOC codebase. This code utilizes the **Model Context Protocol (MCP) Toolbox for Databases** to run queries, monitor limits, and execute our custom resiliency/fallback strategies.

### Prerequisite Environment Configuration

To protect database credentials and avoid hardcoding secrets in your code, the agent reads its runtime parameters from a localized `.env` configuration file.

1. Navigate to the agent workspace:
```bash
cd threatintelagent

```


2. Create a `.env` file from your template:
```bash
touch .env

```


3. Populate the `.env` file with your specific target configuration:
```env
PROJECT_ID="your-gcp-project-id"
REGION="us-central1"
LOG_CONN_STRING="dbname=secopsdb user=postgres password=YourSecurePassword host=10.40.64.16"

```


> ⚠️ **Security Warning:** Ensure your `.env` file is added to your local `.gitignore` so database passwords and internal GCP IP configurations are never committed to version control.



### Installation & Execution

1. Create and activate a Python virtual environment:
```bash
python3 -m venv .venv
source .venv/bin/activate

```


2. Install the necessary system dependencies:
```bash
pip install -r requirements.txt

```


3. Start the Agent loop:
```bash
python3 agent.py

```

### Operational Resilience & Fallback Demonstration

If the primary BigQuery connection is severed or a query times out, the agent will gracefully execute the following circuit-breaker sequence in real-time:

* **Log Triage Event:** The agent automatically runs `triage_and_log_federation_timeout` and writes a detailed log (including the compiled `INFORMATION_SCHEMA` debug query) to `public.federation_circuit_breaker_logs` on your primary AlloyDB instance.
* **Initiate Cache Fallback:** The agent calls `get_tenant_security_events_fallback` to read the cached data replicated by `pg_cron`.
* **Deliver Report:** The agent presents its findings to your **Agentic SOC Console** with a warning stating that live threat intelligence was unavailable and fallback records were used instead.

* ### Key Metric Thresholds & Alerting Guide

Configure automated alerts within Cloud Monitoring or your notification channels using these core operational benchmarks:

| Aspect | Core Metric | Target Threshold | Mitigation Action |
| :--- | :--- | :--- | :--- |
| **Database Cache** | AlloyDB Buffer Cache Hit Ratio | `>= 99%` | Drop below indicates caching footprints are spilling; scale instance memory. |
| **Concurrency** | Connection Pool Depth | `< 90%` | Scale out your read pool node count to handle concurrent agent connections. |
| **BigQuery Limits** | Slot Utilization & Queue Depth | `0 Queued` | If queries get queued or trigger `403 Rate Limit` errors, increase reservation slots. |
| **System Integrity** | Service Account Executions | `0 Failures` | Track IAM permissions on your Lakehouse Federation service account to catch drifts. |
