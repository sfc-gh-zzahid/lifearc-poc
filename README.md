# LifeArc POC - Snowflake for Life Sciences

## Why Snowflake for Life Sciences?

This POC demonstrates capabilities that are **UNIQUE to Snowflake** and cannot be easily replicated in Databricks or Microsoft Fabric:

| Snowflake Differentiator | Why It Matters for Life Sciences |
|--------------------------|----------------------------------|
| **Secure Data Sharing** | Share trial data with CROs without copying - zero-copy, governed, auditable |
| **Zero-Copy Cloning** | Create dev/test environments in seconds, pay only for changes |
| **Time Travel** | GxP-compliant audit trails, point-in-time queries for regulatory submissions |
| **Cortex AI Privacy** | LLMs run INSIDE Snowflake - PHI never leaves the platform (HIPAA-safe) |
| **Instant Elasticity** | Scale for genomic queries, auto-suspend when idle, per-second billing |
| **Native Governance** | Data classification tags queryable via SQL, automatic policy enforcement |
| **Marketplace** | Pre-built life sciences datasets ready to query - no ETL |

**Competitors Cannot Match This Combination:**
- Databricks: Data sharing copies data, cluster management overhead, AI requires external calls
- Fabric: No zero-copy sharing, AI requires Azure OpenAI (data leaves), Microsoft-locked

---

## Demo Materials

### Snowflake Intelligence Demo ("Talk to Your Data")

**App:** `LIFEARC_POC.AI_DEMO.INTELLIGENCE_DEMO` (Streamlit)

Demonstrates natural language queries over drug discovery data:

| Question | Business Action |
|----------|----------------|
| "Why are compounds failing drug-likeness?" | Adjust chemistry guidelines (LogP < 4.5) |
| "Why is BRCA1 outperforming KRAS?" | Mandate ctDNA for KRAS enrollment |
| "How should we reallocate R&D budget?" | Shift $107M from CNS to Oncology |
| "What does research say about EGFR?" | Pivot to next-gen inhibitors |
| "Which 3 candidates for the board?" | Prioritize Olaparib-LA, OmoMYC-LA, Ceralasertib-LA |

**Schema:** `LIFEARC_POC.AI_DEMO` (71 rows across 5 tables)

---

### Snowflake-Unique Differentiators Demo

**Script:** `sql_scripts/snowflake_differentiators_demo.sql`

| Demo | What It Shows |
|------|---------------|
| Secure Data Sharing | Zero-copy share with CRO (`LIFEARC_CRO_SHARE`) |
| Zero-Copy Cloning | `CREATE DATABASE CLONE` in seconds |
| Time Travel | `AT (OFFSET => -3600)` - query data 1 hour ago |
| Cortex Privacy | AI on PHI without external API calls |
| Instant Elasticity | Scale warehouse up/down in seconds |
| Data Classification | PHI/PII tags queryable via SQL |

---

### ML Pipeline Demo

**Script:** `sql_scripts/ml_pipeline_demo.sql`

Complete ML workflow in Snowflake:
1. Feature engineering from compound properties
2. Model training (`SNOWFLAKE.ML.CLASSIFICATION`)
3. Model registry for governance
4. Batch inference view
5. Prediction monitoring

**Model:** `LIFEARC_POC.ML_DEMO.DRUG_LIKENESS_MODEL`

---

### DBT Data Pipeline

**Object:** `LIFEARC_POC.PUBLIC.LIFEARC_DBT_PROJECT`

Native Snowflake DBT PROJECT with medallion architecture:

```
Bronze (Staging)          → Silver (Intermediate)        → Gold (Marts)
stg_compounds            → int_compound_properties     → mart_compound_analysis
stg_clinical_results     → int_trial_patient_outcomes  → mart_trial_efficacy
stg_gene_sequences       →                             → mart_gene_analysis
```

**Deploy from Git:**
```sql
EXECUTE DBT PROJECT LIFEARC_POC.PUBLIC.LIFEARC_DBT_PROJECT ARGS = 'build';
```

---

### Unstructured Data Demo

**App:** `LIFEARC_POC.AI_DEMO.UNSTRUCTURED_DATA_DEMO` (Streamlit)

| Capability | Implementation |
|------------|----------------|
| Parse FASTA sequences | `PARSE_FASTA` Python UDTF |
| Store molecular structures | VARIANT type with JSON properties |
| Query clinical JSON | Path notation, LATERAL FLATTEN |
| Document AI analysis | `SNOWFLAKE.CORTEX.COMPLETE` |
| Semantic search | `RESEARCH_SEARCH_SERVICE` Cortex Search |

---

## Snowflake Objects Summary

| Schema | Key Objects |
|--------|-------------|
| `AI_DEMO` | 5 demo tables, Semantic View, Cortex Search, 2 Streamlit apps |
| `ML_DEMO` | ML model, Model Registry, Feature Store, Inference View |
| `GOVERNANCE` | Masking Policies, Row Access Policy, Data Classification Tags |
| `DATA_SHARING` | Clinical Results, Partner View, Secure Share |
| `UNSTRUCTURED_DATA` | PARSE_FASTA UDF, Gene Sequences, Compound Library |
| `PUBLIC` | DBT Project, Git Repository |

---

## Quick Start

### 1. Verify Environment
```sql
USE DATABASE LIFEARC_POC;
SHOW SCHEMAS;
SHOW STREAMLITS;
SHOW SHARES LIKE 'LIFEARC%';
```

### 2. Run Snowflake Intelligence Demo
```sql
-- Open in Snowsight: Apps → INTELLIGENCE_DEMO
-- Or query directly:
SELECT * FROM LIFEARC_POC.AI_DEMO.COMPOUND_PIPELINE_ANALYSIS;
SELECT * FROM LIFEARC_POC.AI_DEMO.BOARD_CANDIDATE_SCORECARD WHERE board_recommendation LIKE 'Priority%';
```

### 3. Run ML Inference
```sql
SELECT 
    compound_name, 
    therapeutic_area,
    actual_drug_likeness,
    ROUND(predicted_drug_like_prob * 100, 1) AS ml_prediction_pct
FROM LIFEARC_POC.ML_DEMO.COMPOUND_PREDICTIONS
ORDER BY predicted_drug_like_prob DESC;
```

### 4. Demo Data Sharing
```sql
-- Show zero-copy share (unique to Snowflake)
SHOW SHARES LIKE 'LIFEARC%';
DESC SHARE LIFEARC_CRO_SHARE;
```

### 5. Demo Time Travel (unique to Snowflake)
```sql
-- Query data as it was 1 hour ago
SELECT COUNT(*) FROM LIFEARC_POC.AI_DEMO.COMPOUND_PIPELINE_ANALYSIS AT (OFFSET => -3600);
```

---

## Repository Structure

```
LifeArc/
├── sql_scripts/
│   ├── snowflake_differentiators_demo.sql  # ⭐ UNIQUE capabilities
│   ├── create_semantic_view.sql            # Snowflake Intelligence
│   ├── ml_pipeline_demo.sql                # End-to-end ML
│   ├── demo5_data_sharing_governance.sql   # Governance & sharing
│   └── demo6_programmatic_access_auth.sql  # Auth patterns
├── streamlit_apps/
│   ├── intelligence_demo.py                # Talk to Your Data
│   └── unstructured_data_demo.py           # Unstructured data
├── dbt/                                    # Native DBT pipeline
├── architecture/                           # Reference architectures
├── specs/                                  # Demo specifications
└── demo_data/                              # Sample files
```

---

## Key Talking Points

1. **"Why can't I do this in Databricks?"**
   - Data sharing copies data in Delta Sharing
   - No native Streamlit, no instant cloning
   - AI requires external API calls (data leaves)

2. **"Why can't I do this in Fabric?"**
   - No zero-copy sharing across organizations
   - AI requires Azure OpenAI (data leaves the warehouse)
   - No Time Travel for audit compliance

3. **"What about compliance?"**
   - Cortex AI keeps PHI in Snowflake (HIPAA-safe)
   - Time Travel provides audit trail (GxP)
   - Data classification tags are SQL-queryable

4. **"What about cost?"**
   - Per-second billing, auto-suspend
   - Zero-copy cloning = no storage duplication
   - Marketplace = no ETL maintenance

---

## Contact

For questions about this POC, contact the Snowflake team.
