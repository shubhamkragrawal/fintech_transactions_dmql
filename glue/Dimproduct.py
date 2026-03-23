import pandas as pd
import awswrangler as wr




def process(source_path, target_path):
    print(f"Dimproduct Reading {source_path}")
    df = wr.s3.read_csv(path=source_path)


    # ──────────────────────────────────────────────────────

    print(f"Dimproduct Cleaned shape: {df.shape}")
    wr.s3.to_parquet(df=df, path=target_path, dataset=True, mode='overwrite')
    print(f"Dimproduct Written to {target_path}")