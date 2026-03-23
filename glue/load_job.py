import sys
import traceback
import awswrangler as wr
from awsglue.utils import getResolvedOptions
from sqlalchemy import create_engine, text

args = getResolvedOptions(sys.argv, [
    'TARGET_BASE',
    'RDS_HOST',
    'RDS_DB',
    'RDS_USER',
    'RDS_PASSWORD'
])

TARGET_BASE  = args['TARGET_BASE']
RDS_HOST     = args['RDS_HOST']
RDS_DB       = args['RDS_DB']
RDS_USER     = args['RDS_USER']
RDS_PASSWORD = args['RDS_PASSWORD']

engine = create_engine(
    f'postgresql+psycopg2://{RDS_USER}:{RDS_PASSWORD}@{RDS_HOST}:5432/{RDS_DB}'
)

# ── Load order: parents before children (foreign keys) ────────────────────────
LOAD_CONFIG = [
    {'name': 'dim_product_category',     'table': 'DimProductCategory'},
    {'name': 'dim_product_sub_category', 'table': 'DimProductSubCategory'},
    {'name': 'dim_product',              'table': 'DimProduct'},
    {'name': 'dim_customer',             'table': 'DimCustomer'},
    {'name': 'dim_customer_usa',         'table': 'DimCustomerUSA'},
    {'name': 'dim_account',              'table': 'DimAccount'},
    {'name': 'fact_transaction',         'table': 'FactTransaction'},
]

results = {}

for cfg in LOAD_CONFIG:
    name         = cfg['name']
    table        = cfg['table']
    parquet_path = f"{TARGET_BASE.rstrip('/')}/{name}/"

    print(f"\nLoading {name} → dmql_base.{table}")

    try:
        df = wr.s3.read_parquet(path=parquet_path)
        print(f"  Rows: {len(df)} | Columns: {list(df.columns)}")

        # Truncate first to overwrite safely without dropping table structure
        with engine.begin() as conn:
            conn.execute(text(f'TRUNCATE TABLE dmql_base."{table}" CASCADE'))
            print(f"  Truncated dmql_base.{table}")

        df.to_sql(
            name      = table,
            con       = engine,
            schema    = 'dmql_base',
            if_exists = 'append',
            index     = False,
            method    = 'multi',
            chunksize = 1000
        )
        results[name] = f"SUCCESS — {len(df)} rows"
        print(f"  Status: SUCCESS")

    except Exception as e:
        results[name] = f"FAILED: {str(e)}"
        print(f"  Status: FAILED — {e}")
        traceback.print_exc()

# ── Summary ───────────────────────────────────────────────────────────────────
print(f"\n{'='*55}")
print("LOAD SUMMARY")
print(f"{'='*55}")
failed = []
for name, status in results.items():
    icon = 'OK  ' if 'SUCCESS' in status else 'FAIL'
    print(f"  [{icon}]  {name:<30s}  {status}")
    if 'FAIL' in status:
        failed.append(name)

if failed:
    raise Exception(f"Load job finished with failures: {failed}")

print("\nAll 7 tables loaded into RDS successfully.")