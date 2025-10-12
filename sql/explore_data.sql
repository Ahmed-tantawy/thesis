-- 1. Date range of orders
SELECT 
    MIN(order_purchase_timestamp) as first_order,
    MAX(order_purchase_timestamp) as last_order,
    MAX(order_purchase_timestamp)::date - MIN(order_purchase_timestamp)::date as days_span
FROM orders;

-- 2. Order status distribution
SELECT 
    order_status,
    COUNT(*) as count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 2) as percentage
FROM orders
GROUP BY order_status
ORDER BY count DESC;

-- 3. Top product categories
SELECT 
    p.product_category_name,
    COUNT(DISTINCT oi.order_id) as orders,
    SUM(oi.price) as total_revenue
FROM order_items oi
JOIN products p ON oi.product_id = p.product_id
WHERE p.product_category_name IS NOT NULL
GROUP BY p.product_category_name
ORDER BY total_revenue DESC
LIMIT 10;

-- 4. Average order value and items per order
SELECT 
    COUNT(DISTINCT order_id) as total_orders,
    ROUND(AVG(items_per_order), 2) as avg_items_per_order,
    ROUND(AVG(order_value), 2) as avg_order_value
FROM (
    SELECT 
        order_id,
        COUNT(*) as items_per_order,
        SUM(price + freight_value) as order_value
    FROM order_items
    GROUP BY order_id
) subquery;

-- 5. Peak ordering hours (if data has time)
SELECT 
    EXTRACT(HOUR FROM order_purchase_timestamp) as hour,
    COUNT(*) as orders
FROM orders
WHERE order_purchase_timestamp IS NOT NULL
GROUP BY hour
ORDER BY hour;

\q