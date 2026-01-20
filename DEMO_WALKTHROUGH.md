# LifeArc POC - 4-Hour Demo Walkthrough

## POC Overview

**Duration:** 4 hours (2 sessions of 2 hours each)  
**Audience:** Life Sciences Data Platform Team, IT Leadership, Data Scientists  
**Objective:** Demonstrate Snowflake capabilities that are unique and differentiated vs Databricks/Fabric

---

## Session Structure

| Session | Duration | Focus Area |
|---------|----------|------------|
| **Session 1** | 2 hours | Intelligence, Governance, Data Sharing |
| **Session 2** | 2 hours | ML/AI Pipeline, DBT, Architecture Deep Dive |

---

## Pre-POC Validation (Run 30 min before)

```sql
-- Run the full validation script
USE DATABASE LIFEARC_POC;
USE WAREHOUSE COMPUTE_WH;

-- Quick health check (all should return data)
SELECT COUNT(*) as compounds FROM AI_DEMO.COMPOUND_PIPELINE_ANALYSIS;  -- Expected: 29
SELECT COUNT(*) as trials FROM DATA_SHARING.CLINICAL_TRIAL_RESULTS;   -- Expected: 10,008
SELECT COUNT(*) as research FROM AI_DEMO.RESEARCH_INTELLIGENCE;       -- Expected: 8

-- Verify critical services
SHOW STREAMLITS IN DATABASE LIFEARC_POC;           -- Expected: 2 apps
SHOW SHARES LIKE 'LIFEARC%';                       -- Expected: 1 share
SHOW SEMANTIC VIEWS IN DATABASE LIFEARC_POC;       -- Expected: 1 view
SHOW SNOWFLAKE.ML.CLASSIFICATION IN SCHEMA ML_DEMO; -- Expected: 1 model
```

---

# SESSION 1: Intelligence & Governance (2 hours)

## Module 1.1: Opening & Context (15 min)

### The LifeArc Challenge

**Talk Track:**
> "LifeArc is a medical research charity with a $2.5B portfolio spanning 29 compounds in development. Today's challenge isn't collecting data - it's extracting insights from it. Executives need to answer questions like 'Why are CNS compounds failing?' without waiting 2 weeks for an analyst report. Data scientists need governed ML pipelines that satisfy regulatory requirements. And CRO partners need access to trial data without copying it."

### Show the Executive Summary

```sql
-- The baseline: What does LifeArc's portfolio look like?
SELECT * FROM LIFEARC_POC.AI_DEMO.EXECUTIVE_PIPELINE_SUMMARY;
```

**Key Numbers to Highlight:**
- $903M total investment
- 29 compounds across 6 therapeutic areas
- 45% drug-like rate (industry benchmark: 60%)
- Question: "Why isn't this higher?"

---

## Module 1.2: Snowflake Intelligence - Talk to Your Data (30 min)

### Demo: The Intelligence App

**Open:** Streamlit app `INTELLIGENCE_DEMO`

**Navigate:** Snowsight → Apps → LIFEARC_POC.AI_DEMO.INTELLIGENCE_DEMO

### The 5 "Why" Questions

#### Question 1: "Why are compounds failing drug-likeness screening?"

**Expected Insight:**
- CNS compounds: 0% drug-like (vs 75% for Oncology)
- Root cause: LogP values exceeding 5.0
- **Action:** Adjust medicinal chemistry guidelines for CNS

**SQL Backup:**
```sql
SELECT 
    therapeutic_area,
    COUNT(*) as total_compounds,
    SUM(CASE WHEN drug_likeness = 'drug_like' THEN 1 ELSE 0 END) as drug_like,
    ROUND(SUM(CASE WHEN drug_likeness = 'drug_like' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 1) as pct
FROM AI_DEMO.COMPOUND_PIPELINE_ANALYSIS
GROUP BY therapeutic_area
ORDER BY pct DESC;
```

#### Question 2: "Why is BRCA1 outperforming KRAS in trials?"

**Expected Insight:**
- BRCA1: 52.9% response rate vs KRAS: 32.1%
- Key differentiator: ctDNA confirmation (100% vs 33%)
- **Action:** Mandate ctDNA for all KRAS patients

**SQL Backup:**
```sql
SELECT 
    target_gene,
    COUNT(*) as patients,
    ROUND(AVG(CASE WHEN response_category IN ('Complete_Response', 'Partial_Response') THEN 1 ELSE 0 END) * 100, 1) as response_rate_pct,
    ROUND(AVG(CASE WHEN ctdna_confirmation = 'YES' THEN 1 ELSE 0 END) * 100, 1) as ctdna_usage_pct
FROM DATA_SHARING.CLINICAL_TRIAL_RESULTS
GROUP BY target_gene
ORDER BY response_rate_pct DESC;
```

#### Question 3: "How should we reallocate R&D budget?"

**Expected Insight:**
- Oncology ROI: 21.6x (best performing)
- CNS ROI: 2.8x (underperforming)
- Recommendation: Shift $107M from CNS to Oncology

**SQL Backup:**
```sql
SELECT * FROM AI_DEMO.PROGRAM_ROI_SUMMARY ORDER BY roi_multiple DESC;
```

#### Question 4: Research Intelligence Search

**Type in search:** "EGFR resistance mechanisms"

**Expected Results:**
- C797S mutation (42% of patients)
- MET bypass mechanism (28% of patients)
- **Action:** Consider 4th-gen inhibitor partnerships

**Technical Note (for IT audience):** "This uses Cortex Search - a native vector database. No external service needed."

```sql
-- The query behind the search
SELECT SNOWFLAKE.CORTEX.SEARCH_PREVIEW(
    'LIFEARC_POC.AI_DEMO.RESEARCH_SEARCH_SERVICE',
    '{"query": "EGFR resistance mechanisms", "columns": ["doc_title", "key_finding"], "limit": 3}'
) AS search_results;
```

#### Question 5: Board Meeting Priorities

**Click:** Board Priorities tab

**Show:**
- Top 3 candidates ranked by combined success probability + market opportunity
- Olaparib-LA: 85% success, $1.2B peak sales
- OmoMYC-LA: 78% success, $3.5B peak sales

### The HIPAA-Safe Differentiator

**Key Message:**
> "Everything you just saw - the AI analysis, the semantic search - runs INSIDE Snowflake. Patient data never left the platform. This is impossible with Databricks or Fabric without sending data to external AI services."

**Demonstrate:**
```sql
-- This AI query keeps PHI inside Snowflake
SELECT SNOWFLAKE.CORTEX.COMPLETE(
    'llama3.1-70b',
    'Summarize the competitive threats to our EGFR program based on: ' || 
    (SELECT LISTAGG(key_finding, '. ') FROM AI_DEMO.RESEARCH_INTELLIGENCE WHERE target_gene = 'EGFR')
) AS ai_analysis;
```

---

## Module 1.3: Snowflake-Unique Capabilities (45 min)

### Capability 1: Zero-Copy Data Sharing (15 min)

**Talk Track:**
> "LifeArc works with CRO partners who need access to trial data. Traditional approach: extract, encrypt, transfer, load, maintain sync. Snowflake approach: share LIVE data with zero copies."

**Show the Share:**
```sql
-- View our existing share
DESC SHARE LIFEARC_CRO_SHARE;

-- View grants to the share
SHOW GRANTS TO SHARE LIFEARC_CRO_SHARE;

-- What partners see (the governed view)
SELECT COUNT(*) as shared_rows FROM DATA_SHARING.CLINICAL_RESULTS_PARTNER_VIEW;
-- This is filtered! Full table has 10,008 rows, partner sees ~2,000
```

**Create a Share Live (if time permits):**
```sql
-- Create a new share in seconds
CREATE SHARE IF NOT EXISTS DEMO_REGULATORY_SHARE
    COMMENT = 'Regulatory submission data for FDA';

-- Grant access
GRANT USAGE ON DATABASE LIFEARC_POC TO SHARE DEMO_REGULATORY_SHARE;
GRANT USAGE ON SCHEMA LIFEARC_POC.DATA_SHARING TO SHARE DEMO_REGULATORY_SHARE;
GRANT SELECT ON VIEW LIFEARC_POC.DATA_SHARING.CLINICAL_RESULTS_PARTNER_VIEW TO SHARE DEMO_REGULATORY_SHARE;

-- That's it! Partner can now access live data
-- Clean up
DROP SHARE IF EXISTS DEMO_REGULATORY_SHARE;
```

**Competitive Comparison:**
| Feature | Snowflake | Databricks | Fabric |
|---------|-----------|------------|--------|
| Zero-copy sharing | Yes | No (Delta Sharing copies) | No |
| Cross-cloud sharing | Yes | Limited | No |
| Governed views in shares | Yes | No | No |
| Real-time sync | Yes | Batch only | Batch only |

---

### Capability 2: Time Travel (10 min)

**Talk Track:**
> "For GxP compliance, you need complete audit trails. Snowflake retains 90 days of history by default - queryable with a simple syntax."

```sql
-- Current data
SELECT COUNT(*) as current_rows FROM AI_DEMO.COMPOUND_PIPELINE_ANALYSIS;

-- Data as it was 1 hour ago
SELECT COUNT(*) as one_hour_ago FROM AI_DEMO.COMPOUND_PIPELINE_ANALYSIS AT (OFFSET => -3600);

-- Data as it was yesterday
SELECT COUNT(*) as yesterday FROM AI_DEMO.COMPOUND_PIPELINE_ANALYSIS AT (TIMESTAMP => DATEADD('day', -1, CURRENT_TIMESTAMP()));

-- Show a specific historical state
SELECT * FROM AI_DEMO.COMPOUND_PIPELINE_ANALYSIS AT (OFFSET => -3600) LIMIT 5;
```

**The Undrop Demo:**
```sql
-- Create a test table
CREATE TABLE DEMO_DELETE_TEST AS SELECT * FROM AI_DEMO.COMPOUND_PIPELINE_ANALYSIS LIMIT 5;

-- Accidentally delete it
DROP TABLE DEMO_DELETE_TEST;

-- Oh no! But wait...
UNDROP TABLE DEMO_DELETE_TEST;

-- It's back!
SELECT COUNT(*) FROM DEMO_DELETE_TEST;

-- Clean up
DROP TABLE DEMO_DELETE_TEST;
```

**Key Message:** "No backup configuration needed. This is built in."

---

### Capability 3: Zero-Copy Cloning (10 min)

**Talk Track:**
> "Data scientists need production-like environments for testing. In traditional systems, this means copying terabytes of data. Watch this."

```sql
-- Clone the entire database (even if it's 10TB, this takes seconds)
CREATE DATABASE LIFEARC_DEV CLONE LIFEARC_POC;

-- Verify it worked
USE DATABASE LIFEARC_DEV;
SELECT COUNT(*) FROM AI_DEMO.COMPOUND_PIPELINE_ANALYSIS;
SELECT COUNT(*) FROM DATA_SHARING.CLINICAL_TRIAL_RESULTS;

-- Show it's truly independent
DROP TABLE LIFEARC_DEV.AI_DEMO.COMPOUND_PIPELINE_ANALYSIS;
-- Original is unaffected
SELECT COUNT(*) FROM LIFEARC_POC.AI_DEMO.COMPOUND_PIPELINE_ANALYSIS;

-- Clean up
DROP DATABASE LIFEARC_DEV;
USE DATABASE LIFEARC_POC;
```

**Cost Explanation:**
> "You only pay for data that CHANGES in the clone. A 10TB clone costs $0 until you modify it."

---

### Capability 4: Cortex AI Privacy (10 min)

**Talk Track:**
> "What if you need AI analysis on patient data? Most platforms require sending data to OpenAI or Azure OpenAI - which may violate HIPAA. Cortex runs INSIDE Snowflake."

```sql
-- AI analysis on patient data - HIPAA compliant
SELECT 
    patient_id,
    SNOWFLAKE.CORTEX.SENTIMENT(
        'Patient showed ' || response_category || ' after ' || treatment_arm || ' treatment'
    ) AS sentiment_analysis
FROM DATA_SHARING.CLINICAL_TRIAL_RESULTS
LIMIT 5;

-- Summarize trial outcomes
SELECT SNOWFLAKE.CORTEX.SUMMARIZE(
    (SELECT LISTAGG(
        'Patient ' || patient_id || ': ' || response_category || ' (' || treatment_arm || ')', 
        '. '
    ) FROM DATA_SHARING.CLINICAL_TRIAL_RESULTS WHERE target_gene = 'BRCA1' LIMIT 50)
) AS trial_summary;

-- Translation (for global trials)
SELECT SNOWFLAKE.CORTEX.TRANSLATE(
    'The patient showed complete response to combination therapy',
    'en', 'es'
) AS spanish_translation;
```

---

## Module 1.4: Data Governance Deep Dive (30 min)

### Data Classification Tags

**Talk Track:**
> "Regulatory compliance requires knowing what data you have and who can access it. Snowflake makes this queryable."

```sql
-- View our classification tags
SHOW TAGS IN SCHEMA GOVERNANCE;

-- See what's tagged as PHI
SELECT 
    object_database,
    object_schema,
    object_name,
    column_name,
    tag_value
FROM TABLE(LIFEARC_POC.INFORMATION_SCHEMA.TAG_REFERENCES_ALL_COLUMNS(
    'LIFEARC_POC.DATA_SHARING.CLINICAL_TRIAL_RESULTS',
    'TABLE'
))
WHERE tag_name = 'DATA_CLASSIFICATION';
```

### Masking Policies in Action

```sql
-- Show masking policies
SHOW MASKING POLICIES IN SCHEMA GOVERNANCE;

-- See how masking works per role
-- As ACCOUNTADMIN, we see real data
SELECT patient_id, patient_age FROM DATA_SHARING.CLINICAL_TRIAL_RESULTS LIMIT 3;

-- Show the policy definition
DESC MASKING POLICY GOVERNANCE.MASK_PATIENT_ID;
```

### Row Access Policies

```sql
-- Show row access policies
SHOW ROW ACCESS POLICIES IN SCHEMA GOVERNANCE;

-- Site access mapping
SELECT * FROM GOVERNANCE.SITE_ACCESS_MAPPING;

-- The policy ensures users only see their assigned sites
DESC ROW ACCESS POLICY GOVERNANCE.SITE_BASED_ACCESS;
```

### Audit Queries for Compliance

```sql
-- Who accessed what? (Last 24 hours)
SELECT 
    query_start_time,
    user_name,
    role_name,
    query_type,
    query_text
FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY
WHERE query_start_time > DATEADD('hour', -24, CURRENT_TIMESTAMP())
  AND query_text ILIKE '%CLINICAL_TRIAL_RESULTS%'
ORDER BY query_start_time DESC
LIMIT 10;
```

---

## Break (10 min)

---

# SESSION 2: ML/AI & Architecture (2 hours)

## Module 2.1: End-to-End ML Pipeline (45 min)

### Opening Context

**Talk Track:**
> "Life sciences ML has unique requirements: reproducibility for regulatory submissions, lineage tracking for compliance, and governance for PHI. Let me show you how Snowflake addresses all of these natively."

### Native Snowflake ML Components

| Component | What It Does | Why It Matters |
|-----------|--------------|----------------|
| **Feature Store** | Centralized, versioned features | Same features train & prod, reproducibility |
| **Model Registry** | Version control for models | Lifecycle management, aliases |
| **ML Functions** | Built-in classification, forecasting | No external tools needed |
| **ML Lineage** | End-to-end traceability | Regulatory submissions |

### Demo: ML Pipeline SQL

```sql
USE DATABASE LIFEARC_POC;
USE SCHEMA ML_DEMO;

-- 1. Feature Engineering Views
SELECT * FROM ML_FEATURE_STORE.PATIENT_CLINICAL_FEATURES_SOURCE LIMIT 5;
SELECT * FROM ML_FEATURE_STORE.TRIAL_AGGREGATE_FEATURES_SOURCE;

-- 2. Training Dataset (combines patient + trial features)
SELECT COUNT(*) as training_rows FROM ML_DEMO.TRAINING_DATASET;
SELECT * FROM ML_DEMO.TRAINING_DATASET LIMIT 5;

-- 3. The Native ML Model
SHOW SNOWFLAKE.ML.CLASSIFICATION IN SCHEMA ML_DEMO;

-- 4. Model Predictions
SELECT 
    patient_id,
    response_category as actual,
    prediction_result
FROM ML_DEMO.MODEL_PREDICTIONS
LIMIT 10;

-- 5. Feature Importance
SELECT CLINICAL_RESPONSE_MODEL!EXPLAIN_FEATURE_IMPORTANCE() AS feature_importance;
```

### Demo: Notebook Walkthrough (for Data Scientists)

**Open:** `notebooks/ml_lifecycle_complete.ipynb`

**Key Sections to Highlight:**

1. **Feature Store API** (Cell: feature-store-init)
```python
from snowflake.ml.feature_store import FeatureStore, Entity, FeatureView
fs = FeatureStore(session, database="LIFEARC_POC", name="ML_FEATURE_STORE")
```

2. **Entity Registration** (Cell: create-entities)
```python
patient_entity = Entity(name="PATIENT", join_keys=["PATIENT_ID"])
fs.register_entity(patient_entity)
```

3. **Model Registry** (Cell: log-model)
```python
from snowflake.ml.registry import Registry
registry = Registry(session)
model_version = registry.log_model(model, model_name="CLINICAL_RESPONSE_PREDICTOR", metrics={...})
model_version.set_alias("production")
```

**Key Message:**
> "This is the NATIVE Snowflake ML API - not Databricks MLflow, not Azure ML. The model, features, and lineage all stay within Snowflake governance."

### Model Monitoring & Drift Detection

```sql
-- View monitoring data
SELECT * FROM ML_DEMO.MODEL_MONITORING ORDER BY MONITORING_DATE DESC;

-- Check for prediction drift
SELECT * FROM ML_DEMO.PREDICTION_DRIFT;

-- The scheduled monitoring task
SHOW TASKS IN SCHEMA ML_DEMO;
```

---

## Module 2.2: Native DBT Integration (30 min)

### DBT in Snowflake

**Talk Track:**
> "LifeArc uses dbt for transformations. Snowflake has native dbt support - no external orchestrator, no dbt Cloud subscription required."

```sql
-- Show the dbt project
SHOW DBT PROJECTS IN DATABASE LIFEARC_POC;

-- Show Git repository sync
SHOW GIT REPOSITORIES IN DATABASE LIFEARC_POC;

-- Show versions (each git commit = a version)
SHOW VERSIONS IN DBT PROJECT LIFEARC_POC.PUBLIC.LIFEARC_DBT_PROJECT;
```

### DBT Model Layers

| Layer | Schema | Purpose | Example |
|-------|--------|---------|---------|
| **Bronze** | PUBLIC_BRONZE | Raw standardization | stg_compounds, stg_clinical_results |
| **Silver** | PUBLIC_SILVER | Business logic | int_compound_properties, int_trial_patient_outcomes |
| **Gold** | PUBLIC_GOLD | Analytics-ready | mart_compound_analysis, mart_trial_efficacy |

### Show DBT Output

```sql
-- Bronze layer (standardized raw)
SELECT * FROM PUBLIC_BRONZE.STG_COMPOUNDS LIMIT 5;

-- Silver layer (intermediate)
SELECT * FROM PUBLIC_SILVER.INT_COMPOUND_PROPERTIES LIMIT 5;

-- Gold layer (analytics marts)
SELECT * FROM PUBLIC_GOLD.MART_COMPOUND_ANALYSIS;
SELECT * FROM PUBLIC_GOLD.MART_TRIAL_EFFICACY;
```

### Run DBT (Live Demo)

```sql
-- Execute the dbt project
EXECUTE DBT PROJECT LIFEARC_DBT_PROJECT ARGS = 'build';

-- Or run specific models
EXECUTE DBT PROJECT LIFEARC_DBT_PROJECT ARGS = 'run --select mart_compound_analysis';

-- Run tests
EXECUTE DBT PROJECT LIFEARC_DBT_PROJECT ARGS = 'test';
```

---

## Module 2.3: Unstructured Data Handling (20 min)

### Snowflake for Life Sciences File Types

**Demo:** Open Streamlit app `UNSTRUCTURED_DATA_DEMO`

**Show:**

1. **FASTA Sequences**
```sql
-- Parse FASTA with Python UDF
SELECT 
    gene_name,
    LIFEARC_POC.UNSTRUCTURED_DATA.PARSE_FASTA(sequence_data):header::string as header,
    LENGTH(LIFEARC_POC.UNSTRUCTURED_DATA.PARSE_FASTA(sequence_data):sequence::string) as sequence_length
FROM UNSTRUCTURED_DATA.GENE_SEQUENCES;
```

2. **JSON Clinical Protocols**
```sql
-- Query nested JSON
SELECT 
    protocol_id,
    protocol_data:trial_name::string as trial_name,
    protocol_data:phase::string as phase,
    protocol_data:endpoints[0]::string as primary_endpoint
FROM UNSTRUCTURED_DATA.CLINICAL_TRIALS;
```

3. **AI Analysis of Documents**
```sql
-- Cortex analysis of research documents
SELECT 
    doc_title,
    SNOWFLAKE.CORTEX.SUMMARIZE(full_text) as ai_summary
FROM AI_DEMO.RESEARCH_INTELLIGENCE
LIMIT 3;
```

---

## Module 2.4: Architecture Deep Dive (20 min)

### Show Architecture Diagrams

**Open:** `ARCHITECTURE_DIAGRAMS.md`

**Key Diagrams to Present:**

1. **End-to-End Data Flow** - How data moves from source to insight
2. **ML Pipeline Architecture** - Feature Store → Training → Registry → Inference
3. **Governance Architecture** - Tags, masking, row access, audit
4. **Competitor Comparison** - Snowflake vs Databricks vs Fabric

### The 9 Snowflake Differentiators

| # | Capability | Snowflake | Databricks | Fabric |
|---|------------|-----------|------------|--------|
| 1 | Zero-Copy Sharing | Native | Delta Sharing (copies) | No |
| 2 | Time Travel | 90 days | 30 days | None |
| 3 | Instant Cloning | Yes | Yes (slower) | No |
| 4 | Cortex AI (in-platform LLM) | Yes | No | No |
| 5 | Cortex Search (native vector) | Yes | Via Mosaic | Via Copilot |
| 6 | Native Feature Store | Yes | MLflow | No |
| 7 | Native Model Registry | Yes | MLflow | Azure ML |
| 8 | SQL-Queryable Governance | Yes | Unity Catalog | Purview |
| 9 | Native dbt | Yes | Partner | No |

---

## Module 2.5: RBAC at Scale (15 min)

**Reference:** `RBAC_BEST_PRACTICES.md`

### Key Patterns for LifeArc

1. **Role Hierarchy**
```
DATA_ADMIN → DOMAIN_ADMIN_CLINICAL → DE_CLINICAL → ANALYST_CLINICAL → CONSUMER_CLINICAL
```

2. **Dynamic Masking by Role**
```sql
-- DATA_ADMIN sees real patient IDs
-- ANALYST sees pseudonymized: PAT-a1b2c3d4
-- CONSUMER sees: ***MASKED***
```

3. **Row-Level Security for Multi-Site Studies**
```sql
-- Users only see data from their assigned sites
CREATE ROW ACCESS POLICY ... AS (site_id) RETURNS BOOLEAN ->
    EXISTS (SELECT 1 FROM SITE_USER_MAPPING WHERE USER_NAME = CURRENT_USER() AND SITE_ID = site_id);
```

4. **Automated Provisioning via SCIM**
- Azure AD groups → Snowflake roles
- No manual user management

---

## Closing & Q&A (10 min)

### Summary Slide

**What We Demonstrated:**

| Module | Snowflake Capability | Business Value |
|--------|---------------------|----------------|
| Intelligence | Semantic View + Cortex | Self-service analytics |
| Governance | Tags, Masking, Row Access | Regulatory compliance |
| Sharing | Zero-Copy Shares | CRO collaboration |
| ML Pipeline | Feature Store, Registry | Reproducible ML |
| DBT | Native Git Integration | Version-controlled transformations |
| Unstructured | FASTA/JSON/AI | Unified data platform |

### Next Steps

1. **Proof of Concept Extension:** Bring your own data (2-3 tables)
2. **Architecture Workshop:** Design LifeArc-specific patterns
3. **Security Review:** RBAC implementation planning
4. **ML Deep Dive:** Your data scientists + Snowflake ML team

---

## Backup Queries (If Something Fails)

### If Streamlit Won't Load
```sql
-- Run the Intelligence queries directly
SELECT therapeutic_area, COUNT(*) as compounds,
       SUM(CASE WHEN drug_likeness = 'drug_like' THEN 1 ELSE 0 END) as drug_like
FROM AI_DEMO.COMPOUND_PIPELINE_ANALYSIS
GROUP BY therapeutic_area;

SELECT * FROM AI_DEMO.BOARD_CANDIDATE_SCORECARD ORDER BY success_probability DESC LIMIT 3;
```

### If Cortex Times Out
```sql
-- Use a simpler model
SELECT SNOWFLAKE.CORTEX.COMPLETE('llama3.1-8b', 'Say hello') as test;

-- Or show pre-computed results
SELECT doc_title, key_finding FROM AI_DEMO.RESEARCH_INTELLIGENCE 
WHERE competitive_impact = 'High' LIMIT 3;
```

### If Share Demo Fails
```sql
-- Show existing share instead
SELECT * FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()));
DESC SHARE LIFEARC_CRO_SHARE;
```

---

## Objects Quick Reference

| Object | Location | Purpose |
|--------|----------|---------|
| `INTELLIGENCE_DEMO` | AI_DEMO (Streamlit) | Talk to Your Data |
| `UNSTRUCTURED_DATA_DEMO` | AI_DEMO (Streamlit) | FASTA/JSON/Cortex |
| `DRUG_DISCOVERY_SEMANTIC_VIEW` | AI_DEMO | Cortex Analyst config |
| `RESEARCH_SEARCH_SERVICE` | AI_DEMO | Cortex Search |
| `LIFEARC_CRO_SHARE` | Account level | Zero-copy sharing |
| `CLINICAL_RESPONSE_MODEL` | ML_DEMO | Native ML Classification |
| `LIFEARC_DBT_PROJECT` | PUBLIC | Native dbt |
| Tags, Masking, RAP | GOVERNANCE | Data governance |

---

## NEW: Module 2.6 - Enterprise Scale & Cost Governance (30 min)

### Scale Demo: 1 Million Clinical Trial Records

**Talk Track:**
> "Everything we've shown works at demo scale. But LifeArc has millions of patient outcomes. Let's prove this works at enterprise scale - 1 million records, with the same governance, the same ML, the same instant cloning."

#### Show the 1M Dataset

```sql
-- Verify scale
SELECT COUNT(*) as total_records FROM LIFEARC_POC.BENCHMARK.CLINICAL_TRIAL_RESULTS_1M;
-- Expected: 1,000,000

-- Distribution across trials
SELECT 
    trial_id,
    target_gene,
    COUNT(*) as patients,
    ROUND(AVG(CASE WHEN response_category IN ('Complete_Response', 'Partial_Response') THEN 1 ELSE 0 END) * 100, 1) as response_rate_pct,
    ROUND(AVG(pfs_months), 1) as avg_pfs
FROM LIFEARC_POC.BENCHMARK.CLINICAL_TRIAL_RESULTS_1M
GROUP BY trial_id, target_gene
ORDER BY response_rate_pct DESC;
```

**Expected Results:**
| Trial | Gene | Patients | Response Rate | Avg PFS |
|-------|------|----------|---------------|---------|
| TRIAL-BRCA-001 | BRCA1 | 200,000 | 65.1% | 16.2 mo |
| TRIAL-BRCA-002 | BRCA2 | 200,000 | 59.5% | 15.5 mo |
| TRIAL-EGFR-001 | EGFR | 200,000 | 50.7% | 14.3 mo |
| TRIAL-KRAS-001 | KRAS | 200,000 | 39.4% | 12.8 mo |
| TRIAL-TP53-001 | TP53 | 200,000 | 35.0% | 12.2 mo |

**Highlight:** "Response rates match published oncology trial data - BRCA high due to PARP inhibitor sensitivity, KRAS low because it's the 'undruggable' target."

#### ML at Scale: 89.5% Accuracy

```sql
-- ML model trained on 100K samples, tested on 1K
WITH predictions AS (
    SELECT 
        is_responder AS actual,
        LIFEARC_POC.ML.RESPONSE_MODEL_1M!PREDICT(
            INPUT_DATA => OBJECT_CONSTRUCT(
                'TRIAL_ID', trial_id,
                'TREATMENT_ARM', treatment_arm,
                'BIOMARKER_STATUS', biomarker_status,
                'PATIENT_AGE', patient_age,
                'PATIENT_SEX', patient_sex,
                'TARGET_GENE', target_gene,
                'CTDNA_CONFIRMATION', ctdna_confirmation,
                'PFS_MONTHS', pfs_months,
                'OS_MONTHS', os_months
            )
        ):class::INT AS predicted
    FROM LIFEARC_POC.BENCHMARK.ML_TRAINING_DATA_1M
    SAMPLE (1000 ROWS)
)
SELECT 
    ROUND(100.0 * SUM(CASE WHEN actual = predicted THEN 1 ELSE 0 END) / COUNT(*), 1) AS accuracy_pct
FROM predictions;
-- Expected: ~89-90%
```

**Talk Track:** "89.5% accuracy on predicting treatment responders - trained in under a minute, no Spark cluster, no external tools."

#### Instant Clone at Scale

```sql
-- Watch the execution time - should be instant
CREATE OR REPLACE TABLE LIFEARC_POC.BENCHMARK.CLINICAL_TRIAL_RESULTS_1M_DEV
    CLONE LIFEARC_POC.BENCHMARK.CLINICAL_TRIAL_RESULTS_1M;

-- Verify both have same data
SELECT 
    'Original' AS source, COUNT(*) as rows FROM LIFEARC_POC.BENCHMARK.CLINICAL_TRIAL_RESULTS_1M
UNION ALL
SELECT 'Clone', COUNT(*) FROM LIFEARC_POC.BENCHMARK.CLINICAL_TRIAL_RESULTS_1M_DEV;
```

**Highlight:** "1 million rows cloned in under 1 second. Zero storage cost until you modify it. Try that with Databricks."

#### Cortex AI on 1M Records

```sql
-- LLM summarizes 1M rows
WITH trial_summary AS (
    SELECT 
        trial_id,
        ROUND(AVG(CASE WHEN response_category IN ('Complete_Response', 'Partial_Response') THEN 1 ELSE 0 END) * 100, 1) as response_rate
    FROM LIFEARC_POC.BENCHMARK.CLINICAL_TRIAL_RESULTS_1M
    GROUP BY 1
)
SELECT SNOWFLAKE.CORTEX.COMPLETE(
    'llama3.1-8b',
    'As a clinical trial analyst, summarize these results: ' || 
    (SELECT LISTAGG(trial_id || ': ' || response_rate || '%', '; ') FROM trial_summary)
) AS executive_summary;
```

**Highlight:** "C-suite gets insights from 1 million patient records in plain English - no data scientists required."

---

### Cost Governance Framework

**Talk Track:**
> "Enterprise deployments need cost controls. Snowflake provides native resource monitors - no third-party tools, no surprise bills."

#### Resource Monitors

```sql
-- Show configured monitors
SHOW RESOURCE MONITORS LIKE 'LIFEARC%';
```

**Expected Output:**
| Monitor | Credit Quota | Triggers |
|---------|--------------|----------|
| LIFEARC_POC_MONITOR | 1,000 | 50%, 75%, 90% (notify), 100% (suspend) |
| LIFEARC_ML_MONITOR | 500 | 75% (notify), 100% (suspend) |
| LIFEARC_ETL_MONITOR | 300 | 75% (notify), 100% (suspend) |
| LIFEARC_ANALYTICS_MONITOR | 200 | 80% (notify), 100% (suspend immediate) |

**Talk Track:** "Department-level spending caps with automatic shutoff. ML gets 500 credits, ETL gets 300. If anyone hits 100%, workloads suspend - no bill shock."

#### Cost Tracking Dashboard

```sql
-- Executive cost summary
SELECT * FROM LIFEARC_POC.COST_GOVERNANCE.V_COST_DASHBOARD;

-- Top expensive queries (last 7 days)
SELECT 
    user_name,
    LEFT(query_preview, 50) as query,
    elapsed_seconds,
    gb_scanned
FROM LIFEARC_POC.COST_GOVERNANCE.V_TOP_EXPENSIVE_QUERIES
LIMIT 5;

-- Cost recommendations
SELECT * FROM LIFEARC_POC.COST_GOVERNANCE.COST_RECOMMENDATIONS
WHERE priority = 'HIGH';
```

**Highlight:** "Proactive recommendations - warehouse sizing, auto-suspend, clustering. These aren't add-ons, they're built into the platform."

#### Governance at Scale

```sql
-- Tags applied to 1M row table
SELECT 
    tag_name,
    tag_value
FROM TABLE(
    LIFEARC_POC.INFORMATION_SCHEMA.TAG_REFERENCES(
        'LIFEARC_POC.BENCHMARK.CLINICAL_TRIAL_RESULTS_1M', 
        'TABLE'
    )
);
```

**Expected:** PHI classification, 10-year retention, CONFIDENTIAL sensitivity - all queryable via SQL.

**Talk Track:** "Auditors can query governance policies across 1 million records in seconds. No spreadsheets, no manual tracking."

---

## Presenter Notes

### Timing Guide

| Section | Start Time | Duration |
|---------|------------|----------|
| Module 1.1: Opening | 0:00 | 15 min |
| Module 1.2: Intelligence | 0:15 | 30 min |
| Module 1.3: Differentiators | 0:45 | 45 min |
| Module 1.4: Governance | 1:30 | 30 min |
| **Break** | 2:00 | 10 min |
| Module 2.1: ML Pipeline | 2:10 | 40 min |
| Module 2.2: DBT | 2:50 | 25 min |
| Module 2.3: Unstructured | 3:15 | 15 min |
| Module 2.4: Architecture | 3:30 | 15 min |
| Module 2.5: RBAC | 3:45 | 10 min |
| **Module 2.6: Scale & Cost** | 3:55 | 30 min |
| Closing/Q&A | 4:25 | 5 min |

### Key Talking Points by Audience

**For Executives:**
- Focus on self-service analytics (Module 1.2)
- Emphasize zero data copies for CRO sharing
- Highlight cost efficiency of cloning

**For IT/Security:**
- Deep dive on governance (Module 1.4)
- RBAC patterns (Module 2.5)
- Audit trail capabilities

**For Data Scientists:**
- Feature Store and Model Registry (Module 2.1)
- Notebook walkthrough
- ML Lineage for regulatory submissions

---

*Generated by FDE-mode POC validation*
