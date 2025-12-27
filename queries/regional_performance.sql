SELECT
    region,
    product_id,
    total_sales
FROM {DATABASE}.top_products
WHERE rank = 1;