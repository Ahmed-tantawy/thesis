#!/usr/bin/env python3
"""
Concurrency and Load Testing for PostgreSQL
Simulates multiple simultaneous users querying the database
"""

import psycopg2
import time
import threading
import statistics
from datetime import datetime

# Database connection parameters
DB_PARAMS = {
    'host': 'localhost',
    'database': 'ecommerce_olist',
    'user': 'ahmedali',
    'port': 5432
}

# Test queries
QUERIES = {
    'catalog_lookup': """
        SELECT product_id, product_category_name, product_weight_g
        FROM products 
        WHERE product_category_name = 'beleza_saude' 
        LIMIT 50
    """,
    'customer_orders': """
        SELECT o.order_id, o.order_status, o.order_purchase_timestamp
        FROM orders o
        WHERE o.customer_id = (SELECT customer_id FROM customers LIMIT 1 OFFSET 100)
        LIMIT 10
    """,
    'order_analytics': """
        SELECT 
            p.product_category_name,
            COUNT(*) as order_count,
            AVG(oi.price) as avg_price
        FROM order_items oi
        JOIN products p ON oi.product_id = p.product_id
        WHERE oi.price > 20
        GROUP BY p.product_category_name
        ORDER BY order_count DESC
        LIMIT 10
    """
}

results = []
errors = []

def run_query(query_name, query, thread_id, iterations=10):
    """Execute queries and measure performance"""
    thread_results = []
    
    try:
        # Create connection for this thread
        conn = psycopg2.connect(**DB_PARAMS)
        cursor = conn.cursor()
        
        for i in range(iterations):
            start_time = time.time()
            
            try:
                cursor.execute(query)
                rows = cursor.fetchall()
                
                end_time = time.time()
                duration = (end_time - start_time) * 1000  # Convert to ms
                
                thread_results.append({
                    'thread_id': thread_id,
                    'query': query_name,
                    'iteration': i + 1,
                    'duration_ms': duration,
                    'rows': len(rows),
                    'success': True
                })
                
            except Exception as e:
                errors.append({
                    'thread_id': thread_id,
                    'query': query_name,
                    'error': str(e)
                })
                thread_results.append({
                    'thread_id': thread_id,
                    'query': query_name,
                    'iteration': i + 1,
                    'duration_ms': 0,
                    'rows': 0,
                    'success': False
                })
        
        cursor.close()
        conn.close()
        
    except Exception as e:
        errors.append({
            'thread_id': thread_id,
            'error': f"Connection error: {str(e)}"
        })
    
    results.extend(thread_results)

def run_concurrency_test(num_threads, query_name, iterations=10):
    """Run queries with specified number of concurrent threads"""
    print(f"\n{'='*70}")
    print(f"Testing: {query_name} with {num_threads} concurrent threads")
    print(f"{'='*70}")
    
    query = QUERIES[query_name]
    threads = []
    
    # Clear previous results
    results.clear()
    errors.clear()
    
    # Start timer
    start_time = time.time()
    
    # Create and start threads
    for i in range(num_threads):
        thread = threading.Thread(
            target=run_query,
            args=(query_name, query, i, iterations)
        )
        threads.append(thread)
        thread.start()
    
    # Wait for all threads to complete
    for thread in threads:
        thread.join()
    
    # End timer
    end_time = time.time()
    total_duration = end_time - start_time
    
    # Calculate statistics
    successful_queries = [r for r in results if r['success']]
    
    if successful_queries:
        durations = [r['duration_ms'] for r in successful_queries]
        
        print(f"\nResults:")
        print(f"  Total time: {total_duration:.2f} seconds")
        print(f"  Successful queries: {len(successful_queries)}/{len(results)}")
        print(f"  Failed queries: {len(results) - len(successful_queries)}")
        print(f"  Queries per second: {len(successful_queries)/total_duration:.2f}")
        print(f"\nQuery Performance:")
        print(f"  Average: {statistics.mean(durations):.2f} ms")
        print(f"  Median: {statistics.median(durations):.2f} ms")
        print(f"  Min: {min(durations):.2f} ms")
        print(f"  Max: {max(durations):.2f} ms")
        print(f"  Std Dev: {statistics.stdev(durations):.2f} ms" if len(durations) > 1 else "  Std Dev: N/A")
        
        if errors:
            print(f"\nErrors encountered: {len(errors)}")
            for error in errors[:3]:  # Show first 3 errors
                print(f"  - {error}")
        
        return {
            'threads': num_threads,
            'query': query_name,
            'total_time': total_duration,
            'successful': len(successful_queries),
            'failed': len(results) - len(successful_queries),
            'qps': len(successful_queries)/total_duration,
            'avg_ms': statistics.mean(durations),
            'median_ms': statistics.median(durations),
            'min_ms': min(durations),
            'max_ms': max(durations),
            'p95_ms': sorted(durations)[int(len(durations) * 0.95)] if len(durations) > 1 else durations[0],
            'p99_ms': sorted(durations)[int(len(durations) * 0.99)] if len(durations) > 1 else durations[0]
        }
    else:
        print("\nAll queries failed!")
        return None

def main():
    """Main test execution"""
    print("="*70)
    print("PostgreSQL Concurrency and Load Testing")
    print("="*70)
    print(f"Start time: {datetime.now()}")
    print(f"Database: {DB_PARAMS['database']}")
    print(f"Queries to test: {len(QUERIES)}")
    
    # Test configurations
    thread_counts = [1, 5, 10, 20, 50]
    iterations = 5  # Iterations per thread
    
    all_results = []
    
    # Test each query with different concurrency levels
    for query_name in QUERIES.keys():
        print(f"\n\n{'#'*70}")
        print(f"# Query: {query_name}")
        print(f"{'#'*70}")
        
        for num_threads in thread_counts:
            result = run_concurrency_test(num_threads, query_name, iterations)
            if result:
                all_results.append(result)
            
            # Small delay between tests
            time.sleep(1)
    
    # Summary report
    print("\n\n" + "="*70)
    print("SUMMARY REPORT")
    print("="*70)
    
    for query_name in QUERIES.keys():
        print(f"\n{query_name.upper()}:")
        print(f"{'Threads':<10} {'QPS':<10} {'Avg(ms)':<10} {'P95(ms)':<10} {'P99(ms)':<10}")
        print("-" * 50)
        
        query_results = [r for r in all_results if r['query'] == query_name]
        for r in query_results:
            print(f"{r['threads']:<10} {r['qps']:<10.2f} {r['avg_ms']:<10.2f} "
                  f"{r['p95_ms']:<10.2f} {r['p99_ms']:<10.2f}")
    
    print(f"\n\nTest completed: {datetime.now()}")
    print("="*70)

if __name__ == "__main__":
    main()