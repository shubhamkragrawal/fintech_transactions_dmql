-- =============================================================
-- Phase 2 - Step 2.3: Advanced Analytical Queries
-- =============================================================

-- -------------------------------------------------------------
-- QUERY 1: Monthly Transaction Revenue with Running Total
-- -------------------------------------------------------------

WITH monthly_summary AS (
    SELECT
        DATE_TRUNC('month', "TransactionDate")      AS month,
        "TransactionType"                           AS transactiontype,
        COUNT(*)                                    AS txn_count,
        SUM("TransactionAmount")                    AS total_amount,
        AVG("TransactionAmount")                    AS avg_amount
    FROM dmql_base."FactTransaction"
    WHERE "Status" = 'Success'
      AND "TransactionDate" IS NOT NULL
    GROUP BY 1, 2
)
SELECT
    month,
    transactiontype,
    txn_count,
    ROUND(total_amount::numeric, 2)                 AS total_amount,
    ROUND(avg_amount::numeric, 2)                   AS avg_amount,
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
-- -------------------------------------------------------------
WITH customer_spend AS (
    SELECT
        c."CustomerID",
        c."FullName",
        c."Region",
        c."Status"                                  AS customer_status,
        COUNT(t."TransactionID")                    AS txn_count,
        SUM(t."TransactionAmount")                  AS total_spent,
        AVG(t."TransactionAmount")                  AS avg_txn_amount,
        MAX(t."TransactionDate")                    AS last_transaction_date
    FROM dmql_base."FactTransaction"    t
    JOIN dmql_base."DimAccount"         a ON t."AccountID"  = a."AccountID"
    JOIN dmql_base."DimCustomer"        c ON a."CustomerID" = c."CustomerID"
    WHERE t."Status" = 'Success'
    GROUP BY 1, 2, 3, 4
)
SELECT
    "CustomerID",
    "FullName",
    "Region",
    customer_status,
    txn_count,
    ROUND(total_spent::numeric, 2)                  AS total_spent,
    ROUND(avg_txn_amount::numeric, 2)               AS avg_txn_amount,
    last_transaction_date,
    RANK() OVER (ORDER BY total_spent DESC)         AS spend_rank,
    ROUND(
        (PERCENT_RANK() OVER (ORDER BY total_spent))::numeric * 100, 1
    )                                               AS spend_percentile
FROM customer_spend
ORDER BY spend_rank
LIMIT 20;


-- -------------------------------------------------------------
-- QUERY 3: Failure Rate & Risk Analysis by Product Category
-- -------------------------------------------------------------
WITH product_stats AS (
    SELECT
        pc."ProductCategoryName"                        AS category,
        ps."ProductSubCategoryName"                     AS sub_category,
        p."ProductName"                                 AS productname,
        COUNT(t."TransactionID")                        AS total_txns,
        COUNT(t."TransactionID")
            FILTER (WHERE t."Status" = 'Success')       AS completed,
        COUNT(t."TransactionID")
            FILTER (WHERE t."Status" = 'Failed')        AS failed,
        SUM(t."TransactionAmount")                      AS total_volume,
        SUM(t."TransactionAmount")
            FILTER (WHERE t."Status" = 'Failed')        AS failed_volume
    FROM dmql_base."FactTransaction"            t
    JOIN dmql_base."DimProduct"                 p  ON t."ProductID"              = p."ProductID"
    JOIN dmql_base."DimProductSubCategory"      ps ON p."ProductSubcategoryID"   = ps."ProductSubCategoryID"
    JOIN dmql_base."DimProductCategory"         pc ON ps."ProductCategoryID"     = pc."ProductCategoryID"
    GROUP BY 1, 2, 3
)
SELECT
    category,
    sub_category,
    productname,
    total_txns,
    completed,
    failed,
    ROUND((failed::numeric / NULLIF(total_txns, 0)) * 100, 2)  AS failure_rate_pct,
    ROUND(total_volume::numeric, 2)                             AS total_volume,
    ROUND(failed_volume::numeric, 2)                            AS failed_volume,
    RANK() OVER (
        PARTITION BY category
        ORDER BY (failed::numeric / NULLIF(total_txns, 0)) DESC
    )                                                           AS risk_rank_in_category
FROM product_stats
ORDER BY failure_rate_pct DESC;


-- =============================================================
-- EXPLAIN ANALYZE — Run this for performance_report.md
-- =============================================================
EXPLAIN ANALYZE
WITH product_stats AS (
    SELECT
        pc."ProductCategoryName"                        AS category,
        p."ProductName"                                 AS productname,
        COUNT(t."TransactionID")                        AS total_txns,
        COUNT(t."TransactionID")
            FILTER (WHERE t."Status" = 'Failed')        AS failed,
        SUM(t."TransactionAmount")                      AS total_volume
    FROM dmql_base."FactTransaction"            t
    JOIN dmql_base."DimProduct"                 p  ON t."ProductID"            = p."ProductID"
    JOIN dmql_base."DimProductSubCategory"      ps ON p."ProductSubcategoryID" = ps."ProductSubCategoryID"
    JOIN dmql_base."DimProductCategory"         pc ON ps."ProductCategoryID"   = pc."ProductCategoryID"
    GROUP BY 1, 2
)
SELECT *, RANK() OVER (PARTITION BY category ORDER BY total_txns DESC)
FROM product_stats
ORDER BY total_txns DESC;


-- INDEXES
CREATE INDEX IF NOT EXISTS idx_facttxn_productid
    ON dmql_base."FactTransaction"("ProductID");

CREATE INDEX IF NOT EXISTS idx_facttxn_accountid
    ON dmql_base."FactTransaction"("AccountID");

CREATE INDEX IF NOT EXISTS idx_facttxn_status
    ON dmql_base."FactTransaction"("Status");

CREATE INDEX IF NOT EXISTS idx_facttxn_date
    ON dmql_base."FactTransaction"("TransactionDate");

CREATE INDEX IF NOT EXISTS idx_product_subcategoryid
    ON dmql_base."DimProduct"("ProductSubcategoryID");

CREATE INDEX IF NOT EXISTS idx_account_customerid
    ON dmql_base."DimAccount"("CustomerID");



-- =============================================================
-- Phase 2 - Step 2.3: Advanced Analytical Queries
-- =============================================================

-- -------------------------------------------------------------
-- QUERY 1: Monthly Transaction Revenue with Running Total
-- -------------------------------------------------------------
WITH monthly_summary AS (
    SELECT
        DATE_TRUNC('month', "TransactionDate")      AS month,
        "TransactionType"                           AS transactiontype,
        COUNT(*)                                    AS txn_count,
        SUM("TransactionAmount")                    AS total_amount,
        AVG("TransactionAmount")                    AS avg_amount
    FROM dmql_base."FactTransaction"
    WHERE "Status" = 'Success'
      AND "TransactionDate" IS NOT NULL
    GROUP BY 1, 2
)
SELECT
    month,
    transactiontype,
    txn_count,
    ROUND(total_amount::numeric, 2)                 AS total_amount,
    ROUND(avg_amount::numeric, 2)                   AS avg_amount,
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
-- -------------------------------------------------------------
WITH customer_spend AS (
    SELECT
        c."CustomerID",
        c."FullName",
        c."Region",
        c."Status"                                  AS customer_status,
        COUNT(t."TransactionID")                    AS txn_count,
        SUM(t."TransactionAmount")                  AS total_spent,
        AVG(t."TransactionAmount")                  AS avg_txn_amount,
        MAX(t."TransactionDate")                    AS last_transaction_date
    FROM dmql_base."FactTransaction"    t
    JOIN dmql_base."DimAccount"         a ON t."AccountID"  = a."AccountID"
    JOIN dmql_base."DimCustomer"        c ON a."CustomerID" = c."CustomerID"
    WHERE t."Status" = 'Success'
    GROUP BY 1, 2, 3, 4
)
SELECT
    "CustomerID",
    "FullName",
    "Region",
    customer_status,
    txn_count,
    ROUND(total_spent::numeric, 2)                  AS total_spent,
    ROUND(avg_txn_amount::numeric, 2)               AS avg_txn_amount,
    last_transaction_date,
    RANK() OVER (ORDER BY total_spent DESC)         AS spend_rank,
    ROUND(
        (PERCENT_RANK() OVER (ORDER BY total_spent))::numeric * 100, 1
    )                                               AS spend_percentile
FROM customer_spend
ORDER BY spend_rank
LIMIT 20;


-- -------------------------------------------------------------
-- QUERY 3: Failure Rate & Risk Analysis by Product Category
-- -------------------------------------------------------------
WITH product_stats AS (
    SELECT
        pc."ProductCategoryName"                        AS category,
        ps."ProductSubCategoryName"                     AS sub_category,
        p."ProductName"                                 AS productname,
        COUNT(t."TransactionID")                        AS total_txns,
        COUNT(t."TransactionID")
            FILTER (WHERE t."Status" = 'Success')       AS completed,
        COUNT(t."TransactionID")
            FILTER (WHERE t."Status" = 'Failed')        AS failed,
        SUM(t."TransactionAmount")                      AS total_volume,
        SUM(t."TransactionAmount")
            FILTER (WHERE t."Status" = 'Failed')        AS failed_volume
    FROM dmql_base."FactTransaction"            t
    JOIN dmql_base."DimProduct"                 p  ON t."ProductID"              = p."ProductID"
    JOIN dmql_base."DimProductSubCategory"      ps ON p."ProductSubcategoryID"   = ps."ProductSubCategoryID"
    JOIN dmql_base."DimProductCategory"         pc ON ps."ProductCategoryID"     = pc."ProductCategoryID"
    GROUP BY 1, 2, 3
)
SELECT
    category,
    sub_category,
    productname,
    total_txns,
    completed,
    failed,
    ROUND((failed::numeric / NULLIF(total_txns, 0)) * 100, 2)  AS failure_rate_pct,
    ROUND(total_volume::numeric, 2)                             AS total_volume,
    ROUND(failed_volume::numeric, 2)                            AS failed_volume,
    RANK() OVER (
        PARTITION BY category
        ORDER BY (failed::numeric / NULLIF(total_txns, 0)) DESC
    )                                                           AS risk_rank_in_category
FROM product_stats
ORDER BY failure_rate_pct DESC;



EXPLAIN ANALYZE
WITH product_stats AS (
    SELECT
        pc."ProductCategoryName"                        AS category,
        p."ProductName"                                 AS productname,
        COUNT(t."TransactionID")                        AS total_txns,
        COUNT(t."TransactionID")
            FILTER (WHERE t."Status" = 'Failed')        AS failed,
        SUM(t."TransactionAmount")                      AS total_volume
    FROM dmql_base."FactTransaction"            t
    JOIN dmql_base."DimProduct"                 p  ON t."ProductID"            = p."ProductID"
    JOIN dmql_base."DimProductSubCategory"      ps ON p."ProductSubcategoryID" = ps."ProductSubCategoryID"
    JOIN dmql_base."DimProductCategory"         pc ON ps."ProductCategoryID"   = pc."ProductCategoryID"
    GROUP BY 1, 2
)
SELECT *, RANK() OVER (PARTITION BY category ORDER BY total_txns DESC)
FROM product_stats
ORDER BY total_txns DESC;

-- dropped index sql
-- DROP INDEX IF EXISTS dmql_base.idx_facttxn_productid;
-- DROP INDEX IF EXISTS dmql_base.idx_facttxn_accountid;
-- DROP INDEX IF EXISTS dmql_base.idx_facttxn_status;
-- DROP INDEX IF EXISTS dmql_base.idx_facttxn_date;
-- DROP INDEX IF EXISTS dmql_base.idx_product_subcategoryid;
-- DROP INDEX IF EXISTS dmql_base.idx_account_customerid;