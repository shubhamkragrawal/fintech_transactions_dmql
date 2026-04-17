import pandas as pd
import awswrangler as wr
import re



def process(source_path, target_path):
    print(f"DimCustomerUSA Reading {source_path}")
    df = wr.s3.read_csv(path=source_path)

    # ── CSV-specific cleaning 
    df.dropna(subset=['CustomerID'], inplace=True)   # CustomerID is mandatory
    df.drop_duplicates(subset=['CustomerID'], inplace=True)
    df['JoinDate'] = pd.to_datetime(df['JoinDate'], errors='coerce')
    df['ingested_at'] = pd.Timestamp.utcnow()
    # ──────────────────────────────────────────────────────

    print(f"DimCustomerUSA Cleaned shape: {df.shape}")
    wr.s3.to_parquet(df=df, path=target_path, dataset=True, mode='overwrite')
    print(f"DimCustomerUSA Written to {target_path}")