-- stg_products.sql
-- Joins DimProduct → DimProductSubCategory → DimProductCategory into one flat staging model

with products as (
    select * from {{ source('dmql_base', 'DimProduct') }}
),

subcategories as (
    select * from {{ source('dmql_base', 'DimProductSubCategory') }}
),

categories as (
    select * from {{ source('dmql_base', 'DimProductCategory') }}
),

joined as (
    select
        p."ProductID"                           as product_id,
        trim(p."ProductName")                   as product_name,
        s."ProductSubCategoryID"                as sub_category_id,
        trim(s."ProductSubCategoryName")        as sub_category_name,
        c."ProductCategoryID"                   as category_id,
        trim(c."ProductCategoryName")           as category_name
    from products p
    left join subcategories s on p."ProductSubcategoryID" = s."ProductSubCategoryID"
    left join categories c on s."ProductCategoryID" = c."ProductCategoryID"
    where p."ProductID" is not null
)

select * from joined