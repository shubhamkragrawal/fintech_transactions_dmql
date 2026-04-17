import pandas as pd
import awswrangler as wr




def process(source_path, target_path):
    print(f"DimProductCategory Reading {source_path}")
    df = wr.s3.read_csv(path=source_path)

    # ──────────────────────────────────────────────────────

    print(f"DimProductCategory Cleaned shape: {df.shape}")
    wr.s3.to_parquet(df=df, path=target_path, dataset=True, mode='overwrite')
    print(f"DimProductCategory Written to {target_path}")