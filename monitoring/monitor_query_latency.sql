SELECT 
    query,
    calls,
    round(mean_exec_time::numeric, 2) AS mean_ms,
    round(max_exec_time::numeric, 2) AS max_ms
FROM pg_stat_statements
WHERE 
calls > 10  -- Filters out statistically insignificant single runs
AND query LIKE '%agent_module:%' --Filtering only agent specific queries
ORDER BY mean_ms DESC
LIMIT 10;
