import streamlit as st

conn = st.session_state["conn"]


@st.cache_data(ttl=600)
def load_patient_list():
    return conn.query("""
        SELECT patient_id, first_name || ' ' || last_name AS patient_name, age, gender, ethnicity
        FROM HEALTH_TRANSFORM_DB.MASTER.DIM_PATIENT
        WHERE is_current = TRUE
        AND patient_id IN (SELECT DISTINCT patient_id FROM HEALTH_TRANSFORM_DB.CLEANSED.FACT_REHAB_REFERRAL)
        ORDER BY patient_id LIMIT 500
    """)


@st.cache_data(ttl=600)
def load_patient_sessions(patient_id):
    return conn.query(
        """
        SELECT session_number, session_date, modality, duration_minutes, resting_hr, peak_hr,
               recovery_hr, hr_recovery_delta, rpe_peak, spo2_min, achieved_hrr_percent, safety_flag,
               resting_bp_systolic, peak_bp_systolic, ecg_rhythm
        FROM HEALTH_TRANSFORM_DB.CLEANSED.FACT_REHAB_SESSION
        WHERE patient_id = :1
        ORDER BY session_number
        """,
        params=[patient_id],
    )


@st.cache_data(ttl=600)
def load_patient_outcomes(patient_id):
    return conn.query(
        """
        SELECT measurement_point, six_min_walk_meters, peak_mets, dasi_score, phq9_score,
               weight_kg, bmi, hba1c, ldl, hdl, total_cholesterol, depression_severity
        FROM HEALTH_TRANSFORM_DB.CLEANSED.FACT_REHAB_OUTCOME
        WHERE patient_id = :1
        ORDER BY measurement_point
        """,
        params=[patient_id],
    )


@st.cache_data(ttl=600)
def load_patient_referral(patient_id):
    return conn.query(
        """
        SELECT referral_id, qualifying_diagnosis, cardiac_event_date, lvef_percent,
               gxt_peak_hr, gxt_peak_mets, computed_risk, referral_date, days_event_to_referral
        FROM HEALTH_TRANSFORM_DB.CLEANSED.FACT_REHAB_REFERRAL
        WHERE patient_id = :1
        LIMIT 1
        """,
        params=[patient_id],
    )


@st.cache_data(ttl=600)
def load_patient_medications(patient_id):
    return conn.query(
        """
        SELECT medication_name, drug_class, dosage, route, frequency, start_date
        FROM HEALTH_TRANSFORM_DB.CLEANSED.FACT_MEDICATION
        WHERE patient_id = :1
        ORDER BY start_date DESC LIMIT 20
        """,
        params=[patient_id],
    )


@st.cache_data(ttl=600)
def load_patient_diagnoses(patient_id):
    return conn.query(
        """
        SELECT icd_code, description, cardiac_category, diagnosis_type, diagnosis_date
        FROM HEALTH_TRANSFORM_DB.CLEANSED.FACT_DIAGNOSIS
        WHERE patient_id = :1
        ORDER BY diagnosis_date DESC LIMIT 20
        """,
        params=[patient_id],
    )


st.title("Clinical Analytics")
st.caption("Patient-level cardiac rehabilitation drill-down | Hemodynamic trends & outcome tracking")

patients = load_patient_list()
if patients.empty:
    st.warning("No rehab patients found.")
    st.stop()

with st.sidebar:
    st.subheader("Patient Selection")
    patient_options = dict(zip(patients["PATIENT_ID"], patients["PATIENT_NAME"]))
    selected_id = st.selectbox("Select Patient", options=list(patient_options.keys()),
                                format_func=lambda x: f"{x} - {patient_options[x]}")

referral = load_patient_referral(selected_id)
patient_info = patients[patients["PATIENT_ID"] == selected_id].iloc[0]

st.subheader(f"Patient: {patient_info['PATIENT_NAME']}")
with st.container(horizontal=True):
    st.metric("Age", patient_info["AGE"], border=True)
    st.metric("Gender", patient_info["GENDER"], border=True)
    st.metric("Ethnicity", patient_info["ETHNICITY"], border=True)
    if not referral.empty:
        r = referral.iloc[0]
        st.metric("Risk Category", r["COMPUTED_RISK"], border=True)
        st.metric("LVEF %", f"{r['LVEF_PERCENT']}%", border=True)
        st.metric("Peak METs", r["GXT_PEAK_METS"], border=True)
        st.metric("Qualifying Dx", r["QUALIFYING_DIAGNOSIS"], border=True)

tab1, tab2, tab3, tab4 = st.tabs(["Hemodynamic Trends", "Outcomes", "Medications", "Diagnoses"])

with tab1:
    sessions = load_patient_sessions(selected_id)
    if sessions.empty:
        st.info("No rehab sessions found for this patient.")
    else:
        col1, col2 = st.columns(2)
        with col1:
            with st.container(border=True):
                st.markdown("**Heart Rate Progression**")
                st.line_chart(sessions, x="SESSION_NUMBER", y=["RESTING_HR", "PEAK_HR", "RECOVERY_HR"])
        with col2:
            with st.container(border=True):
                st.markdown("**RPE & HRR% Progression**")
                st.line_chart(sessions, x="SESSION_NUMBER", y=["RPE_PEAK", "ACHIEVED_HRR_PERCENT"])

        col3, col4 = st.columns(2)
        with col3:
            with st.container(border=True):
                st.markdown("**Blood Pressure Trend**")
                st.line_chart(sessions, x="SESSION_NUMBER", y=["RESTING_BP_SYSTOLIC", "PEAK_BP_SYSTOLIC"])
        with col4:
            with st.container(border=True):
                st.markdown("**SpO2 & Duration**")
                st.line_chart(sessions, x="SESSION_NUMBER", y=["SPO2_MIN", "DURATION_MINUTES"])

        with st.container(border=True):
            st.markdown("**Session Detail Table**")
            st.dataframe(sessions, hide_index=True, use_container_width=True)

with tab2:
    outcomes = load_patient_outcomes(selected_id)
    if outcomes.empty:
        st.info("No outcome measurements found.")
    else:
        st.subheader("Baseline vs Discharge Comparison")
        baseline = outcomes[outcomes["MEASUREMENT_POINT"] == "BASELINE"]
        discharge = outcomes[outcomes["MEASUREMENT_POINT"] == "DISCHARGE"]

        if not baseline.empty and not discharge.empty:
            b = baseline.iloc[0]
            d = discharge.iloc[0]
            with st.container(horizontal=True):
                delta_6mwt = int(d["SIX_MIN_WALK_METERS"] - b["SIX_MIN_WALK_METERS"]) if d["SIX_MIN_WALK_METERS"] and b["SIX_MIN_WALK_METERS"] else None
                st.metric("6MWT (m)", f"{int(d['SIX_MIN_WALK_METERS'])}", delta=f"+{delta_6mwt}m" if delta_6mwt else None, border=True)
                delta_mets = round(d["PEAK_METS"] - b["PEAK_METS"], 1) if d["PEAK_METS"] and b["PEAK_METS"] else None
                st.metric("Peak METs", f"{d['PEAK_METS']}", delta=f"+{delta_mets}" if delta_mets else None, border=True)
                delta_phq = int(d["PHQ9_SCORE"] - b["PHQ9_SCORE"]) if d["PHQ9_SCORE"] is not None and b["PHQ9_SCORE"] is not None else None
                st.metric("PHQ-9", f"{int(d['PHQ9_SCORE'])}", delta=f"{delta_phq}" if delta_phq else None, delta_color="inverse", border=True)
                delta_bmi = round(d["BMI"] - b["BMI"], 1) if d["BMI"] and b["BMI"] else None
                st.metric("BMI", f"{d['BMI']}", delta=f"{delta_bmi}" if delta_bmi else None, delta_color="inverse", border=True)
                delta_ldl = int(d["LDL"] - b["LDL"]) if d["LDL"] and b["LDL"] else None
                st.metric("LDL", f"{int(d['LDL'])}", delta=f"{delta_ldl}" if delta_ldl else None, delta_color="inverse", border=True)

            mcid = "CLINICALLY SIGNIFICANT" if delta_6mwt and delta_6mwt >= 25 else "Not significant"
            st.info(f"6MWT MCID Assessment: **{mcid}** (threshold: +25m)")

        st.dataframe(outcomes, hide_index=True, use_container_width=True)

with tab3:
    meds = load_patient_medications(selected_id)
    if meds.empty:
        st.info("No medications found.")
    else:
        st.dataframe(meds, hide_index=True, use_container_width=True)

with tab4:
    dx = load_patient_diagnoses(selected_id)
    if dx.empty:
        st.info("No diagnoses found.")
    else:
        st.dataframe(dx, hide_index=True, use_container_width=True)
