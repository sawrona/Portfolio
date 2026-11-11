# Autopay Enrollment Trends — Reconstructing Account-Level Autopay History from Servicing Notes

**Role:** Senior Servicing Analyst, solar loan servicing
**Stack:** Snowflake SQL · subservicer data mart (servicing comments + daily account snapshots)
**Status:** In production — runs daily · History back to Nov 1, 2025 · ~300,000 accounts

## The problem

Autopay status in the servicing system was a **stale field**: it showed an account's *current* payment method and nothing else. There was no way to look back and see when an account enrolled in autopay, when it unenrolled, or how enrollment was trending over time.

That mattered because autopay enrollment is one of the clearest signals of collection activity and customer behavior — and investors need to see it. Without history, the team couldn't answer basic questions: Is autopay enrollment rising or falling? Did a collections push move the needle? Which accounts just dropped off autopay and need attention? The only alternative was combing through hundreds of thousands of free-text comments in the servicing portal by hand.

## What I built

A single Snowflake query that reconstructs the **full autopay enrollment history for every account**, from the free-text servicing notes and the daily account snapshots. The developer team used it to build out the autopay logic and update the daily table, so any account's AP history — every enrollment and unenrollment — is now queryable by date.

The query outputs one row per report date:

| Column | Meaning |
|---|---|
| `report_date` | The date the trend is measured on |
| `active_accounts` | Active accounts that day (denominator) |
| `autopay_accounts` | Accounts enrolled in autopay |
| `autopay_ach` | Enrolled via ACH (bank draft) |
| `autopay_cc` | Enrolled via credit card |
| `pct_enrolled_autopay` | Share of active accounts on autopay |

## How it works

**1. Events are mined from free-text notes, not from a status field.**
There is no enrollment event table — the only record of an autopay change is a line in a servicing comment. The query parses note text with regex to extract payment-method changes (`ST → SP/CC` = enroll, `SP/CC → ST` = unenroll, `SP ↔ CC` = method switch, stays enrolled). Note date + note time + sequence number order the events; the last event of a day wins.

**2. Buried matches are only trusted from system users.**
Agents sometimes paste old notes into call notes, which would carry the wrong date. A payment-method match buried inside a longer note is only accepted when it was written by the system users (`SP.RET`, `qrunr`).

**3. Holds and resumes are handled as events.**
`PLACED ON HOLD` / `CANCELLED` unenroll an account; `ACTIVATED` re-enrolls it, carrying the previous payment method forward (via `LAST_VALUE ... IGNORE NULLS`) since a resume note doesn't restate the method. Bankruptcy holds (`PBS SP/CC TO HOLD`, `HOLD SP/CC RPI`) and bank-return holds are covered too.

**4. Silent unenrolls get tiered removal signals.**
Some accounts drop off autopay with no payment-method note at all — an expired or failed card. The query catches those with three tiers of signals, used only when the signal comes *after* the account's last enrollment and the payment-method field currently reads `ST` (if the field still says `SP`/`CC`, the customer kept or updated the method and the signal is ignored):
- **Tier 1:** the recurring payment instrument was cancelled
- **Tier 2:** the card failed permanently (fatal decline) — CC enrollments only
- **Tier 3:** the card expired (expiry-letter requests, `CC EXP DATE PASSED`) — CC enrollments only

The best (lowest) tier available wins; the earliest note within that tier sets the unenroll date.

**5. A trailing-unenroll guard filters batch noise.**
If an account's last events are unenrolls with no enrollment after them, *and* the payment-method field still says `SP`/`CC`, those unenrolls are ignored — they're treated as an error or quick fix (e.g. automated batch runs), and the account stays on autopay. If the field says `ST`, the unenroll stands.

**6. Status is resolved per account, per day.**
For each report date, an account's status is its most recent event on or before that date (via an `ASOF` join against the daily snapshots). If the report date falls *before* the account's first event, the prior state is inferred from that event. Accounts with no events at all fall back to their latest payment method, held across all dates. Numerator and denominator are limited to active disposition codes.

## Impact

- **~300,000 accounts** covered, with history back to **Nov 1, 2025**, refreshed **daily**.
- **Investor reporting is now accurate**: autopay trends can be reported at the account level and rolled up to any granularity — no more hand-combing hundreds of thousands of portal comments.
- **Securitization decisions** (million-dollar calls) now rest on real enrollment trends instead of a stale point-in-time field.
- **Newly unenrolled customers can be targeted** — the team can see exactly who dropped off autopay and when, and act on it.
- The logic is **reusable**: the same event-reconstruction pattern works for any status that only exists as free-text notes.

## Output — format

`sample-output-illustrative.csv` shows the shape of the daily output. **The figures in it are illustrative, not real data** — real enrollment numbers are proprietary. The columns and grain are exactly what the query produces.

## Files

- `sql/autopay_enrollment_trend.sql` — the full query (v6), with table names shortened to the table only, per the author's sharing rule; no schemas, no real account data.
- `sample-output-illustrative.csv` — illustrative daily output (format only).

