-- ============================================================
-- HEALTH_DOMAIN - SIMPLIFIED RBAC SETUP
-- ============================================================
-- Phase 02: RBAC Setup (Simplified)
-- Script: 02_rbac_setup.sql
-- Version: 1.0.0
--
-- Description:
--   Simplified RBAC for Healthcare & Life Sciences Platform.
--   Only 7 essential roles for EHR, Cardiac Rehab, Clinical Analytics.
--
-- Role Count: 7 (NOT 18)
-- ============================================================

USE ROLE ACCOUNTADMIN;

-- ============================================================
-- SECTION 1: CREATE ONLY 7 ESSENTIAL ROLES
-- ============================================================
/*
ROLE HIERARCHY:

                    SYSADMIN
         ┌────────────┼────────────┐
   HEALTH_DATA_ADMIN HEALTH_ML_ADMIN HEALTH_APP_ADMIN
         │              │              │
  HEALTH_DATA_ENGINEER HEALTH_ML_ENGINEER HEALTH_ANALYST
         └──────────────┼──────────────┘
                  HEALTH_READONLY

WHY THESE 7 ROLES?
1. HEALTH_READONLY      - View clinical reports (auditors, stakeholders, compliance)
2. HEALTH_ANALYST       - Create reports, analyze outcomes, population health
3. HEALTH_DATA_ENGINEER - Build ETL pipelines, manage EHR/claims data
4. HEALTH_ML_ENGINEER   - Build ML models for mortality, readmission, drug rec
5. HEALTH_DATA_ADMIN    - Admin for RAW/TRANSFORM/ANALYTICS databases
6. HEALTH_ML_ADMIN      - Admin for AI_READY database
7. HEALTH_APP_ADMIN     - Manage Streamlit clinical dashboards
*/

-- ------------------------------------------------------------
-- ROLE 1: HEALTH_READONLY (Base Read-Only Access)
-- ------------------------------------------------------------
CREATE ROLE IF NOT EXISTS HEALTH_READONLY
    COMMENT = 'Read-only access to health analytics. For viewing clinical dashboards, quality measures, KPIs. Persona: Stakeholders, auditors, compliance officers, hospital admin.';

-- ------------------------------------------------------------
-- ROLE 2: HEALTH_ANALYST (Clinical/Business Analyst)
-- ------------------------------------------------------------
CREATE ROLE IF NOT EXISTS HEALTH_ANALYST
    COMMENT = 'Health analysts - analyze cardiac rehab outcomes, population health, quality measures. Can read all data, create views in reporting schema. Persona: Clinical analysts, quality improvement, case managers.';

-- ------------------------------------------------------------
-- ROLE 3: HEALTH_DATA_ENGINEER (Data Pipeline Developer)
-- ------------------------------------------------------------
CREATE ROLE IF NOT EXISTS HEALTH_DATA_ENGINEER
    COMMENT = 'Data engineers - build ETL pipelines, manage EHR/claims data transformations. Full access to RAW and TRANSFORM databases. Persona: Data engineers, health IT, ETL developers.';

-- ------------------------------------------------------------
-- ROLE 4: HEALTH_ML_ENGINEER (Machine Learning Engineer)
-- ------------------------------------------------------------
CREATE ROLE IF NOT EXISTS HEALTH_ML_ENGINEER
    COMMENT = 'ML engineers - build predictive models (mortality, readmission, drug recommendation), feature engineering. Full access to AI_READY database. Persona: Data scientists, clinical informaticists, bioinformatics.';

-- ------------------------------------------------------------
-- ROLE 5: HEALTH_DATA_ADMIN (Data Platform Admin)
-- ------------------------------------------------------------
CREATE ROLE IF NOT EXISTS HEALTH_DATA_ADMIN
    COMMENT = 'Data administrator - manage RAW, TRANSFORM, ANALYTICS databases. Senior data engineers, health data platform team.';

-- ------------------------------------------------------------
-- ROLE 6: HEALTH_ML_ADMIN (ML Platform Admin)
-- ------------------------------------------------------------
CREATE ROLE IF NOT EXISTS HEALTH_ML_ADMIN
    COMMENT = 'ML administrator - manage AI_READY database, model registry, feature store. Senior data scientists, ML platform team.';

-- ------------------------------------------------------------
-- ROLE 7: HEALTH_APP_ADMIN (Application Admin)
-- ------------------------------------------------------------
CREATE ROLE IF NOT EXISTS HEALTH_APP_ADMIN
    COMMENT = 'Application administrator - manage Streamlit clinical dashboards, patient-facing APIs. Application developers, health IT DevOps.';

-- VERIFICATION: 7 roles created
SHOW ROLES LIKE 'HEALTH_%';


-- ============================================================
-- SECTION 2: ROLE HIERARCHY
-- ============================================================
-- Child roles granted TO parent roles (inheritance flows UP)

USE ROLE SECURITYADMIN;

-- Base layer: HEALTH_READONLY is foundation
-- Layer 2: Functional roles inherit from READONLY
GRANT ROLE HEALTH_READONLY TO ROLE HEALTH_ANALYST;
GRANT ROLE HEALTH_READONLY TO ROLE HEALTH_DATA_ENGINEER;
GRANT ROLE HEALTH_READONLY TO ROLE HEALTH_ML_ENGINEER;

-- Layer 3: Admin roles inherit from functional roles
GRANT ROLE HEALTH_ANALYST TO ROLE HEALTH_APP_ADMIN;
GRANT ROLE HEALTH_DATA_ENGINEER TO ROLE HEALTH_DATA_ADMIN;
GRANT ROLE HEALTH_ML_ENGINEER TO ROLE HEALTH_ML_ADMIN;

-- Layer 4: Admin roles to SYSADMIN
GRANT ROLE HEALTH_DATA_ADMIN TO ROLE SYSADMIN;
GRANT ROLE HEALTH_ML_ADMIN TO ROLE SYSADMIN;
GRANT ROLE HEALTH_APP_ADMIN TO ROLE SYSADMIN;

-- Grant admin to current user
GRANT ROLE HEALTH_DATA_ADMIN TO USER VARUN2287;

-- VERIFICATION
SHOW GRANTS OF ROLE HEALTH_READONLY;
SHOW GRANTS TO ROLE HEALTH_DATA_ADMIN;
SHOW GRANTS TO ROLE SYSADMIN;


-- ============================================================
-- SECTION 3: WAREHOUSE GRANTS
-- ============================================================

USE ROLE ACCOUNTADMIN;

-- HEALTH_INGEST_WH: Data loading (EHR feeds, claims, labs)
GRANT USAGE, OPERATE ON WAREHOUSE HEALTH_INGEST_WH TO ROLE HEALTH_DATA_ENGINEER;
GRANT USAGE, OPERATE ON WAREHOUSE HEALTH_INGEST_WH TO ROLE HEALTH_DATA_ADMIN;

-- HEALTH_TRANSFORM_WH: ETL processing (dbt, data conformation)
GRANT USAGE, OPERATE ON WAREHOUSE HEALTH_TRANSFORM_WH TO ROLE HEALTH_DATA_ENGINEER;
GRANT USAGE, OPERATE ON WAREHOUSE HEALTH_TRANSFORM_WH TO ROLE HEALTH_DATA_ADMIN;

-- HEALTH_ANALYTICS_WH: BI and clinical reporting
GRANT USAGE ON WAREHOUSE HEALTH_ANALYTICS_WH TO ROLE HEALTH_READONLY;
GRANT OPERATE ON WAREHOUSE HEALTH_ANALYTICS_WH TO ROLE HEALTH_ANALYST;
GRANT ALL PRIVILEGES ON WAREHOUSE HEALTH_ANALYTICS_WH TO ROLE HEALTH_DATA_ADMIN;
GRANT USAGE, OPERATE ON WAREHOUSE HEALTH_ANALYTICS_WH TO ROLE HEALTH_APP_ADMIN;

-- HEALTH_AI_WH: Machine learning (mortality, readmission, Cortex AI)
GRANT USAGE, OPERATE ON WAREHOUSE HEALTH_AI_WH TO ROLE HEALTH_ML_ENGINEER;
GRANT ALL PRIVILEGES ON WAREHOUSE HEALTH_AI_WH TO ROLE HEALTH_ML_ADMIN;


-- ============================================================
-- SECTION 4: DATABASE GRANTS - HEALTH_RAW_DB
-- ============================================================
-- Schemas: EHR_INGEST, CARDIAC_REHAB_INGEST, CLAIMS_INGEST,
--          LAB_INGEST, STAGING
-- (Databases & schemas already created in Phase 04;
--  this section grants privileges only)

USE ROLE ACCOUNTADMIN;

GRANT USAGE ON DATABASE HEALTH_RAW_DB TO ROLE HEALTH_DATA_ENGINEER;
GRANT USAGE ON DATABASE HEALTH_RAW_DB TO ROLE HEALTH_DATA_ADMIN;

GRANT USAGE ON ALL SCHEMAS IN DATABASE HEALTH_RAW_DB TO ROLE HEALTH_DATA_ENGINEER;

GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA HEALTH_RAW_DB.EHR_INGEST TO ROLE HEALTH_DATA_ENGINEER;
GRANT ALL PRIVILEGES ON FUTURE TABLES IN SCHEMA HEALTH_RAW_DB.EHR_INGEST TO ROLE HEALTH_DATA_ENGINEER;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA HEALTH_RAW_DB.CARDIAC_REHAB_INGEST TO ROLE HEALTH_DATA_ENGINEER;
GRANT ALL PRIVILEGES ON FUTURE TABLES IN SCHEMA HEALTH_RAW_DB.CARDIAC_REHAB_INGEST TO ROLE HEALTH_DATA_ENGINEER;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA HEALTH_RAW_DB.CLAIMS_INGEST TO ROLE HEALTH_DATA_ENGINEER;
GRANT ALL PRIVILEGES ON FUTURE TABLES IN SCHEMA HEALTH_RAW_DB.CLAIMS_INGEST TO ROLE HEALTH_DATA_ENGINEER;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA HEALTH_RAW_DB.LAB_INGEST TO ROLE HEALTH_DATA_ENGINEER;
GRANT ALL PRIVILEGES ON FUTURE TABLES IN SCHEMA HEALTH_RAW_DB.LAB_INGEST TO ROLE HEALTH_DATA_ENGINEER;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA HEALTH_RAW_DB.STAGING TO ROLE HEALTH_DATA_ENGINEER;
GRANT ALL PRIVILEGES ON FUTURE TABLES IN SCHEMA HEALTH_RAW_DB.STAGING TO ROLE HEALTH_DATA_ENGINEER;

GRANT CREATE TABLE ON ALL SCHEMAS IN DATABASE HEALTH_RAW_DB TO ROLE HEALTH_DATA_ENGINEER;

GRANT OWNERSHIP ON DATABASE HEALTH_RAW_DB TO ROLE HEALTH_DATA_ADMIN COPY CURRENT GRANTS;


-- ============================================================
-- SECTION 5: DATABASE GRANTS - HEALTH_TRANSFORM_DB
-- ============================================================
-- Schemas: PATIENTS, ENCOUNTERS, DIAGNOSES, MEDICATIONS,
--          PROCEDURES, CARDIAC_REHAB, LAB_VITALS

GRANT USAGE ON DATABASE HEALTH_TRANSFORM_DB TO ROLE HEALTH_DATA_ENGINEER;
GRANT USAGE ON DATABASE HEALTH_TRANSFORM_DB TO ROLE HEALTH_ML_ENGINEER;
GRANT USAGE ON DATABASE HEALTH_TRANSFORM_DB TO ROLE HEALTH_ANALYST;
GRANT USAGE ON DATABASE HEALTH_TRANSFORM_DB TO ROLE HEALTH_DATA_ADMIN;

GRANT USAGE ON ALL SCHEMAS IN DATABASE HEALTH_TRANSFORM_DB TO ROLE HEALTH_DATA_ENGINEER;
GRANT USAGE ON ALL SCHEMAS IN DATABASE HEALTH_TRANSFORM_DB TO ROLE HEALTH_ML_ENGINEER;
GRANT USAGE ON ALL SCHEMAS IN DATABASE HEALTH_TRANSFORM_DB TO ROLE HEALTH_ANALYST;

GRANT ALL PRIVILEGES ON ALL TABLES IN DATABASE HEALTH_TRANSFORM_DB TO ROLE HEALTH_DATA_ENGINEER;
GRANT ALL PRIVILEGES ON FUTURE TABLES IN DATABASE HEALTH_TRANSFORM_DB TO ROLE HEALTH_DATA_ENGINEER;
GRANT CREATE TABLE ON ALL SCHEMAS IN DATABASE HEALTH_TRANSFORM_DB TO ROLE HEALTH_DATA_ENGINEER;
GRANT CREATE VIEW ON ALL SCHEMAS IN DATABASE HEALTH_TRANSFORM_DB TO ROLE HEALTH_DATA_ENGINEER;

GRANT SELECT ON ALL TABLES IN DATABASE HEALTH_TRANSFORM_DB TO ROLE HEALTH_ML_ENGINEER;
GRANT SELECT ON FUTURE TABLES IN DATABASE HEALTH_TRANSFORM_DB TO ROLE HEALTH_ML_ENGINEER;

GRANT SELECT ON ALL TABLES IN DATABASE HEALTH_TRANSFORM_DB TO ROLE HEALTH_ANALYST;
GRANT SELECT ON ALL VIEWS IN DATABASE HEALTH_TRANSFORM_DB TO ROLE HEALTH_ANALYST;
GRANT SELECT ON FUTURE TABLES IN DATABASE HEALTH_TRANSFORM_DB TO ROLE HEALTH_ANALYST;
GRANT SELECT ON FUTURE VIEWS IN DATABASE HEALTH_TRANSFORM_DB TO ROLE HEALTH_ANALYST;

GRANT OWNERSHIP ON DATABASE HEALTH_TRANSFORM_DB TO ROLE HEALTH_DATA_ADMIN COPY CURRENT GRANTS;


-- ============================================================
-- SECTION 6: DATABASE GRANTS - HEALTH_ANALYTICS_DB
-- ============================================================
-- Schemas: CLINICAL_DASHBOARDS, POPULATION_HEALTH,
--          CARDIAC_OUTCOMES, QUALITY_MEASURES, FINANCIAL

GRANT USAGE ON DATABASE HEALTH_ANALYTICS_DB TO ROLE HEALTH_READONLY;
GRANT USAGE ON DATABASE HEALTH_ANALYTICS_DB TO ROLE HEALTH_ANALYST;
GRANT USAGE ON DATABASE HEALTH_ANALYTICS_DB TO ROLE HEALTH_DATA_ENGINEER;
GRANT USAGE ON DATABASE HEALTH_ANALYTICS_DB TO ROLE HEALTH_ML_ENGINEER;
GRANT USAGE ON DATABASE HEALTH_ANALYTICS_DB TO ROLE HEALTH_APP_ADMIN;
GRANT USAGE ON DATABASE HEALTH_ANALYTICS_DB TO ROLE HEALTH_DATA_ADMIN;

GRANT USAGE ON ALL SCHEMAS IN DATABASE HEALTH_ANALYTICS_DB TO ROLE HEALTH_READONLY;
GRANT USAGE ON ALL SCHEMAS IN DATABASE HEALTH_ANALYTICS_DB TO ROLE HEALTH_ANALYST;
GRANT USAGE ON ALL SCHEMAS IN DATABASE HEALTH_ANALYTICS_DB TO ROLE HEALTH_DATA_ENGINEER;
GRANT USAGE ON ALL SCHEMAS IN DATABASE HEALTH_ANALYTICS_DB TO ROLE HEALTH_ML_ENGINEER;
GRANT USAGE ON ALL SCHEMAS IN DATABASE HEALTH_ANALYTICS_DB TO ROLE HEALTH_APP_ADMIN;

GRANT SELECT ON ALL TABLES IN DATABASE HEALTH_ANALYTICS_DB TO ROLE HEALTH_READONLY;
GRANT SELECT ON ALL VIEWS IN DATABASE HEALTH_ANALYTICS_DB TO ROLE HEALTH_READONLY;
GRANT SELECT ON FUTURE TABLES IN DATABASE HEALTH_ANALYTICS_DB TO ROLE HEALTH_READONLY;
GRANT SELECT ON FUTURE VIEWS IN DATABASE HEALTH_ANALYTICS_DB TO ROLE HEALTH_READONLY;

GRANT CREATE TABLE ON SCHEMA HEALTH_ANALYTICS_DB.CLINICAL_DASHBOARDS TO ROLE HEALTH_ANALYST;
GRANT CREATE VIEW ON SCHEMA HEALTH_ANALYTICS_DB.CLINICAL_DASHBOARDS TO ROLE HEALTH_ANALYST;
GRANT CREATE TABLE ON SCHEMA HEALTH_ANALYTICS_DB.CARDIAC_OUTCOMES TO ROLE HEALTH_ANALYST;
GRANT CREATE VIEW ON SCHEMA HEALTH_ANALYTICS_DB.CARDIAC_OUTCOMES TO ROLE HEALTH_ANALYST;

GRANT CREATE TABLE ON SCHEMA HEALTH_ANALYTICS_DB.CLINICAL_DASHBOARDS TO ROLE HEALTH_DATA_ENGINEER;
GRANT INSERT, UPDATE, DELETE ON ALL TABLES IN DATABASE HEALTH_ANALYTICS_DB TO ROLE HEALTH_DATA_ENGINEER;
GRANT INSERT, UPDATE, DELETE ON FUTURE TABLES IN DATABASE HEALTH_ANALYTICS_DB TO ROLE HEALTH_DATA_ENGINEER;

GRANT CREATE STREAMLIT ON SCHEMA HEALTH_ANALYTICS_DB.CLINICAL_DASHBOARDS TO ROLE HEALTH_APP_ADMIN;

GRANT OWNERSHIP ON DATABASE HEALTH_ANALYTICS_DB TO ROLE HEALTH_DATA_ADMIN COPY CURRENT GRANTS;


-- ============================================================
-- SECTION 7: DATABASE GRANTS - HEALTH_AI_READY_DB
-- ============================================================
-- Schemas: FEATURE_STORE, EMBEDDINGS, SEMANTIC_MODELS,
--          MODEL_REGISTRY, TRAINING_DATASETS

GRANT USAGE ON DATABASE HEALTH_AI_READY_DB TO ROLE HEALTH_ML_ENGINEER;
GRANT USAGE ON DATABASE HEALTH_AI_READY_DB TO ROLE HEALTH_DATA_ENGINEER;
GRANT USAGE ON DATABASE HEALTH_AI_READY_DB TO ROLE HEALTH_ML_ADMIN;

GRANT USAGE ON ALL SCHEMAS IN DATABASE HEALTH_AI_READY_DB TO ROLE HEALTH_ML_ENGINEER;
GRANT USAGE ON SCHEMA HEALTH_AI_READY_DB.FEATURE_STORE TO ROLE HEALTH_DATA_ENGINEER;

GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA HEALTH_AI_READY_DB.FEATURE_STORE TO ROLE HEALTH_ML_ENGINEER;
GRANT ALL PRIVILEGES ON FUTURE TABLES IN SCHEMA HEALTH_AI_READY_DB.FEATURE_STORE TO ROLE HEALTH_ML_ENGINEER;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA HEALTH_AI_READY_DB.TRAINING_DATASETS TO ROLE HEALTH_ML_ENGINEER;
GRANT ALL PRIVILEGES ON FUTURE TABLES IN SCHEMA HEALTH_AI_READY_DB.TRAINING_DATASETS TO ROLE HEALTH_ML_ENGINEER;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA HEALTH_AI_READY_DB.EMBEDDINGS TO ROLE HEALTH_ML_ENGINEER;
GRANT ALL PRIVILEGES ON FUTURE TABLES IN SCHEMA HEALTH_AI_READY_DB.EMBEDDINGS TO ROLE HEALTH_ML_ENGINEER;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA HEALTH_AI_READY_DB.MODEL_REGISTRY TO ROLE HEALTH_ML_ENGINEER;
GRANT ALL PRIVILEGES ON FUTURE TABLES IN SCHEMA HEALTH_AI_READY_DB.MODEL_REGISTRY TO ROLE HEALTH_ML_ENGINEER;
GRANT CREATE TABLE ON ALL SCHEMAS IN DATABASE HEALTH_AI_READY_DB TO ROLE HEALTH_ML_ENGINEER;

GRANT SELECT ON ALL TABLES IN SCHEMA HEALTH_AI_READY_DB.FEATURE_STORE TO ROLE HEALTH_DATA_ENGINEER;
GRANT SELECT ON FUTURE TABLES IN SCHEMA HEALTH_AI_READY_DB.FEATURE_STORE TO ROLE HEALTH_DATA_ENGINEER;

GRANT OWNERSHIP ON DATABASE HEALTH_AI_READY_DB TO ROLE HEALTH_ML_ADMIN COPY CURRENT GRANTS;


-- ============================================================
-- SECTION 8: DATABASE GRANTS - HEALTH_GOVERNANCE_DB
-- ============================================================
-- Schemas: SECURITY (Phase 01), MONITORS, TAGS, POLICIES, AUDIT

GRANT USAGE ON DATABASE HEALTH_GOVERNANCE_DB TO ROLE HEALTH_DATA_ADMIN;
GRANT USAGE ON DATABASE HEALTH_GOVERNANCE_DB TO ROLE HEALTH_READONLY;

GRANT USAGE ON SCHEMA HEALTH_GOVERNANCE_DB.SECURITY TO ROLE HEALTH_DATA_ADMIN;
GRANT USAGE ON SCHEMA HEALTH_GOVERNANCE_DB.MONITORS TO ROLE HEALTH_DATA_ADMIN;
GRANT USAGE ON SCHEMA HEALTH_GOVERNANCE_DB.MONITORS TO ROLE HEALTH_READONLY;
GRANT SELECT ON ALL VIEWS IN SCHEMA HEALTH_GOVERNANCE_DB.MONITORS TO ROLE HEALTH_DATA_ADMIN;
GRANT SELECT ON ALL VIEWS IN SCHEMA HEALTH_GOVERNANCE_DB.MONITORS TO ROLE HEALTH_READONLY;
GRANT SELECT ON FUTURE VIEWS IN SCHEMA HEALTH_GOVERNANCE_DB.MONITORS TO ROLE HEALTH_DATA_ADMIN;
GRANT SELECT ON FUTURE VIEWS IN SCHEMA HEALTH_GOVERNANCE_DB.MONITORS TO ROLE HEALTH_READONLY;


-- ============================================================
-- SECTION 9: VERIFICATION
-- ============================================================

USE ROLE ACCOUNTADMIN;

-- Verify 7 roles exist
SELECT
    'Role Count Check' AS test_name,
    COUNT(*) AS role_count,
    CASE WHEN COUNT(*) = 7 THEN 'PASS: 7 roles created'
         ELSE 'CHECK: Expected 7 roles' END AS status
FROM SNOWFLAKE.ACCOUNT_USAGE.ROLES
WHERE NAME LIKE 'HEALTH_%'
  AND DELETED_ON IS NULL;

-- List all roles
SHOW ROLES LIKE 'HEALTH_%';

-- Verify hierarchy
SHOW GRANTS OF ROLE HEALTH_READONLY;
SHOW GRANTS TO ROLE HEALTH_DATA_ADMIN;
SHOW GRANTS TO ROLE SYSADMIN;


-- ============================================================
-- SECTION 10: SUMMARY
-- ============================================================
/*
================================================================================
SIMPLIFIED RBAC - 7 ROLES ONLY
================================================================================

ROLES CREATED:
┌───────────────────────┬────────────────────────────────────────────────────────┐
│ Role                  │ Purpose                                                │
├───────────────────────┼────────────────────────────────────────────────────────┤
│ HEALTH_READONLY       │ View clinical reports, dashboards (auditors, admin)     │
│ HEALTH_ANALYST        │ Analyze outcomes, quality measures, population health   │
│ HEALTH_DATA_ENGINEER  │ Build ETL pipelines, manage EHR/claims data            │
│ HEALTH_ML_ENGINEER    │ Build ML models (mortality, readmission, drug rec)      │
│ HEALTH_DATA_ADMIN     │ Admin for RAW/TRANSFORM/ANALYTICS databases            │
│ HEALTH_ML_ADMIN       │ Admin for AI_READY database, model registry            │
│ HEALTH_APP_ADMIN      │ Manage Streamlit clinical dashboards                   │
└───────────────────────┴────────────────────────────────────────────────────────┘

ROLE HIERARCHY:
                         SYSADMIN
              ┌──────────────┼──────────────┐
        HEALTH_DATA_ADMIN HEALTH_ML_ADMIN HEALTH_APP_ADMIN
              │              │              │
       HEALTH_DATA_ENGINEER HEALTH_ML_ENGINEER HEALTH_ANALYST
              └──────────────┼──────────────┘
                       HEALTH_READONLY

WAREHOUSE ACCESS:
┌─────────────────────────┬──────────────────────────────────────────────────┐
│ Warehouse               │ Roles                                            │
├─────────────────────────┼──────────────────────────────────────────────────┤
│ HEALTH_INGEST_WH        │ DATA_ENGINEER, DATA_ADMIN                        │
│ HEALTH_TRANSFORM_WH     │ DATA_ENGINEER, DATA_ADMIN                        │
│ HEALTH_ANALYTICS_WH     │ READONLY, ANALYST, DATA_ADMIN, APP_ADMIN         │
│ HEALTH_AI_WH            │ ML_ENGINEER, ML_ADMIN                            │
└─────────────────────────┴──────────────────────────────────────────────────┘

DATABASE ACCESS:
┌─────────────────────────┬────────────────────────────┬─────────────────────────────┐
│ Database                │ Schemas                    │ Roles                       │
├─────────────────────────┼────────────────────────────┼─────────────────────────────┤
│ HEALTH_RAW_DB           │ EHR_INGEST                 │ DATA_ENGINEER (full)        │
│                         │ CARDIAC_REHAB_INGEST       │ DATA_ADMIN (owner)          │
│                         │ CLAIMS_INGEST              │                             │
│                         │ LAB_INGEST                 │                             │
│                         │ STAGING                    │                             │
├─────────────────────────┼────────────────────────────┼─────────────────────────────┤
│ HEALTH_TRANSFORM_DB     │ PATIENTS, ENCOUNTERS       │ DATA_ENGINEER (full)        │
│                         │ DIAGNOSES, MEDICATIONS     │ ML_ENGINEER/ANALYST (read)  │
│                         │ PROCEDURES, CARDIAC_REHAB  │                             │
│                         │ LAB_VITALS                 │                             │
├─────────────────────────┼────────────────────────────┼─────────────────────────────┤
│ HEALTH_ANALYTICS_DB     │ CLINICAL_DASHBOARDS        │ DATA_ENGINEER (write)       │
│                         │ POPULATION_HEALTH          │ ANALYST (create), APP_ADMIN │
│                         │ CARDIAC_OUTCOMES           │ READONLY (select)           │
│                         │ QUALITY_MEASURES           │                             │
│                         │ FINANCIAL                  │                             │
├─────────────────────────┼────────────────────────────┼─────────────────────────────┤
│ HEALTH_AI_READY_DB      │ FEATURE_STORE              │ ML_ENGINEER (full)          │
│                         │ EMBEDDINGS                 │ DATA_ENGINEER (read FEAT.)  │
│                         │ SEMANTIC_MODELS            │                             │
│                         │ MODEL_REGISTRY             │                             │
│                         │ TRAINING_DATASETS          │                             │
├─────────────────────────┼────────────────────────────┼─────────────────────────────┤
│ HEALTH_GOVERNANCE_DB    │ SECURITY                   │ DATA_ADMIN                  │
│                         │ MONITORS                   │ READONLY (monitoring)       │
│                         │ TAGS, POLICIES, AUDIT      │                             │
└─────────────────────────┴────────────────────────────┴─────────────────────────────┘

NO COMPLIANCE_OFFICER - Not needed; DATA_ADMIN handles compliance visibility
NO CLINICIAN role    - PHI access controlled via masking policies (Phase 08)
================================================================================
*/

SELECT '============================================' AS separator
UNION ALL
SELECT '  PHASE 02: RBAC SETUP COMPLETE'
UNION ALL
SELECT '  7 Roles Created (Simplified)'
UNION ALL
SELECT '  Health Domain - Healthcare Platform'
UNION ALL
SELECT '  Proceed to Phase 03: Warehouse Management'
UNION ALL
SELECT '============================================';

-- ============================================================
-- END OF PHASE 02: SIMPLIFIED RBAC SETUP
-- ============================================================
