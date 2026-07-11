--Checking if errors are happening on refresh! Also run_duration for successful runs
SELECT 
    runid,
    jobid,
    command,
    status,
    return_message,
    start_time AT TIME ZONE 'UTC' AT TIME ZONE 'America/Chicago' AS start_time_central,
    -- Calculates exact run duration in an easily readable format
    end_time - start_time AS run_duration,
    EXTRACT(EPOCH FROM (end_time - start_time)) AS run_duration_seconds
FROM 
    cron.job_run_details
WHERE 
    -- Filters for your BigQuery materialization commands
    (command ILIKE '%global_indicators_local%' OR command ILIKE '%refresh%')
    AND start_time >= CURRENT_TIMESTAMP - INTERVAL '24 hours'
ORDER BY 
    start_time DESC;

--If a data synchronization job hangs or hits a network bottleneck while streaming data from BigQuery, its end_time will remain blank. This query catches active tasks exceeding your expected maintenance window.
SELECT 
    runid,
    jobid,
    command,
    status,
    start_time AT TIME ZONE 'UTC' AT TIME ZONE 'America/Chicago' AS start_time_central,
    -- Tracks how long the job has been running up to the current moment
    CURRENT_TIMESTAMP - start_time AS current_running_duration,
    EXTRACT(EPOCH FROM (CURRENT_TIMESTAMP - start_time)) AS current_running_seconds
FROM 
    cron.job_run_details
WHERE 
    end_time IS NULL 
    AND status = 'running'
    -- Highlights jobs running longer than a typical 10-minute threshold
    AND start_time < CURRENT_TIMESTAMP - INTERVAL '10 minutes'
ORDER BY 
    start_time ASC;

--High level performance aggregates
--total_runs, total_failures, success_rate, avg and max duration of runs
SELECT 
    jobid,
    command,
    COUNT(*) AS total_runs,
    COUNT(CASE WHEN status = 'failed' THEN 1 END) AS total_failures,
    ROUND(AVG(EXTRACT(EPOCH FROM (end_time - start_time)))::numeric, 2) AS avg_duration_seconds,
    ROUND(MAX(EXTRACT(EPOCH FROM (end_time - start_time)))::numeric, 2) AS max_duration_seconds,
    -- Percentage of successful runs
    ROUND((COUNT(CASE WHEN status = 'succeeded' THEN 1 END)::numeric / COUNT(*)) * 100, 2) AS success_rate_percentage
FROM 
    cron.job_run_details
WHERE 
    end_time IS NOT NULL
GROUP BY 
    jobid, 
    command
ORDER BY 
    avg_duration_seconds DESC;

--pg_cron history isnt purged automatically
--script to purge the history if needed
-- Automatically purges history records older than 7 days
SELECT cron.schedule('prune-cron-history', '0 0 * * *', "DELETE FROM cron.job_run_details WHERE start_time < CURRENT_TIMESTAMP - INTERVAL '7 days'");
