-- ============================================================================
-- PostgreSQL Configuration Optimization
-- Optimized for: Mac M2, 16GB RAM, SSD, 8 cores
-- Database: ecommerce_olist
-- ============================================================================

-- Note: These settings require restart to take effect
-- Apply via postgresql.conf or ALTER SYSTEM

\echo '============================================='
\echo 'PostgreSQL Configuration Optimization'
\echo 'Target: E-commerce workload on Mac M2'
\echo '============================================='
\echo ''

-- ============================================================================
-- MEMORY SETTINGS
-- ============================================================================

\echo 'Applying memory optimizations...'

-- Shared memory for caching data
ALTER SYSTEM SET shared_buffers = '4GB';

-- Memory for complex sorts and joins
ALTER SYSTEM SET work_mem = '64MB';

-- Planner estimate of cache available
ALTER SYSTEM SET effective_cache_size = '12GB';

-- Memory for maintenance operations (VACUUM, CREATE INDEX)
ALTER SYSTEM SET maintenance_work_mem = '1GB';

\echo 'Memory settings configured.'
\echo ''

-- ============================================================================
-- QUERY PLANNER SETTINGS (SSD Optimized)
-- ============================================================================

\echo 'Configuring query planner for SSD...'

-- Cost of random page access (lower for SSD)
ALTER SYSTEM SET random_page_cost = 1.1;

-- Enable bitmap scans
ALTER SYSTEM SET enable_bitmapscan = on;

-- Parallelism for SSD
ALTER SYSTEM SET effective_io_concurrency = 200;

\echo 'Query planner configured for SSD.'
\echo ''

-- ============================================================================
-- PARALLELISM SETTINGS (8-core M2)
-- ============================================================================

\echo 'Configuring parallelism for 8-core CPU...'

-- Maximum background worker processes
ALTER SYSTEM SET max_worker_processes = 8;

-- Parallel workers per query
ALTER SYSTEM SET max_parallel_workers_per_gather = 4;

-- Total parallel workers
ALTER SYSTEM SET max_parallel_workers = 8;

-- Minimum table size for parallel scan (default 8MB)
ALTER SYSTEM SET min_parallel_table_scan_size = '8MB';

\echo 'Parallelism configured.'
\echo ''

-- ============================================================================
-- CHECKPOINT AND WAL SETTINGS
-- ============================================================================

\echo 'Optimizing checkpoint and WAL settings...'

-- Checkpoint frequency (increase for performance)
ALTER SYSTEM SET checkpoint_completion_target = 0.9;

-- WAL buffers
ALTER SYSTEM SET wal_buffers = '16MB';

\echo 'Checkpoint settings configured.'
\echo ''

-- ============================================================================
-- AUTOVACUUM TUNING
-- ============================================================================

\echo 'Configuring autovacuum...'

-- Make autovacuum more aggressive for e-commerce workload
ALTER SYSTEM SET autovacuum_max_workers = 4;
ALTER SYSTEM SET autovacuum_naptime = '30s';

\echo 'Autovacuum configured.'
\echo ''

-- ============================================================================
-- VERIFICATION
-- ============================================================================

\echo '============================================='
\echo 'Configuration changes applied!'
\echo 'IMPORTANT: Restart PostgreSQL for changes to take effect'
\echo '============================================='
\echo ''

\echo 'New configuration:'
SELECT name, setting, unit, context 
FROM pg_settings 
WHERE name IN (
    'shared_buffers',
    'effective_cache_size',
    'work_mem',
    'maintenance_work_mem',
    'random_page_cost',
    'effective_io_concurrency',
    'max_worker_processes',
    'max_parallel_workers_per_gather'
)
ORDER BY name;