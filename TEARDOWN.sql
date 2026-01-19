/*
================================================================================
 LIFEARC POC - TEARDOWN SCRIPT
================================================================================
 
 PURPOSE: Cleanly remove all LifeArc POC objects from Snowflake account
 
 WARNING: This script PERMANENTLY DELETES all POC objects and data!
 
 USAGE:
   1. Connect to Snowflake as ACCOUNTADMIN
   2. Review the script carefully
   3. Run entire script
 
 VERSION: 1.0.0
 LAST UPDATED: 2026-01-19
================================================================================
*/

USE ROLE ACCOUNTADMIN;

-- =============================================================================
-- SECTION 1: DROP USERS AND ROLES
-- =============================================================================

-- Drop service users first
DROP USER IF EXISTS LIFEARC_ML_SERVICE;
DROP USER IF EXISTS LIFEARC_ETL_SERVICE;

-- Drop roles (grants are automatically cleaned up)
DROP ROLE IF EXISTS LIFEARC_ML_PIPELINE_ROLE;
DROP ROLE IF EXISTS LIFEARC_ETL_SERVICE_ROLE;
DROP ROLE IF EXISTS LIFEARC_ANALYST_ROLE;
DROP ROLE IF EXISTS CLINICAL_DATA_ADMIN;
DROP ROLE IF EXISTS CLINICAL_ANALYST;

-- =============================================================================
-- SECTION 2: DROP NETWORK POLICY
-- =============================================================================

DROP NETWORK POLICY IF EXISTS LIFEARC_ML_NETWORK_POLICY;

-- =============================================================================
-- SECTION 3: DROP DATABASE (cascades all schemas, tables, views, UDFs, etc.)
-- =============================================================================

-- This single command removes:
-- - All schemas
-- - All tables and data
-- - All views
-- - All UDFs and procedures
-- - All tags and policies
-- - All stages
-- - All secrets

DROP DATABASE IF EXISTS LIFEARC_POC CASCADE;

-- =============================================================================
-- SECTION 4: OPTIONAL - DROP WAREHOUSE
-- =============================================================================

-- Uncomment the following line if you also want to remove the warehouse
-- DROP WAREHOUSE IF EXISTS DEMO_WH;

-- =============================================================================
-- VERIFICATION
-- =============================================================================

SELECT 'TEARDOWN COMPLETE' AS status;

-- Verify database is gone
SELECT COUNT(*) AS remaining_databases 
FROM INFORMATION_SCHEMA.DATABASES 
WHERE DATABASE_NAME = 'LIFEARC_POC';

-- Verify roles are gone
SHOW ROLES LIKE 'LIFEARC%';
SHOW ROLES LIKE 'CLINICAL%';

/*
================================================================================
 TEARDOWN COMPLETE
================================================================================
 
 All LifeArc POC objects have been removed.
 
 To redeploy, run DEPLOY.sql
 
================================================================================
*/
