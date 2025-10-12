-- ============================================================================
-- Baseline Performance Test with Load Simulation
-- Tests catalog queries under repeated load to warm up cache
-- ============================================================================

\timing on

\echo '============================================='
\echo 'Baseline Performance Test - Catalog Queries'
\echo 'Testing with cache warm-up'
\echo '============================================='
\echo ''

-- Don't reset stats - we want to see cache building up
-- SELECT pg_stat_reset();

\echo 'Phase 1: Cold start (first run, cache empty)'
\echo '---------------------------------------------'

\echo 'Query 1: Category lookup (cold)'
SELECT COUNT(*) 
FROM products 
WHERE product_category_name = 'beleza_saude';

\echo ''
\echo 'Query 2: Multi-category search (cold)'
SELECT COUNT(*)
FROM products
WHERE product_category_name IN ('beleza_saude', 'relogios_presentes', 'esporte_lazer')
    AND product_weight_g BETWEEN 100 AND 5000;

\echo ''
\echo 'Query 3: Heavy aggregation (cold)'
SELECT 
    product_category_name,
    COUNT(*) as products,
    ROUND(AVG(product_weight_g), 2) as avg_weight
FROM products
WHERE product_category_name IS NOT NULL
    AND product_weight_g IS NOT NULL
GROUP BY product_category_name
ORDER BY products DESC
LIMIT 10;

\echo ''
\echo '============================================='
\echo 'Phase 2: Warm cache (repeat 10 times)'
\echo '============================================='

-- Repeat queries to warm up cache
\echo 'Running queries 10 times to warm cache...'

SELECT COUNT(*) FROM products WHERE product_category_name = 'beleza_saude';
SELECT COUNT(*) FROM products WHERE product_category_name = 'beleza_saude';
SELECT COUNT(*) FROM products WHERE product_category_name = 'beleza_saude';
SELECT COUNT(*) FROM products WHERE product_category_name = 'beleza_saude';
SELECT COUNT(*) FROM products WHERE product_category_name = 'beleza_saude';
SELECT COUNT(*) FROM products WHERE product_category_name = 'beleza_saude';
SELECT COUNT(*) FROM products WHERE product_category_name = 'beleza_saude';
SELECT COUNT(*) FROM products WHERE product_category_name = 'beleza_saude';
SELECT COUNT(*) FROM products WHERE product_category_name = 'beleza_saude';
SELECT COUNT(*) FROM products WHERE product_category_name = 'beleza_saude';

\echo ''
\echo 'Query 1: Category lookup (warm cache)'
SELECT COUNT(*) 
FROM products 
WHERE product_category_name = 'beleza_saude';

\echo ''
\echo '============================================='
\echo 'Phase 3: Cache Statistics'
\echo '============================================='

-- Table-level cache statistics
SELECT 
    relname as table_name,
    heap_blks_read as disk_reads,
    heap_blks_hit as cache_hits,
    CASE 
        WHEN (heap_blks_hit + heap_blks_read) = 0 THEN 0
        ELSE ROUND(100.0 * heap_blks_hit / (heap_blks_hit + heap_blks_read), 2)
    END as cache_hit_ratio_pct
FROM pg_statio_user_tables
WHERE schemaname = 'public'
ORDER BY heap_blks_read DESC;

\echo ''
\echo '--- Index Usage Statistics ---'
SELECT 
    schemaname,
    relname as tablename,    
    indexrelname as indexname,
    idx_scan as index_scans,
    idx_tup_read as tuples_read,
    idx_tup_fetch as tuples_fetched
FROM pg_stat_user_indexes
WHERE schemaname = 'public'
    AND idx_scan > 0
ORDER BY idx_scan DESC
LIMIT 10;

\echo ''
\echo '--- Database-wide Cache Hit Ratio ---'
SELECT 
    SUM(heap_blks_read) as total_disk_reads,
    SUM(heap_blks_hit) as total_cache_hits,
    CASE 
        WHEN SUM(heap_blks_hit + heap_blks_read) = 0 THEN 0
        ELSE ROUND(100.0 * SUM(heap_blks_hit) / SUM(heap_blks_hit + heap_blks_read), 2)
    END as overall_cache_hit_ratio_pct
FROM pg_statio_user_tables
WHERE schemaname = 'public';

\echo ''
\echo '============================================='
\echo 'Phase 4: Query Plan Analysis'
\echo '============================================='

\echo '--- Explain Plan for Category Lookup ---'
EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)
SELECT product_id, product_category_name
FROM products
WHERE product_category_name = 'beleza_saude'
LIMIT 50;

\echo ''
\echo 'Test completed!'