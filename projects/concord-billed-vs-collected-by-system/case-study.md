# Concord Billed vs. Collected by System

**Role:** Senior Servicing Analyst, Billing Operations & Collections
**Stack:** Snowflake SQL
**Status:** In production — runs regularly

## The problem

Finance and servicing needed to compare what Concord billed against what it collected for a month, by system. The account-level version double counted accounts that were in non-active dispositions and wasn't rolled up the way anyone discussed the portfolio.

## What I built

I rewrote the Billed vs. Collected query so it returns one row per system for any month. It uses the account's disposition on each charge's due date, so accounts parked in non-billing dispositions are excluded for that period and counted again once they return to an active code.

## How it works

1. Parameter CTE sets the month window from a single date.
2. Charge disposition CTE finds the disposition in effect on each charge's due date (latest change before the due date, via QUALIFY ROW_NUMBER).
3. Billed = direct-debit charges with latest status 'C', excluding sales tax and charges of $1 or less, and excluding the listed dispositions.
4. Collected = payment transactions in the month, minus any payment later reversed by a return/NSF of the same account and amount.
5. Full outer join billed and collected at account level; roll up to system name, showing current disposition codes with LISTAGG; unmapped accounts stay on their own row.

## Impact

Pulls ~300,000 accounts every month of charges and payments.

## Output — format

One row per system: Month, System Name, Disposition Code(s), Amount Billed, Amount Collected.

## Files

- `sql/concord-billed-vs-collected-by-system.sql` — the full query. Table names only, no schemas.

## Notes on sharing

Sharing: show code, table names only — no schemas.
