# Retail Banking Executive Dashboard
### EAS 550 — Financial Services & Retail Banking Analytics
**Team 2:** Shubham Kumar Agrawal · Rahul Yadav · Kavyansh Tiwari

---

## Project Overview

A cloud-native BI application providing high-level visibility into institutional liquidity and customer account health. The pipeline ingests a FinTech Financial Transactions dataset, models it into a Star Schema, and serves it through an interactive Streamlit dashboard built for executive decision-making.

---

## Architecture

```
Kaggle Dataset
      │
      ▼
AWS Lambda (curl download → S3 raw/)
      │
      ▼
AWS Glue — Master ETL Job (Pandas · Python Shell)
   ├── dimAccount.py
   ├── dimCustomer.py
   ├── dimCustomersUSA.py
   ├── Dimproduct.py
   ├── dimProductCateg.py
   ├── DimProductSubCategory.py
   └── factTransaction.py
      │
      ▼
S3 Cleaned Zone (Parquet)
      │
      ▼
AWS Glue — Load Job (psycopg2 · SQLAlchemy)
      │
      ▼
Amazon RDS PostgreSQL (Star Schema)
      │
      ▼
Streamlit Dashboard
```

---

## Tech Stack

| Layer | Technology |
|---|---|
| Ingestion | AWS Lambda, curl, Amazon S3 |
| Transformation | AWS Glue (Python Shell), Pandas, AWS Wrangler |
| Storage | Amazon S3 (raw + cleaned), Amazon RDS PostgreSQL |
| Orchestration | Lambda → Glue Master Job → Glue Load Job |
| Credentials | AWS Secrets Manager |
| Dashboard | Streamlit |
| Transformation (Phase 2) | dbt Core |
| IDE / Query Tool | DBeaver |

---

## Repository Structure

```
├── glue/
│   ├── master_job.py               # Master Glue orchestrator
│   ├── load_job.py                 # RDS load job
│   ├── dimAccount.py               # Processor: DimAccount
│   ├── dimCustomer.py              # Processor: DimCustomer
│   ├── dimCustomersUSA.py          # Processor: DimCustomerUSA
│   ├── Dimproduct.py               # Processor: DimProduct
│   ├── dimProductCateg.py          # Processor: DimProductCategory
│   ├── DimProductSubCategory.py    # Processor: DimProductSubCategory
│   └── factTransaction.py          # Processor: FactTransaction
├── lambda/
│   └── lambda_function.py          # Extraction + pipeline trigger
├── sql/
│   ├── ddl.sql                     # Table definitions (Star Schema)
│   └── security.sql                # RBAC roles and users
├── dbt/
│   └── models/                     # dbt transformation models
├── streamlit/
│   └── app.py                      # Dashboard application
└── README.md
```

---

## Database Schema (Star Schema)

```
                    ┌─────────────────────┐
                    │   FactTransaction   │
                    │─────────────────────│
                    │ TransactionID (PK)  │
                    │ AccountID (FK)      │
                    │ ProductID (FK)      │
                    │ TransactionDate     │
                    │ TransactionAmount   │
                    │ TransactionType     │
                    │ TransactionChannel  │
                    │ Status              │
                    └──────┬──────┬───────┘
                           │      │
              ┌────────────┘      └────────────┐
              ▼                                ▼
   ┌──────────────────┐           ┌─────────────────────────┐
   │   DimAccount     │           │       DimProduct        │
   │──────────────────│           │─────────────────────────│
   │ AccountID (PK)   │           │ ProductID (PK)          │
   │ CustomerID (FK)  │           │ ProductSubCategoryID FK │
   │ AccountType      │           │ ProductName             │
   │ OpenDate         │           └────────────┬────────────┘
   │ ClosedDate       │                        │
   │ Status           │            ┌───────────┘
   │ Balance          │            ▼
   └────────┬─────────┘  ┌──────────────────────────┐
            │            │  DimProductSubCategory   │
            ▼            │──────────────────────────│
   ┌──────────────────┐  │ ProductSubCategoryID PK  │
   │   DimCustomer    │  │ ProductCategoryID (FK)   │
   │──────────────────│  │ ProductSubCategoryName   │
   │ CustomerID (PK)  │  └────────────┬─────────────┘
   │ FullName         │               │
   │ DOB              │               ▼
   │ Gender           │  ┌──────────────────────────┐
   │ Region           │  │   DimProductCategory     │
   │ Email            │  │──────────────────────────│
   │ Status           │  │ ProductCategoryID (PK)   │
   │ JoinDate         │  │ ProductCategoryName      │
   └──────────────────┘  └──────────────────────────┘
```

---

## Project Phases

### Phase 1 — 3NF Relational Modeling & ELT Ingestion

- Designed a 3NF PostgreSQL schema from raw FinTech entities (Customers, Accounts, Products, Transactions)
- Built an automated ELT pipeline using AWS Lambda, Glue Python Shell, and S3
- Applied programmatic data cleaning with Pandas: null handling, deduplication, type casting, column normalization
- Implemented RBAC security with analyst and app user roles

### Phase 2 — Dimensional Modeling & Advanced SQL

- Transformed 3NF schema into a Star Schema using dbt Core
- Centralized `FactTransaction` table surrounded by conformed dimension tables
- Complex SQL queries using CTEs and window functions: 30-day rolling average balances, transaction volume ranking by branch
- dbt tests enforcing referential integrity and non-null constraints on critical financial fields

### Phase 3 — High Performance Application Serving

- Strategic SQL indexing and query optimization for 100,000+ row dataset
- Streamlit dashboard with interactive widgets: date sliders, account type filters
- KPI visualizations: daily transaction volume trends, branch liquidity, account balance distributions
- `@st.cache_data` caching to keep the live cloud-hosted app responsive

---

## Setup & Deployment

### Prerequisites

- AWS account (free tier)
- Kaggle account + API token
- Python 3.12+
- DBeaver
- dbt Core

### Step 1 — AWS Infrastructure

```bash
# S3 bucket structure
your-bucket/
├── raw/financial-transactions/
├── cleaned/financial-transactions/
└── scripts/
```

Create the following IAM roles:
- `LambdaETLRole` — Lambda, S3, Secrets Manager, Glue
- `GlueETLRole` — Glue, S3, RDS

### Step 2 — Store Kaggle Credentials

```
AWS Secrets Manager → kaggle/credentials
{
  "KAGGLE_USERNAME": "your_username",
  "KAGGLE_KEY": "your_api_key"
}
```

### Step 3 — Upload Glue Scripts to S3

```bash
aws s3 cp glue/ s3://your-bucket/scripts/ --recursive
```

### Step 4 — Lambda Environment Variables

| Variable | Value |
|---|---|
| `S3_BUCKET` | your bucket name |
| `DATASET_OWNER` | kaggle dataset owner |
| `DATASET_NAME` | kaggle dataset name |
| `GLUE_JOB_NAME` | `etl-master-job` |
| `GLUE_LOAD_JOB_NAME` | `etl-load-job` |
| `RDS_HOST` | RDS endpoint |
| `RDS_DB` | `etldb` |
| `RDS_USER` | `postgres` |
| `RDS_PASSWORD` | your password |

### Step 5 — Create Glue Jobs

**Master Transform Job**

| Setting | Value |
|---|---|
| Type | Python Shell |
| Script | `s3://your-bucket/scripts/master_job.py` |
| DPU | 0.0625 |
| `--additional-python-modules` | `awswrangler` |

**Load Job**

| Setting | Value |
|---|---|
| Type | Python Shell |
| Script | `s3://your-bucket/scripts/load_job.py` |
| DPU | 0.0625 |
| `--additional-python-modules` | `awswrangler,psycopg2-binary,sqlalchemy` |

### Step 6 — Database Setup

```bash
# Run in DBeaver connected to RDS
psql -f sql/ddl.sql
psql -f sql/security.sql
```

### Step 7 — Run the Pipeline

```
AWS Console → Lambda → your function → Test → {}
```

Monitor progress:
- Lambda logs → CloudWatch `/aws/lambda/your-function`
- Transform job → Glue → `etl-master-job` → Runs
- Load job → Glue → `etl-load-job` → Runs

### Step 8 — Verify Data

```sql
SELECT 'DimProductCategory'    AS table_name, COUNT(*) AS rows FROM etl."DimProductCategory"    UNION ALL
SELECT 'DimProductSubCategory' AS table_name, COUNT(*) AS rows FROM etl."DimProductSubCategory" UNION ALL
SELECT 'DimProduct'            AS table_name, COUNT(*) AS rows FROM etl."DimProduct"            UNION ALL
SELECT 'DimCustomer'           AS table_name, COUNT(*) AS rows FROM etl."DimCustomer"           UNION ALL
SELECT 'DimCustomerUSA'        AS table_name, COUNT(*) AS rows FROM etl."DimCustomerUSA"        UNION ALL
SELECT 'DimAccount'            AS table_name, COUNT(*) AS rows FROM etl."DimAccount"            UNION ALL
SELECT 'FactTransaction'       AS table_name, COUNT(*) AS rows FROM etl."FactTransaction";
```

---

## Security — RBAC

```sql
-- Two roles implemented
analyst_role    → SELECT only on all etl schema tables
app_user_role   → SELECT, INSERT, UPDATE on all etl schema tables

-- Two users created
analyst_user    → assigned analyst_role
app_user        → assigned app_user_role
```

Full implementation in `sql/security.sql`.

---

## Dashboard KPIs

- Daily transaction volume trends
- Overall branch liquidity
- Account balance distributions
- 30-day rolling average balance per account
- Transaction volume ranking by branch
- Account type breakdown (filter widget)
- Date range selector (slider widget)

---

## Dataset

**FinTech Financial Transactions Dataset**
- Source: Kaggle — `saidaminsaidaxmadov/financial-transactions`
- Size: ~100,000+ rows of transactional data
- Entities: Customers, Accounts, Products, Product Categories, Transactions

---

## Cost Estimate (AWS Free Tier)

| Service | Usage | Cost |
|---|---|---|
| Lambda | 1 invocation | ~$0.00 |
| S3 | < 1 GB storage | ~$0.00 |
| Glue (transform) | 0.0625 DPU | ~$0.014 |
| Glue (load) | 0.0625 DPU | ~$0.014 |
| RDS PostgreSQL | db.t3.micro | Free tier |
| **Total** | | **~$0.03** |

---

## Team

| Name | Role |
|---|---|
| Shubham Kumar Agrawal | Data Modeling, dbt, Advanced SQL |
| Rahul Yadav | AWS Infrastructure, Pipeline Orchestration |
| Kavyansh Tiwari | Glue ETL, RDS Setup, Streamlit Dashboard |

---

*EAS 550 · University at Buffalo · Spring 2026*
