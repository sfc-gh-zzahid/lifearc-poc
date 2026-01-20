# LifeArc RBAC Best Practices - Automated Deployment at Scale

## Overview

This document provides production-ready Role-Based Access Control (RBAC) patterns for life sciences organizations deploying Snowflake at enterprise scale. These patterns are designed for:

- **Regulatory Compliance**: 21 CFR Part 11, GxP, HIPAA, GDPR
- **Automated Deployment**: Infrastructure-as-Code via Terraform/Pulumi
- **Scalability**: Supporting 100+ users, 20+ data domains, multiple business units
- **Audit Trail**: Complete access logging for regulatory submissions

---

## 1. Role Hierarchy Design

### Recommended Life Sciences Role Structure

```
ACCOUNTADMIN (break-glass only)
    │
    ├── SYSADMIN
    │   └── Creates databases, warehouses, integrations
    │
    ├── SECURITYADMIN
    │   └── Manages roles, grants, policies
    │
    └── FUNCTIONAL ROLES (Custom)
        ├── DATA_ADMIN
        │   └── DOMAIN_ADMIN_CLINICAL
        │   └── DOMAIN_ADMIN_GENOMICS
        │   └── DOMAIN_ADMIN_COMPOUND
        │
        ├── DATA_ENGINEER
        │   └── DE_CLINICAL
        │   └── DE_GENOMICS
        │   └── DE_COMPOUND
        │
        ├── DATA_SCIENTIST
        │   └── DS_CLINICAL
        │   └── DS_GENOMICS
        │   └── DS_COMPOUND
        │
        ├── DATA_ANALYST
        │   └── ANALYST_CLINICAL
        │   └── ANALYST_GENOMICS
        │   └── ANALYST_COMPOUND
        │
        └── DATA_CONSUMER
            └── CONSUMER_INTERNAL
            └── CONSUMER_CRO_PARTNER
            └── CONSUMER_REGULATORY
```

### Implementation SQL

```sql
-- ============================================================================
-- STEP 1: CREATE CUSTOM FUNCTIONAL ROLES
-- ============================================================================

-- Top-level functional roles
CREATE ROLE IF NOT EXISTS DATA_ADMIN COMMENT = 'Full admin for data domains';
CREATE ROLE IF NOT EXISTS DATA_ENGINEER COMMENT = 'Build and maintain data pipelines';
CREATE ROLE IF NOT EXISTS DATA_SCIENTIST COMMENT = 'ML/AI development and experimentation';
CREATE ROLE IF NOT EXISTS DATA_ANALYST COMMENT = 'Reporting and analytics';
CREATE ROLE IF NOT EXISTS DATA_CONSUMER COMMENT = 'Read-only data access';

-- Grant to SYSADMIN (allows SYSADMIN to manage these roles)
GRANT ROLE DATA_ADMIN TO ROLE SYSADMIN;
GRANT ROLE DATA_ENGINEER TO ROLE SYSADMIN;
GRANT ROLE DATA_SCIENTIST TO ROLE SYSADMIN;
GRANT ROLE DATA_ANALYST TO ROLE SYSADMIN;
GRANT ROLE DATA_CONSUMER TO ROLE SYSADMIN;

-- ============================================================================
-- STEP 2: CREATE DOMAIN-SPECIFIC ROLES
-- ============================================================================

-- Clinical domain roles
CREATE ROLE IF NOT EXISTS DOMAIN_ADMIN_CLINICAL;
CREATE ROLE IF NOT EXISTS DE_CLINICAL;
CREATE ROLE IF NOT EXISTS DS_CLINICAL;
CREATE ROLE IF NOT EXISTS ANALYST_CLINICAL;
CREATE ROLE IF NOT EXISTS CONSUMER_CLINICAL;

-- Role hierarchy for clinical domain
GRANT ROLE DE_CLINICAL TO ROLE DOMAIN_ADMIN_CLINICAL;
GRANT ROLE DS_CLINICAL TO ROLE DOMAIN_ADMIN_CLINICAL;
GRANT ROLE ANALYST_CLINICAL TO ROLE DE_CLINICAL;
GRANT ROLE ANALYST_CLINICAL TO ROLE DS_CLINICAL;
GRANT ROLE CONSUMER_CLINICAL TO ROLE ANALYST_CLINICAL;

-- Grant domain admin to functional admin
GRANT ROLE DOMAIN_ADMIN_CLINICAL TO ROLE DATA_ADMIN;

-- Repeat for GENOMICS domain
CREATE ROLE IF NOT EXISTS DOMAIN_ADMIN_GENOMICS;
CREATE ROLE IF NOT EXISTS DE_GENOMICS;
CREATE ROLE IF NOT EXISTS DS_GENOMICS;
CREATE ROLE IF NOT EXISTS ANALYST_GENOMICS;
CREATE ROLE IF NOT EXISTS CONSUMER_GENOMICS;

GRANT ROLE DE_GENOMICS TO ROLE DOMAIN_ADMIN_GENOMICS;
GRANT ROLE DS_GENOMICS TO ROLE DOMAIN_ADMIN_GENOMICS;
GRANT ROLE ANALYST_GENOMICS TO ROLE DE_GENOMICS;
GRANT ROLE ANALYST_GENOMICS TO ROLE DS_GENOMICS;
GRANT ROLE CONSUMER_GENOMICS TO ROLE ANALYST_GENOMICS;
GRANT ROLE DOMAIN_ADMIN_GENOMICS TO ROLE DATA_ADMIN;

-- Repeat for COMPOUND domain
CREATE ROLE IF NOT EXISTS DOMAIN_ADMIN_COMPOUND;
CREATE ROLE IF NOT EXISTS DE_COMPOUND;
CREATE ROLE IF NOT EXISTS DS_COMPOUND;
CREATE ROLE IF NOT EXISTS ANALYST_COMPOUND;
CREATE ROLE IF NOT EXISTS CONSUMER_COMPOUND;

GRANT ROLE DE_COMPOUND TO ROLE DOMAIN_ADMIN_COMPOUND;
GRANT ROLE DS_COMPOUND TO ROLE DOMAIN_ADMIN_COMPOUND;
GRANT ROLE ANALYST_COMPOUND TO ROLE DE_COMPOUND;
GRANT ROLE ANALYST_COMPOUND TO ROLE DS_COMPOUND;
GRANT ROLE CONSUMER_COMPOUND TO ROLE ANALYST_COMPOUND;
GRANT ROLE DOMAIN_ADMIN_COMPOUND TO ROLE DATA_ADMIN;
```

---

## 2. Database and Schema Access Patterns

### Life Sciences Data Architecture

```
LIFEARC_PROD (Database)
├── RAW (Schema) - Landing zone, append-only
│   └── Accessible by: DATA_ENGINEER
├── BRONZE (Schema) - Standardized raw
│   └── Accessible by: DATA_ENGINEER, DATA_SCIENTIST
├── SILVER (Schema) - Cleaned, conformant
│   └── Accessible by: DATA_ENGINEER, DATA_SCIENTIST, DATA_ANALYST
├── GOLD (Schema) - Business-ready
│   └── Accessible by: ALL ROLES (including CONSUMER)
├── ML_FEATURES (Schema) - Feature Store
│   └── Accessible by: DATA_SCIENTIST, ML_OPS
├── ML_MODELS (Schema) - Model Registry
│   └── Accessible by: DATA_SCIENTIST, ML_OPS
├── GOVERNANCE (Schema) - Tags, policies
│   └── Accessible by: SECURITYADMIN, DATA_ADMIN
└── AUDIT (Schema) - Access logs
    └── Accessible by: SECURITYADMIN, COMPLIANCE_OFFICER
```

### Implementation SQL

```sql
-- ============================================================================
-- DATABASE & SCHEMA CREATION
-- ============================================================================

CREATE DATABASE IF NOT EXISTS LIFEARC_PROD
    DATA_RETENTION_TIME_IN_DAYS = 90
    COMMENT = 'Production database for LifeArc';

CREATE SCHEMA IF NOT EXISTS LIFEARC_PROD.RAW;
CREATE SCHEMA IF NOT EXISTS LIFEARC_PROD.BRONZE;
CREATE SCHEMA IF NOT EXISTS LIFEARC_PROD.SILVER;
CREATE SCHEMA IF NOT EXISTS LIFEARC_PROD.GOLD;
CREATE SCHEMA IF NOT EXISTS LIFEARC_PROD.ML_FEATURES;
CREATE SCHEMA IF NOT EXISTS LIFEARC_PROD.ML_MODELS;
CREATE SCHEMA IF NOT EXISTS LIFEARC_PROD.GOVERNANCE;
CREATE SCHEMA IF NOT EXISTS LIFEARC_PROD.AUDIT;

-- ============================================================================
-- GRANT PATTERNS BY ROLE
-- ============================================================================

-- DATA_ADMIN: Full access to all schemas
GRANT USAGE ON DATABASE LIFEARC_PROD TO ROLE DATA_ADMIN;
GRANT CREATE SCHEMA ON DATABASE LIFEARC_PROD TO ROLE DATA_ADMIN;
GRANT ALL ON ALL SCHEMAS IN DATABASE LIFEARC_PROD TO ROLE DATA_ADMIN;
GRANT ALL ON FUTURE SCHEMAS IN DATABASE LIFEARC_PROD TO ROLE DATA_ADMIN;

-- DATA_ENGINEER: RAW through SILVER
GRANT USAGE ON DATABASE LIFEARC_PROD TO ROLE DATA_ENGINEER;
GRANT ALL ON SCHEMA LIFEARC_PROD.RAW TO ROLE DATA_ENGINEER;
GRANT ALL ON SCHEMA LIFEARC_PROD.BRONZE TO ROLE DATA_ENGINEER;
GRANT ALL ON SCHEMA LIFEARC_PROD.SILVER TO ROLE DATA_ENGINEER;
GRANT USAGE ON SCHEMA LIFEARC_PROD.GOLD TO ROLE DATA_ENGINEER;
GRANT SELECT ON ALL TABLES IN SCHEMA LIFEARC_PROD.GOLD TO ROLE DATA_ENGINEER;

-- DATA_SCIENTIST: BRONZE through ML schemas
GRANT USAGE ON DATABASE LIFEARC_PROD TO ROLE DATA_SCIENTIST;
GRANT SELECT ON ALL TABLES IN SCHEMA LIFEARC_PROD.BRONZE TO ROLE DATA_SCIENTIST;
GRANT SELECT ON ALL TABLES IN SCHEMA LIFEARC_PROD.SILVER TO ROLE DATA_SCIENTIST;
GRANT SELECT ON ALL TABLES IN SCHEMA LIFEARC_PROD.GOLD TO ROLE DATA_SCIENTIST;
GRANT ALL ON SCHEMA LIFEARC_PROD.ML_FEATURES TO ROLE DATA_SCIENTIST;
GRANT ALL ON SCHEMA LIFEARC_PROD.ML_MODELS TO ROLE DATA_SCIENTIST;

-- DATA_ANALYST: SILVER and GOLD only
GRANT USAGE ON DATABASE LIFEARC_PROD TO ROLE DATA_ANALYST;
GRANT USAGE ON SCHEMA LIFEARC_PROD.SILVER TO ROLE DATA_ANALYST;
GRANT SELECT ON ALL TABLES IN SCHEMA LIFEARC_PROD.SILVER TO ROLE DATA_ANALYST;
GRANT USAGE ON SCHEMA LIFEARC_PROD.GOLD TO ROLE DATA_ANALYST;
GRANT SELECT ON ALL TABLES IN SCHEMA LIFEARC_PROD.GOLD TO ROLE DATA_ANALYST;

-- DATA_CONSUMER: GOLD only (masked)
GRANT USAGE ON DATABASE LIFEARC_PROD TO ROLE DATA_CONSUMER;
GRANT USAGE ON SCHEMA LIFEARC_PROD.GOLD TO ROLE DATA_CONSUMER;
GRANT SELECT ON ALL TABLES IN SCHEMA LIFEARC_PROD.GOLD TO ROLE DATA_CONSUMER;

-- Apply to future objects
GRANT SELECT ON FUTURE TABLES IN SCHEMA LIFEARC_PROD.RAW TO ROLE DATA_ENGINEER;
GRANT SELECT ON FUTURE TABLES IN SCHEMA LIFEARC_PROD.BRONZE TO ROLE DATA_ENGINEER;
GRANT SELECT ON FUTURE TABLES IN SCHEMA LIFEARC_PROD.SILVER TO ROLE DATA_ENGINEER;
GRANT SELECT ON FUTURE TABLES IN SCHEMA LIFEARC_PROD.GOLD TO ROLE DATA_CONSUMER;
```

---

## 3. Warehouse Access Control

### Warehouse Strategy for Life Sciences

| Warehouse | Size | Purpose | Roles |
|-----------|------|---------|-------|
| WH_ETL_XS | X-Small | Light ETL jobs | DATA_ENGINEER |
| WH_ETL_M | Medium | Heavy transformations | DATA_ENGINEER |
| WH_ML_L | Large | ML training | DATA_SCIENTIST |
| WH_REPORTING | Small | BI queries | DATA_ANALYST, DATA_CONSUMER |
| WH_AD_HOC | X-Small | Interactive queries | DATA_ANALYST |

### Implementation SQL

```sql
-- ============================================================================
-- WAREHOUSE CREATION WITH RESOURCE MONITORING
-- ============================================================================

CREATE WAREHOUSE IF NOT EXISTS WH_ETL_XS
    WAREHOUSE_SIZE = 'XSMALL'
    AUTO_SUSPEND = 60
    AUTO_RESUME = TRUE
    INITIALLY_SUSPENDED = TRUE
    COMMENT = 'Light ETL workloads';

CREATE WAREHOUSE IF NOT EXISTS WH_ETL_M
    WAREHOUSE_SIZE = 'MEDIUM'
    AUTO_SUSPEND = 120
    AUTO_RESUME = TRUE
    INITIALLY_SUSPENDED = TRUE
    MAX_CLUSTER_COUNT = 3
    MIN_CLUSTER_COUNT = 1
    SCALING_POLICY = 'ECONOMY'
    COMMENT = 'Heavy ETL transformations';

CREATE WAREHOUSE IF NOT EXISTS WH_ML_L
    WAREHOUSE_SIZE = 'LARGE'
    AUTO_SUSPEND = 300
    AUTO_RESUME = TRUE
    INITIALLY_SUSPENDED = TRUE
    COMMENT = 'ML model training';

CREATE WAREHOUSE IF NOT EXISTS WH_REPORTING
    WAREHOUSE_SIZE = 'SMALL'
    AUTO_SUSPEND = 60
    AUTO_RESUME = TRUE
    INITIALLY_SUSPENDED = TRUE
    MAX_CLUSTER_COUNT = 5
    MIN_CLUSTER_COUNT = 1
    SCALING_POLICY = 'STANDARD'
    COMMENT = 'BI and reporting queries';

-- ============================================================================
-- WAREHOUSE GRANTS
-- ============================================================================

-- ETL warehouses for engineers
GRANT USAGE ON WAREHOUSE WH_ETL_XS TO ROLE DATA_ENGINEER;
GRANT USAGE ON WAREHOUSE WH_ETL_M TO ROLE DATA_ENGINEER;
GRANT OPERATE ON WAREHOUSE WH_ETL_M TO ROLE DATA_ENGINEER;

-- ML warehouse for data scientists
GRANT USAGE ON WAREHOUSE WH_ML_L TO ROLE DATA_SCIENTIST;
GRANT OPERATE ON WAREHOUSE WH_ML_L TO ROLE DATA_SCIENTIST;

-- Reporting warehouse for analysts and consumers
GRANT USAGE ON WAREHOUSE WH_REPORTING TO ROLE DATA_ANALYST;
GRANT USAGE ON WAREHOUSE WH_REPORTING TO ROLE DATA_CONSUMER;

-- ============================================================================
-- RESOURCE MONITORS (Cost Control)
-- ============================================================================

CREATE RESOURCE MONITOR IF NOT EXISTS RM_ETL
    WITH CREDIT_QUOTA = 1000
    TRIGGERS
        ON 75 PERCENT DO NOTIFY
        ON 90 PERCENT DO NOTIFY
        ON 100 PERCENT DO SUSPEND;

CREATE RESOURCE MONITOR IF NOT EXISTS RM_ML
    WITH CREDIT_QUOTA = 5000
    TRIGGERS
        ON 50 PERCENT DO NOTIFY
        ON 80 PERCENT DO NOTIFY
        ON 100 PERCENT DO SUSPEND;

CREATE RESOURCE MONITOR IF NOT EXISTS RM_REPORTING
    WITH CREDIT_QUOTA = 500
    TRIGGERS
        ON 90 PERCENT DO NOTIFY
        ON 100 PERCENT DO SUSPEND_IMMEDIATE;

-- Apply monitors to warehouses
ALTER WAREHOUSE WH_ETL_XS SET RESOURCE_MONITOR = RM_ETL;
ALTER WAREHOUSE WH_ETL_M SET RESOURCE_MONITOR = RM_ETL;
ALTER WAREHOUSE WH_ML_L SET RESOURCE_MONITOR = RM_ML;
ALTER WAREHOUSE WH_REPORTING SET RESOURCE_MONITOR = RM_REPORTING;
```

---

## 4. Data Masking for Life Sciences

### PHI/PII Masking Policies

```sql
-- ============================================================================
-- DYNAMIC DATA MASKING POLICIES
-- ============================================================================

-- Create governance schema if not exists
CREATE SCHEMA IF NOT EXISTS LIFEARC_PROD.GOVERNANCE;

-- Patient ID masking (full mask for non-privileged roles)
CREATE OR REPLACE MASKING POLICY LIFEARC_PROD.GOVERNANCE.MASK_PATIENT_ID
    AS (val STRING) RETURNS STRING ->
    CASE
        WHEN CURRENT_ROLE() IN ('DATA_ADMIN', 'DATA_ENGINEER', 'DS_CLINICAL') 
            THEN val
        WHEN CURRENT_ROLE() LIKE '%ANALYST%' 
            THEN 'PAT-' || RIGHT(SHA2(val), 8)  -- Pseudonymized
        ELSE '***MASKED***'
    END;

-- Age masking (range buckets for analysts)
CREATE OR REPLACE MASKING POLICY LIFEARC_PROD.GOVERNANCE.MASK_AGE
    AS (val NUMBER) RETURNS NUMBER ->
    CASE
        WHEN CURRENT_ROLE() IN ('DATA_ADMIN', 'DATA_ENGINEER', 'DS_CLINICAL') 
            THEN val
        WHEN CURRENT_ROLE() LIKE '%ANALYST%' 
            THEN FLOOR(val / 10) * 10  -- Round to decade
        ELSE NULL
    END;

-- Genetic sequence masking (truncate for non-privileged)
CREATE OR REPLACE MASKING POLICY LIFEARC_PROD.GOVERNANCE.MASK_GENETIC_SEQUENCE
    AS (val STRING) RETURNS STRING ->
    CASE
        WHEN CURRENT_ROLE() IN ('DATA_ADMIN', 'DATA_ENGINEER', 'DS_GENOMICS') 
            THEN val
        WHEN CURRENT_ROLE() LIKE '%ANALYST%' 
            THEN LEFT(val, 20) || '...[TRUNCATED]'
        ELSE '***PROTECTED_GENETIC_DATA***'
    END;

-- Email masking
CREATE OR REPLACE MASKING POLICY LIFEARC_PROD.GOVERNANCE.MASK_EMAIL
    AS (val STRING) RETURNS STRING ->
    CASE
        WHEN CURRENT_ROLE() IN ('DATA_ADMIN') 
            THEN val
        ELSE REGEXP_REPLACE(val, '(^[^@]{1,3})[^@]*(@.*)', '\\1***\\2')
    END;

-- ============================================================================
-- APPLY MASKING POLICIES TO COLUMNS
-- ============================================================================

-- Example: Apply to clinical trials table
ALTER TABLE IF EXISTS LIFEARC_PROD.GOLD.CLINICAL_TRIALS 
    MODIFY COLUMN PATIENT_ID 
    SET MASKING POLICY LIFEARC_PROD.GOVERNANCE.MASK_PATIENT_ID;

ALTER TABLE IF EXISTS LIFEARC_PROD.GOLD.CLINICAL_TRIALS 
    MODIFY COLUMN PATIENT_AGE 
    SET MASKING POLICY LIFEARC_PROD.GOVERNANCE.MASK_AGE;
```

---

## 5. Row-Level Security for Multi-Site Studies

### Row Access Policies

```sql
-- ============================================================================
-- ROW ACCESS POLICIES FOR STUDY-LEVEL ACCESS
-- ============================================================================

-- Site access mapping table
CREATE TABLE IF NOT EXISTS LIFEARC_PROD.GOVERNANCE.SITE_USER_MAPPING (
    USER_NAME VARCHAR(256),
    SITE_ID VARCHAR(50),
    ACCESS_LEVEL VARCHAR(20),  -- FULL, AGGREGATED, NONE
    VALID_FROM DATE,
    VALID_TO DATE,
    CONSTRAINT pk_site_user PRIMARY KEY (USER_NAME, SITE_ID)
);

-- Row access policy for site-based filtering
CREATE OR REPLACE ROW ACCESS POLICY LIFEARC_PROD.GOVERNANCE.RAP_SITE_ACCESS
    AS (site_id VARCHAR) RETURNS BOOLEAN ->
    CASE
        -- Admins see all sites
        WHEN CURRENT_ROLE() IN ('DATA_ADMIN', 'DOMAIN_ADMIN_CLINICAL') 
            THEN TRUE
        -- Users see their assigned sites
        WHEN EXISTS (
            SELECT 1 FROM LIFEARC_PROD.GOVERNANCE.SITE_USER_MAPPING
            WHERE USER_NAME = CURRENT_USER()
            AND SITE_ID = site_id
            AND ACCESS_LEVEL IN ('FULL', 'AGGREGATED')
            AND CURRENT_DATE() BETWEEN VALID_FROM AND COALESCE(VALID_TO, '9999-12-31')
        ) THEN TRUE
        ELSE FALSE
    END;

-- Apply to clinical tables
ALTER TABLE IF EXISTS LIFEARC_PROD.GOLD.CLINICAL_TRIALS
    ADD ROW ACCESS POLICY LIFEARC_PROD.GOVERNANCE.RAP_SITE_ACCESS
    ON (SITE_ID);

-- ============================================================================
-- SPONSOR ACCESS POLICY (for CRO scenarios)
-- ============================================================================

CREATE TABLE IF NOT EXISTS LIFEARC_PROD.GOVERNANCE.SPONSOR_ACCESS_MAPPING (
    USER_NAME VARCHAR(256),
    SPONSOR_ID VARCHAR(50),
    STUDY_ID VARCHAR(50),
    ACCESS_TYPE VARCHAR(20),  -- DATA_ACCESS, ANALYTICS_ONLY, MONITORING
    PRIMARY KEY (USER_NAME, SPONSOR_ID, STUDY_ID)
);

CREATE OR REPLACE ROW ACCESS POLICY LIFEARC_PROD.GOVERNANCE.RAP_SPONSOR_ACCESS
    AS (sponsor_id VARCHAR, study_id VARCHAR) RETURNS BOOLEAN ->
    CASE
        WHEN CURRENT_ROLE() IN ('DATA_ADMIN') THEN TRUE
        WHEN EXISTS (
            SELECT 1 FROM LIFEARC_PROD.GOVERNANCE.SPONSOR_ACCESS_MAPPING
            WHERE USER_NAME = CURRENT_USER()
            AND (SPONSOR_ID = sponsor_id OR SPONSOR_ID = '*')
            AND (STUDY_ID = study_id OR STUDY_ID = '*')
        ) THEN TRUE
        ELSE FALSE
    END;
```

---

## 6. Automated Role Assignment via SCIM

### SCIM Integration for Enterprise SSO

```sql
-- ============================================================================
-- SCIM INTEGRATION SETUP
-- ============================================================================

-- Create SCIM integration for Okta/Azure AD
CREATE OR REPLACE SECURITY INTEGRATION SCIM_INTEGRATION
    TYPE = SCIM
    SCIM_CLIENT = 'OKTA'  -- or 'AZURE_AD'
    RUN_AS_ROLE = 'AAD_PROVISIONER';  -- Custom role for SCIM

-- Create provisioner role
CREATE ROLE IF NOT EXISTS AAD_PROVISIONER;
GRANT CREATE USER ON ACCOUNT TO ROLE AAD_PROVISIONER;
GRANT CREATE ROLE ON ACCOUNT TO ROLE AAD_PROVISIONER;
GRANT ROLE AAD_PROVISIONER TO ROLE SECURITYADMIN;

-- ============================================================================
-- AUTOMATIC ROLE MAPPING PROCEDURE
-- ============================================================================

-- Stored procedure to assign roles based on AD group membership
CREATE OR REPLACE PROCEDURE LIFEARC_PROD.GOVERNANCE.SYNC_USER_ROLES()
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
DECLARE
    v_result VARCHAR;
BEGIN
    -- Map AD groups to Snowflake roles
    -- This runs after SCIM provisions the user
    
    -- Data Engineers (AD Group: DataEngineers)
    FOR user_rec IN (
        SELECT DISTINCT GRANTEE_NAME 
        FROM SNOWFLAKE.ACCOUNT_USAGE.GRANTS_TO_USERS 
        WHERE ROLE = 'SCIM_AD_DATAENGINEERS'
    ) DO
        EXECUTE IMMEDIATE 'GRANT ROLE DATA_ENGINEER TO USER ' || user_rec.GRANTEE_NAME;
    END FOR;
    
    -- Data Scientists (AD Group: DataScientists)
    FOR user_rec IN (
        SELECT DISTINCT GRANTEE_NAME 
        FROM SNOWFLAKE.ACCOUNT_USAGE.GRANTS_TO_USERS 
        WHERE ROLE = 'SCIM_AD_DATASCIENTISTS'
    ) DO
        EXECUTE IMMEDIATE 'GRANT ROLE DATA_SCIENTIST TO USER ' || user_rec.GRANTEE_NAME;
    END FOR;
    
    -- Analysts (AD Group: DataAnalysts)
    FOR user_rec IN (
        SELECT DISTINCT GRANTEE_NAME 
        FROM SNOWFLAKE.ACCOUNT_USAGE.GRANTS_TO_USERS 
        WHERE ROLE = 'SCIM_AD_DATAANALYSTS'
    ) DO
        EXECUTE IMMEDIATE 'GRANT ROLE DATA_ANALYST TO USER ' || user_rec.GRANTEE_NAME;
    END FOR;
    
    RETURN 'Role sync completed';
END;
$$;

-- Schedule role sync task
CREATE OR REPLACE TASK LIFEARC_PROD.GOVERNANCE.TASK_SYNC_ROLES
    WAREHOUSE = WH_ETL_XS
    SCHEDULE = 'USING CRON 0 * * * * UTC'  -- Every hour
AS
    CALL LIFEARC_PROD.GOVERNANCE.SYNC_USER_ROLES();
```

---

## 7. Terraform/Pulumi Automation

### Terraform Module Structure

```hcl
# terraform/modules/snowflake_rbac/main.tf

terraform {
  required_providers {
    snowflake = {
      source  = "Snowflake-Labs/snowflake"
      version = "~> 0.70"
    }
  }
}

# Variables
variable "environment" {
  type        = string
  description = "Environment name (dev, staging, prod)"
}

variable "data_domains" {
  type        = list(string)
  description = "List of data domains"
  default     = ["clinical", "genomics", "compound"]
}

# Functional Roles
resource "snowflake_role" "data_admin" {
  name    = "DATA_ADMIN"
  comment = "Full admin for data domains"
}

resource "snowflake_role" "data_engineer" {
  name    = "DATA_ENGINEER"
  comment = "Build and maintain data pipelines"
}

resource "snowflake_role" "data_scientist" {
  name    = "DATA_SCIENTIST"
  comment = "ML/AI development"
}

resource "snowflake_role" "data_analyst" {
  name    = "DATA_ANALYST"
  comment = "Reporting and analytics"
}

# Domain-specific roles (dynamic)
resource "snowflake_role" "domain_admin" {
  for_each = toset(var.data_domains)
  name     = "DOMAIN_ADMIN_${upper(each.value)}"
  comment  = "Admin for ${each.value} domain"
}

resource "snowflake_role" "domain_engineer" {
  for_each = toset(var.data_domains)
  name     = "DE_${upper(each.value)}"
  comment  = "Data engineer for ${each.value}"
}

resource "snowflake_role" "domain_scientist" {
  for_each = toset(var.data_domains)
  name     = "DS_${upper(each.value)}"
  comment  = "Data scientist for ${each.value}"
}

resource "snowflake_role" "domain_analyst" {
  for_each = toset(var.data_domains)
  name     = "ANALYST_${upper(each.value)}"
  comment  = "Analyst for ${each.value}"
}

# Role hierarchy grants
resource "snowflake_role_grants" "domain_to_functional" {
  for_each  = toset(var.data_domains)
  role_name = snowflake_role.domain_admin[each.value].name
  roles     = [snowflake_role.data_admin.name]
}

# Database
resource "snowflake_database" "main" {
  name                        = "LIFEARC_${upper(var.environment)}"
  data_retention_time_in_days = var.environment == "prod" ? 90 : 7
  comment                     = "LifeArc ${var.environment} database"
}

# Schemas
resource "snowflake_schema" "schemas" {
  for_each = toset(["RAW", "BRONZE", "SILVER", "GOLD", "ML_FEATURES", "ML_MODELS", "GOVERNANCE", "AUDIT"])
  database = snowflake_database.main.name
  name     = each.value
}

# Schema grants
resource "snowflake_schema_grant" "gold_consumer" {
  database_name = snowflake_database.main.name
  schema_name   = "GOLD"
  privilege     = "USAGE"
  roles         = [snowflake_role.data_analyst.name]
}
```

### Terraform Usage

```bash
# Initialize
terraform init

# Plan changes
terraform plan -var="environment=prod" -var="data_domains=[\"clinical\",\"genomics\",\"compound\",\"operational\"]"

# Apply
terraform apply -auto-approve

# Destroy (dev only!)
terraform destroy -var="environment=dev"
```

---

## 8. Audit and Compliance Queries

### Pre-built Audit Queries for Regulatory Submissions

```sql
-- ============================================================================
-- COMPLIANCE AUDIT QUERIES
-- ============================================================================

-- 1. Who has access to PHI data?
CREATE OR REPLACE VIEW LIFEARC_PROD.AUDIT.V_PHI_ACCESS_REPORT AS
SELECT DISTINCT
    g.GRANTEE_NAME AS user_or_role,
    g.GRANTED_ON AS object_type,
    g.NAME AS object_name,
    g.PRIVILEGE,
    tr.TAG_VALUE AS data_classification
FROM SNOWFLAKE.ACCOUNT_USAGE.GRANTS_TO_ROLES g
JOIN SNOWFLAKE.ACCOUNT_USAGE.TAG_REFERENCES tr
    ON g.NAME = tr.OBJECT_NAME
WHERE tr.TAG_NAME = 'DATA_CLASSIFICATION'
  AND tr.TAG_VALUE = 'PHI'
ORDER BY g.GRANTEE_NAME;

-- 2. Access history for specific table (last 30 days)
CREATE OR REPLACE VIEW LIFEARC_PROD.AUDIT.V_TABLE_ACCESS_HISTORY AS
SELECT 
    QUERY_START_TIME,
    USER_NAME,
    ROLE_NAME,
    QUERY_TEXT,
    ROWS_PRODUCED,
    EXECUTION_STATUS
FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY
WHERE QUERY_TEXT ILIKE '%CLINICAL_TRIALS%'
  AND QUERY_START_TIME > DATEADD('day', -30, CURRENT_TIMESTAMP())
ORDER BY QUERY_START_TIME DESC;

-- 3. Role changes audit trail
CREATE OR REPLACE VIEW LIFEARC_PROD.AUDIT.V_ROLE_CHANGES AS
SELECT 
    EVENT_TIMESTAMP,
    USER_NAME,
    ROLE_NAME,
    QUERY_TYPE,
    QUERY_TEXT
FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY
WHERE QUERY_TYPE IN ('GRANT', 'REVOKE', 'CREATE_ROLE', 'DROP_ROLE')
  AND QUERY_START_TIME > DATEADD('day', -90, CURRENT_TIMESTAMP())
ORDER BY EVENT_TIMESTAMP DESC;

-- 4. Failed login attempts
CREATE OR REPLACE VIEW LIFEARC_PROD.AUDIT.V_FAILED_LOGINS AS
SELECT 
    EVENT_TIMESTAMP,
    USER_NAME,
    CLIENT_IP,
    ERROR_CODE,
    ERROR_MESSAGE,
    REPORTED_CLIENT_TYPE
FROM SNOWFLAKE.ACCOUNT_USAGE.LOGIN_HISTORY
WHERE IS_SUCCESS = 'NO'
  AND EVENT_TIMESTAMP > DATEADD('day', -30, CURRENT_TIMESTAMP())
ORDER BY EVENT_TIMESTAMP DESC;

-- 5. Data export audit (potential data exfiltration)
CREATE OR REPLACE VIEW LIFEARC_PROD.AUDIT.V_DATA_EXPORTS AS
SELECT 
    QUERY_START_TIME,
    USER_NAME,
    ROLE_NAME,
    QUERY_TEXT,
    BYTES_WRITTEN_TO_RESULT,
    ROWS_PRODUCED
FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY
WHERE (
    QUERY_TEXT ILIKE '%COPY INTO%'
    OR QUERY_TEXT ILIKE '%UNLOAD%'
    OR QUERY_TEXT ILIKE '%GET%@%'
)
AND QUERY_START_TIME > DATEADD('day', -7, CURRENT_TIMESTAMP())
ORDER BY BYTES_WRITTEN_TO_RESULT DESC;
```

---

## 9. Onboarding Checklist

### New User Onboarding Procedure

```sql
-- ============================================================================
-- USER ONBOARDING PROCEDURE
-- ============================================================================

CREATE OR REPLACE PROCEDURE LIFEARC_PROD.GOVERNANCE.ONBOARD_USER(
    p_username VARCHAR,
    p_email VARCHAR,
    p_role VARCHAR,  -- DATA_ENGINEER, DATA_SCIENTIST, DATA_ANALYST
    p_domains ARRAY,  -- ['clinical', 'genomics']
    p_default_warehouse VARCHAR
)
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
DECLARE
    v_domain VARCHAR;
BEGIN
    -- 1. Create user (for non-SSO environments)
    -- In SSO environments, user is created via SCIM
    EXECUTE IMMEDIATE 'CREATE USER IF NOT EXISTS ' || p_username || 
                      ' EMAIL = ''' || p_email || '''' ||
                      ' DEFAULT_WAREHOUSE = ''' || p_default_warehouse || '''' ||
                      ' DEFAULT_ROLE = ''' || p_role || '''';
    
    -- 2. Grant functional role
    EXECUTE IMMEDIATE 'GRANT ROLE ' || p_role || ' TO USER ' || p_username;
    
    -- 3. Grant domain-specific roles
    FOR v_domain IN (SELECT VALUE FROM TABLE(FLATTEN(INPUT => p_domains))) DO
        EXECUTE IMMEDIATE 'GRANT ROLE ' || p_role || '_' || UPPER(v_domain) || 
                          ' TO USER ' || p_username;
    END FOR;
    
    -- 4. Log onboarding event
    INSERT INTO LIFEARC_PROD.AUDIT.USER_ONBOARDING_LOG 
        (USER_NAME, EMAIL, ROLE, DOMAINS, ONBOARDED_BY, ONBOARDED_AT)
    VALUES 
        (p_username, p_email, p_role, ARRAY_TO_STRING(p_domains, ','), 
         CURRENT_USER(), CURRENT_TIMESTAMP());
    
    RETURN 'User ' || p_username || ' onboarded successfully with role ' || p_role;
END;
$$;

-- Usage example:
-- CALL LIFEARC_PROD.GOVERNANCE.ONBOARD_USER(
--     'jsmith',
--     'john.smith@lifearc.org',
--     'DATA_SCIENTIST',
--     ARRAY_CONSTRUCT('clinical', 'genomics'),
--     'WH_ML_L'
-- );
```

---

## 10. Quick Reference Card

### Role Permissions Matrix

| Action | DATA_ADMIN | DATA_ENGINEER | DATA_SCIENTIST | DATA_ANALYST | DATA_CONSUMER |
|--------|------------|---------------|----------------|--------------|---------------|
| Create schemas |  |  |  |  |  |
| Create tables |  |  |  |  |  |
| Read RAW |  |  |  |  |  |
| Read BRONZE |  |  |  |  |  |
| Read SILVER |  |  |  |  |  |
| Read GOLD |  |  |  |  |  |
| Create ML models |  |  |  |  |  |
| View PHI unmasked |  |  |  |  |  |
| Export data |  |  |  |  |  |
| Create shares |  |  |  |  |  |

### Emergency Procedures

```sql
-- BREAK GLASS: Revoke all access for compromised user
REVOKE ALL PRIVILEGES ON ALL OBJECTS IN DATABASE LIFEARC_PROD FROM USER compromised_user;
ALTER USER compromised_user SET DISABLED = TRUE;

-- EMERGENCY: Revoke all access from role
REVOKE ROLE suspicious_role FROM USER all_users;

-- AUDIT: What did this user access?
SELECT * FROM SNOWFLAKE.ACCOUNT_USAGE.ACCESS_HISTORY
WHERE USER_NAME = 'suspicious_user'
AND QUERY_START_TIME > DATEADD('day', -7, CURRENT_TIMESTAMP());
```

---

## Summary

This RBAC framework provides:

1. **Hierarchical Role Structure** - Functional + Domain-specific roles
2. **Least Privilege Access** - Schema-level grants with progressive access
3. **Dynamic Data Masking** - PHI/PII protection per role
4. **Row-Level Security** - Multi-site, multi-sponsor access control
5. **Automated Provisioning** - SCIM + Terraform integration
6. **Complete Audit Trail** - Regulatory-ready queries
7. **Cost Control** - Resource monitors per workload type

For questions or customization, contact your Snowflake Solutions Architect.
