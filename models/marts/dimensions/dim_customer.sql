-- dim_customer.sql
-- Final customer dimension for the Star Schema

with customers as (
    select * from {{ ref('stg_customers') }}
)

select
    customer_id,
    full_name,
    date_of_birth,
    gender,
    region,
    email,
    status,
    join_date,
    -- Derived: customer age bucket
    case
        when date_of_birth is null then 'Unknown'
        when date_part('year', age(to_date(date_of_birth, 'DD/MM/YYYY'))) < 25 then '18-24'
        when date_part('year', age(to_date(date_of_birth, 'DD/MM/YYYY'))) < 35 then '25-34'
        when date_part('year', age(to_date(date_of_birth, 'DD/MM/YYYY'))) < 50 then '35-49'
        when date_part('year', age(to_date(date_of_birth, 'DD/MM/YYYY'))) < 65 then '50-64'
        else '65+'
    end as age_bucket
from customers