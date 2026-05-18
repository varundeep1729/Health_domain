import os
import streamlit as st

st.set_page_config(page_title="Health Domain Dashboard", page_icon="🏥", layout="wide")

conn = st.connection("snowflake", ttl=os.getenv("SNOWFLAKE_CONNECTION_TTL"))


@st.cache_data(ttl=600)
def load_patient_summary():
    return conn.query("""
        SELECT gender, ethnicity, COUNT(*) AS patient_count, ROUND(AVG(age), 1) AS avg_age
        FROM HEALTH_TRANSFORM_DB.MASTER.DIM_PATIENT
        WHERE is_current = TRUE
        GROUP BY gender, ethnicity
        ORDER BY patient_count DESC
    """)


@st.cache_data(ttl=600)
def load_rehab_program_summary():
    return conn.query("""
        SELECT
            R.computed_risk AS risk_category,
            R.qualifying_diagnosis,
            COUNT(DISTINCT R.referral_id) AS referral_count,
            ROUND(AVG(R.lvef_percent), 1) AS avg_lvef,
            ROUND(AVG(R.gxt_peak_mets), 1) AS avg_peak_mets
        FROM HEALTH_TRANSFORM_DB.CLEANSED.FACT_REHAB_REFERRAL R
        GROUP BY 1, 2
        ORDER BY referral_count DESC
    """)


@st.cache_data(ttl=600)
def load_session_metrics():
    return conn.query("""
        SELECT
            session_date,
            COUNT(*) AS sessions_conducted,
            COUNT(DISTINCT patient_id) AS unique_patients,
            ROUND(AVG(duration_minutes), 1) AS avg_duration,
            ROUND(AVG(peak_hr), 1) AS avg_peak_hr,
            ROUND(AVG(rpe_peak), 1) AS avg_rpe,
            SUM(CASE WHEN safety_flag THEN 1 ELSE 0 END) AS safety_incidents
        FROM HEALTH_TRANSFORM_DB.CLEANSED.FACT_REHAB_SESSION
        GROUP BY session_date
        ORDER BY session_date DESC
        LIMIT 60
    """)


@st.cache_data(ttl=600)
def load_kpi_metrics():
    return conn.query("""
        SELECT
            (SELECT COUNT(*) FROM HEALTH_TRANSFORM_DB.MASTER.DIM_PATIENT WHERE is_current = TRUE) AS total_patients,
            (SELECT COUNT(*) FROM HEALTH_TRANSFORM_DB.CLEANSED.FACT_ENCOUNTER) AS total_encounters,
            (SELECT COUNT(*) FROM HEALTH_TRANSFORM_DB.CLEANSED.FACT_REHAB_REFERRAL) AS total_referrals,
            (SELECT COUNT(*) FROM HEALTH_TRANSFORM_DB.CLEANSED.FACT_REHAB_SESSION) AS total_sessions,
            (SELECT ROUND(AVG(CASE WHEN safety_flag THEN 1 ELSE 0 END) * 100, 2)
             FROM HEALTH_TRANSFORM_DB.CLEANSED.FACT_REHAB_SESSION) AS safety_flag_pct,
            (SELECT COUNT(DISTINCT patient_id) FROM HEALTH_TRANSFORM_DB.CLEANSED.FACT_REHAB_SESSION) AS active_rehab_patients
    """)


@st.cache_data(ttl=600)
def load_diagnosis_distribution():
    return conn.query("""
        SELECT cardiac_category, COUNT(*) AS diagnosis_count, COUNT(DISTINCT patient_id) AS unique_patients
        FROM HEALTH_TRANSFORM_DB.CLEANSED.FACT_DIAGNOSIS
        WHERE cardiac_category IS NOT NULL
        GROUP BY cardiac_category
        ORDER BY diagnosis_count DESC
    """)


@st.cache_data(ttl=600)
def load_medication_distribution():
    return conn.query("""
        SELECT drug_class, COUNT(*) AS prescription_count, COUNT(DISTINCT patient_id) AS unique_patients
        FROM HEALTH_TRANSFORM_DB.CLEANSED.FACT_MEDICATION
        WHERE drug_class IS NOT NULL
        GROUP BY drug_class
        ORDER BY prescription_count DESC
    """)


@st.cache_data(ttl=600)
def load_claims_summary():
    return conn.query("""
        SELECT
            payer_name,
            COUNT(*) AS claim_count,
            ROUND(SUM(billed_amount), 2) AS total_billed,
            ROUND(SUM(paid_amount), 2) AS total_paid,
            SUM(CASE WHEN claim_status = 'DENIED' THEN 1 ELSE 0 END) AS denials,
            ROUND(SUM(CASE WHEN claim_status = 'DENIED' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 1) AS denial_rate_pct
        FROM HEALTH_RAW_DB.REFERENCE_DATA.RAW_CLAIMS
        GROUP BY payer_name
        ORDER BY claim_count DESC
    """)


def clear_all_caches():
    load_patient_summary.clear()
    load_rehab_program_summary.clear()
    load_session_metrics.clear()
    load_kpi_metrics.clear()
    load_diagnosis_distribution.clear()
    load_medication_distribution.clear()
    load_claims_summary.clear()


st.title("Health Domain - Cardiac Rehabilitation Dashboard")
st.caption("HIPAA-compliant clinical analytics | AACVPR-aligned outcomes tracking")

with st.sidebar:
    st.header("Controls")
    st.button("Refresh Data", on_click=clear_all_caches)
    st.divider()
    st.markdown("**Database:** HEALTH_TRANSFORM_DB")
    st.markdown("**Schemas:** MASTER, CLEANSED")
    st.markdown("**Source:** PyHealth + AACVPR Skills")

with st.spinner("Loading KPIs..."):
    kpis = load_kpi_metrics()

if not kpis.empty:
    row = kpis.iloc[0]
    with st.container(horizontal=True):
        st.metric("Total Patients", f"{int(row['TOTAL_PATIENTS']):,}", border=True)
        st.metric("Total Encounters", f"{int(row['TOTAL_ENCOUNTERS']):,}", border=True)
        st.metric("Rehab Referrals", f"{int(row['TOTAL_REFERRALS']):,}", border=True)
        st.metric("Rehab Sessions", f"{int(row['TOTAL_SESSIONS']):,}", border=True)
        st.metric("Active Rehab Patients", f"{int(row['ACTIVE_REHAB_PATIENTS']):,}", border=True)
        st.metric("Safety Flag Rate", f"{row['SAFETY_FLAG_PCT']}%", border=True)

tab1, tab2, tab3, tab4, tab5 = st.tabs([
    "Session Trends", "Diagnoses & Meds", "Rehab Programs", "Claims", "Patient Demographics"
])

with tab1:
    st.subheader("Daily Cardiac Rehab Session Metrics")
    with st.spinner("Loading session data..."):
        sessions = load_session_metrics()
    if not sessions.empty:
        col1, col2 = st.columns(2)
        with col1:
            with st.container(border=True):
                st.markdown("**Sessions & Patients per Day**")
                st.line_chart(sessions, x="SESSION_DATE", y=["SESSIONS_CONDUCTED", "UNIQUE_PATIENTS"])
        with col2:
            with st.container(border=True):
                st.markdown("**Avg Peak HR & RPE Trend**")
                st.line_chart(sessions, x="SESSION_DATE", y=["AVG_PEAK_HR", "AVG_RPE"])
        with st.container(border=True):
            st.markdown("**Safety Incidents per Day**")
            st.bar_chart(sessions, x="SESSION_DATE", y="SAFETY_INCIDENTS")

with tab2:
    col1, col2 = st.columns(2)
    with col1:
        st.subheader("Cardiac Diagnosis Distribution")
        with st.spinner("Loading diagnoses..."):
            dx = load_diagnosis_distribution()
        if not dx.empty:
            st.bar_chart(dx, x="CARDIAC_CATEGORY", y="DIAGNOSIS_COUNT")
            st.dataframe(dx, hide_index=True, use_container_width=True)
    with col2:
        st.subheader("Medication Drug Class Distribution")
        with st.spinner("Loading medications..."):
            meds = load_medication_distribution()
        if not meds.empty:
            st.bar_chart(meds, x="DRUG_CLASS", y="PRESCRIPTION_COUNT")
            st.dataframe(meds, hide_index=True, use_container_width=True)

with tab3:
    st.subheader("Cardiac Rehab Program Summary (by Risk & Diagnosis)")
    with st.spinner("Loading rehab programs..."):
        rehab = load_rehab_program_summary()
    if not rehab.empty:
        with st.container(horizontal=True):
            for risk in ["LOW", "MODERATE", "HIGH"]:
                subset = rehab[rehab["RISK_CATEGORY"] == risk]
                count = int(subset["REFERRAL_COUNT"].sum()) if not subset.empty else 0
                st.metric(f"{risk} Risk Referrals", count, border=True)
        st.dataframe(rehab, hide_index=True, use_container_width=True)

with tab4:
    st.subheader("Claims Summary by Payer")
    with st.spinner("Loading claims..."):
        claims = load_claims_summary()
    if not claims.empty:
        col1, col2 = st.columns(2)
        with col1:
            with st.container(border=True):
                st.markdown("**Claims by Payer**")
                st.bar_chart(claims, x="PAYER_NAME", y="CLAIM_COUNT")
        with col2:
            with st.container(border=True):
                st.markdown("**Denial Rate by Payer (%)**")
                st.bar_chart(claims, x="PAYER_NAME", y="DENIAL_RATE_PCT")
        st.dataframe(claims, hide_index=True, use_container_width=True)

with tab5:
    st.subheader("Patient Demographics")
    with st.spinner("Loading demographics..."):
        patients = load_patient_summary()
    if not patients.empty:
        col1, col2 = st.columns(2)
        with col1:
            with st.container(border=True):
                st.markdown("**Patients by Gender**")
                gender_df = patients.groupby("GENDER", as_index=False)["PATIENT_COUNT"].sum()
                st.bar_chart(gender_df, x="GENDER", y="PATIENT_COUNT")
        with col2:
            with st.container(border=True):
                st.markdown("**Patients by Ethnicity**")
                eth_df = patients.groupby("ETHNICITY", as_index=False)["PATIENT_COUNT"].sum()
                st.bar_chart(eth_df, x="ETHNICITY", y="PATIENT_COUNT")
        st.dataframe(patients, hide_index=True, use_container_width=True)
