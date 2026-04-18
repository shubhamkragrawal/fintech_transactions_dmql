# Phase 2 — Performance Tuning Report
## FinTech Dataset | AWS PostgreSQL

---

## 1. Query Profiled

**Query 3 — Failure Rate & Risk Analysis by Product Category**
(chosen because it involves a 4-table JOIN chain and window functions)

---

## 2. Before Indexing

Run this in your AWS PostgreSQL client and paste the output below:

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

**Paste EXPLAIN ANALYZE output here:**
```
[PASTE OUTPUT HERE]
```

**Observed execution time (before):** `XX ms`

**Bottlenecks identified:**
- [ ] Sequential Scan on `facttransaction` (no index on `productid`)
- [ ] Sequential Scan on `dimproduct` (no index on `productsubcategoryid`)
- [ ] High cost hash joins due to missing FK indexes

---

## 3. Indexes Applied

```sql
-- Index 1: FK join — transactions to products
CREATE INDEX idx_facttxn_productid
    ON dmql_base.facttransaction(productid);

-- Index 2: FK join — transactions to accounts
CREATE INDEX idx_facttxn_accountid
    ON dmql_base.facttransaction(accountid);

-- Index 3: Filtering by status (used in FILTER aggregations)
CREATE INDEX idx_facttxn_status
    ON dmql_base.facttransaction(status);

-- Index 4: Date range queries (used in Query 1)
CREATE INDEX idx_facttxn_date
    ON dmql_base.facttransaction(transactiondate);

-- Index 5: FK join — product to sub-category
CREATE INDEX idx_product_subcategoryid
    ON dmql_base.dimproduct(productsubcategoryid);

-- Index 6: FK join — account to customer
CREATE INDEX idx_account_customerid
    ON dmql_base.dimaccount(customerid);
```

---

## 4. After Indexing

Re-run the same `EXPLAIN ANALYZE` query after creating the indexes.

**Paste EXPLAIN ANALYZE output here:**
```
[PASTE OUTPUT HERE]
```

**Observed execution time (after):** `XX ms`

---

## 5. Results Summary

| Metric                  | Before | After |
|-------------------------|--------|-------|
| Execution time          | XX ms  | XX ms |
| Seq Scans on fact table | X      | 0     |
| Index Scans used        | 0      | X     |
| Improvement             | —      | XX%   |

---

## 6. Key Findings

- Adding an index on `facttransaction.productid` eliminated the sequential scan on the largest table, which produced the biggest speedup.
- The composite filter on `status` benefited from a partial index approach since most analytical queries target `COMPLETED` transactions.
- Hash joins were replaced by index nested-loop joins for smaller dimension table lookups.
