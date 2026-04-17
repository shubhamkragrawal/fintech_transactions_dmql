import pandas as pd
import awswrangler as wr




def process(source_path, target_path):
    print(f"FactTransaction Reading {source_path}")
    df = wr.s3.read_csv(path=source_path)

    # ── CSV-specific cleaning 
    df.dropna(subset=['TransactionID'], inplace=True)   # TransactionID is mandatory
    df.drop_duplicates(subset=['TransactionID'], inplace=True)
    df['TransactionDate'] = pd.to_datetime(df['TransactionDate'], errors='coerce')
    df['ingested_at'] = pd.Timestamp.utcnow()
    # ──────────────────────────────────────────────────────

    print(f"FactTransaction Cleaned shape: {df.shape}")
    wr.s3.to_parquet(df=df, path=target_path, dataset=True, mode='overwrite')
    print(f"FactTransaction Written to {target_path}")