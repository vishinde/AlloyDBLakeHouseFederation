
-- Next Insert in BigQuery
-- Insert 'Cold' historical threat intelligence
INSERT INTO `bq-project-402513.threat_intelligence.global_indicators` (indicator_val, malware_family, risk_score, last_seen_at)
VALUES 
-- Known Malicious IPs matched to AlloyDB entries above
('192.168.1.50', 'Mirai_Botnet', 0.98, CURRENT_TIMESTAMP()),
('104.244.42.1', 'Cobalt_Strike_C2', 0.95, TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 2 DAY)),
('45.79.10.12', 'Generic_Scanner', 0.65, TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 10 DAY)),

-- Historical noise (to test join performance)
('8.8.8.8', 'Clean_Google_DNS', 0.01, CURRENT_TIMESTAMP()),
('1.1.1.1', 'Clean_Cloudflare_DNS', 0.02, CURRENT_TIMESTAMP()),
('185.199.108.153', 'GitHub_Pages', 0.05, CURRENT_TIMESTAMP());

-- Generate 10,000 "Noise" rows to test Push-Down Aggregation efficiency
INSERT INTO `bq-project-402513.threat_intelligence.global_indicators` (indicator_val, malware_family, risk_score, last_seen_at)
SELECT 
    format('%d.%d.%d.%d', cast(rand()*255 as int64), cast(rand()*255 as int64), cast(rand()*255 as int64), cast(rand()*255 as int64)),
    'Unknown_Background_Noise',
    rand(),
    TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL cast(rand()*365 as int64) DAY)
FROM unnest(generate_array(1, 10000));

--Insert latest day's data to test AlloyDB Federated Query view - v_agent_threat_intelligence
INSERT INTO `bq-project-402513.threat_intelligence.global_indicators` (indicator_val, malware_family, risk_score, last_seen_at)
SELECT 
    format('%d.%d.%d.%d', cast(rand()*255 as int64), cast(rand()*255 as int64), cast(rand()*255 as int64), cast(rand()*255 as int64)),
    'Unknown_Background_Noise',
    rand(),
    TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL CAST(RAND() * 86400 AS INT64) SECOND)
FROM unnest(generate_array(1, 100));
