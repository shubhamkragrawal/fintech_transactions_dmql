import streamlit as st
import psycopg2
import pandas as pd

@st.cache_resource
def get_connection():
    return psycopg2.connect(
        host=st.secrets["RDS_HOST"],
        database=st.secrets["RDS_DB"],
        user=st.secrets["RDS_USER"],
        password=st.secrets["RDS_PASSWORD"],
        port=st.secrets.get("RDS_PORT", 5432)
    )

conn = get_connection()

@st.cache_data(ttl=600)
def run_query(query):
    return pd.read_sql(query, conn)