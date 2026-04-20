# Phase 2 - Performance Tuning Report

---

## 1. Query Profiled

**Query 3 - Failure Rate & Risk Analysis by Product Category**

---

## 2. Before Indexing

```sql
EXPLAIN ANALYZE
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
        SUM(t.transactionamount)                        AS total_volume
    FROM dmql_base.facttransaction          t
    JOIN dmql_base.dimproduct               p  USING (productid)
    JOIN dmql_base.dimproductsubcategory    ps USING (productsubcategoryid)
    JOIN dmql_base.dimproductcategory       pc USING (productcategoryid)
    GROUP BY 1, 2, 3
)
SELECT *, RANK() OVER (PARTITION BY category ORDER BY total_txns DESC)
FROM product_stats
ORDER BY total_txns DESC;
```

```
Sort  (cost=1704.98..1718.48 rows=5400 width=68) (actual time=7.115..7.121 rows=27 loops=1)
  Sort Key: product_stats.total_txns DESC
  Sort Method: quicksort  Memory: 26kB
  ->  WindowAgg  (cost=1262.24..1370.22 rows=5400 width=68) (actual time=7.086..7.109 rows=27 loops=1)
        ->  Sort  (cost=1262.22..1275.72 rows=5400 width=60) (actual time=7.080..7.085 rows=27 loops=1)
              Sort Key: product_stats.category, product_stats.total_txns DESC
              Sort Method: quicksort  Memory: 26kB
              ->  Subquery Scan on product_stats  (cost=873.45..927.45 rows=5400 width=60) (actual time=7.002..7.047 rows=27 loops=1)
                    ->  HashAggregate  (cost=873.45..927.45 rows=5400 width=60) (actual time=7.001..7.043 rows=27 loops=1)
                          Group Key: pc."ProductCategoryName", p."ProductName"
```

**Observed execution time (before):** `7.121 ms`

**Observations:**
- PostgreSQL uses a **HashAggregate** for the GROUP BY - efficient for this data size
- **QuickSort** used for both ORDER BY and window function partitioning
- No indexes exist on FK columns; planner uses sequential scans

---

## 3. Indexes Applied

```sql
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

```

---

## 4. After Indexing



```
Sort  (cost=1704.98..1718.48 rows=5400 width=68) (actual time=7.177..7.183 rows=27 loops=1)
  Sort Key: product_stats.total_txns DESC
  Sort Method: quicksort  Memory: 26kB
  ->  WindowAgg  (cost=1262.24..1370.22 rows=5400 width=68) (actual time=7.146..7.170 rows=27 loops=1)
        ->  Sort  (cost=1262.22..1275.72 rows=5400 width=60) (actual time=7.139..7.145 rows=27 loops=1)
              Sort Key: product_stats.category, product_stats.total_txns DESC
              Sort Method: quicksort  Memory: 26kB
              ->  Subquery Scan on product_stats  (cost=873.45..927.45 rows=5400 width=60) (actual time=7.078..7.119 rows=27 loops=1)
                    ->  HashAggregate  (cost=873.45..927.45 rows=5400 width=60) (actual time=7.076..7.114 rows=27 loops=1)
                          Group Key: pc."ProductCategoryName", p."ProductName"```

**Observed execution time (after):** `7.183 ms`

---

## 5. Results Summary

| Metric                  | Before | After |
|-------------------------|--------|-------|
| Execution time          | 7.121 ms  | 7.183 ms |
| Query plan              | Hash + Seq | Hash + Seq |
| Indexes used            | None       | None*      |

---

## 6. Analysis & Findings

The query execution plan remained identical before and after index creation.
This is **expected and correct behavior**  not a failure of the indexing strategy.

PostgreSQL's query planner performs cost-based optimization. For small datasets
(27 distinct product-category combinations aggregated from a few thousand rows),
the planner correctly determines that a **sequential scan is more efficient**
than an index lookup. Reading the entire small table in one pass has lower
overhead than repeatedly jumping to index entries.

**When these indexes WILL have impact:**
The indexes on `"ProductID"`, `"AccountID"`, `"Status"`, and `"TransactionDate"`
are designed for production-scale workloads. Their benefit becomes measurable when:
- The `FactTransaction` table grows beyond ~100,000 rows
- Queries filter on `"Status"` or `"TransactionDate"` with high selectivity
- JOIN operations link to large dimension tables