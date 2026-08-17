-- 1. Enable BigQuery Sync Extension
CREATE EXTENSION IF NOT EXISTS alloydb_sync;

-- 2. Create Managed Continuous Mirror (Replaces pg_cron schedule & INSERT loop)
SELECT alloydb_sync.create_bq_sync_table(
    'bq-project-402513.threat_intelligence.global_indicators', -- Source BQ table
    'public.global_indicators_local',                          -- Destination AlloyDB table
    '1 day',                                                   -- Refresh interval (e.g. '1 hour', '1 day')
    'replace',                                                 -- On exists: 'replace' | 'skip' | 'error'
    ARRAY['indicator_val']                                     -- Primary key columns
);

-- 3. Verify sync status
SELECT * FROM alloydb_sync.job_status;
