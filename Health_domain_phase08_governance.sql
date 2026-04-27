------------------------------------------------------------------------
-- HEALTH_DOMAIN — PHASE 8: DATA GOVERNANCE
-- Tags, 3 masking policies, row access policy
------------------------------------------------------------------------

USE ROLE ACCOUNTADMIN;

------------------------------------------------------------------------
-- 8A. TAG DEFINITIONS (HIPAA / HCLS classification)
------------------------------------------------------------------------
CREATE TAG IF NOT EXISTS HEALTH_GOVERNANCE_DB.TAGS.SENSITIVITY
  ALLOWED_VALUES 'PHI', 'PII', 'CONFIDENTIAL', 'INTERNAL', 'PUBLIC'
  COMMENT = 'Data sensitivity classification per HIPAA';

CREATE TAG IF NOT EXISTS HEALTH_GOVERNANCE_DB.TAGS.DATA_DOMAIN
  ALLOWED_VALUES 'PATIENT', 'CLINICAL', 'FINANCIAL', 'OPERATIONAL', 'RESEARCH'
  COMMENT = 'Business domain classification';

CREATE TAG IF NOT EXISTS HEALTH_GOVERNANCE_DB.TAGS.DATA_OWNER
  COMMENT = 'Owner team or individual';

CREATE TAG IF NOT EXISTS HEALTH_GOVERNANCE_DB.TAGS.RETENTION_DAYS
  COMMENT = 'Required retention period in days';

CREATE TAG IF NOT EXISTS HEALTH_GOVERNANCE_DB.TAGS.PII_TYPE
  ALLOWED_VALUES 'SSN', 'MRN', 'DOB', 'NAME', 'ADDRESS', 'PHONE', 'EMAIL', 'NONE'
  COMMENT = 'Specific PII element type';

------------------------------------------------------------------------
-- 8B. MASKING POLICY 1 – Full SSN masking (show last 4 to clinicians)
------------------------------------------------------------------------
CREATE OR REPLACE MASKING POLICY HEALTH_GOVERNANCE_DB.POLICIES.MASK_SSN
  AS (VAL STRING) RETURNS STRING ->
    CASE
      WHEN CURRENT_ROLE() IN ('HEALTH_ADMIN', 'ACCOUNTADMIN')
        THEN VAL
      WHEN CURRENT_ROLE() = 'HEALTH_CLINICIAN'
        THEN 'XXX-XX-' || RIGHT(VAL, 4)
      ELSE '***-**-****'
    END
  COMMENT = 'SSN masking – full for admin, last-4 for clinician, redacted for others';

------------------------------------------------------------------------
-- 8C. MASKING POLICY 2 – Date-of-birth masking (year only for analysts)
------------------------------------------------------------------------
CREATE OR REPLACE MASKING POLICY HEALTH_GOVERNANCE_DB.POLICIES.MASK_DOB
  AS (VAL DATE) RETURNS DATE ->
    CASE
      WHEN CURRENT_ROLE() IN ('HEALTH_ADMIN', 'ACCOUNTADMIN', 'HEALTH_CLINICIAN')
        THEN VAL
      WHEN CURRENT_ROLE() = 'HEALTH_ANALYST'
        THEN DATE_FROM_PARTS(YEAR(VAL), 1, 1)
      ELSE NULL
    END
  COMMENT = 'DOB masking – full for clinical, year-only for analysts, NULL for others';

------------------------------------------------------------------------
-- 8D. MASKING POLICY 3 – Patient name masking
------------------------------------------------------------------------
CREATE OR REPLACE MASKING POLICY HEALTH_GOVERNANCE_DB.POLICIES.MASK_PATIENT_NAME
  AS (VAL STRING) RETURNS STRING ->
    CASE
      WHEN CURRENT_ROLE() IN ('HEALTH_ADMIN', 'ACCOUNTADMIN', 'HEALTH_CLINICIAN')
        THEN VAL
      WHEN CURRENT_ROLE() = 'HEALTH_ANALYST'
        THEN LEFT(VAL, 1) || '****'
      ELSE '**REDACTED**'
    END
  COMMENT = 'Patient name masking – full for clinical roles, initial for analysts';

------------------------------------------------------------------------
-- 8E. ROW ACCESS POLICY – restrict patient data by care-team assignment
------------------------------------------------------------------------
CREATE OR REPLACE ROW ACCESS POLICY HEALTH_GOVERNANCE_DB.POLICIES.RAP_PATIENT_CARE_TEAM
  AS (CARE_TEAM_ID STRING) RETURNS BOOLEAN ->
    CURRENT_ROLE() IN ('HEALTH_ADMIN', 'ACCOUNTADMIN')
    OR CURRENT_ROLE() = 'HEALTH_CLINICIAN'
       AND EXISTS (
         SELECT 1
         FROM HEALTH_TRANSFORM_DB.PATIENTS.CARE_TEAM_ASSIGNMENTS
         WHERE CLINICIAN_USER = CURRENT_USER()
           AND CARE_TEAM_ID = CARE_TEAM_ID
       )
    OR CURRENT_ROLE() IN ('HEALTH_ANALYST', 'HEALTH_SCIENTIST')
  COMMENT = 'Row-level security – clinicians see only their care-team patients';

------------------------------------------------------------------------
-- 8F. APPLY tags to known sensitive columns (examples)
------------------------------------------------------------------------

GRANT APPLY TAG ON ACCOUNT TO ROLE HEALTH_GOVERNANCE;
GRANT APPLY MASKING POLICY ON ACCOUNT TO ROLE HEALTH_GOVERNANCE;
GRANT APPLY ROW ACCESS POLICY ON ACCOUNT TO ROLE HEALTH_GOVERNANCE;
