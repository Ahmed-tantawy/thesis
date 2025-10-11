"""
Data Exploration Script
Explore the Olist dataset before loading into PostgreSQL
"""

import pandas as pd
import os

# Set display options
pd.set_option('display.max_columns', None)
pd.set_option('display.width', None)

# Base path to data
DATA_PATH = 'data/raw'

def explore_csv(filename):
    """Explore a single CSV file"""
    filepath = os.path.join(DATA_PATH, filename)
    
    print(f"\n{'='*80}")
    print(f"FILE: {filename}")
    print(f"{'='*80}")
    
    # Read CSV
    df = pd.read_csv(filepath)
    
    # Basic info
    print(f"\nShape: {df.shape[0]:,} rows × {df.shape[1]} columns")
    print(f"Memory: {df.memory_usage(deep=True).sum() / 1024**2:.2f} MB")
    
    # Column info
    print(f"\nColumns and Types:")
    print(df.dtypes)
    
    # Missing values
    print(f"\nMissing Values:")
    missing = df.isnull().sum()
    missing_pct = (missing / len(df) * 100).round(2)
    missing_df = pd.DataFrame({
        'Missing': missing,
        'Percentage': missing_pct
    })
    print(missing_df[missing_df['Missing'] > 0])
    
    # First few rows
    print(f"\nFirst 3 rows:")
    print(df.head(3))
    
    # Unique values for categorical columns
    categorical_cols = df.select_dtypes(include=['object']).columns
    if len(categorical_cols) > 0:
        print(f"\nUnique values in categorical columns:")
        for col in categorical_cols[:5]:  # First 5 categorical columns
            print(f"  {col}: {df[col].nunique()} unique values")
    
    return df

def main():
    """Main exploration function"""
    
    print("OLIST DATASET EXPLORATION")
    print("="*80)
    
    # List all CSV files
    csv_files = [f for f in os.listdir(DATA_PATH) if f.endswith('.csv')]
    
    print(f"\nFound {len(csv_files)} CSV files:")
    for i, filename in enumerate(csv_files, 1):
        print(f"  {i}. {filename}")
    
    # Explore each file
    dataframes = {}
    for filename in csv_files:
        df = explore_csv(filename)
        key = filename.replace('olist_', '').replace('_dataset.csv', '')
        dataframes[key] = df
    
    # Summary statistics
    print(f"\n{'='*80}")
    print("DATASET SUMMARY")
    print(f"{'='*80}")
    
    total_rows = sum(df.shape[0] for df in dataframes.values())
    total_memory = sum(df.memory_usage(deep=True).sum() for df in dataframes.values())
    
    print(f"\nTotal rows across all files: {total_rows:,}")
    print(f"Total memory usage: {total_memory / 1024**2:.2f} MB")
    
    # Key statistics
    if 'orders' in dataframes:
        orders_df = dataframes['orders']
        print(f"\nOrder Statistics:")
        print(f"  Total orders: {len(orders_df):,}")
        print(f"  Unique customers: {orders_df['customer_id'].nunique():,}")
        print(f"  Date range: {orders_df['order_purchase_timestamp'].min()} to {orders_df['order_purchase_timestamp'].max()}")
    
    if 'order_items' in dataframes:
        items_df = dataframes['order_items']
        print(f"\nOrder Items Statistics:")
        print(f"  Total items: {len(items_df):,}")
        print(f"  Average items per order: {len(items_df) / len(orders_df):.2f}")
        print(f"  Unique products: {items_df['product_id'].nunique():,}")
    
    print("\n" + "="*80)
    print("Exploration complete! Ready for PostgreSQL import.")
    print("="*80)

if __name__ == "__main__":
    main()