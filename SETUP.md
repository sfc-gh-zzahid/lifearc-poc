# LifeArc POC - Setup Guide

**Purpose:** Deploy this POC to any Snowflake environment  
**Time Required:** 30-45 minutes  
**Prerequisites:** ACCOUNTADMIN or equivalent privileges

---

## Quick Start

### Step 1: Set Your Environment Variables

```bash
# Set these for your target Snowflake account
export SF_ACCOUNT="your_account_identifier"
export SF_USER="your_username"
export SF_WAREHOUSE="COMPUTE_WH"
export SF_DATABASE="LIFEARC_POC"
```

### Step 2: Deploy Core Infrastructure

```bash
# Using Snowflake CLI
snow sql -f DEPLOY.sql --account $SF_ACCOUNT --user $SF_USER
```

Or run `DEPLOY.sql` directly in Snowsight.

### Step 3: Verify Deployment

```sql
-- Run this to validate all components
USE DATABASE LIFEARC_POC;

-- Check schemas
SHOW SCHEMAS;
-- Expected: AI_DEMO, ML_DEMO, BENCHMARK, GOVERNANCE, DATA_SHARING, UNSTRUCTURED_DATA, etc.

-- Check data
SELECT COUNT(*) FROM BENCHMARK.CLINICAL_TRIAL_RESULTS_1M;
-- Expected: 1,000,000

-- Check Streamlit apps
SHOW STREAMLITS;
-- Expected: INTELLIGENCE_DEMO, UNSTRUCTURED_DATA_DEMO, LIFEARC_ML_DASHBOARD

-- Check governance
SHOW TAGS IN SCHEMA GOVERNANCE;
-- Expected: DATA_CLASSIFICATION, DATA_DOMAIN, DATA_SENSITIVITY, PII_TYPE, RETENTION_PERIOD
```

---

## Component Deployment

### Option A: Full Deployment (Recommended)

Run `DEPLOY.sql` which creates:
- All schemas and tables
- Sample data (1M clinical trial records)
- Governance policies (tags, masking, row access)
- ML pipeline components
- Streamlit applications
- Data sharing configuration

### Option B: Selective Deployment

Deploy individual components:

| Component | Script | Purpose |
|-----------|--------|---------|
| Core Data | `DEPLOY.sql` (Section 1-3) | Schemas + sample data |
| Governance | `sql_scripts/demo5_data_sharing_governance.sql` | Tags, policies, shares |
| ML Pipeline | `sql_scripts/ml_pipeline_production.sql` | Feature store, model |
| DBT Project | `dbt/` folder | Transform layer |

---

## Environment Customization

### Update Connection Names

If using Snowflake CLI, create a connection:

```bash
snow connection add \
  --connection-name my_lifearc_poc \
  --account YOUR_ACCOUNT \
  --user YOUR_USER \
  --authenticator externalbrowser
```

### Update Warehouse Size

For demo purposes, `XSMALL` is sufficient:

```sql
CREATE OR REPLACE WAREHOUSE LIFEARC_WH
  WAREHOUSE_SIZE = 'XSMALL'
  AUTO_SUSPEND = 60
  AUTO_RESUME = TRUE;
```

For ML training on 100K+ rows, use `MEDIUM` or larger.

### Update Resource Monitor Quotas

Adjust based on your account:

```sql
ALTER RESOURCE MONITOR LIFEARC_POC_MONITOR SET CREDIT_QUOTA = 500;
```

---

## Post-Deployment Verification

Run the full validation checklist:

```sql
-- 1. Data Volume
SELECT 'CLINICAL_TRIAL_RESULTS_1M' AS table_name, COUNT(*) AS row_count 
FROM BENCHMARK.CLINICAL_TRIAL_RESULTS_1M
UNION ALL
SELECT 'COMPOUND_PIPELINE_ANALYSIS', COUNT(*) FROM AI_DEMO.COMPOUND_PIPELINE_ANALYSIS
UNION ALL
SELECT 'RESEARCH_INTELLIGENCE', COUNT(*) FROM AI_DEMO.RESEARCH_INTELLIGENCE;

-- 2. Cortex AI
SELECT SNOWFLAKE.CORTEX.COMPLETE('mistral-large2', 'Say hello in one word');

-- 3. Governance Tags
SELECT COUNT(*) AS tag_count FROM INFORMATION_SCHEMA.TAGS 
WHERE TAG_SCHEMA = 'GOVERNANCE';

-- 4. Shares
SHOW SHARES LIKE 'LIFEARC%';

-- 5. Resource Monitors
SHOW RESOURCE MONITORS LIKE 'LIFEARC%';
```

---

## Cleanup / Teardown

To remove all POC objects:

```bash
snow sql -f TEARDOWN.sql --account $SF_ACCOUNT --user $SF_USER
```

Or run `TEARDOWN.sql` directly in Snowsight.

---

## Troubleshooting

### Cortex AI Not Responding

Cortex requires:
- Enterprise Edition or higher
- Region with Cortex availability (check Snowflake docs)

```sql
-- Test Cortex availability
SELECT SNOWFLAKE.CORTEX.COMPLETE('mistral-large2', 'test');
```

### Streamlit Apps Not Visible

Ensure Streamlit is enabled:

```sql
-- Check if Streamlits exist
SHOW STREAMLITS IN DATABASE LIFEARC_POC;

-- If empty, redeploy from notebooks
-- Navigate to: Snowsight → Projects → Streamlit → Create
```

### ML Model Not Predicting

Verify model exists:

```sql
SHOW SNOWFLAKE.ML.CLASSIFICATION IN SCHEMA ML_DEMO;
```

If missing, retrain:

```sql
-- Run ML pipeline
CALL ML_DEMO.TRAIN_CLINICAL_RESPONSE_MODEL();
```

---

## File Structure

```
LifeArc/
├── DEPLOY.sql              # Main deployment script
├── TEARDOWN.sql            # Cleanup script
├── SETUP.md                # This file
├── README.md               # Project overview
│
├── DEMO_WALKTHROUGH.md     # 4-hour demo script
├── FDE_AUDIT_REPORT.md     # Technical validation
├── ARCHITECTURE_DIAGRAMS.md # Visual diagrams
│
├── EXECUTIVE_SUMMARY.md    # CxO 1-pager
├── OBJECTION_HANDLING.md   # Competitive responses
├── ROI_CALCULATOR.md       # Business case
├── STAKEHOLDER_TALK_TRACKS.md # Persona messaging
├── COMPETITIVE_BATTLECARD.md # Feature comparison
│
├── sql_scripts/            # Individual SQL demos
├── dbt/                    # DBT project
├── architecture/           # Architecture patterns
└── specs/                  # Original specifications
```

---

## Support

For issues deploying this POC:
1. Check Snowflake documentation for region/edition requirements
2. Verify ACCOUNTADMIN privileges
3. Review error messages in Query History

---

*Setup guide for LifeArc POC - Portable across Snowflake environments*
