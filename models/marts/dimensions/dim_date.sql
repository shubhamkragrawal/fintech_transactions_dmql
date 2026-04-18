-- dim_date.sql
-- Date dimension generated from the range of transaction dates

with date_spine as (
    select generate_series(
        (select min(transaction_date) from {{ ref('stg_transactions') }}),
        (select max(transaction_date) from {{ ref('stg_transactions') }}),
        interval '1 day'
    )::date as full_date
)

select
    full_date                                           as date_key,
    full_date,
    date_part('year',  full_date)::int                  as year,
    date_part('month', full_date)::int                  as month,
    to_char(full_date, 'Month')                         as month_name,
    date_part('day',   full_date)::int                  as day,
    date_part('dow',   full_date)::int                  as day_of_week,   -- 0=Sun
    to_char(full_date, 'Day')                           as day_name,
    date_part('quarter', full_date)::int                as quarter,
    'Q' || date_part('quarter', full_date)::int         as quarter_label,
    date_part('week', full_date)::int                   as week_of_year,
    case
        when date_part('dow', full_date) in (0, 6) then true
        else false
    end                                                 as is_weekend
from date_spine
