import streamlit as st

conn = st.session_state["conn"]


@st.cache_data(ttl=600)
def load_cohort_data():
    return conn.query("""
        SELECT p.gender, p.ethnicity,
            CASE WHEN p.age < 45 THEN '<45' WHEN p.age < 55 THEN '45-54'
                 WHEN p.age < 65 THEN '55-64' WHEN p.age < 75 THEN '65-74' ELSE '75+' END AS age_group,
            r.computed_risk AS risk_category, r.qualifying_diagnosis,
            COUNT(DISTINCT p.patient_id) AS patient_count,
            ROUND(AVG(r.lvef_percent), 1) AS avg_lvef,
            ROUND(AVG(r.gxt_peak_mets), 1) AS avg_peak_mets
        FROM HEALTH_TRANSFORM_DB.MASTER.DIM_PATIENT p
        JOIN HEALTH_TRANSFORM_DB.CLEANSED.FACT_REHAB_REFERRAL r ON p.patient_id = r.patient_id
        GROUP BY 1,2,3,4,5
    """)


@st.cache_data(ttl=600)
def load_demographics():
    return conn.query("""
        SELECT gender, ethnicity,
            CASE WHEN age < 45 THEN '<45' WHEN age < 55 THEN '45-54'
                 WHEN age < 65 THEN '55-64' WHEN age < 75 THEN '65-74' ELSE '75+' END AS age_group,
            COUNT(*) AS patient_count, ROUND(AVG(age), 1) AS avg_age
        FROM HEALTH_TRANSFORM_DB.MASTER.DIM_PATIENT WHERE is_current = TRUE
        GROUP BY 1,2,3
    """)


@st.cache_data(ttl=600)
def load_diagnosis_prevalence():
    return conn.query("""
        SELECT cardiac_category, COUNT(DISTINCT patient_id) AS patients,
               COUNT(*) AS total_diagnoses,
               ROUND(COUNT(DISTINCT patient_id) * 100.0 /
                     (SELECT COUNT(*) FROM HEALTH_TRANSFORM_DB.MASTER.DIM_PATIENT WHERE is_current = TRUE), 1) AS prevalence_pct
        FROM HEALTH_TRANSFORM_DB.CLEANSED.FACT_DIAGNOSIS
        WHERE cardiac_category IS NOT NULL
        GROUP BY cardiac_category ORDER BY patients DESC
    """)


@st.cache_data(ttl=600)
def load_comorbidity_matrix():
    return conn.query("""
        SELECT d1.cardiac_category AS condition_1, d2.cardiac_category AS condition_2,
               COUNT(DISTINCT d1.patient_id) AS co_occurrence
        FROM HEALTH_TRANSFORM_DB.CLEANSED.FACT_DIAGNOSIS d1
        JOIN HEALTH_TRANSFORM_DB.CLEANSED.FACT_DIAGNOSIS d2
            ON d1.patient_id = d2.patient_id AND d1.cardiac_category < d2.cardiac_category
        WHERE d1.cardiac_category IS NOT NULL AND d2.cardiac_category IS NOT NULL
        GROUP BY 1, 2
        HAVING co_occurrence > 5
        ORDER BY co_occurrence DESC LIMIT 20
    """)


st.title("Population Health")
st.caption("Cohort analysis | Demographics | Disease prevalence | Comorbidity patterns")

tab1, tab2, tab3 = st.tabs(["Demographics", "Disease Prevalence", "Cohort Analysis"])

with tab1:
    demo = load_demographics()
    if not demo.empty:
        col1, col2 = st.columns(2)
        with col1:
            with st.container(border=True):
                st.subheader("Patients by Age Group")
                age_df = demo.groupby("AGE_GROUP", as_index=False)["PATIENT_COUNT"].sum()
                st.bar_chart(age_df, x="AGE_GROUP", y="PATIENT_COUNT")
        with col2:
            with st.container(border=True):
                st.subheader("Patients by Gender")
                gender_df = demo.groupby("GENDER", as_index=False)["PATIENT_COUNT"].sum()
                st.bar_chart(gender_df, x="GENDER", y="PATIENT_COUNT")

        with st.container(border=True):
            st.subheader("Patients by Ethnicity")
            eth_df = demo.groupby("ETHNICITY", as_index=False)["PATIENT_COUNT"].sum()
            st.bar_chart(eth_df, x="ETHNICITY", y="PATIENT_COUNT")

with tab2:
    prev = load_diagnosis_prevalence()
    if not prev.empty:
        with st.container(border=True):
            st.subheader("Cardiac Condition Prevalence")
            st.bar_chart(prev, x="CARDIAC_CATEGORY", y="PREVALENCE_PCT")
        st.dataframe(prev, hide_index=True, use_container_width=True)

    st.subheader("Top Comorbidity Pairs")
    comorb = load_comorbidity_matrix()
    if not comorb.empty:
        st.dataframe(comorb, hide_index=True, use_container_width=True)

with tab3:
    cohort = load_cohort_data()
    if not cohort.empty:
        with st.sidebar:
            risk_filter = st.multiselect("Filter by Risk", options=cohort["RISK_CATEGORY"].unique().tolist(),
                                          default=cohort["RISK_CATEGORY"].unique().tolist())
        filtered = cohort[cohort["RISK_CATEGORY"].isin(risk_filter)]

        with st.container(horizontal=True):
            st.metric("Total Cohort", int(filtered["PATIENT_COUNT"].sum()), border=True)
            st.metric("Avg LVEF", f"{filtered['AVG_LVEF'].mean():.1f}%", border=True)
            st.metric("Avg Peak METs", f"{filtered['AVG_PEAK_METS'].mean():.1f}", border=True)

        with st.container(border=True):
            st.subheader("Cohort by Risk & Diagnosis")
            pivot = filtered.groupby(["RISK_CATEGORY", "QUALIFYING_DIAGNOSIS"], as_index=False)["PATIENT_COUNT"].sum()
            st.bar_chart(pivot, x="QUALIFYING_DIAGNOSIS", y="PATIENT_COUNT", color="RISK_CATEGORY")

        st.dataframe(filtered, hide_index=True, use_container_width=True)
