------------------------------------------------------------------------
-- HEALTH_DOMAIN — PHASE 7: ALERTS
-- 10+ cost and queue alerts
------------------------------------------------------------------------

USE ROLE ACCOUNTADMIN;

CREATE WAREHOUSE IF NOT EXISTS HEALTH_ALERT_WH
  WAREHOUSE_SIZE       = 'XSMALL'
  AUTO_SUSPEND         = 60
  AUTO_RESUME          = TRUE
  INITIALLY_SUSPENDED  = TRUE
  COMMENT = 'Dedicated warehouse for alert condition checks';

-- 1. Daily credit spend exceeds threshold
CREATE OR REPLACE ALERT HEALTH_GOVERNANCE_DB.MONITORS.ALERT_DAILY_CREDIT_SPIKE
  WAREHOUSE = HEALTH_ALERT_WH
  SCHEDULE  = 'USING CRON 0 8 * * * America/New_York'
  IF (EXISTS (
    SELECT 1
    FROM SNOWFLAKE.ACCOUNT_USAGE.WAREHOUSE_METERING_HISTORY
    WHERE START_TIME >= DATEADD('DAY', -1, CURRENT_TIMESTAMP())
    GROUP BY WAREHOUSE_NAME
    HAVING SUM(CREDITS_USED) > 50
  ))
  THEN
    CALL SYSTEM$SEND_EMAIL(
      'health_domain_alerts',
      'health-alerts@example.com',
      'ALERT: Daily credit spike detected',
      'One or more warehouses exceeded 50 credits in the last 24 hours.'
    );

-- 2. Warehouse queue overload
CREATE OR REPLACE ALERT HEALTH_GOVERNANCE_DB.MONITORS.ALERT_WAREHOUSE_QUEUE
  WAREHOUSE = HEALTH_ALERT_WH
  SCHEDULE  = 'USING CRON */15 * * * * America/New_York'
  IF (EXISTS (
    SELECT 1
    FROM SNOWFLAKE.ACCOUNT_USAGE.WAREHOUSE_LOAD_HISTORY
    WHERE START_TIME >= DATEADD('MINUTE', -15, CURRENT_TIMESTAMP())
      AND AVG_QUEUED_LOAD > 5
  ))
  THEN
    CALL SYSTEM$SEND_EMAIL(
      'health_domain_alerts',
      'health-alerts@example.com',
      'ALERT: Warehouse queue overload',
      'Average queued load exceeded 5 in the last 15 minutes.'
    );

-- 3. Failed query surge
CREATE OR REPLACE ALERT HEALTH_GOVERNANCE_DB.MONITORS.ALERT_FAILED_QUERY_SURGE
  WAREHOUSE = HEALTH_ALERT_WH
  SCHEDULE  = 'USING CRON 0 * * * * America/New_York'
  IF (EXISTS (
    SELECT 1
    FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY
    WHERE EXECUTION_STATUS = 'FAIL'
      AND START_TIME >= DATEADD('HOUR', -1, CURRENT_TIMESTAMP())
    HAVING COUNT(*) > 20
  ))
  THEN
    CALL SYSTEM$SEND_EMAIL(
      'health_domain_alerts',
      'health-alerts@example.com',
      'ALERT: Failed query surge',
      'More than 20 failed queries detected in the last hour.'
    );

-- 4. Long-running query alert (>30 min)
CREATE OR REPLACE ALERT HEALTH_GOVERNANCE_DB.MONITORS.ALERT_LONG_RUNNING_QUERY
  WAREHOUSE = HEALTH_ALERT_WH
  SCHEDULE  = 'USING CRON */10 * * * * America/New_York'
  IF (EXISTS (
    SELECT 1
    FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY
    WHERE EXECUTION_STATUS = 'RUNNING'
      AND START_TIME <= DATEADD('MINUTE', -30, CURRENT_TIMESTAMP())
      AND START_TIME >= DATEADD('HOUR', -2, CURRENT_TIMESTAMP())
  ))
  THEN
    CALL SYSTEM$SEND_EMAIL(
      'health_domain_alerts',
      'health-alerts@example.com',
      'ALERT: Long-running query detected',
      'A query has been running for more than 30 minutes.'
    );

-- 5. Storage growth spike (>10% daily increase)
CREATE OR REPLACE ALERT HEALTH_GOVERNANCE_DB.MONITORS.ALERT_STORAGE_GROWTH
  WAREHOUSE = HEALTH_ALERT_WH
  SCHEDULE  = 'USING CRON 0 6 * * * America/New_York'
  IF (EXISTS (
    SELECT 1
    FROM (
      SELECT
        STORAGE_BYTES AS TODAY_BYTES,
        LAG(STORAGE_BYTES) OVER (ORDER BY USAGE_DATE) AS YESTERDAY_BYTES
      FROM SNOWFLAKE.ACCOUNT_USAGE.STORAGE_USAGE
      WHERE USAGE_DATE >= DATEADD('DAY', -2, CURRENT_DATE())
    )
    WHERE YESTERDAY_BYTES > 0
      AND (TODAY_BYTES - YESTERDAY_BYTES) / YESTERDAY_BYTES > 0.10
  ))
  THEN
    CALL SYSTEM$SEND_EMAIL(
      'health_domain_alerts',
      'health-alerts@example.com',
      'ALERT: Storage growth spike >10%',
      'Storage increased by more than 10% in the last day.'
    );

-- 6. Resource monitor approaching limit (>85%)
CREATE OR REPLACE ALERT HEALTH_GOVERNANCE_DB.MONITORS.ALERT_RESOURCE_MONITOR_THRESHOLD
  WAREHOUSE = HEALTH_ALERT_WH
  SCHEDULE  = 'USING CRON 0 */4 * * * America/New_York'
  IF (EXISTS (
    SELECT 1
    FROM TABLE(INFORMATION_SCHEMA.RESOURCE_MONITORS())
    WHERE USED_CREDITS / NULLIF(CREDIT_QUOTA, 0) > 0.85
  ))
  THEN
    CALL SYSTEM$SEND_EMAIL(
      'health_domain_alerts',
      'health-alerts@example.com',
      'ALERT: Resource monitor >85% utilised',
      'A resource monitor has exceeded 85% of its credit quota.'
    );

-- 7. Login failure spike
CREATE OR REPLACE ALERT HEALTH_GOVERNANCE_DB.MONITORS.ALERT_LOGIN_FAILURES
  WAREHOUSE = HEALTH_ALERT_WH
  SCHEDULE  = 'USING CRON 0 * * * * America/New_York'
  IF (EXISTS (
    SELECT 1
    FROM SNOWFLAKE.ACCOUNT_USAGE.LOGIN_HISTORY
    WHERE IS_SUCCESS = 'NO'
      AND EVENT_TIMESTAMP >= DATEADD('HOUR', -1, CURRENT_TIMESTAMP())
    HAVING COUNT(*) > 10
  ))
  THEN
    CALL SYSTEM$SEND_EMAIL(
      'health_domain_alerts',
      'health-alerts@example.com',
      'ALERT: Login failure spike',
      'More than 10 failed login attempts in the last hour – possible brute force.'
    );

-- 8. AI warehouse high spend
CREATE OR REPLACE ALERT HEALTH_GOVERNANCE_DB.MONITORS.ALERT_AI_WH_HIGH_SPEND
  WAREHOUSE = HEALTH_ALERT_WH
  SCHEDULE  = 'USING CRON 0 */6 * * * America/New_York'
  IF (EXISTS (
    SELECT 1
    FROM SNOWFLAKE.ACCOUNT_USAGE.WAREHOUSE_METERING_HISTORY
    WHERE WAREHOUSE_NAME = 'HEALTH_AI_WH'
      AND START_TIME >= DATEADD('DAY', -1, CURRENT_TIMESTAMP())
    GROUP BY WAREHOUSE_NAME
    HAVING SUM(CREDITS_USED) > 30
  ))
  THEN
    CALL SYSTEM$SEND_EMAIL(
      'health_domain_alerts',
      'health-alerts@example.com',
      'ALERT: AI warehouse high daily spend',
      'HEALTH_AI_WH exceeded 30 credits in the last 24 hours.'
    );

-- 9. Idle warehouse running (no queries but not suspended)
CREATE OR REPLACE ALERT HEALTH_GOVERNANCE_DB.MONITORS.ALERT_IDLE_WAREHOUSE
  WAREHOUSE = HEALTH_ALERT_WH
  SCHEDULE  = 'USING CRON 0 */2 * * * America/New_York'
  IF (EXISTS (
    SELECT 1
    FROM SNOWFLAKE.ACCOUNT_USAGE.WAREHOUSE_LOAD_HISTORY
    WHERE START_TIME >= DATEADD('HOUR', -2, CURRENT_TIMESTAMP())
    GROUP BY WAREHOUSE_NAME
    HAVING MAX(AVG_RUNNING) = 0 AND MAX(AVG_QUEUED_LOAD) = 0
  ))
  THEN
    CALL SYSTEM$SEND_EMAIL(
      'health_domain_alerts',
      'health-alerts@example.com',
      'ALERT: Idle warehouse detected',
      'A warehouse has had zero load for 2+ hours but may still be running.'
    );

-- 10. Privilege escalation – new ACCOUNTADMIN grant
CREATE OR REPLACE ALERT HEALTH_GOVERNANCE_DB.MONITORS.ALERT_PRIVILEGE_ESCALATION
  WAREHOUSE = HEALTH_ALERT_WH
  SCHEDULE  = 'USING CRON 0 * * * * America/New_York'
  IF (EXISTS (
    SELECT 1
    FROM SNOWFLAKE.ACCOUNT_USAGE.GRANTS_TO_USERS
    WHERE ROLE = 'ACCOUNTADMIN'
      AND CREATED_ON >= DATEADD('HOUR', -1, CURRENT_TIMESTAMP())
  ))
  THEN
    CALL SYSTEM$SEND_EMAIL(
      'health_domain_alerts',
      'health-alerts@example.com',
      'ALERT: ACCOUNTADMIN grant detected',
      'A new ACCOUNTADMIN role grant was detected in the last hour.'
    );

-- 11. Data sharing/export anomaly
CREATE OR REPLACE ALERT HEALTH_GOVERNANCE_DB.MONITORS.ALERT_DATA_EXPORT_ANOMALY
  WAREHOUSE = HEALTH_ALERT_WH
  SCHEDULE  = 'USING CRON 0 8 * * * America/New_York'
  IF (EXISTS (
    SELECT 1
    FROM SNOWFLAKE.ACCOUNT_USAGE.DATA_TRANSFER_HISTORY
    WHERE START_TIME >= DATEADD('DAY', -1, CURRENT_TIMESTAMP())
    GROUP BY TRANSFER_TYPE
    HAVING SUM(BYTES_TRANSFERRED) / POWER(1024,3) > 10
  ))
  THEN
    CALL SYSTEM$SEND_EMAIL(
      'health_domain_alerts',
      'health-alerts@example.com',
      'ALERT: Large data export detected (>10 GB)',
      'More than 10 GB transferred externally in the last 24 hours.'
    );

-- 12. Cortex/serverless credit spike
CREATE OR REPLACE ALERT HEALTH_GOVERNANCE_DB.MONITORS.ALERT_SERVERLESS_SPIKE
  WAREHOUSE = HEALTH_ALERT_WH
  SCHEDULE  = 'USING CRON 0 */6 * * * America/New_York'
  IF (EXISTS (
    SELECT 1
    FROM SNOWFLAKE.ACCOUNT_USAGE.SERVERLESS_TASK_HISTORY
    WHERE START_TIME >= DATEADD('DAY', -1, CURRENT_TIMESTAMP())
    HAVING SUM(CREDITS_USED) > 20
  ))
  THEN
    CALL SYSTEM$SEND_EMAIL(
      'health_domain_alerts',
      'health-alerts@example.com',
      'ALERT: Serverless credit spike',
      'Serverless features consumed >20 credits in the last 24 hours.'
    );

ALTER ALERT HEALTH_GOVERNANCE_DB.MONITORS.ALERT_DAILY_CREDIT_SPIKE         RESUME;
ALTER ALERT HEALTH_GOVERNANCE_DB.MONITORS.ALERT_WAREHOUSE_QUEUE            RESUME;
ALTER ALERT HEALTH_GOVERNANCE_DB.MONITORS.ALERT_FAILED_QUERY_SURGE         RESUME;
ALTER ALERT HEALTH_GOVERNANCE_DB.MONITORS.ALERT_LONG_RUNNING_QUERY         RESUME;
ALTER ALERT HEALTH_GOVERNANCE_DB.MONITORS.ALERT_STORAGE_GROWTH             RESUME;
ALTER ALERT HEALTH_GOVERNANCE_DB.MONITORS.ALERT_RESOURCE_MONITOR_THRESHOLD RESUME;
ALTER ALERT HEALTH_GOVERNANCE_DB.MONITORS.ALERT_LOGIN_FAILURES             RESUME;
ALTER ALERT HEALTH_GOVERNANCE_DB.MONITORS.ALERT_AI_WH_HIGH_SPEND          RESUME;
ALTER ALERT HEALTH_GOVERNANCE_DB.MONITORS.ALERT_IDLE_WAREHOUSE             RESUME;
ALTER ALERT HEALTH_GOVERNANCE_DB.MONITORS.ALERT_PRIVILEGE_ESCALATION       RESUME;
ALTER ALERT HEALTH_GOVERNANCE_DB.MONITORS.ALERT_DATA_EXPORT_ANOMALY        RESUME;
ALTER ALERT HEALTH_GOVERNANCE_DB.MONITORS.ALERT_SERVERLESS_SPIKE           RESUME;
