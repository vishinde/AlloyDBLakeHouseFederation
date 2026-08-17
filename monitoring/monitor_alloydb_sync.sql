-- 1. Check sync job status, processed row counts, and errors
SELECT 
    import_id,
    source_table,
    destination_table,
    status,                 -- 'PENDING' | 'RUNNING' | 'COMPLETED' | 'FAILED' | 'CANCELLED'
    records_processed,
    total_records,
    start_time,
    end_time,
    end_time - start_time AS sync_duration,
    error
FROM alloydb_sync.job_status
ORDER BY start_time DESC;

-- 2. Cancel an active / stuck sync job if necessary
-- SELECT alloydb_sync.cancel_import_job('<IMPORT_UUID>');

-- 3. Safely stop mirroring and clean up background scheduler hooks
-- SELECT alloydb_sync.delete_bq_sync_table('public.global_indicators_local');
