-- ============================================================================
-- Data Import Script
-- Import Olist CSV files into PostgreSQL
-- ============================================================================

\timing on

-- Set client encoding
SET client_encoding = 'UTF8';

\echo '============================================='
\echo 'Starting Olist Data Import'
\echo '============================================='

-- ============================================================================
-- IMPORT REFERENCE TABLES FIRST (no dependencies)
-- ============================================================================

\echo ''
\echo 'Importing product_category_translation...'
\COPY product_category_translation FROM 'data/raw/product_category_name_translation.csv' WITH (FORMAT csv, HEADER true, DELIMITER ',', NULL '');

\echo 'Importing sellers...'
\COPY sellers(seller_id, seller_zip_code_prefix, seller_city, seller_state) FROM 'data/raw/olist_sellers_dataset.csv' WITH (FORMAT csv, HEADER true, DELIMITER ',', NULL '');

\echo 'Importing products...'
\COPY products(product_id, product_category_name, product_name_length, product_description_length, product_photos_qty, product_weight_g, product_length_cm, product_height_cm, product_width_cm) FROM 'data/raw/olist_products_dataset.csv' WITH (FORMAT csv, HEADER true, DELIMITER ',', NULL '');

\echo 'Importing geolocation (with duplicate handling)...'
CREATE TEMP TABLE geolocation_temp (LIKE geolocation);
\COPY geolocation_temp FROM 'data/raw/olist_geolocation_dataset.csv' WITH (FORMAT csv, HEADER true, DELIMITER ',', NULL '');
INSERT INTO geolocation 
SELECT DISTINCT ON (geolocation_zip_code_prefix, geolocation_lat, geolocation_lng) *
FROM geolocation_temp
ON CONFLICT DO NOTHING;
DROP TABLE geolocation_temp;

-- ============================================================================
-- IMPORT CORE TABLES
-- ============================================================================

\echo ''
\echo 'Importing customers...'
\COPY customers(customer_id, customer_unique_id, customer_zip_code_prefix, customer_city, customer_state) FROM 'data/raw/olist_customers_dataset.csv' WITH (FORMAT csv, HEADER true, DELIMITER ',', NULL '');

\echo 'Importing orders...'
\COPY orders(order_id, customer_id, order_status, order_purchase_timestamp, order_approved_at, order_delivered_carrier_date, order_delivered_customer_date, order_estimated_delivery_date) FROM 'data/raw/olist_orders_dataset.csv' WITH (FORMAT csv, HEADER true, DELIMITER ',', NULL '');

-- ============================================================================
-- IMPORT DEPENDENT TABLES
-- ============================================================================

\echo ''
\echo 'Importing order_items...'
\COPY order_items(order_id, order_item_id, product_id, seller_id, shipping_limit_date, price, freight_value) FROM 'data/raw/olist_order_items_dataset.csv' WITH (FORMAT csv, HEADER true, DELIMITER ',', NULL '');

\echo 'Importing order_payments...'
\COPY order_payments(order_id, payment_sequential, payment_type, payment_installments, payment_value) FROM 'data/raw/olist_order_payments_dataset.csv' WITH (FORMAT csv, HEADER true, DELIMITER ',', NULL '');
\echo 'Importing order_reviews (with duplicate handling)...'
CREATE TEMP TABLE order_reviews_temp (LIKE order_reviews INCLUDING ALL);
\COPY order_reviews_temp(review_id, order_id, review_score, review_comment_title, review_comment_message, review_creation_date, review_answer_timestamp) FROM 'data/raw/olist_order_reviews_dataset.csv' WITH (FORMAT csv, HEADER true, DELIMITER ',', NULL '');
INSERT INTO order_reviews 
SELECT DISTINCT ON (review_id) *
FROM order_reviews_temp
ON CONFLICT DO NOTHING;
DROP TABLE order_reviews_temp;
-- ============================================================================
-- VERIFICATION
-- ============================================================================

\echo ''
\echo '============================================='
\echo 'IMPORT SUMMARY'
\echo '============================================='

SELECT 'customers' as table_name, COUNT(*) as row_count FROM customers
UNION ALL
SELECT 'products', COUNT(*) FROM products
UNION ALL
SELECT 'sellers', COUNT(*) FROM sellers
UNION ALL
SELECT 'orders', COUNT(*) FROM orders
UNION ALL
SELECT 'order_items', COUNT(*) FROM order_items
UNION ALL
SELECT 'order_payments', COUNT(*) FROM order_payments
UNION ALL
SELECT 'order_reviews', COUNT(*) FROM order_reviews
UNION ALL
SELECT 'geolocation', COUNT(*) FROM geolocation
UNION ALL
SELECT 'category_translation', COUNT(*) FROM product_category_translation
ORDER BY table_name;

\echo ''
\echo 'Database size:'
SELECT pg_size_pretty(pg_database_size('ecommerce_olist'));

\echo ''
\echo 'Table sizes:'
SELECT 
    tablename,
    pg_size_pretty(pg_total_relation_size('public.'||tablename)) AS size,
    pg_size_pretty(pg_relation_size('public.'||tablename)) AS data_size,
    pg_size_pretty(pg_total_relation_size('public.'||tablename) - pg_relation_size('public.'||tablename)) AS index_size
FROM pg_tables
WHERE schemaname = 'public'
ORDER BY pg_total_relation_size('public.'||tablename) DESC;

\echo ''
\echo '============================================='
\echo 'Import Complete!'
\echo '============================================='