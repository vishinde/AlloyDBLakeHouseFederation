CREATE EXTENSION pg_cron;

SELECT cron.schedule(
    'import_global_indicators', 
    '0 1 * * *', -- Runs every night at 1:00 AM
    $$
    INSERT INTO public.global_indicators_local (indicator_val, malware_family, risk_score, last_seen_at)
    SELECT indicator_val, malware_family, risk_score, last_seen_at
    FROM public.global_indicators_from_bq
    WHERE last_seen_at >= (CURRENT_DATE - INTERVAL '1 day')::TIMESTAMP
      AND last_seen_at < CURRENT_DATE::TIMESTAMP
    ON CONFLICT (indicator_val, last_seen_at) 
    DO UPDATE SET 
        malware_family = EXCLUDED.malware_family,
        risk_score = EXCLUDED.risk_score;

    -- Step 2: Manually force the Columnar Engine to serialize the new data blocks
    PERFORM google_columnar_engine_refresh('public.global_indicators_local');
    $$
);
