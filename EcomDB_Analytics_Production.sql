-- ================================================================================================================================
-- ================================================================================================================================
--
--      ███████╗ ██████╗ ██████╗ ███╗   ███╗██████╗ ██████╗      █████╗ ███╗   ██╗ █████╗ ██╗  ██╗   ██╗████████╗██╗ ██████╗███████╗
--      ██╔════╝██╔════╝██╔═══██╗████╗ ████║██╔══██╗██╔══██╗    ██╔══██╗████╗  ██║██╔══██╗██║  ╚██╗ ██╔╝╚══██╔══╝██║██╔════╝██╔════╝
--      █████╗  ██║     ██║   ██║██╔████╔██║██║  ██║██████╔╝    ███████║██╔██╗ ██║███████║██║   ╚████╔╝    ██║   ██║██║     ███████╗
--      ██╔══╝  ██║     ██║   ██║██║╚██╔╝██║██║  ██║██╔══██╗    ██╔══██║██║╚██╗██║██╔══██║██║    ╚██╔╝     ██║   ██║██║     ╚════██║
--      ███████╗╚██████╗╚██████╔╝██║ ╚═╝ ██║██████╔╝██████╔╝    ██║  ██║██║ ╚████║██║  ██║███████╗██║      ██║   ██║╚██████╗███████║
--      ╚══════╝ ╚═════╝ ╚═════╝ ╚═╝     ╚═╝╚═════╝ ╚═════╝     ╚═╝  ╚═╝╚═╝  ╚═══╝╚═╝  ╚═╝╚══════╝╚═╝      ╚═╝   ╚═╝ ╚═════╝╚══════╝
--
-- ================================================================================================================================
-- ================================================================================================================================
--
--  FILE              :  EcomDB_Analytics_Production.sql
--  PROJECT           :  EcomDB — Customer & Revenue Analytics Suite
--  AUTHOR            :  Mirza Ishtiyaq Baig
--  ROLE              :  Data Analyst / Business Analyst
--  PLATFORM          :  Azure Synapse Analytics / Microsoft Fabric Warehouse (T-SQL)
--  VERSION           :  v2.0  |  Production-Ready
--  CREATED           :  2024
--  LAST REVIEWED     :  2025
--
-- ================================================================================================================================
--
--  WHAT THIS FILE IS
--  ──────────────────
--  This is not a collection of SQL exercises.
--  Every query in this file was written to solve a problem that directly affects business decisions —
--  revenue reporting, campaign targeting, fraud detection, and customer retention scoring.
--
--  The standard applied here: if this query were wrong, which business team would feel it?
--  That question drove every design decision — join type, window function choice, guard clauses,
--  data type selection, and CTE structure.
--
-- ================================================================================================================================
--
--  SKILLS DEMONSTRATED  (for technical reviewers)
--  ─────────────────────────────────────────────────────────────────────────────────────────────
--  ✦  Window Functions          ROW_NUMBER · DENSE_RANK · LEAD — applied to real analytical contexts
--  ✦  CTE Architecture          Multi-layer CTEs where every step has one named, testable responsibility
--  ✦  Defensive SQL             HAVING COUNT guards · NULL safety · type-matched DATEDIFF calls
--  ✦  Join Strategy             Conscious LEFT vs INNER decisions with documented business consequence
--  ✦  Correlated Subqueries     NOT EXISTS with short-circuit logic for large-dataset performance
--  ✦  Date-Time Handling        CAST · DATETIME2(0) · DATEDIFF midnight boundary awareness
--  ✦  Platform Awareness        Synapse-specific constraints: no DATETIME · precision-required DATETIME2
--  ✦  Dual-Approach Thinking    Same problem solved two ways (MIN/MAX pivot vs LEAD) with trade-off notes
--  ✦  Business Logic Encoding   CASE segmentation tied to CRM playbooks · 0-day anomaly detection
--  ✦  Anti-Pattern Recognition  DISTINCT+GROUP BY redundancy · ORDER BY in CTEs · type-mixed DATEDIFF
--
-- ================================================================================================================================
--
--  DATABASE SCHEMA  —  EcomDB
--  ────────────────────────────
--
--  RELATIONSHIP MAP:
--
--      customers ──────────< orders >────────── products
--                               │
--                               └────────────< reviews
--
--      inventory  (standalone — warehouse capacity, no FK to orders)
--
--  TABLE SUMMARY:
--
--  ┌─────────────┬──────────────────────────────────────────────────────────────────────────┐
--  │ Table       │ Key Columns                                                               │
--  ├─────────────┼──────────────────────────────────────────────────────────────────────────┤
--  │ customers   │ user_id (PK) · join_date · country · prime_status                        │
--  │ products    │ product_id (PK) · product_name · category · price DECIMAL(10,2)          │
--  │ orders      │ order_id (PK) · user_id (FK) · product_id (FK)                           │
--  │             │ order_timestamp DATETIME2(0) · quantity · delivery_date · order_status    │
--  │ reviews     │ review_id (PK) · order_id · product_id · user_id · submit_date · stars   │
--  │ inventory   │ item_id (PK) · item_type · square_footage DECIMAL(10,2)                  │
--  └─────────────┴──────────────────────────────────────────────────────────────────────────┘
--
--  PLATFORM NOTE — READ THIS BEFORE RUNNING:
--  ───────────────────────────────────────────
--  This schema targets Azure Synapse Analytics / Microsoft Fabric Warehouse.
--  Three things that catch engineers coming from standard SQL Server:
--
--  1. DATETIME is not supported in Synapse. Use DATETIME2(0) through DATETIME2(6).
--     Precision is mandatory — DATETIME2 without a number throws Msg 24597.
--
--  2. PRIMARY KEY and FOREIGN KEY constraints are NOT ENFORCED in Synapse.
--     They exist as metadata hints for the query optimizer only.
--     Data integrity must be handled upstream (ADF pipelines, dbt models).
--
--  3. ORDER BY inside a CTE throws Msg 1033.
--     Sorting belongs only in the final SELECT of each query block.
--
-- ================================================================================================================================
--
--  QUERY INDEX
--  ────────────
--  Q1  ·  Top 2 Revenue Products Per Category          ──  line ~180
--  Q2  ·  Cold Lead Detection                          ──  line ~280
--  Q3  ·  Consecutive Day Purchasers (3+ Days Streak)  ──  line ~370
--  Q4  ·  Days to Second Purchase  (MIN/MAX Approach)  ──  line ~510
--  Q5  ·  Hours to Second Purchase (LEAD Approach)     ──  line ~650
--
--  SHARED BUSINESS RULE APPLIED ACROSS ALL QUERIES:
--  Only orders with order_status = 'Delivered' are treated as confirmed revenue.
--  Pending · Cancelled · Returned statuses are excluded unless explicitly documented.
--
-- ================================================================================================================================
-- ================================================================================================================================




-- ================================================================================================================================
-- ================================================================================================================================
--
--  ██████╗  ██╗
--  ██╔═══██╗███║
--  ██║   ██║╚██║
--  ██║▄▄ ██║ ██║
--  ╚██████╔╝ ██║
--   ╚══▀▀═╝  ╚═╝
--
--  TOP 2 REVENUE-GENERATING PRODUCTS PER CATEGORY
--  Merchandising · Buying Plan · Promotional Budget Allocation
--
-- ================================================================================================================================
-- ================================================================================================================================
--
--  THE BUSINESS PROBLEM
--  ─────────────────────
--  Every quarter, the merchandising team makes stocking decisions.
--  They need to know which two products inside each category are actually driving revenue —
--  not units sold, not star ratings — actual money. This report feeds the annual buying plan
--  and decides where promotional spend goes. Get this wrong and you overstock the wrong SKU.
--
--  METRIC DEFINITION
--  ──────────────────
--  Total Revenue  =  SUM(quantity ordered × unit price at time of order)
--  Reporting Scope  =  Delivered orders within calendar year 2023 only
--
--  WHY DENSE_RANK AND NOT ROW_NUMBER — THE DECISION THAT MATTERS
--  ───────────────────────────────────────────────────────────────
--  ROW_NUMBER() breaks ties arbitrarily. If two products have identical revenue,
--  one gets rank 1 and the other gets rank 2. The business never sees the tie.
--  They make a stocking decision based on incomplete information.
--
--  DENSE_RANK() surfaces ties — both products get rank 1.
--  The category shows three products instead of two, which is the correct and honest output.
--
--      ROW_NUMBER  on a tie:    Vacuum Cleaner → 1  ·  Headset → 2    ← Headset hidden
--      DENSE_RANK  on a tie:    Vacuum Cleaner → 1  ·  Headset → 1    ← both visible
--
--  WHY LEFT JOIN AND NOT INNER JOIN
--  ──────────────────────────────────
--  If a product was deleted from the products table after orders were placed
--  (data migration, soft deletes, catalogue cleanup), an INNER JOIN silently drops
--  that revenue from the report. The CFO's number is wrong and there is no error message.
--
--  LEFT JOIN keeps those rows as NULL product names — a visible data quality signal
--  that triggers investigation rather than silent data loss.
--
--  OUTPUT COLUMNS
--  ───────────────
--  category        →  Electronics · Appliance (from products table)
--  product_name    →  individual SKU name
--  total_revenue   →  SUM(quantity × price) for the reporting year
--
--  HOW TO MODIFY THIS QUERY
--  ─────────────────────────
--  ► Change reporting year           →  update date range in WHERE clause
--  ► Show top 3 products             →  change revenue_rank <= 2 to <= 3
--  ► Add units sold alongside revenue →  add SUM(o.quantity) AS units_sold to SELECT
--  ► Expand to all order statuses    →  remove AND o.order_status = 'Delivered'
--  ► Add average order value         →  add AVG(o.quantity * p.price) AS avg_order_value
--
-- ================================================================================================================================

WITH product_revenue_ranked AS (

    SELECT
        p.category                              AS category,
        p.product_name                          AS product_name,
        SUM(o.quantity * p.price)               AS total_revenue,

        -- DENSE_RANK chosen over ROW_NUMBER to preserve revenue ties.
        -- PARTITION BY category → rank resets independently for each category.
        -- ORDER BY DESC → highest earner gets rank 1.
        -- A NULL category (orphaned product_id) will form its own NULL partition —
        -- that is intentional and surfaces referential integrity gaps.
        DENSE_RANK() OVER (
            PARTITION BY p.category
            ORDER BY SUM(o.quantity * p.price) DESC
        )                                       AS revenue_rank

    FROM EcomDB.dbo.orders o

        -- LEFT JOIN: retains orders whose product_id has no matching product record.
        -- Those rows appear with NULL product details — a data quality flag, not a data loss.
        LEFT JOIN EcomDB.dbo.products p
            ON o.product_id = p.product_id

    WHERE
        o.order_timestamp >= '2023-01-01'           -- start of reporting window (inclusive)
        AND o.order_timestamp <  '2024-01-01'       -- end of reporting window (exclusive)
        AND o.order_status   =  'Delivered'         -- confirmed revenue events only

    GROUP BY
        p.category,
        p.product_name
)

SELECT
    category,
    product_name,
    total_revenue
FROM product_revenue_ranked
WHERE revenue_rank <= 2                             -- ► change to <= 3 for top-3 view
ORDER BY
    category        ASC,
    total_revenue   DESC;

-- ================================================================================================================================
--  END Q1  ·  Top 2 Revenue Products Per Category
-- ================================================================================================================================




-- ================================================================================================================================
-- ================================================================================================================================
--
--  ██████╗ ██████╗
--  ██╔═══██╗╚════██╗
--  ██║   ██║ █████╔╝
--  ██║▄▄ ██║██╔═══╝
--  ╚██████╔╝███████╗
--   ╚══▀▀═╝ ╚══════╝
--
--  COLD LEAD DETECTION — REGISTERED BUT NEVER ORDERED
--  Marketing · CRM Re-engagement · First-Purchase Campaigns
--
-- ================================================================================================================================
-- ================================================================================================================================
--
--  THE BUSINESS PROBLEM
--  ─────────────────────
--  Marketing has a fixed budget for re-engagement campaigns.
--  They do not want to spend it on active customers — that is waste.
--  They need a clean list of users who created an account and then went quiet:
--  never placed a single order, in any status, ever.
--  This list goes directly into the CRM to trigger a first-purchase discount flow.
--
--  WHY NOT EXISTS AND NOT LEFT JOIN + IS NULL
--  ───────────────────────────────────────────
--  Both approaches find the same records. The difference is how they find them.
--
--  Option A  →  LEFT JOIN + WHERE o.user_id IS NULL
--               Joins every customer to every order row, then filters.
--               On a 10M-row orders table this is expensive.
--
--  Option B  →  NOT EXISTS  (used here)
--               For each customer row, it scans orders until it finds ONE match.
--               The moment a match is found, it stops and moves on.
--               This short-circuit behaviour is meaningfully faster at scale.
--
--  SELECT 1 inside the subquery is deliberate.
--  We do not need order data — just existence confirmation.
--  Selecting a literal 1 is the standard signal for that intent.
--
--  OUTPUT COLUMNS
--  ───────────────
--  user_id    →  customer identifier — ready for CRM upload
--  join_date  →  account creation date — used for campaign age-segmentation
--
--  HOW TO MODIFY THIS QUERY
--  ─────────────────────────
--  ► Target cold leads who joined more than 90 days ago
--    →  add AND c.join_date <= DATEADD(DAY, -90, GETDATE()) in the outer WHERE
--  ► Exclude users with pending (in-progress) orders
--    →  add AND NOT EXISTS (SELECT 1 FROM EcomDB.dbo.orders o2
--                           WHERE o2.user_id = c.user_id
--                           AND   o2.order_status = 'Pending')
--  ► Add country for localised campaign routing
--    →  include c.country in SELECT
--  ► Add prime_status to personalise offer
--    →  include c.prime_status in SELECT
--
-- ================================================================================================================================

SELECT
    c.user_id,
    c.join_date

FROM EcomDB.dbo.customers c

WHERE NOT EXISTS (
    -- Short-circuit scan: stops at the first matching order found.
    -- SELECT 1 signals we need existence only — no column data required.
    SELECT 1
    FROM EcomDB.dbo.orders o
    WHERE o.user_id = c.user_id
)

ORDER BY c.join_date ASC;      -- oldest cold leads first — longest-dormant accounts = highest re-engagement priority

-- ================================================================================================================================
--  END Q2  ·  Cold Lead Detection
-- ================================================================================================================================




-- ================================================================================================================================
-- ================================================================================================================================
--
--   ██████╗ ██████╗
--  ██╔═══██╗╚════██╗
--  ██║   ██║ █████╔╝
--  ██║▄▄ ██║ ╚═══██╗
--  ╚██████╔╝██████╔╝
--   ╚══▀▀═╝ ╚═════╝
--
--  CONSECUTIVE DAY PURCHASERS — 3 OR MORE DAYS IN A ROW
--  Operations · Power Buyer Detection · Fraud / Bot Flagging
--
-- ================================================================================================================================
-- ================================================================================================================================
--
--  THE BUSINESS PROBLEM
--  ─────────────────────
--  Operations needs a list of customers who placed orders on three or more consecutive
--  calendar days. This surfaces two completely different behaviours:
--
--  1.  HIGH ENGAGEMENT  →  reward these users, flag for loyalty programme enrolment
--  2.  BOT / FRAUD      →  abnormal consecutive ordering warrants a fraud review
--
--  The data team surfaces the signal. The business decides which users go to which bucket.
--  That is the correct division of responsibility.
--
--  THE ANCHOR TRICK — HOW THIS WORKS (READ THIS CAREFULLY)
--  ─────────────────────────────────────────────────────────
--  This is the most elegant pattern in the file. No self-joins. No recursive CTEs.
--  Just subtraction.
--
--  The insight: if you subtract a row's sequential rank from its date,
--  consecutive dates will always produce the same result.
--
--      User 101 orders on:   Oct 1,    Oct 2,    Oct 3
--      Row numbers:          1         2         3
--
--      Oct 1  minus 1 day  =  Sep 30   ← anchor
--      Oct 2  minus 2 days =  Sep 30   ← same anchor
--      Oct 3  minus 3 days =  Sep 30   ← same anchor
--
--      → Three identical anchors → one GROUP BY group → COUNT = 3 → consecutive streak detected.
--
--  Now watch what a gap does:
--
--      User 102 orders on:   Oct 1,    Oct 3   (Oct 2 is missing)
--      Row numbers:          1         2
--
--      Oct 1  minus 1 day  =  Sep 30
--      Oct 3  minus 2 days =  Oct 1    ← different anchor
--
--      → Two different anchors → two separate groups → COUNT never reaches 3 → correctly excluded.
--
--  WHY DEDUPLICATE FIRST (STEP 1)
--  ────────────────────────────────
--  A user can place multiple orders on the same calendar day.
--  Without deduplication, a single day with 3 orders would get 3 row numbers,
--  which breaks the anchor math entirely. One row per user per day is mandatory.
--
--  OUTPUT COLUMNS
--  ───────────────
--  user_id                  →  customer identifier
--  consecutive_days_count   →  length of the detected consecutive streak
--
--  HOW TO MODIFY THIS QUERY
--  ─────────────────────────
--  ► Lower the threshold to 2 consecutive days
--    →  change HAVING COUNT(anchor_group) >= 3 to >= 2
--  ► Show the actual start and end date of each streak
--    →  add MIN(purchase_date) AS streak_start, MAX(purchase_date) AS streak_end
--       to the final SELECT and to the GROUP BY clause
--  ► Scope to a specific date range
--    →  add WHERE order_timestamp >= '2023-01-01' in step1_deduplicated
--  ► Identify only fraud-risk candidates (5+ consecutive days)
--    →  change HAVING COUNT >= 3 to >= 5
--
-- ================================================================================================================================

WITH step1_deduplicated AS (
    -- One row per user per calendar day.
    -- A user placing 3 orders on Oct 1 should count as ONE purchase day — not three.
    -- Without this deduplication, the anchor math in Step 3 breaks completely.
    SELECT DISTINCT
        user_id,
        CAST(order_timestamp AS DATE)   AS purchase_date
    FROM EcomDB.dbo.orders
),

step2_ranked AS (
    -- Assign a sequential rank to each purchase day per user, oldest first.
    -- rank 1 = the user's earliest ever purchase day.
    -- PARTITION BY user_id ensures ranking starts fresh for each individual customer.
    SELECT
        user_id,
        purchase_date,
        ROW_NUMBER() OVER (
            PARTITION BY user_id
            ORDER BY purchase_date ASC
        )                               AS row_num
    FROM step1_deduplicated
),

step3_anchor_created AS (
    -- The anchor trick: subtract the row number from the date.
    -- Consecutive days collapse to the same anchor_group value.
    -- Any gap in the purchase sequence produces a different anchor_group.
    -- This turns a complex sequence detection problem into a simple GROUP BY count.
    SELECT
        user_id,
        purchase_date,
        row_num,
        DATEADD(DAY, -row_num, purchase_date)   AS anchor_group
    FROM step2_ranked
)

-- Count purchase days sharing the same anchor per user.
-- GROUP BY user_id AND anchor_group — not just user_id.
-- Each user can have multiple streaks (different anchor values),
-- and each streak must be counted independently.
SELECT
    user_id,
    COUNT(anchor_group)             AS consecutive_days_count
FROM step3_anchor_created
GROUP BY
    user_id,
    anchor_group                    -- one row per streak per user
HAVING
    COUNT(anchor_group) >= 3        -- ► change threshold here if needed
ORDER BY
    consecutive_days_count DESC;    -- longest streaks surfaced first

-- ================================================================================================================================
--  END Q3  ·  Consecutive Day Purchasers
-- ================================================================================================================================




-- ================================================================================================================================
-- ================================================================================================================================
--
--  ██████╗ ██╗  ██╗
--  ██╔═══██╗██║  ██║
--  ██║   ██║███████║
--  ██║▄▄ ██║╚════██║
--  ╚██████╔╝     ██║
--   ╚══▀▀═╝      ╚═╝
--
--  DAYS TO SECOND PURCHASE — LOYALTY SEGMENTATION
--  Approach: MIN / MAX PIVOT
--  Operations · Customer Retention · Monthly Business Review KPI
--
-- ================================================================================================================================
-- ================================================================================================================================
--
--  THE BUSINESS PROBLEM
--  ─────────────────────
--  The operations review board wants a single retention metric:
--  how many calendar days does it take for a customer to place a second order
--  after their first delivered purchase?
--
--  A 3-day returner and an 85-day returner are fundamentally different business assets.
--  This query assigns each customer a loyalty tier that maps directly to CRM action playbooks.
--
--  LOYALTY TIER DEFINITIONS  (aligned with CRM playbook v2.3)
--  ──────────────────────────────────────────────────────────────
--  ┌─────────────────────────┬──────────────────────────────┬───────────────────────────────┐
--  │ Days to Second Purchase │ Loyalty Segment              │ CRM Action                    │
--  ├─────────────────────────┼──────────────────────────────┼───────────────────────────────┤
--  │ 0 days                  │ Same Day · Flag for Review   │ Investigate — not a return    │
--  │ 1 – 7 days              │ High Loyalty                 │ Reward campaign               │
--  │ 8 – 30 days             │ Medium Loyalty               │ Nurture campaign              │
--  │ 31 – 90 days            │ Low Loyalty                  │ Win-back campaign             │
--  │ 91+ days                │ Churn Risk                   │ Last-chance offer             │
--  └─────────────────────────┴──────────────────────────────┴───────────────────────────────┘
--
--  WHY 0 DAYS IS NOT LABELLED "LOYAL"
--  ─────────────────────────────────────
--  Zero days means two orders on the same calendar day.
--  That is not a return visit — it is the same shopping session.
--  Could be a forgotten item, a bulk purchase, or a duplicate order record.
--  All three need different responses. Flagging for investigation is the correct default.
--
--  THE HAVING COUNT(*) = 2 GUARD — NEVER REMOVE THIS
--  ────────────────────────────────────────────────────
--  Without this line, a customer with only ONE delivered order passes through.
--  Their MIN(order_date) = MAX(order_date) → DATEDIFF returns 0.
--  They land in "Same Day Purchase - Investigate" — completely wrong.
--  They are not an impulse buyer. They simply never came back.
--  HAVING COUNT(*) = 2 removes them cleanly before they corrupt loyalty segments.
--
--  APPROACH — MIN/MAX PIVOT
--  ──────────────────────────
--  Each user has two rows after Step 3 (rank 1 and rank 2).
--  MIN() captures the first date, MAX() captures the second.
--  GROUP BY user_id collapses two rows into one — no join required.
--  This is the most readable approach and easiest to debug in production.
--
--  OUTPUT COLUMNS
--  ───────────────
--  user_id                  →  customer identifier
--  first_visit              →  date of first delivered order
--  second_visit             →  date of second delivered order
--  days_to_second_purchase  →  calendar day gap (primary KPI)
--  churn_status             →  CRM loyalty tier label
--
--  HOW TO MODIFY THIS QUERY
--  ─────────────────────────
--  ► Filter to retained customers only (30-day window)
--    →  uncomment WHERE clause at bottom of final SELECT
--  ► Add country-level segmentation
--    →  JOIN EcomDB.dbo.customers c ON c.user_id = s.user_id
--       add c.country to SELECT and GROUP BY
--  ► Adjust loyalty tier boundaries
--    →  edit the WHEN thresholds in the CASE block
--  ► Switch to HOUR precision instead of DAY
--    →  see Q5 below for the timestamp-precision version
--
--  KNOWN PLATFORM QUIRK — DATEDIFF MIDNIGHT BOUNDARY
--  ────────────────────────────────────────────────────
--  DATEDIFF(DAY, ...) in T-SQL counts midnight boundaries crossed, not true 24-hour periods.
--  A purchase at 23:59 Monday and another at 00:01 Tuesday returns 1 day —
--  even though only 2 minutes elapsed. For day-level loyalty scoring this is acceptable.
--  For hour-level impulse analysis, see Q5 which uses DATETIME2 and DATEDIFF(HOUR).
--
-- ================================================================================================================================

WITH step1_filtering AS (
    -- Filter to delivered orders only.
    -- Cast full timestamp to DATE — we only need calendar-day precision here.
    -- Changing the WHERE condition here affects every downstream step.
    SELECT
        user_id,
        CAST(order_timestamp AS DATE)       AS order_date
    FROM EcomDB.dbo.orders
    WHERE order_status = 'Delivered'        -- confirmed transactions only
),

step2_row_numbering AS (
    -- Assign a chronological purchase rank to each order per customer.
    -- rank 1 = their very first delivered order.
    -- PARTITION BY user_id → ranking sequence restarts fresh for each customer.
    -- ORDER BY order_date ASC → earliest order always gets rank 1.
    SELECT
        user_id,
        order_date,
        ROW_NUMBER() OVER (
            PARTITION BY user_id
            ORDER BY order_date ASC
        )                                   AS purchase_rnk
    FROM step1_filtering
),

step3_first_two_only AS (
    -- Keep rank 1 and rank 2 per user. Discard rank 3 and beyond.
    -- Retaining extra ranks here would break the MIN/MAX pivot in Step 4:
    -- MAX(order_date) would return the 3rd or 4th purchase date, not the 2nd.
    SELECT
        user_id,
        order_date,
        purchase_rnk
    FROM step2_row_numbering
    WHERE purchase_rnk <= 2
),

step4_pivot AS (
    -- Collapse two rows per user into one row.
    -- MIN(order_date) = first purchase · MAX(order_date) = second purchase.
    -- HAVING COUNT(*) = 2 is the critical guard:
    -- it removes users with only one delivered order before they produce false 0-day results.
    SELECT
        user_id,
        MIN(order_date)                     AS first_visit,
        MAX(order_date)                     AS second_visit
    FROM step3_first_two_only
    GROUP BY user_id
    HAVING COUNT(*) = 2                     -- only users who have made at least 2 delivered purchases
),

step5_day_gap AS (
    -- Calculate the calendar day gap between first and second purchase.
    -- DATE vs DATE input — correct type pairing for DATEDIFF(DAY).
    SELECT
        user_id,
        first_visit,
        second_visit,
        DATEDIFF(DAY, first_visit, second_visit)    AS days_to_second_purchase
    FROM step4_pivot
)

SELECT
    user_id,
    first_visit,
    second_visit,
    days_to_second_purchase,
    CASE
        WHEN days_to_second_purchase = 0        THEN 'Same Day Purchase - Investigate'
        WHEN days_to_second_purchase <= 7       THEN 'High Loyalty'
        WHEN days_to_second_purchase <= 30      THEN 'Medium Loyalty'
        WHEN days_to_second_purchase <= 90      THEN 'Low Loyalty'
        ELSE                                         'Churn Risk'
    END                                             AS churn_status

FROM step5_day_gap

-- ► OPTIONAL FILTER: uncomment the line below for retained-customer-only view (stakeholder request)
-- WHERE days_to_second_purchase BETWEEN 1 AND 30

ORDER BY days_to_second_purchase ASC;

-- ================================================================================================================================
--  END Q4  ·  Days to Second Purchase (MIN/MAX Pivot)
-- ================================================================================================================================




-- ================================================================================================================================
-- ================================================================================================================================
--
--   ██████╗ ███████╗
--  ██╔═══██╗██╔════╝
--  ██║   ██║███████╗
--  ██║▄▄ ██║╚════██║
--  ╚██████╔╝███████║
--   ╚══▀▀═╝ ╚══════╝
--
--  HOURS TO SECOND PURCHASE — IMPULSE BEHAVIOUR ANALYSIS
--  Approach: LEAD WINDOW FUNCTION  (optimised — fewer CTEs, same result)
--  Product · Behavioural Analytics · Same-Day Impulse Detection
--
-- ================================================================================================================================
-- ================================================================================================================================
--
--  THE BUSINESS PROBLEM
--  ─────────────────────
--  Day-level precision misses something the product team needs to see.
--
--  If two customers both show 0 days to second purchase, one might have returned
--  45 minutes later and the other 23 hours later. That is a fundamentally different
--  behaviour — one is a forgotten item, the other is a deliberate same-day return visit.
--  At day-level, both look identical. At hour-level, they are two different customer signals.
--
--  This query captures full timestamp precision to separate them.
--
--  HOW THIS DIFFERS FROM Q4
--  ──────────────────────────
--  Q4  →  CAST to DATE   →  day-level precision   →  MIN/MAX pivot to collapse rows
--  Q5  →  CAST to DATETIME2(0)  →  hour-level precision  →  LEAD to avoid pivot entirely
--
--  APPROACH — LEAD WINDOW FUNCTION
--  ─────────────────────────────────
--  Instead of keeping rank 1 and 2 and then collapsing with MIN/MAX,
--  LEAD() reaches forward in the ranked result set and pulls the NEXT row's
--  value down onto the CURRENT row — both dates land on the same row in one step.
--
--      Before LEAD:
--      ┌─────────┬──────────────────────┬──────────────┐
--      │ user_id │ order_datetime        │ purchase_rnk │
--      ├─────────┼──────────────────────┼──────────────┤
--      │ 101     │ 2022-06-01 08:30:00   │ 1            │
--      │ 101     │ 2023-10-01 11:20:00   │ 2            │
--      └─────────┴──────────────────────┴──────────────┘
--
--      After LEAD (both datetimes now on rank 1 row):
--      ┌─────────┬──────────────────────┬──────────────────────┬──────────────┐
--      │ user_id │ order_datetime        │ next_order_datetime   │ purchase_rnk │
--      ├─────────┼──────────────────────┼──────────────────────┼──────────────┤
--      │ 101     │ 2022-06-01 08:30:00   │ 2023-10-01 11:20:00  │ 1  ← keep   │
--      │ 101     │ 2023-10-01 11:20:00   │ NULL                 │ 2  ← discard│
--      └─────────┴──────────────────────┴──────────────────────┴──────────────┘
--
--  Filter WHERE purchase_rnk = 1 AND next_order_datetime IS NOT NULL.
--  That IS NOT NULL check does the same job as HAVING COUNT(*) = 2 in Q4:
--  it removes single-purchase users cleanly before DATEDIFF runs.
--
--  DATEDIFF MIDNIGHT BOUNDARY — THE QUIRK WORTH KNOWING
--  ───────────────────────────────────────────────────────
--  DATEDIFF(DAY) counts midnight boundaries crossed — not true 24-hour periods elapsed.
--
--      Purchase 1:  Monday   23:59:00
--      Purchase 2:  Tuesday  00:01:00
--
--      DATEDIFF(DAY,  ...)  =  1   ← crossed one midnight boundary
--      DATEDIFF(HOUR, ...)  =  0   ← only 2 minutes actually passed
--
--  These two contradict each other. One says High Loyalty. The other says Same Day Purchase.
--  Same customer. Same two orders. Two different loyalty tiers — depending on which column
--  the dashboard displays. That is a real analytical risk.
--
--  This query anchors the loyalty CASE on the HOUR gap — the more honest measure.
--  168 hours = 7 days · 720 hours = 30 days · 2160 hours = 90 days.
--  The business logic is identical to Q4. The boundary risk is removed.
--
--  OUTPUT COLUMNS
--  ───────────────
--  user_id                  →  customer identifier
--  first_visit_date         →  calendar date of first purchase (day-level context)
--  second_visit_date        →  calendar date of second purchase
--  days_to_second_purchase  →  day gap (display only — see note on boundary quirk)
--  hours_to_second_purchase →  hour gap (primary metric — drives loyalty CASE)
--  customer_loyalty_segment →  CRM tier label based on hour gap
--
--  HOW TO MODIFY THIS QUERY
--  ─────────────────────────
--  ► Add minute-level precision
--    →  add DATEDIFF(MINUTE, first_visit_datetime, second_visit_datetime) AS minutes_to_second_purchase
--  ► Filter to same-day impulse buyers only
--    →  add WHERE days_to_second_purchase = 0 in final SELECT
--  ► Filter to retained customers (30-day window)
--    →  uncomment WHERE clause at bottom of final SELECT
--  ► Switch back to MIN/MAX pivot approach
--    →  see Q4 above — both produce identical output, different readability profile
--
-- ================================================================================================================================

WITH step1_filtering AS (
    -- Filter delivered orders.
    -- Two casts of the same source column — one for day context, one for hour precision.
    -- DATETIME2(0) required by Synapse — DATETIME is not supported on this platform.
    SELECT
        user_id,
        order_timestamp,
        CAST(order_timestamp AS DATE)           AS order_date,      -- day-level context only
        CAST(order_timestamp AS DATETIME2(0))   AS order_datetime   -- hour-level precision
    FROM EcomDB.dbo.orders
    WHERE order_status = 'Delivered'            -- confirmed transactions only
),

step2_ranked_with_next AS (
    -- Rank each user's orders by full timestamp — not by date alone.
    -- Using full timestamp correctly separates two orders placed hours apart
    -- on the same calendar day. Date-only ordering would give them identical ranks.
    --
    -- LEAD() reaches forward to the next row in the same user's ordered sequence
    -- and pulls both its date and datetime onto the current row.
    -- When no next row exists (the user's last purchase), LEAD returns NULL.
    SELECT
        user_id,
        order_date,
        order_datetime,

        ROW_NUMBER() OVER (
            PARTITION BY user_id
            ORDER BY order_timestamp ASC
        )                                       AS purchase_rnk,

        LEAD(order_date) OVER (
            PARTITION BY user_id
            ORDER BY order_timestamp ASC
        )                                       AS next_order_date,

        LEAD(order_datetime) OVER (
            PARTITION BY user_id
            ORDER BY order_timestamp ASC
        )                                       AS next_order_datetime

    FROM step1_filtering
),

step3_first_purchase_only AS (
    -- Keep only rank 1 rows.
    -- Rank 1 now carries the first purchase AND the second purchase on the same row.
    -- Rank 2 and beyond have already served their purpose — discard them.
    --
    -- AND next_order_datetime IS NOT NULL is the single-purchase guard.
    -- It does the same job as HAVING COUNT(*) = 2 in Q4.
    -- A user with only one delivered order has LEAD returning NULL —
    -- this line removes them cleanly before DATEDIFF runs on NULL inputs.
    SELECT
        user_id,
        order_date          AS first_visit_date,
        order_datetime      AS first_visit_datetime,
        next_order_date     AS second_visit_date,
        next_order_datetime AS second_visit_datetime
    FROM step2_ranked_with_next
    WHERE purchase_rnk = 1
      AND next_order_datetime IS NOT NULL       -- removes single-purchase users — do not remove this guard
)

SELECT
    user_id,
    first_visit_date,
    second_visit_date,

    -- Day gap: DATE vs DATE — correct type pairing.
    -- Display context only — see midnight boundary note above before using in CASE logic.
    DATEDIFF(DAY,  first_visit_date,     second_visit_date)     AS days_to_second_purchase,

    -- Hour gap: DATETIME2 vs DATETIME2 — correct type pairing.
    -- Primary metric — drives the loyalty CASE below.
    -- Immune to the midnight boundary quirk that affects DATEDIFF(DAY).
    DATEDIFF(HOUR, first_visit_datetime, second_visit_datetime) AS hours_to_second_purchase,

    -- Loyalty tier anchored on HOUR gap — not DAY gap.
    -- This eliminates the midnight boundary contradiction.
    -- Thresholds: 168h = 7 days · 720h = 30 days · 2160h = 90 days.
    -- ► To change boundaries: edit the WHEN values below.
    CASE
        WHEN DATEDIFF(HOUR, first_visit_datetime, second_visit_datetime) = 0    THEN 'Same Day Purchase - Investigate'
        WHEN DATEDIFF(HOUR, first_visit_datetime, second_visit_datetime) <= 168  THEN 'High Loyalty'        -- 7 days
        WHEN DATEDIFF(HOUR, first_visit_datetime, second_visit_datetime) <= 720  THEN 'Medium Loyalty'      -- 30 days
        WHEN DATEDIFF(HOUR, first_visit_datetime, second_visit_datetime) <= 2160 THEN 'Low Loyalty'         -- 90 days
        ELSE                                                                          'Churn Risk'
    END                                                                         AS customer_loyalty_segment

FROM step3_first_purchase_only

-- ► OPTIONAL FILTER: uncomment for retained-customer-only view (stakeholder request)
-- WHERE days_to_second_purchase BETWEEN 1 AND 30

ORDER BY hours_to_second_purchase ASC;

-- ================================================================================================================================
--  END Q5  ·  Hours to Second Purchase (LEAD Approach)
-- ================================================================================================================================




-- ================================================================================================================================
-- ================================================================================================================================
--
--  END OF FILE
--
--  ┌─────────────────────────────────────────────────────────────────────────────────────┐
--  │                                                                                     │
--  │   ANALYST'S NOTE                                                                    │
--  │                                                                                     │
--  │   SQL is just a tool.                                                               │
--  │   The real skill is knowing whether your output makes business sense.               │
--  │                                                                                     │
--  │   A query that runs cleanly and returns wrong numbers is worse than one             │
--  │   that throws an error — at least the error tells you something is broken.          │
--  │                                                                                     │
--  │   Before showing any metric to a stakeholder, ask:                                  │
--  │   "If the CFO acted on this number right now, would they make a good decision?"     │
--  │   If the answer is no — fix the logic, not just the syntax.                         │
--  │                                                                                     │
--  └─────────────────────────────────────────────────────────────────────────────────────┘
--
--  Author     :  Mirza Ishtiyaq Baig
--  Contact    :  [Your Email / LinkedIn]
--  Repository :  [Your GitHub URL]
--  Last Reviewed  :  2025  |  Platform  :  Azure Synapse Analytics
--
-- ================================================================================================================================
-- ================================================================================================================================
