CREATE EXTENSION pg_cron;

SELECT cron.schedule(
    'import_global_indicators', 
    '0 1 * * *', -- Runs every night at 1:00 AM
    $$
    -- Manually force the Columnar Engine to serialize the new data blocks
    PERFORM google_columnar_engine_refresh('public.global_indicators_local');
    $$
);
