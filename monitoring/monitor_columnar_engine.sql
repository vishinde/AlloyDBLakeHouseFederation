--Make sure the extension is enabled
--CREATE EXTENSION pg_stat_statements;

--Audit Specific Table & Index Sizes & Stateleness
--This query isolates memory footprint consumption down to the relation level and highlights column staleness caused by high transactional writes:
SELECT 
    database_name,
    schema_name,
    relation_name,
    status,
    size AS columnar_size_bytes,
    invalid_block_count,
    total_block_count,
    -- High invalid ratios mean row updates are out-pacing the columnar background refresh background thread
    ROUND((invalid_block_count::numeric / GREATEST(total_block_count, 1)) * 100, 2) AS invalidation_ratio_percentage
FROM g_columnar_relations
--your tables, views here for filtering data only for your workload
WHERE relation_name IN ('global_indicators_local', 'v_agent_threat_intelligence', 'v_agent_threat_intelligence_2') -- Your Agent-Specific Targets
ORDER BY size DESC;


--Columnar Execution Diagnostics
--Run this performance audit to see which historical queries are successfully using vectorized pathways versus running un-pushed operations:
SELECT 
    p.query,
    c.columnar_unit_read,
    c.rows_filtered,
    -- Time spent in specialized columnar processing
    round(c.columnar_scan_time::numeric, 2) AS columnar_scan_ms,
    round(c.vectorized_join_time::numeric, 2) AS vectorized_join_ms,
    round(c.vectorized_aggregation_time::numeric, 2) AS vectorized_agg_ms,
    -- Overall query metrics from pg_stat_statements
    p.calls,
    round(p.mean_exec_time::numeric, 2) AS total_mean_time_ms
FROM g_columnar_stat_statements c
JOIN pg_stat_statements p ON c.query_id = p.queryid
WHERE 
    -- Filters exclusively for queries tagged with your agent comment pattern
    p.query LIKE '%agent_module:%'
ORDER BY c.columnar_scan_time DESC
LIMIT 10;

--EXPLAIN ANALYZE for your query confirm: 
--Custom Scan (Columnar Scan): Indicates the optimizer read directly from the columnar store. Check the execution breakdown attributes: look for the Rows Removed by Columnar Filter line to confirm the engine is discarding unwanted matching values quickly inside memory.
--Vectorized Hash Join / Vectorized Aggregation: This proves the engine is executing math across multi-row chunks simultaneously using hardware SIMD (Single Instruction, Multiple Data) processor extensions rather than stepping loop-by-loop through standard individual rows.
