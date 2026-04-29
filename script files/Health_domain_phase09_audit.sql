-- ============================================================
-- HEALTH_DOMAIN — PHASE 09: AUDIT & COMPLIANCE
-- ============================================================
-- Script:      09_audit_compliance.sql
-- Version:     1.0.0
-- Environment: Enterprise Snowflake (HIPAA/HITECH-regulated)
-- Purpose:     Implement centralized enterprise audit and
--              compliance monitoring framework for healthcare.
--
-- AUDIT FRAMEWORK OVERVIEW:
-- -------------------------
-- This phase implements comprehensive audit capabilities:
--   - Security event monitoring (logins, grants, escalations)
--   - PHI data access tracking
--   - Governance change auditing (tags, policies)
--   - Compliance monitoring (HIPAA, HITECH, CMS)
--   - Risk scoring per user
--
-- DATA SOURCES:
-- -------------
-- All views source from SNOWFLAKE.ACCOUNT_USAGE which has:
--   - Up to 45 minutes latency for query data
--   - Up to 2-3 hours latency for some metadata
--   - 365 days retention for most views
--
-- REGULATORY COMPLIANCE:
-- ----------------------
-- These audit views support requirements for:
--   - HIPAA § 164.312(b): Audit controls
--   - HIPAA § 164.308(a)(1)(ii)(D): Information system activity review
--   - HITECH Act: Breach notification evidence
--   - CMS CoP: Medical records access documentation
--
-- Prerequisites:
--   - Phase 01-08 completed
--   - HEALTH_GOVERNANCE_DB.MONITORING schema exists
--   - Tags and policies deployed (Phase 08)
--
-- Execution: Run as ACCOUNTADMIN
-- ============================================================


-- ============================================================
-- SECTION 1: AUDIT SCHEMA SETUP
-- ============================================================

USE ROLE ACCOUNTADMIN;
USE DATABASE HEALTH_GOVERNANCE_DB;
USE WAREHOUSE COMPUTE_WH;
USE SCHEMA MONITORING;


-- ============================================================
-- SECTION 2: SECURITY EVENT AUDIT VIEWS
-- ============================================================

-- ------------------------------------------------------------
-- VIEW: V_LOGIN_HISTORY
-- ------------------------------------------------------------
-- Tracks all authentication attempts including successes and
-- failures. Critical for detecting brute force attacks and
-- unauthorized access attempts to PHI systems.
--
-- Data Latency: Up to 2 hours
-- Retention: Last 90 days
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW HEALTH_GOVERNANCE_DB.MONITORING.V_LOGIN_HISTORY
    COMMENT = 'Authentication audit log tracking login successes and failures. Includes IP, client type, MFA status, and risk level. HIPAA § 164.312(b). Data latency: up to 2 hours. Retention: 90 days.'
AS
SELECT
    EVENT_ID                                                AS EVENT_ID,
    EVENT_TIMESTAMP                                         AS LOGIN_TIMESTAMP,
    USER_NAME                                               AS USER_NAME,
    CLIENT_IP                                               AS CLIENT_IP,
    REPORTED_CLIENT_TYPE                                    AS CLIENT_TYPE,
    REPORTED_CLIENT_VERSION                                 AS CLIENT_VERSION,
    FIRST_AUTHENTICATION_FACTOR                             AS AUTH_METHOD,
    SECOND_AUTHENTICATION_FACTOR                            AS MFA_METHOD,
    IS_SUCCESS                                              AS LOGIN_SUCCESS,
    ERROR_CODE                                              AS ERROR_CODE,
    ERROR_MESSAGE                                           AS ERROR_MESSAGE,
    CASE
        WHEN IS_SUCCESS = 'NO' THEN 'FAILED'
        WHEN SECOND_AUTHENTICATION_FACTOR IS NOT NULL THEN 'SUCCESS_MFA'
        ELSE 'SUCCESS'
    END                                                     AS LOGIN_STATUS,
    CASE
        WHEN IS_SUCCESS = 'NO' THEN 'HIGH'
        WHEN CLIENT_IP NOT LIKE '10.%'
             AND CLIENT_IP NOT LIKE '192.168.%' THEN 'MEDIUM'
        ELSE 'LOW'
    END                                                     AS RISK_LEVEL
FROM SNOWFLAKE.ACCOUNT_USAGE.LOGIN_HISTORY
WHERE EVENT_TIMESTAMP >= DATEADD(DAY, -90, CURRENT_TIMESTAMP())
ORDER BY EVENT_TIMESTAMP DESC;


-- ------------------------------------------------------------
-- VIEW: V_ROLE_GRANT_HISTORY
-- ------------------------------------------------------------
-- Tracks role grants to users and role-to-role inheritance.
-- Essential for detecting unauthorized privilege expansion
-- that could expose PHI.
--
-- Data Latency: Up to 3 hours
-- Retention: Last 180 days
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW HEALTH_GOVERNANCE_DB.MONITORING.V_ROLE_GRANT_HISTORY
    COMMENT = 'Role grant audit tracking grants to users and role hierarchy changes. HIPAA § 164.312(a). Data latency: up to 3 hours. Retention: 180 days.'
AS
SELECT
    CREATED_ON                                              AS GRANT_TIMESTAMP,
    'USER_GRANT'                                            AS GRANT_TYPE,
    ROLE                                                    AS GRANTED_ROLE,
    GRANTEE_NAME                                            AS GRANTEE_NAME,
    'USER'                                                  AS GRANTEE_TYPE,
    GRANTED_BY                                              AS GRANTED_BY,
    CASE
        WHEN ROLE IN ('ACCOUNTADMIN', 'SECURITYADMIN', 'SYSADMIN', 'ORGADMIN')
        THEN 'CRITICAL'
        WHEN ROLE LIKE '%ADMIN%' THEN 'HIGH'
        ELSE 'NORMAL'
    END                                                     AS SENSITIVITY_LEVEL
FROM SNOWFLAKE.ACCOUNT_USAGE.GRANTS_TO_USERS
WHERE CREATED_ON >= DATEADD(DAY, -180, CURRENT_TIMESTAMP())
  AND DELETED_ON IS NULL

UNION ALL

SELECT
    CREATED_ON                                              AS GRANT_TIMESTAMP,
    'ROLE_GRANT'                                            AS GRANT_TYPE,
    NAME                                                    AS GRANTED_ROLE,
    GRANTEE_NAME                                            AS GRANTEE_NAME,
    'ROLE'                                                  AS GRANTEE_TYPE,
    GRANTED_BY                                              AS GRANTED_BY,
    CASE
        WHEN NAME IN ('ACCOUNTADMIN', 'SECURITYADMIN', 'SYSADMIN', 'ORGADMIN')
        THEN 'CRITICAL'
        WHEN NAME LIKE '%ADMIN%' THEN 'HIGH'
        ELSE 'NORMAL'
    END                                                     AS SENSITIVITY_LEVEL
FROM SNOWFLAKE.ACCOUNT_USAGE.GRANTS_TO_ROLES
WHERE GRANTED_ON = 'ROLE'
  AND PRIVILEGE = 'USAGE'
  AND CREATED_ON >= DATEADD(DAY, -180, CURRENT_TIMESTAMP())
  AND DELETED_ON IS NULL

ORDER BY GRANT_TIMESTAMP DESC;


-- ------------------------------------------------------------
-- VIEW: V_PRIVILEGE_ESCALATION_EVENTS
-- ------------------------------------------------------------
-- Detects high-risk privilege grants that could indicate
-- privilege escalation attacks or policy violations.
-- Critical for HIPAA breach detection.
--
-- Data Latency: Up to 3 hours
-- Retention: Last 180 days
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW HEALTH_GOVERNANCE_DB.MONITORING.V_PRIVILEGE_ESCALATION_EVENTS
    COMMENT = 'High-risk privilege escalation detection. Monitors OWNERSHIP, admin role grants, and policy application privileges. HIPAA breach indicator. Data latency: up to 3 hours.'
AS
SELECT
    CREATED_ON                                              AS EVENT_TIMESTAMP,
    PRIVILEGE                                               AS PRIVILEGE_GRANTED,
    GRANTED_ON                                              AS OBJECT_TYPE,
    NAME                                                    AS OBJECT_NAME,
    GRANTEE_NAME                                            AS GRANTEE,
    GRANTED_BY                                              AS GRANTED_BY,
    'HIGH_RISK'                                             AS RISK_FLAG,
    CASE
        WHEN PRIVILEGE = 'OWNERSHIP' THEN 'OWNERSHIP_TRANSFER'
        WHEN PRIVILEGE IN ('APPLY MASKING POLICY', 'APPLY ROW ACCESS POLICY', 'APPLY TAG')
        THEN 'GOVERNANCE_PRIVILEGE'
        WHEN NAME IN ('ACCOUNTADMIN', 'SECURITYADMIN', 'ORGADMIN')
        THEN 'ADMIN_ROLE_GRANT'
        ELSE 'OTHER_ESCALATION'
    END                                                     AS ESCALATION_TYPE,
    CASE
        WHEN NAME IN ('ACCOUNTADMIN', 'ORGADMIN') THEN 'CRITICAL'
        WHEN PRIVILEGE = 'OWNERSHIP' THEN 'CRITICAL'
        WHEN NAME = 'SECURITYADMIN' THEN 'HIGH'
        WHEN PRIVILEGE LIKE 'APPLY%' THEN 'HIGH'
        ELSE 'MEDIUM'
    END                                                     AS SEVERITY
FROM SNOWFLAKE.ACCOUNT_USAGE.GRANTS_TO_ROLES
WHERE (
    PRIVILEGE = 'OWNERSHIP'
    OR PRIVILEGE IN ('APPLY MASKING POLICY', 'APPLY ROW ACCESS POLICY', 'APPLY TAG')
    OR (GRANTED_ON = 'ROLE' AND NAME IN ('ACCOUNTADMIN', 'SECURITYADMIN', 'SYSADMIN', 'ORGADMIN'))
)
AND CREATED_ON >= DATEADD(DAY, -180, CURRENT_TIMESTAMP())
AND DELETED_ON IS NULL
ORDER BY CREATED_ON DESC;


-- ============================================================
-- SECTION 3: PHI DATA ACCESS AUDIT
-- ============================================================

-- ------------------------------------------------------------
-- VIEW: V_PHI_DATA_ACCESS
-- ------------------------------------------------------------
-- Tracks queries that accessed PHI-tagged columns.
-- Joins query history with tag references to identify
-- access to DIRECT_PHI patient data.
--
-- HIPAA § 164.312(b) requires audit controls that record
-- and examine activity in systems containing ePHI.
--
-- Data Latency: Up to 3 hours
-- Retention: Last 90 days
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW HEALTH_GOVERNANCE_DB.MONITORING.V_PHI_DATA_ACCESS
    COMMENT = 'PHI data access audit tracking queries to columns tagged as DIRECT_PHI or CLINICAL. HIPAA § 164.312(b) audit control. Data latency: up to 3 hours. Retention: 90 days.'
AS
SELECT
    qh.QUERY_ID                                             AS QUERY_ID,
    qh.START_TIME                                           AS ACCESS_TIMESTAMP,
    qh.USER_NAME                                            AS USER_NAME,
    qh.ROLE_NAME                                            AS ROLE_NAME,
    qh.WAREHOUSE_NAME                                       AS WAREHOUSE_NAME,
    qh.DATABASE_NAME                                        AS DATABASE_ACCESSED,
    qh.SCHEMA_NAME                                          AS SCHEMA_ACCESSED,
    COALESCE(tr.OBJECT_NAME, 'UNKNOWN')                     AS TABLE_ACCESSED,
    COALESCE(tr.COLUMN_NAME, 'UNKNOWN')                     AS COLUMN_ACCESSED,
    tr.TAG_VALUE                                            AS PHI_CLASSIFICATION,
    LEFT(qh.QUERY_TEXT, 500)                                AS QUERY_TEXT_PREVIEW,
    qh.EXECUTION_STATUS                                     AS EXECUTION_STATUS,
    qh.TOTAL_ELAPSED_TIME / 1000                            AS EXECUTION_SECONDS,
    CASE
        WHEN tr.TAG_VALUE = 'DIRECT_PHI' THEN 'CRITICAL'
        WHEN tr.TAG_VALUE = 'CLINICAL' THEN 'HIGH'
        WHEN tr.TAG_VALUE = 'QUASI_PHI' THEN 'MEDIUM'
        ELSE 'LOW'
    END                                                     AS SENSITIVITY_LEVEL,
    CASE
        WHEN qh.ROLE_NAME NOT IN ('HEALTH_DATA_ADMIN', 'HEALTH_ANALYST', 'ACCOUNTADMIN')
             AND tr.TAG_VALUE = 'DIRECT_PHI'
        THEN 'POTENTIAL_VIOLATION'
        ELSE 'AUTHORIZED'
    END                                                     AS ACCESS_ASSESSMENT
FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY qh
LEFT JOIN SNOWFLAKE.ACCOUNT_USAGE.TAG_REFERENCES tr
    ON tr.OBJECT_DATABASE = qh.DATABASE_NAME
    AND tr.OBJECT_SCHEMA = qh.SCHEMA_NAME
    AND tr.TAG_DATABASE = 'HEALTH_GOVERNANCE_DB'
    AND tr.TAG_SCHEMA = 'SECURITY'
    AND tr.TAG_NAME = 'PHI_CLASSIFICATION'
    AND tr.TAG_VALUE IN ('DIRECT_PHI', 'QUASI_PHI', 'CLINICAL')
WHERE qh.START_TIME >= DATEADD(DAY, -90, CURRENT_TIMESTAMP())
  AND (qh.WAREHOUSE_NAME LIKE 'HEALTH_%' OR qh.WAREHOUSE_NAME = 'COMPUTE_WH')
  AND qh.QUERY_TYPE IN ('SELECT', 'INSERT', 'UPDATE', 'MERGE', 'DELETE')
  AND tr.TAG_VALUE IS NOT NULL
ORDER BY qh.START_TIME DESC;


-- ------------------------------------------------------------
-- VIEW: V_PHI_ACCESS_LOG (ACCESS_HISTORY based)
-- ------------------------------------------------------------
-- Tracks queries touching patient tables via ACCESS_HISTORY.
-- Complements tag-based audit with object-level tracking.
--
-- Data Latency: Up to 3 hours
-- Retention: Last 90 days
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW HEALTH_GOVERNANCE_DB.MONITORING.V_PHI_ACCESS_LOG
    COMMENT = 'PHI access log via ACCESS_HISTORY. Tracks queries touching patient-related tables. HIPAA § 164.312(b). Retention: 90 days.'
AS
SELECT
    QH.QUERY_ID                                             AS QUERY_ID,
    QH.START_TIME                                           AS ACCESS_TIMESTAMP,
    QH.USER_NAME                                            AS USER_NAME,
    QH.ROLE_NAME                                            AS ROLE_NAME,
    QH.WAREHOUSE_NAME                                       AS WAREHOUSE_NAME,
    AH.DIRECT_OBJECTS_ACCESSED                              AS OBJECTS_ACCESSED,
    LEFT(QH.QUERY_TEXT, 500)                                AS QUERY_TEXT_PREVIEW,
    QH.EXECUTION_STATUS                                     AS EXECUTION_STATUS,
    CASE
        WHEN QH.ROLE_NAME NOT IN ('HEALTH_DATA_ADMIN', 'HEALTH_ANALYST', 'ACCOUNTADMIN')
        THEN 'REQUIRES_REVIEW'
        ELSE 'AUTHORIZED'
    END                                                     AS ACCESS_ASSESSMENT
FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY QH
JOIN SNOWFLAKE.ACCOUNT_USAGE.ACCESS_HISTORY AH
  ON QH.QUERY_ID = AH.QUERY_ID
WHERE QH.START_TIME >= DATEADD(DAY, -90, CURRENT_TIMESTAMP())
  AND ARRAY_TO_STRING(AH.DIRECT_OBJECTS_ACCESSED, ',') ILIKE '%PATIENT%'
ORDER BY QH.START_TIME DESC;


-- ------------------------------------------------------------
-- VIEW: V_MASKING_POLICY_USAGE
-- ------------------------------------------------------------
-- Tracks which columns are protected by masking policies.
-- Data Latency: Up to 3 hours
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW HEALTH_GOVERNANCE_DB.MONITORING.V_MASKING_POLICY_USAGE
    COMMENT = 'Masking policy application audit showing which columns are protected. Data latency: up to 3 hours.'
AS
SELECT
    pr.POLICY_NAME                                          AS MASKING_POLICY_NAME,
    pr.POLICY_DB                                            AS POLICY_DATABASE,
    pr.POLICY_SCHEMA                                        AS POLICY_SCHEMA,
    pr.REF_DATABASE_NAME                                    AS PROTECTED_DATABASE,
    pr.REF_SCHEMA_NAME                                      AS PROTECTED_SCHEMA,
    pr.REF_ENTITY_NAME                                      AS PROTECTED_TABLE,
    pr.REF_COLUMN_NAME                                      AS PROTECTED_COLUMN,
    pr.REF_ENTITY_DOMAIN                                    AS OBJECT_TYPE,
    mp.POLICY_OWNER                                         AS POLICY_OWNER,
    mp.CREATED                                              AS POLICY_CREATED,
    CASE
        WHEN pr.POLICY_NAME LIKE '%SSN%' THEN 'CRITICAL'
        WHEN pr.POLICY_NAME LIKE '%PHI%' THEN 'CRITICAL'
        WHEN pr.POLICY_NAME LIKE '%DOB%' THEN 'HIGH'
        WHEN pr.POLICY_NAME LIKE '%PHONE%' OR pr.POLICY_NAME LIKE '%EMAIL%' THEN 'HIGH'
        ELSE 'STANDARD'
    END                                                     AS PROTECTION_LEVEL
FROM SNOWFLAKE.ACCOUNT_USAGE.POLICY_REFERENCES pr
JOIN SNOWFLAKE.ACCOUNT_USAGE.MASKING_POLICIES mp
    ON pr.POLICY_NAME = mp.POLICY_NAME
    AND pr.POLICY_DB = mp.POLICY_CATALOG
    AND pr.POLICY_SCHEMA = mp.POLICY_SCHEMA
WHERE pr.POLICY_KIND = 'MASKING_POLICY'
  AND pr.REF_DATABASE_NAME LIKE 'HEALTH_%'
  AND mp.DELETED IS NULL
ORDER BY pr.POLICY_NAME, pr.REF_DATABASE_NAME, pr.REF_SCHEMA_NAME;


-- ------------------------------------------------------------
-- VIEW: V_ROW_ACCESS_POLICY_USAGE
-- ------------------------------------------------------------
-- Tracks tables with row access policies applied.
-- Data Latency: Up to 3 hours
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW HEALTH_GOVERNANCE_DB.MONITORING.V_ROW_ACCESS_POLICY_USAGE
    COMMENT = 'Row access policy application audit showing which tables have row-level security. Data latency: up to 3 hours.'
AS
SELECT
    pr.POLICY_NAME                                          AS ROW_ACCESS_POLICY_NAME,
    pr.POLICY_DB                                            AS POLICY_DATABASE,
    pr.POLICY_SCHEMA                                        AS POLICY_SCHEMA,
    pr.REF_DATABASE_NAME                                    AS PROTECTED_DATABASE,
    pr.REF_SCHEMA_NAME                                      AS PROTECTED_SCHEMA,
    pr.REF_ENTITY_NAME                                      AS PROTECTED_TABLE,
    pr.REF_ENTITY_DOMAIN                                    AS OBJECT_TYPE,
    rap.POLICY_OWNER                                        AS POLICY_OWNER,
    rap.CREATED                                             AS POLICY_CREATED,
    CASE
        WHEN pr.POLICY_NAME LIKE '%CARE_TEAM%' THEN 'HIGH'
        WHEN pr.POLICY_NAME LIKE '%DATA_QUALITY%' THEN 'MEDIUM'
        ELSE 'STANDARD'
    END                                                     AS PROTECTION_LEVEL
FROM SNOWFLAKE.ACCOUNT_USAGE.POLICY_REFERENCES pr
JOIN SNOWFLAKE.ACCOUNT_USAGE.ROW_ACCESS_POLICIES rap
    ON pr.POLICY_NAME = rap.POLICY_NAME
    AND pr.POLICY_DB = rap.POLICY_CATALOG
    AND pr.POLICY_SCHEMA = rap.POLICY_SCHEMA
WHERE pr.POLICY_KIND = 'ROW_ACCESS_POLICY'
  AND pr.REF_DATABASE_NAME LIKE 'HEALTH_%'
  AND rap.DELETED IS NULL
ORDER BY pr.POLICY_NAME, pr.REF_DATABASE_NAME, pr.REF_SCHEMA_NAME;


-- ============================================================
-- SECTION 4: GOVERNANCE CHANGE AUDIT
-- ============================================================

-- ------------------------------------------------------------
-- VIEW: V_TAG_CHANGE_HISTORY
-- ------------------------------------------------------------
-- Tracks tag-related DDL operations.
-- Data Latency: Up to 45 minutes | Retention: 180 days
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW HEALTH_GOVERNANCE_DB.MONITORING.V_TAG_CHANGE_HISTORY
    COMMENT = 'Tag governance change audit. Tracks CREATE/ALTER/DROP TAG and SET/UNSET TAG. Data latency: up to 45 minutes. Retention: 180 days.'
AS
SELECT
    QUERY_ID                                                AS QUERY_ID,
    START_TIME                                              AS CHANGE_TIMESTAMP,
    USER_NAME                                               AS CHANGED_BY,
    ROLE_NAME                                               AS ROLE_USED,
    QUERY_TYPE                                              AS OPERATION_TYPE,
    DATABASE_NAME                                           AS TARGET_DATABASE,
    SCHEMA_NAME                                             AS TARGET_SCHEMA,
    LEFT(QUERY_TEXT, 1000)                                  AS DDL_STATEMENT,
    EXECUTION_STATUS                                        AS STATUS,
    CASE
        WHEN QUERY_TEXT ILIKE '%DROP TAG%' THEN 'CRITICAL'
        WHEN QUERY_TEXT ILIKE '%UNSET TAG%' THEN 'HIGH'
        WHEN QUERY_TEXT ILIKE '%ALTER TAG%' THEN 'MEDIUM'
        WHEN QUERY_TEXT ILIKE '%SET TAG%' THEN 'MEDIUM'
        ELSE 'LOW'
    END                                                     AS CHANGE_SEVERITY
FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY
WHERE START_TIME >= DATEADD(DAY, -180, CURRENT_TIMESTAMP())
  AND (
    QUERY_TEXT ILIKE '%CREATE TAG%'
    OR QUERY_TEXT ILIKE '%ALTER TAG%'
    OR QUERY_TEXT ILIKE '%DROP TAG%'
    OR QUERY_TEXT ILIKE '%SET TAG%'
    OR QUERY_TEXT ILIKE '%UNSET TAG%'
  )
  AND QUERY_TYPE IN ('CREATE', 'ALTER', 'DROP', 'ALTER_TABLE', 'ALTER_TABLE_MODIFY_COLUMN')
ORDER BY START_TIME DESC;


-- ------------------------------------------------------------
-- VIEW: V_POLICY_CHANGE_HISTORY
-- ------------------------------------------------------------
-- Tracks masking/RAP policy DDL operations.
-- Data Latency: Up to 45 minutes | Retention: 180 days
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW HEALTH_GOVERNANCE_DB.MONITORING.V_POLICY_CHANGE_HISTORY
    COMMENT = 'Policy governance change audit. Tracks CREATE/ALTER/DROP for masking and row access policies. Data latency: up to 45 minutes. Retention: 180 days.'
AS
SELECT
    QUERY_ID                                                AS QUERY_ID,
    START_TIME                                              AS CHANGE_TIMESTAMP,
    USER_NAME                                               AS CHANGED_BY,
    ROLE_NAME                                               AS ROLE_USED,
    QUERY_TYPE                                              AS OPERATION_TYPE,
    DATABASE_NAME                                           AS TARGET_DATABASE,
    SCHEMA_NAME                                             AS TARGET_SCHEMA,
    LEFT(QUERY_TEXT, 1000)                                  AS DDL_STATEMENT,
    EXECUTION_STATUS                                        AS STATUS,
    CASE
        WHEN QUERY_TEXT ILIKE '%MASKING POLICY%' THEN 'MASKING_POLICY'
        WHEN QUERY_TEXT ILIKE '%ROW ACCESS POLICY%' THEN 'ROW_ACCESS_POLICY'
        ELSE 'OTHER_POLICY'
    END                                                     AS POLICY_TYPE,
    CASE
        WHEN QUERY_TEXT ILIKE '%DROP%POLICY%' THEN 'CRITICAL'
        WHEN QUERY_TEXT ILIKE '%ALTER%POLICY%' THEN 'HIGH'
        WHEN QUERY_TEXT ILIKE '%CREATE%POLICY%' THEN 'MEDIUM'
        ELSE 'LOW'
    END                                                     AS CHANGE_SEVERITY
FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY
WHERE START_TIME >= DATEADD(DAY, -180, CURRENT_TIMESTAMP())
  AND (
    QUERY_TEXT ILIKE '%MASKING POLICY%'
    OR QUERY_TEXT ILIKE '%ROW ACCESS POLICY%'
  )
  AND QUERY_TYPE IN ('CREATE_MASKING_POLICY', 'CREATE_ROW_ACCESS_POLICY',
                     'ALTER_MASKING_POLICY', 'ALTER_ROW_ACCESS_POLICY',
                     'DROP_MASKING_POLICY', 'DROP_ROW_ACCESS_POLICY',
                     'CREATE', 'ALTER', 'DROP')
ORDER BY START_TIME DESC;


-- ============================================================
-- SECTION 5: USER & SESSION AUDIT
-- ============================================================

-- ------------------------------------------------------------
-- VIEW: V_USER_INVENTORY
-- ------------------------------------------------------------
-- Complete user inventory with MFA status and last login.
-- Identifies dormant accounts that should be disabled.
-- Data Latency: Up to 3 hours
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW HEALTH_GOVERNANCE_DB.MONITORING.V_USER_INVENTORY
    COMMENT = 'User inventory with MFA status, last login, and dormancy flag. HIPAA § 164.312(a) access control. Data latency: up to 3 hours.'
AS
SELECT
    NAME                                                    AS USER_NAME,
    LOGIN_NAME                                              AS LOGIN_NAME,
    DISPLAY_NAME                                            AS DISPLAY_NAME,
    EMAIL                                                   AS EMAIL,
    DEFAULT_ROLE                                            AS DEFAULT_ROLE,
    DEFAULT_WAREHOUSE                                       AS DEFAULT_WAREHOUSE,
    CREATED_ON                                              AS CREATED_ON,
    LAST_SUCCESS_LOGIN                                      AS LAST_LOGIN,
    DISABLED                                                AS IS_DISABLED,
    LOCKED                                                  AS IS_LOCKED,
    HAS_MFA                                                 AS HAS_MFA,
    DATEDIFF(DAY, LAST_SUCCESS_LOGIN, CURRENT_TIMESTAMP())  AS DAYS_SINCE_LAST_LOGIN,
    CASE
        WHEN DISABLED = 'true' THEN 'DISABLED'
        WHEN LAST_SUCCESS_LOGIN IS NULL THEN 'NEVER_LOGGED_IN'
        WHEN DATEDIFF(DAY, LAST_SUCCESS_LOGIN, CURRENT_TIMESTAMP()) > 90 THEN 'DORMANT_90D'
        WHEN DATEDIFF(DAY, LAST_SUCCESS_LOGIN, CURRENT_TIMESTAMP()) > 30 THEN 'DORMANT_30D'
        ELSE 'ACTIVE'
    END                                                     AS ACCOUNT_STATUS,
    CASE
        WHEN HAS_MFA = 'false' AND DISABLED = 'false' THEN 'HIGH'
        WHEN DATEDIFF(DAY, LAST_SUCCESS_LOGIN, CURRENT_TIMESTAMP()) > 90 THEN 'MEDIUM'
        ELSE 'LOW'
    END                                                     AS RISK_LEVEL
FROM SNOWFLAKE.ACCOUNT_USAGE.USERS
ORDER BY LAST_SUCCESS_LOGIN DESC NULLS LAST;


-- ------------------------------------------------------------
-- VIEW: V_SESSION_HISTORY
-- ------------------------------------------------------------
-- Session tracking including client details and duration.
-- Data Latency: Up to 3 hours | Retention: 90 days
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW HEALTH_GOVERNANCE_DB.MONITORING.V_SESSION_HISTORY
    COMMENT = 'Session audit log tracking user sessions. Flags extended sessions and missing MFA. Data latency: up to 3 hours. Retention: 90 days.'
AS
SELECT
    SESSION_ID                                              AS SESSION_ID,
    USER_NAME                                               AS USER_NAME,
    CREATED_ON                                              AS LOGIN_TIME,
    IS_OPEN                                                 AS IS_SESSION_OPEN,
    CLOSED_REASON                                           AS CLOSED_REASON,
    CLIENT_APPLICATION_ID                                   AS CLIENT_APPLICATION,
    CLIENT_APPLICATION_VERSION                              AS CLIENT_VERSION,
    CLIENT_ENVIRONMENT                                      AS CLIENT_ENVIRONMENT,
    AUTHENTICATION_METHOD                                   AS AUTH_METHOD,
    CASE
        WHEN IS_OPEN AND DATEDIFF(HOUR, CREATED_ON, CURRENT_TIMESTAMP()) > 8
        THEN 'EXTENDED_SESSION'
        WHEN AUTHENTICATION_METHOD NOT LIKE '%MFA%' AND AUTHENTICATION_METHOD NOT LIKE '%MULTI%'
        THEN 'NO_MFA'
        ELSE 'NORMAL'
    END                                                     AS SESSION_FLAG
FROM SNOWFLAKE.ACCOUNT_USAGE.SESSIONS
WHERE CREATED_ON >= DATEADD(DAY, -90, CURRENT_TIMESTAMP())
ORDER BY CREATED_ON DESC;


-- ------------------------------------------------------------
-- VIEW: V_ADMIN_ACTIVITY
-- ------------------------------------------------------------
-- Tracks all activity performed using administrative roles.
-- Critical for HIPAA separation of duties compliance.
-- Data Latency: Up to 45 minutes | Retention: 90 days
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW HEALTH_GOVERNANCE_DB.MONITORING.V_ADMIN_ACTIVITY
    COMMENT = 'Administrative activity audit. Tracks ACCOUNTADMIN, SECURITYADMIN, SYSADMIN operations. HIPAA separation of duties. Data latency: up to 45 minutes. Retention: 90 days.'
AS
SELECT
    QUERY_ID                                                AS QUERY_ID,
    START_TIME                                              AS ACTIVITY_TIMESTAMP,
    USER_NAME                                               AS USER_NAME,
    ROLE_NAME                                               AS ADMIN_ROLE,
    QUERY_TYPE                                              AS OPERATION_TYPE,
    DATABASE_NAME                                           AS TARGET_DATABASE,
    SCHEMA_NAME                                             AS TARGET_SCHEMA,
    WAREHOUSE_NAME                                          AS WAREHOUSE_NAME,
    LEFT(QUERY_TEXT, 500)                                   AS QUERY_TEXT_PREVIEW,
    EXECUTION_STATUS                                        AS STATUS,
    TOTAL_ELAPSED_TIME / 1000                               AS EXECUTION_SECONDS,
    ROWS_PRODUCED                                           AS ROWS_AFFECTED,
    CASE
        WHEN ROLE_NAME = 'ACCOUNTADMIN' THEN 'CRITICAL'
        WHEN ROLE_NAME = 'SECURITYADMIN' THEN 'HIGH'
        WHEN ROLE_NAME = 'SYSADMIN' THEN 'MEDIUM'
        ELSE 'OTHER'
    END                                                     AS PRIVILEGE_LEVEL,
    CASE
        WHEN QUERY_TYPE IN ('GRANT', 'REVOKE') THEN 'PRIVILEGE_CHANGE'
        WHEN QUERY_TYPE IN ('CREATE_USER', 'ALTER_USER', 'DROP_USER') THEN 'USER_MANAGEMENT'
        WHEN QUERY_TYPE IN ('CREATE_ROLE', 'DROP_ROLE') THEN 'ROLE_MANAGEMENT'
        WHEN QUERY_TYPE LIKE 'CREATE%' OR QUERY_TYPE LIKE 'DROP%' THEN 'DDL_OPERATION'
        ELSE 'OTHER_OPERATION'
    END                                                     AS ACTIVITY_CATEGORY
FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY
WHERE START_TIME >= DATEADD(DAY, -90, CURRENT_TIMESTAMP())
  AND ROLE_NAME IN ('ACCOUNTADMIN', 'SECURITYADMIN', 'SYSADMIN')
  AND EXECUTION_STATUS = 'SUCCESS'
ORDER BY START_TIME DESC;


-- ------------------------------------------------------------
-- VIEW: V_DDL_CHANGE_LOG
-- ------------------------------------------------------------
-- Tracks all DDL operations (CREATE/ALTER/DROP/GRANT/REVOKE).
-- Carried from original health domain for schema change audit.
-- Data Latency: Up to 45 minutes | Retention: 90 days
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW HEALTH_GOVERNANCE_DB.MONITORING.V_DDL_CHANGE_LOG
    COMMENT = 'DDL change log tracking CREATE/ALTER/DROP/GRANT/REVOKE operations across the platform. Data latency: up to 45 minutes. Retention: 90 days.'
AS
SELECT
    QUERY_ID                                                AS QUERY_ID,
    START_TIME                                              AS CHANGE_TIMESTAMP,
    USER_NAME                                               AS CHANGED_BY,
    ROLE_NAME                                               AS ROLE_USED,
    DATABASE_NAME                                           AS TARGET_DATABASE,
    SCHEMA_NAME                                             AS TARGET_SCHEMA,
    QUERY_TYPE                                              AS OPERATION_TYPE,
    LEFT(QUERY_TEXT, 500)                                   AS DDL_STATEMENT,
    EXECUTION_STATUS                                        AS STATUS,
    CASE
        WHEN QUERY_TYPE LIKE 'DROP%' THEN 'HIGH'
        WHEN QUERY_TYPE IN ('GRANT', 'REVOKE') THEN 'HIGH'
        WHEN QUERY_TYPE LIKE 'ALTER%' THEN 'MEDIUM'
        WHEN QUERY_TYPE LIKE 'CREATE%' THEN 'LOW'
        ELSE 'LOW'
    END                                                     AS CHANGE_SEVERITY
FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY
WHERE QUERY_TYPE IN ('CREATE_TABLE', 'ALTER_TABLE', 'DROP_TABLE',
                     'CREATE_VIEW', 'ALTER_VIEW', 'DROP_VIEW',
                     'CREATE_SCHEMA', 'DROP_SCHEMA',
                     'CREATE_DATABASE', 'DROP_DATABASE',
                     'GRANT', 'REVOKE')
  AND START_TIME >= DATEADD(DAY, -90, CURRENT_TIMESTAMP())
ORDER BY START_TIME DESC;


-- ============================================================
-- SECTION 6: HIPAA RETENTION COMPLIANCE
-- ============================================================

-- ------------------------------------------------------------
-- VIEW: V_RETENTION_COMPLIANCE_STATUS
-- ------------------------------------------------------------
-- Tracks data retention status against HIPAA/CMS requirements.
-- Data Latency: Up to 3 hours
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW HEALTH_GOVERNANCE_DB.MONITORING.V_RETENTION_COMPLIANCE_STATUS
    COMMENT = 'HIPAA/CMS retention compliance status showing data retention policy adherence. Data latency: up to 3 hours.'
AS
SELECT
    tr.OBJECT_DATABASE                                      AS DATABASE_NAME,
    tr.OBJECT_SCHEMA                                        AS SCHEMA_NAME,
    tr.OBJECT_NAME                                          AS TABLE_NAME,
    tr.TAG_VALUE                                            AS RETENTION_POLICY,
    t.CREATED                                               AS TABLE_CREATED,
    t.ROW_COUNT                                             AS ROW_COUNT,
    t.BYTES / (1024*1024*1024)                              AS SIZE_GB,
    CASE
        WHEN tr.TAG_VALUE = '7_YEARS' THEN DATEADD(YEAR, 7, t.CREATED)
        WHEN tr.TAG_VALUE = '10_YEARS' THEN DATEADD(YEAR, 10, t.CREATED)
        WHEN tr.TAG_VALUE = 'PERMANENT' THEN NULL
        WHEN tr.TAG_VALUE = '1_YEAR' THEN DATEADD(YEAR, 1, t.CREATED)
        ELSE NULL
    END                                                     AS EARLIEST_DELETION_DATE,
    CASE
        WHEN tr.TAG_VALUE = 'PERMANENT' THEN 'NEVER_DELETE'
        WHEN tr.TAG_VALUE IS NULL THEN 'UNTAGGED_REVIEW_REQUIRED'
        ELSE 'RETENTION_ACTIVE'
    END                                                     AS RETENTION_STATUS,
    'HIPAA/CMS'                                             AS REGULATORY_REFERENCE
FROM SNOWFLAKE.ACCOUNT_USAGE.TAG_REFERENCES tr
JOIN SNOWFLAKE.ACCOUNT_USAGE.TABLES t
    ON tr.OBJECT_DATABASE = t.TABLE_CATALOG
    AND tr.OBJECT_SCHEMA = t.TABLE_SCHEMA
    AND tr.OBJECT_NAME = t.TABLE_NAME
WHERE tr.TAG_DATABASE = 'HEALTH_GOVERNANCE_DB'
  AND tr.TAG_SCHEMA = 'SECURITY'
  AND tr.TAG_NAME = 'RETENTION_POLICY'
  AND tr.OBJECT_DATABASE LIKE 'HEALTH_%'
  AND t.DELETED IS NULL
ORDER BY tr.OBJECT_DATABASE, tr.OBJECT_SCHEMA, tr.OBJECT_NAME;


-- ============================================================
-- SECTION 7: RISK SCORING
-- ============================================================

-- ------------------------------------------------------------
-- VIEW: V_SECURITY_RISK_SCORE
-- ------------------------------------------------------------
-- Computes a security risk score for each user based on:
--   +50  ACCOUNTADMIN usage
--   +30  Privilege escalation grants
--   +25  Access to DIRECT_PHI data
--   +40  Access to HIGHLY_CONFIDENTIAL data
--   +20  Multiple failed logins
--
-- Risk Levels: LOW (0-25), MEDIUM (26-50), HIGH (51-100), CRITICAL (101+)
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW HEALTH_GOVERNANCE_DB.MONITORING.V_SECURITY_RISK_SCORE
    COMMENT = 'User security risk scoring based on admin usage, privilege escalations, PHI access, and failed logins. Risk levels: LOW, MEDIUM, HIGH, CRITICAL.'
AS
WITH admin_usage AS (
    SELECT USER_NAME, COUNT(*) AS admin_query_count, 50 AS risk_points
    FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY
    WHERE ROLE_NAME = 'ACCOUNTADMIN'
      AND START_TIME >= DATEADD(DAY, -90, CURRENT_TIMESTAMP())
      AND EXECUTION_STATUS = 'SUCCESS'
    GROUP BY USER_NAME
),
privilege_escalations AS (
    SELECT GRANTED_BY AS USER_NAME, COUNT(*) AS escalation_count, 30 AS risk_points
    FROM SNOWFLAKE.ACCOUNT_USAGE.GRANTS_TO_ROLES
    WHERE (PRIVILEGE = 'OWNERSHIP' OR NAME IN ('ACCOUNTADMIN', 'SECURITYADMIN'))
      AND CREATED_ON >= DATEADD(DAY, -90, CURRENT_TIMESTAMP())
      AND DELETED_ON IS NULL
    GROUP BY GRANTED_BY
),
direct_phi_access AS (
    SELECT qh.USER_NAME, COUNT(*) AS phi_access_count, 25 AS risk_points
    FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY qh
    JOIN SNOWFLAKE.ACCOUNT_USAGE.TAG_REFERENCES tr
        ON tr.OBJECT_DATABASE = qh.DATABASE_NAME
    WHERE qh.START_TIME >= DATEADD(DAY, -90, CURRENT_TIMESTAMP())
      AND tr.TAG_NAME = 'PHI_CLASSIFICATION'
      AND tr.TAG_VALUE = 'DIRECT_PHI'
    GROUP BY qh.USER_NAME
),
confidential_access AS (
    SELECT qh.USER_NAME, COUNT(*) AS confidential_access_count, 40 AS risk_points
    FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY qh
    JOIN SNOWFLAKE.ACCOUNT_USAGE.TAG_REFERENCES tr
        ON tr.OBJECT_DATABASE = qh.DATABASE_NAME
    WHERE qh.START_TIME >= DATEADD(DAY, -90, CURRENT_TIMESTAMP())
      AND tr.TAG_NAME = 'DATA_SENSITIVITY'
      AND tr.TAG_VALUE = 'HIGHLY_CONFIDENTIAL'
      AND qh.ROLE_NAME NOT IN ('HEALTH_DATA_ADMIN', 'HEALTH_ANALYST', 'ACCOUNTADMIN')
    GROUP BY qh.USER_NAME
),
failed_logins AS (
    SELECT USER_NAME, COUNT(*) AS failed_login_count, 20 AS risk_points
    FROM SNOWFLAKE.ACCOUNT_USAGE.LOGIN_HISTORY
    WHERE IS_SUCCESS = 'NO'
      AND EVENT_TIMESTAMP >= DATEADD(DAY, -90, CURRENT_TIMESTAMP())
    GROUP BY USER_NAME
    HAVING COUNT(*) >= 3
),
all_users AS (
    SELECT DISTINCT USER_NAME
    FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY
    WHERE START_TIME >= DATEADD(DAY, -90, CURRENT_TIMESTAMP())
)
SELECT
    u.USER_NAME                                             AS USER_NAME,
    COALESCE(au.admin_query_count, 0)                       AS ACCOUNTADMIN_QUERIES,
    COALESCE(pe.escalation_count, 0)                        AS PRIVILEGE_ESCALATIONS,
    COALESCE(dpa.phi_access_count, 0)                       AS PHI_ACCESS_COUNT,
    COALESCE(ca.confidential_access_count, 0)               AS CONFIDENTIAL_ACCESS_COUNT,
    COALESCE(fl.failed_login_count, 0)                      AS FAILED_LOGINS,
    (
        CASE WHEN au.USER_NAME IS NOT NULL THEN au.risk_points ELSE 0 END +
        CASE WHEN pe.USER_NAME IS NOT NULL THEN pe.risk_points ELSE 0 END +
        CASE WHEN dpa.USER_NAME IS NOT NULL THEN dpa.risk_points ELSE 0 END +
        CASE WHEN ca.USER_NAME IS NOT NULL THEN ca.risk_points ELSE 0 END +
        CASE WHEN fl.USER_NAME IS NOT NULL THEN fl.risk_points ELSE 0 END
    )                                                       AS RISK_SCORE,
    CASE
        WHEN (CASE WHEN au.USER_NAME IS NOT NULL THEN 50 ELSE 0 END +
              CASE WHEN pe.USER_NAME IS NOT NULL THEN 30 ELSE 0 END +
              CASE WHEN dpa.USER_NAME IS NOT NULL THEN 25 ELSE 0 END +
              CASE WHEN ca.USER_NAME IS NOT NULL THEN 40 ELSE 0 END +
              CASE WHEN fl.USER_NAME IS NOT NULL THEN 20 ELSE 0 END) >= 101 THEN 'CRITICAL'
        WHEN (CASE WHEN au.USER_NAME IS NOT NULL THEN 50 ELSE 0 END +
              CASE WHEN pe.USER_NAME IS NOT NULL THEN 30 ELSE 0 END +
              CASE WHEN dpa.USER_NAME IS NOT NULL THEN 25 ELSE 0 END +
              CASE WHEN ca.USER_NAME IS NOT NULL THEN 40 ELSE 0 END +
              CASE WHEN fl.USER_NAME IS NOT NULL THEN 20 ELSE 0 END) >= 51 THEN 'HIGH'
        WHEN (CASE WHEN au.USER_NAME IS NOT NULL THEN 50 ELSE 0 END +
              CASE WHEN pe.USER_NAME IS NOT NULL THEN 30 ELSE 0 END +
              CASE WHEN dpa.USER_NAME IS NOT NULL THEN 25 ELSE 0 END +
              CASE WHEN ca.USER_NAME IS NOT NULL THEN 40 ELSE 0 END +
              CASE WHEN fl.USER_NAME IS NOT NULL THEN 20 ELSE 0 END) >= 26 THEN 'MEDIUM'
        ELSE 'LOW'
    END                                                     AS RISK_LEVEL,
    CURRENT_TIMESTAMP()                                     AS SCORE_CALCULATED_AT
FROM all_users u
LEFT JOIN admin_usage au ON u.USER_NAME = au.USER_NAME
LEFT JOIN privilege_escalations pe ON u.USER_NAME = pe.USER_NAME
LEFT JOIN direct_phi_access dpa ON u.USER_NAME = dpa.USER_NAME
LEFT JOIN confidential_access ca ON u.USER_NAME = ca.USER_NAME
LEFT JOIN failed_logins fl ON u.USER_NAME = fl.USER_NAME
ORDER BY RISK_SCORE DESC;


-- ============================================================
-- SECTION 8: SECURITY GRANTS
-- ============================================================

GRANT SELECT ON ALL VIEWS IN SCHEMA HEALTH_GOVERNANCE_DB.MONITORING
    TO ROLE HEALTH_DATA_ADMIN;

GRANT SELECT ON ALL VIEWS IN SCHEMA HEALTH_GOVERNANCE_DB.MONITORING
    TO ROLE HEALTH_ML_ADMIN;

GRANT SELECT ON FUTURE VIEWS IN SCHEMA HEALTH_GOVERNANCE_DB.MONITORING
    TO ROLE HEALTH_DATA_ADMIN;

GRANT SELECT ON FUTURE VIEWS IN SCHEMA HEALTH_GOVERNANCE_DB.MONITORING
    TO ROLE HEALTH_ML_ADMIN;


-- ============================================================
-- SECTION 9: VERIFICATION
-- ============================================================

SHOW VIEWS IN SCHEMA HEALTH_GOVERNANCE_DB.MONITORING;

SHOW GRANTS TO ROLE HEALTH_DATA_ADMIN;


-- ============================================================
-- PHASE 09 COMPLETE
-- ============================================================
/*
================================================================================
Enterprise Audit & Compliance Framework deployed with:

SECURITY EVENT VIEWS (3):
  - V_LOGIN_HISTORY
  - V_ROLE_GRANT_HISTORY
  - V_PRIVILEGE_ESCALATION_EVENTS

PHI DATA ACCESS VIEWS (4):
  - V_PHI_DATA_ACCESS (tag-based)
  - V_PHI_ACCESS_LOG (ACCESS_HISTORY based)
  - V_MASKING_POLICY_USAGE
  - V_ROW_ACCESS_POLICY_USAGE

GOVERNANCE CHANGE VIEWS (2):
  - V_TAG_CHANGE_HISTORY
  - V_POLICY_CHANGE_HISTORY

USER & SESSION VIEWS (4):
  - V_USER_INVENTORY (with dormancy + MFA status)
  - V_SESSION_HISTORY
  - V_ADMIN_ACTIVITY
  - V_DDL_CHANGE_LOG

RETENTION COMPLIANCE (1):
  - V_RETENTION_COMPLIANCE_STATUS

RISK SCORING (1):
  - V_SECURITY_RISK_SCORE

TOTAL VIEWS: 15

ACCESS GRANTED TO:
  - HEALTH_DATA_ADMIN
  - HEALTH_ML_ADMIN

HIPAA COMPLIANCE ADDRESSED:
  - § 164.312(b): Audit controls (login, access, DDL)
  - § 164.308(a)(1)(ii)(D): Information system activity review
  - § 164.312(a): Access control (user inventory, privilege escalation)
  - HITECH: Breach notification evidence (PHI access, risk score)
  - CMS CoP: Medical records access documentation

NEXT STEPS:
  1. Configure alerting on CRITICAL risk score users
  2. Schedule quarterly compliance reviews
  3. Integrate with SIEM if applicable
  4. Create Streamlit dashboard for security monitoring
================================================================================
*/

SELECT '============================================' AS separator
UNION ALL
SELECT '  PHASE 09: AUDIT & COMPLIANCE COMPLETE'
UNION ALL
SELECT '  15 Audit Views + Risk Scoring'
UNION ALL
SELECT '  Health Domain - Healthcare Platform'
UNION ALL
SELECT '  Proceed to Phase 10: Verification'
UNION ALL
SELECT '============================================';

-- ============================================================
-- END OF PHASE 09: AUDIT & COMPLIANCE
-- ============================================================
