--Insert live Telemetry data in AlloyDB first
-- Simulate 'Hot' data for three different ISV tenants
INSERT INTO active_security_events (tenant_id, source_ip, event_type, severity, event_signature)
VALUES 
-- Tenant 3
('ak_001', '192.168.1.50', 'DDoS_Connection_Burst', 5, 'High frequency connection requests from single IP: 5000 req/sec'),
('ak_001', '45.79.10.12', 'Cache_Poisoning_Attempt', 4, 'Suspicious header injection detected in GET request'),

-- Tenant 2
('sk_prod_88', '104.244.42.1', 'Log4j_JNDI_Lookup', 5, 'jndi:ldap://external-malicious-server.com/Exploit detected in user-agent'),
('sk_prod_88', '185.199.108.153', 'Dependency_Confused_Pull', 2, 'Attempted pull of internal-only package from public registry'),

-- Tenant 3
('bv_ms', '172.16.0.5', 'Lateral_Movement_SMB', 3, 'Multiple failed SMB logins observed from internal workstation');

-- Insert bulk data
INSERT INTO active_security_events (tenant_id, source_ip, event_type, severity, event_signature)
SELECT 
    'stress_test_tenant',
    (format('%s.%s.%s.%s', 
        (random()*255)::int, 
        (random()*255)::int, 
        (random()*255)::int, 
        (random()*255)::int
    ))::inet,
    'Synthetic_Probe',
    (1 + floor(random() * 5))::int, -- Corrected: Generates 1, 2, 3, 4, or 5
    'Automated stress test event signature for monitoring benchmark'
FROM generate_series(1, 1000);

