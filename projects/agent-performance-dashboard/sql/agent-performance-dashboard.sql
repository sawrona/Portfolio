-- ==============================================================
--              AWS Call Data
-- ==============================================================

select
    QUEUE_NAME,
    case
        when username = 'agent01@company.com' then 'Agent 01'
        when username = 'agent02@company.com' then 'Agent 02'
        when username = 'agent03@company.com' then 'Agent 03'
        when username = 'agent04@company.com' then 'Agent 04'
        when username = 'agent05@company.com' then 'Agent 05'
        when username = 'agent06@company.com' then 'Agent 06'
        when username = 'agent07@company.com' then 'Agent 07'
    end as NAME,
    ROUTING_PROFILE_NAME,
    CONTACT_ID,
    CHANNEL,
    case
        when initiation_method = 'API' then 'DIALER'
        when initiation_method = 'OUTBOUND' then 'MANUAL OUTBOUND'
        else initiation_method
    end as INITIATION_METHOD,
    TO_VARCHAR(INITIATION_TS,'MM/DD/YYYY') AS INITIATION_TS,
    TO_VARCHAR(DISCONNECT_TS, 'MM/DD/YYYY') AS DISCONNECT_TS,
    TO_VARCHAR(DATEADD(day, 1-dayofweek(INITIATION_TS), INITIATION_TS),'MM/DD/YYYY') as "Week Start Date (Mon)",
    ROUND(TALK_DURATION_SEC/60,2) as TALK_DURATION_MIN,
    ROUND(HOLD_DURATION_SEC/60,2) as HOLD_DURATION_MIN,
    ROUND(ACW_DURATION_SEC/60,2) as ACW_DURATION_MIN,
    DISCONNECT_REASON,
    ABANDONED_FLAG,
    HOLD_COUNT,
    CUSTOMER_ENDPOINT,
    PREVIOUS_CONTACT_ID,
    INITIAL_CONTACT_ID,
    IS_TRANSFER_LEG,
    TRANSFERRED_OUT_FLAG,
    CAMPAIGN_NAME,
    IS_CAMPAIGN_CONTACT,
    AMD_STATUS,
    TO_VARCHAR(CONTACT_DATE,'MM/DD/YYYY') AS CONTACT_DATE

    from FACT_CONTACT
-- where campaign_name ilike '%Collections%'
where username in ('agent01@company.com',
'agent02@company.com',
'agent03@company.com',
'agent04@company.com',
'agent05@company.com',
'agent06@company.com',
'agent07@company.com')
-- and CONTACT_DATE = (SELECT MAX(CONTACT_DATE) FROM FACT_CONTACT)
and contact_date >= '2026-10-31'
-- and contact_date = '2026-09-25'
;
