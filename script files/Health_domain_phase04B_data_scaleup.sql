-- ============================================================
-- HEALTH_DOMAIN - DATA SCALE-UP TO 100K+ RECORDS
-- ============================================================
-- Script: Phase04B_data_scaleup.sql
-- Version: 1.0.0
--
-- Description:
--   Scales synthetic data to ~100K+ total records and fills
--   all previously empty tables (lab results, vital signs,
--   clinical notes).
--
-- TARGET RECORD COUNTS:
--   DIM_PATIENT:          5,000   (was 500)
--   FACT_ENCOUNTER:      15,000   (was 2,000)
--   FACT_DIAGNOSIS:      25,000   (was 3,000)
--   FACT_MEDICATION:     15,000   (was 2,500)
--   FACT_REHAB_REFERRAL:  2,000   (was 200)
--   FACT_REHAB_SESSION:  20,000   (was 4,000)
--   FACT_REHAB_OUTCOME:   4,000   (was 400)
--   FACT_LAB_RESULT:     10,000   (was 0 - NEW)
--   RAW_VITAL_SIGNS:      8,000   (was 0 - NEW)
--   RAW_CLAIMS:           5,000   (was 1,000)
--   CLINICAL_NOTES:       3,000   (was 0 - NEW)
--   ────────────────────────────
--   TOTAL:             ~112,000
--
-- Dependencies:
--   - Phase 04 Sections 1-11 executed (DDL created)
--   - Lookup temp tables will be recreated here
-- ============================================================

USE ROLE SYSADMIN;
USE WAREHOUSE HEALTH_TRANSFORM_WH;

-- ============================================================
-- LOOKUP TABLES
-- ============================================================

CREATE OR REPLACE TEMPORARY TABLE TEMP_CARDIAC_DIAGNOSES AS
SELECT column1 AS dx_code, column2 AS dx_name, column3 AS cardiac_category FROM VALUES
    ('I21.0','STEMI of anterior wall','ACUTE_MI'),
    ('I21.1','STEMI of inferior wall','ACUTE_MI'),
    ('I21.3','STEMI of unspecified site','ACUTE_MI'),
    ('I21.4','NSTEMI','ACUTE_MI'),
    ('I25.10','Atherosclerotic heart disease','CHRONIC_IHD'),
    ('I25.110','Atherosclerotic heart disease native vessel unstable angina','CHRONIC_IHD'),
    ('I25.5','Ischemic cardiomyopathy','CHRONIC_IHD'),
    ('I50.20','Unspecified systolic heart failure','HEART_FAILURE'),
    ('I50.22','Chronic systolic heart failure','HEART_FAILURE'),
    ('I50.23','Acute on chronic systolic heart failure','HEART_FAILURE'),
    ('I50.30','Unspecified diastolic heart failure','HEART_FAILURE'),
    ('I50.32','Chronic diastolic heart failure','HEART_FAILURE'),
    ('I20.0','Unstable angina','ANGINA'),
    ('I20.9','Angina pectoris unspecified','ANGINA'),
    ('I48.0','Paroxysmal atrial fibrillation','ATRIAL_FIBRILLATION'),
    ('I48.1','Persistent atrial fibrillation','ATRIAL_FIBRILLATION'),
    ('I48.2','Chronic atrial fibrillation','ATRIAL_FIBRILLATION'),
    ('I42.0','Dilated cardiomyopathy','CARDIOMYOPATHY'),
    ('I42.9','Cardiomyopathy unspecified','CARDIOMYOPATHY'),
    ('Z95.1','Presence of CABG graft','CARDIAC_DEVICE'),
    ('Z95.5','Presence of coronary stent','CARDIAC_DEVICE'),
    ('Z95.2','Presence of prosthetic heart valve','CARDIAC_DEVICE'),
    ('I35.0','Aortic valve stenosis','VALVULAR'),
    ('I34.0','Mitral valve insufficiency','VALVULAR'),
    ('E11.9','Type 2 diabetes without complications','COMORBIDITY'),
    ('I10','Essential hypertension','COMORBIDITY'),
    ('E78.5','Hyperlipidemia unspecified','COMORBIDITY'),
    ('J44.1','COPD with acute exacerbation','COMORBIDITY'),
    ('N18.3','CKD stage 3','COMORBIDITY'),
    ('F32.1','Major depressive disorder moderate','COMORBIDITY')
AS t(column1, column2, column3);

CREATE OR REPLACE TEMPORARY TABLE TEMP_MEDICATIONS AS
SELECT column1 AS med_name, column2 AS drug_class FROM VALUES
    ('Metoprolol Succinate 50mg','BETA_BLOCKER'),('Carvedilol 12.5mg','BETA_BLOCKER'),
    ('Atenolol 50mg','BETA_BLOCKER'),('Lisinopril 10mg','ACE_INHIBITOR'),
    ('Enalapril 5mg','ACE_INHIBITOR'),('Ramipril 5mg','ACE_INHIBITOR'),
    ('Warfarin 5mg','ANTICOAGULANT'),('Apixaban 5mg','ANTICOAGULANT'),
    ('Rivaroxaban 20mg','ANTICOAGULANT'),('Heparin 5000u','ANTICOAGULANT'),
    ('Amiodarone 200mg','ANTIARRHYTHMIC'),('Sotalol 80mg','ANTIARRHYTHMIC'),
    ('Atorvastatin 40mg','STATIN'),('Atorvastatin 80mg','STATIN'),
    ('Rosuvastatin 20mg','STATIN'),('Simvastatin 40mg','STATIN'),
    ('Aspirin 81mg','ANTIPLATELET'),('Clopidogrel 75mg','ANTIPLATELET'),
    ('Ticagrelor 90mg','ANTIPLATELET'),('Furosemide 40mg','DIURETIC'),
    ('Spironolactone 25mg','DIURETIC'),('Amlodipine 5mg','CALCIUM_CHANNEL_BLOCKER'),
    ('Metformin 500mg','ANTIDIABETIC'),('Nitroglycerin 0.4mg SL','NITRATE'),
    ('Isosorbide Mononitrate 30mg','NITRATE'),('Entresto 97/103mg','ARNI'),
    ('Losartan 50mg','ARB'),('Valsartan 160mg','ARB'),
    ('Diltiazem 120mg','CALCIUM_CHANNEL_BLOCKER'),('Digoxin 0.125mg','CARDIAC_GLYCOSIDE')
AS t(column1, column2);

CREATE OR REPLACE TEMPORARY TABLE TEMP_LAB_TESTS AS
SELECT column1 AS loinc_code, column2 AS test_name, column3 AS unit,
       column4 AS ref_low, column5 AS ref_high FROM VALUES
    ('2093-3','Total Cholesterol','mg/dL',125,200),
    ('2571-8','Triglycerides','mg/dL',50,150),
    ('2085-9','HDL Cholesterol','mg/dL',40,60),
    ('13457-7','LDL Cholesterol','mg/dL',50,100),
    ('4548-4','Hemoglobin A1c','%',4.0,5.6),
    ('2160-0','Creatinine','mg/dL',0.6,1.2),
    ('3094-0','BUN','mg/dL',7,20),
    ('6299-2','BNP','pg/mL',0,100),
    ('33762-6','NT-proBNP','pg/mL',0,300),
    ('2823-3','Potassium','mEq/L',3.5,5.0),
    ('2951-2','Sodium','mEq/L',136,145),
    ('718-7','Hemoglobin','g/dL',12.0,17.5),
    ('4544-3','Hematocrit','%',36,51),
    ('777-3','Platelets','K/uL',150,400),
    ('6598-7','Troponin T','ng/mL',0,0.04),
    ('49563-0','Troponin I','ng/mL',0,0.04),
    ('30313-1','INR','ratio',0.8,1.2),
    ('5902-2','PT','seconds',11,13.5),
    ('14959-1','aPTT','seconds',25,35),
    ('33914-3','eGFR','mL/min/1.73m2',60,120),
    ('2345-7','Glucose','mg/dL',70,100),
    ('1742-6','ALT','U/L',7,56),
    ('1920-8','AST','U/L',10,40),
    ('1975-2','Bilirubin Total','mg/dL',0.1,1.2),
    ('2532-0','LDH','U/L',140,280),
    ('2157-6','CK','U/L',22,198),
    ('13969-1','CK-MB','ng/mL',0,5),
    ('1988-5','CRP','mg/L',0,3),
    ('30341-2','ESR','mm/hr',0,20),
    ('14647-2','TSH','mIU/L',0.4,4.0)
AS t(column1, column2, column3, column4, column5);


-- ============================================================
-- 1. PATIENTS: 5,000 records
-- ============================================================

TRUNCATE TABLE IF EXISTS HEALTH_TRANSFORM_DB.MASTER.DIM_PATIENT;

INSERT INTO HEALTH_TRANSFORM_DB.MASTER.DIM_PATIENT (
    patient_id, first_name, last_name, date_of_birth, age, gender, ethnicity, ssn, address, phone, email,
    insurance_id, primary_language, marital_status, is_active, effective_from, is_current
)
SELECT
    'PAT-' || LPAD(SEQ4(), 6, '0'),
    CASE MOD(SEQ4(), 20) WHEN 0 THEN 'James' WHEN 1 THEN 'Robert' WHEN 2 THEN 'John' WHEN 3 THEN 'Michael'
        WHEN 4 THEN 'David' WHEN 5 THEN 'William' WHEN 6 THEN 'Mary' WHEN 7 THEN 'Patricia' WHEN 8 THEN 'Jennifer'
        WHEN 9 THEN 'Linda' WHEN 10 THEN 'Elizabeth' WHEN 11 THEN 'Susan' WHEN 12 THEN 'Jessica' WHEN 13 THEN 'Sarah'
        WHEN 14 THEN 'Thomas' WHEN 15 THEN 'Charles' WHEN 16 THEN 'Karen' WHEN 17 THEN 'Nancy' WHEN 18 THEN 'Lisa' ELSE 'Mark' END,
    CASE MOD(FLOOR(SEQ4()/20), 20) WHEN 0 THEN 'Smith' WHEN 1 THEN 'Johnson' WHEN 2 THEN 'Williams' WHEN 3 THEN 'Brown'
        WHEN 4 THEN 'Jones' WHEN 5 THEN 'Garcia' WHEN 6 THEN 'Miller' WHEN 7 THEN 'Davis' WHEN 8 THEN 'Rodriguez'
        WHEN 9 THEN 'Martinez' WHEN 10 THEN 'Wilson' WHEN 11 THEN 'Anderson' WHEN 12 THEN 'Thomas' WHEN 13 THEN 'Taylor'
        WHEN 14 THEN 'Moore' WHEN 15 THEN 'Jackson' WHEN 16 THEN 'Lee' WHEN 17 THEN 'Perez' WHEN 18 THEN 'White' ELSE 'Harris' END,
    DATEADD(DAY, -UNIFORM(16000, 32000, RANDOM()), CURRENT_DATE()),
    ROUND(UNIFORM(44, 88, RANDOM())),
    CASE WHEN MOD(SEQ4(), 20) IN (0,1,2,3,4,5,14,15,19) THEN 'M' ELSE 'F' END,
    CASE MOD(SEQ4(), 7) WHEN 0 THEN 'WHITE' WHEN 1 THEN 'BLACK' WHEN 2 THEN 'HISPANIC' WHEN 3 THEN 'ASIAN'
        WHEN 4 THEN 'NATIVE_AMERICAN' WHEN 5 THEN 'PACIFIC_ISLANDER' ELSE 'OTHER' END,
    LPAD(UNIFORM(100,999,RANDOM()),3,'0') || '-' || LPAD(UNIFORM(10,99,RANDOM()),2,'0') || '-' || LPAD(UNIFORM(1000,9999,RANDOM()),4,'0'),
    UNIFORM(100,9999,RANDOM()) || ' ' || CASE MOD(SEQ4(),8) WHEN 0 THEN 'Oak St' WHEN 1 THEN 'Maple Ave' WHEN 2 THEN 'Cedar Dr'
        WHEN 3 THEN 'Pine Ln' WHEN 4 THEN 'Elm Blvd' WHEN 5 THEN 'Main St' WHEN 6 THEN 'Park Ave' ELSE 'Broadway' END,
    '(' || LPAD(UNIFORM(200,999,RANDOM()),3,'0') || ') 555-' || LPAD(UNIFORM(1000,9999,RANDOM()),4,'0'),
    'patient' || SEQ4() || '@email.com',
    'INS-' || LPAD(UNIFORM(10000,99999,RANDOM()),5,'0'),
    CASE MOD(SEQ4(),5) WHEN 0 THEN 'ENGLISH' WHEN 1 THEN 'SPANISH' WHEN 2 THEN 'CHINESE' WHEN 3 THEN 'VIETNAMESE' ELSE 'ENGLISH' END,
    CASE MOD(SEQ4(),4) WHEN 0 THEN 'MARRIED' WHEN 1 THEN 'SINGLE' WHEN 2 THEN 'DIVORCED' ELSE 'WIDOWED' END,
    TRUE, CURRENT_TIMESTAMP(), TRUE
FROM TABLE(GENERATOR(ROWCOUNT => 5000));


-- ============================================================
-- 2. ENCOUNTERS: 15,000 records
-- ============================================================

TRUNCATE TABLE IF EXISTS HEALTH_TRANSFORM_DB.CLEANSED.FACT_ENCOUNTER;

INSERT INTO HEALTH_TRANSFORM_DB.CLEANSED.FACT_ENCOUNTER (
    encounter_id, patient_id, encounter_type, admit_date, discharge_date,
    length_of_stay_days, department, attending_provider, facility_code, admit_diagnosis_code, discharge_status
)
SELECT
    'ENC-' || LPAD(SEQ4(), 8, '0'),
    'PAT-' || LPAD(MOD(SEQ4(), 5000), 6, '0'),
    CASE MOD(SEQ4(),5) WHEN 0 THEN 'INPATIENT' WHEN 1 THEN 'OUTPATIENT' WHEN 2 THEN 'EMERGENCY' WHEN 3 THEN 'OBSERVATION' ELSE 'INPATIENT' END,
    DATEADD(DAY, -UNIFORM(1, 1095, RANDOM()), CURRENT_TIMESTAMP()),
    DATEADD(DAY, -UNIFORM(1, 1095, RANDOM()) + UNIFORM(1, 14, RANDOM()), CURRENT_TIMESTAMP()),
    UNIFORM(1, 14, RANDOM()),
    CASE MOD(SEQ4(),8) WHEN 0 THEN 'CARDIOLOGY' WHEN 1 THEN 'CARDIAC_SURGERY' WHEN 2 THEN 'CARDIAC_REHAB' WHEN 3 THEN 'ICU'
        WHEN 4 THEN 'INTERNAL_MEDICINE' WHEN 5 THEN 'EMERGENCY' WHEN 6 THEN 'PULMONOLOGY' ELSE 'NEPHROLOGY' END,
    CASE MOD(SEQ4(),10) WHEN 0 THEN 'Dr. Patel' WHEN 1 THEN 'Dr. Chen' WHEN 2 THEN 'Dr. Williams' WHEN 3 THEN 'Dr. Kim'
        WHEN 4 THEN 'Dr. Rodriguez' WHEN 5 THEN 'Dr. Johnson' WHEN 6 THEN 'Dr. Lee' WHEN 7 THEN 'Dr. Brown'
        WHEN 8 THEN 'Dr. Gupta' ELSE 'Dr. Singh' END,
    CASE MOD(SEQ4(),5) WHEN 0 THEN 'FAC-001' WHEN 1 THEN 'FAC-002' WHEN 2 THEN 'FAC-003' WHEN 3 THEN 'FAC-004' ELSE 'FAC-005' END,
    CASE MOD(SEQ4(),6) WHEN 0 THEN 'I21.0' WHEN 1 THEN 'I21.4' WHEN 2 THEN 'I50.22' WHEN 3 THEN 'I20.0' WHEN 4 THEN 'I25.10' ELSE 'I48.0' END,
    CASE WHEN MOD(SEQ4(), 20) = 0 THEN 'EXPIRED' WHEN MOD(SEQ4(), 15) = 0 THEN 'TRANSFERRED' ELSE 'DISCHARGED_HOME' END
FROM TABLE(GENERATOR(ROWCOUNT => 15000));


-- ============================================================
-- 3. DIAGNOSES: 25,000 records
-- ============================================================

TRUNCATE TABLE IF EXISTS HEALTH_TRANSFORM_DB.CLEANSED.FACT_DIAGNOSIS;

INSERT INTO HEALTH_TRANSFORM_DB.CLEANSED.FACT_DIAGNOSIS (
    diagnosis_id, encounter_id, patient_id, icd_code, icd_version, description, diagnosis_type, diagnosis_date, cardiac_category
)
SELECT
    'DX-' || LPAD(SEQ4(), 8, '0'),
    'ENC-' || LPAD(MOD(SEQ4(), 15000), 8, '0'),
    'PAT-' || LPAD(MOD(SEQ4(), 5000), 6, '0'),
    dx.dx_code, '10', dx.dx_name,
    CASE MOD(SEQ4(), 3) WHEN 0 THEN 'PRIMARY' WHEN 1 THEN 'SECONDARY' ELSE 'ADMITTING' END,
    DATEADD(DAY, -UNIFORM(1, 1095, RANDOM()), CURRENT_DATE()),
    dx.cardiac_category
FROM TABLE(GENERATOR(ROWCOUNT => 25000)) g,
     (SELECT dx_code, dx_name, cardiac_category, ROW_NUMBER() OVER (ORDER BY dx_code) AS rn FROM TEMP_CARDIAC_DIAGNOSES) dx
WHERE dx.rn = MOD(SEQ4(), 30) + 1
LIMIT 25000;


-- ============================================================
-- 4. MEDICATIONS: 15,000 records
-- ============================================================

TRUNCATE TABLE IF EXISTS HEALTH_TRANSFORM_DB.CLEANSED.FACT_MEDICATION;

INSERT INTO HEALTH_TRANSFORM_DB.CLEANSED.FACT_MEDICATION (
    medication_id, encounter_id, patient_id, ndc_code, medication_name, dosage,
    route, frequency, prescriber, start_date, end_date, drug_class
)
SELECT
    'MED-' || LPAD(SEQ4(), 8, '0'),
    'ENC-' || LPAD(MOD(SEQ4(), 15000), 8, '0'),
    'PAT-' || LPAD(MOD(SEQ4(), 5000), 6, '0'),
    LPAD(UNIFORM(10000, 99999, RANDOM()), 11, '0'),
    m.med_name,
    REGEXP_SUBSTR(m.med_name, '[0-9]+[a-zA-Z]+'),
    CASE MOD(SEQ4(), 4) WHEN 0 THEN 'PO' WHEN 1 THEN 'IV' WHEN 2 THEN 'SL' ELSE 'PO' END,
    CASE MOD(SEQ4(), 4) WHEN 0 THEN 'BID' WHEN 1 THEN 'DAILY' WHEN 2 THEN 'TID' ELSE 'PRN' END,
    CASE MOD(SEQ4(), 10) WHEN 0 THEN 'Dr. Patel' WHEN 1 THEN 'Dr. Chen' WHEN 2 THEN 'Dr. Williams'
        WHEN 3 THEN 'Dr. Kim' WHEN 4 THEN 'Dr. Rodriguez' WHEN 5 THEN 'Dr. Johnson'
        WHEN 6 THEN 'Dr. Lee' WHEN 7 THEN 'Dr. Brown' WHEN 8 THEN 'Dr. Gupta' ELSE 'Dr. Singh' END,
    DATEADD(DAY, -UNIFORM(30, 730, RANDOM()), CURRENT_DATE()),
    DATEADD(DAY, UNIFORM(30, 365, RANDOM()), CURRENT_DATE()),
    m.drug_class
FROM TABLE(GENERATOR(ROWCOUNT => 15000)) g,
     (SELECT med_name, drug_class, ROW_NUMBER() OVER (ORDER BY med_name) AS rn FROM TEMP_MEDICATIONS) m
WHERE m.rn = MOD(SEQ4(), 30) + 1
LIMIT 15000;


-- ============================================================
-- 5. REHAB REFERRALS: 2,000 records
-- ============================================================

TRUNCATE TABLE IF EXISTS HEALTH_TRANSFORM_DB.CLEANSED.FACT_REHAB_REFERRAL;

INSERT INTO HEALTH_TRANSFORM_DB.CLEANSED.FACT_REHAB_REFERRAL (
    referral_id, patient_id, referring_physician, qualifying_diagnosis, cardiac_event_date,
    lvef_percent, gxt_peak_hr, gxt_peak_mets, aacvpr_risk_category, computed_risk, referral_date, days_event_to_referral
)
SELECT
    'REF-' || LPAD(SEQ4(), 6, '0'),
    'PAT-' || LPAD(MOD(SEQ4(), 5000), 6, '0'),
    CASE MOD(SEQ4(), 10) WHEN 0 THEN 'Dr. Patel' WHEN 1 THEN 'Dr. Chen' WHEN 2 THEN 'Dr. Williams'
        WHEN 3 THEN 'Dr. Kim' WHEN 4 THEN 'Dr. Rodriguez' WHEN 5 THEN 'Dr. Johnson'
        WHEN 6 THEN 'Dr. Lee' WHEN 7 THEN 'Dr. Brown' WHEN 8 THEN 'Dr. Gupta' ELSE 'Dr. Singh' END,
    CASE MOD(SEQ4(), 7) WHEN 0 THEN 'STEMI' WHEN 1 THEN 'NSTEMI' WHEN 2 THEN 'CABG' WHEN 3 THEN 'PCI'
        WHEN 4 THEN 'STABLE_ANGINA' WHEN 5 THEN 'HFrEF' ELSE 'VALVE_REPLACEMENT' END,
    DATEADD(DAY, -UNIFORM(30, 730, RANDOM()), CURRENT_DATE()),
    UNIFORM(20, 65, RANDOM()),
    UNIFORM(80, 170, RANDOM()),
    ROUND(UNIFORM(3.0, 12.0, RANDOM()), 1),
    CASE WHEN UNIFORM(0,2,RANDOM()) = 0 THEN 'LOW' WHEN UNIFORM(0,2,RANDOM()) = 1 THEN 'MODERATE' ELSE 'HIGH' END,
    CASE WHEN UNIFORM(0,2,RANDOM()) = 0 THEN 'LOW' WHEN UNIFORM(0,2,RANDOM()) = 1 THEN 'MODERATE' ELSE 'HIGH' END,
    DATEADD(DAY, -UNIFORM(1, 60, RANDOM()), CURRENT_DATE()),
    UNIFORM(2, 30, RANDOM())
FROM TABLE(GENERATOR(ROWCOUNT => 2000));


-- ============================================================
-- 6. REHAB SESSIONS: 20,000 records (~10 per referral)
-- ============================================================

TRUNCATE TABLE IF EXISTS HEALTH_TRANSFORM_DB.CLEANSED.FACT_REHAB_SESSION;

INSERT INTO HEALTH_TRANSFORM_DB.CLEANSED.FACT_REHAB_SESSION (
    session_id, referral_id, patient_id, session_number, session_date, modality, duration_minutes,
    target_hr_low, target_hr_high, resting_hr, peak_hr, recovery_hr,
    resting_bp_systolic, resting_bp_diastolic, peak_bp_systolic, peak_bp_diastolic,
    post_bp_systolic, post_bp_diastolic, rpe_peak, spo2_min, ecg_rhythm, ecg_monitor_minutes,
    exercise_terminated_early, therapist, achieved_hrr_percent, hr_recovery_delta, safety_flag
)
SELECT
    'SES-' || LPAD(SEQ4(), 8, '0'),
    'REF-' || LPAD(MOD(FLOOR(SEQ4() / 10), 2000), 6, '0'),
    'PAT-' || LPAD(MOD(FLOOR(SEQ4() / 10), 5000), 6, '0'),
    MOD(SEQ4(), 10) + 1,
    DATEADD(DAY, MOD(SEQ4(), 10) * 3 + UNIFORM(0, 2, RANDOM()), DATEADD(DAY, -90, CURRENT_DATE())),
    CASE MOD(SEQ4(), 5) WHEN 0 THEN 'TREADMILL' WHEN 1 THEN 'CYCLE_ERGOMETER' WHEN 2 THEN 'RECUMBENT_STEPPER'
        WHEN 3 THEN 'ARM_ERGOMETER' ELSE 'NU_STEP' END,
    UNIFORM(20, 55, RANDOM()),
    UNIFORM(88, 112, RANDOM()),
    UNIFORM(118, 148, RANDOM()),
    UNIFORM(58, 88, RANDOM()),
    UNIFORM(92, 160, RANDOM()),
    UNIFORM(68, 105, RANDOM()),
    UNIFORM(108, 145, RANDOM()), UNIFORM(62, 88, RANDOM()),
    UNIFORM(128, 185, RANDOM()), UNIFORM(68, 98, RANDOM()),
    UNIFORM(112, 148, RANDOM()), UNIFORM(62, 88, RANDOM()),
    UNIFORM(10, 17, RANDOM()),
    ROUND(UNIFORM(88.0, 100.0, RANDOM()), 1),
    CASE MOD(SEQ4(), 12) WHEN 0 THEN 'PVC_OCCASIONAL' WHEN 1 THEN 'PAC_RARE' WHEN 2 THEN 'SINUS_BRADYCARDIA'
        WHEN 3 THEN 'SINUS_TACHYCARDIA' ELSE 'NORMAL_SINUS' END,
    UNIFORM(15, 50, RANDOM()),
    CASE WHEN UNIFORM(0, 100, RANDOM()) < 3 THEN TRUE ELSE FALSE END,
    CASE MOD(SEQ4(), 8) WHEN 0 THEN 'Sarah PT' WHEN 1 THEN 'Mike PT' WHEN 2 THEN 'Lisa PT' WHEN 3 THEN 'James PT'
        WHEN 4 THEN 'Amy PT' WHEN 5 THEN 'Chris PT' WHEN 6 THEN 'Diana PT' ELSE 'Kevin PT' END,
    ROUND(UNIFORM(38.0, 88.0, RANDOM()), 1),
    UNIFORM(8, 40, RANDOM()),
    CASE WHEN UNIFORM(0, 100, RANDOM()) < 4 THEN TRUE ELSE FALSE END
FROM TABLE(GENERATOR(ROWCOUNT => 20000));


-- ============================================================
-- 7. REHAB OUTCOMES: 4,000 records (2,000 baseline + 2,000 discharge)
-- ============================================================

TRUNCATE TABLE IF EXISTS HEALTH_TRANSFORM_DB.CLEANSED.FACT_REHAB_OUTCOME;

INSERT INTO HEALTH_TRANSFORM_DB.CLEANSED.FACT_REHAB_OUTCOME (
    outcome_id, referral_id, patient_id, measurement_type, measurement_point, measurement_date,
    six_min_walk_meters, peak_mets, dasi_score, phq9_score, weight_kg, bmi, waist_cm,
    hba1c, ldl, hdl, total_cholesterol, triglycerides, depression_severity
)
SELECT
    'OUT-B-' || LPAD(SEQ4(), 6, '0'),
    'REF-' || LPAD(SEQ4(), 6, '0'),
    'PAT-' || LPAD(MOD(SEQ4(), 5000), 6, '0'),
    'COMPREHENSIVE', 'BASELINE',
    DATEADD(DAY, -UNIFORM(60, 180, RANDOM()), CURRENT_DATE()),
    UNIFORM(180, 520, RANDOM()), ROUND(UNIFORM(2.5, 8.5, RANDOM()), 1),
    ROUND(UNIFORM(8.0, 48.0, RANDOM()), 1), UNIFORM(1, 24, RANDOM()),
    ROUND(UNIFORM(50.0, 140.0, RANDOM()), 1), ROUND(UNIFORM(18.5, 45.0, RANDOM()), 1),
    ROUND(UNIFORM(65.0, 135.0, RANDOM()), 1), ROUND(UNIFORM(5.0, 10.0, RANDOM()), 1),
    ROUND(UNIFORM(70.0, 200.0, RANDOM()), 0), ROUND(UNIFORM(25.0, 75.0, RANDOM()), 0),
    ROUND(UNIFORM(140.0, 300.0, RANDOM()), 0), ROUND(UNIFORM(70.0, 350.0, RANDOM()), 0),
    CASE WHEN UNIFORM(1,24,RANDOM()) >= 20 THEN 'SEVERE' WHEN UNIFORM(1,24,RANDOM()) >= 15 THEN 'MODERATELY_SEVERE'
         WHEN UNIFORM(1,24,RANDOM()) >= 10 THEN 'MODERATE' WHEN UNIFORM(1,24,RANDOM()) >= 5 THEN 'MILD' ELSE 'MINIMAL' END
FROM TABLE(GENERATOR(ROWCOUNT => 2000));

INSERT INTO HEALTH_TRANSFORM_DB.CLEANSED.FACT_REHAB_OUTCOME (
    outcome_id, referral_id, patient_id, measurement_type, measurement_point, measurement_date,
    six_min_walk_meters, peak_mets, dasi_score, phq9_score, weight_kg, bmi, waist_cm,
    hba1c, ldl, hdl, total_cholesterol, triglycerides, depression_severity
)
SELECT
    'OUT-D-' || LPAD(SEQ4(), 6, '0'),
    'REF-' || LPAD(SEQ4(), 6, '0'),
    'PAT-' || LPAD(MOD(SEQ4(), 5000), 6, '0'),
    'COMPREHENSIVE', 'DISCHARGE',
    DATEADD(DAY, -UNIFORM(1, 30, RANDOM()), CURRENT_DATE()),
    UNIFORM(220, 620, RANDOM()), ROUND(UNIFORM(3.5, 11.0, RANDOM()), 1),
    ROUND(UNIFORM(12.0, 58.0, RANDOM()), 1), UNIFORM(0, 20, RANDOM()),
    ROUND(UNIFORM(48.0, 135.0, RANDOM()), 1), ROUND(UNIFORM(18.0, 43.0, RANDOM()), 1),
    ROUND(UNIFORM(62.0, 130.0, RANDOM()), 1), ROUND(UNIFORM(4.8, 9.0, RANDOM()), 1),
    ROUND(UNIFORM(55.0, 180.0, RANDOM()), 0), ROUND(UNIFORM(30.0, 80.0, RANDOM()), 0),
    ROUND(UNIFORM(130.0, 270.0, RANDOM()), 0), ROUND(UNIFORM(60.0, 280.0, RANDOM()), 0),
    CASE WHEN UNIFORM(0,20,RANDOM()) >= 20 THEN 'SEVERE' WHEN UNIFORM(0,20,RANDOM()) >= 15 THEN 'MODERATELY_SEVERE'
         WHEN UNIFORM(0,20,RANDOM()) >= 10 THEN 'MODERATE' WHEN UNIFORM(0,20,RANDOM()) >= 5 THEN 'MILD' ELSE 'MINIMAL' END
FROM TABLE(GENERATOR(ROWCOUNT => 2000));


-- ============================================================
-- 8. LAB RESULTS: 10,000 records (NEW - was 0)
-- ============================================================

TRUNCATE TABLE IF EXISTS HEALTH_TRANSFORM_DB.CLEANSED.FACT_LAB_RESULT;

INSERT INTO HEALTH_TRANSFORM_DB.CLEANSED.FACT_LAB_RESULT (
    lab_id, encounter_id, patient_id, loinc_code, test_name, result_value, result_numeric,
    unit, reference_low, reference_high, abnormal_flag, computed_flag, collected_at
)
SELECT
    'LAB-' || LPAD(SEQ4(), 8, '0'),
    'ENC-' || LPAD(MOD(SEQ4(), 15000), 8, '0'),
    'PAT-' || LPAD(MOD(SEQ4(), 5000), 6, '0'),
    lt.loinc_code,
    lt.test_name,
    ROUND(UNIFORM(lt.ref_low * 0.5, lt.ref_high * 1.8, RANDOM()), 2)::VARCHAR,
    ROUND(UNIFORM(lt.ref_low * 0.5, lt.ref_high * 1.8, RANDOM()), 2),
    lt.unit,
    lt.ref_low,
    lt.ref_high,
    NULL,
    CASE
        WHEN UNIFORM(lt.ref_low * 0.5, lt.ref_high * 1.8, RANDOM()) < lt.ref_low THEN 'LOW'
        WHEN UNIFORM(lt.ref_low * 0.5, lt.ref_high * 1.8, RANDOM()) > lt.ref_high THEN 'HIGH'
        ELSE 'NORMAL'
    END,
    DATEADD(MINUTE, -UNIFORM(1, 1500000, RANDOM()), CURRENT_TIMESTAMP())
FROM TABLE(GENERATOR(ROWCOUNT => 10000)) g,
     (SELECT loinc_code, test_name, unit, ref_low, ref_high, ROW_NUMBER() OVER (ORDER BY loinc_code) AS rn FROM TEMP_LAB_TESTS) lt
WHERE lt.rn = MOD(SEQ4(), 30) + 1
LIMIT 10000;


-- ============================================================
-- 9. VITAL SIGNS: 8,000 records (NEW - was 0)
-- ============================================================

TRUNCATE TABLE IF EXISTS HEALTH_RAW_DB.CLINICAL_DATA.RAW_VITAL_SIGNS;

INSERT INTO HEALTH_RAW_DB.CLINICAL_DATA.RAW_VITAL_SIGNS (
    vital_id, patient_id, encounter_id, vital_type, value_numeric, unit, measured_at, measured_by, source_system
)
SELECT
    'VIT-' || LPAD(SEQ4(), 8, '0'),
    'PAT-' || LPAD(MOD(SEQ4(), 5000), 6, '0'),
    'ENC-' || LPAD(MOD(SEQ4(), 15000), 8, '0'),
    CASE MOD(SEQ4(), 8)
        WHEN 0 THEN 'HEART_RATE'
        WHEN 1 THEN 'SYSTOLIC_BP'
        WHEN 2 THEN 'DIASTOLIC_BP'
        WHEN 3 THEN 'RESPIRATORY_RATE'
        WHEN 4 THEN 'TEMPERATURE'
        WHEN 5 THEN 'SPO2'
        WHEN 6 THEN 'WEIGHT_KG'
        ELSE 'PAIN_SCALE'
    END,
    CASE MOD(SEQ4(), 8)
        WHEN 0 THEN UNIFORM(50, 130, RANDOM())
        WHEN 1 THEN UNIFORM(90, 200, RANDOM())
        WHEN 2 THEN UNIFORM(50, 110, RANDOM())
        WHEN 3 THEN UNIFORM(10, 30, RANDOM())
        WHEN 4 THEN ROUND(UNIFORM(96.0, 103.0, RANDOM()), 1)
        WHEN 5 THEN ROUND(UNIFORM(85.0, 100.0, RANDOM()), 1)
        WHEN 6 THEN ROUND(UNIFORM(45.0, 150.0, RANDOM()), 1)
        ELSE UNIFORM(0, 10, RANDOM())
    END,
    CASE MOD(SEQ4(), 8)
        WHEN 0 THEN 'bpm' WHEN 1 THEN 'mmHg' WHEN 2 THEN 'mmHg' WHEN 3 THEN 'breaths/min'
        WHEN 4 THEN 'F' WHEN 5 THEN '%' WHEN 6 THEN 'kg' ELSE '0-10 scale'
    END,
    DATEADD(MINUTE, -UNIFORM(1, 1500000, RANDOM()), CURRENT_TIMESTAMP()),
    CASE MOD(SEQ4(), 6) WHEN 0 THEN 'RN Smith' WHEN 1 THEN 'RN Johnson' WHEN 2 THEN 'RN Williams'
        WHEN 3 THEN 'RN Davis' WHEN 4 THEN 'RN Garcia' ELSE 'RN Martinez' END,
    'BEDSIDE_MONITOR'
FROM TABLE(GENERATOR(ROWCOUNT => 8000));


-- ============================================================
-- 10. CLAIMS: 5,000 records (was 1,000)
-- ============================================================

TRUNCATE TABLE IF EXISTS HEALTH_RAW_DB.REFERENCE_DATA.RAW_CLAIMS;

INSERT INTO HEALTH_RAW_DB.REFERENCE_DATA.RAW_CLAIMS (
    claim_id, patient_id, encounter_id, payer_id, payer_name, claim_type, service_date, cpt_code, drg_code,
    billed_amount, allowed_amount, paid_amount, patient_responsibility, claim_status, denial_reason, source_system
)
SELECT
    'CLM-' || LPAD(SEQ4(), 8, '0'),
    'PAT-' || LPAD(MOD(SEQ4(), 5000), 6, '0'),
    'ENC-' || LPAD(MOD(SEQ4(), 15000), 8, '0'),
    'PAY-' || LPAD(MOD(SEQ4(), 10), 3, '0'),
    CASE MOD(SEQ4(),8) WHEN 0 THEN 'Medicare' WHEN 1 THEN 'Medicaid' WHEN 2 THEN 'Blue Cross' WHEN 3 THEN 'Aetna'
        WHEN 4 THEN 'UnitedHealth' WHEN 5 THEN 'Cigna' WHEN 6 THEN 'Humana' ELSE 'Kaiser' END,
    CASE MOD(SEQ4(),3) WHEN 0 THEN 'PROFESSIONAL' WHEN 1 THEN 'INSTITUTIONAL' ELSE 'OUTPATIENT' END,
    DATEADD(DAY, -UNIFORM(1, 730, RANDOM()), CURRENT_DATE()),
    CASE MOD(SEQ4(),10) WHEN 0 THEN '93798' WHEN 1 THEN '93015' WHEN 2 THEN '93000' WHEN 3 THEN '93306'
        WHEN 4 THEN '99213' WHEN 5 THEN '99214' WHEN 6 THEN '93797' WHEN 7 THEN '93010'
        WHEN 8 THEN '99232' ELSE '99223' END,
    CASE MOD(SEQ4(),7) WHEN 0 THEN '291' WHEN 1 THEN '292' WHEN 2 THEN '280' WHEN 3 THEN '281'
        WHEN 4 THEN '293' WHEN 5 THEN '286' ELSE '287' END,
    ROUND(UNIFORM(150.0, 35000.0, RANDOM()), 2),
    ROUND(UNIFORM(100.0, 28000.0, RANDOM()), 2),
    ROUND(UNIFORM(80.0, 25000.0, RANDOM()), 2),
    ROUND(UNIFORM(0.0, 5000.0, RANDOM()), 2),
    CASE WHEN UNIFORM(0, 100, RANDOM()) < 12 THEN 'DENIED' WHEN UNIFORM(0, 100, RANDOM()) < 5 THEN 'PENDING' ELSE 'PAID' END,
    CASE WHEN UNIFORM(0, 100, RANDOM()) < 12 THEN
        CASE MOD(SEQ4(),6) WHEN 0 THEN 'MEDICAL_NECESSITY' WHEN 1 THEN 'PRIOR_AUTH_MISSING' WHEN 2 THEN 'CODING_ERROR'
            WHEN 3 THEN 'TIMELY_FILING' WHEN 4 THEN 'DUPLICATE_CLAIM' ELSE 'BUNDLING_ERROR' END
    ELSE NULL END,
    'CLAIMS_SYSTEM'
FROM TABLE(GENERATOR(ROWCOUNT => 5000));


-- ============================================================
-- 11. CLINICAL NOTES: 3,000 records (NEW - was 0)
-- ============================================================

CREATE TABLE IF NOT EXISTS HEALTH_RAW_DB.CLINICAL_DATA.RAW_CLINICAL_NOTES (
    note_id         VARCHAR(50),
    patient_id      VARCHAR(50),
    encounter_id    VARCHAR(50),
    note_type       VARCHAR(50),
    note_text       VARCHAR(4000),
    author          VARCHAR(100),
    authored_at     TIMESTAMP_NTZ,
    source_system   VARCHAR(50) DEFAULT 'EHR',
    load_timestamp  TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

TRUNCATE TABLE IF EXISTS HEALTH_RAW_DB.CLINICAL_DATA.RAW_CLINICAL_NOTES;

INSERT INTO HEALTH_RAW_DB.CLINICAL_DATA.RAW_CLINICAL_NOTES (
    note_id, patient_id, encounter_id, note_type, note_text, author, authored_at
)
SELECT
    'NOTE-' || LPAD(SEQ4(), 8, '0'),
    'PAT-' || LPAD(MOD(SEQ4(), 5000), 6, '0'),
    'ENC-' || LPAD(MOD(SEQ4(), 15000), 8, '0'),
    CASE MOD(SEQ4(), 8)
        WHEN 0 THEN 'PROGRESS_NOTE'
        WHEN 1 THEN 'DISCHARGE_SUMMARY'
        WHEN 2 THEN 'CARDIAC_REHAB_NOTE'
        WHEN 3 THEN 'CONSULTATION'
        WHEN 4 THEN 'NURSING_NOTE'
        WHEN 5 THEN 'PROCEDURE_NOTE'
        WHEN 6 THEN 'ADMISSION_NOTE'
        ELSE 'FOLLOW_UP_NOTE'
    END,
    CASE MOD(SEQ4(), 8)
        WHEN 0 THEN 'Patient seen in clinic today. Vital signs stable. ' ||
            CASE MOD(SEQ4(), 4) WHEN 0 THEN 'Cardiac function improved. LVEF trending up. Continue current medications.'
                WHEN 1 THEN 'Mild exertional dyspnea reported. Adjusted diuretic dose. Follow up in 2 weeks.'
                WHEN 2 THEN 'No chest pain or palpitations. ECG shows normal sinus rhythm. Tolerating beta-blocker well.'
                ELSE 'Blood pressure well controlled. HbA1c improving. Encouraged continued exercise and dietary compliance.' END
        WHEN 1 THEN 'DISCHARGE SUMMARY: Patient admitted for ' ||
            CASE MOD(SEQ4(), 3) WHEN 0 THEN 'acute STEMI. Underwent PCI with DES placement to LAD. Post-procedure course uncomplicated.'
                WHEN 1 THEN 'acute decompensated heart failure. Treated with IV diuresis. Euvolemic at discharge.'
                ELSE 'NSTEMI. Medical management with dual antiplatelet therapy initiated. Cardiac rehab referral placed.' END ||
            ' Discharge medications reconciled. Follow up with cardiology in 1 week.'
        WHEN 2 THEN 'CARDIAC REHAB SESSION: Patient completed ' ||
            CASE MOD(SEQ4(), 3) WHEN 0 THEN 'treadmill exercise at 3.0 mph, 2% grade for 30 minutes. Peak HR 118, RPE 13. No symptoms. ECG: normal sinus rhythm throughout.'
                WHEN 1 THEN 'cycle ergometer at 50 watts for 25 minutes. Tolerated well. BP response appropriate. Progressing intensity next session.'
                ELSE 'combined aerobic and resistance training. 20 min treadmill + upper body resistance (1 set x 12 reps). Good effort and adherence.' END
        WHEN 3 THEN 'CARDIOLOGY CONSULTATION: Evaluated for ' ||
            CASE MOD(SEQ4(), 3) WHEN 0 THEN 'new onset atrial fibrillation. CHADS2-VASc score calculated. Anticoagulation recommended.'
                WHEN 1 THEN 'preoperative cardiac risk assessment. Stress test completed. Cleared for surgery with optimization of beta-blocker.'
                ELSE 'recurrent chest pain. Troponin negative x2. Stress echo pending. Continue ASA and statin.' END
        WHEN 4 THEN 'NURSING NOTE: ' ||
            CASE MOD(SEQ4(), 3) WHEN 0 THEN 'Patient resting comfortably. VS: HR 72, BP 128/78, SpO2 97% on RA. Telemetry: NSR. Pain 0/10.'
                WHEN 1 THEN 'Ambulated in hallway x2 with assistance. Tolerated well. No dizziness or SOB. Diet tolerated.'
                ELSE 'IV heparin drip running per protocol. PTT checked and within therapeutic range. No bleeding noted.' END
        WHEN 5 THEN 'PROCEDURE NOTE: ' ||
            CASE MOD(SEQ4(), 2) WHEN 0 THEN 'Left heart catheterization performed via right radial approach. Single vessel CAD identified (90% LAD stenosis). PCI with DES performed successfully. TIMI 3 flow restored.'
                ELSE 'Echocardiogram performed. LVEF 40%. Mild MR. No pericardial effusion. Diastolic dysfunction grade II.' END
        WHEN 6 THEN 'ADMISSION NOTE: ' || UNIFORM(55, 88, RANDOM()) || '-year-old ' ||
            CASE MOD(SEQ4(), 2) WHEN 0 THEN 'male' ELSE 'female' END ||
            ' presenting with ' ||
            CASE MOD(SEQ4(), 3) WHEN 0 THEN 'acute chest pain radiating to left arm. ECG: ST elevation in leads V1-V4. Troponin elevated. Activated cath lab.'
                WHEN 1 THEN 'progressive dyspnea on exertion over 2 weeks. BNP elevated at 1200. CXR: bilateral pleural effusions. Started IV furosemide.'
                ELSE 'palpitations and dizziness. ECG: atrial fibrillation with RVR at 142 bpm. Started rate control with IV diltiazem.' END
        ELSE 'FOLLOW-UP NOTE: Patient returns for cardiac rehab progress evaluation. ' ||
            CASE MOD(SEQ4(), 3) WHEN 0 THEN 'Completed 18 of 36 sessions. 6MWT improved from 320m to 410m. Functional capacity increasing. Continue current program.'
                WHEN 1 THEN 'PHQ-9 score improved from 14 to 8. Mood and engagement improving. Encourage continued participation in support group.'
                ELSE 'Lipid panel improved: LDL decreased from 145 to 98. HbA1c decreased from 7.8 to 7.1. Medication adherence excellent.' END
    END,
    CASE MOD(SEQ4(), 10) WHEN 0 THEN 'Dr. Patel' WHEN 1 THEN 'Dr. Chen' WHEN 2 THEN 'Dr. Williams'
        WHEN 3 THEN 'Dr. Kim' WHEN 4 THEN 'Dr. Rodriguez' WHEN 5 THEN 'Dr. Johnson'
        WHEN 6 THEN 'RN Smith' WHEN 7 THEN 'RN Davis' WHEN 8 THEN 'Sarah PT' ELSE 'Dr. Gupta' END,
    DATEADD(MINUTE, -UNIFORM(1, 1500000, RANDOM()), CURRENT_TIMESTAMP())
FROM TABLE(GENERATOR(ROWCOUNT => 3000));


-- ============================================================
-- 12. MODEL CATALOG: Keep 4 records
-- ============================================================

TRUNCATE TABLE IF EXISTS HEALTH_AI_READY_DB.MODELS.MODEL_CATALOG;

INSERT INTO HEALTH_AI_READY_DB.MODELS.MODEL_CATALOG
  (model_id, model_name, model_version, model_type, task, target_platform, training_dataset, description)
VALUES
  ('MDL-001','ICU_MORTALITY_RETAIN','v1.0','RETAIN','BINARY_CLASSIFICATION','WAREHOUSE',
   'HEALTH_AI_READY_DB.FEATURES.DS_MORTALITY_PREDICTION','ICU mortality prediction using RETAIN per PyHealth'),
  ('MDL-002','CARDIAC_ADVERSE_TRANSFORMER','v1.0','TRANSFORMER','BINARY_CLASSIFICATION','WAREHOUSE',
   'HEALTH_AI_READY_DB.FEATURES.DS_CARDIAC_ADVERSE_EVENT','Cardiac rehab adverse event prediction using Transformer'),
  ('MDL-003','DRUG_RECOMMENDATION_SAFEDRUG','v1.0','SAFEDRUG','MULTI_LABEL_CLASSIFICATION','SNOWPARK_CONTAINER_SERVICES',
   'HEALTH_TRANSFORM_DB.CLEANSED.FACT_MEDICATION','Safe medication recommendation with DDI constraints per PyHealth SafeDrug'),
  ('MDL-004','READMISSION_30DAY_GNN','v1.0','GNN','BINARY_CLASSIFICATION','WAREHOUSE',
   'HEALTH_AI_READY_DB.FEATURES.FACT_PATIENT_CLINICAL_FEATURES','30-day hospital readmission prediction using GNN');


-- ============================================================
-- VERIFICATION: Record Count Summary
-- ============================================================

SELECT 'DIM_PATIENT' AS table_name, COUNT(*) AS records FROM HEALTH_TRANSFORM_DB.MASTER.DIM_PATIENT
UNION ALL SELECT 'FACT_ENCOUNTER', COUNT(*) FROM HEALTH_TRANSFORM_DB.CLEANSED.FACT_ENCOUNTER
UNION ALL SELECT 'FACT_DIAGNOSIS', COUNT(*) FROM HEALTH_TRANSFORM_DB.CLEANSED.FACT_DIAGNOSIS
UNION ALL SELECT 'FACT_MEDICATION', COUNT(*) FROM HEALTH_TRANSFORM_DB.CLEANSED.FACT_MEDICATION
UNION ALL SELECT 'FACT_REHAB_REFERRAL', COUNT(*) FROM HEALTH_TRANSFORM_DB.CLEANSED.FACT_REHAB_REFERRAL
UNION ALL SELECT 'FACT_REHAB_SESSION', COUNT(*) FROM HEALTH_TRANSFORM_DB.CLEANSED.FACT_REHAB_SESSION
UNION ALL SELECT 'FACT_REHAB_OUTCOME', COUNT(*) FROM HEALTH_TRANSFORM_DB.CLEANSED.FACT_REHAB_OUTCOME
UNION ALL SELECT 'FACT_LAB_RESULT', COUNT(*) FROM HEALTH_TRANSFORM_DB.CLEANSED.FACT_LAB_RESULT
UNION ALL SELECT 'RAW_VITAL_SIGNS', COUNT(*) FROM HEALTH_RAW_DB.CLINICAL_DATA.RAW_VITAL_SIGNS
UNION ALL SELECT 'RAW_CLAIMS', COUNT(*) FROM HEALTH_RAW_DB.REFERENCE_DATA.RAW_CLAIMS
UNION ALL SELECT 'RAW_CLINICAL_NOTES', COUNT(*) FROM HEALTH_RAW_DB.CLINICAL_DATA.RAW_CLINICAL_NOTES
UNION ALL SELECT 'MODEL_CATALOG', COUNT(*) FROM HEALTH_AI_READY_DB.MODELS.MODEL_CATALOG
ORDER BY table_name;

SELECT
    'TOTAL RECORDS' AS metric,
    SUM(records) AS total
FROM (
    SELECT COUNT(*) AS records FROM HEALTH_TRANSFORM_DB.MASTER.DIM_PATIENT
    UNION ALL SELECT COUNT(*) FROM HEALTH_TRANSFORM_DB.CLEANSED.FACT_ENCOUNTER
    UNION ALL SELECT COUNT(*) FROM HEALTH_TRANSFORM_DB.CLEANSED.FACT_DIAGNOSIS
    UNION ALL SELECT COUNT(*) FROM HEALTH_TRANSFORM_DB.CLEANSED.FACT_MEDICATION
    UNION ALL SELECT COUNT(*) FROM HEALTH_TRANSFORM_DB.CLEANSED.FACT_REHAB_REFERRAL
    UNION ALL SELECT COUNT(*) FROM HEALTH_TRANSFORM_DB.CLEANSED.FACT_REHAB_SESSION
    UNION ALL SELECT COUNT(*) FROM HEALTH_TRANSFORM_DB.CLEANSED.FACT_REHAB_OUTCOME
    UNION ALL SELECT COUNT(*) FROM HEALTH_TRANSFORM_DB.CLEANSED.FACT_LAB_RESULT
    UNION ALL SELECT COUNT(*) FROM HEALTH_RAW_DB.CLINICAL_DATA.RAW_VITAL_SIGNS
    UNION ALL SELECT COUNT(*) FROM HEALTH_RAW_DB.REFERENCE_DATA.RAW_CLAIMS
    UNION ALL SELECT COUNT(*) FROM HEALTH_RAW_DB.CLINICAL_DATA.RAW_CLINICAL_NOTES
    UNION ALL SELECT COUNT(*) FROM HEALTH_AI_READY_DB.MODELS.MODEL_CATALOG
);

/*
================================================================================
DATA SCALE-UP SUMMARY
================================================================================

TABLE                      │ BEFORE  │ AFTER    │ STATUS
───────────────────────────┼─────────┼──────────┼────────────
DIM_PATIENT                │ 500     │ 5,000    │ 10x scaled
FACT_ENCOUNTER             │ 2,000   │ 15,000   │ 7.5x scaled
FACT_DIAGNOSIS             │ 3,000   │ 25,000   │ 8x scaled
FACT_MEDICATION            │ 2,500   │ 15,000   │ 6x scaled
FACT_REHAB_REFERRAL        │ 200     │ 2,000    │ 10x scaled
FACT_REHAB_SESSION         │ 4,000   │ 20,000   │ 5x scaled
FACT_REHAB_OUTCOME         │ 400     │ 4,000    │ 10x scaled
FACT_LAB_RESULT            │ 0       │ 10,000   │ NEW (30 LOINC tests)
RAW_VITAL_SIGNS            │ 0       │ 8,000    │ NEW (8 vital types)
RAW_CLAIMS                 │ 1,000   │ 5,000    │ 5x scaled
RAW_CLINICAL_NOTES         │ 0       │ 3,000    │ NEW (8 note types)
MODEL_CATALOG              │ 4       │ 4        │ Unchanged
───────────────────────────┼─────────┼──────────┼────────────
TOTAL                      │ ~13,600 │ ~112,004 │ 8.2x increase

NEW DATA FILLED:
  - FACT_LAB_RESULT: 30 LOINC-coded lab tests (Troponin, BNP, lipids, CBC, metabolic, coag)
  - RAW_VITAL_SIGNS: 8 vital types (HR, SBP, DBP, RR, Temp, SpO2, Weight, Pain)
  - RAW_CLINICAL_NOTES: 8 note types with realistic cardiac rehab clinical text

================================================================================
*/

SELECT '============================================' AS separator
UNION ALL SELECT '  DATA SCALE-UP COMPLETE: ~112K Records'
UNION ALL SELECT '  All zero-row tables now populated'
UNION ALL SELECT '  Health Domain - Healthcare Platform'
UNION ALL SELECT '============================================';
