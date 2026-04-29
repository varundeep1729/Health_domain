-- ============================================================
-- HEALTH_DOMAIN - DATA GOVERNANCE
-- ============================================================
-- Phase 08: Data Governance
-- Script: 08_data_governance.sql
-- Version: 1.0.0
--
-- Description:
--   Data governance layer for Healthcare & Life Sciences Platform.
--   Implements tags, masking policies, and access controls
--   for HIPAA/HITECH compliance.
--
-- Regulatory Framework:
--   - HIPAA Privacy Rule: PHI protection
--   - HIPAA Security Rule: Technical safeguards
--   - HITECH Act: Breach notification, EHR security
--   - 42 CFR Part 2: Substance abuse records
--   - CMS Conditions of Participation
--
-- Components:
--   - Tags: 8 classification tags
--   - Masking Policies: 4 policies
--   - Row Access Policies: 2 policies
--
-- Dependencies:
--   - Phase 04: HEALTH_GOVERNANCE_DB exists
--   - Phase 02: 7 roles exist
-- ============================================================


-- ============================================================
-- DETAILED EXPLANATION: WHAT IS DATA GOVERNANCE?
-- ============================================================
/*
DATA GOVERNANCE is a framework of policies, processes, and standards
that ensures data is:
  1. ACCURATE    - Data represents reality correctly
  2. ACCESSIBLE  - Right people can access right data
  3. CONSISTENT  - Same data means same thing everywhere
  4. SECURE      - Protected from unauthorized access
  5. COMPLIANT   - Meets regulatory requirements

WHY DATA GOVERNANCE FOR HEALTHCARE PLATFORM?
─────────────────────────────────────────────
Healthcare is heavily regulated. We must:
  - Protect patient PHI (Protected Health Information)
  - Maintain audit trails for HIPAA compliance
  - Ensure data quality for accurate clinical decisions
  - Track data lineage for regulatory reporting

SNOWFLAKE GOVERNANCE OBJECTS:
────────────────────────────
┌─────────────────────┬────────────────────────────────────────────────────────┐
│ Object Type         │ Purpose                                                │
├─────────────────────┼────────────────────────────────────────────────────────┤
│ TAGS                │ Classify and label data (metadata)                     │
│ MASKING POLICIES    │ Hide/transform sensitive data based on role            │
│ ROW ACCESS POLICIES │ Filter rows based on user role/attributes              │
│ ACCESS HISTORY      │ Track who accessed what data (audit)                   │
└─────────────────────┴────────────────────────────────────────────────────────┘

REGULATORY COMPLIANCE CONTEXT:
──────────────────────────────
┌─────────────────────┬────────────────────────────────────────────────────────┐
│ Regulation          │ What It Requires                                       │
├─────────────────────┼────────────────────────────────────────────────────────┤
│ HIPAA Privacy Rule  │ Minimum necessary standard for PHI access              │
│ § 164.502(b)        │ - Only disclose minimum PHI needed                     │
│                     │ - Role-based access to patient data                    │
├─────────────────────┼────────────────────────────────────────────────────────┤
│ HIPAA Security Rule │ Technical safeguards for ePHI                          │
│ § 164.312           │ - Access controls (unique user ID, auto logoff)        │
│                     │ - Audit controls (record access to PHI)                │
│                     │ - Transmission security (encryption)                   │
├─────────────────────┼────────────────────────────────────────────────────────┤
│ HITECH Act          │ Breach notification requirements                       │
│                     │ - Notify patients within 60 days of breach             │
│                     │ - Notify HHS for breaches >500 individuals             │
├─────────────────────┼────────────────────────────────────────────────────────┤
│ 42 CFR Part 2       │ Substance abuse treatment records                      │
│                     │ - Stricter than HIPAA for SUD data                     │
│                     │ - Requires explicit patient consent                    │
├─────────────────────┼────────────────────────────────────────────────────────┤
│ CMS CoP             │ Conditions of Participation                            │
│                     │ - Medical records must be confidential                 │
│                     │ - Document retention requirements                      │
└─────────────────────┴────────────────────────────────────────────────────────┘
*/

USE ROLE ACCOUNTADMIN;
USE DATABASE HEALTH_GOVERNANCE_DB;
USE WAREHOUSE COMPUTE_WH;


-- ============================================================
-- SECTION 1: CREATE TAGS
-- ============================================================
/*
WHAT ARE TAGS?
──────────────
Tags are metadata labels that you attach to Snowflake objects
(databases, schemas, tables, columns) to classify them.

WHY USE TAGS?
─────────────
1. CLASSIFICATION: Identify PHI/PII data automatically
2. DISCOVERY: Find all patient columns across the platform
3. AUTOMATION: Drive masking policies based on tag values
4. COMPLIANCE: Document data for HIPAA auditors
5. LINEAGE: Track data origin and purpose

HIPAA 18 IDENTIFIERS (PHI):
────────────────────────────
HIPAA defines 18 types of Protected Health Information:
  1. Names                    10. Account numbers
  2. Geographic data          11. Certificate/license numbers
  3. Dates (DOB, admit, etc.) 12. Vehicle identifiers
  4. Phone numbers            13. Device identifiers
  5. Fax numbers              14. Web URLs
  6. Email addresses          15. IP addresses
  7. SSN                      16. Biometric identifiers
  8. Medical record numbers   17. Full-face photos
  9. Health plan beneficiary  18. Any other unique identifier
*/

USE SCHEMA HEALTH_GOVERNANCE_DB.SECURITY;

-- ------------------------------------------------------------
-- TAG 1: PHI_CLASSIFICATION
-- ------------------------------------------------------------
/*
PURPOSE: Classify Protected Health Information per HIPAA 18 identifiers

VALUES AND THEIR MEANING:
┌─────────────────────┬────────────────────────────────────────────────────────┐
│ Value               │ Examples & Treatment                                   │
├─────────────────────┼────────────────────────────────────────────────────────┤
│ DIRECT_PHI          │ Patient name, SSN, MRN, DOB, full address              │
│                     │ Treatment: Full masking for unauthorized roles         │
├─────────────────────┼────────────────────────────────────────────────────────┤
│ QUASI_PHI           │ ZIP code, age, gender, ethnicity                       │
│                     │ Treatment: Partial masking or generalisation           │
├─────────────────────┼────────────────────────────────────────────────────────┤
│ CLINICAL            │ Diagnoses, medications, lab results, vitals            │
│                     │ Treatment: Role-based access, no masking if authorised │
├─────────────────────┼────────────────────────────────────────────────────────┤
│ NON_PHI             │ Facility codes, procedure codes, timestamps            │
│                     │ Treatment: No masking required                         │
└─────────────────────┴────────────────────────────────────────────────────────┘
*/
CREATE OR REPLACE TAG PHI_CLASSIFICATION
    COMMENT = 'HIPAA PHI classification. Values: DIRECT_PHI (name, SSN, MRN, DOB), QUASI_PHI (ZIP, age), CLINICAL (diagnoses, meds), NON_PHI (no protection)';

-- ------------------------------------------------------------
-- TAG 2: DATA_SENSITIVITY
-- ------------------------------------------------------------
/*
PURPOSE: Overall sensitivity level for access control decisions

VALUES:
┌─────────────────────┬────────────────────────────────────────────────────────┐
│ Value               │ Description & Access Level                             │
├─────────────────────┼────────────────────────────────────────────────────────┤
│ HIGHLY_CONFIDENTIAL │ Patient PHI, SSN, psychiatric notes, SUD records      │
│                     │ Access: DATA_ADMIN, ANALYST only                       │
├─────────────────────┼────────────────────────────────────────────────────────┤
│ CONFIDENTIAL        │ Clinical data, lab results, cardiac rehab sessions     │
│                     │ Access: All functional roles                           │
├─────────────────────┼────────────────────────────────────────────────────────┤
│ INTERNAL            │ Aggregated metrics, quality measures, de-identified    │
│                     │ Access: All authenticated users                        │
├─────────────────────┼────────────────────────────────────────────────────────┤
│ PUBLIC              │ Facility info, published quality scores                │
│                     │ Access: Anyone (no restrictions)                       │
└─────────────────────┴────────────────────────────────────────────────────────┘
*/
CREATE OR REPLACE TAG DATA_SENSITIVITY
    COMMENT = 'Data sensitivity level. Values: HIGHLY_CONFIDENTIAL (PHI), CONFIDENTIAL (clinical), INTERNAL (aggregated), PUBLIC';

-- ------------------------------------------------------------
-- TAG 3: DATA_DOMAIN
-- ------------------------------------------------------------
/*
PURPOSE: Business domain classification for healthcare data

VALUES:
┌─────────────────────┬────────────────────────────────────────────────────────┐
│ Value               │ Description                                            │
├─────────────────────┼────────────────────────────────────────────────────────┤
│ PATIENT             │ Demographics, identifiers, insurance, care teams       │
│ CLINICAL            │ Encounters, diagnoses, procedures, medications         │
│ CARDIAC_REHAB       │ Referrals, sessions, hemodynamics, outcomes (AACVPR)   │
│ LAB_VITALS          │ Lab results, vital signs, physiological data           │
│ FINANCIAL           │ Claims, billing, reimbursement, denials                │
│ RESEARCH            │ De-identified data, ML features, training datasets     │
└─────────────────────┴────────────────────────────────────────────────────────┘
*/
CREATE OR REPLACE TAG DATA_DOMAIN
    COMMENT = 'Business domain. Values: PATIENT, CLINICAL, CARDIAC_REHAB, LAB_VITALS, FINANCIAL, RESEARCH';

-- ------------------------------------------------------------
-- TAG 4: MEDALLION_LAYER
-- ------------------------------------------------------------
/*
PURPOSE: Identify data position in the medallion architecture

┌─────────────┬─────────────┬─────────────┬──────────────────────┐
│   BRONZE    │   SILVER    │    GOLD     │      PLATINUM        │
│  (RAW_DB)   │(TRANSFORM_DB│(ANALYTICS_DB│   (AI_READY_DB)      │
├─────────────┼─────────────┼─────────────┼──────────────────────┤
│ Raw EHR     │ Cleansed    │ Clinical    │ ML-ready             │
│ feeds as-is │ ICD-mapped  │ dashboards  │ Feature store        │
│ from Epic   │ normalised  │ quality KPIs│ Training data        │
├─────────────┼─────────────┼─────────────┼──────────────────────┤
│ Quality:LOW │ Quality:MED │ Quality:HIGH│ Quality:HIGH         │
│ Trusted:NO  │ Trusted:YES │ Trusted:YES │ Trusted:YES          │
└─────────────┴─────────────┴─────────────┴──────────────────────┘
*/
CREATE OR REPLACE TAG MEDALLION_LAYER
    COMMENT = 'Medallion layer. Values: BRONZE (raw), SILVER (cleansed), GOLD (analytics), PLATINUM (ML)';

-- ------------------------------------------------------------
-- TAG 5: DATA_QUALITY_STATUS
-- ------------------------------------------------------------
/*
PURPOSE: Track data quality certification status

VALUES AND WORKFLOW:
┌─────────────────────┬────────────────────────────────────────────────────────┐
│ Value               │ Meaning & Allowed Actions                              │
├─────────────────────┼────────────────────────────────────────────────────────┤
│ CERTIFIED           │ Passed all DQ checks - safe for clinical use           │
│ UNDER_REVIEW        │ Pending validation - use with caution                  │
│ QUARANTINED         │ Failed DQ checks - do NOT use for patient care         │
│ DEPRECATED          │ Scheduled for removal - migrate away                   │
└─────────────────────┴────────────────────────────────────────────────────────┘
*/
CREATE OR REPLACE TAG DATA_QUALITY_STATUS
    COMMENT = 'Data quality status. Values: CERTIFIED, UNDER_REVIEW, QUARANTINED, DEPRECATED';

-- ------------------------------------------------------------
-- TAG 6: SOURCE_SYSTEM
-- ------------------------------------------------------------
/*
PURPOSE: Track data origin for lineage and troubleshooting

COMMON HEALTHCARE DATA SOURCES:
┌─────────────────────┬────────────────────────────────────────────────────────┐
│ Source              │ Data Provided                                          │
├─────────────────────┼────────────────────────────────────────────────────────┤
│ EPIC                │ EHR: patients, encounters, orders, notes               │
│ CERNER              │ EHR: patients, encounters, results                     │
│ CLAIMS_SYSTEM       │ Insurance claims, billing, reimbursement               │
│ LIS                 │ Lab Information System: lab results, pathology         │
│ CARDIAC_DEVICE      │ Telemetry, ECG monitors, rehab equipment              │
│ MANUAL              │ Manually entered data (assessments, screenings)        │
└─────────────────────┴────────────────────────────────────────────────────────┘
*/
CREATE OR REPLACE TAG SOURCE_SYSTEM
    COMMENT = 'Source system. Values: EPIC, CERNER, CLAIMS_SYSTEM, LIS, CARDIAC_DEVICE, MANUAL';

-- ------------------------------------------------------------
-- TAG 7: REFRESH_FREQUENCY
-- ------------------------------------------------------------
/*
PURPOSE: Document data refresh cadence for SLA monitoring
*/
CREATE OR REPLACE TAG REFRESH_FREQUENCY
    COMMENT = 'Refresh frequency. Values: REAL_TIME, HOURLY, DAILY, WEEKLY, MONTHLY, ON_DEMAND';

-- ------------------------------------------------------------
-- TAG 8: RETENTION_POLICY
-- ------------------------------------------------------------
/*
PURPOSE: HIPAA/CMS compliance for records retention

HIPAA RETENTION REQUIREMENTS:
─────────────────────────────
  - Medical records: 6-10 years (varies by state)
  - HIPAA policies/procedures: 6 years from creation or last effective date
  - Cardiac rehab records: 7 years (CMS)
  - Billing records: 7 years (CMS)
  - Consent forms: Duration of care + 6 years
*/
CREATE OR REPLACE TAG RETENTION_POLICY
    COMMENT = 'Retention period per HIPAA/CMS. Values: 7_YEARS (standard), 10_YEARS (extended), PERMANENT, 1_YEAR';

-- VERIFICATION
SHOW TAGS IN SCHEMA HEALTH_GOVERNANCE_DB.SECURITY;


-- ============================================================
-- SECTION 2: CREATE MASKING POLICIES
-- ============================================================
/*
WHAT ARE MASKING POLICIES?
──────────────────────────
Masking policies dynamically transform column values at query time
based on the role of the user executing the query.

HOW MASKING WORKS:
──────────────────
┌─────────────────────────────────────────────────────────────────┐
│                     MASKING FLOW                                │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│   User Query                                                    │
│       │                                                         │
│       ▼                                                         │
│   SELECT PATIENT_NAME FROM DIM_PATIENT                          │
│       │                                                         │
│       ▼                                                         │
│   Snowflake checks: Does PATIENT_NAME have masking policy?      │
│       │                                                         │
│       ▼ YES                                                     │
│   Evaluate policy: CASE WHEN CURRENT_ROLE() IN (...) THEN ...   │
│       │                                                         │
│       ├── ANALYST role → Return actual value: "John Smith"      │
│       │                                                         │
│       └── READONLY role → Return masked value: "**REDACTED**"   │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘

KEY CONCEPTS:
─────────────
1. COLUMN-LEVEL: Policies attach to specific columns
2. DYNAMIC: Evaluated at query time (not stored)
3. ROLE-BASED: Different output based on CURRENT_ROLE()
4. TRANSPARENT: Users don't know data is masked
5. AUDITABLE: All access is logged
*/

USE SCHEMA HEALTH_GOVERNANCE_DB.MONITORING;

-- ------------------------------------------------------------
-- POLICY 1: MASK_PATIENT_PHI (Names, identifiers)
-- ------------------------------------------------------------
/*
PURPOSE: Protect patient personal identifiable information

┌─────────────────────────┬────────────────────────────────────────────────────┐
│ Role                    │ What They See                                      │
├─────────────────────────┼────────────────────────────────────────────────────┤
│ HEALTH_DATA_ADMIN       │ Full value: "John Smith"                           │
│ HEALTH_ML_ADMIN         │ Full value: "John Smith"                           │
│ HEALTH_ANALYST          │ Full value: "John Smith"                           │
│ ACCOUNTADMIN            │ Full value: "John Smith"                           │
├─────────────────────────┼────────────────────────────────────────────────────┤
│ HEALTH_DATA_ENGINEER    │ Partial mask: "*****mith" (last 4 chars)          │
│ HEALTH_ML_ENGINEER      │ Partial mask: "*****mith" (last 4 chars)          │
├─────────────────────────┼────────────────────────────────────────────────────┤
│ HEALTH_READONLY         │ Full mask: "**REDACTED**"                          │
│ HEALTH_APP_ADMIN        │ Full mask: "**REDACTED**"                          │
└─────────────────────────┴────────────────────────────────────────────────────┘
*/
CREATE OR REPLACE MASKING POLICY MASK_PATIENT_PHI
    AS (val STRING)
    RETURNS STRING
    ->
    CASE
        WHEN CURRENT_ROLE() IN ('HEALTH_DATA_ADMIN', 'HEALTH_ML_ADMIN', 'HEALTH_ANALYST', 'ACCOUNTADMIN') THEN val
        WHEN CURRENT_ROLE() IN ('HEALTH_DATA_ENGINEER', 'HEALTH_ML_ENGINEER') THEN
            CASE
                WHEN LENGTH(val) > 4 THEN CONCAT(REPEAT('*', LENGTH(val) - 4), RIGHT(val, 4))
                ELSE REPEAT('*', LENGTH(val))
            END
        ELSE '**REDACTED**'
    END
    COMMENT = 'Masks patient PHI (names, identifiers). Full: DATA_ADMIN, ANALYST. Partial: Engineers. Redacted: others.';

-- ------------------------------------------------------------
-- POLICY 2: MASK_SSN (Social Security Number)
-- ------------------------------------------------------------
/*
PURPOSE: Protect Social Security Numbers - highest sensitivity PHI

SSN MASKING STRATEGY:
─────────────────────
SSN is the most sensitive identifier. If exposed, enables:
  - Medical identity theft (fraudulent insurance claims)
  - Financial identity theft
  - HIPAA breach notification required

Masking: "123-45-6789" → "***-**-6789" (last 4 only)
*/
CREATE OR REPLACE MASKING POLICY MASK_SSN
    AS (val STRING)
    RETURNS STRING
    ->
    CASE
        WHEN CURRENT_ROLE() IN ('HEALTH_DATA_ADMIN', 'ACCOUNTADMIN') THEN val
        WHEN CURRENT_ROLE() = 'HEALTH_ANALYST' THEN 'XXX-XX-' || RIGHT(val, 4)
        ELSE '***-**-****'
    END
    COMMENT = 'Masks SSN. Full: DATA_ADMIN only. Last-4: ANALYST. Redacted: all others.';

-- ------------------------------------------------------------
-- POLICY 3: MASK_DOB (Date of Birth)
-- ------------------------------------------------------------
/*
PURPOSE: Protect patient date of birth

DOB MASKING STRATEGY:
─────────────────────
DOB is HIPAA PHI identifier #3. Combined with other data,
DOB enables re-identification of de-identified datasets.

Masking: "1955-03-15" → "1955-01-01" (year only for analysts)

This allows:
  - Age-based cohort analysis (year is sufficient)
  - Population health grouping by birth year
  - Prevention of exact DOB-based re-identification
*/
CREATE OR REPLACE MASKING POLICY MASK_DOB
    AS (val DATE)
    RETURNS DATE
    ->
    CASE
        WHEN CURRENT_ROLE() IN ('HEALTH_DATA_ADMIN', 'HEALTH_ML_ADMIN', 'ACCOUNTADMIN') THEN val
        WHEN CURRENT_ROLE() = 'HEALTH_ANALYST' THEN DATE_FROM_PARTS(YEAR(val), 1, 1)
        ELSE NULL
    END
    COMMENT = 'Masks DOB. Full: DATA_ADMIN. Year-only: ANALYST. NULL: all others.';

-- ------------------------------------------------------------
-- POLICY 4: MASK_PHONE_EMAIL (Contact information)
-- ------------------------------------------------------------
/*
PURPOSE: Protect patient contact information

CONTACT INFORMATION RISKS:
──────────────────────────
Exposed phone/email can be used for:
  - Phishing attacks targeting patients
  - Social engineering for medical identity theft
  - HIPAA breach (contact info is PHI identifier #4/#6)

Masking:
  Email: "john.smith@email.com" → "jo***@***.com"
  Phone: "(555) 123-4567" → "***-***-4567"
*/
CREATE OR REPLACE MASKING POLICY MASK_PHONE_EMAIL
    AS (val STRING)
    RETURNS STRING
    ->
    CASE
        WHEN CURRENT_ROLE() IN ('HEALTH_DATA_ADMIN', 'HEALTH_ANALYST', 'ACCOUNTADMIN') THEN val
        WHEN CONTAINS(val, '@') THEN CONCAT(LEFT(val, 2), '***@***.com')
        WHEN LENGTH(val) >= 10 THEN CONCAT('***-***-', RIGHT(val, 4))
        ELSE '***'
    END
    COMMENT = 'Masks phone numbers and emails. Full: DATA_ADMIN, ANALYST. Partial: others.';

-- VERIFICATION
SHOW MASKING POLICIES IN SCHEMA HEALTH_GOVERNANCE_DB.MONITORING;


-- ============================================================
-- SECTION 3: CREATE ROW ACCESS POLICIES
-- ============================================================
/*
WHAT ARE ROW ACCESS POLICIES?
─────────────────────────────
Row access policies filter which ROWS a user can see, based on
column values and the user's role/attributes.

MASKING vs ROW ACCESS:
──────────────────────
┌─────────────────────┬────────────────────────────────────────────────────────┐
│ Masking Policy      │ Row Access Policy                                      │
├─────────────────────┼────────────────────────────────────────────────────────┤
│ Hides COLUMN values │ Hides entire ROWS                                      │
│ Shows *** or NULL   │ Row doesn't appear in results                          │
│ All rows visible    │ Filtered rows not visible                              │
│ COUNT(*) unchanged  │ COUNT(*) shows only visible rows                       │
└─────────────────────┴────────────────────────────────────────────────────────┘

HOW ROW ACCESS WORKS IN HEALTHCARE:
───────────────────────────────────
┌─────────────────────────────────────────────────────────────────┐
│   Original Table: DIM_PATIENT                                   │
│   ┌────────────┬──────────────┬──────────────┐                 │
│   │ PATIENT_ID │ PATIENT_NAME │ CARE_TEAM_ID │                 │
│   ├────────────┼──────────────┼──────────────┤                 │
│   │ PAT-001    │ John Smith   │ TEAM-CARDIO  │                 │
│   │ PAT-002    │ Jane Doe     │ TEAM-ORTHO   │                 │
│   │ PAT-003    │ Bob Johnson  │ TEAM-CARDIO  │                 │
│   └────────────┴──────────────┴──────────────┘                 │
│                                                                 │
│   Cardiology team member sees only TEAM-CARDIO patients        │
│   → PAT-001 and PAT-003 visible, PAT-002 hidden               │
└─────────────────────────────────────────────────────────────────┘
*/

-- ------------------------------------------------------------
-- POLICY 1: ROW_ACCESS_DATA_QUALITY
-- ------------------------------------------------------------
/*
PURPOSE: Prevent use of bad data by filtering quarantined rows

WHY CRITICAL IN HEALTHCARE:
───────────────────────────
Bad data in healthcare can cause:
  - Wrong medication dosage calculations
  - Incorrect cardiac rehab exercise prescription
  - Missed diagnoses in population health analysis
  - Incorrect CMS quality measure reporting

ACCESS MATRIX:
┌─────────────────────────┬───────────┬─────────────┬─────────────┬────────────┐
│ Role                    │ CERTIFIED │ UNDER_REVIEW│ QUARANTINED │ DEPRECATED │
├─────────────────────────┼───────────┼─────────────┼─────────────┼────────────┤
│ HEALTH_DATA_ADMIN       │ Y         │ Y           │ Y           │ Y          │
│ HEALTH_DATA_ENGINEER    │ Y         │ Y           │ Y           │ Y          │
│ ACCOUNTADMIN            │ Y         │ Y           │ Y           │ Y          │
├─────────────────────────┼───────────┼─────────────┼─────────────┼────────────┤
│ HEALTH_ANALYST          │ Y         │ N           │ N           │ N          │
│ HEALTH_ML_ENGINEER      │ Y         │ N           │ N           │ N          │
│ HEALTH_READONLY         │ Y         │ N           │ N           │ N          │
└─────────────────────────┴───────────┴─────────────┴─────────────┴────────────┘
*/
CREATE OR REPLACE ROW ACCESS POLICY ROW_ACCESS_DATA_QUALITY
    AS (dq_status STRING)
    RETURNS BOOLEAN
    ->
    CASE
        WHEN dq_status = 'CERTIFIED' THEN TRUE
        WHEN dq_status = 'UNDER_REVIEW' THEN
            CURRENT_ROLE() IN ('HEALTH_DATA_ADMIN', 'HEALTH_DATA_ENGINEER', 'ACCOUNTADMIN')
        WHEN dq_status IN ('QUARANTINED', 'DEPRECATED') THEN
            CURRENT_ROLE() IN ('HEALTH_DATA_ADMIN', 'HEALTH_DATA_ENGINEER', 'ACCOUNTADMIN')
        ELSE TRUE
    END
    COMMENT = 'DQ-based access. CERTIFIED: all. QUARANTINED: engineers only. Prevents bad data in clinical analytics.';

-- ------------------------------------------------------------
-- POLICY 2: ROW_ACCESS_CARE_TEAM
-- ------------------------------------------------------------
/*
PURPOSE: Restrict patient data access by care-team assignment

WHY CARE-TEAM SEGREGATION?
──────────────────────────
HIPAA Minimum Necessary Standard (§ 164.502(b)):
  - Healthcare providers should only access PHI for patients
    in their care team
  - A cardiologist should not see orthopaedic patient records
  - This implements "need to know" access

HOW IT WORKS:
─────────────
  - Admin/Analyst: See all patients (for reporting, compliance)
  - ML Engineers: See all patients (for model training on aggregated data)
  - Data Engineers: See all patients (for ETL pipeline management)
  - Readonly: Filtered by AACVPR risk category (HIGH risk only for safety monitoring)

NOTE: In production, this would join to CARE_TEAM_ASSIGNMENTS
      using CURRENT_USER(). Simplified here for demonstration.
*/
CREATE OR REPLACE ROW ACCESS POLICY ROW_ACCESS_CARE_TEAM
    AS (care_team_id STRING)
    RETURNS BOOLEAN
    ->
    CASE
        WHEN CURRENT_ROLE() IN ('HEALTH_DATA_ADMIN', 'HEALTH_ANALYST', 'ACCOUNTADMIN') THEN TRUE
        WHEN CURRENT_ROLE() IN ('HEALTH_DATA_ENGINEER', 'HEALTH_ML_ENGINEER', 'HEALTH_ML_ADMIN') THEN TRUE
        WHEN CURRENT_ROLE() = 'HEALTH_READONLY' THEN
            EXISTS (
                SELECT 1
                FROM HEALTH_TRANSFORM_DB.MASTER.CARE_TEAM_ASSIGNMENTS
                WHERE CLINICIAN_USER = CURRENT_USER()
                  AND CARE_TEAM_ID = care_team_id
            )
        ELSE FALSE
    END
    COMMENT = 'Care-team access per HIPAA Minimum Necessary Standard. READONLY users see only their assigned patients.';

-- VERIFICATION
SHOW ROW ACCESS POLICIES IN SCHEMA HEALTH_GOVERNANCE_DB.MONITORING;


-- ============================================================
-- SECTION 4: GOVERNANCE GRANTS
-- ============================================================
/*
GOVERNANCE PRIVILEGE HIERARCHY:
───────────────────────────────
┌─────────────────────────┬────────────────────────────────────────────────────┐
│ Role                    │ Governance Privileges                              │
├─────────────────────────┼────────────────────────────────────────────────────┤
│ HEALTH_DATA_ADMIN       │ FULL: Create + Apply all governance objects        │
│                         │ Reason: Responsible for platform governance        │
├─────────────────────────┼────────────────────────────────────────────────────┤
│ HEALTH_DATA_ENGINEER    │ APPLY TAG only                                     │
│                         │ Reason: Tag data during ETL, can't create policies │
├─────────────────────────┼────────────────────────────────────────────────────┤
│ HEALTH_ML_ADMIN         │ READ tags only (USAGE on schema)                   │
│                         │ Reason: Understand data classification, not modify │
├─────────────────────────┼────────────────────────────────────────────────────┤
│ Other roles             │ No governance privileges                           │
│                         │ Reason: Consumers, not governors                   │
└─────────────────────────┴────────────────────────────────────────────────────┘
*/

GRANT USAGE ON SCHEMA HEALTH_GOVERNANCE_DB.SECURITY TO ROLE HEALTH_DATA_ADMIN;
GRANT USAGE ON SCHEMA HEALTH_GOVERNANCE_DB.MONITORING TO ROLE HEALTH_DATA_ADMIN;

GRANT CREATE TAG ON SCHEMA HEALTH_GOVERNANCE_DB.SECURITY TO ROLE HEALTH_DATA_ADMIN;
GRANT CREATE MASKING POLICY ON SCHEMA HEALTH_GOVERNANCE_DB.MONITORING TO ROLE HEALTH_DATA_ADMIN;
GRANT CREATE ROW ACCESS POLICY ON SCHEMA HEALTH_GOVERNANCE_DB.MONITORING TO ROLE HEALTH_DATA_ADMIN;

GRANT APPLY TAG ON ACCOUNT TO ROLE HEALTH_DATA_ADMIN;
GRANT APPLY MASKING POLICY ON ACCOUNT TO ROLE HEALTH_DATA_ADMIN;
GRANT APPLY ROW ACCESS POLICY ON ACCOUNT TO ROLE HEALTH_DATA_ADMIN;

GRANT USAGE ON SCHEMA HEALTH_GOVERNANCE_DB.SECURITY TO ROLE HEALTH_ML_ADMIN;

GRANT USAGE ON SCHEMA HEALTH_GOVERNANCE_DB.SECURITY TO ROLE HEALTH_DATA_ENGINEER;
GRANT APPLY TAG ON ACCOUNT TO ROLE HEALTH_DATA_ENGINEER;


-- ============================================================
-- SECTION 5: TAG & POLICY APPLICATION EXAMPLES
-- ============================================================
/*
HOW TO APPLY TAGS AND POLICIES TO YOUR HEALTHCARE DATA:
───────────────────────────────────────────────────────

SYNTAX EXAMPLES:
────────────────
-- Tag a table
ALTER TABLE database.schema.table
    SET TAG tag_name = 'tag_value';

-- Tag a column
ALTER TABLE database.schema.table
    MODIFY COLUMN column_name
    SET TAG tag_name = 'tag_value';

-- Apply masking policy to column
ALTER TABLE database.schema.table
    MODIFY COLUMN column_name
    SET MASKING POLICY policy_name;

-- Apply row access policy to table
ALTER TABLE database.schema.table
    ADD ROW ACCESS POLICY policy_name
    ON (column_name);
*/

-- ============================================================
-- UNCOMMENT AND MODIFY FOR YOUR ACTUAL DATA MODEL:
-- ============================================================

/*
-- ============================================================
-- EXAMPLE 1: Tag and mask DIM_PATIENT table
-- ============================================================

ALTER TABLE HEALTH_TRANSFORM_DB.MASTER.DIM_PATIENT
    SET TAG HEALTH_GOVERNANCE_DB.SECURITY.DATA_DOMAIN = 'PATIENT',
        TAG HEALTH_GOVERNANCE_DB.SECURITY.DATA_SENSITIVITY = 'HIGHLY_CONFIDENTIAL',
        TAG HEALTH_GOVERNANCE_DB.SECURITY.MEDALLION_LAYER = 'SILVER';

ALTER TABLE HEALTH_TRANSFORM_DB.MASTER.DIM_PATIENT
    MODIFY COLUMN FIRST_NAME
    SET TAG HEALTH_GOVERNANCE_DB.SECURITY.PHI_CLASSIFICATION = 'DIRECT_PHI';

ALTER TABLE HEALTH_TRANSFORM_DB.MASTER.DIM_PATIENT
    MODIFY COLUMN FIRST_NAME
    SET MASKING POLICY HEALTH_GOVERNANCE_DB.MONITORING.MASK_PATIENT_PHI;

ALTER TABLE HEALTH_TRANSFORM_DB.MASTER.DIM_PATIENT
    MODIFY COLUMN LAST_NAME
    SET MASKING POLICY HEALTH_GOVERNANCE_DB.MONITORING.MASK_PATIENT_PHI;

ALTER TABLE HEALTH_TRANSFORM_DB.MASTER.DIM_PATIENT
    MODIFY COLUMN SSN
    SET MASKING POLICY HEALTH_GOVERNANCE_DB.MONITORING.MASK_SSN;

ALTER TABLE HEALTH_TRANSFORM_DB.MASTER.DIM_PATIENT
    MODIFY COLUMN DATE_OF_BIRTH
    SET MASKING POLICY HEALTH_GOVERNANCE_DB.MONITORING.MASK_DOB;

ALTER TABLE HEALTH_TRANSFORM_DB.MASTER.DIM_PATIENT
    MODIFY COLUMN EMAIL
    SET MASKING POLICY HEALTH_GOVERNANCE_DB.MONITORING.MASK_PHONE_EMAIL;

ALTER TABLE HEALTH_TRANSFORM_DB.MASTER.DIM_PATIENT
    MODIFY COLUMN PHONE
    SET MASKING POLICY HEALTH_GOVERNANCE_DB.MONITORING.MASK_PHONE_EMAIL;


-- ============================================================
-- EXAMPLE 2: Tag and protect cardiac rehab sessions
-- ============================================================

ALTER TABLE HEALTH_TRANSFORM_DB.CLEANSED.FACT_REHAB_SESSION
    SET TAG HEALTH_GOVERNANCE_DB.SECURITY.DATA_DOMAIN = 'CARDIAC_REHAB',
        TAG HEALTH_GOVERNANCE_DB.SECURITY.MEDALLION_LAYER = 'SILVER',
        TAG HEALTH_GOVERNANCE_DB.SECURITY.SOURCE_SYSTEM = 'CARDIAC_DEVICE',
        TAG HEALTH_GOVERNANCE_DB.SECURITY.REFRESH_FREQUENCY = 'DAILY',
        TAG HEALTH_GOVERNANCE_DB.SECURITY.DATA_QUALITY_STATUS = 'CERTIFIED';


-- ============================================================
-- EXAMPLE 3: Tag claims data
-- ============================================================

ALTER TABLE HEALTH_RAW_DB.REFERENCE_DATA.RAW_CLAIMS
    SET TAG HEALTH_GOVERNANCE_DB.SECURITY.DATA_DOMAIN = 'FINANCIAL',
        TAG HEALTH_GOVERNANCE_DB.SECURITY.MEDALLION_LAYER = 'BRONZE',
        TAG HEALTH_GOVERNANCE_DB.SECURITY.SOURCE_SYSTEM = 'CLAIMS_SYSTEM',
        TAG HEALTH_GOVERNANCE_DB.SECURITY.RETENTION_POLICY = '7_YEARS';
*/


-- ============================================================
-- SECTION 6: VERIFICATION
-- ============================================================

SHOW TAGS IN SCHEMA HEALTH_GOVERNANCE_DB.SECURITY;

SHOW MASKING POLICIES IN SCHEMA HEALTH_GOVERNANCE_DB.MONITORING;

SHOW ROW ACCESS POLICIES IN SCHEMA HEALTH_GOVERNANCE_DB.MONITORING;

SHOW GRANTS TO ROLE HEALTH_DATA_ADMIN;


-- ============================================================
-- SECTION 7: COMPREHENSIVE SUMMARY
-- ============================================================
/*
================================================================================
PHASE 08: DATA GOVERNANCE - COMPREHENSIVE SUMMARY
================================================================================

WHAT WE BUILT:
──────────────
A complete data governance layer for healthcare with:
  - 8 classification tags
  - 4 masking policies
  - 2 row access policies
  - Role-based access control

TAGS CREATED (8):
┌───────────────────────┬───────────────────────────────────────────────────────┐
│ Tag                   │ Purpose                                               │
├───────────────────────┼───────────────────────────────────────────────────────┤
│ PHI_CLASSIFICATION    │ HIPAA PHI level (DIRECT_PHI, QUASI_PHI, CLINICAL)    │
│ DATA_SENSITIVITY      │ Sensitivity (HIGHLY_CONFIDENTIAL → PUBLIC)           │
│ DATA_DOMAIN           │ Business domain (PATIENT, CLINICAL, CARDIAC_REHAB)   │
│ MEDALLION_LAYER       │ Data layer (BRONZE, SILVER, GOLD, PLATINUM)          │
│ DATA_QUALITY_STATUS   │ DQ status (CERTIFIED, QUARANTINED)                   │
│ SOURCE_SYSTEM         │ Data source (EPIC, CERNER, LIS, CARDIAC_DEVICE)      │
│ REFRESH_FREQUENCY     │ Refresh cadence (REAL_TIME, DAILY, etc.)             │
│ RETENTION_POLICY      │ HIPAA/CMS retention (7_YEARS, 10_YEARS, PERMANENT)   │
└───────────────────────┴───────────────────────────────────────────────────────┘

MASKING POLICIES CREATED (4):
┌───────────────────────┬───────────────────────────────────────────────────────┐
│ Policy                │ Purpose & Behaviour                                   │
├───────────────────────┼───────────────────────────────────────────────────────┤
│ MASK_PATIENT_PHI      │ Protects patient names, identifiers                  │
│                       │ Admin/Analyst: Full | Engineers: Last 4 | Others: *** │
├───────────────────────┼───────────────────────────────────────────────────────┤
│ MASK_SSN              │ Protects Social Security Numbers                     │
│                       │ Admin: Full | Analyst: XXX-XX-6789 | Others: ***     │
├───────────────────────┼───────────────────────────────────────────────────────┤
│ MASK_DOB              │ Protects date of birth                               │
│                       │ Admin: Full | Analyst: Year-only | Others: NULL       │
├───────────────────────┼───────────────────────────────────────────────────────┤
│ MASK_PHONE_EMAIL      │ Protects contact information                         │
│                       │ Admin/Analyst: Full | Others: jo***@***.com           │
└───────────────────────┴───────────────────────────────────────────────────────┘

ROW ACCESS POLICIES CREATED (2):
┌─────────────────────────┬─────────────────────────────────────────────────────┐
│ Policy                  │ Purpose & Behaviour                                 │
├─────────────────────────┼─────────────────────────────────────────────────────┤
│ ROW_ACCESS_DATA_QUALITY │ Filters rows by DQ status                          │
│                         │ CERTIFIED: All roles | QUARANTINED: Engineers only  │
│                         │ Prevents bad data in clinical analytics            │
├─────────────────────────┼─────────────────────────────────────────────────────┤
│ ROW_ACCESS_CARE_TEAM    │ Filters rows by care-team assignment               │
│                         │ HIPAA Minimum Necessary Standard                   │
│                         │ READONLY: Only assigned patients visible           │
└─────────────────────────┴─────────────────────────────────────────────────────┘

GOVERNANCE GRANTS SUMMARY:
┌─────────────────────────┬─────────────────────────────────────────────────────┐
│ Role                    │ Governance Privileges                               │
├─────────────────────────┼─────────────────────────────────────────────────────┤
│ HEALTH_DATA_ADMIN       │ CREATE + APPLY: tags, masking, row access          │
│ HEALTH_DATA_ENGINEER    │ APPLY: tags only                                   │
│ HEALTH_ML_ADMIN         │ READ: tags only                                    │
│ Others                  │ No governance privileges                            │
└─────────────────────────┴─────────────────────────────────────────────────────┘

HIPAA COMPLIANCE ACHIEVED:
┌───────────────────────┬───────────────────────────────────────────────────────┐
│ Regulation            │ How We Address It                                     │
├───────────────────────┼───────────────────────────────────────────────────────┤
│ HIPAA Privacy Rule    │ PHI masking policies (names, SSN, DOB, contact)      │
│ § 164.502(b)          │ Minimum Necessary via ROW_ACCESS_CARE_TEAM           │
├───────────────────────┼───────────────────────────────────────────────────────┤
│ HIPAA Security Rule   │ Role-based access control (7 roles)                  │
│ § 164.312             │ Audit trail via Snowflake access history             │
│                       │ Encryption via Snowflake platform                     │
├───────────────────────┼───────────────────────────────────────────────────────┤
│ HITECH Act            │ PHI classification tags for breach scope assessment  │
│                       │ Data sensitivity tags for impact analysis             │
├───────────────────────┼───────────────────────────────────────────────────────┤
│ CMS CoP               │ Retention policy tags (7_YEARS, 10_YEARS)            │
│                       │ Data quality status tracking                          │
└───────────────────────┴───────────────────────────────────────────────────────┘

NEXT STEPS:
───────────
1. Identify tables/columns containing PHI (see HIPAA 18 identifiers)
2. Apply PHI_CLASSIFICATION tags to classify data
3. Apply masking policies to sensitive columns (SSN, DOB, names)
4. Apply row access policies to patient tables
5. Test with each role to verify masking behaviour
6. Document governance in data catalog
7. Train clinical users on data classification

================================================================================
*/

SELECT '============================================' AS separator
UNION ALL
SELECT '  PHASE 08: DATA GOVERNANCE COMPLETE'
UNION ALL
SELECT '  8 Tags + 4 Masking + 2 Row Access'
UNION ALL
SELECT '  Health Domain - Healthcare Platform'
UNION ALL
SELECT '  Proceed to Phase 09: Audit'
UNION ALL
SELECT '============================================';

-- ============================================================
-- END OF PHASE 08: DATA GOVERNANCE
-- ============================================================
