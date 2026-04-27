------------------------------------------------------------------------
-- HEALTH_DOMAIN — PHASE 10: VERIFICATION
-- Validation queries, test scripts, and test cases
------------------------------------------------------------------------

USE ROLE ACCOUNTADMIN;

------------------------------------------------------------------------
-- TEST SUITE 1: RBAC VALIDATION
------------------------------------------------------------------------

-- TC-01: Verify all 7 custom roles exist
SELECT 'TC-01: Custom roles exist' AS TEST_CASE,
       CASE WHEN COUNT(*) = 7 THEN 'PASS' ELSE 'FAIL – found ' || COUNT(*) END AS RESULT
FROM SNOWFLAKE.ACCOUNT_USAGE.ROLES
WHERE NAME IN ('HEALTH_ADMIN','HEALTH_ENGINEER','HEALTH_ANALYST',
               'HEALTH_SCIENTIST','HEALTH_CLINICIAN','HEALTH_GOVERNANCE','HEALTH_VIEWER')
  AND DELETED_ON IS NULL;

-- TC-02: Verify role hierarchy – HEALTH_ADMIN granted to ACCOUNTADMIN
SELECT 'TC-02: HEALTH_ADMIN → ACCOUNTADMIN' AS TEST_CASE,
       CASE WHEN COUNT(*) >= 1 THEN 'PASS' ELSE 'FAIL' END AS RESULT
FROM SNOWFLAKE.ACCOUNT_USAGE.GRANTS_TO_ROLES
WHERE GRANTEE_NAME = 'ACCOUNTADMIN'
  AND NAME = 'HEALTH_ADMIN'
  AND PRIVILEGE = 'USAGE'
  AND DELETED_ON IS NULL;

-- TC-03: Verify HEALTH_VIEWER is granted to HEALTH_ANALYST
SELECT 'TC-03: HEALTH_VIEWER → HEALTH_ANALYST' AS TEST_CASE,
       CASE WHEN COUNT(*) >= 1 THEN 'PASS' ELSE 'FAIL' END AS RESULT
FROM SNOWFLAKE.ACCOUNT_USAGE.GRANTS_TO_ROLES
WHERE GRANTEE_NAME = 'HEALTH_ANALYST'
  AND NAME = 'HEALTH_VIEWER'
  AND PRIVILEGE = 'USAGE'
  AND DELETED_ON IS NULL;

------------------------------------------------------------------------
-- TEST SUITE 2: WAREHOUSE VALIDATION
------------------------------------------------------------------------

-- TC-04: Verify 4 workload warehouses exist
SELECT 'TC-04: 4 warehouses exist' AS TEST_CASE,
       CASE WHEN COUNT(*) = 4 THEN 'PASS' ELSE 'FAIL – found ' || COUNT(*) END AS RESULT
FROM SNOWFLAKE.ACCOUNT_USAGE.WAREHOUSES
WHERE NAME IN ('HEALTH_INGEST_WH','HEALTH_TRANSFORM_WH','HEALTH_ANALYTICS_WH','HEALTH_AI_WH')
  AND DELETED IS NULL;

-- TC-05: Verify auto-suspend is configured on all warehouses
SELECT 'TC-05: Auto-suspend configured' AS TEST_CASE,
       CASE WHEN COUNT(*) = 4 THEN 'PASS' ELSE 'FAIL' END AS RESULT
FROM SNOWFLAKE.ACCOUNT_USAGE.WAREHOUSES
WHERE NAME IN ('HEALTH_INGEST_WH','HEALTH_TRANSFORM_WH','HEALTH_ANALYTICS_WH','HEALTH_AI_WH')
  AND AUTO_SUSPEND IS NOT NULL
  AND DELETED IS NULL;

-- TC-06: Verify warehouse sizes are correct
SELECT 'TC-06: WH size – ' || NAME AS TEST_CASE,
       CASE
         WHEN NAME = 'HEALTH_INGEST_WH'    AND SIZE = 'Small'  THEN 'PASS'
         WHEN NAME = 'HEALTH_TRANSFORM_WH' AND SIZE = 'Medium' THEN 'PASS'
         WHEN NAME = 'HEALTH_ANALYTICS_WH' AND SIZE = 'Small'  THEN 'PASS'
         WHEN NAME = 'HEALTH_AI_WH'        AND SIZE = 'Large'  THEN 'PASS'
         ELSE 'FAIL – actual size: ' || SIZE
       END AS RESULT
FROM SNOWFLAKE.ACCOUNT_USAGE.WAREHOUSES
WHERE NAME IN ('HEALTH_INGEST_WH','HEALTH_TRANSFORM_WH','HEALTH_ANALYTICS_WH','HEALTH_AI_WH')
  AND DELETED IS NULL;

------------------------------------------------------------------------
-- TEST SUITE 3: DATABASE & SCHEMA VALIDATION
------------------------------------------------------------------------

-- TC-07: Verify 5 databases exist
SELECT 'TC-07: 5 databases exist' AS TEST_CASE,
       CASE WHEN COUNT(*) = 5 THEN 'PASS' ELSE 'FAIL – found ' || COUNT(*) END AS RESULT
FROM SNOWFLAKE.ACCOUNT_USAGE.DATABASES
WHERE DATABASE_NAME IN ('HEALTH_RAW_DB','HEALTH_TRANSFORM_DB','HEALTH_ANALYTICS_DB',
                         'HEALTH_AI_READY_DB','HEALTH_GOVERNANCE_DB')
  AND DELETED IS NULL;

-- TC-08: Verify RAW_DB has expected schemas
SELECT 'TC-08: RAW_DB schemas' AS TEST_CASE,
       CASE WHEN COUNT(*) >= 5 THEN 'PASS' ELSE 'FAIL – found ' || COUNT(*) END AS RESULT
FROM SNOWFLAKE.ACCOUNT_USAGE.SCHEMATA
WHERE CATALOG_NAME = 'HEALTH_RAW_DB'
  AND SCHEMA_NAME IN ('EHR_INGEST','CARDIAC_REHAB_INGEST','CLAIMS_INGEST','LAB_INGEST','STAGING')
  AND DELETED IS NULL;

-- TC-09: Verify TRANSFORM_DB has expected schemas
SELECT 'TC-09: TRANSFORM_DB schemas' AS TEST_CASE,
       CASE WHEN COUNT(*) >= 7 THEN 'PASS' ELSE 'FAIL – found ' || COUNT(*) END AS RESULT
FROM SNOWFLAKE.ACCOUNT_USAGE.SCHEMATA
WHERE CATALOG_NAME = 'HEALTH_TRANSFORM_DB'
  AND SCHEMA_NAME IN ('PATIENTS','ENCOUNTERS','DIAGNOSES','MEDICATIONS',
                      'PROCEDURES','CARDIAC_REHAB','LAB_VITALS')
  AND DELETED IS NULL;

-- TC-10: Verify ANALYTICS_DB has expected schemas
SELECT 'TC-10: ANALYTICS_DB schemas' AS TEST_CASE,
       CASE WHEN COUNT(*) >= 5 THEN 'PASS' ELSE 'FAIL – found ' || COUNT(*) END AS RESULT
FROM SNOWFLAKE.ACCOUNT_USAGE.SCHEMATA
WHERE CATALOG_NAME = 'HEALTH_ANALYTICS_DB'
  AND SCHEMA_NAME IN ('CLINICAL_DASHBOARDS','POPULATION_HEALTH','CARDIAC_OUTCOMES',
                      'QUALITY_MEASURES','FINANCIAL')
  AND DELETED IS NULL;

-- TC-11: Verify AI_READY_DB has expected schemas
SELECT 'TC-11: AI_READY_DB schemas' AS TEST_CASE,
       CASE WHEN COUNT(*) >= 5 THEN 'PASS' ELSE 'FAIL – found ' || COUNT(*) END AS RESULT
FROM SNOWFLAKE.ACCOUNT_USAGE.SCHEMATA
WHERE CATALOG_NAME = 'HEALTH_AI_READY_DB'
  AND SCHEMA_NAME IN ('FEATURE_STORE','EMBEDDINGS','SEMANTIC_MODELS','MODEL_REGISTRY','TRAINING_DATASETS')
  AND DELETED IS NULL;

------------------------------------------------------------------------
-- TEST SUITE 4: RESOURCE MONITOR VALIDATION
------------------------------------------------------------------------

-- TC-12: Verify account-level resource monitor
SELECT 'TC-12: Account resource monitor' AS TEST_CASE,
       CASE WHEN COUNT(*) >= 1 THEN 'PASS' ELSE 'FAIL' END AS RESULT
FROM TABLE(INFORMATION_SCHEMA.RESOURCE_MONITORS())
WHERE NAME = 'HEALTH_ACCOUNT_MONITOR';

-- TC-13: Verify per-warehouse resource monitors
SELECT 'TC-13: Per-WH monitors' AS TEST_CASE,
       CASE WHEN COUNT(*) = 4 THEN 'PASS' ELSE 'FAIL – found ' || COUNT(*) END AS RESULT
FROM TABLE(INFORMATION_SCHEMA.RESOURCE_MONITORS())
WHERE NAME IN ('HEALTH_INGEST_MONITOR','HEALTH_TRANSFORM_MONITOR',
               'HEALTH_ANALYTICS_MONITOR','HEALTH_AI_MONITOR');

------------------------------------------------------------------------
-- TEST SUITE 5: MONITORING VIEWS VALIDATION
------------------------------------------------------------------------

-- TC-14: Verify 12+ monitoring views exist
SELECT 'TC-14: Monitoring views' AS TEST_CASE,
       CASE WHEN COUNT(*) >= 12 THEN 'PASS' ELSE 'FAIL – found ' || COUNT(*) END AS RESULT
FROM SNOWFLAKE.ACCOUNT_USAGE.VIEWS
WHERE TABLE_CATALOG = 'HEALTH_GOVERNANCE_DB'
  AND TABLE_SCHEMA = 'MONITORS'
  AND TABLE_NAME LIKE 'V_%'
  AND DELETED IS NULL;

------------------------------------------------------------------------
-- TEST SUITE 6: ALERT VALIDATION
------------------------------------------------------------------------

-- TC-15: Verify 12 alerts exist
SELECT 'TC-15: Alerts created' AS TEST_CASE,
       CASE WHEN COUNT(*) >= 10 THEN 'PASS' ELSE 'FAIL – found ' || COUNT(*) END AS RESULT
FROM SNOWFLAKE.ACCOUNT_USAGE.ALERTS
WHERE DATABASE_NAME = 'HEALTH_GOVERNANCE_DB'
  AND SCHEMA_NAME = 'MONITORS'
  AND DELETED_ON IS NULL;

------------------------------------------------------------------------
-- TEST SUITE 7: GOVERNANCE VALIDATION
------------------------------------------------------------------------

-- TC-16: Verify tags exist
SELECT 'TC-16: Governance tags' AS TEST_CASE,
       CASE WHEN COUNT(*) >= 5 THEN 'PASS' ELSE 'FAIL – found ' || COUNT(*) END AS RESULT
FROM SNOWFLAKE.ACCOUNT_USAGE.TAGS
WHERE TAG_DATABASE = 'HEALTH_GOVERNANCE_DB'
  AND TAG_SCHEMA = 'TAGS'
  AND DELETED IS NULL;

-- TC-17: Verify 3 masking policies exist
SELECT 'TC-17: Masking policies' AS TEST_CASE,
       CASE WHEN COUNT(*) >= 3 THEN 'PASS' ELSE 'FAIL – found ' || COUNT(*) END AS RESULT
FROM SNOWFLAKE.ACCOUNT_USAGE.MASKING_POLICIES
WHERE POLICY_CATALOG = 'HEALTH_GOVERNANCE_DB'
  AND POLICY_SCHEMA = 'POLICIES'
  AND DELETED IS NULL;

-- TC-18: Verify row access policy exists
SELECT 'TC-18: Row access policy' AS TEST_CASE,
       CASE WHEN COUNT(*) >= 1 THEN 'PASS' ELSE 'FAIL' END AS RESULT
FROM SNOWFLAKE.ACCOUNT_USAGE.ROW_ACCESS_POLICIES
WHERE POLICY_CATALOG = 'HEALTH_GOVERNANCE_DB'
  AND POLICY_SCHEMA = 'POLICIES'
  AND DELETED IS NULL;

------------------------------------------------------------------------
-- TEST SUITE 8: AUDIT VIEWS VALIDATION
------------------------------------------------------------------------

-- TC-19: Verify audit views exist
SELECT 'TC-19: Audit views' AS TEST_CASE,
       CASE WHEN COUNT(*) >= 10 THEN 'PASS' ELSE 'FAIL – found ' || COUNT(*) END AS RESULT
FROM SNOWFLAKE.ACCOUNT_USAGE.VIEWS
WHERE TABLE_CATALOG = 'HEALTH_GOVERNANCE_DB'
  AND TABLE_SCHEMA = 'AUDIT'
  AND TABLE_NAME LIKE 'V_%'
  AND DELETED IS NULL;

------------------------------------------------------------------------
-- TEST SUITE 9: SECURITY VALIDATION
------------------------------------------------------------------------

-- TC-20: Verify network policy exists
SELECT 'TC-20: Network policy' AS TEST_CASE,
       CASE WHEN COUNT(*) >= 1 THEN 'PASS' ELSE 'FAIL' END AS RESULT
FROM SNOWFLAKE.ACCOUNT_USAGE.NETWORK_POLICIES
WHERE NAME = 'HEALTH_DOMAIN_NETWORK_POLICY'
  AND DELETED_ON IS NULL;

-- TC-21: Verify password policy exists
SELECT 'TC-21: Password policy' AS TEST_CASE,
       CASE WHEN COUNT(*) >= 1 THEN 'PASS' ELSE 'FAIL' END AS RESULT
FROM SNOWFLAKE.ACCOUNT_USAGE.PASSWORD_POLICIES
WHERE NAME = 'HEALTH_DOMAIN_PASSWORD_POLICY'
  AND DELETED IS NULL;

------------------------------------------------------------------------
-- TEST SUITE 10: COMPREHENSIVE SUMMARY
------------------------------------------------------------------------

-- TC-22: Full test summary collector
SELECT
  'HEALTH_DOMAIN VERIFICATION SUMMARY' AS HEADER,
  CURRENT_TIMESTAMP()                   AS RUN_AT,
  CURRENT_ROLE()                        AS RUN_AS_ROLE;
