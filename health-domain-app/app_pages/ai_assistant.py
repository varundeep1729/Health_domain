import streamlit as st

conn = st.session_state["conn"]

st.title("AI Assistant")
st.caption("Cortex-powered clinical intelligence | Natural language queries | AI analysis")

tab1, tab2, tab3 = st.tabs(["Clinical Chat", "AI Summarize Notes", "AI Classify & Analyze"])

with tab1:
    st.subheader("Ask questions about your cardiac rehab data")
    st.markdown("""
    **Example questions:**
    - How many patients have HIGH risk and LVEF below 35%?
    - What is the average 6MWT improvement for STEMI patients?
    - Which payer has the highest denial rate?
    - Show me patients with safety flags in the last 30 days
    - What medications are most prescribed to heart failure patients?
    """)

    if "chat_history" not in st.session_state:
        st.session_state.chat_history = []

    for msg in st.session_state.chat_history:
        with st.chat_message(msg["role"]):
            if msg["role"] == "assistant" and "dataframe" in msg:
                st.dataframe(msg["dataframe"], hide_index=True, use_container_width=True)
            st.markdown(msg["content"])

    user_input = st.chat_input("Ask a clinical question...")

    if user_input:
        st.session_state.chat_history.append({"role": "user", "content": user_input})
        with st.chat_message("user"):
            st.markdown(user_input)

        with st.chat_message("assistant"):
            with st.spinner("Cortex AI is thinking..."):
                try:
                    result = conn.query(
                        """
                        SELECT SNOWFLAKE.CORTEX.COMPLETE(
                            'mistral-large2',
                            CONCAT(
                                'You are a clinical data analyst for a cardiac rehabilitation program. ',
                                'You have access to these tables in Snowflake:\n',
                                '- HEALTH_TRANSFORM_DB.MASTER.DIM_PATIENT (patient_id, first_name, last_name, age, gender, ethnicity)\n',
                                '- HEALTH_TRANSFORM_DB.CLEANSED.FACT_ENCOUNTER (encounter_id, patient_id, encounter_type, department, length_of_stay_days, discharge_status)\n',
                                '- HEALTH_TRANSFORM_DB.CLEANSED.FACT_DIAGNOSIS (patient_id, icd_code, description, cardiac_category)\n',
                                '- HEALTH_TRANSFORM_DB.CLEANSED.FACT_MEDICATION (patient_id, medication_name, drug_class)\n',
                                '- HEALTH_TRANSFORM_DB.CLEANSED.FACT_REHAB_REFERRAL (patient_id, referral_id, qualifying_diagnosis, lvef_percent, gxt_peak_mets, computed_risk)\n',
                                '- HEALTH_TRANSFORM_DB.CLEANSED.FACT_REHAB_SESSION (patient_id, referral_id, session_number, peak_hr, rpe_peak, achieved_hrr_percent, safety_flag, duration_minutes)\n',
                                '- HEALTH_TRANSFORM_DB.CLEANSED.FACT_REHAB_OUTCOME (referral_id, measurement_point, six_min_walk_meters, peak_mets, phq9_score, bmi)\n',
                                '- HEALTH_RAW_DB.REFERENCE_DATA.RAW_CLAIMS (patient_id, payer_name, billed_amount, paid_amount, claim_status, denial_reason)\n',
                                '\nUser question: ', :1,
                                '\n\nGenerate a valid Snowflake SQL query to answer this question. Return ONLY the SQL query, no explanation. Use fully qualified table names.'
                            )
                        ) AS sql_response
                        """,
                        params=[user_input],
                    )

                    if not result.empty:
                        generated_sql = result.iloc[0]["SQL_RESPONSE"]
                        generated_sql = generated_sql.strip().strip("```sql").strip("```").strip()

                        st.code(generated_sql, language="sql")

                        try:
                            query_result = conn.query(generated_sql)
                            if not query_result.empty:
                                st.dataframe(query_result, hide_index=True, use_container_width=True)
                                summary = f"Query returned {len(query_result)} rows."
                                st.session_state.chat_history.append({
                                    "role": "assistant",
                                    "content": f"```sql\n{generated_sql}\n```\n\n{summary}",
                                    "dataframe": query_result
                                })
                            else:
                                st.info("Query executed successfully but returned no results.")
                                st.session_state.chat_history.append({
                                    "role": "assistant",
                                    "content": f"```sql\n{generated_sql}\n```\n\nNo results returned."
                                })
                        except Exception as query_err:
                            st.error(f"SQL execution error: {query_err}")
                            st.session_state.chat_history.append({
                                "role": "assistant",
                                "content": f"Generated SQL had an error: {query_err}"
                            })
                except Exception as e:
                    st.error(f"Cortex AI error: {e}")
                    st.session_state.chat_history.append({
                        "role": "assistant",
                        "content": f"Error: {e}"
                    })

with tab2:
    st.subheader("AI-Powered Clinical Note Summarization")
    st.markdown("Uses **SNOWFLAKE.CORTEX.SUMMARIZE** to condense clinical notes.")

    note_limit = st.slider("Number of notes to summarize", 1, 20, 5)

    if st.button("Load & Summarize Notes", type="primary"):
        with st.spinner("Loading clinical notes and generating AI summaries..."):
            try:
                notes = conn.query(
                    """
                    SELECT note_id, patient_id, note_type, authored_at,
                           LEFT(note_text, 2000) AS note_text,
                           SNOWFLAKE.CORTEX.SUMMARIZE(note_text) AS ai_summary
                    FROM HEALTH_RAW_DB.CLINICAL_DATA.RAW_CLINICAL_NOTES
                    WHERE note_text IS NOT NULL
                    ORDER BY authored_at DESC
                    LIMIT :1
                    """,
                    params=[note_limit],
                )

                if not notes.empty:
                    for _, note in notes.iterrows():
                        with st.container(border=True):
                            col1, col2, col3 = st.columns([1, 1, 1])
                            with col1:
                                st.markdown(f"**{note['NOTE_TYPE']}**")
                            with col2:
                                st.markdown(f"Patient: `{note['PATIENT_ID']}`")
                            with col3:
                                st.markdown(f"Date: {note['AUTHORED_AT']}")
                            st.markdown("**AI Summary:**")
                            st.success(note["AI_SUMMARY"])
                            with st.expander("View Original Note"):
                                st.text(note["NOTE_TEXT"])
                else:
                    st.warning("No clinical notes found. Run Phase 04B data scale-up first.")
            except Exception as e:
                st.error(f"Error: {e}")

with tab3:
    st.subheader("AI Classification & Sentiment Analysis")

    col1, col2 = st.columns(2)

    with col1:
        st.markdown("#### AI Risk Classification")
        st.markdown("Uses **SNOWFLAKE.CORTEX.COMPLETE** to classify patient risk from clinical features.")

        if st.button("Run AI Risk Assessment", type="primary"):
            with st.spinner("Running Cortex AI risk classification..."):
                try:
                    risk_assessment = conn.query("""
                        SELECT
                            r.patient_id,
                            r.qualifying_diagnosis,
                            r.lvef_percent,
                            r.gxt_peak_mets,
                            r.computed_risk AS rule_based_risk,
                            SNOWFLAKE.CORTEX.COMPLETE(
                                'mistral-large2',
                                CONCAT(
                                    'Classify this cardiac rehab patient risk as LOW, MODERATE, or HIGH based on AACVPR guidelines. ',
                                    'LVEF: ', r.lvef_percent::VARCHAR, '%, ',
                                    'Peak METs: ', r.gxt_peak_mets::VARCHAR, ', ',
                                    'Diagnosis: ', r.qualifying_diagnosis,
                                    '. Respond with only: LOW, MODERATE, or HIGH'
                                )
                            ) AS ai_risk_classification
                        FROM HEALTH_TRANSFORM_DB.CLEANSED.FACT_REHAB_REFERRAL r
                        ORDER BY RANDOM()
                        LIMIT 10
                    """)

                    if not risk_assessment.empty:
                        st.dataframe(risk_assessment, hide_index=True, use_container_width=True)
                        agreement = risk_assessment.apply(
                            lambda row: row["RULE_BASED_RISK"].strip() in row["AI_RISK_CLASSIFICATION"], axis=1
                        ).mean() * 100
                        st.metric("AI vs Rule Agreement", f"{agreement:.0f}%")
                except Exception as e:
                    st.error(f"Error: {e}")

    with col2:
        st.markdown("#### AI Sentiment on Clinical Notes")
        st.markdown("Uses **SNOWFLAKE.CORTEX.SENTIMENT** to assess patient progress tone.")

        if st.button("Analyze Note Sentiment", type="primary"):
            with st.spinner("Running sentiment analysis..."):
                try:
                    sentiment = conn.query("""
                        SELECT
                            note_id,
                            note_type,
                            patient_id,
                            LEFT(note_text, 200) AS note_preview,
                            SNOWFLAKE.CORTEX.SENTIMENT(note_text) AS sentiment_score
                        FROM HEALTH_RAW_DB.CLINICAL_DATA.RAW_CLINICAL_NOTES
                        WHERE note_text IS NOT NULL
                        ORDER BY authored_at DESC
                        LIMIT 15
                    """)

                    if not sentiment.empty:
                        sentiment["SENTIMENT_LABEL"] = sentiment["SENTIMENT_SCORE"].apply(
                            lambda x: "POSITIVE" if x > 0.2 else ("NEGATIVE" if x < -0.2 else "NEUTRAL")
                        )
                        st.dataframe(sentiment[["NOTE_TYPE", "PATIENT_ID", "SENTIMENT_SCORE", "SENTIMENT_LABEL", "NOTE_PREVIEW"]],
                                     hide_index=True, use_container_width=True)

                        pos = (sentiment["SENTIMENT_LABEL"] == "POSITIVE").sum()
                        neg = (sentiment["SENTIMENT_LABEL"] == "NEGATIVE").sum()
                        neu = (sentiment["SENTIMENT_LABEL"] == "NEUTRAL").sum()
                        with st.container(horizontal=True):
                            st.metric("Positive", pos, border=True)
                            st.metric("Neutral", neu, border=True)
                            st.metric("Negative", neg, border=True)
                except Exception as e:
                    st.error(f"Error: {e}")

    st.divider()
    st.markdown("#### AI Extract Key Entities")
    st.markdown("Uses **SNOWFLAKE.CORTEX.COMPLETE** to extract clinical entities from notes.")

    if st.button("Extract Entities from Notes"):
        with st.spinner("Extracting clinical entities..."):
            try:
                entities = conn.query("""
                    SELECT
                        note_id, note_type, patient_id,
                        SNOWFLAKE.CORTEX.COMPLETE(
                            'mistral-large2',
                            CONCAT(
                                'Extract the following from this clinical note in JSON format: ',
                                '{"diagnoses": [], "medications": [], "vitals": [], "procedures": [], "follow_up": ""}. ',
                                'Note: ', LEFT(note_text, 1500)
                            )
                        ) AS extracted_entities
                    FROM HEALTH_RAW_DB.CLINICAL_DATA.RAW_CLINICAL_NOTES
                    WHERE note_text IS NOT NULL
                    ORDER BY authored_at DESC
                    LIMIT 5
                """)

                if not entities.empty:
                    for _, row in entities.iterrows():
                        with st.container(border=True):
                            st.markdown(f"**{row['NOTE_TYPE']}** | Patient: `{row['PATIENT_ID']}`")
                            st.json(row["EXTRACTED_ENTITIES"])
            except Exception as e:
                st.error(f"Error: {e}")
