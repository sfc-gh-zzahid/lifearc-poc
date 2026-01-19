# AGENTS.md - LifeArc POC

## Project Goal
Build a production-ready POC for LifeArc demonstrating Snowflake capabilities for life sciences: unstructured data handling, data governance/sharing, and programmatic access/auth.

## Build Commands

```bash
# Validate SQL scripts (syntax check)
# Run in Snowflake via snowflake_sql_execute tool

# Test Streamlit app (local)
cd /Users/zzahid/Documents/GitHub/LifeArc/streamlit_apps
streamlit run unstructured_data_demo.py --server.headless true

# Test notebook
jupyter nbconvert --execute notebooks/demo6_programmatic_access.ipynb --to notebook
```

## Validation Checklist

### Database Objects
- [ ] All schemas exist: UNSTRUCTURED_DATA, DATA_SHARING, AUTH_ACCESS, GOVERNANCE, ARCHIVE, ML_FEATURES, AZURE_ML_INTEGRATION
- [ ] Tables have data: CLINICAL_TRIAL_RESULTS, CLINICAL_TRIALS, COMPOUND_LIBRARY
- [ ] UDFs compile: PARSE_FASTA, PARSE_FASTQ, PARSE_SDF
- [ ] Cortex LLM functions work
- [ ] Masking policies apply correctly
- [ ] Row access policies work
- [ ] Tags are created

### Demo 4 - Unstructured Data
- [ ] FASTA parser UDF works
- [ ] SDF molecular data loads
- [ ] JSON clinical trial queries work
- [ ] Cortex Search service creates
- [ ] Cortex LLM analysis functions

### Demo 5 - Data Sharing & Governance
- [ ] Data classification tags exist
- [ ] Masking policies work per role
- [ ] Row access policies filter correctly
- [ ] Secure share objects create
- [ ] Audit logging captures events

### Demo 6 - Programmatic Access
- [ ] Key-pair auth setup works
- [ ] Service account roles exist
- [ ] Network policies create
- [ ] Python connection examples work

## Snowflake Connection
- Connection: `sfseeeurope_keypair`
- Database: `LIFEARC_POC`
- Warehouse: `DEMO_WH`
- Role: `ACCOUNTADMIN`

## Patterns
- Use PARSE_JSON with SELECT UNION ALL (not VALUES clause)
- Use VARIANT for semi-structured data
- Use LATERAL FLATTEN for nested JSON arrays
- Create UDFs with RUNTIME_VERSION = '3.11'
