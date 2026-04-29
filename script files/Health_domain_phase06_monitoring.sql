-- ============================================================
-- HEALTH_DOMAIN - MONITORING VIEWS
-- ============================================================
-- Phase 06: Monitoring Views (Extended)
-- Script: 06_monitoring_views.sql
-- Version: 1.0.0
--
-- Description:
--   Extended monitoring views for Healthcare & Life Sciences Platform.
--   Builds on Phase 05 resource monitors with detailed query
--   performance, warehouse utilization, and cost attribution.
--
-- Data Latency Note:
--   Views pull from SNOWFLAKE.ACCOUNT_USAGE which has latency:
--   - Query views: up to 45 minutes
--   - Warehouse views: up to 3 hours
--
-- Views Created: 10
--   1. VW_QUERY_PERFORMANCE       - Query execution metrics
--   2. VW_LONG_RUNNING_QUERIES    - Queries > 5 minutes
--   3. VW_FAILED_QUERIES          - Queries with errors
--   4. VW_WAREHOUSE_UTILIZATION   - Warehouse load patterns
--   5. VW_ACTIVE_WAREHOUSE_LOAD   - Current warehouse load
--   6. VW_COST_BY_MONTH           - Monthly cost by warehouse
--   7. VW_LOGIN_HISTORY           - User login activity
--   8. VW_DATA_TRANSFER           - Data transfer costs
--   9. VW_QUERY_TYPE_SUMMARY      - Query type distribution
--  10. VW_DATABASE_STORAGE        - Storage by database
--
-- Dependencies:
--   - Phase 04 completed: HEALTH_GOVERNANCE_DB.MONITORING exists
--   - Phase 05 completed: Resource monitors exist
-- ============================================================

USE ROLE ACCOUNTADMIN;
USE DATABASE HEALTH_GOVERNANCE_DB;
USE SCHEMA MONITORING;


-- ============================================================
-- SECTION 1: QUERY PERFORMANCE VIEWS
-- ============================================================

-- ------------------------------------------------------------
-- VIEW 1: Query Performance Metrics
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW VW_QUERY_PERFORMANCE AS
SELECT
    query_id,
    SUBSTR(query_text, 1, 500) AS query_preview,
    user_name,
    role_name,
    warehouse_name,
    warehouse_size,
    database_name,
    schema_name,
    query_type,
    execution_status,
    start_time,
    end_time,
    ROUND(total_elapsed_time / 1000, 2) AS execution_seconds,
    ROUND(compilation_time / 1000, 2) AS compile_seconds,
    ROUND(queued_overload_time / 1000, 2) AS queue_seconds,
    bytes_scanned,
    ROUND(bytes_scanned / POWER(1024, 3), 4) AS gb_scanned,
    rows_produced,
    partitions_scanned,
    partitions_total,
    ROUND(partitions_scanned / NULLIF(partitions_total, 0) * 100, 2) AS partition_scan_pct,
    credits_used_cloud_services AS credits_used
FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY
WHERE warehouse_name LIKE 'HEALTH_%'
  AND start_time >= DATEADD(DAY, -30, CURRENT_DATE())
ORDER BY start_time DESC;

-- ------------------------------------------------------------
-- VIEW 2: Long Running Queries (> 5 minutes)
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW VW_LONG_RUNNING_QUERIES AS
SELECT
    query_id,
    SUBSTR(query_text, 1, 300) AS query_preview,
    user_name,
    role_name,
    warehouse_name,
    warehouse_size,
    database_name,
    query_type,
    execution_status,
    start_time,
    end_time,
    ROUND(total_elapsed_time / 1000, 2) AS execution_seconds,
    ROUND(total_elapsed_time / 60000, 2) AS execution_minutes,
    bytes_scanned,
    ROUND(bytes_scanned / POWER(1024, 3), 2) AS gb_scanned,
    rows_produced,
    partitions_scanned
FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY
WHERE warehouse_name LIKE 'HEALTH_%'
  AND total_elapsed_time > 300000
  AND start_time >= DATEADD(DAY, -30, CURRENT_DATE())
ORDER BY total_elapsed_time DESC;

-- ------------------------------------------------------------
-- VIEW 3: Failed Queries
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW VW_FAILED_QUERIES AS
SELECT
    query_id,
    SUBSTR(query_text, 1, 300) AS query_preview,
    user_name,
    role_name,
    warehouse_name,
    database_name,
    schema_name,
    query_type,
    execution_status,
    error_code,
    error_message,
    start_time,
    ROUND(total_elapsed_time / 1000, 2) AS execution_seconds
FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY
WHERE warehouse_name LIKE 'HEALTH_%'
  AND execution_status = 'FAIL'
  AND start_time >= DATEADD(DAY, -30, CURRENT_DATE())
ORDER BY start_time DESC;


-- ============================================================
-- SECTION 2: WAREHOUSE UTILIZATION VIEWS
-- ============================================================

-- ------------------------------------------------------------
-- VIEW 4: Warehouse Utilization Over Time
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW VW_WAREHOUSE_UTILIZATION AS
SELECT
    warehouse_name,
    start_time,
    end_time,
    ROUND(avg_running, 2) AS avg_queries_running,
    ROUND(avg_queued_load, 2) AS avg_queries_queued,
    ROUND(avg_queued_provisioning, 2) AS avg_queries_provisioning,
    ROUND(avg_blocked, 2) AS avg_queries_blocked,
    ROUND(avg_running + avg_queued_load, 2) AS total_load,
    CASE
        WHEN avg_queued_load > 5 THEN 'HIGH_QUEUE'
        WHEN avg_running > 10 THEN 'HIGH_LOAD'
        WHEN avg_blocked > 0 THEN 'BLOCKED'
        ELSE 'NORMAL'
    END AS load_status,
    DATE_TRUNC('HOUR', start_time) AS hour_bucket
FROM SNOWFLAKE.ACCOUNT_USAGE.WAREHOUSE_LOAD_HISTORY
WHERE warehouse_name LIKE 'HEALTH_%'
  AND start_time >= DATEADD(DAY, -30, CURRENT_DATE())
ORDER BY start_time DESC;

-- ------------------------------------------------------------
-- VIEW 5: Active Warehouse Load (Last 24 Hours)
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW VW_ACTIVE_WAREHOUSE_LOAD AS
SELECT
    warehouse_name,
    COUNT(*) AS sample_count,
    ROUND(AVG(avg_running), 2) AS avg_queries_running,
    ROUND(AVG(avg_queued_load), 2) AS avg_queries_queued,
    ROUND(AVG(avg_blocked), 2) AS avg_queries_blocked,
    ROUND(MAX(avg_running), 2) AS peak_queries_running,
    ROUND(MAX(avg_queued_load), 2) AS peak_queries_queued,
    MIN(start_time) AS period_start,
    MAX(end_time) AS period_end
FROM SNOWFLAKE.ACCOUNT_USAGE.WAREHOUSE_LOAD_HISTORY
WHERE warehouse_name LIKE 'HEALTH_%'
  AND start_time >= DATEADD(HOUR, -24, CURRENT_TIMESTAMP())
GROUP BY warehouse_name
ORDER BY avg_queries_running DESC;


-- ============================================================
-- SECTION 3: COST ATTRIBUTION VIEWS
-- ============================================================

-- ------------------------------------------------------------
-- VIEW 6: Monthly Cost by Warehouse
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW VW_COST_BY_MONTH AS
SELECT
    warehouse_name,
    DATE_TRUNC('MONTH', start_time) AS usage_month,
    ROUND(SUM(credits_used), 4) AS compute_credits,
    ROUND(SUM(credits_used_cloud_services), 4) AS cloud_services_credits,
    ROUND(SUM(credits_used) + SUM(credits_used_cloud_services), 4) AS total_credits,
    COUNT(DISTINCT DATE_TRUNC('DAY', start_time)) AS active_days,
    ROUND((SUM(credits_used) + SUM(credits_used_cloud_services)) /
          NULLIF(COUNT(DISTINCT DATE_TRUNC('DAY', start_time)), 0), 4) AS avg_credits_per_day,
    ROUND((SUM(credits_used) + SUM(credits_used_cloud_services)) * 3, 2) AS estimated_cost_usd
FROM SNOWFLAKE.ACCOUNT_USAGE.WAREHOUSE_METERING_HISTORY
WHERE warehouse_name LIKE 'HEALTH_%'
  AND start_time >= DATEADD(MONTH, -12, CURRENT_DATE())
GROUP BY warehouse_name, DATE_TRUNC('MONTH', start_time)
ORDER BY usage_month DESC, total_credits DESC;


-- ============================================================
-- SECTION 4: SECURITY & ACCESS VIEWS
-- ============================================================

-- ------------------------------------------------------------
-- VIEW 7: User Login History
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW VW_LOGIN_HISTORY AS
SELECT
    user_name,
    reported_client_type AS client_type,
    first_authentication_factor AS auth_factor_1,
    second_authentication_factor AS auth_factor_2,
    is_success,
    error_code,
    error_message,
    event_timestamp AS login_time,
    client_ip,
    connection AS connection_name
FROM SNOWFLAKE.ACCOUNT_USAGE.LOGIN_HISTORY
WHERE event_timestamp >= DATEADD(DAY, -30, CURRENT_DATE())
ORDER BY event_timestamp DESC;


-- ============================================================
-- SECTION 5: DATA TRANSFER & STORAGE VIEWS
-- ============================================================

-- ------------------------------------------------------------
-- VIEW 8: Data Transfer Costs
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW VW_DATA_TRANSFER AS
SELECT
    DATE_TRUNC('DAY', start_time) AS transfer_date,
    source_cloud,
    source_region,
    target_cloud,
    target_region,
    transfer_type,
    ROUND(SUM(bytes_transferred) / POWER(1024, 3), 4) AS gb_transferred,
    ROUND(SUM(bytes_transferred) / POWER(1024, 4), 6) AS tb_transferred
FROM SNOWFLAKE.ACCOUNT_USAGE.DATA_TRANSFER_HISTORY
WHERE start_time >= DATEADD(DAY, -30, CURRENT_DATE())
GROUP BY 1, 2, 3, 4, 5, 6
ORDER BY transfer_date DESC, gb_transferred DESC;

-- ------------------------------------------------------------
-- VIEW 9: Query Type Distribution
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW VW_QUERY_TYPE_SUMMARY AS
SELECT
    query_type,
    warehouse_name,
    COUNT(*) AS query_count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (PARTITION BY warehouse_name), 2) AS pct_of_warehouse,
    SUM(credits_used_cloud_services) AS total_credits,
    ROUND(AVG(total_elapsed_time) / 1000, 2) AS avg_execution_seconds,
    ROUND(SUM(bytes_scanned) / POWER(1024, 4), 4) AS tb_scanned
FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY
WHERE warehouse_name LIKE 'HEALTH_%'
  AND start_time >= DATEADD(DAY, -30, CURRENT_DATE())
GROUP BY query_type, warehouse_name
ORDER BY warehouse_name, query_count DESC;

-- ------------------------------------------------------------
-- VIEW 10: Database Storage
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW VW_DATABASE_STORAGE AS
SELECT
    database_name,
    ROUND(SUM(average_database_bytes) / POWER(1024, 3), 4) AS database_size_gb,
    ROUND(SUM(average_failsafe_bytes) / POWER(1024, 3), 4) AS failsafe_size_gb,
    ROUND((SUM(average_database_bytes) + SUM(average_failsafe_bytes)) / POWER(1024, 3), 4) AS total_size_gb,
    ROUND((SUM(average_database_bytes) + SUM(average_failsafe_bytes)) / POWER(1024, 3) * 23 / 30, 2) AS estimated_daily_cost_usd
FROM SNOWFLAKE.ACCOUNT_USAGE.DATABASE_STORAGE_USAGE_HISTORY
WHERE usage_date = (SELECT MAX(usage_date) FROM SNOWFLAKE.ACCOUNT_USAGE.DATABASE_STORAGE_USAGE_HISTORY)
  AND database_name LIKE 'HEALTH_%'
GROUP BY database_name
ORDER BY total_size_gb DESC;


-- ============================================================
-- SECTION 6: GRANT ACCESS TO 7 ROLES
-- ============================================================

-- DATA_ADMIN: Full monitoring access
GRANT SELECT ON ALL VIEWS IN SCHEMA HEALTH_GOVERNANCE_DB.MONITORING TO ROLE HEALTH_DATA_ADMIN;
GRANT SELECT ON FUTURE VIEWS IN SCHEMA HEALTH_GOVERNANCE_DB.MONITORING TO ROLE HEALTH_DATA_ADMIN;

-- ML_ADMIN: Full monitoring access
GRANT SELECT ON ALL VIEWS IN SCHEMA HEALTH_GOVERNANCE_DB.MONITORING TO ROLE HEALTH_ML_ADMIN;

-- DATA_ENGINEER: Query and warehouse views
GRANT SELECT ON VIEW VW_QUERY_PERFORMANCE TO ROLE HEALTH_DATA_ENGINEER;
GRANT SELECT ON VIEW VW_LONG_RUNNING_QUERIES TO ROLE HEALTH_DATA_ENGINEER;
GRANT SELECT ON VIEW VW_FAILED_QUERIES TO ROLE HEALTH_DATA_ENGINEER;
GRANT SELECT ON VIEW VW_WAREHOUSE_UTILIZATION TO ROLE HEALTH_DATA_ENGINEER;
GRANT SELECT ON VIEW VW_ACTIVE_WAREHOUSE_LOAD TO ROLE HEALTH_DATA_ENGINEER;

-- ML_ENGINEER: Query and warehouse views
GRANT SELECT ON VIEW VW_QUERY_PERFORMANCE TO ROLE HEALTH_ML_ENGINEER;
GRANT SELECT ON VIEW VW_LONG_RUNNING_QUERIES TO ROLE HEALTH_ML_ENGINEER;
GRANT SELECT ON VIEW VW_WAREHOUSE_UTILIZATION TO ROLE HEALTH_ML_ENGINEER;

-- ANALYST: Cost views for reporting
GRANT SELECT ON VIEW VW_COST_BY_MONTH TO ROLE HEALTH_ANALYST;
GRANT SELECT ON VIEW VW_DATABASE_STORAGE TO ROLE HEALTH_ANALYST;

-- READONLY: Basic monitoring
GRANT SELECT ON VIEW VW_DAILY_WAREHOUSE_CREDITS TO ROLE HEALTH_READONLY;
GRANT SELECT ON VIEW VW_MONTHLY_CREDIT_SUMMARY TO ROLE HEALTH_READONLY;
GRANT SELECT ON VIEW VW_RESOURCE_MONITOR_STATUS TO ROLE HEALTH_READONLY;


-- ============================================================
-- SECTION 7: VERIFICATION
-- ============================================================

-- Verify all views created
SHOW VIEWS IN SCHEMA HEALTH_GOVERNANCE_DB.MONITORING;

-- Test key views
SELECT COUNT(*) AS row_count FROM VW_QUERY_PERFORMANCE;
SELECT COUNT(*) AS row_count FROM VW_WAREHOUSE_UTILIZATION;
SELECT COUNT(*) AS row_count FROM VW_COST_BY_MONTH;


-- ============================================================
-- SECTION 8: SUMMARY
-- ============================================================
/*
================================================================================
PHASE 06: MONITORING VIEWS - SUMMARY
================================================================================

VIEWS CREATED: 10 (+ 7 from Phase 05 = 17 Total)
┌───────────────────────────────┬───────────────────────────────────────────────┐
│ View                          │ Purpose                                       │
├───────────────────────────────┼───────────────────────────────────────────────┤
│ VW_QUERY_PERFORMANCE          │ Query execution metrics                       │
│ VW_LONG_RUNNING_QUERIES       │ Queries > 5 minutes                          │
│ VW_FAILED_QUERIES             │ Queries with errors                          │
│ VW_WAREHOUSE_UTILIZATION      │ Warehouse load over time                     │
│ VW_ACTIVE_WAREHOUSE_LOAD      │ Current warehouse load (24h)                 │
│ VW_COST_BY_MONTH              │ Monthly cost by warehouse                    │
│ VW_LOGIN_HISTORY              │ User login activity                          │
│ VW_DATA_TRANSFER              │ Data transfer costs                          │
│ VW_QUERY_TYPE_SUMMARY         │ Query type distribution                      │
│ VW_DATABASE_STORAGE           │ Storage by database                          │
└───────────────────────────────┴───────────────────────────────────────────────┘

PREVIOUS VIEWS (Phase 05):
  - VW_DAILY_WAREHOUSE_CREDITS
  - VW_MONTHLY_CREDIT_SUMMARY
  - VW_CREDITS_BY_USER
  - VW_CREDITS_BY_ROLE
  - VW_TOP_EXPENSIVE_QUERIES
  - VW_STORAGE_CONSUMPTION
  - VW_RESOURCE_MONITOR_STATUS

ACCESS BY ROLE:
┌────────────────────────┬──────────────────────────────────────────────────────┐
│ Role                   │ View Access                                          │
├────────────────────────┼──────────────────────────────────────────────────────┤
│ HEALTH_DATA_ADMIN      │ ALL monitoring views                                 │
│ HEALTH_ML_ADMIN        │ ALL monitoring views                                 │
│ HEALTH_DATA_ENGINEER   │ Query + Warehouse views                              │
│ HEALTH_ML_ENGINEER     │ Query + Warehouse views                              │
│ HEALTH_ANALYST         │ Cost + Storage views                                 │
│ HEALTH_READONLY        │ Basic credit views                                   │
│ HEALTH_APP_ADMIN       │ (inherits from ANALYST)                              │
└────────────────────────┴──────────────────────────────────────────────────────┘

DATA LATENCY:
  - Query views: up to 45 minutes
  - Warehouse/Storage views: up to 3 hours

================================================================================
*/

SELECT '============================================' AS separator
UNION ALL
SELECT '  PHASE 06: MONITORING VIEWS COMPLETE'
UNION ALL
SELECT '  10 New Views (17 Total)'
UNION ALL
SELECT '  Health Domain - Healthcare Platform'
UNION ALL
SELECT '  Proceed to Phase 07: Alerts'
UNION ALL
SELECT '============================================';

-- ============================================================
-- END OF PHASE 06: MONITORING VIEWS
-- ============================================================
