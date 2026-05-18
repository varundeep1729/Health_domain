import streamlit as st

conn = st.session_state["conn"]


@st.cache_data(ttl=600)
def load_cms_metrics():
    return conn.query("""
        SELECT
            DATE_TRUNC('MONTH', R.referral_date)::DATE AS referral_month,
            COUNT(DISTINCT R.referral_id) AS total_referrals,
            COUNT(DISTINCT S.referral_id) AS referrals_with_sessions,
            ROUND(COUNT(DISTINCT S.referral_id) * 100.0 / NULLIF(COUNT(DISTINCT R.referral_id), 0), 1) AS enrollment_rate_pct,
            ROUND(AVG(R.days_event_to_referral), 1) AS avg_days_to_referral,
            COUNT(DISTINCT CASE WHEN PS.total_sessions >= 36 THEN R.referral_id END) AS completed_programs
        FROM HEALTH_TRANSFORM_DB.CLEANSED.FACT_REHAB_REFERRAL R
        LEFT JOIN HEALTH_TRANSFORM_DB.CLEANSED.FACT_REHAB_SESSION S ON R.referral_id = S.referral_id
        LEFT JOIN (SELECT referral_id, COUNT(*) AS total_sessions FROM HEALTH_TRANSFORM_DB.CLEANSED.FACT_REHAB_SESSION GROUP BY 1) PS
            ON R.referral_id = PS.referral_id
        GROUP BY 1 ORDER BY 1 DESC
    """)


@st.cache_data(ttl=600)
def load_adherence_stats():
    return conn.query("""
        SELECT
            R.computed_risk AS risk_category,
            COUNT(DISTINCT R.referral_id) AS total_programs,
            ROUND(AVG(S.session_count), 1) AS avg_sessions,
            ROUND(AVG(S.session_count) * 100.0 / 36, 1) AS avg_adherence_pct,
            SUM(CASE WHEN S.session_count >= 36 THEN 1 ELSE 0 END) AS completed,
            ROUND(SUM(CASE WHEN S.session_count >= 36 THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 1) AS completion_rate
        FROM HEALTH_TRANSFORM_DB.CLEANSED.FACT_REHAB_REFERRAL R
        LEFT JOIN (SELECT referral_id, COUNT(*) AS session_count FROM HEALTH_TRANSFORM_DB.CLEANSED.FACT_REHAB_SESSION GROUP BY 1) S
            ON R.referral_id = S.referral_id
        GROUP BY 1
    """)


@st.cache_data(ttl=600)
def load_safety_metrics():
    return conn.query("""
        SELECT
            modality,
            COUNT(*) AS total_sessions,
            SUM(CASE WHEN safety_flag THEN 1 ELSE 0 END) AS safety_events,
            ROUND(SUM(CASE WHEN safety_flag THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS safety_rate_pct,
            SUM(CASE WHEN exercise_terminated_early THEN 1 ELSE 0 END) AS early_terminations,
            ROUND(AVG(ecg_monitor_minutes), 1) AS avg_ecg_minutes
        FROM HEALTH_TRANSFORM_DB.CLEANSED.FACT_REHAB_SESSION
        GROUP BY modality ORDER BY total_sessions DESC
    """)


@st.cache_data(ttl=600)
def load_outcome_improvement():
    return conn.query("""
        SELECT
            R.computed_risk,
            ROUND(AVG(D.six_min_walk_meters - B.six_min_walk_meters), 1) AS avg_6mwt_change,
            ROUND(AVG(D.peak_mets - B.peak_mets), 2) AS avg_mets_change,
            ROUND(AVG(D.phq9_score - B.phq9_score), 1) AS avg_phq9_change,
            SUM(CASE WHEN (D.six_min_walk_meters - B.six_min_walk_meters) >= 25 THEN 1 ELSE 0 END) AS mcid_met,
            COUNT(*) AS total_measured,
            ROUND(SUM(CASE WHEN (D.six_min_walk_meters - B.six_min_walk_meters) >= 25 THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 1) AS mcid_rate
        FROM HEALTH_TRANSFORM_DB.CLEANSED.FACT_REHAB_REFERRAL R
        JOIN HEALTH_TRANSFORM_DB.CLEANSED.FACT_REHAB_OUTCOME B ON R.referral_id = B.referral_id AND B.measurement_point = 'BASELINE'
        JOIN HEALTH_TRANSFORM_DB.CLEANSED.FACT_REHAB_OUTCOME D ON R.referral_id = D.referral_id AND D.measurement_point = 'DISCHARGE'
        GROUP BY R.computed_risk
    """)


st.title("Quality Measures")
st.caption("CMS Cardiac Rehabilitation | AACVPR Certification | HEDIS Metrics")

tab1, tab2, tab3, tab4 = st.tabs(["CMS Enrollment", "Adherence & Completion", "Safety Monitoring", "Outcome MCID"])

with tab1:
    cms = load_cms_metrics()
    if not cms.empty:
        latest = cms.iloc[0] if not cms.empty else None
        if latest is not None:
            with st.container(horizontal=True):
                st.metric("Monthly Referrals", int(latest["TOTAL_REFERRALS"]), border=True)
                st.metric("Enrollment Rate", f"{latest['ENROLLMENT_RATE_PCT']}%", border=True)
                st.metric("Avg Days to Referral", f"{latest['AVG_DAYS_TO_REFERRAL']}", border=True)

        with st.container(border=True):
            st.subheader("Enrollment Rate Trend (Monthly)")
            st.line_chart(cms, x="REFERRAL_MONTH", y="ENROLLMENT_RATE_PCT")

        st.dataframe(cms, hide_index=True, use_container_width=True)

with tab2:
    adherence = load_adherence_stats()
    if not adherence.empty:
        with st.container(horizontal=True):
            for _, row in adherence.iterrows():
                st.metric(f"{row['RISK_CATEGORY']} Completion", f"{row['COMPLETION_RATE']}%", border=True)

        with st.container(border=True):
            st.subheader("Average Sessions & Adherence by Risk")
            st.bar_chart(adherence, x="RISK_CATEGORY", y="AVG_ADHERENCE_PCT")

        st.dataframe(adherence, hide_index=True, use_container_width=True)

with tab3:
    safety = load_safety_metrics()
    if not safety.empty:
        with st.container(border=True):
            st.subheader("Safety Rate by Modality")
            st.bar_chart(safety, x="MODALITY", y="SAFETY_RATE_PCT")

        st.dataframe(safety, hide_index=True, use_container_width=True)

with tab4:
    outcomes = load_outcome_improvement()
    if not outcomes.empty:
        with st.container(horizontal=True):
            for _, row in outcomes.iterrows():
                st.metric(f"{row['COMPUTED_RISK']} MCID Rate", f"{row['MCID_RATE']}%", border=True)

        with st.container(border=True):
            st.subheader("Average 6MWT Improvement by Risk (meters)")
            st.bar_chart(outcomes, x="COMPUTED_RISK", y="AVG_6MWT_CHANGE")

        st.info("MCID (Minimal Clinically Important Difference) for 6MWT = +25 meters (AACVPR)")
        st.dataframe(outcomes, hide_index=True, use_container_width=True)
