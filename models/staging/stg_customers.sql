-- stg_customers.sql
-- Cleans DimCustomer records

with source as (
    select * from {{ source('dmql_base', 'DimCustomer') }}
),

cleaned as (
    select
        "CustomerID"                        as customer_id,
        trim("FullName")                    as full_name,
        "DOB"                               as date_of_birth,
        trim("Gender")                      as gender,
        trim("Region")                      as region,
        lower(trim("Email"))                as email,
        upper(trim("Status"))               as status,
        "JoinDate"                          as join_date,
        ingested_at
    from source
    where "CustomerID" is not null
)

select * from cleaned