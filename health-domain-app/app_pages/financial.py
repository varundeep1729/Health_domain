import streamlit as st

conn = st.session_state["conn"]


@st.cache_data(ttl=600)
def load_claims_by_payer():
    return conn.query("""
        SELECT payer_name, claim_type, COUNT(*) AS claim_count,
               ROUND(SUM(billed_amount), 2) AS total_billed,
               ROUND(SUM(allowed_amount), 2) AS total_allowed,
               ROUND(SUM(paid_amount), 2) AS total_paid,
               ROUND(SUM(patient_responsibility), 2) AS total_patient_resp,
               SUM(CASE WHEN claim_status = 'DENIED' THEN 1 ELSE 0 END) AS denials,
               ROUND(SUM(CASE WHEN claim_status = 'DENIED' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 1) AS denial_rate,
               ROUND(SUM(paid_amount) * 100.0 / NULLIF(SUM(billed_amount), 0), 1) AS collection_rate
        FROM HEALTH_RAW_DB.REFERENCE_DATA.RAW_CLAIMS
        GROUP BY payer_name, claim_type ORDER BY total_billed DESC
    """)


@st.cache_data(ttl=600)
def load_denial_reasons():
    return conn.query("""
        SELECT denial_reason, payer_name, COUNT(*) AS denial_count,
               ROUND(SUM(billed_amount), 2) AS denied_amount
        FROM HEALTH_RAW_DB.REFERENCE_DATA.RAW_CLAIMS
        WHERE claim_status = 'DENIED' AND denial_reason IS NOT NULL
        GROUP BY denial_reason, payer_name ORDER BY denial_count DESC
    """)


@st.cache_data(ttl=600)
def load_revenue_summary():
    return conn.query("""
        SELECT
            ROUND(SUM(billed_amount), 0) AS total_billed,
            ROUND(SUM(allowed_amount), 0) AS total_allowed,
            ROUND(SUM(paid_amount), 0) AS total_paid,
            ROUND(SUM(billed_amount) - SUM(paid_amount), 0) AS total_write_off,
            ROUND(SUM(patient_responsibility), 0) AS total_patient_resp,
            COUNT(*) AS total_claims,
            SUM(CASE WHEN claim_status = 'DENIED' THEN 1 ELSE 0 END) AS total_denials,
            SUM(CASE WHEN claim_status = 'PAID' THEN 1 ELSE 0 END) AS total_paid_claims,
            ROUND(SUM(paid_amount) * 100.0 / NULLIF(SUM(billed_amount), 0), 1) AS net_collection_rate
        FROM HEALTH_RAW_DB.REFERENCE_DATA.RAW_CLAIMS
    """)


@st.cache_data(ttl=600)
def load_monthly_revenue():
    return conn.query("""
        SELECT DATE_TRUNC('MONTH', service_date)::DATE AS service_month,
               ROUND(SUM(billed_amount), 0) AS billed, ROUND(SUM(paid_amount), 0) AS paid,
               COUNT(*) AS claims
        FROM HEALTH_RAW_DB.REFERENCE_DATA.RAW_CLAIMS
        WHERE service_date IS NOT NULL
        GROUP BY 1 ORDER BY 1 DESC LIMIT 24
    """)


st.title("Financial & Claims")
st.caption("Revenue cycle management | Payer analysis | Denial tracking")

rev = load_revenue_summary()
if not rev.empty:
    r = rev.iloc[0]
    with st.container(horizontal=True):
        st.metric("Total Billed", f"${int(r['TOTAL_BILLED']):,}", border=True)
        st.metric("Total Paid", f"${int(r['TOTAL_PAID']):,}", border=True)
        st.metric("Write-Offs", f"${int(r['TOTAL_WRITE_OFF']):,}", border=True)
        st.metric("Collection Rate", f"{r['NET_COLLECTION_RATE']}%", border=True)
        st.metric("Total Denials", f"{int(r['TOTAL_DENIALS']):,}", border=True)

tab1, tab2, tab3 = st.tabs(["Revenue Trend", "Payer Analysis", "Denial Analysis"])

with tab1:
    monthly = load_monthly_revenue()
    if not monthly.empty:
        with st.container(border=True):
            st.subheader("Monthly Billed vs Paid")
            st.line_chart(monthly, x="SERVICE_MONTH", y=["BILLED", "PAID"])
        with st.container(border=True):
            st.subheader("Monthly Claim Volume")
            st.bar_chart(monthly, x="SERVICE_MONTH", y="CLAIMS")

with tab2:
    claims = load_claims_by_payer()
    if not claims.empty:
        payer_summary = claims.groupby("PAYER_NAME", as_index=False).agg(
            {"CLAIM_COUNT": "sum", "TOTAL_BILLED": "sum", "TOTAL_PAID": "sum", "DENIALS": "sum"})
        with st.container(border=True):
            st.subheader("Claims & Revenue by Payer")
            st.bar_chart(payer_summary, x="PAYER_NAME", y=["TOTAL_BILLED", "TOTAL_PAID"])
        st.dataframe(claims, hide_index=True, use_container_width=True)

with tab3:
    denials = load_denial_reasons()
    if not denials.empty:
        reason_summary = denials.groupby("DENIAL_REASON", as_index=False).agg(
            {"DENIAL_COUNT": "sum", "DENIED_AMOUNT": "sum"})
        with st.container(border=True):
            st.subheader("Denial Reasons")
            st.bar_chart(reason_summary, x="DENIAL_REASON", y="DENIAL_COUNT")
        st.dataframe(denials, hide_index=True, use_container_width=True)
