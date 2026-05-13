import streamlit as st
import pandas as pd
from sqlalchemy import create_engine
import plotly.express as px
import datetime

st.set_page_config(
    page_title="FinTech Transaction Analytics Dashboard",
    page_icon="📊",
    layout="wide"
)

st.title("📊 FinTech Transaction Analytics Dashboard")
st.markdown("Real-time insights from the AWS cloud data warehouse.")

@st.cache_resource
def init_connection():

    db_url = st.secrets["database"]["url"]
    
    return create_engine(
        db_url, 
        pool_size=10,        
        max_overflow=20,     
        pool_recycle=1800    
    )

try:
    engine = init_connection()
except Exception as e:
    st.error(f"Failed to connect to the AWS database: {e}")
    st.stop()

# CACHED DATA FETCHING
@st.cache_data(ttl=600)
def fetch_transaction_data():
    query = """
        SELECT 
            t."TransactionID",
            t."TransactionDate",
            t."TransactionAmount",
            t."TransactionType",
            t."TransactionChannel",
            c."FullName",
            c."Region",
            p."ProductName"
        FROM dmql_base."FactTransaction" t
        JOIN dmql_base."DimAccount" a ON t."AccountID" = a."AccountID"
        JOIN dmql_base."DimCustomer" c ON a."CustomerID" = c."CustomerID"
        JOIN dmql_base."DimProduct" p ON t."ProductID" = p."ProductID";
    """
    with engine.connect() as conn:
        df = pd.read_sql(query, conn)
    # Standardize data structures
    df['TransactionDate'] = pd.to_datetime(df['TransactionDate']).dt.date
    return df

with st.spinner("Fetching data from AWS Production Warehouse..."):
    df_raw = fetch_transaction_data()

# INTERACTIVE WIDGETS (Sidebar Filters)
st.sidebar.header("Filter Analytics")

# 1. Date Range Slider Widget
min_date = df_raw['TransactionDate'].min()
max_date = df_raw['TransactionDate'].max()

start_date, end_date = st.sidebar.slider(
    "Select Transaction Date Range",
    min_value=min_date,
    max_value=max_date,
    value=(min_date, max_date),
    format="YYYY-MM-DD"
)

# 2. Multi-select Dropdown Filter
selected_channels = st.sidebar.multiselect(
    "Transaction Channels",
    options=df_raw['TransactionChannel'].unique(),
    default=df_raw['TransactionChannel'].unique()
)

# Apply runtime logical filtering
df_filtered = df_raw[
    (df_raw['TransactionDate'] >= start_date) & 
    (df_raw['TransactionDate'] <= end_date) &
    (df_raw['TransactionChannel'].isin(selected_channels))
]

# KPI METRICS
col1, col2, col3, col4 = st.columns(4)
with col1:
    st.metric("Total Transaction Volume", f"${df_filtered['TransactionAmount'].sum():,.2f}")
with col2:
    st.metric("Total Transactions Count", f"{len(df_filtered):,}")
with col3:
    st.metric("Avg. Transaction Value", f"${df_filtered['TransactionAmount'].mean():,.2f}")
with col4:
    st.metric("Active Regions", f"{df_filtered['Region'].nunique()}")

st.markdown("---")

# DYNAMIC VISUALIZATIONS
vis_col1, vis_col2 = st.columns(2)

with vis_col1:
    st.subheader("📈 Transaction Volume Trend over Time")
    df_trend = df_filtered.groupby('TransactionDate')['TransactionAmount'].sum().reset_index()
    fig_line = px.line(
        df_trend, 
        x='TransactionDate', 
        y='TransactionAmount',
        labels={'TransactionAmount': 'Total Amount ($)', 'TransactionDate': 'Date'},
        template="plotly_dark"
    )
    st.plotly_chart(fig_line, use_container_width=True)

with vis_col2:
    st.subheader("🛍️ Spending Distribution by Transaction Type")
    df_type = df_filtered.groupby('TransactionType')['TransactionAmount'].sum().reset_index()
    fig_pie = px.pie(
        df_type, 
        values='TransactionAmount', 
        names='TransactionType',
        hole=0.4,
        template="plotly_dark"
    )
    st.plotly_chart(fig_pie, use_container_width=True)

st.markdown("-----")

# DATA VIEW LAYER
st.subheader("🔍 Filtered Transaction Ledger (Sample Preview)")
st.dataframe(df_filtered.head(100), use_container_width=True)