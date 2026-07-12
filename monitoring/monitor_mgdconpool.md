Metrics for monitoring AlloyDB's built-in managed connection pooling:
Alert if client_connections state moves to waiting > 0, signaling your incoming traffic is exceeding your pool capacity thresholds.
Track client_connections_avg_wait_time to isolate client-side network delay spikes from actual internal database execution latencies.
Critical Metrics (Alert Rules)
Client Connections (Waiting Priority Line): Tracks upstream agent connection starvation. Any result greater than 0 indicates connection exhaustion.
Code snippet
alloydb_googleapis_com:database_conn_pool_client_connections{
    location="us-central1",
    instance_id="secagentpool",
    database="secopsdb",
    state="waiting"
}


Average Connection Acquisition Delay: Converts raw client wait time from microseconds into seconds.
Code snippet
alloydb_googleapis_com:database_conn_pool_client_connections_avg_wait_time{
    location="us-central1",
    instance_id="secagentpool",
    database="secopsdb"
} / 1000000


Diagnostic Metrics
Backend Instance Sockets (Active vs. Idle): Evaluates whether the proxy pool needs a resizing adjustment based on how busy your database backends are.
Code snippet
sum by (state) (
    alloydb_googleapis_com:database_conn_pool_server_connections{
        location="us-central1",
        instance_id="secagentpool",
        database="secopsdb"
    }
)

Unique User Pool Allocations:
alloydb_googleapis_com:database_conn_pool_num_pools{
    location="us-central1",
    instance_id="secagentpool",
    database="secopsdb"}
