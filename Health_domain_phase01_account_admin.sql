-- ============================================================
-- HEALTH_DOMAIN - SNOWFLAKE DATA PLATFORM
-- ============================================================
-- Phase 01: Account Administration
-- Script: 01_account_administration.sql
-- Version: 2.0.0
--
-- Change Reason: Configured for Healthcare & Life Sciences domain
--               (Cardiac Rehabilitation, EHR, Clinical Analytics)
--               HEALTH_GOVERNANCE_DB.SECURITY schema created as Phase 01
--               bootstrap prerequisite for security policy objects.
--               All remaining governance schemas (POLICIES, TAGS,
--               DATA_QUALITY, AUDIT) are created in Phase 04.
--
-- Description:
--   Configures account-level security settings for a HIPAA/HITECH/CMS
--   compliant healthcare Snowflake environment. Creates
--   HEALTH_GOVERNANCE_DB and HEALTH_GOVERNANCE_DB.SECURITY as a bootstrap
--   step — these are required by Phase 01 to house security policy
--   objects before any other phase runs. Phase 04 completes the full
--   governance database structure.
--
-- Scope: Healthcare data across 4 domains (EHR, CARDIAC_REHAB,
--        CLAIMS, LAB_VITALS) supporting Medallion Architecture
--
-- Prerequisites:
--   - Must be executed as ACCOUNTADMIN
--   - Snowflake Enterprise Edition or higher
--   - Appropriate BAA (Business Associate Agreement) in place
--
-- Execution Order:
--   Phase 01 (this file) → Phase 02 → Phase 03 → Phase 04 → Phase 05
--
-- !! WARNING !!
--   This script configures ACCOUNT-LEVEL settings affecting ALL users.
--   Network policy misconfiguration can lock out all users.
--   HEALTH_GOVERNANCE_DB.SECURITY is created here as a bootstrap
--   prerequisite only. Do not add non-security objects to this schema.
--   All other governance schemas are managed exclusively by Phase 04.
--
-- Regulatory Framework:
--   - HIPAA (Health Insurance Portability and Accountability Act) - PHI protection
--   - HITECH Act - EHR technology and breach notification
--   - CMS Conditions of Participation - Healthcare program compliance
--   - AACVPR Standards - Cardiac rehabilitation certification
--   - 42 CFR Part 2 - Substance abuse records confidentiality
--
-- Author: Health Domain Platform Team
-- Date: 2026-04-22
-- ============================================================

USE ROLE ACCOUNTADMIN;

-- ============================================================
-- SECTION 1: GOVERNANCE DATABASE BOOTSTRAP
-- ============================================================
-- HEALTH_GOVERNANCE_DB and its SECURITY schema are created
-- here as a Phase 01 bootstrap prerequisite ONLY.
--
-- Reason: Password policies, session policies, and network rules
-- must live in a named schema. These objects are required by
-- Phase 01 and must exist before any other phase runs.
--
-- Phase 04 will create the remaining governance schemas:
--   HEALTH_GOVERNANCE_DB.POLICIES
--   HEALTH_GOVERNANCE_DB.TAGS
--   HEALTH_GOVERNANCE_DB.DATA_QUALITY
--   HEALTH_GOVERNANCE_DB.AUDIT
--   HEALTH_GOVERNANCE_DB.MONITORS
--
-- Do NOT create any non-security objects in this schema.
-- Do NOT create any other schemas in HEALTH_GOVERNANCE_DB here.
-- ============================================================

CREATE DATABASE IF NOT EXISTS HEALTH_GOVERNANCE_DB
    DATA_RETENTION_TIME_IN_DAYS = 90
    COMMENT = 'Central governance database for Health Domain Platform. Houses security policies (Phase 01), data governance policies, tags, data quality rules, monitoring views, and audit logs (Phase 04). Supports HIPAA/HITECH/CMS compliance requirements for healthcare services.';

CREATE SCHEMA IF NOT EXISTS HEALTH_GOVERNANCE_DB.SECURITY
    COMMENT = 'Bootstrap schema created in Phase 01. Houses account-level security objects: network rules, password policies, session policies. Created before all other phases as a prerequisite for policy application. Managed by ACCOUNTADMIN and HEALTH_ADMIN.';

-- Verification
SHOW SCHEMAS IN DATABASE HEALTH_GOVERNANCE_DB;

-- ============================================================
-- SECTION 2: NETWORK POLICY
-- ============================================================
-- Regulatory Reference: HIPAA § 164.312(e)(1) - Transmission Security
--                      HITECH Act - Access Controls
-- Restricts Snowflake access to approved IP ranges only.
-- All connections from outside approved ranges are rejected.
-- Critical for protecting PHI (Protected Health Information),
-- patient records, cardiac rehab data, and clinical notes.
-- ============================================================

-- !! PLACEHOLDER IP - Replace before production !!
-- Production should include:
--   - Hospital/clinic network IPs
--   - VPN gateway endpoints for remote clinicians
--   - CI/CD runner IPs (GitHub Actions, Azure DevOps)
--   - Approved EHR vendor IPs (Epic, Cerner feeds)
--   - Cloud service provider NAT gateways
--   - Telehealth platform IPs
ALTER ACCOUNT UNSET NETWORK_POLICY;
DROP NETWORK POLICY IF EXISTS HEALTH_DOMAIN_NETWORK_POLICY;

CREATE OR REPLACE NETWORK RULE HEALTH_GOVERNANCE_DB.SECURITY.HEALTH_ALLOWED_IPS
    TYPE = IPV4
    VALUE_LIST = ('0.0.0.0/0')
    MODE = INGRESS
    COMMENT = 'PLACEHOLDER - Replace with production IP ranges before go-live. Should include: hospital network IPs, VPN gateway IPs, clinical workstation subnets, EHR vendor IPs (Epic/Cerner), CI/CD runner IPs, cloud NAT gateway IPs, telehealth platform IPs.';

CREATE OR REPLACE NETWORK POLICY HEALTH_DOMAIN_NETWORK_POLICY
    ALLOWED_NETWORK_RULE_LIST = ('HEALTH_GOVERNANCE_DB.SECURITY.HEALTH_ALLOWED_IPS')
    COMMENT = 'Primary account-level network policy per HIPAA § 164.312(e)(1) Transmission Security and HITECH access control requirements. Applied at account level — affects all users, service accounts, and API connections.';

-- Apply network policy at account level
ALTER ACCOUNT SET NETWORK_POLICY = HEALTH_DOMAIN_NETWORK_POLICY;

-- Verification
SHOW NETWORK POLICIES LIKE 'HEALTH%';

-- ============================================================
-- SECTION 3: PASSWORD POLICY
-- ============================================================
-- Regulatory Reference: HIPAA § 164.312(d) - Person or Entity Authentication
--                      HIPAA § 164.312(a)(1) - Access Control
--                      HITECH Act - Meaningful Use Security
-- Enforces strong password requirements for all human users.
-- Note: Service accounts (SVC_ETL_HEALTH, SVC_EHR_FEEDS)
-- should use key-pair authentication and bypass password policy.
-- ============================================================

ALTER ACCOUNT UNSET PASSWORD POLICY;

CREATE OR REPLACE PASSWORD POLICY HEALTH_GOVERNANCE_DB.SECURITY.HEALTH_PASSWORD_POLICY
    PASSWORD_MIN_LENGTH = 14
    PASSWORD_MAX_LENGTH = 256
    PASSWORD_MIN_UPPER_CASE_CHARS = 2
    PASSWORD_MIN_LOWER_CASE_CHARS = 2
    PASSWORD_MIN_NUMERIC_CHARS = 2
    PASSWORD_MIN_SPECIAL_CHARS = 2
    PASSWORD_MIN_AGE_DAYS = 1
    PASSWORD_MAX_AGE_DAYS = 90
    PASSWORD_MAX_RETRIES = 5
    PASSWORD_LOCKOUT_TIME_MINS = 30
    PASSWORD_HISTORY = 12
    COMMENT = 'Healthcare compliant password policy (HIPAA/HITECH): 14+ chars, mixed case required, numeric and special chars required, 90-day expiry, 12-password history, 30-min lockout after 5 failed attempts. Applied at account level. Exceeds industry baseline for healthcare platforms handling PHI.';

-- Apply password policy at account level
ALTER ACCOUNT SET PASSWORD POLICY HEALTH_GOVERNANCE_DB.SECURITY.HEALTH_PASSWORD_POLICY;

-- Verification
DESCRIBE PASSWORD POLICY HEALTH_GOVERNANCE_DB.SECURITY.HEALTH_PASSWORD_POLICY;

-- ============================================================
-- SECTION 4: SESSION POLICY
-- ============================================================
-- Regulatory Reference: HIPAA § 164.312(a)(2)(iii) - Automatic Logoff
--                      HITECH Act - EHR Security Requirements
--                      CMS Conditions of Participation
-- Forces session termination after period of inactivity.
-- Prevents unauthorized access from unattended workstations.
-- Critical for clinical workstations, nursing stations,
-- and cardiac rehab therapy terminals.
-- ============================================================

ALTER ACCOUNT UNSET SESSION POLICY;

CREATE OR REPLACE SESSION POLICY HEALTH_GOVERNANCE_DB.SECURITY.HEALTH_SESSION_POLICY
    SESSION_IDLE_TIMEOUT_MINS = 30
    SESSION_UI_IDLE_TIMEOUT_MINS = 15
    COMMENT = '30-minute programmatic / 15-minute UI idle timeout per HIPAA § 164.312(a)(2)(iii) Automatic Logoff. Shorter UI timeout due to clinical workstation exposure to PHI (patient records, cardiac telemetry, lab results). Applies to all interactive sessions including Snowsight UI, BI tools, and programmatic connections.';

-- Apply session policy at account level
ALTER ACCOUNT SET SESSION POLICY HEALTH_GOVERNANCE_DB.SECURITY.HEALTH_SESSION_POLICY;

-- Verification
DESCRIBE SESSION POLICY HEALTH_GOVERNANCE_DB.SECURITY.HEALTH_SESSION_POLICY;

-- ============================================================
-- SECTION 5: ACCOUNT PARAMETERS
-- ============================================================
-- Account-level configuration for performance, security,
-- and compliance. These settings apply to all users,
-- warehouses, and workloads across the entire account.
-- Optimized for healthcare / clinical data workloads.
-- ============================================================

-- Timezone: Eastern Time (US healthcare standard / CMS reporting)
-- Most US hospital systems and CMS reporting use Eastern Time
ALTER ACCOUNT SET TIMEZONE = 'America/New_York';

-- Query execution limits: prevent runaway queries
-- Clinical analytics and ML feature engineering can be complex
-- 1 hour max execution, 30 min queue timeout
ALTER ACCOUNT SET STATEMENT_TIMEOUT_IN_SECONDS = 3600;
ALTER ACCOUNT SET STATEMENT_QUEUED_TIMEOUT_IN_SECONDS = 1800;

-- Data retention defaults: 30-day account default, 14-day minimum
-- HIPAA requires 6-year retention for certain records
-- Individual databases override this based on data classification:
--   HEALTH_RAW_DB: 7 days | HEALTH_TRANSFORM_DB: 14 days
--   HEALTH_ANALYTICS_DB: 30 days | HEALTH_AI_READY_DB: 30 days
--   HEALTH_GOVERNANCE_DB: 90 days (audit trails)
ALTER ACCOUNT SET DATA_RETENTION_TIME_IN_DAYS = 30;
ALTER ACCOUNT SET MIN_DATA_RETENTION_TIME_IN_DAYS = 14;

-- Storage integration requirement: prevents ad-hoc external stage creation
-- All external stages must use a governed storage integration object
-- Critical for controlling EHR data feeds and external clinical data sources
ALTER ACCOUNT SET REQUIRE_STORAGE_INTEGRATION_FOR_STAGE_CREATION = TRUE;
ALTER ACCOUNT SET REQUIRE_STORAGE_INTEGRATION_FOR_STAGE_OPERATION = TRUE;

-- Encryption: automatic periodic re-keying of all data at rest
-- HIPAA § 164.312(a)(2)(iv) encryption requirement for PHI at rest
ALTER ACCOUNT SET PERIODIC_DATA_REKEYING = TRUE;

-- OAuth security: blocks privileged roles from OAuth token escalation
-- Prevents unauthorized role elevation through OAuth flows
ALTER ACCOUNT SET OAUTH_ADD_PRIVILEGED_ROLES_TO_BLOCKED_LIST = TRUE;
ALTER ACCOUNT SET EXTERNAL_OAUTH_ADD_PRIVILEGED_ROLES_TO_BLOCKED_LIST = TRUE;

-- Login: enables username-first login flow for MFA compatibility
-- MFA is required for HIPAA-compliant access to PHI
ALTER ACCOUNT SET ENABLE_IDENTIFIER_FIRST_LOGIN = TRUE;

-- Verification
SELECT 'Account Parameters Configured' AS status;
SHOW PARAMETERS LIKE 'TIMEZONE' IN ACCOUNT;
SHOW PARAMETERS LIKE 'STATEMENT_TIMEOUT%' IN ACCOUNT;
SHOW PARAMETERS LIKE 'DATA_RETENTION%' IN ACCOUNT;
SHOW PARAMETERS LIKE 'PERIODIC_DATA_REKEYING' IN ACCOUNT;
SHOW PARAMETERS LIKE 'REQUIRE_STORAGE_INTEGRATION%' IN ACCOUNT;

-- ============================================================
-- SECTION 6: RESOURCE MONITORS (Cost Control)
-- ============================================================
-- Healthcare platforms require strict cost controls and budget
-- management. Resource monitors prevent runaway costs and
-- provide visibility into credit consumption across
-- clinical, analytical, and AI workloads.
-- ============================================================

-- Account-level resource monitor (overall budget ceiling)
CREATE OR REPLACE RESOURCE MONITOR HEALTH_ACCOUNT_MONITOR
    WITH CREDIT_QUOTA = 500
    FREQUENCY = MONTHLY
    START_TIMESTAMP = IMMEDIATELY
    TRIGGERS
        ON 50 PERCENT DO NOTIFY
        ON 75 PERCENT DO NOTIFY
        ON 90 PERCENT DO NOTIFY
        ON 100 PERCENT DO SUSPEND
        ON 110 PERCENT DO SUSPEND_IMMEDIATE;

ALTER ACCOUNT SET RESOURCE_MONITOR = HEALTH_ACCOUNT_MONITOR;

-- Verification
SHOW RESOURCE MONITORS LIKE 'HEALTH%';

-- ============================================================
-- SECTION 7: PHASE 01 VERIFICATION & SUMMARY
-- ============================================================

-- Final verification of all Phase 01 objects
SELECT '========== PHASE 01 VERIFICATION ==========' AS section;

-- Check database exists
SELECT 'DATABASE CHECK' AS check_type,
       DATABASE_NAME,
       CREATED,
       COMMENT
FROM SNOWFLAKE.ACCOUNT_USAGE.DATABASES
WHERE DATABASE_NAME = 'HEALTH_GOVERNANCE_DB'
  AND DELETED IS NULL;

-- Check schema exists
SELECT 'SCHEMA CHECK' AS check_type,
       CATALOG_NAME AS database_name,
       SCHEMA_NAME,
       CREATED
FROM SNOWFLAKE.ACCOUNT_USAGE.SCHEMATA
WHERE CATALOG_NAME = 'HEALTH_GOVERNANCE_DB'
  AND SCHEMA_NAME = 'SECURITY'
  AND DELETED IS NULL;

-- Check policies exist
SHOW PASSWORD POLICIES IN SCHEMA HEALTH_GOVERNANCE_DB.SECURITY;
SHOW SESSION POLICIES IN SCHEMA HEALTH_GOVERNANCE_DB.SECURITY;
SHOW NETWORK RULES IN SCHEMA HEALTH_GOVERNANCE_DB.SECURITY;
SHOW NETWORK POLICIES LIKE 'HEALTH%';
SHOW RESOURCE MONITORS LIKE 'HEALTH%';

-- ============================================================
-- SECTION 8: PHASE 01 SUMMARY
-- ============================================================
--
-- BOOTSTRAP OBJECTS CREATED:
--   DATABASE : HEALTH_GOVERNANCE_DB
--   SCHEMA   : HEALTH_GOVERNANCE_DB.SECURITY
--
-- NOTE: Remaining HEALTH_GOVERNANCE_DB schemas are created
--       in Phase 04 (POLICIES, TAGS, DATA_QUALITY, AUDIT, MONITORS).
--
-- SECURITY OBJECTS CREATED:
--   NETWORK RULE    : HEALTH_GOVERNANCE_DB.SECURITY.HEALTH_ALLOWED_IPS
--   NETWORK POLICY  : HEALTH_DOMAIN_NETWORK_POLICY (applied at account level)
--   PASSWORD POLICY : HEALTH_GOVERNANCE_DB.SECURITY.HEALTH_PASSWORD_POLICY (applied)
--   SESSION POLICY  : HEALTH_GOVERNANCE_DB.SECURITY.HEALTH_SESSION_POLICY (applied)
--   RESOURCE MONITOR: HEALTH_ACCOUNT_MONITOR
--
-- ACCOUNT PARAMETERS CONFIGURED: 11
--   TIMEZONE                                         = America/New_York
--   STATEMENT_TIMEOUT_IN_SECONDS                     = 3600
--   STATEMENT_QUEUED_TIMEOUT_IN_SECONDS              = 1800
--   DATA_RETENTION_TIME_IN_DAYS                      = 30
--   MIN_DATA_RETENTION_TIME_IN_DAYS                  = 14
--   REQUIRE_STORAGE_INTEGRATION_FOR_STAGE_CREATION  = TRUE
--   REQUIRE_STORAGE_INTEGRATION_FOR_STAGE_OPERATION = TRUE
--   PERIODIC_DATA_REKEYING                           = TRUE
--   OAUTH_ADD_PRIVILEGED_ROLES_TO_BLOCKED_LIST       = TRUE
--   EXTERNAL_OAUTH_ADD_PRIVILEGED_ROLES_TO_BLOCKED_LIST = TRUE
--   ENABLE_IDENTIFIER_FIRST_LOGIN                    = TRUE
--
-- REGULATORY COMPLIANCE:
--   - HIPAA § 164.312 - Technical safeguards (access, audit, integrity, transmission)
--   - HIPAA § 164.310 - Physical safeguards (workstation security)
--   - HITECH Act - Breach notification, EHR security requirements
--   - CMS Conditions of Participation - Healthcare program compliance
--   - AACVPR Standards - Cardiac rehabilitation certification requirements
--   - 42 CFR Part 2 - Substance abuse records confidentiality
--
-- PHASE 02 DEPENDENCIES:
--   - HEALTH_GOVERNANCE_DB exists for role grant references
--   - HEALTH_GOVERNANCE_DB.SECURITY exists for policy references
--   - HEALTH_PASSWORD_POLICY exists for user account setup
--   - Network policy applied — ensure CI/CD runner IPs and
--     EHR vendor IPs (Epic/Cerner) are whitelisted before
--     executing Phase 02 and beyond
--
-- ============================================================
-- ROLLBACK COMMANDS (run only if needed before Phase 02)
-- ============================================================
-- USE ROLE ACCOUNTADMIN;
--
-- ALTER ACCOUNT UNSET NETWORK_POLICY;
-- DROP NETWORK POLICY IF EXISTS HEALTH_DOMAIN_NETWORK_POLICY;
-- DROP NETWORK RULE IF EXISTS HEALTH_GOVERNANCE_DB.SECURITY.HEALTH_ALLOWED_IPS;
--
-- ALTER ACCOUNT UNSET PASSWORD POLICY;
-- DROP PASSWORD POLICY IF EXISTS HEALTH_GOVERNANCE_DB.SECURITY.HEALTH_PASSWORD_POLICY;
--
-- ALTER ACCOUNT UNSET SESSION POLICY;
-- DROP SESSION POLICY IF EXISTS HEALTH_GOVERNANCE_DB.SECURITY.HEALTH_SESSION_POLICY;
--
-- DROP RESOURCE MONITOR IF EXISTS HEALTH_ACCOUNT_MONITOR;
--
-- ALTER ACCOUNT UNSET RESOURCE_MONITOR;
--
-- DROP SCHEMA IF EXISTS HEALTH_GOVERNANCE_DB.SECURITY;
-- DROP DATABASE IF EXISTS HEALTH_GOVERNANCE_DB;
--
-- ALTER ACCOUNT SET TIMEZONE = 'America/Los_Angeles';
-- ALTER ACCOUNT SET DATA_RETENTION_TIME_IN_DAYS = 1;
-- ALTER ACCOUNT SET MIN_DATA_RETENTION_TIME_IN_DAYS = 0;
-- ============================================================

SELECT '============================================' AS separator
UNION ALL
SELECT '  PHASE 01: ACCOUNT ADMINISTRATION COMPLETE'
UNION ALL
SELECT '  Health Domain - Healthcare Platform'
UNION ALL
SELECT '  Proceed to Phase 02: RBAC Setup'
UNION ALL
SELECT '============================================';

-- ============================================================
-- END OF PHASE 01: ACCOUNT ADMINISTRATION
-- ============================================================
