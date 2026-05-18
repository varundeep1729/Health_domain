import os
import streamlit as st

st.set_page_config(page_title="Health Domain Platform", page_icon="🏥", layout="wide")

conn = st.connection("snowflake", ttl=os.getenv("SNOWFLAKE_CONNECTION_TTL"))
st.session_state["conn"] = conn

pages = [
    st.Page("app_pages/executive_summary.py", title="Executive Summary", icon="📊"),
    st.Page("app_pages/clinical_analytics.py", title="Clinical Analytics", icon="🫀"),
    st.Page("app_pages/population_health.py", title="Population Health", icon="👥"),
    st.Page("app_pages/quality_measures.py", title="Quality Measures", icon="✅"),
    st.Page("app_pages/financial.py", title="Financial & Claims", icon="💰"),
    st.Page("app_pages/ai_assistant.py", title="AI Assistant", icon="🤖"),
]

page = st.navigation(pages)
page.run()
