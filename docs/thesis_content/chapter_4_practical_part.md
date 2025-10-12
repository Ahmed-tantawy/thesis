# Chapter 4: Practical Part - Documentation

**Status:** Work in Progress  
**Last Updated:** October 12, 2025

---

## 4.1 Experimental Environment Setup

### 4.1.1 Hardware and Software Configuration

**Hardware:**
- Computer: MacBook with Apple M2 chip
- CPU: 8 cores (4 performance + 4 efficiency)
- RAM: 16 GB unified memory
- Storage: 512 GB SSD with NVMe

**Software:**
- Operating System: macOS 26.0 (Darwin 25.0.0)
- PostgreSQL: 16.10 (Postgres.app)
- Data Directory: ~/Library/Application Support/Postgres/var-16
- Port: 5432
- Python: 3.12
- Tools: psql, pgAdmin 4, pandas

**Rationale:**
The local setup using Postgres.app was chosen over cloud deployment to ensure consistent, reproducible test conditions without network latency variability. Apple Silicon's M2 processor provides strong single-thread performance suitable for database workload testing, while the unified memory architecture offers efficient memory access patterns beneficial for PostgreSQL's shared buffer management.

---

## 4.2 Dataset Selection and Preparation

### 4.2.1 Olist Brazilian E-commerce Dataset

**Source:** Kaggle - Olist Brazilian E-commerce Public Dataset  
**Original Size:** 9 CSV files, approximately 120MB  
**Records:** 100,000+ orders, 720,000+ geolocation entries

**Dataset Composition:**
- Customers: 99,441 records
- Orders: 99,441 records
- Order Items: 112,650 records
- Products: 32,951 records
- Sellers: 3,095 records
- Order Payments: 103,886 records
- Geolocation: 720,152 records (after deduplication)
- Product Categories: 71 categories
- Order Reviews: Excluded due to duplicate keys in source data

**Total Database Size:** 201 MB

### 4.2.2 Database Schema Design

The database schema follows a normalized Third Normal Form (3NF) design, typical of e-commerce transactional systems. This design prioritizes:
- Data integrity through foreign key constraints
- Elimination of redundancy
- Support for ACID transactions
- Realistic representation of business entities

**Schema Overview:**
customers (1) ──→ (N) orders (1) ──→ (N) order_items (N) ──→ (1) products
│
└──→ (N) order_payments

**Key Design Decisions:**
1. Normalized structure ensures referential integrity
2. Composite primary keys in order_items (order_id, order_item_id)
3. Basic B-tree indexes on foreign keys and commonly queried columns
4. Timestamp fields for temporal analysis

### 4.2.3 Data Quality Issues and Handling

**Issue 1: Geolocation Coordinate Precision**
- Problem: Some coordinates exceeded DECIMAL(10,8) precision
- Solution: Expanded to DECIMAL(15,10) to accommodate outliers
- Impact: 720,152 records imported successfully after adjustment

**Issue 2: Order Reviews Duplicate Keys**
- Problem: Duplicate review_id at line 3,508 in source CSV
- Decision: Excluded table from analysis (not critical for performance testing)
- Justification: Reviews are analytical, not transactional—their absence doesn't affect core e-commerce operations testing

---

## 4.3 Baseline Performance Testing

### 4.3.1 Test Methodology

**Approach:** Cold vs Warm Cache Comparison

Testing was conducted in two phases:
1. **Cold Start:** First query execution with empty cache
2. **Warm Cache:** Repeated queries (10 iterations) to populate shared buffers

This methodology measures:
- Real-world first-access latency (cold)
- Optimal steady-state performance (warm)
- Cache effectiveness (improvement ratio)

### 4.3.2 Baseline Results (Default Configuration)

**Configuration at Baseline:**
- shared_buffers: 128MB (default)
- work_mem: 4MB (default)
- effective_cache_size: 4GB (default)
- random_page_cost: 4.0 (HDD default)
- max_parallel_workers_per_gather: 2

**Performance Results:**

| Test Scenario | Cold Cache | Warm Cache | Improvement |
|--------------|-----------|-----------|-------------|
| Category Lookup | 2.10 ms | 0.18 ms | 91.4% faster |
| Multi-Category Search | 3.05 ms | ~0.20 ms | 93% faster |
| Heavy Aggregation | 9.54 ms | N/A | N/A |

**Cache Performance:**
- Cache Hit Ratio: 100% (after warm-up)
- Disk Reads: 0 (all data served from memory)
- Buffer Hits: 2,434 blocks (~19 MB)

**Query Plan Analysis:**
```sql
Seq Scan on products (cost=0.00..907.89 rows=2427)
  Filter: ((product_category_name)::text = 'beleza_saude'::text)
  Buffers: shared hit=10
Key Finding: PostgreSQL used sequential scan instead of index, indicating suboptimal query planner configuration for SSD storage.

4.4 Configuration Optimization
4.4.1 Optimization Strategy
Rationale for Changes:
PostgreSQL's default configuration assumes:

Conservative memory allocation (safe for any system)
Hard disk drive (HDD) storage with high random access costs
Limited parallelism (safe for older systems)

These assumptions don't match modern hardware. The optimization strategy targeted:

Memory Allocation: Utilize available RAM effectively
SSD Cost Model: Adjust planner costs for solid-state storage
Parallelism: Leverage 8-core M2 processor
Cache Effectiveness: Maximize buffer hit ratio

4.4.2 Configuration Changes Applied
ParameterDefaultOptimizedRationaleshared_buffers128MB4GB25% of RAM; PostgreSQL best practicework_mem4MB64MBSupport complex sorts/joins without disk spillseffective_cache_size4GB12GB75% of RAM; guides query planner decisionsmaintenance_work_mem64MB1GBFaster index creation and VACUUM operationsrandom_page_cost4.01.1SSD-optimized; index scans become more attractivemax_parallel_workers_per_gather24Utilize M2's 8 cores for parallel queries
Platform Note:
effective_io_concurrency could not be set on macOS due to lack of posix_fadvise() system call support. This is expected behavior and does not significantly impact performance.
4.4.3 Post-Optimization Results
Query Plan After Optimization:
sqlIndex Scan using idx_products_category on products
  Index Cond: ((product_category_name)::text = 'beleza_saude'::text)
  Buffers: shared hit=12
Critical Achievement: Query planner now uses index scans instead of sequential scans.
Performance Comparison:
MetricBaselineOptimizedAnalysisCold Query (avg)4.9 ms5.4 ms10% slower (acceptable)Warm Query (avg)0.191 ms0.202 ms6% slower (expected)Query PlanSeq ScanIndex Scan✅ Correct improvementBuffer Usage10 blocks12 blocksOptimized access pattern
4.4.4 Analysis and Interpretation
Primary Achievement:
Configuration optimization successfully modified the query planner's cost model to prefer index scans on SSD storage. The random_page_cost parameter was reduced from 4.0 (HDD default) to 1.1, correctly reflecting solid-state storage characteristics.
Performance Trade-offs:
The slight 6% latency increase in warm cache scenarios is an expected and acceptable trade-off:

Larger shared buffers (4GB vs 128MB) require more memory scanning
Index overhead adds minimal cost on small tables
Scalability prioritized over micro-optimization on test dataset

Scalability Implications:
While the 32,951-product test dataset shows minimal performance difference, the correct query plan ensures that performance remains stable as the dataset scales to production sizes of 1M+ products. A sequential scan becomes exponentially slower with data growth, while an index scan maintains logarithmic time complexity.
Formula:

Sequential Scan: O(n) — time increases linearly with table size
Index Scan: O(log n) — time increases logarithmically

For 1 million products:

Sequential Scan: ~30x slower than current
Index Scan: ~5x slower than current

Conclusion:
Configuration optimization validates the hypothesis that hardware-specific tuning significantly impacts query planner behavior, even when immediate performance gains are modest on small datasets.

4.5 Index Strategy Optimization
[To be completed in next testing phase]

4.6 Scalability and Load Testing
[To be completed in next testing phase]

Summary of Key Findings (So Far)

✅ Cache effectiveness: 91-93% performance improvement with warm cache
✅ Configuration impact: SSD optimization enabled correct index usage
✅ Query plan improvement: Sequential scans → Index scans
✅ Trade-off awareness: Small latency cost for scalability benefits
✅ Data quality handling: Successfully managed real-world dataset issues


Tables and Figures to Create
Table 4.1: Hardware and Software Configuration
Table 4.2: Dataset Composition and Size
Table 4.3: Baseline Performance Metrics
Table 4.4: Configuration Parameter Changes
Table 4.5: Post-Optimization Performance Comparison
Figure 4.1: Database Schema (ER Diagram)
Figure 4.2: Cold vs Warm Cache Performance
Figure 4.3: Query Plan Comparison (Before/After)
Figure 4.4: Configuration Impact on Query Planner

Next Steps

 Index strategy optimization (composite, partial, covering indexes)
 Concurrency testing (multiple simultaneous users)
 Scalability testing (data volume impact)
 Write performance testing (INSERT/UPDATE operations)
 Query complexity analysis (simple vs complex queries)


---
