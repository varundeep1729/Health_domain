-- ============================================================
-- HEALTH_DOMAIN - DATABASE STRUCTURE
-- ============================================================
-- Phase 04: Database Structure (Simplified)
-- Script: 04_database_structure.sql
-- Version: 1.0.0
--
-- Description:
--   Creates 5 databases with simple schema structure for
--   Healthcare & Life Sciences Platform. No DEV/QA/PROD complexity.
--
-- Databases: 5 (Medallion Architecture)
--   1. HEALTH_GOVERNANCE_DB - Security, monitoring (2 schemas)
--   2. HEALTH_RAW_DB        - Bronze: CLINICAL_DATA, REFERENCE_DATA
--   3. HEALTH_TRANSFORM_DB  - Silver: CLEANSED, MASTER
--   4. HEALTH_ANALYTICS_DB  - Gold: CORE, REPORTING
--   5. HEALTH_AI_READY_DB   - Platinum: FEATURES, MODELS
--
-- Dependencies:
--   - Phase 01 completed (HEALTH_GOVERNANCE_DB.SECURITY exists)
--   - Phase 02 completed (7 roles exist)
--   - Phase 03 completed (4 warehouses exist)
-- ============================================================

USE ROLE ACCOUNTADMIN;

-- ============================================================
-- SECTION 1: COMPLETE HEALTH_GOVERNANCE_DB (2 schemas)
-- ============================================================
-- Phase 01 created SECURITY schema. Add MONITORING schema.

USE DATABASE HEALTH_GOVERNANCE_DB;

CREATE SCHEMA IF NOT EXISTS MONITORING
    COMMENT = 'Cost monitoring, query performance, usage tracking, masking policies, tags, audit views';

-- VERIFICATION
SHOW SCHEMAS IN DATABASE HEALTH_GOVERNANCE_DB;


-- ============================================================
-- SECTION 2: HEALTH_RAW_DB — BRONZE LAYER
-- ============================================================
-- Landing zone for raw data from EHR systems, claims feeds,
-- lab interfaces, cardiac rehab devices. Data stored as-is.

CREATE DATABASE IF NOT EXISTS HEALTH_RAW_DB
    DATA_RETENTION_TIME_IN_DAYS = 90
    COMMENT = 'Bronze Layer: Raw healthcare data from sources. EHR feeds, claims imports, lab interfaces, cardiac rehab devices. 90-day retention per HIPAA.';

USE DATABASE HEALTH_RAW_DB;

CREATE SCHEMA IF NOT EXISTS CLINICAL_DATA
    COMMENT = 'Raw clinical data - EHR patients, encounters, diagnoses, medications, procedures, cardiac rehab, labs, vitals from Epic/Cerner';

CREATE SCHEMA IF NOT EXISTS REFERENCE_DATA
    COMMENT = 'Raw reference/claims data - insurance claims, CMS billing, payer info, lookup tables';

-- VERIFICATION
SHOW SCHEMAS IN DATABASE HEALTH_RAW_DB;


-- ============================================================
-- SECTION 3: HEALTH_TRANSFORM_DB — SILVER LAYER
-- ============================================================
-- Cleansed, validated, standardized clinical data with
-- ICD mapping, medication normalisation, risk stratification.

CREATE DATABASE IF NOT EXISTS HEALTH_TRANSFORM_DB
    DATA_RETENTION_TIME_IN_DAYS = 30
    COMMENT = 'Silver Layer: Cleansed and validated healthcare data. Business rules applied, ICD mapped, medications normalised. 30-day retention.';

USE DATABASE HEALTH_TRANSFORM_DB;

CREATE SCHEMA IF NOT EXISTS CLEANSED
    COMMENT = 'Cleansed fact tables - validated encounters, diagnoses, medications, procedures, cardiac rehab sessions, lab results';

CREATE SCHEMA IF NOT EXISTS MASTER
    COMMENT = 'Master data dimensions - patients (SCD Type 2), care teams, reference lookups';

-- VERIFICATION
SHOW SCHEMAS IN DATABASE HEALTH_TRANSFORM_DB;


-- ============================================================
-- SECTION 4: HEALTH_ANALYTICS_DB — GOLD LAYER
-- ============================================================
-- Business-ready analytics optimised for clinical BI and reporting.

CREATE DATABASE IF NOT EXISTS HEALTH_ANALYTICS_DB
    DATA_RETENTION_TIME_IN_DAYS = 90
    COMMENT = 'Gold Layer: Business-ready clinical analytics for BI and reporting. 90-day retention for compliance.';

USE DATABASE HEALTH_ANALYTICS_DB;

CREATE SCHEMA IF NOT EXISTS CORE
    COMMENT = 'Core analytics - cardiac outcomes, population health, quality measures, clinical dashboards';

CREATE SCHEMA IF NOT EXISTS REPORTING
    COMMENT = 'Analyst-created reports, views, KPIs, claims summary, Streamlit dashboards';

-- VERIFICATION
SHOW SCHEMAS IN DATABASE HEALTH_ANALYTICS_DB;


-- ============================================================
-- SECTION 5: HEALTH_AI_READY_DB — PLATINUM LAYER
-- ============================================================
-- ML-ready data for clinical prediction models (PyHealth-aligned).

CREATE DATABASE IF NOT EXISTS HEALTH_AI_READY_DB
    DATA_RETENTION_TIME_IN_DAYS = 30
    COMMENT = 'Platinum Layer: ML-ready features, training data, model artifacts. PyHealth-aligned clinical prediction. 30-day retention.';

USE DATABASE HEALTH_AI_READY_DB;

CREATE SCHEMA IF NOT EXISTS FEATURES
    COMMENT = 'Feature store - clinical features, training datasets, embeddings for ML models';

CREATE SCHEMA IF NOT EXISTS MODELS
    COMMENT = 'Model artifacts - registry, predictions, experiment tracking';

-- VERIFICATION
SHOW SCHEMAS IN DATABASE HEALTH_AI_READY_DB;


-- ============================================================
-- SECTION 6: DATABASE GRANTS TO 7 ROLES
-- ============================================================

USE ROLE ACCOUNTADMIN;

-- ------------------------------------------------------------
-- HEALTH_GOVERNANCE_DB GRANTS
-- ------------------------------------------------------------
GRANT USAGE ON DATABASE HEALTH_GOVERNANCE_DB TO ROLE HEALTH_DATA_ADMIN;
GRANT USAGE ON DATABASE HEALTH_GOVERNANCE_DB TO ROLE HEALTH_READONLY;
GRANT USAGE ON ALL SCHEMAS IN DATABASE HEALTH_GOVERNANCE_DB TO ROLE HEALTH_DATA_ADMIN;
GRANT USAGE ON SCHEMA HEALTH_GOVERNANCE_DB.MONITORING TO ROLE HEALTH_READONLY;
GRANT SELECT ON FUTURE VIEWS IN SCHEMA HEALTH_GOVERNANCE_DB.MONITORING TO ROLE HEALTH_DATA_ADMIN;
GRANT SELECT ON FUTURE VIEWS IN SCHEMA HEALTH_GOVERNANCE_DB.MONITORING TO ROLE HEALTH_READONLY;

-- ------------------------------------------------------------
-- HEALTH_RAW_DB GRANTS
-- ------------------------------------------------------------
GRANT USAGE ON DATABASE HEALTH_RAW_DB TO ROLE HEALTH_DATA_ENGINEER;
GRANT USAGE ON SCHEMA HEALTH_RAW_DB.CLINICAL_DATA TO ROLE HEALTH_DATA_ENGINEER;
GRANT USAGE ON SCHEMA HEALTH_RAW_DB.REFERENCE_DATA TO ROLE HEALTH_DATA_ENGINEER;
GRANT CREATE TABLE, CREATE VIEW, CREATE STAGE ON SCHEMA HEALTH_RAW_DB.CLINICAL_DATA TO ROLE HEALTH_DATA_ENGINEER;
GRANT CREATE TABLE, CREATE VIEW, CREATE STAGE ON SCHEMA HEALTH_RAW_DB.REFERENCE_DATA TO ROLE HEALTH_DATA_ENGINEER;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA HEALTH_RAW_DB.CLINICAL_DATA TO ROLE HEALTH_DATA_ENGINEER;
GRANT ALL PRIVILEGES ON FUTURE TABLES IN SCHEMA HEALTH_RAW_DB.CLINICAL_DATA TO ROLE HEALTH_DATA_ENGINEER;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA HEALTH_RAW_DB.REFERENCE_DATA TO ROLE HEALTH_DATA_ENGINEER;
GRANT ALL PRIVILEGES ON FUTURE TABLES IN SCHEMA HEALTH_RAW_DB.REFERENCE_DATA TO ROLE HEALTH_DATA_ENGINEER;

GRANT OWNERSHIP ON DATABASE HEALTH_RAW_DB TO ROLE HEALTH_DATA_ADMIN COPY CURRENT GRANTS;

-- ------------------------------------------------------------
-- HEALTH_TRANSFORM_DB GRANTS
-- ------------------------------------------------------------
GRANT USAGE ON DATABASE HEALTH_TRANSFORM_DB TO ROLE HEALTH_DATA_ENGINEER;
GRANT USAGE ON SCHEMA HEALTH_TRANSFORM_DB.CLEANSED TO ROLE HEALTH_DATA_ENGINEER;
GRANT USAGE ON SCHEMA HEALTH_TRANSFORM_DB.MASTER TO ROLE HEALTH_DATA_ENGINEER;
GRANT CREATE TABLE, CREATE VIEW, CREATE DYNAMIC TABLE ON SCHEMA HEALTH_TRANSFORM_DB.CLEANSED TO ROLE HEALTH_DATA_ENGINEER;
GRANT CREATE TABLE, CREATE VIEW, CREATE DYNAMIC TABLE ON SCHEMA HEALTH_TRANSFORM_DB.MASTER TO ROLE HEALTH_DATA_ENGINEER;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA HEALTH_TRANSFORM_DB.CLEANSED TO ROLE HEALTH_DATA_ENGINEER;
GRANT ALL PRIVILEGES ON FUTURE TABLES IN SCHEMA HEALTH_TRANSFORM_DB.CLEANSED TO ROLE HEALTH_DATA_ENGINEER;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA HEALTH_TRANSFORM_DB.MASTER TO ROLE HEALTH_DATA_ENGINEER;
GRANT ALL PRIVILEGES ON FUTURE TABLES IN SCHEMA HEALTH_TRANSFORM_DB.MASTER TO ROLE HEALTH_DATA_ENGINEER;

GRANT USAGE ON DATABASE HEALTH_TRANSFORM_DB TO ROLE HEALTH_ML_ENGINEER;
GRANT USAGE ON SCHEMA HEALTH_TRANSFORM_DB.CLEANSED TO ROLE HEALTH_ML_ENGINEER;
GRANT USAGE ON SCHEMA HEALTH_TRANSFORM_DB.MASTER TO ROLE HEALTH_ML_ENGINEER;
GRANT SELECT ON ALL TABLES IN SCHEMA HEALTH_TRANSFORM_DB.CLEANSED TO ROLE HEALTH_ML_ENGINEER;
GRANT SELECT ON FUTURE TABLES IN SCHEMA HEALTH_TRANSFORM_DB.CLEANSED TO ROLE HEALTH_ML_ENGINEER;
GRANT SELECT ON ALL TABLES IN SCHEMA HEALTH_TRANSFORM_DB.MASTER TO ROLE HEALTH_ML_ENGINEER;
GRANT SELECT ON FUTURE TABLES IN SCHEMA HEALTH_TRANSFORM_DB.MASTER TO ROLE HEALTH_ML_ENGINEER;

GRANT USAGE ON DATABASE HEALTH_TRANSFORM_DB TO ROLE HEALTH_ANALYST;
GRANT USAGE ON SCHEMA HEALTH_TRANSFORM_DB.CLEANSED TO ROLE HEALTH_ANALYST;
GRANT USAGE ON SCHEMA HEALTH_TRANSFORM_DB.MASTER TO ROLE HEALTH_ANALYST;
GRANT SELECT ON ALL TABLES IN SCHEMA HEALTH_TRANSFORM_DB.CLEANSED TO ROLE HEALTH_ANALYST;
GRANT SELECT ON ALL VIEWS IN SCHEMA HEALTH_TRANSFORM_DB.CLEANSED TO ROLE HEALTH_ANALYST;
GRANT SELECT ON FUTURE TABLES IN SCHEMA HEALTH_TRANSFORM_DB.CLEANSED TO ROLE HEALTH_ANALYST;
GRANT SELECT ON FUTURE VIEWS IN SCHEMA HEALTH_TRANSFORM_DB.CLEANSED TO ROLE HEALTH_ANALYST;
GRANT SELECT ON ALL TABLES IN SCHEMA HEALTH_TRANSFORM_DB.MASTER TO ROLE HEALTH_ANALYST;
GRANT SELECT ON FUTURE TABLES IN SCHEMA HEALTH_TRANSFORM_DB.MASTER TO ROLE HEALTH_ANALYST;

GRANT OWNERSHIP ON DATABASE HEALTH_TRANSFORM_DB TO ROLE HEALTH_DATA_ADMIN COPY CURRENT GRANTS;

-- ------------------------------------------------------------
-- HEALTH_ANALYTICS_DB GRANTS
-- ------------------------------------------------------------
GRANT USAGE ON DATABASE HEALTH_ANALYTICS_DB TO ROLE HEALTH_READONLY;
GRANT USAGE ON ALL SCHEMAS IN DATABASE HEALTH_ANALYTICS_DB TO ROLE HEALTH_READONLY;
GRANT SELECT ON ALL TABLES IN DATABASE HEALTH_ANALYTICS_DB TO ROLE HEALTH_READONLY;
GRANT SELECT ON ALL VIEWS IN DATABASE HEALTH_ANALYTICS_DB TO ROLE HEALTH_READONLY;
GRANT SELECT ON FUTURE TABLES IN DATABASE HEALTH_ANALYTICS_DB TO ROLE HEALTH_READONLY;
GRANT SELECT ON FUTURE VIEWS IN DATABASE HEALTH_ANALYTICS_DB TO ROLE HEALTH_READONLY;

GRANT USAGE ON DATABASE HEALTH_ANALYTICS_DB TO ROLE HEALTH_ANALYST;
GRANT USAGE ON SCHEMA HEALTH_ANALYTICS_DB.CORE TO ROLE HEALTH_ANALYST;
GRANT USAGE ON SCHEMA HEALTH_ANALYTICS_DB.REPORTING TO ROLE HEALTH_ANALYST;
GRANT CREATE TABLE, CREATE VIEW ON SCHEMA HEALTH_ANALYTICS_DB.REPORTING TO ROLE HEALTH_ANALYST;

GRANT USAGE ON DATABASE HEALTH_ANALYTICS_DB TO ROLE HEALTH_DATA_ENGINEER;
GRANT USAGE ON SCHEMA HEALTH_ANALYTICS_DB.CORE TO ROLE HEALTH_DATA_ENGINEER;
GRANT USAGE ON SCHEMA HEALTH_ANALYTICS_DB.REPORTING TO ROLE HEALTH_DATA_ENGINEER;
GRANT CREATE TABLE, CREATE VIEW, CREATE DYNAMIC TABLE ON SCHEMA HEALTH_ANALYTICS_DB.CORE TO ROLE HEALTH_DATA_ENGINEER;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA HEALTH_ANALYTICS_DB.CORE TO ROLE HEALTH_DATA_ENGINEER;
GRANT ALL PRIVILEGES ON FUTURE TABLES IN SCHEMA HEALTH_ANALYTICS_DB.CORE TO ROLE HEALTH_DATA_ENGINEER;

GRANT USAGE ON DATABASE HEALTH_ANALYTICS_DB TO ROLE HEALTH_ML_ENGINEER;
GRANT USAGE ON SCHEMA HEALTH_ANALYTICS_DB.CORE TO ROLE HEALTH_ML_ENGINEER;
GRANT USAGE ON SCHEMA HEALTH_ANALYTICS_DB.REPORTING TO ROLE HEALTH_ML_ENGINEER;
GRANT SELECT ON ALL TABLES IN DATABASE HEALTH_ANALYTICS_DB TO ROLE HEALTH_ML_ENGINEER;
GRANT SELECT ON FUTURE TABLES IN DATABASE HEALTH_ANALYTICS_DB TO ROLE HEALTH_ML_ENGINEER;

GRANT USAGE ON DATABASE HEALTH_ANALYTICS_DB TO ROLE HEALTH_APP_ADMIN;
GRANT USAGE ON SCHEMA HEALTH_ANALYTICS_DB.CORE TO ROLE HEALTH_APP_ADMIN;
GRANT USAGE ON SCHEMA HEALTH_ANALYTICS_DB.REPORTING TO ROLE HEALTH_APP_ADMIN;
GRANT CREATE STREAMLIT ON SCHEMA HEALTH_ANALYTICS_DB.REPORTING TO ROLE HEALTH_APP_ADMIN;
GRANT SELECT ON ALL TABLES IN DATABASE HEALTH_ANALYTICS_DB TO ROLE HEALTH_APP_ADMIN;
GRANT SELECT ON ALL VIEWS IN DATABASE HEALTH_ANALYTICS_DB TO ROLE HEALTH_APP_ADMIN;

GRANT OWNERSHIP ON DATABASE HEALTH_ANALYTICS_DB TO ROLE HEALTH_DATA_ADMIN COPY CURRENT GRANTS;

-- ------------------------------------------------------------
-- HEALTH_AI_READY_DB GRANTS
-- ------------------------------------------------------------
GRANT USAGE ON DATABASE HEALTH_AI_READY_DB TO ROLE HEALTH_ML_ENGINEER;
GRANT USAGE ON SCHEMA HEALTH_AI_READY_DB.FEATURES TO ROLE HEALTH_ML_ENGINEER;
GRANT USAGE ON SCHEMA HEALTH_AI_READY_DB.MODELS TO ROLE HEALTH_ML_ENGINEER;
GRANT CREATE TABLE, CREATE VIEW ON SCHEMA HEALTH_AI_READY_DB.FEATURES TO ROLE HEALTH_ML_ENGINEER;
GRANT CREATE TABLE, CREATE VIEW ON SCHEMA HEALTH_AI_READY_DB.MODELS TO ROLE HEALTH_ML_ENGINEER;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA HEALTH_AI_READY_DB.FEATURES TO ROLE HEALTH_ML_ENGINEER;
GRANT ALL PRIVILEGES ON FUTURE TABLES IN SCHEMA HEALTH_AI_READY_DB.FEATURES TO ROLE HEALTH_ML_ENGINEER;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA HEALTH_AI_READY_DB.MODELS TO ROLE HEALTH_ML_ENGINEER;
GRANT ALL PRIVILEGES ON FUTURE TABLES IN SCHEMA HEALTH_AI_READY_DB.MODELS TO ROLE HEALTH_ML_ENGINEER;

GRANT USAGE ON DATABASE HEALTH_AI_READY_DB TO ROLE HEALTH_DATA_ENGINEER;
GRANT USAGE ON SCHEMA HEALTH_AI_READY_DB.FEATURES TO ROLE HEALTH_DATA_ENGINEER;
GRANT SELECT ON ALL TABLES IN SCHEMA HEALTH_AI_READY_DB.FEATURES TO ROLE HEALTH_DATA_ENGINEER;
GRANT SELECT ON FUTURE TABLES IN SCHEMA HEALTH_AI_READY_DB.FEATURES TO ROLE HEALTH_DATA_ENGINEER;
GRANT CREATE TABLE, CREATE VIEW ON SCHEMA HEALTH_AI_READY_DB.FEATURES TO ROLE HEALTH_DATA_ENGINEER;
GRANT INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA HEALTH_AI_READY_DB.FEATURES TO ROLE HEALTH_DATA_ENGINEER;

GRANT OWNERSHIP ON DATABASE HEALTH_AI_READY_DB TO ROLE HEALTH_ML_ADMIN COPY CURRENT GRANTS;


-- ============================================================
-- SECTION 7: VERIFICATION
-- ============================================================

SHOW DATABASES LIKE 'HEALTH_%';

SELECT 'HEALTH_GOVERNANCE_DB' AS database_name, COUNT(*) AS schema_count
FROM HEALTH_GOVERNANCE_DB.INFORMATION_SCHEMA.SCHEMATA
WHERE SCHEMA_NAME NOT IN ('INFORMATION_SCHEMA', 'PUBLIC')
UNION ALL
SELECT 'HEALTH_RAW_DB', COUNT(*)
FROM HEALTH_RAW_DB.INFORMATION_SCHEMA.SCHEMATA
WHERE SCHEMA_NAME NOT IN ('INFORMATION_SCHEMA', 'PUBLIC')
UNION ALL
SELECT 'HEALTH_TRANSFORM_DB', COUNT(*)
FROM HEALTH_TRANSFORM_DB.INFORMATION_SCHEMA.SCHEMATA
WHERE SCHEMA_NAME NOT IN ('INFORMATION_SCHEMA', 'PUBLIC')
UNION ALL
SELECT 'HEALTH_ANALYTICS_DB', COUNT(*)
FROM HEALTH_ANALYTICS_DB.INFORMATION_SCHEMA.SCHEMATA
WHERE SCHEMA_NAME NOT IN ('INFORMATION_SCHEMA', 'PUBLIC')
UNION ALL
SELECT 'HEALTH_AI_READY_DB', COUNT(*)
FROM HEALTH_AI_READY_DB.INFORMATION_SCHEMA.SCHEMATA
WHERE SCHEMA_NAME NOT IN ('INFORMATION_SCHEMA', 'PUBLIC')
ORDER BY database_name;

SHOW GRANTS ON DATABASE HEALTH_RAW_DB;
SHOW GRANTS ON DATABASE HEALTH_ANALYTICS_DB;
SHOW GRANTS ON DATABASE HEALTH_AI_READY_DB;


-- ============================================================
-- SECTION 8: CREATE RAW LAYER TABLES
-- ============================================================
USE ROLE SYSADMIN;
USE DATABASE HEALTH_RAW_DB;
USE SCHEMA CLINICAL_DATA;

CREATE TABLE IF NOT EXISTS RAW_PATIENTS (
    record_id           NUMBER AUTOINCREMENT,
    patient_id          VARCHAR(50),
    first_name          VARCHAR(100),
    last_name           VARCHAR(100),
    date_of_birth       DATE,
    gender              VARCHAR(10),
    ethnicity           VARCHAR(50),
    ssn                 VARCHAR(11),
    address             VARCHAR(500),
    phone               VARCHAR(20),
    email               VARCHAR(200),
    insurance_id        VARCHAR(50),
    primary_language    VARCHAR(50),
    marital_status      VARCHAR(20),
    source_system       VARCHAR(50),
    source_file         VARCHAR(500),
    load_timestamp      TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    PRIMARY KEY (record_id)
)
COMMENT = 'Raw patient demographics from EHR feeds (Epic/Cerner)';

CREATE TABLE IF NOT EXISTS RAW_ENCOUNTERS (
    record_id           NUMBER AUTOINCREMENT,
    raw_data            VARIANT,
    encounter_id        VARCHAR(50),
    patient_id          VARCHAR(50),
    encounter_type      VARCHAR(30),
    admit_date          TIMESTAMP_NTZ,
    discharge_date      TIMESTAMP_NTZ,
    department          VARCHAR(100),
    attending_provider  VARCHAR(100),
    facility_code       VARCHAR(20),
    admit_diagnosis_code VARCHAR(20),
    discharge_status    VARCHAR(30),
    source_system       VARCHAR(50),
    load_timestamp      TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
)
COMMENT = 'Raw encounters/visits from EHR';

CREATE TABLE IF NOT EXISTS RAW_DIAGNOSES (
    record_id           NUMBER AUTOINCREMENT,
    raw_data            VARIANT,
    diagnosis_id        VARCHAR(50),
    patient_id          VARCHAR(50),
    encounter_id        VARCHAR(50),
    icd_code            VARCHAR(20),
    icd_version         VARCHAR(5),
    description         VARCHAR(500),
    diagnosis_type      VARCHAR(30),
    diagnosis_date      DATE,
    source_system       VARCHAR(50),
    load_timestamp      TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
)
COMMENT = 'Raw diagnosis records with ICD codes';

CREATE TABLE IF NOT EXISTS RAW_MEDICATIONS (
    record_id           NUMBER AUTOINCREMENT,
    raw_data            VARIANT,
    medication_id       VARCHAR(50),
    patient_id          VARCHAR(50),
    encounter_id        VARCHAR(50),
    ndc_code            VARCHAR(20),
    medication_name     VARCHAR(200),
    dosage              VARCHAR(100),
    route               VARCHAR(50),
    frequency           VARCHAR(50),
    prescriber          VARCHAR(100),
    start_date          DATE,
    end_date            DATE,
    source_system       VARCHAR(50),
    load_timestamp      TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
)
COMMENT = 'Raw medication orders and prescriptions';

CREATE TABLE IF NOT EXISTS RAW_PROCEDURES (
    record_id           NUMBER AUTOINCREMENT,
    raw_data            VARIANT,
    procedure_id        VARCHAR(50),
    patient_id          VARCHAR(50),
    encounter_id        VARCHAR(50),
    cpt_code            VARCHAR(20),
    icd_proc_code       VARCHAR(20),
    description         VARCHAR(500),
    procedure_date      DATE,
    performing_provider VARCHAR(100),
    source_system       VARCHAR(50),
    load_timestamp      TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
)
COMMENT = 'Raw procedure records (CPT, ICD-PROC)';

CREATE TABLE IF NOT EXISTS RAW_LAB_RESULTS (
    record_id           NUMBER AUTOINCREMENT,
    raw_data            VARIANT,
    lab_id              VARCHAR(50),
    patient_id          VARCHAR(50),
    encounter_id        VARCHAR(50),
    loinc_code          VARCHAR(20),
    test_name           VARCHAR(200),
    result_value        VARCHAR(100),
    result_numeric      FLOAT,
    unit                VARCHAR(50),
    reference_low       FLOAT,
    reference_high      FLOAT,
    abnormal_flag       VARCHAR(10),
    collected_at        TIMESTAMP_NTZ,
    source_system       VARCHAR(50),
    load_timestamp      TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
)
COMMENT = 'Raw lab results from LIS';

CREATE TABLE IF NOT EXISTS RAW_VITAL_SIGNS (
    record_id           NUMBER AUTOINCREMENT,
    raw_data            VARIANT,
    vital_id            VARCHAR(50),
    patient_id          VARCHAR(50),
    encounter_id        VARCHAR(50),
    vital_type          VARCHAR(50),
    value_numeric       FLOAT,
    unit                VARCHAR(20),
    measured_at         TIMESTAMP_NTZ,
    measured_by         VARCHAR(100),
    source_system       VARCHAR(50),
    load_timestamp      TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
)
COMMENT = 'Raw vital signs from bedside monitors';

CREATE TABLE IF NOT EXISTS RAW_REHAB_REFERRALS (
    record_id               NUMBER AUTOINCREMENT,
    raw_data                VARIANT,
    referral_id             VARCHAR(50),
    patient_id              VARCHAR(50),
    referring_physician     VARCHAR(100),
    qualifying_diagnosis    VARCHAR(100),
    cardiac_event_date      DATE,
    lvef_percent            FLOAT,
    gxt_peak_hr             INT,
    gxt_peak_mets           FLOAT,
    ischemic_threshold      VARCHAR(100),
    aacvpr_risk_category    VARCHAR(20),
    referral_date           DATE,
    source_system           VARCHAR(50),
    load_timestamp          TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
)
COMMENT = 'Raw cardiac rehab referrals per AACVPR guidelines';

CREATE TABLE IF NOT EXISTS RAW_REHAB_SESSIONS (
    record_id               NUMBER AUTOINCREMENT,
    raw_data                VARIANT,
    session_id              VARCHAR(50),
    referral_id             VARCHAR(50),
    patient_id              VARCHAR(50),
    session_number          INT,
    session_date            DATE,
    modality                VARCHAR(100),
    duration_minutes        INT,
    target_hr_low           INT,
    target_hr_high          INT,
    resting_hr              INT,
    peak_hr                 INT,
    recovery_hr             INT,
    resting_bp_systolic     INT,
    resting_bp_diastolic    INT,
    peak_bp_systolic        INT,
    peak_bp_diastolic       INT,
    post_bp_systolic        INT,
    post_bp_diastolic       INT,
    rpe_peak                INT,
    spo2_min                FLOAT,
    ecg_rhythm              VARCHAR(100),
    ecg_monitor_minutes     INT,
    symptoms                VARCHAR(500),
    adverse_events          VARCHAR(500),
    exercise_terminated_early BOOLEAN DEFAULT FALSE,
    termination_reason      VARCHAR(200),
    therapist               VARCHAR(100),
    source_system           VARCHAR(50),
    load_timestamp          TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
)
COMMENT = 'Raw cardiac rehab exercise sessions with telemetry';

CREATE TABLE IF NOT EXISTS RAW_REHAB_OUTCOMES (
    record_id               NUMBER AUTOINCREMENT,
    raw_data                VARIANT,
    outcome_id              VARCHAR(50),
    referral_id             VARCHAR(50),
    patient_id              VARCHAR(50),
    measurement_type        VARCHAR(50),
    measurement_point       VARCHAR(30),
    measurement_date        DATE,
    six_min_walk_meters     FLOAT,
    peak_mets               FLOAT,
    dasi_score              FLOAT,
    phq9_score              INT,
    weight_kg               FLOAT,
    bmi                     FLOAT,
    waist_cm                FLOAT,
    hba1c                   FLOAT,
    ldl                     FLOAT,
    hdl                     FLOAT,
    total_cholesterol       FLOAT,
    triglycerides           FLOAT,
    source_system           VARCHAR(50),
    load_timestamp          TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
)
COMMENT = 'Raw cardiac rehab outcome measurements (6MWT, DASI, PHQ-9)';

USE SCHEMA REFERENCE_DATA;

CREATE TABLE IF NOT EXISTS RAW_CLAIMS (
    record_id               NUMBER AUTOINCREMENT,
    raw_data                VARIANT,
    claim_id                VARCHAR(50),
    patient_id              VARCHAR(50),
    encounter_id            VARCHAR(50),
    payer_id                VARCHAR(50),
    payer_name              VARCHAR(200),
    claim_type              VARCHAR(30),
    service_date            DATE,
    cpt_code                VARCHAR(20),
    drg_code                VARCHAR(10),
    billed_amount           NUMBER(12,2),
    allowed_amount          NUMBER(12,2),
    paid_amount             NUMBER(12,2),
    patient_responsibility  NUMBER(12,2),
    claim_status            VARCHAR(30),
    denial_reason           VARCHAR(200),
    source_system           VARCHAR(50),
    load_timestamp          TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
)
COMMENT = 'Raw insurance/CMS claims data';


-- ============================================================
-- SECTION 9: CREATE TRANSFORM LAYER TABLES
-- ============================================================
USE DATABASE HEALTH_TRANSFORM_DB;
USE SCHEMA MASTER;

CREATE TABLE IF NOT EXISTS DIM_PATIENT (
    patient_key         NUMBER AUTOINCREMENT,
    patient_id          VARCHAR(50) NOT NULL,
    first_name          VARCHAR(100),
    last_name           VARCHAR(100),
    date_of_birth       DATE,
    age                 NUMBER,
    gender              VARCHAR(10),
    ethnicity           VARCHAR(50),
    ssn                 VARCHAR(11),
    address             VARCHAR(500),
    phone               VARCHAR(20),
    email               VARCHAR(200),
    insurance_id        VARCHAR(50),
    primary_language    VARCHAR(50),
    marital_status      VARCHAR(20),
    is_active           BOOLEAN DEFAULT TRUE,
    effective_from      TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    effective_to        TIMESTAMP_NTZ DEFAULT '9999-12-31 00:00:00'::TIMESTAMP_NTZ,
    is_current          BOOLEAN DEFAULT TRUE,
    PRIMARY KEY (patient_key)
)
COMMENT = 'Patient demographics dimension - SCD Type 2 with PHI';

CREATE TABLE IF NOT EXISTS CARE_TEAM_ASSIGNMENTS (
    assignment_id       NUMBER AUTOINCREMENT,
    patient_id          VARCHAR(50),
    care_team_id        VARCHAR(50),
    clinician_user      VARCHAR(100),
    role_in_team        VARCHAR(50),
    assigned_date       DATE,
    end_date            DATE,
    PRIMARY KEY (assignment_id)
)
COMMENT = 'Care team assignments for row-level security';

USE SCHEMA CLEANSED;

CREATE TABLE IF NOT EXISTS FACT_ENCOUNTER (
    encounter_key       NUMBER AUTOINCREMENT,
    encounter_id        VARCHAR(50) NOT NULL,
    patient_id          VARCHAR(50) NOT NULL,
    encounter_type      VARCHAR(30),
    admit_date          TIMESTAMP_NTZ,
    discharge_date      TIMESTAMP_NTZ,
    length_of_stay_days NUMBER,
    department          VARCHAR(100),
    attending_provider  VARCHAR(100),
    facility_code       VARCHAR(20),
    admit_diagnosis_code VARCHAR(20),
    discharge_status    VARCHAR(30),
    load_timestamp      TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    PRIMARY KEY (encounter_key),
    UNIQUE (encounter_id)
)
COMMENT = 'Cleansed encounters with LOS calculation';

CREATE TABLE IF NOT EXISTS FACT_DIAGNOSIS (
    diagnosis_key       NUMBER AUTOINCREMENT,
    diagnosis_id        VARCHAR(50) NOT NULL,
    encounter_id        VARCHAR(50),
    patient_id          VARCHAR(50) NOT NULL,
    icd_code            VARCHAR(20),
    icd_version         VARCHAR(5),
    description         VARCHAR(500),
    diagnosis_type      VARCHAR(30),
    diagnosis_date      DATE,
    cardiac_category    VARCHAR(50),
    load_timestamp      TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    PRIMARY KEY (diagnosis_key),
    UNIQUE (diagnosis_id)
)
COMMENT = 'Cleansed diagnoses with cardiac category grouping';

CREATE TABLE IF NOT EXISTS FACT_MEDICATION (
    medication_key      NUMBER AUTOINCREMENT,
    medication_id       VARCHAR(50) NOT NULL,
    encounter_id        VARCHAR(50),
    patient_id          VARCHAR(50) NOT NULL,
    ndc_code            VARCHAR(20),
    medication_name     VARCHAR(200),
    dosage              VARCHAR(100),
    route               VARCHAR(50),
    frequency           VARCHAR(50),
    prescriber          VARCHAR(100),
    start_date          DATE,
    end_date            DATE,
    drug_class          VARCHAR(50),
    load_timestamp      TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    PRIMARY KEY (medication_key),
    UNIQUE (medication_id)
)
COMMENT = 'Cleansed medications with drug class mapping';

CREATE TABLE IF NOT EXISTS FACT_REHAB_REFERRAL (
    referral_key        NUMBER AUTOINCREMENT,
    referral_id         VARCHAR(50) NOT NULL,
    patient_id          VARCHAR(50) NOT NULL,
    referring_physician VARCHAR(100),
    qualifying_diagnosis VARCHAR(100),
    cardiac_event_date  DATE,
    lvef_percent        FLOAT,
    gxt_peak_hr         INT,
    gxt_peak_mets       FLOAT,
    ischemic_threshold  VARCHAR(100),
    aacvpr_risk_category VARCHAR(20),
    computed_risk       VARCHAR(20),
    referral_date       DATE,
    days_event_to_referral NUMBER,
    load_timestamp      TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    PRIMARY KEY (referral_key),
    UNIQUE (referral_id)
)
COMMENT = 'Cardiac rehab referrals with AACVPR risk stratification';

CREATE TABLE IF NOT EXISTS FACT_REHAB_SESSION (
    session_key         NUMBER AUTOINCREMENT,
    session_id          VARCHAR(50) NOT NULL,
    referral_id         VARCHAR(50),
    patient_id          VARCHAR(50) NOT NULL,
    session_number      INT,
    session_date        DATE,
    modality            VARCHAR(100),
    duration_minutes    INT,
    target_hr_low       INT,
    target_hr_high      INT,
    resting_hr          INT,
    peak_hr             INT,
    recovery_hr         INT,
    resting_bp_systolic INT,
    resting_bp_diastolic INT,
    peak_bp_systolic    INT,
    peak_bp_diastolic   INT,
    post_bp_systolic    INT,
    post_bp_diastolic   INT,
    rpe_peak            INT,
    spo2_min            FLOAT,
    ecg_rhythm          VARCHAR(100),
    ecg_monitor_minutes INT,
    symptoms            VARCHAR(500),
    adverse_events      VARCHAR(500),
    exercise_terminated_early BOOLEAN DEFAULT FALSE,
    termination_reason  VARCHAR(200),
    therapist           VARCHAR(100),
    achieved_hrr_percent FLOAT,
    hr_recovery_delta   INT,
    safety_flag         BOOLEAN DEFAULT FALSE,
    load_timestamp      TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    PRIMARY KEY (session_key),
    UNIQUE (session_id)
)
COMMENT = 'Cardiac rehab sessions with hemodynamic calculations and safety flags';

CREATE TABLE IF NOT EXISTS FACT_REHAB_OUTCOME (
    outcome_key         NUMBER AUTOINCREMENT,
    outcome_id          VARCHAR(50) NOT NULL,
    referral_id         VARCHAR(50),
    patient_id          VARCHAR(50) NOT NULL,
    measurement_type    VARCHAR(50),
    measurement_point   VARCHAR(30),
    measurement_date    DATE,
    six_min_walk_meters FLOAT,
    peak_mets           FLOAT,
    dasi_score          FLOAT,
    phq9_score          INT,
    weight_kg           FLOAT,
    bmi                 FLOAT,
    waist_cm            FLOAT,
    hba1c               FLOAT,
    ldl                 FLOAT,
    hdl                 FLOAT,
    total_cholesterol   FLOAT,
    triglycerides       FLOAT,
    depression_severity VARCHAR(30),
    load_timestamp      TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    PRIMARY KEY (outcome_key),
    UNIQUE (outcome_id)
)
COMMENT = 'Cardiac rehab outcome measurements with depression severity';

CREATE TABLE IF NOT EXISTS FACT_LAB_RESULT (
    lab_key             NUMBER AUTOINCREMENT,
    lab_id              VARCHAR(50) NOT NULL,
    encounter_id        VARCHAR(50),
    patient_id          VARCHAR(50) NOT NULL,
    loinc_code          VARCHAR(20),
    test_name           VARCHAR(200),
    result_value        VARCHAR(100),
    result_numeric      FLOAT,
    unit                VARCHAR(50),
    reference_low       FLOAT,
    reference_high      FLOAT,
    abnormal_flag       VARCHAR(10),
    computed_flag       VARCHAR(10),
    collected_at        TIMESTAMP_NTZ,
    load_timestamp      TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    PRIMARY KEY (lab_key),
    UNIQUE (lab_id)
)
COMMENT = 'Cleansed lab results with computed abnormal flags';


-- ============================================================
-- SECTION 10: CREATE ANALYTICS LAYER VIEWS
-- ============================================================
USE DATABASE HEALTH_ANALYTICS_DB;
USE SCHEMA CORE;

CREATE OR REPLACE VIEW VW_REHAB_PROGRAM_SUMMARY AS
SELECT
    R.patient_id,
    R.referral_id,
    R.qualifying_diagnosis,
    R.computed_risk                                   AS risk_category,
    R.lvef_percent,
    R.referral_date,
    R.days_event_to_referral,
    COUNT(S.session_id)                               AS total_sessions,
    MIN(S.session_date)                               AS first_session_date,
    MAX(S.session_date)                               AS last_session_date,
    DATEDIFF('WEEK', MIN(S.session_date), MAX(S.session_date)) AS program_weeks,
    AVG(S.duration_minutes)                           AS avg_duration_min,
    AVG(S.achieved_hrr_percent)                       AS avg_hrr_percent,
    AVG(S.rpe_peak)                                   AS avg_rpe,
    SUM(CASE WHEN S.safety_flag THEN 1 ELSE 0 END)   AS safety_flag_count,
    SUM(CASE WHEN S.exercise_terminated_early THEN 1 ELSE 0 END) AS early_terminations,
    ROUND(COUNT(S.session_id)::FLOAT / 36 * 100, 1)  AS adherence_rate_pct
FROM HEALTH_TRANSFORM_DB.CLEANSED.FACT_REHAB_REFERRAL R
LEFT JOIN HEALTH_TRANSFORM_DB.CLEANSED.FACT_REHAB_SESSION S
  ON R.referral_id = S.referral_id
GROUP BY 1,2,3,4,5,6,7;

CREATE OR REPLACE VIEW VW_OUTCOME_COMPARISON AS
SELECT
    B.patient_id,
    B.referral_id,
    B.six_min_walk_meters   AS baseline_6mwt,
    D.six_min_walk_meters   AS discharge_6mwt,
    D.six_min_walk_meters - B.six_min_walk_meters AS delta_6mwt,
    CASE WHEN (D.six_min_walk_meters - B.six_min_walk_meters) >= 25 THEN 'CLINICALLY_SIGNIFICANT' ELSE 'NOT_SIGNIFICANT' END AS mcid_6mwt,
    B.peak_mets             AS baseline_mets,
    D.peak_mets             AS discharge_mets,
    D.peak_mets - B.peak_mets AS delta_mets,
    B.phq9_score            AS baseline_phq9,
    D.phq9_score            AS discharge_phq9,
    D.phq9_score - B.phq9_score AS delta_phq9,
    B.bmi                   AS baseline_bmi,
    D.bmi                   AS discharge_bmi,
    B.ldl                   AS baseline_ldl,
    D.ldl                   AS discharge_ldl,
    B.hba1c                 AS baseline_hba1c,
    D.hba1c                 AS discharge_hba1c
FROM HEALTH_TRANSFORM_DB.CLEANSED.FACT_REHAB_OUTCOME B
JOIN HEALTH_TRANSFORM_DB.CLEANSED.FACT_REHAB_OUTCOME D
  ON B.referral_id = D.referral_id
WHERE B.measurement_point = 'BASELINE'
  AND D.measurement_point = 'DISCHARGE';

CREATE OR REPLACE VIEW VW_CARDIAC_COHORT AS
SELECT
    P.gender,
    P.ethnicity,
    CASE
      WHEN P.age < 45 THEN '<45'
      WHEN P.age < 55 THEN '45-54'
      WHEN P.age < 65 THEN '55-64'
      WHEN P.age < 75 THEN '65-74'
      ELSE '75+'
    END AS age_group,
    R.computed_risk AS risk_category,
    R.qualifying_diagnosis,
    COUNT(DISTINCT P.patient_id) AS patient_count,
    AVG(R.lvef_percent)          AS avg_lvef,
    AVG(R.gxt_peak_mets)        AS avg_peak_mets
FROM HEALTH_TRANSFORM_DB.MASTER.DIM_PATIENT P
JOIN HEALTH_TRANSFORM_DB.CLEANSED.FACT_REHAB_REFERRAL R
  ON P.patient_id = R.patient_id
GROUP BY 1,2,3,4,5;

CREATE OR REPLACE VIEW VW_DAILY_SESSION_METRICS AS
SELECT
    S.session_date,
    COUNT(*)                                          AS sessions_conducted,
    COUNT(DISTINCT S.patient_id)                      AS unique_patients,
    AVG(S.duration_minutes)                           AS avg_duration,
    AVG(S.peak_hr)                                    AS avg_peak_hr,
    AVG(S.rpe_peak)                                   AS avg_rpe,
    SUM(CASE WHEN S.safety_flag THEN 1 ELSE 0 END)   AS safety_incidents,
    SUM(S.ecg_monitor_minutes)                        AS total_ecg_minutes
FROM HEALTH_TRANSFORM_DB.CLEANSED.FACT_REHAB_SESSION S
GROUP BY 1
ORDER BY 1 DESC;

CREATE OR REPLACE VIEW VW_PATIENT_HEMODYNAMIC_TREND AS
SELECT
    S.patient_id,
    S.session_number,
    S.session_date,
    S.modality,
    S.resting_hr,
    S.peak_hr,
    S.recovery_hr,
    S.hr_recovery_delta,
    S.resting_bp_systolic || '/' || S.resting_bp_diastolic AS resting_bp,
    S.peak_bp_systolic || '/' || S.peak_bp_diastolic       AS peak_bp,
    S.rpe_peak,
    S.achieved_hrr_percent,
    S.spo2_min,
    S.ecg_rhythm,
    S.safety_flag,
    S.duration_minutes
FROM HEALTH_TRANSFORM_DB.CLEANSED.FACT_REHAB_SESSION S
ORDER BY S.patient_id, S.session_number;

CREATE OR REPLACE VIEW VW_CMS_CARDIAC_REHAB AS
SELECT
    DATE_TRUNC('MONTH', R.referral_date)::DATE AS referral_month,
    COUNT(DISTINCT R.referral_id)              AS total_referrals,
    COUNT(DISTINCT S.referral_id)              AS referrals_with_sessions,
    ROUND(COUNT(DISTINCT S.referral_id)::FLOAT / NULLIF(COUNT(DISTINCT R.referral_id), 0) * 100, 1) AS enrollment_rate_pct,
    AVG(R.days_event_to_referral)              AS avg_days_to_referral,
    COUNT(DISTINCT CASE WHEN PS.total_sessions >= 36 THEN R.referral_id END) AS completed_programs,
    ROUND(COUNT(DISTINCT CASE WHEN PS.total_sessions >= 36 THEN R.referral_id END)::FLOAT
          / NULLIF(COUNT(DISTINCT S.referral_id), 0) * 100, 1) AS completion_rate_pct
FROM HEALTH_TRANSFORM_DB.CLEANSED.FACT_REHAB_REFERRAL R
LEFT JOIN HEALTH_TRANSFORM_DB.CLEANSED.FACT_REHAB_SESSION S
  ON R.referral_id = S.referral_id
LEFT JOIN (
    SELECT referral_id, COUNT(*) AS total_sessions
    FROM HEALTH_TRANSFORM_DB.CLEANSED.FACT_REHAB_SESSION
    GROUP BY 1
) PS ON R.referral_id = PS.referral_id
GROUP BY 1
ORDER BY 1 DESC;

USE SCHEMA REPORTING;

CREATE OR REPLACE VIEW VW_CLAIMS_SUMMARY AS
SELECT
    DATE_TRUNC('MONTH', C.service_date)::DATE AS service_month,
    C.payer_name,
    C.claim_type,
    COUNT(*)                                  AS claim_count,
    SUM(C.billed_amount)                      AS total_billed,
    SUM(C.allowed_amount)                     AS total_allowed,
    SUM(C.paid_amount)                        AS total_paid,
    SUM(C.billed_amount - C.paid_amount)      AS total_write_off,
    ROUND(SUM(C.paid_amount) / NULLIF(SUM(C.billed_amount), 0) * 100, 1) AS collection_rate_pct,
    SUM(CASE WHEN C.claim_status = 'DENIED' THEN 1 ELSE 0 END) AS denials
FROM HEALTH_RAW_DB.REFERENCE_DATA.RAW_CLAIMS C
GROUP BY 1,2,3
ORDER BY 1 DESC;


-- ============================================================
-- SECTION 11: CREATE AI_READY LAYER TABLES
-- ============================================================
USE DATABASE HEALTH_AI_READY_DB;
USE SCHEMA FEATURES;

CREATE TABLE IF NOT EXISTS FACT_PATIENT_CLINICAL_FEATURES (
    feature_id          NUMBER AUTOINCREMENT,
    patient_id          VARCHAR(50) NOT NULL,
    age                 NUMBER,
    gender              VARCHAR(10),
    ethnicity           VARCHAR(50),
    total_diagnoses     NUMBER,
    unique_icd_codes    NUMBER,
    has_mi              BOOLEAN,
    has_heart_failure   BOOLEAN,
    has_atrial_fib      BOOLEAN,
    total_medications   NUMBER,
    on_beta_blocker     BOOLEAN,
    on_ace_inhibitor    BOOLEAN,
    on_anticoagulant    BOOLEAN,
    on_statin           BOOLEAN,
    distinct_drug_classes NUMBER,
    total_encounters    NUMBER,
    inpatient_visits    NUMBER,
    avg_length_of_stay  FLOAT,
    max_length_of_stay  NUMBER,
    latest_hba1c        FLOAT,
    latest_ldl          FLOAT,
    latest_hdl          FLOAT,
    latest_total_cholesterol FLOAT,
    abnormal_lab_ratio  FLOAT,
    created_at          TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    PRIMARY KEY (feature_id),
    UNIQUE (patient_id)
)
COMMENT = 'Patient-level clinical features for mortality/readmission prediction (PyHealth-aligned)';

CREATE TABLE IF NOT EXISTS FACT_CARDIAC_REHAB_FEATURES (
    feature_id          NUMBER AUTOINCREMENT,
    patient_id          VARCHAR(50) NOT NULL,
    referral_id         VARCHAR(50),
    session_id          VARCHAR(50),
    session_number      INT,
    risk_category       VARCHAR(20),
    lvef_percent        FLOAT,
    gxt_peak_mets       FLOAT,
    resting_hr          INT,
    peak_hr             INT,
    recovery_hr         INT,
    hr_recovery_delta   INT,
    achieved_hrr_percent FLOAT,
    resting_bp_systolic INT,
    peak_bp_systolic    INT,
    rpe_peak            INT,
    spo2_min            FLOAT,
    duration_minutes    INT,
    ecg_monitor_minutes INT,
    safety_flag         BOOLEAN,
    exercise_terminated_early BOOLEAN,
    rolling_3_avg_peak_hr    FLOAT,
    rolling_3_avg_rpe        FLOAT,
    rolling_3_avg_duration   FLOAT,
    peak_hr_delta            FLOAT,
    rpe_delta                FLOAT,
    duration_delta           FLOAT,
    created_at          TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    PRIMARY KEY (feature_id)
)
COMMENT = 'Cardiac rehab session features with rolling windows for adverse event prediction';

CREATE TABLE IF NOT EXISTS DS_MORTALITY_PREDICTION (
    record_id           NUMBER AUTOINCREMENT,
    patient_id          VARCHAR(50),
    age                 NUMBER,
    gender              VARCHAR(10),
    total_diagnoses     NUMBER,
    unique_icd_codes    NUMBER,
    has_mi              BOOLEAN,
    has_heart_failure   BOOLEAN,
    total_medications   NUMBER,
    on_beta_blocker     BOOLEAN,
    on_statin           BOOLEAN,
    distinct_drug_classes NUMBER,
    inpatient_visits    NUMBER,
    avg_length_of_stay  FLOAT,
    latest_hba1c        FLOAT,
    abnormal_lab_ratio  FLOAT,
    label_mortality     NUMBER,
    dataset_version     VARCHAR(10),
    created_at          TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    PRIMARY KEY (record_id)
)
COMMENT = 'Training dataset for ICU mortality prediction (RETAIN/Transformer)';

CREATE TABLE IF NOT EXISTS DS_CARDIAC_ADVERSE_EVENT (
    record_id           NUMBER AUTOINCREMENT,
    patient_id          VARCHAR(50),
    session_id          VARCHAR(50),
    session_number      INT,
    risk_category       VARCHAR(20),
    lvef_percent        FLOAT,
    resting_hr          INT,
    peak_hr             INT,
    rpe_peak            INT,
    spo2_min            FLOAT,
    duration_minutes    INT,
    rolling_3_avg_peak_hr FLOAT,
    peak_hr_delta       FLOAT,
    label_adverse_event NUMBER,
    dataset_version     VARCHAR(10),
    created_at          TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    PRIMARY KEY (record_id)
)
COMMENT = 'Training dataset for cardiac rehab adverse event prediction';

USE SCHEMA MODELS;

CREATE TABLE IF NOT EXISTS FACT_PREDICTIONS (
    prediction_id       NUMBER AUTOINCREMENT,
    model_name          VARCHAR(100),
    model_version       VARCHAR(50),
    prediction_date     DATE,
    patient_id          VARCHAR(50),
    predicted_risk      DECIMAL(10,6),
    predicted_class     NUMBER,
    confidence_score    DECIMAL(8,6),
    actual_outcome      NUMBER,
    is_correct          BOOLEAN,
    created_at          TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    PRIMARY KEY (prediction_id)
)
COMMENT = 'ML model predictions and actual clinical outcomes';

CREATE TABLE IF NOT EXISTS MODEL_CATALOG (
    model_id            VARCHAR(100),
    model_name          VARCHAR(200),
    model_version       VARCHAR(50),
    model_type          VARCHAR(100),
    task                VARCHAR(100),
    target_platform     VARCHAR(50),
    training_dataset    VARCHAR(200),
    feature_columns     VARIANT,
    hyperparameters     VARIANT,
    metrics             VARIANT,
    description         VARCHAR(2000),
    created_by          VARCHAR(100) DEFAULT CURRENT_USER(),
    created_at          TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    status              VARCHAR(20) DEFAULT 'ACTIVE',
    PRIMARY KEY (model_id, model_version)
)
COMMENT = 'Model registry catalog - PyHealth models (RETAIN, SafeDrug, Transformer)';


-- ============================================================
-- SECTION 12: GENERATE SYNTHETIC DATA (~10,000 Records)
-- ============================================================
USE ROLE SYSADMIN;

-- Lookup: Qualifying cardiac diagnoses
CREATE OR REPLACE TEMPORARY TABLE TEMP_CARDIAC_DIAGNOSES AS
SELECT column1 AS dx_code, column2 AS dx_name, column3 AS cardiac_category
FROM VALUES
    ('I21.0', 'STEMI of anterior wall', 'ACUTE_MI'),
    ('I21.1', 'STEMI of inferior wall', 'ACUTE_MI'),
    ('I21.3', 'STEMI of unspecified site', 'ACUTE_MI'),
    ('I21.4', 'NSTEMI', 'ACUTE_MI'),
    ('I25.10', 'Atherosclerotic heart disease', 'CHRONIC_IHD'),
    ('I25.110', 'Atherosclerotic heart disease of native vessel with unstable angina', 'CHRONIC_IHD'),
    ('I25.5', 'Ischemic cardiomyopathy', 'CHRONIC_IHD'),
    ('I50.20', 'Unspecified systolic heart failure', 'HEART_FAILURE'),
    ('I50.22', 'Chronic systolic heart failure', 'HEART_FAILURE'),
    ('I50.23', 'Acute on chronic systolic heart failure', 'HEART_FAILURE'),
    ('I50.30', 'Unspecified diastolic heart failure', 'HEART_FAILURE'),
    ('I50.32', 'Chronic diastolic heart failure', 'HEART_FAILURE'),
    ('I20.0', 'Unstable angina', 'ANGINA'),
    ('I20.9', 'Angina pectoris unspecified', 'ANGINA'),
    ('I48.0', 'Paroxysmal atrial fibrillation', 'ATRIAL_FIBRILLATION'),
    ('I48.1', 'Persistent atrial fibrillation', 'ATRIAL_FIBRILLATION'),
    ('I48.2', 'Chronic atrial fibrillation', 'ATRIAL_FIBRILLATION'),
    ('I42.0', 'Dilated cardiomyopathy', 'CARDIOMYOPATHY'),
    ('I42.9', 'Cardiomyopathy unspecified', 'CARDIOMYOPATHY'),
    ('Z95.1', 'Presence of CABG graft', 'CARDIAC_DEVICE'),
    ('Z95.5', 'Presence of coronary stent', 'CARDIAC_DEVICE'),
    ('Z95.2', 'Presence of prosthetic heart valve', 'CARDIAC_DEVICE'),
    ('I35.0', 'Aortic valve stenosis', 'VALVULAR'),
    ('I34.0', 'Mitral valve insufficiency', 'VALVULAR'),
    ('E11.9', 'Type 2 diabetes without complications', 'COMORBIDITY'),
    ('I10', 'Essential hypertension', 'COMORBIDITY'),
    ('E78.5', 'Hyperlipidemia unspecified', 'COMORBIDITY'),
    ('J44.1', 'COPD with acute exacerbation', 'COMORBIDITY'),
    ('N18.3', 'CKD stage 3', 'COMORBIDITY'),
    ('F32.1', 'Major depressive disorder moderate', 'COMORBIDITY')
AS t(column1, column2, column3);

CREATE OR REPLACE TEMPORARY TABLE TEMP_MEDICATIONS AS
SELECT column1 AS med_name, column2 AS drug_class
FROM VALUES
    ('Metoprolol Succinate 25mg', 'BETA_BLOCKER'),
    ('Metoprolol Succinate 50mg', 'BETA_BLOCKER'),
    ('Carvedilol 6.25mg', 'BETA_BLOCKER'),
    ('Carvedilol 12.5mg', 'BETA_BLOCKER'),
    ('Atenolol 50mg', 'BETA_BLOCKER'),
    ('Lisinopril 10mg', 'ACE_INHIBITOR'),
    ('Lisinopril 20mg', 'ACE_INHIBITOR'),
    ('Enalapril 5mg', 'ACE_INHIBITOR'),
    ('Ramipril 5mg', 'ACE_INHIBITOR'),
    ('Warfarin 5mg', 'ANTICOAGULANT'),
    ('Apixaban 5mg', 'ANTICOAGULANT'),
    ('Rivaroxaban 20mg', 'ANTICOAGULANT'),
    ('Heparin 5000u', 'ANTICOAGULANT'),
    ('Amiodarone 200mg', 'ANTIARRHYTHMIC'),
    ('Sotalol 80mg', 'ANTIARRHYTHMIC'),
    ('Atorvastatin 40mg', 'STATIN'),
    ('Atorvastatin 80mg', 'STATIN'),
    ('Rosuvastatin 20mg', 'STATIN'),
    ('Simvastatin 40mg', 'STATIN'),
    ('Aspirin 81mg', 'ANTIPLATELET'),
    ('Clopidogrel 75mg', 'ANTIPLATELET'),
    ('Ticagrelor 90mg', 'ANTIPLATELET'),
    ('Furosemide 40mg', 'DIURETIC'),
    ('Spironolactone 25mg', 'DIURETIC'),
    ('Amlodipine 5mg', 'CALCIUM_CHANNEL_BLOCKER'),
    ('Metformin 500mg', 'ANTIDIABETIC'),
    ('Nitroglycerin 0.4mg SL', 'NITRATE'),
    ('Isosorbide Mononitrate 30mg', 'NITRATE'),
    ('Sacubitril/Valsartan 49/51mg', 'ARNI'),
    ('Entresto 97/103mg', 'ARNI')
AS t(column1, column2);

CREATE OR REPLACE TEMPORARY TABLE TEMP_FIRST_NAMES AS
SELECT column1 AS first_name, column2 AS gender
FROM VALUES
    ('James','M'),('Robert','M'),('John','M'),('Michael','M'),('David','M'),
    ('William','M'),('Richard','M'),('Joseph','M'),('Thomas','M'),('Charles','M'),
    ('Christopher','M'),('Daniel','M'),('Matthew','M'),('Anthony','M'),('Mark','M'),
    ('Donald','M'),('Steven','M'),('Andrew','M'),('Paul','M'),('Joshua','M'),
    ('Mary','F'),('Patricia','F'),('Jennifer','F'),('Linda','F'),('Barbara','F'),
    ('Elizabeth','F'),('Susan','F'),('Jessica','F'),('Sarah','F'),('Karen','F'),
    ('Lisa','F'),('Nancy','F'),('Betty','F'),('Margaret','F'),('Sandra','F'),
    ('Ashley','F'),('Dorothy','F'),('Kimberly','F'),('Emily','F'),('Donna','F')
AS t(column1, column2);

CREATE OR REPLACE TEMPORARY TABLE TEMP_LAST_NAMES AS
SELECT column1 AS last_name
FROM VALUES
    ('Smith'),('Johnson'),('Williams'),('Brown'),('Jones'),('Garcia'),('Miller'),
    ('Davis'),('Rodriguez'),('Martinez'),('Hernandez'),('Lopez'),('Gonzalez'),
    ('Wilson'),('Anderson'),('Thomas'),('Taylor'),('Moore'),('Jackson'),('Martin'),
    ('Lee'),('Perez'),('Thompson'),('White'),('Harris'),('Sanchez'),('Clark'),
    ('Ramirez'),('Lewis'),('Robinson'),('Walker'),('Young'),('Allen'),('King'),
    ('Wright'),('Scott'),('Torres'),('Nguyen'),('Hill'),('Flores')
AS t(column1);


-- Generate 500 Patients
TRUNCATE TABLE IF EXISTS HEALTH_TRANSFORM_DB.MASTER.DIM_PATIENT;

INSERT INTO HEALTH_TRANSFORM_DB.MASTER.DIM_PATIENT (
    patient_id, first_name, last_name, date_of_birth, age, gender, ethnicity,
    ssn, address, phone, email, insurance_id, primary_language, marital_status,
    is_active, effective_from, is_current
)
SELECT
    'PAT-' || LPAD(SEQ4(), 6, '0') AS patient_id,
    fn.first_name,
    ln.last_name,
    DATEADD(DAY, -UNIFORM(16000, 32000, RANDOM()), CURRENT_DATE()) AS date_of_birth,
    ROUND(UNIFORM(16000, 32000, RANDOM()) / 365.25) AS age,
    fn.gender,
    CASE MOD(SEQ4(), 7)
        WHEN 0 THEN 'WHITE'
        WHEN 1 THEN 'BLACK'
        WHEN 2 THEN 'HISPANIC'
        WHEN 3 THEN 'ASIAN'
        WHEN 4 THEN 'NATIVE_AMERICAN'
        WHEN 5 THEN 'PACIFIC_ISLANDER'
        ELSE 'OTHER'
    END AS ethnicity,
    LPAD(UNIFORM(100, 999, RANDOM()), 3, '0') || '-' || LPAD(UNIFORM(10, 99, RANDOM()), 2, '0') || '-' || LPAD(UNIFORM(1000, 9999, RANDOM()), 4, '0') AS ssn,
    UNIFORM(100, 9999, RANDOM()) || ' ' ||
    CASE MOD(SEQ4(), 8) WHEN 0 THEN 'Oak' WHEN 1 THEN 'Maple' WHEN 2 THEN 'Cedar' WHEN 3 THEN 'Pine'
        WHEN 4 THEN 'Elm' WHEN 5 THEN 'Main' WHEN 6 THEN 'Park' ELSE 'Broadway' END ||
    CASE MOD(SEQ4(), 4) WHEN 0 THEN ' St' WHEN 1 THEN ' Ave' WHEN 2 THEN ' Dr' ELSE ' Ln' END AS address,
    '(' || LPAD(UNIFORM(200, 999, RANDOM()), 3, '0') || ') ' ||
    LPAD(UNIFORM(200, 999, RANDOM()), 3, '0') || '-' || LPAD(UNIFORM(1000, 9999, RANDOM()), 4, '0') AS phone,
    LOWER(fn.first_name) || '.' || LOWER(ln.last_name) || UNIFORM(1, 99, RANDOM()) || '@email.com' AS email,
    'INS-' || LPAD(UNIFORM(10000, 99999, RANDOM()), 5, '0') AS insurance_id,
    CASE MOD(SEQ4(), 5) WHEN 0 THEN 'ENGLISH' WHEN 1 THEN 'SPANISH' WHEN 2 THEN 'CHINESE' WHEN 3 THEN 'VIETNAMESE' ELSE 'ENGLISH' END,
    CASE MOD(SEQ4(), 4) WHEN 0 THEN 'MARRIED' WHEN 1 THEN 'SINGLE' WHEN 2 THEN 'DIVORCED' ELSE 'WIDOWED' END,
    TRUE,
    CURRENT_TIMESTAMP(),
    TRUE
FROM TABLE(GENERATOR(ROWCOUNT => 500)) g,
     (SELECT first_name, gender, ROW_NUMBER() OVER (ORDER BY RANDOM()) AS rn FROM TEMP_FIRST_NAMES) fn,
     (SELECT last_name, ROW_NUMBER() OVER (ORDER BY RANDOM()) AS rn FROM TEMP_LAST_NAMES) ln
WHERE fn.rn = MOD(SEQ4(), 40) + 1
  AND ln.rn = MOD(FLOOR(SEQ4() / 40), 40) + 1
LIMIT 500;


-- Generate 2000 Encounters
TRUNCATE TABLE IF EXISTS HEALTH_TRANSFORM_DB.CLEANSED.FACT_ENCOUNTER;

INSERT INTO HEALTH_TRANSFORM_DB.CLEANSED.FACT_ENCOUNTER (
    encounter_id, patient_id, encounter_type, admit_date, discharge_date,
    length_of_stay_days, department, attending_provider, facility_code,
    admit_diagnosis_code, discharge_status
)
WITH patients AS (
    SELECT patient_id FROM HEALTH_TRANSFORM_DB.MASTER.DIM_PATIENT ORDER BY RANDOM() LIMIT 400
)
SELECT
    'ENC-' || LPAD(SEQ4(), 8, '0') AS encounter_id,
    p.patient_id,
    CASE MOD(SEQ4(), 5)
        WHEN 0 THEN 'INPATIENT'
        WHEN 1 THEN 'OUTPATIENT'
        WHEN 2 THEN 'EMERGENCY'
        WHEN 3 THEN 'OBSERVATION'
        ELSE 'INPATIENT'
    END AS encounter_type,
    DATEADD(DAY, -UNIFORM(1, 730, RANDOM()), CURRENT_TIMESTAMP()) AS admit_date,
    DATEADD(DAY, -UNIFORM(1, 730, RANDOM()) + UNIFORM(1, 14, RANDOM()), CURRENT_TIMESTAMP()) AS discharge_date,
    UNIFORM(1, 14, RANDOM()) AS length_of_stay_days,
    CASE MOD(SEQ4(), 6)
        WHEN 0 THEN 'CARDIOLOGY'
        WHEN 1 THEN 'CARDIAC_SURGERY'
        WHEN 2 THEN 'CARDIAC_REHAB'
        WHEN 3 THEN 'ICU'
        WHEN 4 THEN 'INTERNAL_MEDICINE'
        ELSE 'EMERGENCY'
    END AS department,
    CASE MOD(SEQ4(), 8)
        WHEN 0 THEN 'Dr. Patel' WHEN 1 THEN 'Dr. Chen' WHEN 2 THEN 'Dr. Williams'
        WHEN 3 THEN 'Dr. Kim' WHEN 4 THEN 'Dr. Rodriguez' WHEN 5 THEN 'Dr. Johnson'
        WHEN 6 THEN 'Dr. Lee' ELSE 'Dr. Brown'
    END AS attending_provider,
    CASE MOD(SEQ4(), 3) WHEN 0 THEN 'FAC-001' WHEN 1 THEN 'FAC-002' ELSE 'FAC-003' END,
    dx.dx_code,
    CASE MOD(SEQ4(), 20) WHEN 0 THEN 'EXPIRED' ELSE 'DISCHARGED_HOME' END
FROM patients p,
     TABLE(GENERATOR(ROWCOUNT => 5)) g,
     (SELECT dx_code, ROW_NUMBER() OVER (ORDER BY RANDOM()) AS rn FROM TEMP_CARDIAC_DIAGNOSES) dx
WHERE dx.rn = MOD(SEQ4(), 30) + 1
LIMIT 2000;


-- Generate 3000 Diagnoses
TRUNCATE TABLE IF EXISTS HEALTH_TRANSFORM_DB.CLEANSED.FACT_DIAGNOSIS;

INSERT INTO HEALTH_TRANSFORM_DB.CLEANSED.FACT_DIAGNOSIS (
    diagnosis_id, encounter_id, patient_id, icd_code, icd_version, description,
    diagnosis_type, diagnosis_date, cardiac_category
)
WITH encounters AS (
    SELECT encounter_id, patient_id, admit_date FROM HEALTH_TRANSFORM_DB.CLEANSED.FACT_ENCOUNTER
)
SELECT
    'DX-' || LPAD(SEQ4(), 8, '0') AS diagnosis_id,
    e.encounter_id,
    e.patient_id,
    dx.dx_code,
    '10' AS icd_version,
    dx.dx_name,
    CASE MOD(SEQ4(), 3) WHEN 0 THEN 'PRIMARY' WHEN 1 THEN 'SECONDARY' ELSE 'ADMITTING' END,
    e.admit_date::DATE,
    dx.cardiac_category
FROM encounters e,
     (SELECT dx_code, dx_name, cardiac_category, ROW_NUMBER() OVER (ORDER BY RANDOM()) AS rn FROM TEMP_CARDIAC_DIAGNOSES) dx
WHERE dx.rn = MOD(HASH(e.encounter_id || SEQ4()), 30) + 1
  AND UNIFORM(0, 1, RANDOM()) < 0.5
LIMIT 3000;


-- Generate 2500 Medications
TRUNCATE TABLE IF EXISTS HEALTH_TRANSFORM_DB.CLEANSED.FACT_MEDICATION;

INSERT INTO HEALTH_TRANSFORM_DB.CLEANSED.FACT_MEDICATION (
    medication_id, encounter_id, patient_id, ndc_code, medication_name, dosage,
    route, frequency, prescriber, start_date, end_date, drug_class
)
WITH encounters AS (
    SELECT encounter_id, patient_id, admit_date FROM HEALTH_TRANSFORM_DB.CLEANSED.FACT_ENCOUNTER
)
SELECT
    'MED-' || LPAD(SEQ4(), 8, '0') AS medication_id,
    e.encounter_id,
    e.patient_id,
    LPAD(UNIFORM(10000, 99999, RANDOM()), 11, '0') AS ndc_code,
    m.med_name,
    REGEXP_SUBSTR(m.med_name, '[0-9]+[a-zA-Z]+') AS dosage,
    CASE MOD(SEQ4(), 4) WHEN 0 THEN 'PO' WHEN 1 THEN 'IV' WHEN 2 THEN 'SL' ELSE 'PO' END,
    CASE MOD(SEQ4(), 4) WHEN 0 THEN 'BID' WHEN 1 THEN 'DAILY' WHEN 2 THEN 'TID' ELSE 'PRN' END,
    CASE MOD(SEQ4(), 6) WHEN 0 THEN 'Dr. Patel' WHEN 1 THEN 'Dr. Chen' WHEN 2 THEN 'Dr. Williams'
        WHEN 3 THEN 'Dr. Kim' WHEN 4 THEN 'Dr. Rodriguez' ELSE 'Dr. Johnson' END,
    e.admit_date::DATE,
    DATEADD(DAY, UNIFORM(30, 365, RANDOM()), e.admit_date)::DATE,
    m.drug_class
FROM encounters e,
     (SELECT med_name, drug_class, ROW_NUMBER() OVER (ORDER BY RANDOM()) AS rn FROM TEMP_MEDICATIONS) m
WHERE m.rn = MOD(HASH(e.encounter_id || SEQ4()), 30) + 1
  AND UNIFORM(0, 1, RANDOM()) < 0.4
LIMIT 2500;


-- Generate 200 Rehab Referrals
TRUNCATE TABLE IF EXISTS HEALTH_TRANSFORM_DB.CLEANSED.FACT_REHAB_REFERRAL;

INSERT INTO HEALTH_TRANSFORM_DB.CLEANSED.FACT_REHAB_REFERRAL (
    referral_id, patient_id, referring_physician, qualifying_diagnosis,
    cardiac_event_date, lvef_percent, gxt_peak_hr, gxt_peak_mets,
    ischemic_threshold, aacvpr_risk_category, computed_risk, referral_date,
    days_event_to_referral
)
WITH cardiac_patients AS (
    SELECT DISTINCT patient_id
    FROM HEALTH_TRANSFORM_DB.CLEANSED.FACT_DIAGNOSIS
    WHERE cardiac_category IN ('ACUTE_MI','HEART_FAILURE','CHRONIC_IHD','ANGINA','CARDIAC_DEVICE','VALVULAR')
    LIMIT 200
)
SELECT
    'REF-' || LPAD(SEQ4(), 6, '0') AS referral_id,
    cp.patient_id,
    CASE MOD(SEQ4(), 6) WHEN 0 THEN 'Dr. Patel' WHEN 1 THEN 'Dr. Chen' WHEN 2 THEN 'Dr. Williams'
        WHEN 3 THEN 'Dr. Kim' WHEN 4 THEN 'Dr. Rodriguez' ELSE 'Dr. Johnson' END,
    CASE MOD(SEQ4(), 7)
        WHEN 0 THEN 'STEMI' WHEN 1 THEN 'NSTEMI' WHEN 2 THEN 'CABG'
        WHEN 3 THEN 'PCI' WHEN 4 THEN 'STABLE_ANGINA' WHEN 5 THEN 'HFrEF'
        ELSE 'VALVE_REPLACEMENT'
    END,
    DATEADD(DAY, -UNIFORM(30, 365, RANDOM()), CURRENT_DATE()),
    UNIFORM(20, 65, RANDOM()) AS lvef,
    UNIFORM(80, 170, RANDOM()) AS gxt_hr,
    ROUND(UNIFORM(3.0, 12.0, RANDOM()), 1) AS gxt_mets,
    CASE WHEN UNIFORM(0, 1, RANDOM()) < 0.3 THEN 'ST depression at ' || UNIFORM(4, 8, RANDOM()) || ' METs' ELSE NULL END,
    CASE
        WHEN UNIFORM(20, 65, RANDOM()) >= 50 AND UNIFORM(3.0, 12.0, RANDOM()) >= 7 THEN 'LOW'
        WHEN UNIFORM(20, 65, RANDOM()) BETWEEN 40 AND 49 THEN 'MODERATE'
        ELSE 'HIGH'
    END,
    CASE
        WHEN UNIFORM(20, 65, RANDOM()) >= 50 AND UNIFORM(3.0, 12.0, RANDOM()) >= 7 THEN 'LOW'
        WHEN UNIFORM(20, 65, RANDOM()) BETWEEN 40 AND 49 THEN 'MODERATE'
        ELSE 'HIGH'
    END,
    DATEADD(DAY, -UNIFORM(1, 30, RANDOM()), CURRENT_DATE()),
    UNIFORM(2, 30, RANDOM())
FROM cardiac_patients cp
LIMIT 200;


-- Generate 4000 Rehab Sessions (~20 per referral)
TRUNCATE TABLE IF EXISTS HEALTH_TRANSFORM_DB.CLEANSED.FACT_REHAB_SESSION;

INSERT INTO HEALTH_TRANSFORM_DB.CLEANSED.FACT_REHAB_SESSION (
    session_id, referral_id, patient_id, session_number, session_date, modality,
    duration_minutes, target_hr_low, target_hr_high, resting_hr, peak_hr, recovery_hr,
    resting_bp_systolic, resting_bp_diastolic, peak_bp_systolic, peak_bp_diastolic,
    post_bp_systolic, post_bp_diastolic, rpe_peak, spo2_min, ecg_rhythm,
    ecg_monitor_minutes, symptoms, adverse_events, exercise_terminated_early,
    termination_reason, therapist, achieved_hrr_percent, hr_recovery_delta, safety_flag
)
WITH referrals AS (
    SELECT referral_id, patient_id, referral_date FROM HEALTH_TRANSFORM_DB.CLEANSED.FACT_REHAB_REFERRAL
)
SELECT
    'SES-' || LPAD(SEQ4(), 8, '0') AS session_id,
    r.referral_id,
    r.patient_id,
    MOD(SEQ4(), 36) + 1 AS session_number,
    DATEADD(DAY, MOD(SEQ4(), 36) * 2 + UNIFORM(0, 2, RANDOM()), r.referral_date) AS session_date,
    CASE MOD(SEQ4(), 5) WHEN 0 THEN 'TREADMILL' WHEN 1 THEN 'CYCLE_ERGOMETER' WHEN 2 THEN 'RECUMBENT_STEPPER'
        WHEN 3 THEN 'ARM_ERGOMETER' ELSE 'NU_STEP' END,
    UNIFORM(20, 50, RANDOM()) AS duration_min,
    UNIFORM(90, 110, RANDOM()) AS target_low,
    UNIFORM(120, 145, RANDOM()) AS target_high,
    UNIFORM(60, 85, RANDOM()) AS resting,
    UNIFORM(95, 155, RANDOM()) AS peak,
    UNIFORM(70, 100, RANDOM()) AS recovery,
    UNIFORM(110, 140, RANDOM()), UNIFORM(65, 85, RANDOM()),
    UNIFORM(130, 180, RANDOM()), UNIFORM(70, 95, RANDOM()),
    UNIFORM(115, 145, RANDOM()), UNIFORM(65, 85, RANDOM()),
    UNIFORM(10, 16, RANDOM()) AS rpe,
    ROUND(UNIFORM(90.0, 100.0, RANDOM()), 1) AS spo2,
    CASE MOD(SEQ4(), 10) WHEN 0 THEN 'PVC_OCCASIONAL' WHEN 1 THEN 'PAC_RARE' ELSE 'NORMAL_SINUS' END,
    UNIFORM(15, 45, RANDOM()),
    CASE WHEN UNIFORM(0, 1, RANDOM()) < 0.05 THEN 'MILD_DYSPNEA' ELSE NULL END,
    CASE WHEN UNIFORM(0, 1, RANDOM()) < 0.02 THEN 'TRANSIENT_HYPOTENSION' ELSE NULL END,
    CASE WHEN UNIFORM(0, 1, RANDOM()) < 0.03 THEN TRUE ELSE FALSE END,
    CASE WHEN UNIFORM(0, 1, RANDOM()) < 0.03 THEN 'PATIENT_FATIGUE' ELSE NULL END,
    CASE MOD(SEQ4(), 5) WHEN 0 THEN 'Sarah PT' WHEN 1 THEN 'Mike PT' WHEN 2 THEN 'Lisa PT'
        WHEN 3 THEN 'James PT' ELSE 'Amy PT' END,
    ROUND(UNIFORM(40.0, 85.0, RANDOM()), 1),
    UNIFORM(10, 35, RANDOM()),
    CASE WHEN UNIFORM(0, 1, RANDOM()) < 0.04 THEN TRUE ELSE FALSE END
FROM referrals r,
     TABLE(GENERATOR(ROWCOUNT => 20)) g
LIMIT 4000;


-- Generate 400 Rehab Outcomes (baseline + discharge per referral)
TRUNCATE TABLE IF EXISTS HEALTH_TRANSFORM_DB.CLEANSED.FACT_REHAB_OUTCOME;

INSERT INTO HEALTH_TRANSFORM_DB.CLEANSED.FACT_REHAB_OUTCOME (
    outcome_id, referral_id, patient_id, measurement_type, measurement_point,
    measurement_date, six_min_walk_meters, peak_mets, dasi_score, phq9_score,
    weight_kg, bmi, waist_cm, hba1c, ldl, hdl, total_cholesterol, triglycerides,
    depression_severity
)
WITH referrals AS (
    SELECT referral_id, patient_id, referral_date FROM HEALTH_TRANSFORM_DB.CLEANSED.FACT_REHAB_REFERRAL
)
SELECT
    'OUT-B-' || LPAD(SEQ4(), 6, '0'),
    r.referral_id, r.patient_id, 'COMPREHENSIVE', 'BASELINE', r.referral_date,
    UNIFORM(200, 500, RANDOM()), ROUND(UNIFORM(3.0, 8.0, RANDOM()), 1),
    ROUND(UNIFORM(10.0, 45.0, RANDOM()), 1), UNIFORM(2, 22, RANDOM()),
    ROUND(UNIFORM(55.0, 130.0, RANDOM()), 1), ROUND(UNIFORM(20.0, 42.0, RANDOM()), 1),
    ROUND(UNIFORM(70.0, 130.0, RANDOM()), 1), ROUND(UNIFORM(5.2, 9.5, RANDOM()), 1),
    ROUND(UNIFORM(80.0, 190.0, RANDOM()), 0), ROUND(UNIFORM(30.0, 70.0, RANDOM()), 0),
    ROUND(UNIFORM(150.0, 280.0, RANDOM()), 0), ROUND(UNIFORM(80.0, 300.0, RANDOM()), 0),
    CASE WHEN UNIFORM(2, 22, RANDOM()) >= 20 THEN 'SEVERE'
         WHEN UNIFORM(2, 22, RANDOM()) >= 15 THEN 'MODERATELY_SEVERE'
         WHEN UNIFORM(2, 22, RANDOM()) >= 10 THEN 'MODERATE'
         WHEN UNIFORM(2, 22, RANDOM()) >= 5  THEN 'MILD'
         ELSE 'MINIMAL' END
FROM referrals r
UNION ALL
SELECT
    'OUT-D-' || LPAD(SEQ4(), 6, '0'),
    r.referral_id, r.patient_id, 'COMPREHENSIVE', 'DISCHARGE',
    DATEADD(DAY, UNIFORM(60, 100, RANDOM()), r.referral_date),
    UNIFORM(250, 600, RANDOM()), ROUND(UNIFORM(4.0, 10.0, RANDOM()), 1),
    ROUND(UNIFORM(15.0, 55.0, RANDOM()), 1), UNIFORM(1, 18, RANDOM()),
    ROUND(UNIFORM(52.0, 125.0, RANDOM()), 1), ROUND(UNIFORM(19.0, 40.0, RANDOM()), 1),
    ROUND(UNIFORM(68.0, 125.0, RANDOM()), 1), ROUND(UNIFORM(5.0, 8.5, RANDOM()), 1),
    ROUND(UNIFORM(60.0, 170.0, RANDOM()), 0), ROUND(UNIFORM(35.0, 75.0, RANDOM()), 0),
    ROUND(UNIFORM(140.0, 260.0, RANDOM()), 0), ROUND(UNIFORM(70.0, 250.0, RANDOM()), 0),
    CASE WHEN UNIFORM(1, 18, RANDOM()) >= 20 THEN 'SEVERE'
         WHEN UNIFORM(1, 18, RANDOM()) >= 15 THEN 'MODERATELY_SEVERE'
         WHEN UNIFORM(1, 18, RANDOM()) >= 10 THEN 'MODERATE'
         WHEN UNIFORM(1, 18, RANDOM()) >= 5  THEN 'MILD'
         ELSE 'MINIMAL' END
FROM referrals r;


-- Generate 1000 Claims
TRUNCATE TABLE IF EXISTS HEALTH_RAW_DB.REFERENCE_DATA.RAW_CLAIMS;

INSERT INTO HEALTH_RAW_DB.REFERENCE_DATA.RAW_CLAIMS (
    claim_id, patient_id, encounter_id, payer_id, payer_name, claim_type,
    service_date, cpt_code, drg_code, billed_amount, allowed_amount, paid_amount,
    patient_responsibility, claim_status, denial_reason, source_system
)
WITH encounters AS (
    SELECT encounter_id, patient_id, admit_date FROM HEALTH_TRANSFORM_DB.CLEANSED.FACT_ENCOUNTER ORDER BY RANDOM() LIMIT 800
)
SELECT
    'CLM-' || LPAD(SEQ4(), 8, '0'),
    e.patient_id, e.encounter_id,
    'PAY-' || LPAD(MOD(SEQ4(), 10), 3, '0'),
    CASE MOD(SEQ4(), 6) WHEN 0 THEN 'Medicare' WHEN 1 THEN 'Medicaid' WHEN 2 THEN 'Blue Cross'
        WHEN 3 THEN 'Aetna' WHEN 4 THEN 'UnitedHealth' ELSE 'Cigna' END,
    CASE MOD(SEQ4(), 3) WHEN 0 THEN 'PROFESSIONAL' WHEN 1 THEN 'INSTITUTIONAL' ELSE 'OUTPATIENT' END,
    e.admit_date::DATE,
    CASE MOD(SEQ4(), 8) WHEN 0 THEN '93798' WHEN 1 THEN '93015' WHEN 2 THEN '93000'
        WHEN 3 THEN '93306' WHEN 4 THEN '99213' WHEN 5 THEN '99214' WHEN 6 THEN '93797' ELSE '93010' END,
    CASE MOD(SEQ4(), 5) WHEN 0 THEN '291' WHEN 1 THEN '292' WHEN 2 THEN '280' WHEN 3 THEN '281' ELSE '293' END,
    ROUND(UNIFORM(150.0, 25000.0, RANDOM()), 2),
    ROUND(UNIFORM(100.0, 20000.0, RANDOM()), 2),
    ROUND(UNIFORM(80.0, 18000.0, RANDOM()), 2),
    ROUND(UNIFORM(0.0, 3000.0, RANDOM()), 2),
    CASE WHEN UNIFORM(0, 1, RANDOM()) < 0.12 THEN 'DENIED' ELSE 'PAID' END,
    CASE WHEN UNIFORM(0, 1, RANDOM()) < 0.12 THEN
        CASE MOD(SEQ4(), 4) WHEN 0 THEN 'MEDICAL_NECESSITY' WHEN 1 THEN 'PRIOR_AUTH_MISSING'
            WHEN 2 THEN 'CODING_ERROR' ELSE 'TIMELY_FILING' END
    ELSE NULL END,
    'CLAIMS_SYSTEM'
FROM encounters e,
     TABLE(GENERATOR(ROWCOUNT => 2)) g
LIMIT 1000;


-- Pre-register ML models
TRUNCATE TABLE IF EXISTS HEALTH_AI_READY_DB.MODELS.MODEL_CATALOG;

INSERT INTO HEALTH_AI_READY_DB.MODELS.MODEL_CATALOG
  (model_id, model_name, model_version, model_type, task, target_platform, training_dataset, description)
VALUES
  ('MDL-001', 'ICU_MORTALITY_RETAIN', 'v1.0', 'RETAIN', 'BINARY_CLASSIFICATION', 'WAREHOUSE',
   'HEALTH_AI_READY_DB.FEATURES.DS_MORTALITY_PREDICTION',
   'ICU mortality prediction using RETAIN (interpretable attention model) per PyHealth pipeline'),
  ('MDL-002', 'CARDIAC_ADVERSE_TRANSFORMER', 'v1.0', 'TRANSFORMER', 'BINARY_CLASSIFICATION', 'WAREHOUSE',
   'HEALTH_AI_READY_DB.FEATURES.DS_CARDIAC_ADVERSE_EVENT',
   'Cardiac rehab adverse event prediction using Transformer model'),
  ('MDL-003', 'DRUG_RECOMMENDATION_SAFEDRUG', 'v1.0', 'SAFEDRUG', 'MULTI_LABEL_CLASSIFICATION', 'SNOWPARK_CONTAINER_SERVICES',
   'HEALTH_TRANSFORM_DB.CLEANSED.FACT_MEDICATION',
   'Safe medication recommendation with DDI constraints per PyHealth SafeDrug'),
  ('MDL-004', 'READMISSION_30DAY_GNN', 'v1.0', 'GNN', 'BINARY_CLASSIFICATION', 'WAREHOUSE',
   'HEALTH_AI_READY_DB.FEATURES.FACT_PATIENT_CLINICAL_FEATURES',
   '30-day hospital readmission prediction using Graph Neural Network');


-- Create summary view
CREATE OR REPLACE VIEW HEALTH_ANALYTICS_DB.REPORTING.VW_CLINICAL_SUMMARY AS
SELECT
    e.encounter_id,
    e.patient_id,
    p.first_name || ' ' || p.last_name AS patient_name,
    p.age,
    p.gender,
    p.ethnicity,
    e.encounter_type,
    e.department,
    e.attending_provider,
    e.admit_date,
    e.discharge_date,
    e.length_of_stay_days,
    e.discharge_status,
    d.icd_code,
    d.description AS diagnosis_description,
    d.cardiac_category,
    m.medication_name,
    m.drug_class,
    r.qualifying_diagnosis AS rehab_qualifying_dx,
    r.computed_risk AS rehab_risk_category,
    r.lvef_percent,
    s.session_number AS latest_rehab_session,
    s.achieved_hrr_percent,
    s.safety_flag AS rehab_safety_flag
FROM HEALTH_TRANSFORM_DB.CLEANSED.FACT_ENCOUNTER e
JOIN HEALTH_TRANSFORM_DB.MASTER.DIM_PATIENT p
    ON e.patient_id = p.patient_id AND p.is_current = TRUE
LEFT JOIN HEALTH_TRANSFORM_DB.CLEANSED.FACT_DIAGNOSIS d
    ON e.encounter_id = d.encounter_id AND d.diagnosis_type = 'PRIMARY'
LEFT JOIN HEALTH_TRANSFORM_DB.CLEANSED.FACT_MEDICATION m
    ON e.encounter_id = m.encounter_id
LEFT JOIN HEALTH_TRANSFORM_DB.CLEANSED.FACT_REHAB_REFERRAL r
    ON e.patient_id = r.patient_id
LEFT JOIN HEALTH_TRANSFORM_DB.CLEANSED.FACT_REHAB_SESSION s
    ON r.referral_id = s.referral_id;


-- ============================================================
-- SECTION 13: DATA VERIFICATION
-- ============================================================

SELECT 'DIM_PATIENT' AS table_name, COUNT(*) AS record_count FROM HEALTH_TRANSFORM_DB.MASTER.DIM_PATIENT
UNION ALL
SELECT 'FACT_ENCOUNTER', COUNT(*) FROM HEALTH_TRANSFORM_DB.CLEANSED.FACT_ENCOUNTER
UNION ALL
SELECT 'FACT_DIAGNOSIS', COUNT(*) FROM HEALTH_TRANSFORM_DB.CLEANSED.FACT_DIAGNOSIS
UNION ALL
SELECT 'FACT_MEDICATION', COUNT(*) FROM HEALTH_TRANSFORM_DB.CLEANSED.FACT_MEDICATION
UNION ALL
SELECT 'FACT_REHAB_REFERRAL', COUNT(*) FROM HEALTH_TRANSFORM_DB.CLEANSED.FACT_REHAB_REFERRAL
UNION ALL
SELECT 'FACT_REHAB_SESSION', COUNT(*) FROM HEALTH_TRANSFORM_DB.CLEANSED.FACT_REHAB_SESSION
UNION ALL
SELECT 'FACT_REHAB_OUTCOME', COUNT(*) FROM HEALTH_TRANSFORM_DB.CLEANSED.FACT_REHAB_OUTCOME
UNION ALL
SELECT 'RAW_CLAIMS', COUNT(*) FROM HEALTH_RAW_DB.REFERENCE_DATA.RAW_CLAIMS;

SELECT
    patient_name,
    age,
    gender,
    encounter_type,
    department,
    diagnosis_description,
    cardiac_category,
    medication_name,
    drug_class,
    rehab_risk_category,
    lvef_percent
FROM HEALTH_ANALYTICS_DB.REPORTING.VW_CLINICAL_SUMMARY
LIMIT 20;

SELECT
    cardiac_category,
    COUNT(*) AS num_diagnoses,
    COUNT(DISTINCT patient_id) AS unique_patients
FROM HEALTH_TRANSFORM_DB.CLEANSED.FACT_DIAGNOSIS
WHERE cardiac_category IS NOT NULL
GROUP BY cardiac_category
ORDER BY num_diagnoses DESC;


-- ============================================================
-- SECTION 14: SUMMARY
-- ============================================================
/*
================================================================================
PHASE 04: DATABASE STRUCTURE - SUMMARY
================================================================================

DATABASES CREATED: 5
┌────────────────────────┬──────────────┬──────────────────────────────────────────┐
│ Database               │ Retention    │ Purpose                                  │
├────────────────────────┼──────────────┼──────────────────────────────────────────┤
│ HEALTH_GOVERNANCE_DB   │ 90 days      │ Security, monitoring, policies           │
│ HEALTH_RAW_DB          │ 90 days      │ Bronze: Raw EHR/claims/lab data          │
│ HEALTH_TRANSFORM_DB    │ 30 days      │ Silver: Cleansed, validated clinical data│
│ HEALTH_ANALYTICS_DB    │ 90 days      │ Gold: Business-ready clinical analytics  │
│ HEALTH_AI_READY_DB     │ 30 days      │ Platinum: ML features, models            │
└────────────────────────┴──────────────┴──────────────────────────────────────────┘

SCHEMAS CREATED: 10 Total (2 per database)
┌────────────────────────┬──────────────────────────────────────────────────────────┐
│ Database               │ Schemas                                                  │
├────────────────────────┼──────────────────────────────────────────────────────────┤
│ HEALTH_GOVERNANCE_DB   │ SECURITY, MONITORING (2)                                 │
│ HEALTH_RAW_DB          │ CLINICAL_DATA, REFERENCE_DATA (2)                        │
│ HEALTH_TRANSFORM_DB    │ CLEANSED, MASTER (2)                                     │
│ HEALTH_ANALYTICS_DB    │ CORE, REPORTING (2)                                      │
│ HEALTH_AI_READY_DB     │ FEATURES, MODELS (2)                                     │
└────────────────────────┴──────────────────────────────────────────────────────────┘

DATABASE OWNERSHIP:
┌────────────────────────┬──────────────────────────────────────────────────────────┐
│ Database               │ Owner Role                                               │
├────────────────────────┼──────────────────────────────────────────────────────────┤
│ HEALTH_GOVERNANCE_DB   │ ACCOUNTADMIN                                             │
│ HEALTH_RAW_DB          │ HEALTH_DATA_ADMIN                                        │
│ HEALTH_TRANSFORM_DB    │ HEALTH_DATA_ADMIN                                        │
│ HEALTH_ANALYTICS_DB    │ HEALTH_DATA_ADMIN                                        │
│ HEALTH_AI_READY_DB     │ HEALTH_ML_ADMIN                                          │
└────────────────────────┴──────────────────────────────────────────────────────────┘

SYNTHETIC DATA: ~13,000+ Records
┌──────────────────────────────┬──────────────────┐
│ Table                        │ Approx Records   │
├──────────────────────────────┼──────────────────┤
│ DIM_PATIENT                  │ 500              │
│ FACT_ENCOUNTER               │ 2,000            │
│ FACT_DIAGNOSIS               │ 3,000            │
│ FACT_MEDICATION              │ 2,500            │
│ FACT_REHAB_REFERRAL          │ 200              │
│ FACT_REHAB_SESSION           │ 4,000            │
│ FACT_REHAB_OUTCOME           │ 400              │
│ RAW_CLAIMS                   │ 1,000            │
│ MODEL_CATALOG                │ 4                │
└──────────────────────────────┴──────────────────┘

NO DEV/QA/PROD COMPLEXITY - Simple, clean structure!
================================================================================
*/

SELECT '============================================' AS separator
UNION ALL
SELECT '  PHASE 04: DATABASE STRUCTURE COMPLETE'
UNION ALL
SELECT '  5 Databases, 10 Schemas (2 each), ~13K Records'
UNION ALL
SELECT '  Health Domain - Healthcare Platform'
UNION ALL
SELECT '  Proceed to Phase 05: Resource Monitors'
UNION ALL
SELECT '============================================';

-- ============================================================
-- END OF PHASE 04: DATABASE STRUCTURE
-- ============================================================
