-- stg_accounts.sql
-- Cleans DimAccount records

with source as (
    select * from {{ source('dmql_base', 'DimAccount') }}
),

cleaned as (
    select
        "AccountID"                         as account_id,
        "CustomerID"                        as customer_id,
        trim("AccountType")                 as account_type,
        "OpenDate"                          as open_date,
        "ClosedDate"                        as closed_date,
        upper(trim("Status"))               as status,
        "RegistrationID"                    as registration_id,
        "Balance"::decimal(15, 2)           as balance,
        ingested_at
    from source
    where "AccountID" is not null
)

select * from cleaned