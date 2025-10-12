# Baseline Performance Test Results

**Date:** October 2025  
**Database:** ecommerce_olist (PostgreSQL 16.10)  
**Hardware:** MacBook M2, 16GB RAM  
**Test:** Product Catalog Queries (Read-Heavy Workload)

---

## Test Methodology

- **Scenario:** Product catalog browsing (most common e-commerce operation)
- **Approach:** Cold start → Warm cache (10 iterations) → Analysis
- **Queries Tested:** Category lookup, multi-filter search, aggregations

---

## Results Summary

### Performance Metrics

| Query Type | Cold Cache | Warm Cache | Improvement | Status |
|-----------|-----------|-----------|-------------|--------|
| Simple category lookup | 2.10 ms | 0.18 ms | 91.4% faster | ✅ Excellent |
| Multi-category search | 3.05 ms | ~0.2 ms | ~93% faster | ✅ Excellent |
| Heavy aggregation (GROUP BY) | 9.54 ms | N/A | N/A | ✅ Good |

### Cache Performance

| Metric | Value | Analysis |
|--------|-------|----------|
| **Cache Hit Ratio** | 100% | Perfect - all data served from memory |
| **Disk Reads** | 0 | No disk I/O after warm-up |
| **Cache Hits** | 2,434 blocks | ~19 MB cached |

### Index Usage

| Index | Scans | Tuples Read | Tuples Fetched | Status |
|-------|-------|-------------|----------------|--------|
| idx_products_category | 19 | 45,052 | 0 | ⚠️ Not effectively used |

---

## Key Findings

### ✅ Strengths

1. **Excellent cache performance:** 100% hit ratio after warm-up
2. **Fast queries:** All queries under 10ms (cold), under 0.2ms (warm)
3. **Cache effectiveness:** 91-93% performance improvement with warm cache

### ⚠️ Optimization Opportunities

1. **Sequential Scan Issue:**
   - Query uses `Seq Scan` instead of index
   - Reading entire table (33K rows) to find 2,444 matching records
   - Cost: 907.89 (relatively high for small table)

2. **Index Not Being Used:**
   - `idx_products_category` exists but shows 0 tuples fetched
   - PostgreSQL query planner chose sequential scan
   - Reason: Table is small (~3968 kB data), planner thinks seq scan is faster

3. **Potential Improvements:**
   - Test with larger dataset (scale to 100K+ products)
   - Analyze index selectivity
   - Consider composite indexes for multi-column filters
   - Test partitioning strategies

---

## Query Plan Analysis

**Current Plan:**
Seq Scan on products  (cost=0.00..907.89 rows=2427 width=48)
Filter: ((product_category_name)::text = 'beleza_saude'::text)
Rows Removed by Filter: 645
Buffers: shared hit=10

**Issues:**
- Full table scan (not using index)
- Filtering 645 rows unnecessarily
- 10 buffer hits (could be reduced with index)

**Expected after optimization:**
Index Scan using idx_products_category on products
Index Cond: (product_category_name = 'beleza_saude')
Buffers: shared hit=2-3  ← Reduced buffer usage

---

## Conclusions

1. **Baseline performance is good** but not optimal
2. **Cache is working perfectly** (100% hit ratio)
3. **Query planner needs tuning** to prefer indexes
4. **Clear optimization path** identified for thesis

---

## Next Steps

1. ✅ Baseline documented
2. ⏭️ Configuration optimization (memory, query planner settings)
3. ⏭️ Index strategy improvement (composite, partial indexes)
4. ⏭️ Scalability testing (increase data volume)
5. ⏭️ Workload testing (OLTP vs OLAP configurations)