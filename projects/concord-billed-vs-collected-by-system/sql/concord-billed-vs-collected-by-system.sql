-- Concord Billed vs. Collected, one row per System_Name for a specified month
-- Change the date in params to any date inside the month you want.
--
-- Changes vs. prior version:
--   1. Billed charges are excluded when the account's disposition on the charge due date
--      was one of: C, D, F, I, J, M, P, Q, R, S, T, X (accounts that move back to an
--      active code have their charges counted again for that period)
--   2. System_Name added (via DQ_HISTORY); all accounts roll up to one row per System_Name
--   3. disp_code (current) added to the output

WITH params AS (
    SELECT
        DATE_TRUNC('month', TO_DATE('2026-09-01'))                      AS month_start
        ,DATEADD('month', 1, DATE_TRUNC('month', TO_DATE(month_start))) AS next_month_start
),

-- DISPOSITION AT DUE DATE: for each charge, the disp_code in effect on its due date
--   (latest change dated BEFORE the due date). A change made on the due date itself
--   does not affect that charge. Charges with no prior disposition record are kept.
charge_disp AS (
    SELECT
        bc.charge_id
        ,dc.disp_code AS disp_at_due_date
    FROM PUBLIC_BILLING_CHARGES bc
    CROSS JOIN params p
    LEFT JOIN PUBLIC_BILLING_DISPOSITIONCHANGES dc
        ON  dc.account_id = bc.account_id
        AND dc.as_of_date::DATE < bc.due_date::DATE
    WHERE bc.due_date >= p.month_start
      AND bc.due_date <  p.next_month_start
    QUALIFY ROW_NUMBER() OVER (PARTITION BY bc.charge_id ORDER BY dc.as_of_date DESC, dc.sequence_number DESC) = 1
),

-- CURRENT DISP CODE: latest disposition change per account
current_disp AS (
    SELECT
        account_id
        ,disp_code
    FROM PUBLIC_BILLING_DISPOSITIONCHANGES
    QUALIFY ROW_NUMBER() OVER (PARTITION BY account_id ORDER BY as_of_date DESC, sequence_number DESC) = 1
),

-- SYSTEM NAME: Concord account_id -> System_Name (latest snapshot, one system per account)
acct_system AS (
    SELECT
        account_id
        ,system_name
    FROM DQ_HISTORY
    WHERE system_name IS NOT NULL
    QUALIFY ROW_NUMBER() OVER (PARTITION BY account_id ORDER BY report_date DESC) = 1
),

-- BILLED: same filters as Concord_Billing_Charges_v2
--   due date in month, charge_type = 'DD', latest status code = 'C',
--   excludes sales tax (category 'ST'), individual charges > $1
--   NEW: excludes charges due after the account's disposition cutoff date
billed AS (
    SELECT
        bc.account_id
        ,SUM(bc.amount) AS amount_billed
    FROM PUBLIC_BILLING_CHARGES bc
    LEFT JOIN (
        SELECT charge_id, code
        FROM PUBLIC_BILLING_CHARGES_STATUS
        QUALIFY ROW_NUMBER() OVER (PARTITION BY charge_id ORDER BY sequence_number DESC) = 1
    ) bcs
        ON bc.charge_id = bcs.charge_id
    LEFT JOIN charge_disp cd
        ON bc.charge_id = cd.charge_id
    CROSS JOIN params p
    WHERE bc.due_date >= p.month_start
      AND bc.due_date <  p.next_month_start
      AND bc.charge_type = 'DD'
      AND bcs.code = 'C'
      AND bc.category <> 'ST'
      AND bc.amount > 1
      AND (cd.disp_at_due_date IS NULL
           OR cd.disp_at_due_date NOT IN ('C','D','F','I','J','M','P','Q','R','S','T','X'))
    GROUP BY bc.account_id
),

-- COLLECTED: same filters as Concord_Successful_Payments
--   PMT / NCP transactions, excluding any payment later reversed by a
--   return/NSF with the same account and amount
returns AS (
    SELECT
        account_id
        ,ABS(amount)       AS return_amount
        ,last_update_date  AS return_date
    FROM PUBLIC_BILLING_TRANSACTIONS
    WHERE transaction_code IN ('RTND','RTNE','RTNC','NSF','NSFC','NSFE','NSFW','ZCASH')
),

collected AS (
    SELECT
        t.account_id
        ,SUM(t.amount) AS amount_collected
    FROM PUBLIC_BILLING_TRANSACTIONS t
    CROSS JOIN params p
    WHERE t.transaction_code IN ('PMT','NCP')
      AND t.last_update_date >= p.month_start
      AND t.last_update_date <  p.next_month_start
      AND NOT EXISTS (
            SELECT 1
            FROM returns r
            WHERE r.account_id    = t.account_id
              AND r.return_amount = t.amount
              AND r.return_date  >= t.last_update_date
      )
    GROUP BY t.account_id
),

-- ACCOUNT LEVEL: combine billed + collected, attach system name and disp code
account_level AS (
    SELECT
        COALESCE(b.account_id, c.account_id)  AS account_id
        ,COALESCE(b.amount_billed, 0)         AS amount_billed
        ,COALESCE(c.amount_collected, 0)      AS amount_collected
    FROM billed b
    FULL OUTER JOIN collected c
        ON b.account_id = c.account_id
)

-- SYSTEM LEVEL: one row per System_Name (accounts with no system match stay on their own row)
SELECT
    p.month_start                                                   AS "Month"
    ,COALESCE(s.system_name, 'UNMAPPED - ' || a.account_id)         AS "System Name"
    ,LISTAGG(DISTINCT d.disp_code, ', ') WITHIN GROUP (ORDER BY d.disp_code) AS "Disp Code"
    ,SUM(a.amount_billed)                                           AS "Amount Billed"
    ,SUM(a.amount_collected)                                        AS "Amount Collected"
FROM account_level a
LEFT JOIN acct_system s
    ON a.account_id = s.account_id
LEFT JOIN current_disp d
    ON a.account_id = d.account_id
CROSS JOIN params p
GROUP BY p.month_start, COALESCE(s.system_name, 'UNMAPPED - ' || a.account_id)
ORDER BY "System Name";
