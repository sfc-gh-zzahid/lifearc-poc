/*
================================================================================
LifeArc POC - SNOWFLAKE-UNIQUE DIFFERENTIATORS
================================================================================
This script demonstrates capabilities that are UNIQUE to Snowflake and cannot 
be easily replicated in Databricks or Microsoft Fabric.

Why Snowflake for Life Sciences?
1. SECURE DATA SHARING - Zero-copy sharing with CROs, partners, regulators
2. DATA CLEAN ROOMS - Privacy-preserving collaboration without exposing PHI
3. INSTANT CLONING - Create dev/test environments in seconds, not hours
4. TIME TRAVEL - Query/restore data as of any point in last 90 days
5. CORTEX AI PRIVACY - LLMs run INSIDE Snowflake, data never leaves
6. NEAR-ZERO ADMIN - No indexes, no vacuum, no tuning
7. CROSS-CLOUD - Same platform on AWS, Azure, GCP
8. MARKETPLACE - Pre-built life sciences datasets ready to query

================================================================================
*/

USE DATABASE LIFEARC_POC;

-- ============================================================================
-- DIFFERENTIATOR 1: SECURE DATA SHARING
-- Zero-copy data sharing with external organizations
-- UNIQUE: Databricks Delta Sharing requires copying data
-- UNIQUE: Fabric requires Power BI or data export
-- ============================================================================

/*
SCENARIO: LifeArc needs to share clinical trial results with a CRO partner
for analysis. Traditional approach: Export CSV, encrypt, transfer, import.
Snowflake approach: Share live data, zero copies, instant access.

Why this matters for Life Sciences:
- CRO partnerships require data sharing
- Regulatory submissions need auditable data lineage
- Real-time collaboration without data movement = no stale data
*/

-- Create a secure share for CRO partner
CREATE OR REPLACE SHARE LIFEARC_CRO_SHARE
    COMMENT = 'Clinical trial data for CRO partners - zero-copy, governed';

-- Grant access to specific tables (not entire database)
GRANT USAGE ON DATABASE LIFEARC_POC TO SHARE LIFEARC_CRO_SHARE;
GRANT USAGE ON SCHEMA LIFEARC_POC.DATA_SHARING TO SHARE LIFEARC_CRO_SHARE;
GRANT SELECT ON LIFEARC_POC.DATA_SHARING.CLINICAL_RESULTS_PARTNER_VIEW TO SHARE LIFEARC_CRO_SHARE;

-- The partner sees LIVE data, not a copy
-- Changes are instant, audit trail is complete
-- No ETL, no data movement, no security risk

-- WHY SNOWFLAKE: 
-- Databricks Delta Sharing creates COPIES of data to recipient
-- Fabric requires exporting data or using Power BI (not SQL access)
-- Snowflake shares LIVE data with zero copies

-- ============================================================================
-- DIFFERENTIATOR 2: ZERO-COPY CLONING
-- Create dev/test environments in SECONDS, not hours
-- UNIQUE: Instant clone of multi-TB databases
-- ============================================================================

/*
SCENARIO: Data science team needs a copy of production data for model training.
Traditional approach: Full copy takes hours, costs double storage.
Snowflake approach: Clone in 3 seconds, pay only for changes.

Why this matters for Life Sciences:
- Data scientists need production-like data
- Compliance requires isolated test environments  
- Budget constraints limit data duplication
*/

-- Clone entire database in seconds (even if it's 10TB)
CREATE OR REPLACE DATABASE LIFEARC_DEV CLONE LIFEARC_POC;

-- Clone specific schema for testing
CREATE OR REPLACE SCHEMA LIFEARC_POC.ML_DEV CLONE LIFEARC_POC.ML_DEMO;

-- WHY THIS IS INSTANT:
-- No data is copied! Snowflake uses metadata pointers
-- You only pay for data that CHANGES in the clone
-- Databricks: Full copy required (Delta Clone is shallow but limited)
-- Fabric: Full copy required

-- Clean up demo clone
DROP DATABASE IF EXISTS LIFEARC_DEV;
DROP SCHEMA IF EXISTS LIFEARC_POC.ML_DEV;

-- ============================================================================
-- DIFFERENTIATOR 3: TIME TRAVEL
-- Query data as it existed at any point in the past
-- UNIQUE: Up to 90 days of history with no setup
-- ============================================================================

/*
SCENARIO: A data quality issue is discovered. Need to see what the data 
looked like before the problematic update yesterday.
Traditional approach: Restore from backup (hours), hope you have right backup.
Snowflake approach: Query any point in time instantly.

Why this matters for Life Sciences:
- GxP compliance requires audit trails
- Regulatory submissions need point-in-time data snapshots
- Data quality investigations need before/after comparison
*/

-- Query data as it was 1 hour ago
SELECT * 
FROM LIFEARC_POC.AI_DEMO.COMPOUND_PIPELINE_ANALYSIS
AT (OFFSET => -3600);  -- 1 hour ago in seconds

-- Query data as it was at specific timestamp
SELECT *
FROM LIFEARC_POC.AI_DEMO.COMPOUND_PIPELINE_ANALYSIS  
AT (TIMESTAMP => '2026-01-19 10:00:00'::TIMESTAMP);

-- Compare current vs historical state
SELECT 
    'Current' AS version,
    COUNT(*) AS row_count,
    AVG(molecular_weight) AS avg_mw
FROM LIFEARC_POC.AI_DEMO.COMPOUND_PIPELINE_ANALYSIS
UNION ALL
SELECT 
    '1 hour ago',
    COUNT(*),
    AVG(molecular_weight)
FROM LIFEARC_POC.AI_DEMO.COMPOUND_PIPELINE_ANALYSIS AT (OFFSET => -3600);

-- Restore accidentally deleted data (UNDROP)
-- DROP TABLE important_table;
-- UNDROP TABLE important_table;  -- Instantly recovered!

-- WHY SNOWFLAKE:
-- No backup configuration required - automatic
-- Query ANY point in time, not just backup snapshots
-- Databricks: Delta Time Travel exists but max 30 days, requires config
-- Fabric: Point-in-time restore is manual, requires backup setup

-- ============================================================================
-- DIFFERENTIATOR 4: CORTEX AI - DATA NEVER LEAVES SNOWFLAKE
-- LLMs run INSIDE Snowflake platform
-- UNIQUE: PHI/PII never sent to external API
-- ============================================================================

/*
SCENARIO: Need to analyze clinical notes with AI, but notes contain PHI.
Traditional approach: Send data to OpenAI API (compliance violation!)
Snowflake approach: AI runs inside platform, PHI never leaves.

Why this matters for Life Sciences:
- HIPAA prohibits sending PHI to external services
- GxP requires data sovereignty
- Regulatory risk of external AI is enormous
*/

-- AI analysis of clinical notes - data STAYS in Snowflake
SELECT 
    trial_id,
    protocol_data:title::VARCHAR AS trial_title,
    SNOWFLAKE.CORTEX.COMPLETE(
        'llama3.1-70b',
        'Summarize the key patient safety considerations for this trial protocol: ' || 
        protocol_data::VARCHAR
    ) AS safety_summary
FROM LIFEARC_POC.UNSTRUCTURED_DATA.CLINICAL_TRIALS
LIMIT 1;

-- Analyze research documents without data leaving platform
SELECT 
    doc_title,
    SNOWFLAKE.CORTEX.COMPLETE(
        'llama3.1-70b',
        'Extract the main competitive threats from this research: ' || full_text
    ) AS competitive_analysis
FROM LIFEARC_POC.AI_DEMO.RESEARCH_INTELLIGENCE
WHERE competitive_impact = 'High'
LIMIT 2;

-- WHY SNOWFLAKE:
-- Cortex runs INSIDE Snowflake - data never leaves
-- No API keys to manage, no external calls
-- Databricks: DBRX/external LLMs require data to leave compute boundary
-- Fabric: Azure OpenAI requires data sent to Azure AI service
-- For HIPAA/GxP compliance, Snowflake Cortex is superior

-- ============================================================================
-- DIFFERENTIATOR 5: INSTANT ELASTICITY
-- Scale compute up/down in seconds, pay per second
-- UNIQUE: No cluster spin-up time, auto-suspend
-- ============================================================================

/*
SCENARIO: Large genomic analysis needs 4XL warehouse for 10 minutes.
Traditional approach: Provision large cluster, keep it running (expensive)
Snowflake approach: Scale up for query, auto-suspend after 60 seconds.

Why this matters for Life Sciences:
- Genomic queries are bursty (large, infrequent)
- Budget requires right-sizing compute
- No one should babysit cluster sizes
*/

-- Scale up warehouse for heavy analysis
ALTER WAREHOUSE COMPUTE_WH SET WAREHOUSE_SIZE = 'X-LARGE';

-- Run heavy query (genomic analysis, ML training, etc.)
-- ... query runs ...

-- Warehouse auto-suspends when idle (default 60 seconds)
-- No manual intervention needed
-- Pay ONLY for seconds used

-- Scale back down
ALTER WAREHOUSE COMPUTE_WH SET WAREHOUSE_SIZE = 'X-SMALL';

-- WHY SNOWFLAKE:
-- Resize takes SECONDS, not minutes
-- Auto-suspend means zero cost when idle
-- Per-second billing (not per-hour like some competitors)
-- Databricks: Cluster resize takes 5-10 minutes
-- Fabric: Capacity is provisioned, not elastic per-query

-- ============================================================================
-- DIFFERENTIATOR 6: DATA CLASSIFICATION & GOVERNANCE
-- Native object tagging for compliance
-- UNIQUE: Built-in, not bolt-on
-- ============================================================================

/*
SCENARIO: Compliance team needs to identify all tables containing PHI.
Traditional approach: Manual documentation, spreadsheets, hope it's accurate.
Snowflake approach: Tag objects, query tags, automatic policy enforcement.

Why this matters for Life Sciences:
- 21 CFR Part 11 requires data classification
- HIPAA requires PHI identification
- Auditors need queryable compliance evidence
*/

-- Create classification tags
CREATE OR REPLACE TAG LIFEARC_POC.GOVERNANCE.DATA_CLASSIFICATION
    ALLOWED_VALUES 'PHI', 'PII', 'CONFIDENTIAL', 'PUBLIC';

CREATE OR REPLACE TAG LIFEARC_POC.GOVERNANCE.DATA_RETENTION
    ALLOWED_VALUES '7_YEARS', '15_YEARS', 'PERMANENT';

-- Apply tags to tables and columns
ALTER TABLE LIFEARC_POC.DATA_SHARING.CLINICAL_TRIAL_RESULTS 
    SET TAG LIFEARC_POC.GOVERNANCE.DATA_CLASSIFICATION = 'PHI';

ALTER TABLE LIFEARC_POC.DATA_SHARING.CLINICAL_TRIAL_RESULTS 
    MODIFY COLUMN patient_id 
    SET TAG LIFEARC_POC.GOVERNANCE.DATA_CLASSIFICATION = 'PII';

-- Query: "Show me all PHI data in my account"
SELECT 
    tag_database,
    tag_schema,
    tag_name,
    tag_value,
    object_database,
    object_schema,
    object_name,
    column_name,
    domain
FROM SNOWFLAKE.ACCOUNT_USAGE.TAG_REFERENCES
WHERE tag_name = 'DATA_CLASSIFICATION' 
  AND tag_value = 'PHI';

-- WHY SNOWFLAKE:
-- Native tagging queryable via SQL
-- Tags can trigger automatic masking policies
-- Databricks: Unity Catalog has tagging but less mature
-- Fabric: Purview integration is separate product

-- ============================================================================
-- DIFFERENTIATOR 7: SNOWFLAKE MARKETPLACE
-- Pre-built datasets ready to query instantly
-- UNIQUE: No ETL, no data movement
-- ============================================================================

/*
SCENARIO: Need drug-gene interaction data for analysis.
Traditional approach: License data, negotiate contract, wait for delivery, ETL
Snowflake approach: Get from Marketplace, query in 5 minutes.

Why this matters for Life Sciences:
- Reference data (genes, drugs, ontologies) is expensive to maintain
- External data enriches internal analytics
- Speed of access = speed of discovery
*/

-- Example: Access Marketplace data (hypothetical - would need actual listing)
-- These are LIVE shares from data providers, not copies

-- Drug interaction database
-- SELECT * FROM MARKETPLACE.DRUGBANK.DRUG_INTERACTIONS WHERE drug_name = 'Aspirin';

-- Gene ontology
-- SELECT * FROM MARKETPLACE.GENE_ONTOLOGY.GO_TERMS WHERE term LIKE '%DNA repair%';

-- Clinical trial registries  
-- SELECT * FROM MARKETPLACE.CLINICALTRIALS_GOV.ACTIVE_TRIALS WHERE condition = 'NSCLC';

-- WHY SNOWFLAKE:
-- Marketplace data is LIVE, not a copy
-- No ETL pipeline to maintain
-- Instant access to 2000+ datasets
-- Databricks: Marketplace exists but smaller, requires Delta format
-- Fabric: No equivalent marketplace

-- ============================================================================
-- SUMMARY: Why Snowflake for LifeArc?
-- ============================================================================

/*
SNOWFLAKE-UNIQUE VALUE PROPOSITION FOR LIFE SCIENCES:

1. SECURE DATA SHARING
   - Share trial data with CROs without copying
   - Real-time collaboration with partners
   - Auditable lineage for regulatory submissions
   
2. ZERO-COPY CLONING  
   - Dev/test environments in seconds
   - Data scientists get production-like data instantly
   - Pay only for changes, not full copies

3. TIME TRAVEL
   - GxP-compliant audit trail built-in
   - Point-in-time queries for regulatory snapshots
   - Instant recovery from data quality issues

4. CORTEX AI PRIVACY
   - LLMs on PHI without compliance violation
   - No external API calls, data never leaves
   - HIPAA-safe AI analysis

5. INSTANT ELASTICITY
   - Scale for genomic queries, pay per second
   - Auto-suspend eliminates idle costs
   - No cluster management overhead

6. NATIVE GOVERNANCE
   - Data classification tags queryable via SQL
   - Automatic policy enforcement
   - Compliance evidence at fingertips

7. MARKETPLACE
   - Reference data ready to query
   - No ETL for external datasets
   - Live data, not stale copies

COMPETITORS CANNOT MATCH THIS COMBINATION.

Databricks: Good for ML, but data sharing copies data, no native Streamlit,
            cluster management overhead, AI requires external calls.

Fabric: Good for Microsoft shops, but no zero-copy sharing, no Time Travel,
        AI requires Azure OpenAI (data leaves), no developer-friendly apps.

SNOWFLAKE = THE PLATFORM FOR REGULATED LIFE SCIENCES DATA
*/
