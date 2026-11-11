# Andrew Wrona

**Senior Servicing Analyst, SunStrong Management · Houston, TX**
**Senior Financial Analyst | Business Performance & FP&A Analytics**

## About me

I'm a data analyst with 5+ years of experience turning raw data into actionable insights for leadership and operational strategy utilizing SQL, Python, and Excel, with a focus on business intelligence, data modeling, and predictive analytics. Most of my work lives in solar loan servicing: collections, revenue operations, and billing, where I automate manual reporting and build the dashboards, queries, and logic that decisions rest on.

Right now I'm a Senior Servicing Analyst at SunStrong Management. Before that I was a Senior Collections Analyst at Sunnova (through the transition to SunStrong), and a Workforce Analyst at PFS Group. I keep coming back to the same kind of problem: the answer is buried in data nobody can query cleanly, and the fix is a query, a pipeline, or a dashboard that makes it obvious.

### What I'm doing now

- Built and maintain a vendor tracking and scoring platform spanning five servicing vendors — KPI scoring, corrective-action tracking, and audit logging to support cost-control and service-level decisions.
- Own the buyout/prepayment calculator used across the Third Party Owned (TPO) lease and PPA portfolio, and trained cross-functional and offshore teams on it. It has contributed to $961,104.74 in customer buyout payments and a $161,732.99 improvement in quoted-vs-paid accuracy after a calculator redesign.
- Designed and automated a daily Python/Snowflake pipeline that builds and segments the Collections team's Amazon Connect outbound dialer lists; I manage day-to-day dialer operations, new-hire systems onboarding, and team scheduling.
- Built a clickable HTML onboarding module and designed a hybrid team/individual bonus structure for the Billing Ops & Collections team, documented processes, and cleaned legacy Salesforce data to stabilize reporting under the new servicing entity.

### Before SunStrong

- At Sunnova, automated Salesforce report extraction and transformation using Python, eliminating 8–10 hours per week of manual reporting, and designed and owned Power BI dashboards tracking portfolio health, delinquency, roll rates, and performance across 4,000+ active payment plans.
- At PFS Group, designed utilization strategies that contributed to a 30% year-over-year increase in payments.

## Projects

Work that shows the thinking, not just the résumé. Each project is a real problem from servicing, collections, and revenue operations — what was broken, what I built, and what changed because of it.

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

## Stack

**Data & statistics:** SQL (Snowflake) · Python (pandas) · R · Statistics · Data Modeling · Predictive Analytics · Revenue Modeling · VBA/Macro Development
**Visualization & BI:** Power BI · Tableau · Excel · KPI Design · Roll Rate Analysis · Cross-Functional Reporting
**Tools & infrastructure:** AWS · Snowflake · Salesforce · Amazon Connect · HTML/Web-Based Tooling · APIs

## Education

**Loras College — Dubuque, IA.** Bachelor of Arts in Finance and Business Administration (May 2019). Minors: Data Analytics and Management Information Systems.

## Contact

- GitHub: https://github.com/sawrona
- LinkedIn: https://www.linkedin.com/in/andrew-wrona/
- Email: ajwrona97@gmail.com
