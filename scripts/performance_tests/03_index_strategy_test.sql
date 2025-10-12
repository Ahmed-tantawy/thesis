-- ============================================================================
-- Index Strategy Optimization Testing
-- Tests: Composite, Partial, and Covering indexes
-- ============================================================================

\timing on

\echo '============================================='
\echo 'Index Strategy Testing'
\echo 'Testing various index types and strategies'
\echo '============================================='
\echo ''

-- ============================================================================
-- PHASE 1: Baseline (Current Single-Column Indexes)
-- ============================================================================

\echo 'Phase 1: Baseline Performance with Current Indexes'
\echo '---------------------------------------------------'

-- Test 1: Date range query
\echo 'Test 1.1: Order date range query (using current index)'
EXPLAIN ANALYZE
SELECT order_id, customer_id, order_status, order_purchase_timestamp
FROM orders
WHERE order_purchase_timestamp >= '2018-01-01'
  AND order_purchase_timestamp < '2018-02-01';

\echo ''

-- Test 2: Customer + Status filter
\echo 'Test 1.2: Customer orders by status (using current indexes)'
EXPLAIN ANALYZE
SELECT order_id, order_status, order_purchase_timestamp
FROM orders
WHERE customer_id = (SELECT customer_id FROM customers LIMIT 1)
  AND order_status = 'delivered';

\echo ''

-- Test 3: Product category + price
\echo 'Test 1.3: Products by category and price range'
EXPLAIN ANALYZE
SELECT oi.order_id, oi.product_id, oi.price, p.product_category_name
FROM order_items oi
JOIN products p ON oi.product_id = p.product_id
WHERE p.product_category_name = 'beleza_saude'
  AND oi.price BETWEEN 20 AND 100;

\echo ''
\echo '============================================='
\echo 'Phase 2: Create Composite Indexes'
\echo '============================================='

-- Composite index: customer_id + status
\echo 'Creating composite index: idx_orders_customer_status...'
CREATE INDEX idx_orders_customer_status ON orders(customer_id, order_status);

-- Composite index: category + price
\echo 'Creating composite index: idx_order_items_product_price...'
CREATE INDEX idx_order_items_product_price ON order_items(product_id, price);

-- Analyze tables to update statistics
ANALYZE orders;
ANALYZE order_items;

\echo 'Composite indexes created and analyzed.'
\echo ''

-- ============================================================================
-- PHASE 3: Test with Composite Indexes
-- ============================================================================

\echo 'Phase 3: Performance with Composite Indexes'
\echo '--------------------------------------------'

\echo 'Test 3.1: Customer + Status (with composite index)'
EXPLAIN ANALYZE
SELECT order_id, order_status, order_purchase_timestamp
FROM orders
WHERE customer_id = (SELECT customer_id FROM customers LIMIT 1)
  AND order_status = 'delivered';

\echo ''

\echo 'Test 3.2: Product + Price range (with composite index)'
EXPLAIN ANALYZE
SELECT oi.order_id, oi.product_id, oi.price
FROM order_items oi
WHERE product_id IN (
    SELECT product_id FROM products 
    WHERE product_category_name = 'beleza_saude' 
    LIMIT 100
)
AND price BETWEEN 20 AND 100;

\echo ''

-- ============================================================================
-- PHASE 4: Create Partial Index (Filtered)
-- ============================================================================

\echo '============================================='
\echo 'Phase 4: Partial Index Testing'
\echo '============================================='

-- Partial index: only delivered orders
\echo 'Creating partial index for delivered orders...'
CREATE INDEX idx_orders_delivered_date 
ON orders(order_purchase_timestamp)
WHERE order_status = 'delivered';

ANALYZE orders;

\echo 'Test 4.1: Delivered orders by date (with partial index)'
EXPLAIN ANALYZE
SELECT order_id, customer_id, order_purchase_timestamp
FROM orders
WHERE order_status = 'delivered'
  AND order_purchase_timestamp >= '2018-08-01'
  AND order_purchase_timestamp < '2018-09-01';

\echo ''

-- ============================================================================
-- PHASE 5: Create Covering Index (Index-Only Scan)
-- ============================================================================

\echo '============================================='
\echo 'Phase 5: Covering Index Testing'
\echo '============================================='

-- Covering index: includes commonly selected columns
\echo 'Creating covering index with INCLUDE...'
CREATE INDEX idx_orders_customer_covering 
ON orders(customer_id) 
INCLUDE (order_status, order_purchase_timestamp);

ANALYZE orders;

\echo 'Test 5.1: Customer orders (covering index - no table lookup)'
EXPLAIN ANALYZE
SELECT customer_id, order_status, order_purchase_timestamp
FROM orders
WHERE customer_id = (SELECT customer_id FROM customers LIMIT 1);

\echo ''

-- ============================================================================
-- PHASE 6: Index Size and Usage Summary
-- ============================================================================

\echo '============================================='
\echo 'Index Summary'
\echo '============================================='

\echo 'New indexes created:'
SELECT 
    relname as tablename,
    indexrelname as indexname,
    pg_size_pretty(pg_relation_size(indexrelid)) as size
FROM pg_stat_user_indexes
WHERE schemaname = 'public'
  AND (indexrelname LIKE 'idx_orders_%'
   OR indexrelname LIKE 'idx_order_items_%')
ORDER BY relname, indexrelname;