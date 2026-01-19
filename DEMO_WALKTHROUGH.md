# LifeArc POC - Demo Walkthrough Guide

## Workshop Overview

| Item | Details |
|------|---------|
| **Customer** | LifeArc |
| **Duration** | 90 minutes |
| **Format** | Architecture discussion + hands-on demos |
| **Audience** | Data engineering, Data science, IT leadership |

---

## Timing Summary

| Section | Duration | Cumulative |
|---------|----------|------------|
| Opening & Context | 5 min | 0:05 |
| Part 1: Architecture (UC 1-3) | 30 min | 0:35 |
| Part 2: Demos (UC 4-6) | 45 min | 1:20 |
| Q&A Buffer | 10 min | 1:30 |

---

## Pre-Workshop Checklist

```
[ ] Snowflake session open in Snowsight
[ ] Connected to LIFEARC_POC database
[ ] Role set to ACCOUNTADMIN
[ ] Warehouse DEMO_WH running
[ ] This guide open on second screen
[ ] Architecture SQL files ready to share screen
```

**Quick Verify Query:**
```sql
SELECT TABLE_SCHEMA, TABLE_NAME, ROW_COUNT 
FROM LIFEARC_POC.INFORMATION_SCHEMA.TABLES 
WHERE TABLE_TYPE = 'BASE TABLE' AND TABLE_SCHEMA NOT IN ('INFORMATION_SCHEMA')
ORDER BY TABLE_SCHEMA;
```
*Expected: 9 tables, data loaded*

---

# OPENING [0:00 - 0:05]

## Presenter Script

> "Thank you for joining today. Over the next 90 minutes, we'll work through your six use cases - three architecture discussions and three hands-on demonstrations.
>
> What makes this session different: we've pre-built everything in Snowflake using your actual requirements - the 250TB archive challenge, the clinical trial data governance needs, and the Azure ML integration patterns.
>
> Let's start with where LifeArc is today..."

## Customer Context Slide (if available)

| Current State | Pain Point |
|--------------|------------|
| 250TB on Ctera | Discovery is difficult, access is uncontrolled |
| Clinical trial data in silos | Compliance burden, manual masking |
| Azure ML workflows | Data movement friction, no lineage |

---

# PART 1: ARCHITECTURE DISCUSSIONS [0:05 - 0:35]

---

## Use Case 1: Enterprise Data Archiving [0:05 - 0:15]

### Story Hook
> "You mentioned 250TB on Ctera and growing. The challenge isn't storage - Azure Blob is cheap. The challenge is finding what you need and controlling who sees it."

### Open Architecture File
```
File: architecture/usecase1_data_archiving.sql
```

### Key Points to Cover (10 min)

**[0:05-0:07] The Problem**
> "Traditional archives are 'write once, search never'. Data goes in, costs money, and nobody can find anything."

**[0:07-0:10] The Pattern**
Show ASCII diagram in the SQL file, explain:
- Snowflake = metadata brain (searchable, governed)
- Azure Blob = storage tiers (Hot/Cool/Archive)
- Presigned URLs = secure on-demand access

**[0:10-0:13] Key Queries to Show**
```sql
-- File catalog pattern
SELECT file_path, file_size_gb, data_owner, 
       retention_expiry, tags
FROM LIFEARC_POC.ARCHIVE.FILE_CATALOG
WHERE tags:department = 'Research'
  AND created_date > '2020-01-01';
```

**[0:13-0:15] Discussion Questions**
> "What's your current discovery process? How do researchers find archived data today?"

### Transition
> "Now that we've covered the storage pattern, let's talk about what happens when you need to process this data for ML..."

---

## Use Case 2: MLOps Workflows [0:15 - 0:25]

### Story Hook
> "The question isn't whether Snowflake can do ML - it's knowing when to use SQL, when to use Snowpark, and when to push to external compute."

### Open Architecture File
```
File: architecture/usecase2_mlops_workflows.sql
```

### Key Points to Cover (10 min)

**[0:15-0:18] The Decision Framework**
Show the decision tree:
```
Is it aggregation/transformation? → SQL (80% of work)
Is it row-level Python logic? → Snowpark UDFs (15%)
Is it GPU training? → External (Azure ML) (5%)
```

**[0:18-0:21] Feature Store Pattern**
```sql
-- Feature engineering stays in Snowflake
SELECT 
    patient_id,
    AVG(biomarker_value) OVER (PARTITION BY patient_id ORDER BY measurement_date 
                               ROWS BETWEEN 7 PRECEDING AND CURRENT ROW) AS rolling_avg_7d,
    LAG(biomarker_value, 1) OVER (PARTITION BY patient_id ORDER BY measurement_date) AS prev_value
FROM clinical_measurements;
```

**[0:21-0:23] Model Registry**
> "Every model version, every training dataset, every prediction - traceable back to source data."

**[0:23-0:25] Discussion Questions**
> "What does your current feature engineering look like? Where do models get deployed today?"

### Transition
> "You mentioned Azure ML Studio specifically. Let's look at how Snowflake integrates with your existing Azure investment..."

---

## Use Case 3: Azure ML Integration [0:25 - 0:35]

### Story Hook
> "Azure ML is great for training. Snowflake is great for data. The question is: how do we make them work together without creating another data silo?"

### Open Architecture File
```
File: architecture/usecase3_azure_ml_integration.sql
```

### Key Points to Cover (10 min)

**[0:25-0:28] Data Flow Pattern**
```
Snowflake → Export to ADLS → Azure ML Training → Results back to Snowflake
    ↓                                                    ↑
  Feature                                           Predictions
   Store                                            + Lineage
```

**[0:28-0:31] Key Integration Points**
```sql
-- Export training data
COPY INTO @azure_ml_stage/training/experiment_001/
FROM (
    SELECT * FROM LIFEARC_POC.ML_FEATURES.TRAINING_FEATURES
    WHERE experiment_id = 'EXP-001'
)
FILE_FORMAT = (TYPE = PARQUET);
```

**[0:31-0:33] Model Lineage**
```sql
-- Track what data trained what model
INSERT INTO model_lineage (model_id, training_data_hash, feature_columns)
SELECT 
    'model_v1.2',
    HASH_AGG(*),
    ARRAY_CONSTRUCT('feature_1', 'feature_2', 'feature_3')
FROM training_dataset;
```

**[0:33-0:35] Discussion Questions**
> "What's your current process for tracking which data trained which model? How do you handle model retraining?"

### Transition
> "Now let's shift gears from architecture to hands-on. I'll show you how Snowflake handles your unstructured research data..."

---

# PART 2: HANDS-ON DEMOS [0:35 - 1:20]

---

## Demo 4: Unstructured Data Handling [0:35 - 0:50]

### Story Hook
> "You have FASTA files from sequencing, SDF files from drug discovery, JSON protocols from clinical trials - all in different systems. Let's see how Snowflake unifies this."

### Demo Flow (15 min)

**[0:35-0:38] Show the Data**
```sql
-- Gene sequences loaded from FASTA
SELECT sequence_id, gene_name, sequence_length, gc_content,
       SUBSTRING(sequence, 1, 30) || '...' AS preview
FROM LIFEARC_POC.UNSTRUCTURED_DATA.GENE_SEQUENCES;
```
*Expected: 5 genes (BRCA1, TP53, EGFR, MYC, KRAS)*

**[0:38-0:42] FASTA Parsing UDF**
> "This is a Python UDF that runs inside Snowflake - no external compute, no data movement."

```sql
-- Parse FASTA format on the fly
SELECT * FROM TABLE(LIFEARC_POC.UNSTRUCTURED_DATA.PARSE_FASTA(
'>GENE_BRCA1_HUMAN | Human BRCA1 gene | DNA repair
ATGGATTTATCTGCTCTTCGCGTTGAAGAAGTACAAAATGTCATTAATGCTATGCAGAAA
>GENE_TP53_HUMAN | Human TP53 gene | Tumor suppressor
ATGGAGGAGCCGCAGTCAGATCCTAGCGTCGAGCCCCCTCTGAGTCAGGAAACATTTTCA'
));
```
*Show: sequence_id, gene_name, gc_content calculated*

**[0:42-0:45] Cortex LLM Analysis**
> "Now watch this - Cortex LLM is built into Snowflake. No API keys, no external calls."

```sql
-- AI-powered gene analysis
SELECT 
    gene_name,
    gc_content,
    SNOWFLAKE.CORTEX.COMPLETE(
        'llama3.1-8b',
        'In one sentence, explain the clinical significance of ' || gene_name || ' in cancer research.'
    ) AS ai_analysis
FROM LIFEARC_POC.UNSTRUCTURED_DATA.GENE_SEQUENCES
WHERE gene_name IN ('BRCA1', 'KRAS');
```
*Wait for response - usually 2-3 seconds*

**[0:45-0:48] Clinical Trial JSON**
> "Your clinical trial protocols are nested JSON. Snowflake handles this natively."

```sql
-- Query nested JSON
SELECT 
    trial_id,
    protocol_data:title::VARCHAR AS title,
    protocol_data:phase::VARCHAR AS phase,
    protocol_data:enrollment.current::INT AS enrolled,
    protocol_data:enrollment.target::INT AS target,
    ROUND(protocol_data:enrollment.current / protocol_data:enrollment.target * 100, 1) || '%' AS progress
FROM LIFEARC_POC.UNSTRUCTURED_DATA.CLINICAL_TRIALS;
```

```sql
-- Flatten nested arrays (treatment arms)
SELECT 
    ct.trial_id,
    arm.value:name::VARCHAR AS arm_name,
    arm.value:intervention::VARCHAR AS intervention,
    arm.value:patients::INT AS patients
FROM LIFEARC_POC.UNSTRUCTURED_DATA.CLINICAL_TRIALS ct,
LATERAL FLATTEN(input => ct.protocol_data:arms) arm;
```

**[0:48-0:50] Drug Discovery Compounds**
```sql
-- Lipinski Rule of 5 compliance (SMILES-based compounds)
SELECT 
    compound_id, 
    molecule_name, 
    smiles,
    properties:logP::FLOAT AS logP,
    properties:tpsa::FLOAT AS tpsa,
    CASE 
        WHEN properties:logP::FLOAT <= 5
         AND properties:num_h_donors::INT <= 5
         AND properties:lipinski_violations::INT = 0
        THEN 'DRUG-LIKE' ELSE 'REVIEW'
    END AS lipinski_status
FROM LIFEARC_POC.UNSTRUCTURED_DATA.COMPOUND_LIBRARY;
```

### Key Message
> "All your research data types - genomics, molecular, clinical - queryable with SQL, governed, and AI-ready."

### Transition
> "Now that your data is in Snowflake, how do you control who sees what? Let's look at governance..."

---

## Demo 5: Data Governance & Sharing [0:50 - 1:05]

### Story Hook
> "Clinical trial data has patient IDs, ages, site information. Different teams need different views. Traditionally, you'd create 10 different views. With Snowflake, the policy follows the data."

### Demo Flow (15 min)

**[0:50-0:52] Show Raw Data (as ACCOUNTADMIN)**
```sql
-- Full visibility as admin
SELECT result_id, patient_id, patient_age, site_id, response_category
FROM LIFEARC_POC.DATA_SHARING.CLINICAL_TRIAL_RESULTS
LIMIT 5;
```
*Note: Patient IDs and ages visible because we're ACCOUNTADMIN (masking policies bypass admins)*
*To demo masking, switch to CLINICAL_ANALYST role*

**[0:52-0:55] Explain Masking Policies**
> "We've applied two masking policies - one for patient IDs, one for ages. Watch what happens when a different role queries this."

```sql
-- Show what policies are applied
SELECT policy_name, policy_kind, ref_column_name
FROM TABLE(INFORMATION_SCHEMA.POLICY_REFERENCES(
    ref_entity_domain => 'TABLE',
    ref_entity_name => 'LIFEARC_POC.DATA_SHARING.CLINICAL_TRIAL_RESULTS'
));
```
*Shows: MASK_PATIENT_ID, MASK_AGE, SITE_BASED_ACCESS*

**[0:55-0:58] Show Data Classification Tags**
```sql
-- Tags define the data contract
SELECT tag_name, tag_value, level, column_name
FROM TABLE(INFORMATION_SCHEMA.TAG_REFERENCES_ALL_COLUMNS(
    'LIFEARC_POC.DATA_SHARING.CLINICAL_TRIAL_RESULTS', 'TABLE'
));
```
*Shows: DATA_SENSITIVITY=CONFIDENTIAL, DATA_DOMAIN=CLINICAL, PII_TYPE on columns*

**[0:58-1:00] Row Access Policy**
> "UK team only sees UK sites. US team only sees US sites. Global team sees everything."

```sql
-- Show site access mapping
SELECT role_name, allowed_site_id 
FROM LIFEARC_POC.GOVERNANCE.SITE_ACCESS_MAPPING
ORDER BY role_name;
```

**[1:00-1:02] Data Contracts Summary**
```sql
-- Single view of all governance
SELECT * FROM LIFEARC_POC.GOVERNANCE.DATA_CONTRACTS_SUMMARY;
```

**[1:02-1:05] Secure Sharing Pattern**
> "When you share with a CRO partner, they get a secure view - data never leaves your account."

```sql
-- Partner view with aggregated adverse events
SELECT result_id, masked_patient_id, adverse_event_severity, site_id
FROM LIFEARC_POC.DATA_SHARING.CLINICAL_RESULTS_PARTNER_VIEW
LIMIT 5;
```

### Key Message
> "One table, multiple views based on who's asking. No ETL, no view proliferation, full audit trail."

### Transition
> "Now let's talk about how your automated pipelines connect securely..."

---

## Demo 6: Programmatic Access & Auth [1:05 - 1:20]

### Story Hook
> "Your ML pipelines run overnight. Your ETL jobs run on schedule. They can't use interactive login. Key-pair authentication solves this securely."

### Demo Flow (15 min)

**[1:05-1:08] Service Account Pattern**
```sql
-- Dedicated service accounts per application
SHOW USERS LIKE 'LIFEARC%';
```
*Shows: LIFEARC_ML_SERVICE, LIFEARC_ETL_SERVICE*

```sql
-- Each with dedicated role
SHOW ROLES LIKE 'LIFEARC%';
```
*Shows: LIFEARC_ML_PIPELINE_ROLE, LIFEARC_ETL_SERVICE_ROLE*

**[1:08-1:11] Key-Pair Authentication Explained**
> "No passwords stored. Private key stays with your application, public key registered in Snowflake."

```sql
-- Describe service account
DESC USER LIFEARC_ML_SERVICE;
```
*Note: has_rsa_public_key would be TRUE in production*

Show code pattern (don't execute):
```python
# Python connection with key-pair
from cryptography.hazmat.primitives import serialization
import snowflake.connector

with open("rsa_key.p8", "rb") as key_file:
    private_key = serialization.load_pem_private_key(
        key_file.read(),
        password=b'passphrase'
    )

conn = snowflake.connector.connect(
    user='LIFEARC_ML_SERVICE',
    account='your_account',
    private_key=private_key,
    warehouse='DEMO_WH',
    database='LIFEARC_POC'
)
```

**[1:11-1:14] Network Policies**
> "Defense in depth - even with the right key, only approved IP ranges can connect."

```sql
-- Network restrictions
SHOW NETWORK POLICIES LIKE 'LIFEARC%';
```
*Shows: LIFEARC_ML_NETWORK_POLICY with 3 allowed IP ranges*

**[1:14-1:17] API Pattern for ML Pipelines**
```sql
-- Inference batch retrieval for ML pipeline
CALL LIFEARC_POC.ML_FEATURES.GET_INFERENCE_BATCH('LA-2024-001', 5);
```
*Returns JSON array of patient features ready for model inference*

**[1:17-1:20] OAuth Integration**
```sql
-- For user-facing apps
SHOW SECURITY INTEGRATIONS LIKE 'LIFEARC%';
```
*Shows: LIFEARC_CUSTOM_OAUTH*

### Key Message
> "Key-pair for automation, OAuth for users, network policies for everyone. Full audit of every connection."

---

# CLOSING [1:20 - 1:30]

## Summary Slide

| Use Case | Solution | Key Benefit |
|----------|----------|-------------|
| Data Archiving | Snowflake + Azure Blob | Searchable, governed, cost-optimized |
| MLOps | Feature Store + Lineage | 80% SQL, full traceability |
| Azure ML | Native Integration | No data silos, bidirectional |
| Unstructured Data | Snowpark + Cortex | Parse anything, AI-ready |
| Governance | Tags + Policies | Compliance without complexity |
| Programmatic Access | Key-pair + Network | Secure automation at scale |

## Recommended Next Steps

1. **POC Extension** - Connect to real LifeArc data sample
2. **Architecture Review** - Deep dive on Use Case 1 (250TB archive)
3. **Security Workshop** - Key-pair setup with your Azure Key Vault
4. **Streamlit Deployment** - Deploy Demo 4 app in Snowsight

## Q&A Preparation

### Anticipated Questions

**Q: How does Snowflake pricing compare to Ctera for 250TB?**
> A: Storage is similar (compressed), but you gain discoverability, governance, and SQL access. The question is: what's the cost of NOT finding your data?

**Q: Can we use existing Azure AD for authentication?**
> A: Yes - External OAuth integration with Azure AD. Users authenticate via SSO, Snowflake trusts Azure AD tokens.

**Q: What about HIPAA compliance?**
> A: Snowflake is HIPAA-eligible. Masking policies + row access + encryption + audit logs = compliance framework.

**Q: How do we migrate 250TB?**
> A: Phased approach. Start with metadata catalog, files stay in Azure Blob. Migrate hot data first, cold data references.

---

## Emergency Fallbacks

### If Cortex LLM times out:
```sql
-- Simpler query
SELECT SNOWFLAKE.CORTEX.COMPLETE('llama3.1-8b', 'Hello') AS test;
```

### If UDF fails:
```sql
-- Show pre-loaded data instead
SELECT * FROM LIFEARC_POC.UNSTRUCTURED_DATA.GENE_SEQUENCES;
```

### If role doesn't exist:
```sql
-- Stay as ACCOUNTADMIN, explain concept verbally
SELECT CURRENT_ROLE();
```

---

## Post-Workshop

- [ ] Send this walkthrough document to customer
- [ ] Share GitHub repo access
- [ ] Schedule follow-up for architecture deep-dive
- [ ] Create POC extension proposal

---

*Generated for LifeArc POC Workshop - January 2026*
