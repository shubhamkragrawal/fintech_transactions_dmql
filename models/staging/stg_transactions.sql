-- stg_transactions.sql
-- Cleans and standardizes raw FactTransaction records

with source as (
    select * from {{ source('dmql_base', 'FactTransaction') }}
),

cleaned as (
    select
        "TransactionID"                             as transaction_id,
        "AccountID"                                 as account_id,
        "ProductID"                                 as product_id,
        cast("TransactionDate" as date)             as transaction_date,
        "TransactionAmount"::decimal(15, 2)         as transaction_amount,
        upper(trim("TransactionType"))              as transaction_type,
        upper(trim("TransactionChannel"))           as transaction_channel,
        upper(trim("Status"))                       as status,
        ingested_at
    from source
    where "TransactionID" is not null
      and "AccountID" is not null
      and "TransactionAmount" is not null
)

select * from cleaned