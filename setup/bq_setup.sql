CREATE OR REPLACE TABLE `bq-project-402513.threat_intelligence.global_indicators` (
    indicator_val STRING,
    malware_family STRING,
    risk_score FLOAT64,
    last_seen_at TIMESTAMP
)
PARTITION BY DATE(last_seen_at)
CLUSTER BY indicator_val;
