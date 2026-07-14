-- 1. Create the Hot Telemetry Table
CREATE TABLE active_security_events (
    event_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id VARCHAR(50) NOT NULL,
    source_ip INET NOT NULL,
    event_type VARCHAR(50),
    severity INT CHECK (severity BETWEEN 1 AND 5),
    detection_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    event_signature TEXT
    -- AlloyDB AI: Automatic embedding generation
    --embedding vector(768) GENERATED ALWAYS AS (ai.embedding('text-embedding-004', event_signature)) STORED
);

-- 2. Function to retrieve tenant specific data
CREATE FUNCTION get_tenant_events(p_tenant_id TEXT) 
RETURNS SETOF active_security_events AS $$
  SELECT * FROM active_security_events WHERE tenant_id = p_tenant_id;
$$ LANGUAGE SQL SECURITY DEFINER;

-- 3. Induct the table into the Columnar Engine for high performance
SELECT google_columnar_engine_add('active_security_events');

-- 4. Create foreign table with query mode
CREATE FOREIGN TABLE "public"."global_indicators_from_bq" (
      "indicator_val" VARCHAR, "last_seen_at" TIMESTAMP, "malware_family" VARCHAR, "risk_score" DOUBLE PRECISION
    ) SERVER "bigquery_server" OPTIONS (
      project 'bq-project-402513',
      dataset 'threat_intelligence',
      table 'global_indicators',
      mode 'query'
    );
