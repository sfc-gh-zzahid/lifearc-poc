# LifeArc POC - Demo Walkthrough Checklist

## Pre-Demo Setup (5 min before)

```sql
-- Verify environment
USE DATABASE LIFEARC_POC;
USE WAREHOUSE COMPUTE_WH;

-- Quick health check
SELECT COUNT(*) FROM AI_DEMO.COMPOUND_PIPELINE_ANALYSIS;  -- Should be 29
SELECT COUNT(*) FROM AI_DEMO.BOARD_CANDIDATE_SCORECARD;   -- Should be 8
SHOW STREAMLITS IN DATABASE LIFEARC_POC;                  -- Should show 2
SHOW SHARES LIKE 'LIFEARC%';                              -- Should show 1
```

---

## Demo Flow (15-20 minutes)

### Scene 1: The Problem Statement (1 min)

**Setup:** Open Snowsight, show AI_DEMO schema

**Say:** "LifeArc has 29 compounds in development, $903M invested, and needs to answer strategic questions about their pipeline. Today we'll show how Snowflake Intelligence enables natural language analytics."

```sql
-- Show the executive summary
SELECT * FROM LIFEARC_POC.AI_DEMO.EXECUTIVE_PIPELINE_SUMMARY;
```

---

### Scene 2: Talk to Your Data - Intelligence Demo (5 min)

**Open:** Streamlit app `INTELLIGENCE_DEMO`

**Navigate:** Apps → LIFEARC_POC.AI_DEMO.INTELLIGENCE_DEMO

**Demo the 5 "Why" Questions:**

1. **Discovery Problem:** "Why are compounds failing drug-likeness?"
   - CNS has 0% drug-like, BRCA has 100%
   - LogP > 5 is the killer
   - **Action:** Adjust chemistry guidelines

2. **Clinical Performance:** "Why is BRCA1 outperforming KRAS?"
   - BRCA1: 52.9% response rate vs KRAS: 32.1%
   - Key difference: ctDNA confirmation (100% vs 33%)
   - **Action:** Mandate ctDNA for KRAS

3. **Budget Allocation:** "How should we reallocate R&D?"
   - Oncology: 21.6x ROI
   - CNS: 2.8x ROI
   - **Action:** Shift $107M from CNS to Oncology

4. **Research Intelligence:** Search for "EGFR resistance"
   - Shows C797S mutation (42% of patients)
   - MET bypass mechanism (28%)
   - **Action:** Pivot EGFR program

5. **Board Priorities:** Show the top 3 candidates
   - Olaparib-LA (85% success, $1.2B peak)
   - OmoMYC-LA (78% success, $3.5B peak)
   - Ceralasertib-LA (65% success, $800M peak)

**Key Message:** "The AI stays INSIDE Snowflake - PHI never leaves the platform."

---

### Scene 3: Snowflake-Unique Differentiators (5 min)

**Return to Snowsight SQL worksheet**

#### A. Secure Data Sharing (Unique to Snowflake)

**Say:** "LifeArc needs to share trial data with CRO partners. In other platforms, this means copying data. In Snowflake, it's zero-copy."

```sql
-- Show the share we created
DESC SHARE LIFEARC_CRO_SHARE;

-- The partner gets LIVE data, not a copy
-- No ETL, no data movement, complete audit trail
```

**Key Message:** "Databricks Delta Sharing copies data. Fabric requires export. Snowflake shares LIVE data with zero copies."

#### B. Time Travel (Unique to Snowflake)

**Say:** "For GxP compliance, you need audit trails. Snowflake has this built-in."

```sql
-- Query data as it was 1 hour ago
SELECT COUNT(*) as current_count FROM AI_DEMO.COMPOUND_PIPELINE_ANALYSIS;
SELECT COUNT(*) as one_hour_ago FROM AI_DEMO.COMPOUND_PIPELINE_ANALYSIS AT (OFFSET => -3600);

-- If you accidentally delete data:
-- DROP TABLE important_table;
-- UNDROP TABLE important_table;  -- Instant recovery!
```

**Key Message:** "No backup configuration needed. Query ANY point in the last 90 days."

#### C. Zero-Copy Cloning (Unique to Snowflake)

**Say:** "Data scientists need production-like data for testing. Watch this."

```sql
-- Clone the entire database in seconds (even if it's 10TB)
CREATE DATABASE LIFEARC_DEV CLONE LIFEARC_POC;

-- Verify it worked
SELECT COUNT(*) FROM LIFEARC_DEV.AI_DEMO.COMPOUND_PIPELINE_ANALYSIS;

-- Clean up
DROP DATABASE LIFEARC_DEV;
```

**Key Message:** "That took 3 seconds. You pay only for data that CHANGES in the clone."

#### D. Cortex AI Privacy (Unique to Snowflake)

**Say:** "What if you need AI on PHI data? Most platforms require sending data to external APIs - a HIPAA violation."

```sql
-- AI analysis - data NEVER leaves Snowflake
SELECT SNOWFLAKE.CORTEX.COMPLETE(
    'llama3.1-70b',
    'Summarize the key competitive threats to EGFR programs based on: ' || 
    (SELECT LISTAGG(key_finding, '. ') FROM AI_DEMO.RESEARCH_INTELLIGENCE WHERE target_gene = 'EGFR')
) AS competitive_analysis;
```

**Key Message:** "Cortex runs INSIDE Snowflake. Your PHI never touches an external API."

---

### Scene 4: ML Pipeline (3 min)

**Say:** "We've also built an end-to-end ML pipeline for predicting drug-likeness."

```sql
-- Show the trained model
SHOW SNOWFLAKE.ML.CLASSIFICATION IN SCHEMA ML_DEMO;

-- Show predictions
SELECT 
    compound_name,
    therapeutic_area,
    actual_drug_likeness,
    ROUND(predicted_drug_like_prob * 100, 1) AS ml_prediction_pct
FROM ML_DEMO.COMPOUND_PREDICTIONS
WHERE actual_drug_likeness != CASE WHEN predicted_drug_like_prob > 0.5 THEN 'drug_like' ELSE 'non_drug_like' END
LIMIT 5;

-- Show model registry
SELECT model_name, model_version, status, metrics FROM ML_DEMO.MODEL_REGISTRY;
```

**Key Message:** "Feature engineering, training, registry, inference - all in Snowflake."

---

### Scene 5: Data Governance (2 min)

**Say:** "For regulated industries, governance is critical."

```sql
-- Show data classification tags
SHOW TAGS IN SCHEMA GOVERNANCE;

-- Show which tables are tagged as PHI
SELECT * FROM SNOWFLAKE.ACCOUNT_USAGE.TAG_REFERENCES
WHERE TAG_NAME = 'DATA_CLASSIFICATION' 
  AND TAG_VALUE = 'PHI'
  AND OBJECT_DATABASE = 'LIFEARC_POC';

-- Show masking policies
SHOW MASKING POLICIES IN SCHEMA GOVERNANCE;
```

**Key Message:** "Data classification is SQL-queryable. Auditors can verify compliance in seconds."

---

### Scene 6: Native DBT (2 min)

**Say:** "LifeArc uses dbt for transformations. Snowflake has native support."

```sql
-- Show the dbt project
SHOW DBT PROJECTS IN DATABASE LIFEARC_POC;

-- Show versions (synced from Git)
SHOW VERSIONS IN DBT PROJECT LIFEARC_POC.PUBLIC.LIFEARC_DBT_PROJECT;

-- Run dbt (if time permits)
-- EXECUTE DBT PROJECT LIFEARC_DBT_PROJECT ARGS = 'build';
```

**Key Message:** "Git-synced, version-controlled, native integration."

---

## Closing (1 min)

**Say:** "To summarize what makes Snowflake unique for life sciences:"

| Capability | Why It Matters |
|------------|----------------|
| **Secure Data Sharing** | Share with CROs without copying |
| **Time Travel** | GxP audit compliance built-in |
| **Zero-Copy Cloning** | Dev environments in seconds |
| **Cortex AI Privacy** | AI on PHI without compliance risk |
| **Native Governance** | Tags, masking, access policies |

**Final Message:** "Databricks and Fabric are good platforms, but for regulated life sciences data, Snowflake provides capabilities they cannot match."

---

## Backup Queries (if something fails)

```sql
-- If Streamlit won't load, run queries directly:
SELECT therapeutic_area, COUNT(*) as compounds,
       SUM(CASE WHEN drug_likeness = 'drug_like' THEN 1 ELSE 0 END) as drug_like
FROM AI_DEMO.COMPOUND_PIPELINE_ANALYSIS
GROUP BY therapeutic_area;

-- If Cortex times out:
SELECT doc_title, key_finding FROM AI_DEMO.RESEARCH_INTELLIGENCE 
WHERE competitive_impact = 'High' LIMIT 3;
```

---

## Objects Reference

| Object | Location | Purpose |
|--------|----------|---------|
| `INTELLIGENCE_DEMO` | AI_DEMO schema (Streamlit) | Talk to Your Data |
| `UNSTRUCTURED_DATA_DEMO` | AI_DEMO schema (Streamlit) | FASTA/JSON/Cortex |
| `LIFEARC_CRO_SHARE` | Account level | Zero-copy sharing |
| `DRUG_LIKENESS_MODEL` | ML_DEMO schema | ML classification |
| `LIFEARC_DBT_PROJECT` | PUBLIC schema | Native dbt |
| `DRUG_DISCOVERY_SEMANTIC_VIEW` | AI_DEMO schema | Intelligence config |
