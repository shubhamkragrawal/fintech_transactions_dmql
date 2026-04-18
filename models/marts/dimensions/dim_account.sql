-- dim_account.sql
-- Account dimension enriched with customer info

with accounts as (
    select * from {{ ref('stg_accounts') }}
),

customers as (
    select customer_id, full_name, region, status as customer_status
    from {{ ref('dim_customer') }}
)

select
    a.account_id,
    a.customer_id,
    c.full_name          as customer_name,
    c.region             as customer_region,
    a.account_type,
    a.open_date,
    a.closed_date,
    a.status             as account_status,
    c.customer_status,
    a.registration_id,
    a.balance,
    -- Derived: account age in days
    current_date - a.open_date as account_age_days
from accounts a
left join customers c using (customer_id)
