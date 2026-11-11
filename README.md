# Andrew Wrona — Analytics Portfolio

Work that shows the thinking, not just the résumé. Each project is a real problem from servicing, collections, and revenue operations — what was broken, what I built, and what changed because of it.

## Projects

| Project | What it does | Stack |
|---|---|---|
| [Autopay Enrollment Trends](projects/autopay-enrollment-trend/case-study.md) | Reconstructs account-level autopay enrollment history from free-text servicing notes, so enrollment trends can be reported, securitization decisions can rest on real data, and newly unenrolled customers can be targeted. ~300k accounts, daily, history back to Nov 2025. | Snowflake SQL |
| [First Payment Default Dashboard](projects/first-payment-default-dashboard/case-study.md) | Tracks each onboarding batch from boarding through first payment — payer rate, non-payers, autopay split, and average days to payment, by batch. ~7,000 accounts, runs daily; payer rate 23% → 32% as of Oct 31, 2026. | Excel / VBA · Salesforce |
| [Agent Performance Dashboard](projects/agent-performance-dashboard/case-study.md) | Dropdown-driven view of call volume and handle time by agent, queue, and call type, plus a weekly view so totals tie out. | Excel / VBA · Snowflake SQL · Amazon Connect |
| [Concord Billed vs. Collected by System](projects/concord-billed-vs-collected-by-system/case-study.md) | Rolls billed vs. collected up to one row per system for any month, excluding charges from accounts parked in non-billing dispositions. ~300k accounts a month. | Snowflake SQL |

## Structure

```
projects/
  autopay-enrollment-trend/
    case-study.md                  # Problem, approach, how it works, impact
    sql/autopay_enrollment_trend.sql
    sample-output-illustrative.csv # Output format (illustrative figures, not real data)
```

Every project follows the same shape: the problem in plain language, the approach, the actual code or analysis, and the measurable impact. No real customer or account data appears anywhere; table names are shown without schema qualifiers.

## About

Senior Servicing Analyst in solar loan servicing — collections, revenue operations, billing, and data analytics. I build the queries, logic, and reporting that turn servicing data into decisions.

**Stack:** SQL (Snowflake) · Python (pandas) · Power BI · Power Query · Excel/VBA · Salesforce · Snowflake · APIs

## Contact

- GitHub: https://github.com/sawrona
- LinkedIn: https://www.linkedin.com/in/andrew-wrona/
