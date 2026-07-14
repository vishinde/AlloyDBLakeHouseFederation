SELECT 
    l.tenant_id, 
    l.source_ip, 
    h.malware_family, 
    h.risk_score
FROM 
    active_security_events as l  -- $1 maps to the first parameter ('tenant')
INNER JOIN 
    --Joining with foreign table based view
    public.v_agent_threat_intelligence AS h
ON CAST(l.source_ip AS VARCHAR) = CONCAT(h.indicator_val, '/32');
