-- ============================================================
-- HEALTH_DOMAIN - WAREHOUSE MANAGEMENT
-- ============================================================
-- Phase 03: Warehouse Management (Simplified)
-- Script: 03_warehouse_management.sql
-- Version: 1.0.0
--
-- Description:
--   Creates 4 workload-specific warehouses for Healthcare
--   & Life Sciences Platform. Aligned with 7-role RBAC from Phase 02.
--
-- Warehouses: 4 (Only what's needed)
--   1. HEALTH_INGEST_WH    - Data loading (EHR feeds, claims, labs)
--   2. HEALTH_TRANSFORM_WH - ETL transformations
--   3. HEALTH_ANALYTICS_WH - BI, clinical dashboards, reports
--   4. HEALTH_AI_WH        - Machine learning workloads
--
-- Dependencies:
--   - Phase 01 completed
--   - Phase 02 completed (7 roles exist)
-- ============================================================

USE ROLE ACCOUNTADMIN;

-- ============================================================
-- SECTION 1: CREATE 4 WAREHOUSES
-- ============================================================

-- ------------------------------------------------------------
-- WAREHOUSE 1: HEALTH_INGEST_WH
-- Purpose: Data loading (EHR feeds, claims imports, lab results)
-- Users: HEALTH_DATA_ENGINEER, HEALTH_DATA_ADMIN
-- ------------------------------------------------------------
CREATE WAREHOUSE IF NOT EXISTS HEALTH_INGEST_WH
    WAREHOUSE_SIZE = 'SMALL'
    AUTO_SUSPEND = 60
    AUTO_RESUME = TRUE
    INITIALLY_SUSPENDED = TRUE
    MIN_CLUSTER_COUNT = 1
    MAX_CLUSTER_COUNT = 2
    SCALING_POLICY = 'ECONOMY'
    COMMENT = 'Data ingestion warehouse for EHR feeds, claims imports, lab results, cardiac rehab data. Small size - data loading is I/O bound. 1-min auto-suspend for cost savings.';

-- ------------------------------------------------------------
-- WAREHOUSE 2: HEALTH_TRANSFORM_WH
-- Purpose: ETL transformations, dbt, data pipelines
-- Users: HEALTH_DATA_ENGINEER, HEALTH_DATA_ADMIN
-- ------------------------------------------------------------
CREATE WAREHOUSE IF NOT EXISTS HEALTH_TRANSFORM_WH
    WAREHOUSE_SIZE = 'MEDIUM'
    AUTO_SUSPEND = 120
    AUTO_RESUME = TRUE
    INITIALLY_SUSPENDED = TRUE
    MIN_CLUSTER_COUNT = 1
    MAX_CLUSTER_COUNT = 3
    SCALING_POLICY = 'STANDARD'
    COMMENT = 'ETL transformation warehouse for clinical data pipelines. Medium size for compute-intensive transformations (ICD mapping, medication normalisation). 2-min auto-suspend.';

-- ------------------------------------------------------------
-- WAREHOUSE 3: HEALTH_ANALYTICS_WH
-- Purpose: BI queries, clinical dashboards, reports, Streamlit
-- Users: HEALTH_READONLY, HEALTH_ANALYST, HEALTH_APP_ADMIN, HEALTH_DATA_ADMIN
-- ------------------------------------------------------------
CREATE WAREHOUSE IF NOT EXISTS HEALTH_ANALYTICS_WH
    WAREHOUSE_SIZE = 'LARGE'
    AUTO_SUSPEND = 300
    AUTO_RESUME = TRUE
    INITIALLY_SUSPENDED = TRUE
    MIN_CLUSTER_COUNT = 1
    MAX_CLUSTER_COUNT = 4
    SCALING_POLICY = 'STANDARD'
    ENABLE_QUERY_ACCELERATION = TRUE
    QUERY_ACCELERATION_MAX_SCALE_FACTOR = 4
    COMMENT = 'Analytics warehouse for clinical BI, cardiac outcomes dashboards, Streamlit apps. Large size for fast query response. Query acceleration enabled.';

-- ------------------------------------------------------------
-- WAREHOUSE 4: HEALTH_AI_WH
-- Purpose: ML model training, feature engineering, predictions
-- Users: HEALTH_ML_ENGINEER, HEALTH_ML_ADMIN
-- ------------------------------------------------------------
CREATE WAREHOUSE IF NOT EXISTS HEALTH_AI_WH
    WAREHOUSE_SIZE = 'XLARGE'
    AUTO_SUSPEND = 600
    AUTO_RESUME = TRUE
    INITIALLY_SUSPENDED = TRUE
    MIN_CLUSTER_COUNT = 1
    MAX_CLUSTER_COUNT = 2
    SCALING_POLICY = 'ECONOMY'
    ENABLE_QUERY_ACCELERATION = TRUE
    QUERY_ACCELERATION_MAX_SCALE_FACTOR = 8
    COMMENT = 'ML warehouse for model training (mortality, readmission, drug rec), feature engineering, Cortex AI. X-Large for compute-intensive ML. 10-min auto-suspend for iterative work.';

-- VERIFICATION
SHOW WAREHOUSES LIKE 'HEALTH_%';


-- ============================================================
-- SECTION 2: RESOURCE MONITORS (Per-Warehouse)
-- ============================================================

-- Account-level monitor (created in Phase 01)
-- HEALTH_ACCOUNT_MONITOR already exists

-- Per-warehouse monitors
CREATE OR REPLACE RESOURCE MONITOR HEALTH_INGEST_MONITOR
    WITH CREDIT_QUOTA = 500
    FREQUENCY = MONTHLY
    START_TIMESTAMP = IMMEDIATELY
    TRIGGERS
        ON 75 PERCENT DO NOTIFY
        ON 90 PERCENT DO NOTIFY
        ON 100 PERCENT DO SUSPEND;

CREATE OR REPLACE RESOURCE MONITOR HEALTH_TRANSFORM_MONITOR
    WITH CREDIT_QUOTA = 1500
    FREQUENCY = MONTHLY
    START_TIMESTAMP = IMMEDIATELY
    TRIGGERS
        ON 50 PERCENT DO NOTIFY
        ON 75 PERCENT DO NOTIFY
        ON 90 PERCENT DO NOTIFY
        ON 100 PERCENT DO SUSPEND;

CREATE OR REPLACE RESOURCE MONITOR HEALTH_ANALYTICS_MONITOR
    WITH CREDIT_QUOTA = 2000
    FREQUENCY = MONTHLY
    START_TIMESTAMP = IMMEDIATELY
    TRIGGERS
        ON 50 PERCENT DO NOTIFY
        ON 75 PERCENT DO NOTIFY
        ON 90 PERCENT DO NOTIFY
        ON 100 PERCENT DO SUSPEND;

CREATE OR REPLACE RESOURCE MONITOR HEALTH_AI_MONITOR
    WITH CREDIT_QUOTA = 1000
    FREQUENCY = MONTHLY
    START_TIMESTAMP = IMMEDIATELY
    TRIGGERS
        ON 50 PERCENT DO NOTIFY
        ON 75 PERCENT DO NOTIFY
        ON 90 PERCENT DO NOTIFY
        ON 100 PERCENT DO SUSPEND;

-- Assign monitors to warehouses
ALTER WAREHOUSE HEALTH_INGEST_WH SET RESOURCE_MONITOR = HEALTH_INGEST_MONITOR;
ALTER WAREHOUSE HEALTH_TRANSFORM_WH SET RESOURCE_MONITOR = HEALTH_TRANSFORM_MONITOR;
ALTER WAREHOUSE HEALTH_ANALYTICS_WH SET RESOURCE_MONITOR = HEALTH_ANALYTICS_MONITOR;
ALTER WAREHOUSE HEALTH_AI_WH SET RESOURCE_MONITOR = HEALTH_AI_MONITOR;

-- VERIFICATION
SHOW RESOURCE MONITORS LIKE 'HEALTH_%';


-- ============================================================
-- SECTION 3: WAREHOUSE GRANTS TO 7 ROLES
-- ============================================================

-- ------------------------------------------------------------
-- HEALTH_INGEST_WH GRANTS
-- ------------------------------------------------------------
GRANT USAGE, OPERATE ON WAREHOUSE HEALTH_INGEST_WH TO ROLE HEALTH_DATA_ENGINEER;
GRANT ALL PRIVILEGES ON WAREHOUSE HEALTH_INGEST_WH TO ROLE HEALTH_DATA_ADMIN;

-- ------------------------------------------------------------
-- HEALTH_TRANSFORM_WH GRANTS
-- ------------------------------------------------------------
GRANT USAGE, OPERATE ON WAREHOUSE HEALTH_TRANSFORM_WH TO ROLE HEALTH_DATA_ENGINEER;
GRANT ALL PRIVILEGES ON WAREHOUSE HEALTH_TRANSFORM_WH TO ROLE HEALTH_DATA_ADMIN;

-- ------------------------------------------------------------
-- HEALTH_ANALYTICS_WH GRANTS
-- ------------------------------------------------------------
GRANT USAGE ON WAREHOUSE HEALTH_ANALYTICS_WH TO ROLE HEALTH_READONLY;
GRANT USAGE, OPERATE ON WAREHOUSE HEALTH_ANALYTICS_WH TO ROLE HEALTH_ANALYST;
GRANT USAGE, OPERATE ON WAREHOUSE HEALTH_ANALYTICS_WH TO ROLE HEALTH_APP_ADMIN;
GRANT USAGE ON WAREHOUSE HEALTH_ANALYTICS_WH TO ROLE HEALTH_DATA_ENGINEER;
GRANT USAGE ON WAREHOUSE HEALTH_ANALYTICS_WH TO ROLE HEALTH_ML_ENGINEER;
GRANT ALL PRIVILEGES ON WAREHOUSE HEALTH_ANALYTICS_WH TO ROLE HEALTH_DATA_ADMIN;

-- ------------------------------------------------------------
-- HEALTH_AI_WH GRANTS
-- ------------------------------------------------------------
GRANT USAGE, OPERATE ON WAREHOUSE HEALTH_AI_WH TO ROLE HEALTH_ML_ENGINEER;
GRANT USAGE ON WAREHOUSE HEALTH_AI_WH TO ROLE HEALTH_DATA_ENGINEER;
GRANT ALL PRIVILEGES ON WAREHOUSE HEALTH_AI_WH TO ROLE HEALTH_ML_ADMIN;


-- ============================================================
-- SECTION 4: VERIFICATION
-- ============================================================

-- Verify warehouses
SHOW WAREHOUSES LIKE 'HEALTH_%';

-- Verify grants
SHOW GRANTS ON WAREHOUSE HEALTH_INGEST_WH;
SHOW GRANTS ON WAREHOUSE HEALTH_TRANSFORM_WH;
SHOW GRANTS ON WAREHOUSE HEALTH_ANALYTICS_WH;
SHOW GRANTS ON WAREHOUSE HEALTH_AI_WH;

-- Verify resource monitors
SHOW RESOURCE MONITORS LIKE 'HEALTH_%';


-- ============================================================
-- SECTION 5: SUMMARY
-- ============================================================
/*
================================================================================
PHASE 03: WAREHOUSE MANAGEMENT - SUMMARY
================================================================================

WAREHOUSES CREATED: 4
┌────────────────────────┬─────────┬──────────────┬──────────────────────────────────┐
│ Warehouse              │ Size    │ Auto-Suspend │ Purpose                          │
├────────────────────────┼─────────┼──────────────┼──────────────────────────────────┤
│ HEALTH_INGEST_WH       │ SMALL   │ 60 sec       │ Data loading, EHR/claims feeds   │
│ HEALTH_TRANSFORM_WH    │ MEDIUM  │ 120 sec      │ ETL, dbt, transformations        │
│ HEALTH_ANALYTICS_WH    │ LARGE   │ 300 sec      │ BI, clinical dashboards          │
│ HEALTH_AI_WH           │ XLARGE  │ 600 sec      │ ML training, predictions         │
└────────────────────────┴─────────┴──────────────┴──────────────────────────────────┘

RESOURCE MONITORS: 4
┌──────────────────────────────┬───────────────┬──────────────────────────────────────┐
│ Monitor                      │ Credit Quota  │ Assigned To                          │
├──────────────────────────────┼───────────────┼──────────────────────────────────────┤
│ HEALTH_INGEST_MONITOR        │ 500/month     │ HEALTH_INGEST_WH                     │
│ HEALTH_TRANSFORM_MONITOR     │ 1500/month    │ HEALTH_TRANSFORM_WH                  │
│ HEALTH_ANALYTICS_MONITOR     │ 2000/month    │ HEALTH_ANALYTICS_WH                  │
│ HEALTH_AI_MONITOR            │ 1000/month    │ HEALTH_AI_WH                         │
└──────────────────────────────┴───────────────┴──────────────────────────────────────┘

WAREHOUSE GRANTS BY ROLE:
┌────────────────────────┬───────────────────────────────────────────────────────────┐
│ Role                   │ Warehouse Access                                          │
├────────────────────────┼───────────────────────────────────────────────────────────┤
│ HEALTH_READONLY        │ ANALYTICS_WH (usage)                                      │
│ HEALTH_ANALYST         │ ANALYTICS_WH (usage, operate)                             │
│ HEALTH_DATA_ENGINEER   │ INGEST, TRANSFORM (usage, operate), ANALYTICS, AI (usage) │
│ HEALTH_ML_ENGINEER     │ AI_WH (usage, operate), ANALYTICS_WH (usage)              │
│ HEALTH_DATA_ADMIN      │ INGEST, TRANSFORM, ANALYTICS (all privileges)             │
│ HEALTH_ML_ADMIN        │ AI_WH (all privileges)                                    │
│ HEALTH_APP_ADMIN       │ ANALYTICS_WH (usage, operate)                             │
└────────────────────────┴───────────────────────────────────────────────────────────┘

================================================================================
*/

SELECT '============================================' AS separator
UNION ALL
SELECT '  PHASE 03: WAREHOUSE MANAGEMENT COMPLETE'
UNION ALL
SELECT '  4 Warehouses + 4 Resource Monitors'
UNION ALL
SELECT '  Health Domain - Healthcare Platform'
UNION ALL
SELECT '  Proceed to Phase 04: Database Structure'
UNION ALL
SELECT '============================================';

-- ============================================================
-- END OF PHASE 03: WAREHOUSE MANAGEMENT
-- ============================================================
