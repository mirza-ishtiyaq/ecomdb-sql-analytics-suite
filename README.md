# EcomDB · SQL Analytics Portfolio

**Author:** Mirza Ishtiyaq Baig &nbsp;|&nbsp; **Role Target:** Data Analyst / Business Analyst &nbsp;|&nbsp; **Stack:** T-SQL · Azure Synapse · Microsoft Fabric · Databricks

---

> This is not a "look, I know SQL" repository.
> Every query here was written to solve a problem that actually hurts a business when it goes wrong —
> missed revenue targets, wasted campaign budgets, incorrect churn flags, loyalty scores that lie.
> The standard applied: production-minded SQL, not textbook SQL.

---

## What A Recruiter Or Hiring Manager Should Know First

Before opening any file, here is what this project demonstrates —
mapped directly to what companies are hiring for in 2026:

| Skill Area | What This Project Shows |
|---|---|
| **Window Functions** | `ROW_NUMBER` · `DENSE_RANK` · `LEAD` — applied to real analytical problems, not syntax drills |
| **CTE Architecture** | Multi-step CTEs where every layer has exactly one named, testable responsibility |
| **Business Logic Thinking** | Knowing *why* `HAVING COUNT(*) = 2` exists and what silently breaks without it |
| **Data Type Awareness** | `DATETIME2(0)` vs `DATE` vs `TIME` — and why mixing them produces wrong answers with no error |
| **Platform-Specific Knowledge** | T-SQL `DATEDIFF` midnight boundary quirk · Synapse constraint behaviour · Fabric Warehouse compatibility |
| **Anti-Pattern Recognition** | `DISTINCT` + `GROUP BY` redundancy · `ORDER BY` inside CTEs · wrong join types and their business consequences |
| **Defensive SQL** | Every query guards against NULL leakage, single-purchase user corruption, and type mismatches |
| **Stakeholder Translation** | Every query opens with the business question — not the technical implementation |
| **Dual-Approach Thinking** | Q5 solves the same problem two ways (MIN/MAX pivot vs LEAD) with documented trade-offs |

---

## Background — Where These Patterns Come From

During my internship at **Full Stack Academy**, I worked daily across
**Databricks**, **Microsoft Fabric**, **Snowflake**, and **Google Cloud Platform**.

The queries in this repository are adapted from the analytical patterns
I was actually using — customer retention scoring, revenue ranking for
merchandising decisions, behavioural segmentation for CRM campaigns.

I documented them to production standard because in real team environments,
someone else always needs to pick up your work and understand it without asking you.

---

## The Database — What We Are Working With

A normalised e-commerce schema. Five tables. One central fact table that everything connects through.

```
customers ──────< orders >────── products
                    │
                    └──────────< reviews

inventory  (standalone — warehouse capacity planning)
```

```sql
customers   → user_id (PK) · join_date · country · prime_status
products    → product_id (PK) · product_name · category · price DECIMAL(10,2)
orders      → order_id (PK) · user_id (FK) · product_id (FK)
              order_timestamp DATETIME2(0) · quantity · delivery_date · order_status
reviews     → review_id (PK) · order_id · product_id · user_id · submit_date · stars
inventory   → item_id (PK) · item_type · square_footage DECIMAL(10,2)
```

**One deliberate schema decision worth noting:**
The `orders` table uses `DATETIME2(0)` — not `DATETIME`.
Azure Synapse and Fabric Warehouse do not support the legacy `DATETIME` type.
Any analyst coming from standard SQL Server will hit this the first time they touch a cloud warehouse.
Knowing this upfront is the difference between a two-minute fix and a two-hour debugging session.

---

## The Queries — Five Real Business Problems

---

### Q1 · Top 2 Revenue-Generating Products Per Category

**The business problem:**
The merchandising team is heading into buying season. They need to know which two products
in each category are actually driving revenue — not units sold, not star ratings — actual money.
This directly influences stock allocation and promotional spend for the quarter.

**Why `DENSE_RANK` and not `ROW_NUMBER`:**
`ROW_NUMBER()` breaks ties arbitrarily. If two products have identical revenue,
one gets rank 1 and the other gets rank 2 — purely by database whim.
The business never sees the tie. They make a stocking decision on incomplete information.
`DENSE_RANK()` surfaces both at rank 1. The full picture is visible.

```
ROW_NUMBER on a tie:   Product A → 1  ·  Product B → 2   ← B hidden from report
DENSE_RANK on a tie:   Product A → 1  ·  Product B → 1   ← both visible
```

**Why `LEFT JOIN` and not `INNER JOIN`:**
If a product was deleted from the products table after orders were placed,
`INNER JOIN` silently drops that revenue. The CFO's number is wrong — no error, no warning.
`LEFT JOIN` keeps those rows as `NULL` product names — a visible data quality signal,
not a silent data loss.

---

### Q2 · Cold Lead Detection — Registered But Never Ordered

**The business problem:**
Marketing has a fixed re-engagement budget. They need a clean list of users who created
an account and then disappeared — never placed a single order, in any status, ever.
This list goes directly into the CRM for a first-purchase discount campaign.

**Why `NOT EXISTS` and not `LEFT JOIN + IS NULL`:**
Both find the same records. The difference is efficiency.
`NOT EXISTS` short-circuits — the moment it finds one matching order row, it stops scanning.
On a customers table with millions of rows and an orders table with hundreds of millions,
that is the difference between a query that runs in seconds and one that times out.

`SELECT 1` inside the subquery is deliberate — existence confirmation only, no column data needed.

---

### Q3 · Consecutive Day Purchasers — 3 or More Days in a Row

**The business problem:**
Operations wants a list of customers who ordered on three or more consecutive calendar days.
This surfaces two completely different signals — high engagement (reward them)
or potential bot/fraud activity (flag for review). The data team surfaces the signal.
The business decides which bucket each user goes to.

**The anchor trick:**
If you subtract a row's sequential rank from its date, consecutive dates always produce the same result.

```
User orders on:   Oct 1  · Oct 2  · Oct 3
Row numbers:      1      · 2      · 3

Oct 1 minus 1 day  =  Sep 30  ← anchor
Oct 2 minus 2 days =  Sep 30  ← same anchor
Oct 3 minus 3 days =  Sep 30  ← same anchor
```

Three identical anchors. One `GROUP BY`. Count reaches 3. Streak detected.
A gap in the sequence produces a different anchor and breaks the group automatically.
No self-join. No recursive CTE. Just subtraction.

---

### Q4 · Days to Second Purchase — Customer Loyalty Segmentation

**The business problem:**
The operations review board wants a single retention metric:
how many calendar days between a customer's first and second delivered order?
A 3-day returner and an 85-day returner are fundamentally different business assets.

**Why `HAVING COUNT(*) = 2` cannot be removed:**
Without it, a customer with only one delivered order still passes through.
Their `MIN(order_date)` equals `MAX(order_date)` — DATEDIFF returns 0.
They land in "Same Day Purchase - Investigate" — completely wrong.
They are not an impulse buyer. They simply never came back.

**Why 0 days is not labelled "Loyal":**
Zero days means two orders on the same calendar day — the same shopping session.
Could be a forgotten item, bulk purchase, or duplicate record.
All three need different responses. Flagging for investigation is the correct default.

```
Loyalty Tier Definitions
────────────────────────────────────────────────────
0 days       →  Same Day Purchase  ·  Flag · investigate
1 – 7 days   →  High Loyalty       ·  Reward campaign
8 – 30 days  →  Medium Loyalty     ·  Nurture campaign
31 – 90 days →  Low Loyalty        ·  Win-back campaign
91+ days     →  Churn Risk         ·  Last-chance offer
```

---

### Q5 · Hours to Second Purchase — Impulse Behaviour (Two Approaches)

**The business problem:**
Day-level precision misses something the product team needs.
Two customers both showing 0 days gap — one returned in 45 minutes, the other in 23 hours.
That is a forgotten item versus a deliberate same-day return. Completely different signals.
Hour-level precision separates them.

**Two approaches implemented with documented trade-offs:**

*Approach A — MIN/MAX Pivot:* Maximum readability. Each CTE has one job.
Easy to debug when something breaks in production.

*Approach B — LEAD Window Function:* More concise. `LEAD()` pulls the next row's datetime
onto the current row — eliminating the pivot step entirely.
`AND next_order_datetime IS NOT NULL` does the same protective job as `HAVING COUNT(*) = 2`.
Same result. Fewer CTEs. Higher interview impact.

**The `DATEDIFF` midnight boundary quirk — documented inline:**
`DATEDIFF(DAY)` counts midnight boundaries crossed, not true 24-hour periods.
A purchase at 23:59 Monday and 00:01 Tuesday returns 1 day — even though 2 minutes elapsed.
The LEAD version anchors loyalty segmentation on the HOUR gap to eliminate this contradiction.

---

## Design Principles Applied Throughout

These are not rules from a textbook. They are things that broke in practice and had to be fixed.

**Every CTE has exactly one job.**
When something breaks in production at 9pm, single-responsibility CTEs make the failing layer obvious immediately.

**Comments explain decisions, not syntax.**
`-- filters delivered orders` is a useless comment.
`-- Pending and Cancelled excluded: unconfirmed revenue inflates totals` is useful.
The code shows *what*. The comment explains *why this choice over the alternatives*.

**Never trust a zero in a business metric.**
Zero days. Zero revenue. Zero orders. In real data, zero almost always means something unexpected.
Before presenting any metric with zeros to a stakeholder, ask what they actually represent.

**A query is not done when it runs. It is done when the output makes business sense.**
A query that executes cleanly and returns wrong numbers is worse than one that throws an error.
At least the error tells you something is broken.

---

## Platform Notes — Synapse / Fabric Specific

| Common Catch | Why It Happens | Fix |
|---|---|---|
| `DATETIME` throws Msg 24574 | Not supported in Synapse/Fabric | Use `DATETIME2(0)` |
| `DATETIME2` without precision throws Msg 24597 | Synapse requires explicit precision | Use `DATETIME2(0)` through `DATETIME2(6)` |
| `ORDER BY` inside CTE throws Msg 1033 | T-SQL forbids it without `TOP` or `OFFSET` | Sort only in the final `SELECT` |
| `PRIMARY KEY NOT ENFORCED` | Synapse/Fabric constraints are metadata only — never enforced | Handle integrity upstream in ADF or dbt |

---

## Files In This Repository

```
/
├── README.md                              ← you are here — start here
├── DATA_Structure.sql                     ← schema creation + seed data (run this first)
└── EcomDB_Analytics_Production.sql       ← all five production queries
```

**Run order:** `DATA_Structure.sql` first to create and seed the tables,
then `EcomDB_Analytics_Production.sql` for the analytical queries.

---

## Connect

- **LinkedIn:** [linkedin.com/in/mirzaishtiyaqbaig](https://www.linkedin.com/in/mirzaishtiyaqbaig/)
- **Email:** ishtiyaqmirza7862@gmail.com
- **GitHub:** [@mirza-ishtiyaq](https://github.com/mirza-ishtiyaq)

---

*Production-style SQL analytics built on real internship patterns.*
*Stack: Azure Synapse · Microsoft Fabric · Databricks · Snowflake · GCP · T-SQL*
