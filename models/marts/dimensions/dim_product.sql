-- dim_product.sql
-- Flattened product dimension with category hierarchy

with products as (
    select * from {{ ref('stg_products') }}
)

select
    product_id,
    product_name,
    sub_category_id,
    sub_category_name,
    category_id,
    category_name,
    -- Derived: full hierarchy label
    category_name || ' > ' || sub_category_name || ' > ' || product_name as product_hierarchy
from products
