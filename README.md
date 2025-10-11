# PostgreSQL E-commerce Performance Optimization

Bachelor Thesis Project - Czech University of Life Sciences Prague  
**Author:** Ahmed Abdelfattah Mohamed Ali  
**Date:** October 2025

## Project Description

Performance optimization of PostgreSQL for e-commerce applications using the Olist Brazilian E-commerce dataset. This thesis evaluates various configuration strategies, indexing techniques, and schema designs to improve database performance in realistic e-commerce workloads.

---

## Dataset

**Source:** [Olist Brazilian E-commerce Public Dataset](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce)  
**Original Size:** ~100,000 orders, 9 CSV files (~120MB)

### Imported Tables

| Table | Rows | Description | Status |
|-------|------|-------------|--------|
| orders | 99,441 | Order headers with timestamps | ✅ Imported |
| order_items | 112,650 | Line items within orders | ✅ Imported |
| customers | 99,441 | Customer information | ✅ Imported |
| products | 32,951 | Product catalog | ✅ Imported |
| sellers | 3,095 | Seller/merchant data | ✅ Imported |
| order_payments | 103,886 | Payment information | ✅ Imported |
| geolocation | 720,152 | Brazilian ZIP code geolocation | ✅ Imported |
| product_category_translation | 71 | Category translations (PT→EN) | ✅ Imported |
| order_reviews | 0 | Customer reviews | ⚠️ Skipped (duplicate keys in source) |

**Total Database Size:** 201 MB

### Data Quality Issues

**Note:** The original Olist dataset contains some data quality issues:

1. **Geolocation coordinates:** Some coordinates are outside Brazil's valid range. Fixed by expanding DECIMAL precision from (10,8) to (15,10).

2. **Order reviews duplicates:** The `olist_order_reviews_dataset.csv` contains duplicate `review_id` keys (first duplicate at line 3,508). This table was excluded from the analysis as it's not critical for performance testing.

3. **Handling strategy:** Used `DISTINCT ON` with `ON CONFLICT DO NOTHING` to import geolocation data, keeping only unique coordinate combinations.

---

## Technical Environment

### Hardware
- **Computer:** MacBook with Apple M2 chip
- **CPU:** 8 cores (4 performance + 4 efficiency)  
- **RAM:** 16 GB unified memory
- **Storage:** SSD with NVMe

### Software
- **OS:** macOS 26.0 (Darwin 25.0.0)
- **PostgreSQL:** 16.10 (via Postgres.app)
- **Data Directory:** `~/Library/Application Support/Postgres/var-16`
- **Port:** 5432
- **Tools:** psql, pgAdmin 4, Python 3.x, pandas

---

## Project Structure

thesis-postgres-ecommerce/
├── data/
│   ├── raw/                 # Original Olist CSV files (9 files, 120MB)
│   └── processed/           # Cleaned/transformed data (future use)
├── sql/
│   ├── 01_create_schema.sql # Database schema creation
│   └── 02_import_data.sql   # Data import with duplicate handling
├── scripts/
│   └── 01_explore_data.py   # Initial data exploration
├── notebooks/               # Jupyter notebooks for analysis
├── results/                 # Performance test results
├── docs/                    # Documentation and notes
└── README.md





---

## Setup Instructions

### 1. Clone Repository
```bash
git clone <repository-url>
cd thesis-postgres-ecommerce

# Requires Kaggle API
kaggle datasets download -d olistbr/brazilian-ecommerce -p data/raw
cd data/raw
unzip brazilian-ecommerce.zip
rm brazilian-ecommerce.zip
# create a databse
psql -U ahmedali template1

CREATE DATABASE ecommerce_olist;
\q

#create schema
psql -U ahmedali -d ecommerce_olist -f sql/01_create_schema.sql

#Import Data
bashpsql -U ahmedali -d ecommerce_olist -f sql/02_import_data.sql

customers (99,441)
    ↓ (1:N)
orders (99,441)
    ↓ (1:N)
order_items (112,650)
    ↓ (N:1)
products (32,951)

orders (99,441)
    ↓ (1:N)
order_payments (103,886)

#------------------------------------
Next Steps

Baseline Performance Testing

Create test queries for e-commerce workloads
Measure baseline throughput (TPS)
Measure baseline latency (ms)
Profile resource utilization (CPU, memory, I/O)


Configuration Optimization

Memory tuning (shared_buffers, work_mem)
Query planner settings
Checkpoint and WAL configuration
Connection pooling


Index Strategy Optimization

B-tree vs GIN vs BRIN comparison
Composite index evaluation
Partial index implementation
Index maintenance testing


Performance Analysis

Document performance improvements
Create visualization charts
Statistical analysis of results
Write thesis chapters

#Verfication Queries
-- Check row counts
SELECT 
    schemaname,
    tablename,
    n_live_tup as row_count
FROM pg_stat_user_tables
ORDER BY n_live_tup DESC;

-- Check table sizes
SELECT 
    tablename,
    pg_size_pretty(pg_total_relation_size('public.'||tablename)) AS total_size,
    pg_size_pretty(pg_relation_size('public.'||tablename)) AS data_size,
    pg_size_pretty(pg_total_relation_size('public.'||tablename) - pg_relation_size('public.'||tablename)) AS index_size
FROM pg_tables
WHERE schemaname = 'public'
ORDER BY pg_total_relation_size('public.'||tablename) DESC;

-- Check foreign key relationships
SELECT 
    tc.table_name, 
    kcu.column_name,
    ccu.table_name AS foreign_table_name,
    ccu.column_name AS foreign_column_name
FROM information_schema.table_constraints AS tc
JOIN information_schema.key_column_usage AS kcu
    ON tc.constraint_name = kcu.constraint_name
JOIN information_schema.constraint_column_usage AS ccu
    ON ccu.constraint_name = tc.constraint_name
WHERE tc.constraint_type = 'FOREIGN KEY'
ORDER BY tc.table_name;

#License
This project is for academic purposes only as part of a bachelor thesis at Czech University of Life Sciences Prague.
Acknowledgments

Dataset: Olist (Brazilian E-commerce platform)
Supervisor: Ing. Jan Pavlík, Ph.D.
Institution: Czech University of Life Sciences Prague, Faculty of Economics and Management

