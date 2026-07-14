--View to fetch historical data imported in AlloyDB with latest day data from BigQuery
--pg_cron job inserts data nightly from BigQuery into global_indicators_local table in AlloyDB

-- 1. Create the helper wrapper to create immutable function
CREATE OR REPLACE FUNCTION public.immutable_today() 
RETURNS timestamp AS $$
BEGIN
    RETURN CURRENT_DATE::timestamp;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- 2. Build the view using your wrapper
CREATE OR REPLACE VIEW v_agent_threat_intelligence AS
SELECT indicator_val, malware_family, risk_score, last_seen_at, 'local_cache' AS source
FROM global_indicators_local
UNION ALL
SELECT indicator_val, malware_family, risk_score, last_seen_at, 'live_bq' AS source
FROM "public"."global_indicators_from_bq"
WHERE last_seen_at >= public.immutable_today();
