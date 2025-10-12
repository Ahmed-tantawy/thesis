-- ============================================================================
-- Write Performance Testing
-- Measure INSERT/UPDATE performance with various index configurations
-- ============================================================================

\timing on

\echo '============================================='
\echo 'Write Performance Testing'
\echo 'Testing INSERT/UPDATE overhead with indexes'
\echo '============================================='
\echo ''

-- ============================================================================
-- PHASE 1: Baseline Write Performance (With All Indexes)
-- ============================================================================

\echo 'Phase 1: Current State (All Indexes Present)'
\echo '---------------------------------------------'

-- Count current indexes
SELECT COUNT(*) as total_indexes 
FROM pg_indexes 
WHERE schemaname = 'public';

\echo ''
\echo 'Test 1.1: Single INSERT into orders'

-- Prepare test data
DO $$
DECLARE
    v_customer_id text;
    v_order_id text;
    v_start_time timestamp;
    v_end_time timestamp;
    v_duration interval;
BEGIN
    -- Get a random customer
    SELECT customer_id INTO v_customer_id FROM customers LIMIT 1;
    
    -- Generate unique order ID
    v_order_id := 'test_order_' || extract(epoch from now())::text;
    
    -- Time the INSERT
    v_start_time := clock_timestamp();
    
    INSERT INTO orders (
        order_id, 
        customer_id, 
        order_status, 
        order_purchase_timestamp,
        order_approved_at,
        order_delivered_carrier_date,
        order_delivered_customer_date,
        order_estimated_delivery_date
    ) VALUES (
        v_order_id,
        v_customer_id,
        'processing',
        now(),
        now(),
        now() + interval '1 day',
        now() + interval '3 days',
        now() + interval '5 days'
    );
    
    v_end_time := clock_timestamp();
    v_duration := v_end_time - v_start_time;
    
    RAISE NOTICE 'Single INSERT duration: % ms', extract(milliseconds from v_duration);
    
    -- Cleanup
    DELETE FROM orders WHERE order_id = v_order_id;
END $$;

\echo ''
\echo 'Test 1.2: Batch INSERT (100 orders)'

-- Batch insert test
EXPLAIN ANALYZE
INSERT INTO orders (order_id, customer_id, order_status, order_purchase_timestamp)
SELECT 
    'batch_test_' || generate_series || '_' || extract(epoch from now())::text,
    customer_id,
    'processing',
    now()
FROM (
    SELECT customer_id FROM customers ORDER BY random() LIMIT 10
) c
CROSS JOIN generate_series(1, 10);

-- Cleanup
DELETE FROM orders WHERE order_id LIKE 'batch_test_%';

\echo ''
\echo 'Test 1.3: UPDATE performance'

EXPLAIN ANALYZE
UPDATE orders 
SET order_status = 'shipped'
WHERE order_id IN (
    SELECT order_id FROM orders
    WHERE order_status = 'processing'
      AND order_purchase_timestamp >= '2018-10-01'
    LIMIT 100
);

-- Rollback updates
UPDATE orders 
SET order_status = 'processing'
WHERE order_status = 'shipped'
  AND order_purchase_timestamp >= '2018-10-01';

\echo ''

-- ============================================================================
-- PHASE 2: Test Write Performance WITHOUT Non-Essential Indexes
-- ============================================================================

\echo '============================================='
\echo 'Phase 2: Temporarily Drop Optional Indexes'
\echo '============================================='

-- Drop covering and composite indexes (keep only essential ones)
\echo 'Dropping optional indexes...'

DROP INDEX IF EXISTS idx_orders_customer_covering;
DROP INDEX IF EXISTS idx_orders_customer_status;
DROP INDEX IF EXISTS idx_orders_delivered_date;
DROP INDEX IF EXISTS idx_order_items_product_price;

\echo 'Optional indexes dropped.'
\echo ''

\echo 'Test 2.1: Single INSERT without optional indexes'

DO $$
DECLARE
    v_customer_id text;
    v_order_id text;
    v_start_time timestamp;
    v_end_time timestamp;
    v_duration interval;
BEGIN
    SELECT customer_id INTO v_customer_id FROM customers LIMIT 1;
    v_order_id := 'test_order_noindex_' || extract(epoch from now())::text;
    
    v_start_time := clock_timestamp();
    
    INSERT INTO orders (
        order_id, 
        customer_id, 
        order_status, 
        order_purchase_timestamp,
        order_approved_at,
        order_delivered_carrier_date,
        order_delivered_customer_date,
        order_estimated_delivery_date
    ) VALUES (
        v_order_id,
        v_customer_id,
        'processing',
        now(),
        now(),
        now() + interval '1 day',
        now() + interval '3 days',
        now() + interval '5 days'
    );
    
    v_end_time := clock_timestamp();
    v_duration := v_end_time - v_start_time;
    
    RAISE NOTICE 'Single INSERT (fewer indexes) duration: % ms', extract(milliseconds from v_duration);
    
    DELETE FROM orders WHERE order_id = v_order_id;
END $$;

\echo ''
\echo 'Test 2.2: Batch INSERT without optional indexes'

EXPLAIN ANALYZE
INSERT INTO orders (order_id, customer_id, order_status, order_purchase_timestamp)
SELECT 
    'batch_test_noindex_' || generate_series || '_' || extract(epoch from now())::text,
    customer_id,
    'processing',
    now()
FROM (
    SELECT customer_id FROM customers ORDER BY random() LIMIT 10
) c
CROSS JOIN generate_series(1, 10);

DELETE FROM orders WHERE order_id LIKE 'batch_test_noindex_%';

\echo ''

-- ============================================================================
-- PHASE 3: Restore Indexes and Compare
-- ============================================================================

\echo '============================================='
\echo 'Phase 3: Restore Indexes'
\echo '============================================='

\echo 'Recreating optimal indexes...'

CREATE INDEX idx_orders_customer_status ON orders(customer_id, order_status);
CREATE INDEX idx_orders_delivered_date ON orders(order_purchase_timestamp) WHERE order_status = 'delivered';
CREATE INDEX idx_orders_customer_covering ON orders(customer_id) INCLUDE (order_status, order_purchase_timestamp);
CREATE INDEX idx_order_items_product_price ON order_items(product_id, price);

ANALYZE orders;
ANALYZE order_items;

\echo 'Indexes restored and analyzed.'
\echo ''

-- ============================================================================
-- PHASE 4: Summary and Analysis
-- ============================================================================

\echo '============================================='
\echo 'Write Performance Summary'
\echo '============================================='

\echo 'Current index configuration:'
SELECT 
    relname as tablename,
    COUNT(*) as index_count,
    pg_size_pretty(SUM(pg_relation_size(indexrelid))) as total_index_size
FROM pg_stat_user_indexes
WHERE schemaname = 'public'
  AND relname IN ('orders', 'order_items')
GROUP BY relname
ORDER BY relname;

\echo ''
\echo 'Key Findings:'
\echo '1. Compare Phase 1 vs Phase 2 INSERT times'
\echo '2. Index overhead = (Time with indexes - Time without) / Time without'
\echo '3. Evaluate if read performance gains justify write overhead'
\echo ''
\echo 'Test completed!'