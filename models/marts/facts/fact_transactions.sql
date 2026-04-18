-- fact_transactions.sql
-- Core fact table joining all dimensions into the Star Schema

with transactions as (
    select * from {{ ref('stg_transactions') }}
),

accounts as (
    select account_id, customer_id, account_type, account_status, customer_region
    from {{ ref('dim_account') }}
),

products as (
    select product_id, product_name, sub_category_name, category_name
    from {{ ref('dim_product') }}
),

dates as (
    select date_key, year, month, quarter, quarter_label, is_weekend
    from {{ ref('dim_date') }}
)

select
    -- Keys
    t.transaction_id,
    t.account_id,
    a.customer_id,
    t.product_id,
    t.transaction_date                  as date_key,

    -- Descriptors (denormalized for BI performance)
    t.transaction_type,
    t.transaction_channel,
    t.status                            as transaction_status,
    a.account_type,
    a.account_status,
    a.customer_region,
    p.product_name,
    p.sub_category_name,
    p.category_name,
    d.year,
    d.month,
    d.quarter,
    d.quarter_label,
    d.is_weekend,

    -- Measures
    t.transaction_amount,

    -- Derived flags
    case when t.status = 'FAILED'    then 1 else 0 end as is_failed,
    case when t.status = 'COMPLETED' then 1 else 0 end as is_completed,
    case when d.is_weekend = true    then 1 else 0 end as is_weekend_txn

from transactions t
left join accounts a using (account_id)
left join products p using (product_id)
left join dates d on t.transaction_date = d.date_key
