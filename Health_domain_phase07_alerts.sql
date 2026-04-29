-- ============================================================
-- HEALTH_DOMAIN - ALERTS
-- ============================================================
-- Phase 07: Automated Alerts
-- Script: 07_alerts.sql
-- Version: 1.0.0
--
-- Description:
--   Automated Snowflake ALERT objects for proactive monitoring
--   of Healthcare & Life Sciences Platform. Alerts query Phase 05/06
--   monitoring views and send notifications.
--
-- Alerts Created: 10
--   1.  ALERT_RESOURCE_MONITOR_CRITICAL - Monitor >= 90%
--   2.  ALERT_LONG_RUNNING_QUERY        - Queries > 5 minutes
--   3.  ALERT_FAILED_QUERY_SPIKE        - Failed query threshold
--   4.  ALERT_HIGH_WAREHOUSE_QUEUE      - Queue overload
--   5.  ALERT_MONTHLY_COST_SPIKE        - Month-over-month spike
--   6.  ALERT_LOGIN_FAILURES            - Brute force detection
--   7.  ALERT_PRIVILEGE_ESCALATION      - New ACCOUNTADMIN grant
--   8.  ALERT_PHI_DATA_EXPORT           - Large PHI data transfer
--   9.  ALERT_AI_WH_HIGH_SPEND         - ML warehouse cost spike
--   10. ALERT_STORAGE_GROWTH            - Storage spike >10%
--
-- Initial State: All alerts created SUSPENDED
--
-- Dependencies:
--   - Phase 05/06 monitoring views exist
--   - HEALTH_ANALYTICS_WH exists
-- ============================================================

USE ROLE ACCOUNTADMIN;
USE DATABASE HEALTH_GOVERNANCE_DB;
USE SCHEMA MONITORING;

CREATE NOTIFICATION INTEGRATION IF NOT EXISTS HEALTH_EMAIL_NOTIFICATION
    TYPE = EMAIL
    ENABLED = TRUE
    ALLOWED_RECIPIENTS = ('varundeep2287@gmail.com');


-- ============================================================
-- SECTION 1: RESOURCE MONITOR ALERT
-- ============================================================

-- ------------------------------------------------------------
-- ALERT 1: Resource Monitor Critical (>= 90%)
-- Schedule: Every 30 minutes
-- Severity: CRITICAL
-- ------------------------------------------------------------
CREATE OR REPLACE ALERT HEALTH_GOVERNANCE_DB.MONITORING.ALERT_RESOURCE_MONITOR_CRITICAL
    WAREHOUSE = HEALTH_ANALYTICS_WH
    SCHEDULE = 'USING CRON 0,30 * * * * UTC'
    COMMENT = 'CRITICAL: Resource monitors at or above 90% consumption. Immediate attention required.'
    IF (EXISTS (
        SELECT 1
        FROM HEALTH_GOVERNANCE_DB.MONITORING.VW_RESOURCE_MONITOR_STATUS
        WHERE usage_percent >= 90
    ))
    THEN
        CALL SYSTEM$SEND_EMAIL(
            'HEALTH_EMAIL_NOTIFICATION',
            'varundeep2287@gmail.com',
            'CRITICAL: Health Platform - Resource Monitor Near Limit',
            'One or more resource monitors have reached 90% or higher credit consumption. Review immediately to prevent warehouse suspension.'
        );


-- ============================================================
-- SECTION 2: QUERY ALERTS
-- ============================================================

-- ------------------------------------------------------------
-- ALERT 2: Long Running Queries (> 5 minutes)
-- Schedule: Every 15 minutes
-- Severity: WARNING
-- ------------------------------------------------------------
CREATE OR REPLACE ALERT HEALTH_GOVERNANCE_DB.MONITORING.ALERT_LONG_RUNNING_QUERY
    WAREHOUSE = HEALTH_ANALYTICS_WH
    SCHEDULE = 'USING CRON 0,15,30,45 * * * * UTC'
    COMMENT = 'WARNING: Queries exceeding 5 minutes in last 15 minutes.'
    IF (EXISTS (
        SELECT 1
        FROM HEALTH_GOVERNANCE_DB.MONITORING.VW_LONG_RUNNING_QUERIES
        WHERE start_time >= DATEADD(MINUTE, -15, CURRENT_TIMESTAMP())
    ))
    THEN
        CALL SYSTEM$SEND_EMAIL(
            'HEALTH_EMAIL_NOTIFICATION',
            'varundeep2287@gmail.com',
            'WARNING: Health Platform - Long Running Queries Detected',
            'Long-running queries (>5 min) detected in the last 15 minutes. Review query patterns for optimization.'
        );


-- ------------------------------------------------------------
-- ALERT 3: Failed Query Spike (> 10 failures)
-- Schedule: Every 15 minutes
-- Severity: WARNING
-- ------------------------------------------------------------
CREATE OR REPLACE ALERT HEALTH_GOVERNANCE_DB.MONITORING.ALERT_FAILED_QUERY_SPIKE
    WAREHOUSE = HEALTH_ANALYTICS_WH
    SCHEDULE = 'USING CRON 0,15,30,45 * * * * UTC'
    COMMENT = 'WARNING: More than 10 failed queries in last 15 minutes.'
    IF (EXISTS (
        SELECT 1
        FROM (
            SELECT COUNT(*) AS failed_count
            FROM HEALTH_GOVERNANCE_DB.MONITORING.VW_FAILED_QUERIES
            WHERE start_time >= DATEADD(MINUTE, -15, CURRENT_TIMESTAMP())
        )
        WHERE failed_count > 10
    ))
    THEN
        CALL SYSTEM$SEND_EMAIL(
            'HEALTH_EMAIL_NOTIFICATION',
            'varundeep2287@gmail.com',
            'WARNING: Health Platform - Failed Query Spike',
            'More than 10 failed queries detected in the last 15 minutes. Investigate error patterns.'
        );


-- ============================================================
-- SECTION 3: WAREHOUSE CAPACITY ALERT
-- ============================================================

-- ------------------------------------------------------------
-- ALERT 4: High Warehouse Queue (> 5 queued)
-- Schedule: Every 30 minutes
-- Severity: WARNING
-- ------------------------------------------------------------
CREATE OR REPLACE ALERT HEALTH_GOVERNANCE_DB.MONITORING.ALERT_HIGH_WAREHOUSE_QUEUE
    WAREHOUSE = HEALTH_ANALYTICS_WH
    SCHEDULE = 'USING CRON 0,30 * * * * UTC'
    COMMENT = 'WARNING: Warehouse queue exceeding 5 queries.'
    IF (EXISTS (
        SELECT 1
        FROM HEALTH_GOVERNANCE_DB.MONITORING.VW_ACTIVE_WAREHOUSE_LOAD
        WHERE avg_queries_queued > 5
    ))
    THEN
        CALL SYSTEM$SEND_EMAIL(
            'HEALTH_EMAIL_NOTIFICATION',
            'varundeep2287@gmail.com',
            'WARNING: Health Platform - High Warehouse Queue',
            'One or more warehouses have high query queue load. Consider scaling warehouse size.'
        );


-- ============================================================
-- SECTION 4: COST GOVERNANCE ALERT
-- ============================================================

-- ------------------------------------------------------------
-- ALERT 5: Monthly Cost Spike (> 120% of previous month)
-- Schedule: Daily at 08:00 UTC
-- Severity: CRITICAL
-- ------------------------------------------------------------
CREATE OR REPLACE ALERT HEALTH_GOVERNANCE_DB.MONITORING.ALERT_MONTHLY_COST_SPIKE
    WAREHOUSE = HEALTH_ANALYTICS_WH
    SCHEDULE = 'USING CRON 0 8 * * * UTC'
    COMMENT = 'CRITICAL: Current month credits exceed 120% of previous month.'
    IF (EXISTS (
        SELECT 1
        FROM (
            SELECT
                SUM(CASE WHEN usage_month = DATE_TRUNC('MONTH', CURRENT_DATE()) THEN total_credits ELSE 0 END) AS current_credits,
                SUM(CASE WHEN usage_month = DATE_TRUNC('MONTH', DATEADD(MONTH, -1, CURRENT_DATE())) THEN total_credits ELSE 0 END) AS previous_credits
            FROM HEALTH_GOVERNANCE_DB.MONITORING.VW_COST_BY_MONTH
        )
        WHERE current_credits > previous_credits * 1.2
          AND previous_credits > 0
    ))
    THEN
        CALL SYSTEM$SEND_EMAIL(
            'HEALTH_EMAIL_NOTIFICATION',
            'varundeep2287@gmail.com',
            'CRITICAL: Health Platform - Monthly Cost Spike',
            'Current month credit consumption exceeds 120% of previous month. Review cost drivers immediately.'
        );


-- ============================================================
-- SECTION 5: SECURITY ALERTS (HIPAA-specific)
-- ============================================================

-- ------------------------------------------------------------
-- ALERT 6: Login Failure Spike (>10 failures/hour)
-- Schedule: Hourly
-- Severity: CRITICAL
-- Regulatory: HIPAA § 164.312(b) - Audit Controls
-- ------------------------------------------------------------
CREATE OR REPLACE ALERT HEALTH_GOVERNANCE_DB.MONITORING.ALERT_LOGIN_FAILURES
    WAREHOUSE = HEALTH_ANALYTICS_WH
    SCHEDULE = 'USING CRON 0 * * * * UTC'
    COMMENT = 'CRITICAL: More than 10 failed login attempts in last hour - possible brute force against PHI.'
    IF (EXISTS (
        SELECT 1
        FROM SNOWFLAKE.ACCOUNT_USAGE.LOGIN_HISTORY
        WHERE IS_SUCCESS = 'NO'
          AND EVENT_TIMESTAMP >= DATEADD(HOUR, -1, CURRENT_TIMESTAMP())
        HAVING COUNT(*) > 10
    ))
    THEN
        CALL SYSTEM$SEND_EMAIL(
            'HEALTH_EMAIL_NOTIFICATION',
            'varundeep2287@gmail.com',
            'CRITICAL: Health Platform - Login Failure Spike (Possible Brute Force)',
            'More than 10 failed login attempts in the last hour. Possible unauthorized access attempt to PHI. Investigate immediately per HIPAA incident response.'
        );

-- ------------------------------------------------------------
-- ALERT 7: Privilege Escalation (New ACCOUNTADMIN grant)
-- Schedule: Hourly
-- Severity: CRITICAL
-- Regulatory: HIPAA § 164.312(a) - Access Control
-- ------------------------------------------------------------
CREATE OR REPLACE ALERT HEALTH_GOVERNANCE_DB.MONITORING.ALERT_PRIVILEGE_ESCALATION
    WAREHOUSE = HEALTH_ANALYTICS_WH
    SCHEDULE = 'USING CRON 0 * * * * UTC'
    COMMENT = 'CRITICAL: New ACCOUNTADMIN role grant detected - potential unauthorized privilege escalation.'
    IF (EXISTS (
        SELECT 1
        FROM SNOWFLAKE.ACCOUNT_USAGE.GRANTS_TO_USERS
        WHERE ROLE = 'ACCOUNTADMIN'
          AND CREATED_ON >= DATEADD(HOUR, -1, CURRENT_TIMESTAMP())
    ))
    THEN
        CALL SYSTEM$SEND_EMAIL(
            'HEALTH_EMAIL_NOTIFICATION',
            'varundeep2287@gmail.com',
            'CRITICAL: Health Platform - ACCOUNTADMIN Grant Detected',
            'A new ACCOUNTADMIN role grant was detected in the last hour. Verify this was authorized. Unauthorized privilege escalation is a HIPAA breach indicator.'
        );

-- ------------------------------------------------------------
-- ALERT 8: PHI Data Export Anomaly (>10 GB transferred)
-- Schedule: Daily at 06:00 UTC
-- Severity: CRITICAL
-- Regulatory: HIPAA § 164.312(e) - Transmission Security
-- ------------------------------------------------------------
CREATE OR REPLACE ALERT HEALTH_GOVERNANCE_DB.MONITORING.ALERT_PHI_DATA_EXPORT
    WAREHOUSE = HEALTH_ANALYTICS_WH
    SCHEDULE = 'USING CRON 0 6 * * * UTC'
    COMMENT = 'CRITICAL: Large data export (>10 GB) - potential PHI exfiltration.'
    IF (EXISTS (
        SELECT 1
        FROM SNOWFLAKE.ACCOUNT_USAGE.DATA_TRANSFER_HISTORY
        WHERE START_TIME >= DATEADD(DAY, -1, CURRENT_TIMESTAMP())
        GROUP BY TRANSFER_TYPE
        HAVING SUM(BYTES_TRANSFERRED) / POWER(1024, 3) > 10
    ))
    THEN
        CALL SYSTEM$SEND_EMAIL(
            'HEALTH_EMAIL_NOTIFICATION',
            'varundeep2287@gmail.com',
            'CRITICAL: Health Platform - Large Data Export Detected (>10 GB)',
            'More than 10 GB transferred externally in the last 24 hours. Verify this is authorized. Large PHI transfers require review per HIPAA breach notification rules.'
        );


-- ============================================================
-- SECTION 6: INFRASTRUCTURE ALERTS
-- ============================================================

-- ------------------------------------------------------------
-- ALERT 9: AI/ML Warehouse High Spend (>30 credits/day)
-- Schedule: Every 6 hours
-- Severity: WARNING
-- ------------------------------------------------------------
CREATE OR REPLACE ALERT HEALTH_GOVERNANCE_DB.MONITORING.ALERT_AI_WH_HIGH_SPEND
    WAREHOUSE = HEALTH_ANALYTICS_WH
    SCHEDULE = 'USING CRON 0 0,6,12,18 * * * UTC'
    COMMENT = 'WARNING: HEALTH_AI_WH exceeded 30 credits in 24 hours - ML workload cost spike.'
    IF (EXISTS (
        SELECT 1
        FROM SNOWFLAKE.ACCOUNT_USAGE.WAREHOUSE_METERING_HISTORY
        WHERE WAREHOUSE_NAME = 'HEALTH_AI_WH'
          AND START_TIME >= DATEADD(DAY, -1, CURRENT_TIMESTAMP())
        GROUP BY WAREHOUSE_NAME
        HAVING SUM(CREDITS_USED) > 30
    ))
    THEN
        CALL SYSTEM$SEND_EMAIL(
            'HEALTH_EMAIL_NOTIFICATION',
            'varundeep2287@gmail.com',
            'WARNING: Health Platform - AI Warehouse High Daily Spend',
            'HEALTH_AI_WH exceeded 30 credits in the last 24 hours. Review ML training jobs and feature engineering workloads.'
        );

-- ------------------------------------------------------------
-- ALERT 10: Storage Growth Spike (>10% daily increase)
-- Schedule: Daily at 06:00 UTC
-- Severity: WARNING
-- ------------------------------------------------------------
CREATE OR REPLACE ALERT HEALTH_GOVERNANCE_DB.MONITORING.ALERT_STORAGE_GROWTH
    WAREHOUSE = HEALTH_ANALYTICS_WH
    SCHEDULE = 'USING CRON 0 6 * * * UTC'
    COMMENT = 'WARNING: Storage increased by more than 10% in one day.'
    IF (EXISTS (
        SELECT 1
        FROM (
            SELECT
                STORAGE_BYTES AS today_bytes,
                LAG(STORAGE_BYTES) OVER (ORDER BY USAGE_DATE) AS yesterday_bytes
            FROM SNOWFLAKE.ACCOUNT_USAGE.STORAGE_USAGE
            WHERE USAGE_DATE >= DATEADD(DAY, -2, CURRENT_DATE())
        )
        WHERE yesterday_bytes > 0
          AND (today_bytes - yesterday_bytes) / yesterday_bytes > 0.10
    ))
    THEN
        CALL SYSTEM$SEND_EMAIL(
            'HEALTH_EMAIL_NOTIFICATION',
            'varundeep2287@gmail.com',
            'WARNING: Health Platform - Storage Growth Spike (>10%)',
            'Storage increased by more than 10% in the last day. Review data loading patterns and EHR feed volumes.'
        );


-- ============================================================
-- SECTION 7: ENABLE ALERTS (Initially Suspended)
-- ============================================================
-- Uncomment to enable production alerting

-- ALTER ALERT ALERT_RESOURCE_MONITOR_CRITICAL RESUME;
-- ALTER ALERT ALERT_LONG_RUNNING_QUERY RESUME;
-- ALTER ALERT ALERT_FAILED_QUERY_SPIKE RESUME;
-- ALTER ALERT ALERT_HIGH_WAREHOUSE_QUEUE RESUME;
-- ALTER ALERT ALERT_MONTHLY_COST_SPIKE RESUME;
-- ALTER ALERT ALERT_LOGIN_FAILURES RESUME;
-- ALTER ALERT ALERT_PRIVILEGE_ESCALATION RESUME;
-- ALTER ALERT ALERT_PHI_DATA_EXPORT RESUME;
-- ALTER ALERT ALERT_AI_WH_HIGH_SPEND RESUME;
-- ALTER ALERT ALERT_STORAGE_GROWTH RESUME;


-- ============================================================
-- SECTION 8: GRANT OPERATE TO DATA_ADMIN
-- ============================================================

GRANT OPERATE ON ALERT ALERT_RESOURCE_MONITOR_CRITICAL TO ROLE HEALTH_DATA_ADMIN;
GRANT OPERATE ON ALERT ALERT_LONG_RUNNING_QUERY TO ROLE HEALTH_DATA_ADMIN;
GRANT OPERATE ON ALERT ALERT_FAILED_QUERY_SPIKE TO ROLE HEALTH_DATA_ADMIN;
GRANT OPERATE ON ALERT ALERT_HIGH_WAREHOUSE_QUEUE TO ROLE HEALTH_DATA_ADMIN;
GRANT OPERATE ON ALERT ALERT_MONTHLY_COST_SPIKE TO ROLE HEALTH_DATA_ADMIN;
GRANT OPERATE ON ALERT ALERT_LOGIN_FAILURES TO ROLE HEALTH_DATA_ADMIN;
GRANT OPERATE ON ALERT ALERT_PRIVILEGE_ESCALATION TO ROLE HEALTH_DATA_ADMIN;
GRANT OPERATE ON ALERT ALERT_PHI_DATA_EXPORT TO ROLE HEALTH_DATA_ADMIN;
GRANT OPERATE ON ALERT ALERT_AI_WH_HIGH_SPEND TO ROLE HEALTH_DATA_ADMIN;
GRANT OPERATE ON ALERT ALERT_STORAGE_GROWTH TO ROLE HEALTH_DATA_ADMIN;


-- ============================================================
-- SECTION 9: VERIFICATION
-- ============================================================

SHOW ALERTS IN SCHEMA HEALTH_GOVERNANCE_DB.MONITORING;


-- ============================================================
-- SECTION 10: SUMMARY
-- ============================================================
/*
================================================================================
PHASE 07: ALERTS - SUMMARY
================================================================================

ALERTS CREATED: 10
┌────────────────────────────────────┬────────────────────┬──────────────────────┐
│ Alert                              │ Schedule           │ Condition            │
├────────────────────────────────────┼────────────────────┼──────────────────────┤
│ ALERT_RESOURCE_MONITOR_CRITICAL    │ Every 30 min       │ Monitor >= 90%       │
│ ALERT_LONG_RUNNING_QUERY           │ Every 15 min       │ Query > 5 minutes    │
│ ALERT_FAILED_QUERY_SPIKE           │ Every 15 min       │ > 10 failures        │
│ ALERT_HIGH_WAREHOUSE_QUEUE         │ Every 30 min       │ Queue > 5 queries    │
│ ALERT_MONTHLY_COST_SPIKE           │ Daily 08:00 UTC    │ > 120% of prev month │
│ ALERT_LOGIN_FAILURES               │ Hourly             │ > 10 failed logins   │
│ ALERT_PRIVILEGE_ESCALATION         │ Hourly             │ New ACCOUNTADMIN     │
│ ALERT_PHI_DATA_EXPORT              │ Daily 06:00 UTC    │ > 10 GB transferred  │
│ ALERT_AI_WH_HIGH_SPEND            │ Every 6 hours      │ > 30 credits/day     │
│ ALERT_STORAGE_GROWTH               │ Daily 06:00 UTC    │ > 10% daily growth   │
└────────────────────────────────────┴────────────────────┴──────────────────────┘

SEVERITY LEVELS:
  - CRITICAL: RESOURCE_MONITOR, MONTHLY_COST, LOGIN_FAILURES, PRIVILEGE_ESCALATION, PHI_EXPORT
  - WARNING:  LONG_RUNNING, FAILED_QUERY, WAREHOUSE_QUEUE, AI_WH_SPEND, STORAGE_GROWTH

HIPAA COMPLIANCE COVERAGE:
  - § 164.312(a) Access Control    → ALERT_PRIVILEGE_ESCALATION
  - § 164.312(b) Audit Controls    → ALERT_LOGIN_FAILURES
  - § 164.312(e) Transmission      → ALERT_PHI_DATA_EXPORT
  - Breach Notification Rule       → ALERT_PHI_DATA_EXPORT, ALERT_LOGIN_FAILURES

INITIAL STATE: All alerts SUSPENDED (enable in production)

NOTIFICATION: varundeep2287@gmail.com (update as needed)

WAREHOUSE: HEALTH_ANALYTICS_WH (used for all alert condition checks)

GRANTS: OPERATE privilege to HEALTH_DATA_ADMIN

================================================================================
*/

SELECT '============================================' AS separator
UNION ALL
SELECT '  PHASE 07: ALERTS COMPLETE'
UNION ALL
SELECT '  10 Alerts Created (Suspended)'
UNION ALL
SELECT '  Health Domain - Healthcare Platform'
UNION ALL
SELECT '  Proceed to Phase 08: Data Governance'
UNION ALL
SELECT '============================================';

-- ============================================================
-- END OF PHASE 07: ALERTS
-- ============================================================
/*
ALTER ALERT ALERT_RESOURCE_MONITOR_CRITICAL RESUME;
ALTER ALERT ALERT_LONG_RUNNING_QUERY RESUME;
ALTER ALERT ALERT_FAILED_QUERY_SPIKE RESUME;
ALTER ALERT ALERT_HIGH_WAREHOUSE_QUEUE RESUME;
ALTER ALERT ALERT_MONTHLY_COST_SPIKE RESUME;
ALTER ALERT ALERT_LOGIN_FAILURES RESUME;
ALTER ALERT ALERT_PRIVILEGE_ESCALATION RESUME;
ALTER ALERT ALERT_PHI_DATA_EXPORT RESUME;
ALTER ALERT ALERT_AI_WH_HIGH_SPEND RESUME;
ALTER ALERT ALERT_STORAGE_GROWTH RESUME;
*/ -- To Enable All Alerts
