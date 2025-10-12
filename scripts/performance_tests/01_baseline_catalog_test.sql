-- ============================================================================
-- Baseline Performance Test: Product Catalog Browsing
-- Scenario 1: Read-Heavy Workload
-- ============================================================================

\timing on

-- Enable query statistics
SET pg_stat_statements.track = 'all';

\echo '============================================='
\echo 'Scenario 1: Product Catalog Browsing'
\echo 'Testing read-heavy queries on products table'
\echo '============================================='
\echo ''

-- Clear cache statistics before testing
SELECT pg_stat_reset();

\echo 'Test 1.1: Simple product lookup by category'
SELECT 
    product_id,
    product_category_name
FROM products
WHERE product_category_name = 'beleza_saude'
LIMIT 50;

\echo ''
\echo 'Test 1.2: Product search with multiple filters'
SELECT 
    product_id,
    product_category_name,
    product_weight_g,
    (product_length_cm * product_height_cm * product_width_cm) as volume_cm3
FROM products
WHERE product_category_name IN ('beleza_saude', 'relogios_presentes', 'esporte_lazer')
    AND product_weight_g BETWEEN 100 AND 5000
ORDER BY product_weight_g
LIMIT 100;

\echo ''
\echo 'Test 1.3: Products with dimensions (NULL handling)'
SELECT 
    COUNT(*) as total_products,
    COUNT(product_weight_g) as products_with_weight,
    COUNT(product_length_cm) as products_with_dimensions,
    ROUND(AVG(product_weight_g), 2) as avg_weight
FROM products
WHERE product_category_name = 'beleza_saude';

\echo ''
\echo 'Test 1.4: Top 10 heaviest products per category'
SELECT 
    product_category_name,
    COUNT(*) as products,
    MAX(product_weight_g) as heaviest_product_g,
    ROUND(AVG(product_weight_g), 2) as avg_weight_g
FROM products
WHERE product_category_name IS NOT NULL
    AND product_weight_g IS NOT NULL
GROUP BY product_category_name
ORDER BY heaviest_product_g DESC
LIMIT 10;

\echo ''
\echo '============================================='
\echo 'Cache Hit Ratio Analysis'
\echo '============================================='

SELECT 
    'Heap Blocks Read' as metric,
    SUM(heap_blks_read) as value,
    pg_size_pretty(SUM(heap_blks_read) * 8192) as size_read
FROM pg_statio_user_tables
WHERE schemaname = 'public'
UNION ALL
SELECT 
    'Heap Blocks Hit (cache)',
    SUM(heap_blks_hit),
    pg_size_pretty(SUM(heap_blks_hit) * 8192)
FROM pg_statio_user_tables
WHERE schemaname = 'public';

SELECT 
    'Cache Hit Ratio (%)',
    ROUND(
        SUM(heap_blks_hit) * 100.0 / NULLIF(SUM(heap_blks_hit + heap_blks_read), 0),
        2
    )
FROM pg_statio_user_tables
WHERE schemaname = 'public';

\echo ''
\echo 'Test completed!'