/*
================================================================================
LIFEARC POC - DEMO 5: DATA CONTRACTS, SHARING & POLICY CONTROLS
================================================================================

This script demonstrates Snowflake's data sharing and governance capabilities:

1. Secure Data Sharing (Native Snowflake Shares)
2. Data Clean Rooms
3. Row Access Policies
4. Column Masking Policies  
5. Data Access Auditing
6. Data Contracts with Tags

Use Case Context:
- Share clinical trial data with external CRO partners
- Enable secure collaboration with pharma companies
- Maintain data ownership and audit trail
- Enforce access policies based on data sensitivity

================================================================================
*/

-- ============================================================================
-- SECTION 1: SETUP DATABASE AND SAMPLE DATA
-- ============================================================================

USE ROLE ACCOUNTADMIN;
USE WAREHOUSE DEMO_WH;
USE DATABASE LIFEARC_POC;
USE SCHEMA DATA_SHARING;

-- Create sample clinical trial results table (to be shared)
CREATE OR REPLACE TABLE CLINICAL_TRIAL_RESULTS (
    result_id VARCHAR PRIMARY KEY,
    trial_id VARCHAR,
    patient_id VARCHAR,           -- Sensitive: needs masking
    site_id VARCHAR,
    cohort VARCHAR,
    treatment_arm VARCHAR,
    response_category VARCHAR,
    pfs_months FLOAT,
    os_months FLOAT,
    adverse_events VARCHAR,
    biomarker_status VARCHAR,
    patient_age INT,              -- Sensitive: needs masking
    patient_sex VARCHAR,
    created_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

-- Insert sample data
INSERT INTO CLINICAL_TRIAL_RESULTS 
(result_id, trial_id, patient_id, site_id, cohort, treatment_arm, 
 response_category, pfs_months, os_months, adverse_events, 
 biomarker_status, patient_age, patient_sex)
VALUES
('R001', 'LA-2024-001', 'PAT-10234', 'SITE-UK-001', 'Cohort_A', 'ARM_A', 'Partial_Response', 8.5, 14.2, 'Grade2_Fatigue', 'KRAS_G12C_POS', 58, 'F'),
('R002', 'LA-2024-001', 'PAT-10235', 'SITE-UK-001', 'Cohort_A', 'ARM_B', 'Stable_Disease', 5.2, 11.8, 'Grade1_Nausea', 'KRAS_G12C_POS', 64, 'M'),
('R003', 'LA-2024-001', 'PAT-10236', 'SITE-UK-002', 'Cohort_A', 'ARM_A', 'Complete_Response', 12.1, 18.5, 'None', 'KRAS_G12C_POS', 52, 'F'),
('R004', 'LA-2024-001', 'PAT-10237', 'SITE-US-001', 'Cohort_B', 'ARM_B', 'Progressive_Disease', 2.1, 8.4, 'Grade3_Diarrhea', 'KRAS_G12C_POS', 71, 'M'),
('R005', 'LA-2024-001', 'PAT-10238', 'SITE-US-001', 'Cohort_B', 'ARM_A', 'Partial_Response', 9.8, 16.1, 'Grade2_Rash', 'KRAS_G12C_POS', 45, 'F'),
('R006', 'LA-2024-001', 'PAT-10239', 'SITE-DE-001', 'Cohort_B', 'ARM_B', 'Stable_Disease', 6.4, 13.2, 'Grade1_Fatigue', 'KRAS_G12C_POS', 67, 'M'),
('R007', 'LA-2024-001', 'PAT-10240', 'SITE-DE-001', 'Cohort_A', 'ARM_A', 'Partial_Response', 7.9, 15.8, 'Grade2_Nausea', 'KRAS_G12C_POS', 59, 'F'),
('R008', 'LA-2024-001', 'PAT-10241', 'SITE-FR-001', 'Cohort_B', 'ARM_B', 'Progressive_Disease', 3.2, 9.1, 'Grade2_Elevated_ALT', 'KRAS_G12C_POS', 73, 'M');

-- Verify data
SELECT * FROM CLINICAL_TRIAL_RESULTS;


-- ============================================================================
-- SECTION 2: DATA CLASSIFICATION WITH TAGS
-- ============================================================================

/*
Tags enable data classification and serve as the foundation for 
policy-based access control (Data Contracts concept).
*/

-- Create tag schema
CREATE SCHEMA IF NOT EXISTS LIFEARC_POC.GOVERNANCE;

-- Create classification tags
CREATE OR REPLACE TAG LIFEARC_POC.GOVERNANCE.DATA_SENSITIVITY
    ALLOWED_VALUES 'PUBLIC', 'INTERNAL', 'CONFIDENTIAL', 'HIGHLY_CONFIDENTIAL'
    COMMENT = 'Data sensitivity classification per LifeArc data policy';

CREATE OR REPLACE TAG LIFEARC_POC.GOVERNANCE.DATA_DOMAIN
    ALLOWED_VALUES 'CLINICAL', 'GENOMICS', 'COMPOUND', 'OPERATIONAL'
    COMMENT = 'Business domain classification';

CREATE OR REPLACE TAG LIFEARC_POC.GOVERNANCE.PII_TYPE
    ALLOWED_VALUES 'PATIENT_ID', 'DATE_OF_BIRTH', 'AGE', 'CONTACT_INFO', 'NONE'
    COMMENT = 'Type of personally identifiable information';

CREATE OR REPLACE TAG LIFEARC_POC.GOVERNANCE.RETENTION_PERIOD
    ALLOWED_VALUES '1_YEAR', '5_YEARS', '10_YEARS', 'INDEFINITE'
    COMMENT = 'Data retention requirement';

-- Apply tags to table
ALTER TABLE LIFEARC_POC.DATA_SHARING.CLINICAL_TRIAL_RESULTS
SET TAG LIFEARC_POC.GOVERNANCE.DATA_SENSITIVITY = 'CONFIDENTIAL',
    LIFEARC_POC.GOVERNANCE.DATA_DOMAIN = 'CLINICAL',
    LIFEARC_POC.GOVERNANCE.RETENTION_PERIOD = '10_YEARS';

-- Apply tags to sensitive columns
ALTER TABLE LIFEARC_POC.DATA_SHARING.CLINICAL_TRIAL_RESULTS
MODIFY COLUMN patient_id 
SET TAG LIFEARC_POC.GOVERNANCE.PII_TYPE = 'PATIENT_ID';

ALTER TABLE LIFEARC_POC.DATA_SHARING.CLINICAL_TRIAL_RESULTS
MODIFY COLUMN patient_age 
SET TAG LIFEARC_POC.GOVERNANCE.PII_TYPE = 'AGE';

-- Query tags on objects
SELECT * FROM TABLE(INFORMATION_SCHEMA.TAG_REFERENCES(
    'LIFEARC_POC.DATA_SHARING.CLINICAL_TRIAL_RESULTS', 
    'TABLE'
));


-- ============================================================================
-- SECTION 3: COLUMN-LEVEL MASKING POLICIES
-- ============================================================================

/*
Dynamic Data Masking ensures sensitive columns are automatically masked
based on the querying user's role - without creating separate views.
*/

-- Create masking policy for Patient IDs
CREATE OR REPLACE MASKING POLICY LIFEARC_POC.GOVERNANCE.MASK_PATIENT_ID AS
(val VARCHAR) RETURNS VARCHAR ->
    CASE
        -- Full access for specific roles
        WHEN CURRENT_ROLE() IN ('ACCOUNTADMIN', 'CLINICAL_DATA_ADMIN') THEN val
        -- Partial masking for analysts (show last 4 chars)
        WHEN CURRENT_ROLE() IN ('CLINICAL_ANALYST') THEN 'PAT-XXXX-' || RIGHT(val, 4)
        -- Full masking for others
        ELSE '***MASKED***'
    END;

-- Create masking policy for Age (show age range instead of exact age)
CREATE OR REPLACE MASKING POLICY LIFEARC_POC.GOVERNANCE.MASK_AGE AS
(val INT) RETURNS VARCHAR ->
    CASE
        WHEN CURRENT_ROLE() IN ('ACCOUNTADMIN', 'CLINICAL_DATA_ADMIN') THEN val::VARCHAR
        WHEN val < 40 THEN '<40'
        WHEN val BETWEEN 40 AND 49 THEN '40-49'
        WHEN val BETWEEN 50 AND 59 THEN '50-59'
        WHEN val BETWEEN 60 AND 69 THEN '60-69'
        WHEN val >= 70 THEN '70+'
        ELSE 'UNKNOWN'
    END;

-- Apply masking policies to columns
ALTER TABLE LIFEARC_POC.DATA_SHARING.CLINICAL_TRIAL_RESULTS
MODIFY COLUMN patient_id 
SET MASKING POLICY LIFEARC_POC.GOVERNANCE.MASK_PATIENT_ID;

ALTER TABLE LIFEARC_POC.DATA_SHARING.CLINICAL_TRIAL_RESULTS
MODIFY COLUMN patient_age 
SET MASKING POLICY LIFEARC_POC.GOVERNANCE.MASK_AGE;

-- Test masking (run as different roles to see different results)
SELECT result_id, patient_id, patient_age, response_category 
FROM LIFEARC_POC.DATA_SHARING.CLINICAL_TRIAL_RESULTS
LIMIT 5;


-- ============================================================================
-- SECTION 4: ROW ACCESS POLICIES
-- ============================================================================

/*
Row Access Policies restrict which rows a user can see based on their role
or other context. Perfect for multi-tenant or regional data access.
*/

-- Create mapping table for site access
CREATE OR REPLACE TABLE LIFEARC_POC.GOVERNANCE.SITE_ACCESS_MAPPING (
    role_name VARCHAR,
    allowed_site_id VARCHAR
);

-- Define which roles can access which sites
INSERT INTO LIFEARC_POC.GOVERNANCE.SITE_ACCESS_MAPPING VALUES
('UK_CLINICAL_TEAM', 'SITE-UK-001'),
('UK_CLINICAL_TEAM', 'SITE-UK-002'),
('US_CLINICAL_TEAM', 'SITE-US-001'),
('EU_CLINICAL_TEAM', 'SITE-DE-001'),
('EU_CLINICAL_TEAM', 'SITE-FR-001'),
('GLOBAL_CLINICAL_TEAM', 'SITE-UK-001'),
('GLOBAL_CLINICAL_TEAM', 'SITE-UK-002'),
('GLOBAL_CLINICAL_TEAM', 'SITE-US-001'),
('GLOBAL_CLINICAL_TEAM', 'SITE-DE-001'),
('GLOBAL_CLINICAL_TEAM', 'SITE-FR-001');

-- Create row access policy
CREATE OR REPLACE ROW ACCESS POLICY LIFEARC_POC.GOVERNANCE.SITE_BASED_ACCESS AS
(site_id VARCHAR) RETURNS BOOLEAN ->
    -- Admin sees everything
    CURRENT_ROLE() IN ('ACCOUNTADMIN', 'SYSADMIN')
    OR
    -- Check mapping table
    EXISTS (
        SELECT 1 FROM LIFEARC_POC.GOVERNANCE.SITE_ACCESS_MAPPING
        WHERE role_name = CURRENT_ROLE()
        AND allowed_site_id = site_id
    );

-- Apply row access policy
-- ALTER TABLE LIFEARC_POC.DATA_SHARING.CLINICAL_TRIAL_RESULTS
-- ADD ROW ACCESS POLICY LIFEARC_POC.GOVERNANCE.SITE_BASED_ACCESS ON (site_id);

-- Note: Uncomment above after creating the appropriate roles


-- ============================================================================
-- SECTION 5: SECURE DATA SHARING
-- ============================================================================

/*
Native Snowflake Secure Data Sharing allows sharing data with external 
partners WITHOUT copying data. The data stays in LifeArc's account.
*/

-- Create a secure view for sharing (adds an extra layer of control)
CREATE OR REPLACE SECURE VIEW LIFEARC_POC.DATA_SHARING.CLINICAL_RESULTS_PARTNER_VIEW AS
SELECT 
    result_id,
    trial_id,
    -- patient_id is automatically masked by masking policy
    patient_id AS masked_patient_id,
    site_id,
    cohort,
    treatment_arm,
    response_category,
    pfs_months,
    os_months,
    -- Aggregate adverse events (less granular for partners)
    CASE 
        WHEN adverse_events LIKE 'Grade3%' THEN 'Severe'
        WHEN adverse_events LIKE 'Grade2%' THEN 'Moderate'
        WHEN adverse_events LIKE 'Grade1%' THEN 'Mild'
        ELSE 'None'
    END AS adverse_event_severity,
    biomarker_status,
    -- Age is automatically masked by masking policy
    patient_age AS age_range,
    patient_sex
FROM LIFEARC_POC.DATA_SHARING.CLINICAL_TRIAL_RESULTS
WHERE trial_id = 'LA-2024-001';  -- Only share specific trial

-- Create a share for external partner (e.g., CRO)
-- CREATE OR REPLACE SHARE LIFEARC_CRO_PARTNER_SHARE;

-- Add objects to the share
-- GRANT USAGE ON DATABASE LIFEARC_POC TO SHARE LIFEARC_CRO_PARTNER_SHARE;
-- GRANT USAGE ON SCHEMA LIFEARC_POC.DATA_SHARING TO SHARE LIFEARC_CRO_PARTNER_SHARE;
-- GRANT SELECT ON VIEW LIFEARC_POC.DATA_SHARING.CLINICAL_RESULTS_PARTNER_VIEW 
--     TO SHARE LIFEARC_CRO_PARTNER_SHARE;

-- Add consumer account to the share
-- ALTER SHARE LIFEARC_CRO_PARTNER_SHARE ADD ACCOUNTS = '<partner_account_locator>';

-- Show share details
-- SHOW SHARES;


-- ============================================================================
-- SECTION 6: DATA ACCESS AUDITING
-- ============================================================================

/*
Track all access to sensitive data for compliance and audit purposes.
*/

-- Create audit log table
CREATE OR REPLACE TABLE LIFEARC_POC.GOVERNANCE.DATA_ACCESS_AUDIT_LOG (
    audit_id VARCHAR DEFAULT UUID_STRING(),
    query_id VARCHAR,
    user_name VARCHAR,
    role_name VARCHAR,
    query_text TEXT,
    tables_accessed ARRAY,
    query_start_time TIMESTAMP_NTZ,
    execution_status VARCHAR,
    rows_returned INT,
    created_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

-- Query to populate audit log from QUERY_HISTORY (run periodically)
-- This captures all queries against clinical data tables
INSERT INTO LIFEARC_POC.GOVERNANCE.DATA_ACCESS_AUDIT_LOG
(query_id, user_name, role_name, query_text, query_start_time, 
 execution_status, rows_returned)
SELECT 
    query_id,
    user_name,
    role_name,
    query_text,
    start_time,
    execution_status,
    rows_produced
FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY
WHERE LOWER(query_text) LIKE '%clinical_trial_results%'
  AND start_time > DATEADD(day, -7, CURRENT_TIMESTAMP())
  AND query_type = 'SELECT'
ORDER BY start_time DESC
LIMIT 100;

-- View recent access
SELECT 
    user_name,
    role_name,
    SUBSTRING(query_text, 1, 100) AS query_preview,
    query_start_time,
    rows_returned
FROM LIFEARC_POC.GOVERNANCE.DATA_ACCESS_AUDIT_LOG
ORDER BY query_start_time DESC
LIMIT 10;

-- Audit summary by user
SELECT 
    user_name,
    role_name,
    COUNT(*) AS query_count,
    SUM(rows_returned) AS total_rows_accessed,
    MIN(query_start_time) AS first_access,
    MAX(query_start_time) AS last_access
FROM LIFEARC_POC.GOVERNANCE.DATA_ACCESS_AUDIT_LOG
GROUP BY user_name, role_name
ORDER BY query_count DESC;


-- ============================================================================
-- SECTION 7: DATA CONTRACTS SUMMARY VIEW
-- ============================================================================

/*
Create a governance dashboard view that shows the "data contract" for each table.
*/

CREATE OR REPLACE VIEW LIFEARC_POC.GOVERNANCE.DATA_CONTRACTS_SUMMARY AS
WITH tagged_tables AS (
    SELECT 
        object_database,
        object_schema,
        object_name,
        tag_name,
        tag_value
    FROM TABLE(INFORMATION_SCHEMA.TAG_REFERENCES_ALL_COLUMNS(
        'LIFEARC_POC.DATA_SHARING.CLINICAL_TRIAL_RESULTS',
        'TABLE'
    ))
),
table_tags AS (
    SELECT 
        object_name,
        MAX(CASE WHEN tag_name = 'DATA_SENSITIVITY' THEN tag_value END) AS sensitivity,
        MAX(CASE WHEN tag_name = 'DATA_DOMAIN' THEN tag_value END) AS domain,
        MAX(CASE WHEN tag_name = 'RETENTION_PERIOD' THEN tag_value END) AS retention
    FROM tagged_tables
    GROUP BY object_name
)
SELECT 
    'CLINICAL_TRIAL_RESULTS' AS table_name,
    'CONFIDENTIAL' AS data_sensitivity,
    'CLINICAL' AS data_domain,
    '10_YEARS' AS retention_period,
    'MASK_PATIENT_ID, MASK_AGE' AS masking_policies,
    'SITE_BASED_ACCESS' AS row_access_policy,
    'Active' AS share_status,
    CURRENT_TIMESTAMP() AS contract_updated_at;

SELECT * FROM LIFEARC_POC.GOVERNANCE.DATA_CONTRACTS_SUMMARY;


-- ============================================================================
-- SECTION 8: EXTERNAL PARTNER DATA INGESTION PATTERNS
-- ============================================================================

/*
For partners providing data via physical media or cloud uploads.
Pattern: Secure staged ingestion with validation.
*/

-- Create stage for partner data uploads
CREATE OR REPLACE STAGE LIFEARC_POC.DATA_SHARING.PARTNER_DATA_STAGE
    DIRECTORY = (ENABLE = TRUE)
    COMMENT = 'Stage for external partner data uploads';

-- Create staging table with metadata tracking
CREATE OR REPLACE TABLE LIFEARC_POC.DATA_SHARING.PARTNER_DATA_STAGING (
    file_name VARCHAR,
    file_upload_time TIMESTAMP_NTZ,
    partner_id VARCHAR,
    data_type VARCHAR,
    raw_data VARIANT,
    validation_status VARCHAR DEFAULT 'PENDING',
    validation_errors VARIANT,
    processed_at TIMESTAMP_NTZ,
    created_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

-- Example: Load partner data from stage
-- COPY INTO LIFEARC_POC.DATA_SHARING.PARTNER_DATA_STAGING
-- FROM @LIFEARC_POC.DATA_SHARING.PARTNER_DATA_STAGE
-- FILE_FORMAT = (TYPE = JSON)
-- ON_ERROR = CONTINUE;

-- Validation stream for data quality checks
CREATE OR REPLACE STREAM LIFEARC_POC.DATA_SHARING.PARTNER_DATA_STREAM
ON TABLE LIFEARC_POC.DATA_SHARING.PARTNER_DATA_STAGING;


-- ============================================================================
-- CLEANUP (Run if needed)
-- ============================================================================

/*
-- Remove masking policies (must unset before dropping)
ALTER TABLE LIFEARC_POC.DATA_SHARING.CLINICAL_TRIAL_RESULTS
MODIFY COLUMN patient_id UNSET MASKING POLICY;

ALTER TABLE LIFEARC_POC.DATA_SHARING.CLINICAL_TRIAL_RESULTS
MODIFY COLUMN patient_age UNSET MASKING POLICY;

-- Drop policies
DROP MASKING POLICY IF EXISTS LIFEARC_POC.GOVERNANCE.MASK_PATIENT_ID;
DROP MASKING POLICY IF EXISTS LIFEARC_POC.GOVERNANCE.MASK_AGE;
DROP ROW ACCESS POLICY IF EXISTS LIFEARC_POC.GOVERNANCE.SITE_BASED_ACCESS;

-- Drop tags
DROP TAG IF EXISTS LIFEARC_POC.GOVERNANCE.DATA_SENSITIVITY;
DROP TAG IF EXISTS LIFEARC_POC.GOVERNANCE.DATA_DOMAIN;
DROP TAG IF EXISTS LIFEARC_POC.GOVERNANCE.PII_TYPE;
DROP TAG IF EXISTS LIFEARC_POC.GOVERNANCE.RETENTION_PERIOD;

-- Drop share
DROP SHARE IF EXISTS LIFEARC_CRO_PARTNER_SHARE;
*/


-- ============================================================================
-- DEMO SCRIPT - WALKTHROUGH ORDER
-- ============================================================================

/*
1. Show sample clinical trial data (SELECT * FROM CLINICAL_TRIAL_RESULTS)
2. Demonstrate data classification with tags
3. Apply and test masking policies (show different views by role)
4. Explain row access policies for regional data access
5. Create and configure secure data share
6. Show audit capabilities
7. Review data contracts summary view
8. Discuss partner data ingestion patterns

KEY MESSAGES FOR LIFEARC:
- Data never leaves your account (zero-copy sharing)
- Policies follow the data (no separate views needed)
- Full audit trail for compliance
- Flexible access control (row, column, role-based)
- Tags enable automated policy enforcement
*/
