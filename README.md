# LifeArc POC - Snowflake Workshop Materials

## Overview

This repository contains POC materials for the LifeArc Snowflake workshop, covering 6 use cases plus a complete **dbt data pipeline**:

| Use Case | Type | Materials | Status |
|----------|------|-----------|--------|
| 1. Enterprise Data Archiving | Architecture | `architecture/usecase1_data_archiving.sql` | ✅ Ready |
| 2. MLOps Workflows | Architecture | `architecture/usecase2_mlops_workflows.sql` | ✅ Ready |
| 3. Azure ML Integration | Architecture | `architecture/usecase3_azure_ml_integration.sql` | ✅ Ready |
| 4. Unstructured Data Handling | **Demo** | `streamlit_apps/unstructured_data_demo.py` | ✅ Validated |
| 5. Data Contracts & Sharing | **Demo** | `sql_scripts/demo5_data_sharing_governance.sql` | ✅ Validated |
| 6. Programmatic Access & Auth | **Demo** | `sql_scripts/demo6_programmatic_access_auth.sql` | ✅ Validated |
| **DBT Pipeline** | **Demo** | `dbt/` | ✅ Production-Ready |

## DBT Data Pipeline

This repository includes a **production-ready dbt project** that implements a Bronze → Silver → Gold medallion architecture:

```
Bronze (Staging)              Silver (Intermediate)           Gold (Marts)
────────────────             ───────────────────             ────────────
stg_compounds          →     int_compound_properties    →    mart_compound_analysis
stg_clinical_results   →     int_trial_patient_outcomes →    mart_trial_efficacy
stg_gene_sequences     →                               →    mart_gene_analysis
```

### Deploy as Native Snowflake DBT PROJECT

```sql
-- 1. Create Git Repository Integration (for public repos)
CREATE OR REPLACE API INTEGRATION my_git_integration
  API_PROVIDER = GIT_HTTPS_API
  API_ALLOWED_PREFIXES = ('https://github.com/')
  ENABLED = TRUE;

-- 2. Create Git Repository
CREATE OR REPLACE GIT REPOSITORY my_git_repo
  API_INTEGRATION = my_git_integration
  ORIGIN = 'https://github.com/sfc-gh-zzahid/lifearc-poc.git';

-- 3. Fetch latest
ALTER GIT REPOSITORY my_git_repo FETCH;

-- 4. Create DBT Project
CREATE OR REPLACE DBT PROJECT my_dbt_project
  FROM '@my_git_repo/branches/main/dbt'
  USING WAREHOUSE DEMO_WH
  WITH PROFILE_NAME = 'lifearc_snowflake'
  WITH TARGET_NAME = 'dev';

-- 5. Run dbt build
EXECUTE DBT PROJECT my_dbt_project ARGS = 'build';
```

### Use in Snowsight Workspace

1. Go to **Projects → Worksheets**
2. Click **+ Workspace** → **Create workspace from Git repository**
3. Enter: `https://github.com/sfc-gh-zzahid/lifearc-poc.git`
4. Navigate to `dbt/` folder
5. Run `dbt build` to execute the pipeline

## Snowflake Environment Status

**Database**: `LIFEARC_POC` - All objects created and validated

| Data Category | Records | Capabilities Demonstrated |
|---------------|---------|---------------------------|
| Gene Sequences | 5 | FASTA parsing, GC content analysis |
| Compounds | 3 | Lipinski Rule checking, VARIANT properties |
| Clinical Trials (JSON) | 1 | Nested JSON, LATERAL FLATTEN |
| Clinical Results | 8 | Masking policies, row access, secure sharing |
| Research Documents | 3 | Full-text search, Cortex LLM analysis |

## Repository Structure

```
LifeArc/
├── dbt/                             # ⭐ DBT Data Pipeline (Bronze→Silver→Gold)
│   ├── models/
│   │   ├── staging/                 # Bronze: Raw data cleaning
│   │   ├── intermediate/            # Silver: Business logic
│   │   └── marts/                   # Gold: Analytics-ready
│   ├── seeds/                       # Reference data CSVs
│   ├── macros/                      # Reusable SQL
│   ├── tests/                       # Custom data tests
│   ├── snapshots/                   # SCD Type 2 tracking
│   └── analyses/                    # Ad-hoc queries
├── architecture/                    # Reference architectures (Use Cases 1-3)
│   ├── usecase1_data_archiving.sql
│   ├── usecase2_mlops_workflows.sql
│   └── usecase3_azure_ml_integration.sql
├── streamlit_apps/                  # Interactive demos
│   └── unstructured_data_demo.py    # Demo 4: Unstructured data
├── sql_scripts/                     # SQL-based demos
│   ├── demo5_data_sharing_governance.sql
│   └── demo6_programmatic_access_auth.sql
├── notebooks/                       # Jupyter notebooks
│   └── demo6_programmatic_access.ipynb
├── demo_data/                       # Sample data files
│   ├── sample_gene_sequence.fasta
│   ├── sample_sequences.fastq
│   ├── sample_molecules.sdf
│   ├── clinical_outcomes.csv
│   ├── clinical_trial_protocol.json
│   └── research_abstract.txt
├── specs/                           # Specifications
│   └── lifearc-poc.md
├── AGENTS.md                        # Build/validation config
├── IMPLEMENTATION_PLAN.md           # Task tracking
└── README.md
```

## Quick Start

### Prerequisites
- Snowflake account with ACCOUNTADMIN access
- Warehouse: DEMO_WH
- Database: LIFEARC_POC (already created)

### Verify Environment

```sql
-- Check all data is loaded
SELECT 
    TABLE_SCHEMA,
    TABLE_NAME,
    ROW_COUNT
FROM LIFEARC_POC.INFORMATION_SCHEMA.TABLES 
WHERE TABLE_TYPE = 'BASE TABLE' 
  AND TABLE_SCHEMA NOT IN ('INFORMATION_SCHEMA')
ORDER BY TABLE_SCHEMA;
```

Expected output:
- AUTH_ACCESS.API_ACCESS_LOG: 0 rows
- DATA_SHARING.CLINICAL_TRIAL_RESULTS: 8 rows
- GOVERNANCE.DATA_ACCESS_AUDIT_LOG: 0 rows
- GOVERNANCE.SITE_ACCESS_MAPPING: 10 rows
- UNSTRUCTURED_DATA.CLINICAL_TRIALS: 1 row
- UNSTRUCTURED_DATA.COMPOUND_LIBRARY: 3 rows
- UNSTRUCTURED_DATA.GENE_SEQUENCES: 5 rows
- UNSTRUCTURED_DATA.RESEARCH_DOCUMENTS: 3 rows

## Demo Walkthroughs

### Demo 4: Unstructured & Semi-Structured Data

**Format**: Streamlit in Snowflake App

**Key Topics**:
- FASTA/FASTQ genomic sequence parsing with Snowpark UDFs
- Molecular structure data (SDF) storage with VARIANT
- Clinical trial JSON querying with path notation
- Cortex LLM for document analysis
- Cortex Search for semantic document discovery

**Quick Test** (run in Snowsight):
```sql
-- Test FASTA parser
SELECT * FROM TABLE(LIFEARC_POC.UNSTRUCTURED_DATA.PARSE_FASTA(
    '>GENE_BRCA1_HUMAN | Human BRCA1 gene
ATGGATTTATCTGCTCTTCGCGTTGAAGAAGTACAAAATGTCATTAATGCTATGCAGAAA'
));

-- Test Cortex LLM
SELECT SNOWFLAKE.CORTEX.COMPLETE('llama3.1-8b', 'What is BRCA1?') AS answer;
```

**To Deploy Streamlit**:
1. Create a Streamlit app in Snowsight
2. Copy contents of `streamlit_apps/unstructured_data_demo.py`
3. Run the app

### Demo 5: Data Contracts & Sharing

**Format**: SQL Scripts

**Key Topics**:
- Data classification with Tags
- Column-level masking policies
- Row access policies
- Secure data sharing (zero-copy)
- Access auditing
- Partner data ingestion patterns

**Quick Test**:
```sql
-- Verify masking policies are applied
SELECT result_id, patient_id, patient_age, site_id 
FROM LIFEARC_POC.DATA_SHARING.CLINICAL_TRIAL_RESULTS LIMIT 3;

-- View data contracts
SELECT * FROM LIFEARC_POC.GOVERNANCE.DATA_CONTRACTS_SUMMARY;
```

### Demo 6: Programmatic Access & Auth

**Format**: SQL Scripts + Jupyter Notebook

**Key Topics**:
- Service account setup best practices
- Key-pair authentication configuration
- OAuth integration (custom + Azure AD)
- Network policies
- Python connection examples
- Secrets management

**Quick Test**:
```sql
-- Test inference batch procedure
CALL LIFEARC_POC.AUTH_ACCESS.GET_INFERENCE_BATCH(5);

-- View service accounts
SHOW USERS LIKE 'LIFEARC%';
```

## Objects Created in Snowflake

| Category | Count | Objects |
|----------|-------|---------|
| Schemas | 8 | UNSTRUCTURED_DATA, DATA_SHARING, GOVERNANCE, AUTH_ACCESS, ARCHIVE, ML_FEATURES, AZURE_ML_INTEGRATION, ARCHITECTURE |
| Tables | 8 | GENE_SEQUENCES, COMPOUND_LIBRARY, CLINICAL_TRIALS, CLINICAL_TRIAL_RESULTS, RESEARCH_DOCUMENTS, SITE_ACCESS_MAPPING, API_ACCESS_LOG, DATA_ACCESS_AUDIT_LOG |
| Views | 2 | CLINICAL_RESULTS_PARTNER_VIEW, DATA_CONTRACTS_SUMMARY |
| UDFs | 1 | PARSE_FASTA |
| Procedures | 1 | GET_INFERENCE_BATCH |
| Masking Policies | 2 | MASK_PATIENT_ID, MASK_AGE |
| Row Access Policies | 1 | SITE_BASED_ACCESS |
| Tags | 4 | DATA_SENSITIVITY, DATA_DOMAIN, PII_TYPE, RETENTION_PERIOD |
| Service Users | 2 | LIFEARC_ML_SERVICE, LIFEARC_ETL_SERVICE |
| Roles | 2 | LIFEARC_ML_PIPELINE_ROLE, LIFEARC_ETL_SERVICE_ROLE |
| Network Policies | 1 | LIFEARC_ML_NETWORK_POLICY |
| Secrets | 1 | EXTERNAL_MODEL_API_KEY |

## Key Messages for Workshop

1. **Data Stays in Place**: Snowflake shares data without copying (zero-copy sharing)
2. **Unified Governance**: Tags, policies, and audit follow the data automatically
3. **Flexible Processing**: SQL for 80%, Snowpark for 15%, External for 5%
4. **AI Built-In**: Cortex LLM and Search natively available
5. **Seamless Integration**: Works with existing Azure ML workflows

## Troubleshooting

**Issue**: `SQL compilation error: Invalid expression [PARSE_JSON(...)] in VALUES clause`
**Solution**: Use `SELECT ... UNION ALL` instead of `VALUES` when inserting rows with PARSE_JSON or ARRAY_CONSTRUCT

**Issue**: Masking policy type mismatch
**Solution**: Return type must match input type (INT -> INT, VARCHAR -> VARCHAR)

**Issue**: Cortex Search service creation fails
**Solution**: Ensure you have OPERATE privilege on the warehouse

## Contact

For questions about this POC, contact the Snowflake team.
