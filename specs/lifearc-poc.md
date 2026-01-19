# LifeArc POC Specification

## Overview
2-day POC for LifeArc demonstrating Snowflake capabilities for life sciences data.

## Use Cases

### Use Case 4: Unstructured Data Handling
- Parse FASTA genomic sequences via Python UDF
- Store SDF molecular structures with VARIANT
- Query nested JSON clinical trial data
- Use Cortex LLM for semantic analysis
- Create Cortex Search for document retrieval

### Use Case 5: Data Contracts & Sharing
- Implement data classification tags
- Create masking policies (patient IDs, genetic data)
- Create row access policies (study-level)
- Set up secure data sharing
- Enable audit logging

### Use Case 6: Programmatic Access & Auth
- Document key-pair authentication
- Create service account patterns
- Set up network policies
- Provide Python SDK examples

## Success Criteria
1. All UDFs compile and execute without errors
2. Cortex LLM returns meaningful gene analysis
3. Masking policies hide data appropriately per role
4. Row access policies filter correctly
5. Secure shares can be created
6. Python connection examples are runnable
7. Streamlit app loads and demonstrates all features

## Sample Data
- 5 gene sequences (BRCA1, TP53, EGFR, MYC, KRAS)
- 3 compounds (Aspirin, Ibuprofen, Paracetamol)
- 1 clinical trial protocol (JSON)
- 8 clinical trial results (tabular)
