/*
  Autopay Enrollment Trend  (v6)
  % of active accounts enrolled in Autopay, by report date.

  AUTOPAY EVENTS (read from PUBLIC_NOTES_DETAIL)
  Payment-method notes, matched anywhere in the note text:
  - 'PBS PMT MTHD ST CHANGED TO SP' / '... ST CHANGED TO CC'  -> ENROLL  (SP = ACH, CC = credit card)
  - 'PBS PMT MTHD SP CHANGED TO ST' / '... CC CHANGED TO ST'  -> UNENROLL
  - 'PBS PMT MTHD SP CHANGED TO CC' / 'CC CHANGED TO SP'      -> method switch, stays enrolled
  - 'PBS PMT MTHD CHNGD TO ST' inside the bank-return note written by user SP.RET -> UNENROLL (from SP)
  - 'PBS PMT MTHD CHANGED FROM CC TO ST' (qrunr)                                  -> UNENROLL (from CC)
  - Matches buried inside longer notes are only accepted from the system users SP.RET and qrunr.
    (Agents sometimes paste old notes into call notes, which would carry the wrong date.)

  Autopay hold / resume notes (must START the note):
  - 'Bill Chgs Recurring Autopay ... PLACED ON HOLD'  -> UNENROLL (autopay on hold)
  - 'Bill Chgs Recurring Autopay ... CANCELLED'       -> UNENROLL
  - 'Bill Chgs Recurring Autopay ... ACTIVATED'       -> ENROLL   (hold released; same method as before)
  - 'PBS SP TO HOLD ...' / 'PBS CC TO HOLD ...' (e.g. bankruptcy)                 -> UNENROLL
  - qrunr 'HOLD SP RPI ...' / 'HOLD CC RPI ...' and 'Placed on hold PBS CC RPI ...' -> UNENROLL
  - SP.RET bank-return notes containing 'SUBSEQUENT TRANS ON HOLD'                   -> UNENROLL (from SP)

  REMOVAL SIGNALS WITHOUT A PAYMENT-METHOD NOTE (expired card / failed card, etc.)
  Used only when ALL of these hold: the signal note comes AFTER the account's last enrollment, and
  payment_method is currently ST. The account is then unenrolled on the signal note's date.
    Tier 1: qrunr 'CANCELED PBS CC RPI' / 'CANCELED PBS SP RPI'  (the recurring payment instrument was cancelled)
    Tier 2: qrunr 'PLACING CC TRANS ON HOLD DUE TO FATAL DECLINE' (the card failed permanently), CC enrollments only
    Tier 3: 'CC Exp' system notes (NPS expiry-letter request, EMAIL expiry letter, qrunr 'CC EXP DATE PASSED'),
            CC enrollments only
    The best (lowest) tier available for the account wins; within that tier the earliest note is used.
  If the field still says SP/CC these signals are ignored (the customer kept or updated the payment method).

  ORDERING
  - Events are ordered by NOTE_DATE, then NOTE_TIME, then SEQUENCE_NUMBER; the last event of a day wins.

  STATUS LOGIC (per account per report date), in priority order
  1. Account has an autopay event on or before the report date -> status of its most recent event.
  2. Account has events but the report date is BEFORE its first event -> infer prior state from that event
     (if the first event moved it away from autopay, it was on autopay before; otherwise it was not).
  3. Account has no autopay events -> status from the latest payment_method (SP/CC = on autopay), held across all dates.

  TRAILING-UNENROLL RULE
  - If an account's last autopay event(s) are unenrolls (including holds) with no enrollment after them, AND
    payment_method is currently SP or CC, those unenrolls are ignored (treated as an error / quick fix, e.g. qrunr
    batch runs) and the account stays on autopay. If payment_method is ST, the unenroll stands.

  Numerator and denominator are both limited to active disp_codes.
*/

with parsed as (
    select
        account_id,
        note_date::date as event_date,
        entered_by,
        note_text,
        to_char(note_date::date, 'YYYYMMDD') || coalesce(left(note_time, 8), '00:00:00')
            || lpad(coalesce(sequence_number, 0)::varchar, 10, '0') as ord,
        upper(regexp_substr(note_text, 'PBS PMT MTHD (ST|SP|CC) CHANGED TO (ST|SP|CC)', 1, 1, 'ie', 1)) as a_from,
        upper(regexp_substr(note_text, 'PBS PMT MTHD (ST|SP|CC) CHANGED TO (ST|SP|CC)', 1, 1, 'ie', 2)) as a_to,
        upper(regexp_substr(note_text, 'PBS PMT MTHD CHANGED FROM (SP|CC) TO (ST|SP|CC)', 1, 1, 'ie', 1)) as b_from,
        upper(regexp_substr(note_text, 'PBS PMT MTHD CHANGED FROM (SP|CC) TO (ST|SP|CC)', 1, 1, 'ie', 2)) as b_to,
        regexp_like(note_text, '.*PBS PMT MTHD CHNGD TO ST.*', 'is') as c_hit,
        -- hold / resume notes
        upper(regexp_substr(note_text, '^Bill Chgs Recurring Autopay +(CONFIRMATION NUMBER +[0-9A-Za-z]+ +)?(CANCELLED|PLACED ON HOLD|ACTIVATED)', 1, 1, 'ie', 2)) as bc_verb,
        upper(coalesce(
            regexp_substr(note_text, '^PBS (SP|CC) TO HOLD', 1, 1, 'ie', 1),
            regexp_substr(note_text, '^HOLD (SP|CC) RPI', 1, 1, 'ie', 1),
            regexp_substr(note_text, '^Placed on hold PBS (SP|CC) RPI', 1, 1, 'ie', 1)
        )) as hold_m
    from PUBLIC_NOTES_DETAIL
    where note_text ilike '%PBS PMT MTHD%'
       or note_text ilike '%PBS CC RPI%'
       or note_text ilike '%PBS SP RPI%'
       or note_text ilike '%CC Exp%'
       or note_text ilike 'PLACING CC TRANS ON HOLD DUE TO FATAL DECLINE%'
       or note_text ilike 'Bill Chgs Recurring Autopay%'
       or note_text ilike 'PBS % TO HOLD%'
       or note_text ilike 'HOLD % RPI%'
       or note_text ilike 'Placed on hold PBS%'
       or (entered_by = 'SP.RET' and note_text ilike '%SUBSEQUENT TRANS ON HOLD%')
),

classified as (
    select
        account_id, event_date, entered_by, ord,
        -- ev_from: state before the event (SP/CC = that autopay method, AP = autopay of unknown method, ST/null = not on autopay)
        case
            when a_to is not null and (note_text ilike 'PBS PMT MTHD%' or entered_by in ('SP.RET','qrunr')) then a_from
            when b_to is not null and entered_by in ('SP.RET','qrunr') then b_from
            when c_hit and entered_by = 'SP.RET' then 'SP'
            when bc_verb in ('CANCELLED','PLACED ON HOLD') then 'AP'
            when hold_m is not null and (upper(entered_by) = 'QRUNR' or note_text ilike 'PBS % TO HOLD%') then hold_m
            when entered_by = 'SP.RET' and note_text ilike '%SUBSEQUENT TRANS ON HOLD%' then 'SP'
        end as ev_from,
        -- ev_to: SP/CC = enrolled in that method, AR = autopay resumed (method carried over), ST = not on autopay
        case
            when a_to is not null and (note_text ilike 'PBS PMT MTHD%' or entered_by in ('SP.RET','qrunr')) then a_to
            when b_to is not null and entered_by in ('SP.RET','qrunr') then b_to
            when c_hit and entered_by = 'SP.RET' then 'ST'
            when bc_verb in ('CANCELLED','PLACED ON HOLD') then 'ST'
            when bc_verb = 'ACTIVATED' then 'AR'
            when hold_m is not null and (upper(entered_by) = 'QRUNR' or note_text ilike 'PBS % TO HOLD%') then 'ST'
            when entered_by = 'SP.RET' and note_text ilike '%SUBSEQUENT TRANS ON HOLD%' then 'ST'
        end as ev_to
    from parsed
),

all_events_raw as (
    select
        account_id, event_date, ord, ev_from,
        iff(ev_to in ('SP','CC','AR'), 1, 0)                           as is_enroll,
        iff(ev_to in ('SP','CC'), iff(ev_to = 'SP', 'ACH', 'CC'), null) as new_method
    from classified
    where ev_to is not null
),

-- A resumed autopay (ACTIVATED) keeps the method of the previous enrollment
all_events as (
    select
        account_id, event_date, ord, ev_from, is_enroll,
        coalesce(
            new_method,
            iff(is_enroll = 1,
                last_value(new_method) ignore nulls over (
                    partition by account_id order by ord rows between unbounded preceding and 1 preceding),
                null)
        ) as new_method
    from all_events_raw
),

-- Current payment_method per account
latest_pm as (
    select account_id, payment_method
    from DQ_HISTORY
    qualify row_number() over (partition by account_id order by report_date desc) = 1
),

-- Most recent enrollment per account
last_enroll as (
    select account_id, ord as le_ord, new_method as le_method
    from all_events
    where is_enroll = 1
    qualify row_number() over (partition by account_id order by ord desc) = 1
),

-- Removal signals that carry no payment-method note
sig as (
    select account_id, event_date, ord, 1 as tier
    from parsed
    where upper(entered_by) = 'QRUNR'
      and (note_text ilike '%CANCELED PBS CC RPI%' or note_text ilike '%CANCELED PBS SP RPI%')
    union all
    select account_id, event_date, ord, 2 as tier
    from parsed
    where upper(entered_by) = 'QRUNR'
      and note_text ilike 'PLACING CC TRANS ON HOLD DUE TO FATAL DECLINE%'
    union all
    select account_id, event_date, ord, 3 as tier
    from parsed
    where note_text ilike '%CC Exp%'
      and (   (entered_by = 'NPS' and note_text ilike 'CC Exp Date Letter%')
           or  entered_by = 'EMAIL'
           or (entered_by = 'qrunr' and note_text ilike '%CC EXP DATE PASSED%'))
),

-- Keep one signal per account: must follow the last enrollment, with payment_method currently ST
best_sig as (
    select s.account_id, s.event_date, s.ord, le.le_method
    from sig s
    join last_enroll le on s.account_id = le.account_id
    join latest_pm  p   on s.account_id = p.account_id
    where s.ord > le.le_ord
      and p.payment_method not in ('SP','CC')
      and (s.tier = 1 or le.le_method = 'CC')        -- tiers 2 and 3 apply to CC enrollments only
    qualify row_number() over (partition by s.account_id order by s.tier, s.ord) = 1
),

sig_events as (
    select account_id, event_date, ord,
           iff(le_method = 'ACH', 'SP', 'CC') as ev_from,
           0 as is_enroll,
           null::varchar as new_method
    from best_sig
),

all_events_x as (
    select account_id, event_date, ord, ev_from, is_enroll, new_method from all_events
    union all
    select account_id, event_date, ord, ev_from, is_enroll, new_method from sig_events
),

-- Drop trailing unenrolls (no enrollment after them) when the field still says SP/CC
kept_events as (
    select e.*
    from (
        select a.*, max(iff(is_enroll = 1, ord, null)) over (partition by account_id) as last_enroll_ord
        from all_events_x a
    ) e
    left join latest_pm p on e.account_id = p.account_id
    where not (
        e.is_enroll = 0
        and (e.last_enroll_ord is null or e.ord > e.last_enroll_ord)
        and p.payment_method in ('SP','CC')
    )
),

-- Last event per account per day
events as (
    select account_id, event_date, is_enroll, new_method, ev_from
    from kept_events
    qualify row_number() over (partition by account_id, event_date order by ord desc) = 1
),

-- First event per account (infers the state before notes begin)
first_evt as (
    select account_id, iff(ev_from in ('SP','CC','AP'), 1, 0) as first_prior_on, ev_from as first_from
    from events
    qualify row_number() over (partition by account_id order by event_date asc) = 1
),

active_accts as (
    select account_id, report_date::date as report_date, disp_code
    from DQ_HISTORY
    where disp_code in ('A','B','C','E','G','H','K','L','M','N','O','T','U','V','W','Y','Z')
),

joined as (
    select
        a.report_date,
        a.account_id,
        e.is_enroll   as evt_enroll,
        e.new_method  as evt_method,
        f.first_prior_on,
        f.first_from,
        p.payment_method
    from active_accts a
    asof join events e
        match_condition (a.report_date >= e.event_date)
        on a.account_id = e.account_id
    left join first_evt f on a.account_id = f.account_id
    left join latest_pm p on a.account_id = p.account_id
),

flagged as (
    select
        report_date,
        account_id,
        case
            when evt_enroll is not null     then evt_enroll
            when first_prior_on is not null then first_prior_on
            else iff(payment_method in ('SP','CC'), 1, 0)
        end as enrolled_in_autopay,
        case
            when evt_enroll = 1
                then coalesce(evt_method, iff(payment_method = 'CC', 'CC', 'ACH'))
            when evt_enroll is null and first_prior_on = 1
                then case first_from when 'SP' then 'ACH' when 'CC' then 'CC'
                                     else iff(payment_method = 'CC', 'CC', 'ACH') end
            when evt_enroll is null and first_prior_on is null
                 and payment_method in ('SP','CC')               then iff(payment_method = 'SP', 'ACH', 'CC')
        end as autopay_method
    from joined
)

select
    report_date,
    count(*)                                                           as active_accounts,
    sum(enrolled_in_autopay)                                           as autopay_accounts,
    sum(iff(enrolled_in_autopay = 1 and autopay_method = 'ACH', 1, 0)) as autopay_ach,
    sum(iff(enrolled_in_autopay = 1 and autopay_method = 'CC',  1, 0)) as autopay_cc,
    round(sum(enrolled_in_autopay) / nullif(count(*), 0), 4)           as pct_enrolled_autopay
from flagged
group by report_date
order by report_date
;
