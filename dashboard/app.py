import streamlit as st
import pandas as pd
from sqlalchemy import create_engine
import plotly.express as px
import datetime

st.set_page_config(
    page_title="Fintech Transaction Analytics Dashboard",
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
            c."Gender",
            p."ProductName",
            q."ProductSubCategoryName"
        FROM dmql_base."FactTransaction" t
        JOIN dmql_base."DimAccount" a ON t."AccountID" = a."AccountID"
        JOIN dmql_base."DimCustomer" c ON a."CustomerID" = c."CustomerID"
        JOIN dmql_base."DimProduct" p ON t."ProductID" = p."ProductID"
        JOIN dmql_base."DimProductSubCategory" q ON p."ProductSubcategoryID" = q."ProductSubCategoryID";
    """
    with engine.connect() as conn:
        df = pd.read_sql(query, conn)
    # Standardize data structures
    df['TransactionDate'] = pd.to_datetime(df['TransactionDate']).dt.date
    df['TransactionAmount'] = df['TransactionAmount'].abs()
    return df

with st.spinner("Fetching data from AWS Production Warehouse..."):
    df_raw = fetch_transaction_data()

# INTERACTIVE WIDGETS (Sidebar Filters)
st.sidebar.header("Filter Data")

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

# 3. Region Multi-select Dropdown Filter
selected_region = st.sidebar.multiselect(
    "Region",
    options=df_raw['Region'].unique(),
    default=df_raw['Region'].unique()
)

# 4. Gender Multi-select Dropdown Filter
selected_gender = st.sidebar.multiselect(
    "Gender",
    options=df_raw['Gender'].unique(),
    default=df_raw['Gender'].unique()
)

# 5. Transaction-Type Multi-select Dropdown Filter
selected_transaction_type = st.sidebar.multiselect(
    "Transaction Type",
    options=df_raw['TransactionType'].unique(),
    default=df_raw['TransactionType'].unique()
)

# 6. Product Sub-category Multi-select Dropdown Filter
selected_sub_category = st.sidebar.multiselect(
    "Product Category",
    options=df_raw['ProductSubCategoryName'].unique(),
    default=df_raw['ProductSubCategoryName'].unique()
)

# Apply runtime logical filtering
df_filtered = df_raw[
    (df_raw['TransactionDate'] >= start_date) & 
    (df_raw['TransactionDate'] <= end_date) &
    (df_raw['TransactionChannel'].isin(selected_channels)) &
    (df_raw['Region'].isin(selected_region)) &
    (df_raw['Gender'].isin(selected_gender)) &
    (df_raw['TransactionType'].isin(selected_transaction_type)) &
    (df_raw['ProductSubCategoryName'].isin(selected_sub_category))
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
        template="plotly_dark",
        color_discrete_sequence=["#00A2FF"]
    )
    st.plotly_chart(fig_line, use_container_width=True)

with vis_col2:
    st.subheader("🛍️ Spending Distribution by Product Category")
    df_category = df_filtered.groupby('ProductSubCategoryName')['TransactionAmount'].sum().reset_index()
    fig_pie = px.pie(
        df_category, 
        values='TransactionAmount', 
        names='ProductSubCategoryName',
        hole=0.4,
        template="plotly_dark",
        color_discrete_sequence=["#00A2FF"]
    )
    st.plotly_chart(fig_pie, use_container_width=True)

vis_col3, vis_col4 = st.columns(2)

with vis_col3:
    st.subheader("🛍️ Spending Distribution by Transaction Channel")
    df_channel = df_filtered.groupby('TransactionChannel')['TransactionAmount'].sum().reset_index()
    fig_pie = px.pie(
        df_channel, 
        values='TransactionAmount', 
        names='TransactionChannel',
        hole=0.4,
        template="plotly_dark",
        color_discrete_sequence=["#00A2FF"]
    )
    st.plotly_chart(fig_pie, use_container_width=True)

with vis_col4:
    st.subheader("🛍️ Spending Distribution by Region")
    df_region = df_filtered.groupby('Region')['TransactionAmount'].sum().reset_index()
    fig_pie = px.pie(
        df_region, 
        values='TransactionAmount', 
        names='Region',
        hole=0.4,
        template="plotly_dark",
        color_discrete_sequence=["#00A2FF"]
    )
    st.plotly_chart(fig_pie, use_container_width=True)

vis_col5, vis_col6 = st.columns(2)

with vis_col5:
    st.subheader("🛍️ Spending Distribution by Gender ")
    df_gender = df_filtered.groupby('Gender')['TransactionAmount'].sum().reset_index()
    fig_pie = px.pie(
        df_gender, 
        values='TransactionAmount', 
        names='Gender',
        hole=0.4,
        template="plotly_dark",
        color_discrete_sequence=["#00A2FF"]
    )
    st.plotly_chart(fig_pie, use_container_width=True)

with vis_col6:
    st.subheader("🛍️ Spending Distribution by Transaction Type")
    df_type = df_filtered.groupby('TransactionType')['TransactionAmount'].sum().reset_index()
    fig_pie = px.pie(
        df_type, 
        values='TransactionAmount', 
        names='TransactionType',
        hole=0.4,
        template="plotly_dark",
        color_discrete_sequence=["#00A2FF"]
    )
    st.plotly_chart(fig_pie, use_container_width=True)



st.markdown("-----")

# Raw Data
st.subheader("🔍 Filtered Transaction Ledger (Sample Preview)")
st.dataframe(df_filtered.head(100), use_container_width=True)