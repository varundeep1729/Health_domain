import streamlit as st

conn = st.session_state["conn"]


@st.cache_data(ttl=600)
def load_kpis():
    return conn.query("""
        SELECT
            (SELECT COUNT(*) FROM HEALTH_TRANSFORM_DB.MASTER.DIM_PATIENT WHERE is_current = TRUE) AS total_patients,
            (SELECT COUNT(*) FROM HEALTH_TRANSFORM_DB.CLEANSED.FACT_ENCOUNTER) AS total_encounters,
            (SELECT COUNT(*) FROM HEALTH_TRANSFORM_DB.CLEANSED.FACT_REHAB_REFERRAL) AS total_referrals,
            (SELECT COUNT(*) FROM HEALTH_TRANSFORM_DB.CLEANSED.FACT_REHAB_SESSION) AS total_sessions,
            (SELECT COUNT(*) FROM HEALTH_TRANSFORM_DB.CLEANSED.FACT_DIAGNOSIS) AS total_diagnoses,
            (SELECT COUNT(*) FROM HEALTH_TRANSFORM_DB.CLEANSED.FACT_MEDICATION) AS total_medications,
            (SELECT COUNT(*) FROM HEALTH_TRANSFORM_DB.CLEANSED.FACT_LAB_RESULT) AS total_labs,
            (SELECT COUNT(*) FROM HEALTH_RAW_DB.REFERENCE_DATA.RAW_CLAIMS) AS total_claims,
            (SELECT ROUND(AVG(CASE WHEN safety_flag THEN 1.0 ELSE 0.0 END) * 100, 2) FROM HEALTH_TRANSFORM_DB.CLEANSED.FACT_REHAB_SESSION) AS safety_pct,
            (SELECT ROUND(AVG(CASE WHEN discharge_status = 'EXPIRED' THEN 1.0 ELSE 0.0 END) * 100, 2) FROM HEALTH_TRANSFORM_DB.CLEANSED.FACT_ENCOUNTER) AS mortality_pct,
            (SELECT ROUND(AVG(CASE WHEN claim_status = 'DENIED' THEN 1.0 ELSE 0.0 END) * 100, 1) FROM HEALTH_RAW_DB.REFERENCE_DATA.RAW_CLAIMS) AS denial_pct,
            (SELECT COUNT(DISTINCT patient_id) FROM HEALTH_TRANSFORM_DB.CLEANSED.FACT_REHAB_SESSION) AS active_rehab
    """)


@st.cache_data(ttl=600)
def load_daily_sessions():
    return conn.query("""
        SELECT session_date, COUNT(*) AS sessions, COUNT(DISTINCT patient_id) AS patients,
               ROUND(AVG(peak_hr), 1) AS avg_peak_hr, SUM(CASE WHEN safety_flag THEN 1 ELSE 0 END) AS safety_events
        FROM HEALTH_TRANSFORM_DB.CLEANSED.FACT_REHAB_SESSION
        GROUP BY session_date ORDER BY session_date DESC LIMIT 90
    """)


@st.cache_data(ttl=600)
def load_risk_distribution():
    return conn.query("""
        SELECT computed_risk AS risk_category, COUNT(*) AS count
        FROM HEALTH_TRANSFORM_DB.CLEANSED.FACT_REHAB_REFERRAL
        GROUP BY computed_risk ORDER BY count DESC
    """)


@st.cache_data(ttl=600)
def load_encounter_types():
    return conn.query("""
        SELECT encounter_type, COUNT(*) AS count
        FROM HEALTH_TRANSFORM_DB.CLEANSED.FACT_ENCOUNTER
        GROUP BY encounter_type ORDER BY count DESC
    """)


def clear_caches():
    load_kpis.clear()
    load_daily_sessions.clear()
    load_risk_distribution.clear()
    load_encounter_types.clear()


st.title("Executive Summary")
st.caption("Health Domain Platform | Real-time clinical operations overview")
st.button("Refresh", on_click=clear_caches, type="secondary")

with st.spinner("Loading platform metrics..."):
    kpis = load_kpis()

if not kpis.empty:
    row = kpis.iloc[0]
    st.subheader("Platform Scale")
    with st.container(horizontal=True):
        st.metric("Patients", f"{int(row['TOTAL_PATIENTS']):,}", border=True)
        st.metric("Encounters", f"{int(row['TOTAL_ENCOUNTERS']):,}", border=True)
        st.metric("Diagnoses", f"{int(row['TOTAL_DIAGNOSES']):,}", border=True)
        st.metric("Medications", f"{int(row['TOTAL_MEDICATIONS']):,}", border=True)
        st.metric("Lab Results", f"{int(row['TOTAL_LABS']):,}", border=True)
        st.metric("Claims", f"{int(row['TOTAL_CLAIMS']):,}", border=True)

    st.subheader("Cardiac Rehabilitation")
    with st.container(horizontal=True):
        st.metric("Rehab Referrals", f"{int(row['TOTAL_REFERRALS']):,}", border=True)
        st.metric("Rehab Sessions", f"{int(row['TOTAL_SESSIONS']):,}", border=True)
        st.metric("Active Patients", f"{int(row['ACTIVE_REHAB']):,}", border=True)
        st.metric("Safety Flag Rate", f"{row['SAFETY_PCT']}%", border=True)

    st.subheader("Risk Indicators")
    with st.container(horizontal=True):
        st.metric("Mortality Rate", f"{row['MORTALITY_PCT']}%", border=True)
        st.metric("Claims Denial Rate", f"{row['DENIAL_PCT']}%", border=True)

st.divider()
col1, col2 = st.columns(2)

with col1:
    with st.container(border=True):
        st.subheader("Daily Rehab Sessions (90 days)")
        sessions = load_daily_sessions()
        if not sessions.empty:
            st.line_chart(sessions, x="SESSION_DATE", y=["SESSIONS", "PATIENTS"])

with col2:
    with st.container(border=True):
        st.subheader("Safety Events Trend")
        if not sessions.empty:
            st.bar_chart(sessions, x="SESSION_DATE", y="SAFETY_EVENTS", color="#FF4B4B")

col3, col4 = st.columns(2)
with col3:
    with st.container(border=True):
        st.subheader("AACVPR Risk Distribution")
        risk = load_risk_distribution()
        if not risk.empty:
            st.bar_chart(risk, x="RISK_CATEGORY", y="COUNT")

with col4:
    with st.container(border=True):
        st.subheader("Encounter Types")
        enc = load_encounter_types()
        if not enc.empty:
            st.bar_chart(enc, x="ENCOUNTER_TYPE", y="COUNT")
