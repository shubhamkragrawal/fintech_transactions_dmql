-- =============================================================
-- Phase 2 - Step 2.3: Advanced Analytical Queries
-- FinTech Dataset | dmql_base schema
-- =============================================================

-- -------------------------------------------------------------
-- QUERY 1: Monthly Transaction Revenue with Running Total
-- Techniques: CTE, DATE_TRUNC, Window Function (SUM OVER)
-- -------------------------------------------------------------
WITH monthly_summary AS (
    SELECT
        DATE_TRUNC('month', transactiondate)        AS month,
        transactiontype,
        COUNT(*)                                    AS txn_count,
        SUM(transactionamount)                      AS total_amount,
        AVG(transactionamount)                      AS avg_amount
    FROM dmql_base.facttransaction
    WHERE status = 'COMPLETED'
      AND transactiondate IS NOT NULL
    GROUP BY 1, 2
)
SELECT
    month,
    transactiontype,
    txn_count,
    ROUND(total_amount::numeric,   2)               AS total_amount,
    ROUND(avg_amount::numeric,     2)               AS avg_amount,
    ROUND(
        SUM(total_amount) OVER (
            PARTITION BY transactiontype
            ORDER BY month
        )::numeric, 2
    )                                               AS running_total_by_type,
    ROUND(
        SUM(total_amount) OVER (ORDER BY month)::numeric, 2
    )                                               AS overall_running_total
FROM monthly_summary
ORDER BY month, transactiontype;


-- -------------------------------------------------------------
-- QUERY 2: Top 20 Customers by Spend with Percentile Rank
-- Techniques: CTE, JOIN, Window Functions (RANK, PERCENT_RANK)
-- -------------------------------------------------------------
WITH customer_spend AS (
    SELECT
        c.customerid,
        c.fullname,
        c.region,
        c.status                                    AS customer_status,
        COUNT(t.transactionid)                      AS txn_count,
        SUM(t.transactionamount)                    AS total_spent,
        AVG(t.transactionamount)                    AS avg_txn_amount,
        MAX(t.transactiondate)                      AS last_transaction_date
    FROM dmql_base.facttransaction t
    JOIN dmql_base.dimaccount      a USING (accountid)
    JOIN dmql_base.dimcustomer     c ON a.customerid = c.customerid
    WHERE t.status = 'COMPLETED'
    GROUP BY 1, 2, 3, 4
)
SELECT
    customerid,
    fullname,
    region,
    customer_status,
    txn_count,
    ROUND(total_spent::numeric,      2)             AS total_spent,
    ROUND(avg_txn_amount::numeric,   2)             AS avg_txn_amount,
    last_transaction_date,
    RANK()         OVER (ORDER BY total_spent DESC) AS spend_rank,
    ROUND(
        (PERCENT_RANK() OVER (ORDER BY total_spent))::numeric * 100, 1
    )                                               AS spend_percentile
FROM customer_spend
ORDER BY spend_rank
LIMIT 20;


-- -------------------------------------------------------------
-- QUERY 3: Failure Rate & Risk Analysis by Product Category
-- Techniques: CTE, FILTER aggregation, JOIN chain, Window Function
-- -------------------------------------------------------------
WITH product_stats AS (
    SELECT
        pc.productcategoryname                          AS category,
        ps.productsubcategoryname                       AS sub_category,
        p.productname,
        COUNT(t.transactionid)                          AS total_txns,
        COUNT(t.transactionid)
            FILTER (WHERE t.status = 'COMPLETED')       AS completed,
        COUNT(t.transactionid)
            FILTER (WHERE t.status = 'FAILED')          AS failed,
        COUNT(t.transactionid)
            FILTER (WHERE t.status = 'PENDING')         AS pending,
        SUM(t.transactionamount)                        AS total_volume,
        SUM(t.transactionamount)
            FILTER (WHERE t.status = 'FAILED')          AS failed_volume
    FROM dmql_base.facttransaction          t
    JOIN dmql_base.dimproduct               p  USING (productid)
    JOIN dmql_base.dimproductsubcategory    ps USING (productsubcategoryid)
    JOIN dmql_base.dimproductcategory       pc USING (productcategoryid)
    GROUP BY 1, 2, 3
)
SELECT
    category,
    sub_category,
    productname,
    total_txns,
    completed,
    failed,
    pending,
    ROUND((failed::numeric  / NULLIF(total_txns, 0)) * 100, 2) AS failure_rate_pct,
    ROUND(total_volume::numeric,  2)                            AS total_volume,
    ROUND(failed_volume::numeric, 2)                            AS failed_volume,
    RANK() OVER (
        PARTITION BY category
        ORDER BY (failed::numeric / NULLIF(total_txns, 0)) DESC
    )                                                           AS risk_rank_in_category
FROM product_stats
ORDER BY failure_rate_pct DESC;
