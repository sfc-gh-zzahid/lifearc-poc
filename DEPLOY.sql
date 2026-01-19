/*
================================================================================
 LIFEARC POC - CONSOLIDATED DEPLOYMENT SCRIPT
================================================================================
 
 PURPOSE: Single idempotent script to deploy entire LifeArc POC in any Snowflake account
 
 USAGE:
   1. Connect to Snowflake as ACCOUNTADMIN (or role with CREATE DATABASE)
   2. Run this entire script
   3. Script is idempotent - safe to re-run
 
 REQUIREMENTS:
   - ACCOUNTADMIN role (or equivalent)
   - Warehouse: DEMO_WH will be created if doesn't exist
   - Cortex LLM access (llama3.1-8b model)
   - Anaconda packages enabled for Python UDFs
 
 ESTIMATED RUN TIME: ~2 minutes
 
 VERSION: 1.0.0
 LAST UPDATED: 2026-01-19
================================================================================
*/

-- =============================================================================
-- SECTION 0: PREREQUISITES
-- =============================================================================
USE ROLE ACCOUNTADMIN;

-- Create warehouse if not exists
CREATE WAREHOUSE IF NOT EXISTS DEMO_WH
    WAREHOUSE_SIZE = 'XSMALL'
    AUTO_SUSPEND = 300
    AUTO_RESUME = TRUE;

USE WAREHOUSE DEMO_WH;

-- =============================================================================
-- SECTION 1: DATABASE AND SCHEMAS
-- =============================================================================
CREATE DATABASE IF NOT EXISTS LIFEARC_POC;

USE DATABASE LIFEARC_POC;

-- Core schemas for demo
CREATE SCHEMA IF NOT EXISTS UNSTRUCTURED_DATA COMMENT = 'Demo 4: Unstructured and semi-structured data handling';
CREATE SCHEMA IF NOT EXISTS DATA_SHARING COMMENT = 'Demo 5: Data contracts and sharing patterns';
CREATE SCHEMA IF NOT EXISTS GOVERNANCE COMMENT = 'Governance objects: tags, policies, audit';
CREATE SCHEMA IF NOT EXISTS AUTH_ACCESS COMMENT = 'Demo 6: Programmatic access and authentication';
CREATE SCHEMA IF NOT EXISTS ML_FEATURES COMMENT = 'ML feature store and model registry';
CREATE SCHEMA IF NOT EXISTS ARCHIVE COMMENT = 'Enterprise archive catalog';
CREATE SCHEMA IF NOT EXISTS ARCHITECTURE COMMENT = 'Architecture reference artifacts';
CREATE SCHEMA IF NOT EXISTS AZURE_ML_INTEGRATION COMMENT = 'Azure ML integration objects';

-- Bronze/Silver/Gold tiers for pipeline demo
CREATE SCHEMA IF NOT EXISTS BRONZE COMMENT = 'Raw ingested data';
CREATE SCHEMA IF NOT EXISTS SILVER COMMENT = 'Cleaned and validated data';
CREATE SCHEMA IF NOT EXISTS GOLD COMMENT = 'Analytics-ready aggregated data';

-- =============================================================================
-- SECTION 2: UNSTRUCTURED DATA TABLES
-- =============================================================================
USE SCHEMA UNSTRUCTURED_DATA;

-- Gene Sequences Table
CREATE OR REPLACE TABLE GENE_SEQUENCES (
    sequence_id VARCHAR(50) PRIMARY KEY,
    gene_name VARCHAR(100),
    organism VARCHAR(100),
    sequence TEXT,
    sequence_length INT,
    gc_content FLOAT,
    upload_timestamp TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    metadata VARIANT
);

-- Clinical Trials Table (JSON/VARIANT)
CREATE OR REPLACE TABLE CLINICAL_TRIALS (
    trial_id VARCHAR(50) PRIMARY KEY,
    protocol_data VARIANT,
    created_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    updated_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

-- Compound Library Table
CREATE OR REPLACE TABLE COMPOUND_LIBRARY (
    compound_id VARCHAR(50) PRIMARY KEY,
    molecule_name VARCHAR(200),
    smiles VARCHAR(500),
    mol_block TEXT,
    properties VARIANT,
    created_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

-- Research Documents Table
CREATE OR REPLACE TABLE RESEARCH_DOCUMENTS (
    doc_id VARCHAR(50) PRIMARY KEY,
    doc_type VARCHAR(50),
    title VARCHAR(500),
    content TEXT,
    keywords ARRAY,
    created_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

-- =============================================================================
-- SECTION 3: DATA SHARING TABLES
-- =============================================================================
USE SCHEMA DATA_SHARING;

-- Clinical Trial Results (main table with governance applied)
CREATE OR REPLACE TABLE CLINICAL_TRIAL_RESULTS (
    result_id VARCHAR(50) PRIMARY KEY,
    trial_id VARCHAR(50),
    patient_id VARCHAR(50),
    site_id VARCHAR(50),
    cohort VARCHAR(50),
    treatment_arm VARCHAR(50),
    response_category VARCHAR(50),
    pfs_months FLOAT,
    os_months FLOAT,
    adverse_events VARCHAR(200),
    biomarker_status VARCHAR(100),
    patient_age INT,
    patient_sex VARCHAR(10),
    created_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

-- Partner Data Staging Table
CREATE OR REPLACE TABLE PARTNER_DATA_STAGING (
    staging_id VARCHAR(50) PRIMARY KEY,
    partner_id VARCHAR(50),
    data_type VARCHAR(50),
    payload VARIANT,
    ingested_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    processed BOOLEAN DEFAULT FALSE
);

-- =============================================================================
-- SECTION 4: GOVERNANCE OBJECTS
-- =============================================================================
USE SCHEMA GOVERNANCE;

-- Site Access Mapping (for row-level security)
CREATE OR REPLACE TABLE SITE_ACCESS_MAPPING (
    role_name VARCHAR(100),
    allowed_site_id VARCHAR(50)
);

-- Data Access Audit Log (for governance demo)
CREATE OR REPLACE TABLE DATA_ACCESS_AUDIT_LOG (
    query_id VARCHAR(100) PRIMARY KEY,
    user_name VARCHAR(100),
    role_name VARCHAR(100),
    query_text TEXT,
    tables_accessed ARRAY,
    query_start_time TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    execution_status VARCHAR(50),
    rows_returned INT
);

-- API Access Log (for programmatic access patterns)
CREATE OR REPLACE TABLE API_ACCESS_LOG (
    log_id VARCHAR(50) PRIMARY KEY,
    api_key_id VARCHAR(50),
    endpoint VARCHAR(200),
    method VARCHAR(10),
    request_timestamp TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    response_status VARCHAR(50),
    response_time_ms INT,
    client_ip VARCHAR(50),
    user_agent VARCHAR(200),
    request_payload_size INT,
    response_payload_size INT
);

-- Data Classification Tags
CREATE TAG IF NOT EXISTS DATA_SENSITIVITY ALLOWED_VALUES 'PUBLIC', 'INTERNAL', 'CONFIDENTIAL', 'RESTRICTED';
CREATE TAG IF NOT EXISTS DATA_DOMAIN ALLOWED_VALUES 'CLINICAL', 'GENOMIC', 'COMPOUND', 'ADMINISTRATIVE';
CREATE TAG IF NOT EXISTS PII_TYPE ALLOWED_VALUES 'PATIENT_ID', 'AGE', 'NAME', 'LOCATION', 'NONE';
CREATE TAG IF NOT EXISTS RETENTION_PERIOD ALLOWED_VALUES '1_YEAR', '3_YEARS', '7_YEARS', 'PERMANENT';

-- Masking Policy for Patient ID
CREATE OR REPLACE MASKING POLICY MASK_PATIENT_ID AS (val VARCHAR) RETURNS VARCHAR ->
    CASE
        WHEN CURRENT_ROLE() IN ('ACCOUNTADMIN', 'CLINICAL_DATA_ADMIN') THEN val
        WHEN CURRENT_ROLE() IN ('CLINICAL_ANALYST') THEN 'PAT-XXXX-' || RIGHT(val, 4)
        ELSE '***MASKED***'
    END;

-- Masking Policy for Age (returns ranges)
CREATE OR REPLACE MASKING POLICY MASK_AGE AS (val INT) RETURNS INT ->
    CASE
        WHEN CURRENT_ROLE() IN ('ACCOUNTADMIN', 'CLINICAL_DATA_ADMIN') THEN val
        ELSE FLOOR(val / 10) * 10  -- Returns decade (50, 60, 70, etc.)
    END;

-- Row Access Policy (site-based)
CREATE OR REPLACE ROW ACCESS POLICY SITE_BASED_ACCESS AS (site_id VARCHAR) RETURNS BOOLEAN ->
    CURRENT_ROLE() IN ('ACCOUNTADMIN', 'CLINICAL_DATA_ADMIN')
    OR EXISTS (
        SELECT 1 FROM LIFEARC_POC.GOVERNANCE.SITE_ACCESS_MAPPING
        WHERE role_name = CURRENT_ROLE()
        AND allowed_site_id = site_id
    );

-- =============================================================================
-- SECTION 5: AUTH & ACCESS OBJECTS
-- =============================================================================
USE SCHEMA AUTH_ACCESS;

-- Network Policy
CREATE NETWORK POLICY IF NOT EXISTS LIFEARC_ML_NETWORK_POLICY
    ALLOWED_IP_LIST = ('0.0.0.0/0')  -- Replace with actual IPs in production
    COMMENT = 'Network policy for ML pipeline access';

-- Create roles for RBAC demo
CREATE ROLE IF NOT EXISTS LIFEARC_ML_PIPELINE_ROLE;
CREATE ROLE IF NOT EXISTS LIFEARC_ETL_SERVICE_ROLE;
CREATE ROLE IF NOT EXISTS LIFEARC_ANALYST_ROLE;
CREATE ROLE IF NOT EXISTS CLINICAL_DATA_ADMIN;
CREATE ROLE IF NOT EXISTS CLINICAL_ANALYST;

-- Grant basic permissions
GRANT USAGE ON DATABASE LIFEARC_POC TO ROLE LIFEARC_ML_PIPELINE_ROLE;
GRANT USAGE ON DATABASE LIFEARC_POC TO ROLE LIFEARC_ETL_SERVICE_ROLE;
GRANT USAGE ON DATABASE LIFEARC_POC TO ROLE LIFEARC_ANALYST_ROLE;
GRANT USAGE ON DATABASE LIFEARC_POC TO ROLE CLINICAL_DATA_ADMIN;
GRANT USAGE ON DATABASE LIFEARC_POC TO ROLE CLINICAL_ANALYST;

-- Create service users (note: passwords should be changed in production)
CREATE USER IF NOT EXISTS LIFEARC_ML_SERVICE
    PASSWORD = 'ChangeMe123!'
    DEFAULT_ROLE = LIFEARC_ML_PIPELINE_ROLE
    DEFAULT_WAREHOUSE = DEMO_WH
    COMMENT = 'Service account for ML pipeline';

CREATE USER IF NOT EXISTS LIFEARC_ETL_SERVICE
    PASSWORD = 'ChangeMe123!'
    DEFAULT_ROLE = LIFEARC_ETL_SERVICE_ROLE
    DEFAULT_WAREHOUSE = DEMO_WH
    COMMENT = 'Service account for ETL processes';

GRANT ROLE LIFEARC_ML_PIPELINE_ROLE TO USER LIFEARC_ML_SERVICE;
GRANT ROLE LIFEARC_ETL_SERVICE_ROLE TO USER LIFEARC_ETL_SERVICE;

-- Stage for partner data ingestion
CREATE STAGE IF NOT EXISTS LIFEARC_POC.DATA_SHARING.PARTNER_DATA_STAGE
    COMMENT = 'Stage for partner data file uploads';

-- Secret for external API (demo purposes)
CREATE SECRET IF NOT EXISTS LIFEARC_POC.AUTH_ACCESS.EXTERNAL_MODEL_API_KEY
    TYPE = GENERIC_STRING
    SECRET_STRING = 'demo-api-key-replace-in-production'
    COMMENT = 'API key for external model endpoints';

-- =============================================================================
-- SECTION 6: PYTHON UDF - FASTA PARSER
-- =============================================================================
USE SCHEMA UNSTRUCTURED_DATA;

CREATE OR REPLACE FUNCTION PARSE_FASTA(fasta_content VARCHAR)
RETURNS TABLE (
    sequence_id VARCHAR,
    gene_name VARCHAR,
    seq_length INT,
    gc_content FLOAT,
    sequence TEXT
)
LANGUAGE PYTHON
RUNTIME_VERSION = '3.11'
PACKAGES = ('pandas')
HANDLER = 'FastaParser'
AS $$
import pandas as pd
from typing import Tuple

class FastaParser:
    def process(self, fasta_content: str) -> Tuple[str, str, int, float, str]:
        sequences = []
        current_id = ""
        current_seq = []
        
        for line in fasta_content.strip().split('\n'):
            line = line.strip()
            if line.startswith('>'):
                if current_id and current_seq:
                    seq = ''.join(current_seq)
                    gc = self._calc_gc(seq)
                    parts = current_id.split('|')
                    gene_name = parts[1].strip() if len(parts) > 1 else parts[0].split('_')[0]
                    sequences.append((current_id.split()[0].replace('>', ''), gene_name, len(seq), gc, seq))
                current_id = line[1:]
                current_seq = []
            else:
                current_seq.append(line.upper().replace(' ', ''))
        
        # Don't forget last sequence
        if current_id and current_seq:
            seq = ''.join(current_seq)
            gc = self._calc_gc(seq)
            parts = current_id.split('|')
            gene_name = parts[1].strip() if len(parts) > 1 else parts[0].split('_')[0]
            sequences.append((current_id.split()[0].replace('>', ''), gene_name, len(seq), gc, seq))
        
        for s in sequences:
            yield s
    
    def _calc_gc(self, seq: str) -> float:
        if not seq:
            return 0.0
        gc_count = seq.count('G') + seq.count('C')
        return round((gc_count / len(seq)) * 100, 2)
$$;

-- =============================================================================
-- SECTION 7: ML FEATURES PROCEDURE
-- =============================================================================
USE SCHEMA ML_FEATURES;

CREATE OR REPLACE PROCEDURE GET_INFERENCE_BATCH(p_trial_id VARCHAR, p_batch_size INT)
RETURNS VARIANT
LANGUAGE SQL
AS
$
DECLARE
    result VARIANT;
BEGIN
    SELECT ARRAY_AGG(
        OBJECT_CONSTRUCT(
            'patient_id', patient_id,
            'features', OBJECT_CONSTRUCT(
                'age', patient_age,
                'sex', patient_sex,
                'arm', treatment_arm,
                'biomarker', biomarker_status,
                'site', site_id
            ),
            'prediction_ready', TRUE
        )
    ) INTO :result
    FROM LIFEARC_POC.DATA_SHARING.CLINICAL_TRIAL_RESULTS
    WHERE trial_id = :p_trial_id
    LIMIT :p_batch_size;
    
    RETURN result;
END;
$;

-- =============================================================================
-- SECTION 8: VIEWS
-- =============================================================================
USE SCHEMA DATA_SHARING;

-- Partner view with built-in anonymization
CREATE OR REPLACE SECURE VIEW CLINICAL_RESULTS_PARTNER_VIEW AS
SELECT 
    result_id,
    trial_id,
    patient_id AS masked_patient_id,  -- Will be masked by policy
    site_id,
    cohort,
    treatment_arm,
    response_category,
    pfs_months,
    os_months,
    CASE 
        WHEN adverse_events LIKE '%Grade3%' OR adverse_events LIKE '%Grade4%' THEN 'Severe'
        WHEN adverse_events LIKE '%Grade2%' THEN 'Moderate'
        WHEN adverse_events LIKE '%Grade1%' THEN 'Mild'
        ELSE 'None'
    END AS adverse_event_severity,
    biomarker_status,
    patient_age AS age_range,  -- Will be masked by policy
    patient_sex
FROM CLINICAL_TRIAL_RESULTS;

USE SCHEMA GOVERNANCE;

-- Data contracts summary view
CREATE OR REPLACE VIEW DATA_CONTRACTS_SUMMARY AS
SELECT 
    'CLINICAL_TRIAL_RESULTS' AS table_name,
    'DATA_SHARING' AS schema_name,
    COUNT(*) AS row_count,
    MAX(created_at) AS last_updated,
    'Active' AS contract_status
FROM LIFEARC_POC.DATA_SHARING.CLINICAL_TRIAL_RESULTS
GROUP BY 1, 2;

-- =============================================================================
-- SECTION 9: APPLY GOVERNANCE POLICIES
-- =============================================================================

-- Apply masking policies to clinical trial results
ALTER TABLE LIFEARC_POC.DATA_SHARING.CLINICAL_TRIAL_RESULTS
    MODIFY COLUMN patient_id SET MASKING POLICY LIFEARC_POC.GOVERNANCE.MASK_PATIENT_ID;

ALTER TABLE LIFEARC_POC.DATA_SHARING.CLINICAL_TRIAL_RESULTS
    MODIFY COLUMN patient_age SET MASKING POLICY LIFEARC_POC.GOVERNANCE.MASK_AGE;

-- Apply row access policy
ALTER TABLE LIFEARC_POC.DATA_SHARING.CLINICAL_TRIAL_RESULTS
    ADD ROW ACCESS POLICY LIFEARC_POC.GOVERNANCE.SITE_BASED_ACCESS ON (site_id);

-- Apply tags to sensitive columns
ALTER TABLE LIFEARC_POC.DATA_SHARING.CLINICAL_TRIAL_RESULTS
    MODIFY COLUMN patient_id SET TAG LIFEARC_POC.GOVERNANCE.PII_TYPE = 'PATIENT_ID';

ALTER TABLE LIFEARC_POC.DATA_SHARING.CLINICAL_TRIAL_RESULTS
    MODIFY COLUMN patient_age SET TAG LIFEARC_POC.GOVERNANCE.PII_TYPE = 'AGE';

ALTER TABLE LIFEARC_POC.DATA_SHARING.CLINICAL_TRIAL_RESULTS
    SET TAG LIFEARC_POC.GOVERNANCE.DATA_SENSITIVITY = 'CONFIDENTIAL';

ALTER TABLE LIFEARC_POC.DATA_SHARING.CLINICAL_TRIAL_RESULTS
    SET TAG LIFEARC_POC.GOVERNANCE.DATA_DOMAIN = 'CLINICAL';

-- =============================================================================
-- SECTION 10: LOAD SAMPLE DATA
-- =============================================================================

-- Gene Sequences
INSERT INTO LIFEARC_POC.UNSTRUCTURED_DATA.GENE_SEQUENCES 
    (sequence_id, gene_name, organism, sequence, sequence_length, gc_content, metadata)
SELECT 'BRCA1_001', 'BRCA1', 'Homo sapiens', 
    'ATGGATTTATCTGCTCTTCGCGTTGAAGAAGTACAAAATGTCATTAATGCTATGCAGAAAATCTTAGAGTGTCCCATCTGTCTGGAGTTGATCAAGGAACCTGTCTCCACAAAGTGTGACCACATATTTTGCAAATTTTGCATGCTGAAACTTCTCAACCAGAAGAAAGGGCCTTCACAGTGTCCTTTATGTAAGAATGATATAACCAAAAGGAGCCTACAAGAAAGTACGAGATTTAGTCAACTTGTTGAAGAGCTATTGAAAATCATTTGTGCTTTTCAGCTTGACACAGGTTTGGAGTATGCAAACAGCTATAATTTTGCAAAAAAGGAAAATAACTCTCCTGAACATC',
    301, 38.54, PARSE_JSON('{"reference": "NM_007294.4", "clinical_significance": "pathogenic_variants_common"}')
WHERE NOT EXISTS (SELECT 1 FROM LIFEARC_POC.UNSTRUCTURED_DATA.GENE_SEQUENCES WHERE sequence_id = 'BRCA1_001');

INSERT INTO LIFEARC_POC.UNSTRUCTURED_DATA.GENE_SEQUENCES 
    (sequence_id, gene_name, organism, sequence, sequence_length, gc_content, metadata)
SELECT 'TP53_001', 'TP53', 'Homo sapiens',
    'ATGGAGGAGCCGCAGTCAGATCCTAGCGTCGAGCCCCCTCTGAGTCAGGAAACATTTTCAGACCTATGGAAACTACTTCCTGAAAACAACGTTCTGTCCCCCTTGCCGTCCCAAGCAATGGATGATTTGATGCTGTCCCCGGACGATATTGAACAATGGTTCACTGAAGACCCAGGTCCAGATGAAGCTCCCAGAATGCCAGAGGCTGCTCCCCCCGTGGCCCCTGCACCAGCAGCTCCTACACCGGCGGCCC',
    240, 55.00, PARSE_JSON('{"reference": "NM_000546.6", "clinical_significance": "tumor_suppressor"}')
WHERE NOT EXISTS (SELECT 1 FROM LIFEARC_POC.UNSTRUCTURED_DATA.GENE_SEQUENCES WHERE sequence_id = 'TP53_001');

INSERT INTO LIFEARC_POC.UNSTRUCTURED_DATA.GENE_SEQUENCES 
    (sequence_id, gene_name, organism, sequence, sequence_length, gc_content, metadata)
SELECT 'EGFR_001', 'EGFR', 'Homo sapiens',
    'ATGCGACCCTCCGGGACGGCCGGGGCAGCGCTCCTGGCGCTGCTGGCTGCGCTCTGCCCGGCGAGTCGGGCTCTGGAGGAAAAGAAAGTTTGCCAAGGCACGAGTAACAAGCTCACGCAGTTGGGCACTTTTGAAGATCATTTTCTCAGCCTCCAGAGGATGTTCAATAACTGTGAGGTGGTCCTTGGGAATTTGGAAATTACCTATGTGCAGAGGAATTATGATCTTTCCTTCTTAAAG',
    240, 53.33, PARSE_JSON('{"reference": "NM_005228.5", "clinical_significance": "targeted_therapy_marker"}')
WHERE NOT EXISTS (SELECT 1 FROM LIFEARC_POC.UNSTRUCTURED_DATA.GENE_SEQUENCES WHERE sequence_id = 'EGFR_001');

INSERT INTO LIFEARC_POC.UNSTRUCTURED_DATA.GENE_SEQUENCES 
    (sequence_id, gene_name, organism, sequence, sequence_length, gc_content, metadata)
SELECT 'MYC_001', 'MYC', 'Homo sapiens',
    'ATGCCCCTCAACGTTAGCTTCACCAACAGGAACTATGACCTCGACTACGACTCGGTGCAGCCGTATTTCTACTGCGACGAGGAGGAGAACTTCTACCAGCAGCAGCAGCAGAGCGAGCTGCAGCCCCCGGCGCCCAGCGAGGATATCTGGAAGAAATTCGAGCTGCTGCCCACCCCGCCCCTGTCCCCTAGCCGCCGCTCCGGGCTCTGCTCGCCCTCCTACGTTGCGGTCACACCCTTCTCCCTTCGGGGAGA',
    240, 62.08, PARSE_JSON('{"reference": "NM_002467.6", "clinical_significance": "oncogene"}')
WHERE NOT EXISTS (SELECT 1 FROM LIFEARC_POC.UNSTRUCTURED_DATA.GENE_SEQUENCES WHERE sequence_id = 'MYC_001');

INSERT INTO LIFEARC_POC.UNSTRUCTURED_DATA.GENE_SEQUENCES 
    (sequence_id, gene_name, organism, description, sequence, sequence_length, gc_content)
SELECT 'KRAS_001', 'KRAS', 'Homo sapiens', 'KRAS proto-oncogene - G12C driver mutation target',
    'ATGACTGAATATAAACTTGTGGTAGTTGGAGCTGGTGGCGTAGGCAAGAGTGCCTTGACGATACAGCTAATTCAGAATCATTTTGTGGACGAATATGATCCAACAATAGAGGATTCCTACAGGAAGCAAGTAGTAATTGATGGAGAAACCTGTCTCTTGGATATTCTCGACACAGCAGGTCAAGAGGAGTACAGTGCAATGAGGGACCAGTACATGAGGACTGGGGAGGGCTTTCTTTGTGTATTTGCCATAA',
    240, 38.75
WHERE NOT EXISTS (SELECT 1 FROM LIFEARC_POC.UNSTRUCTURED_DATA.GENE_SEQUENCES WHERE sequence_id = 'KRAS_001');

-- Additional gene sequences (10 more oncogenes and tumor suppressors)
MERGE INTO LIFEARC_POC.UNSTRUCTURED_DATA.GENE_SEQUENCES tgt
USING (
    SELECT 'GENE_PIK3CA_HUMAN' AS seq_id, 'PIK3CA' AS gene, 'Homo sapiens' AS org, 'PIK3CA catalytic subunit alpha - oncogene' AS descr,
        'ATGCCTCCACGACCATCATCAGGTGAACTGTGGGGAGGAGATGTCTCCAGTTTTCTTTTCTGTCAATGGTTGAGACTGGACAAACGTAGGGCACAGATGGCTTTGAAGATTTCTGTGGGAAATCAGTGAAAGAAATTGAAGAGGCAGAAACTGAAGTTATGCGTGGACCAATATTTGATGATACATACAGGGATGGAAAGAATGCTGTTCGACAAGAAAATCTGCTTGTTACTCGGAAATGGAAGATTAAAAGAAGTGCTTTAAAATTGTTGAAGAAATCAATGTATACTTATTTGATGCAAGATGACAATGACATAGTTTTCAAAAAAGATATGCTAACCAATTCAGGAGAAGATTATGTTAACGATTTAAGTGATGAAGGTACTCAGGATTTGACTATACTGTTGGATTCAGCATTAAAAGAGAATAATCAGCACATTAGAGAAATAAAAGATATAAGACGGGATTTACGGTTTAAACAAGGGATGAAGAAATACATTGAAGAAGAAGAAAGTGAAATGGACTTTGAAGA' AS seq, 620 AS len, 42.58 AS gc
    UNION ALL SELECT 'GENE_AKT1_HUMAN', 'AKT1', 'Homo sapiens', 'AKT serine/threonine kinase 1 - oncogene',
        'ATGAGCGACGTGGCTATTGTGAAGGAGGGTTGGCTGCACAAACGAGGGGAGTACATCAAGACCTGGCGGCCACGCTACTTCCTCCTCAAGAATGATGGCACCTTCATTGGCTACAAGGAGCGGCCGCAGGATGTGGACCAACGTGAGGCTCCCCTCAACAACTTCTCTGTGGCGCAGTGCCAGCTGATGAAGACGGAGCGGCCCCGGCAGAACAGCAAGAACGAGATCCACGAGGAGGCCAAAGACTTCCTGAACATCATGCTCAATGATGGGGGAGGGCGCCTGGAGAACCTCATGCTGGACAAGGACGGGCACATTAAGATCACAGACTTCGGGCTGTGCAAGGAGGGGATCAAGGACGGTGCCACCATGAAGACCTTTTGCGGCACACCTGAGTACCTGGCCCCCGAGGTGCTGGAGGACAATGACTACGGCCGTGCAGTGGACTGGTGGGGGCTGGGCGTGGTCATGTACGAGATGATGTGCGGTCGCCTGCCCTTCTACAACCAGGACCATGAG', 540, 54.26
    UNION ALL SELECT 'GENE_PTEN_HUMAN', 'PTEN', 'Homo sapiens', 'Phosphatase and tensin homolog - tumor suppressor',
        'ATGACAGCCATCATCAAAGAGATCGTTAGCAGAAACAAAAGGAGATATCAAGAGGATGGATTCGACTTAGACTTGACCTATATTTATCCAAACATTATTGCTATGGGATTTCCTGCAGAAAGACTTGAAGGCGTATACAGGAACAATATTGATGATGTAGTAAGGTTTTTGGATTCAAAGCATAAAAACCATTACAAGATATACAATCTTTGTGCTGAAAGACATTATGACACCGCCAAATTTAATTGCAGAGTTGCACAATATCCTTTTGAAGACCATAACCCACCACAGCTAGAACTTATCAAACCCTTTTGTGAAGATCTTGACCAATGGCTAAGTGAAGATGACAATCATGTTGCAGCAATTCACTGTAAAGCTGGAAAGGGACGAACTGGTGTAATGATATGTGCATATTTATTACATCGGGGCAAATTTTTAAAGGCACAAGAGGCCCTAGATTTCTATGGGGAAGTAAGGACCAGAGACAAAAAGGGAGTAACTATTCCCAGTCAGAGGCGCTATGTGTATTATTATAGCTACCTGTTAAAGAATCATCTGGATTATAGACCAGTGGCACTGTTGTTTCACAAGAT', 648, 40.12
    UNION ALL SELECT 'GENE_RB1_HUMAN', 'RB1', 'Homo sapiens', 'RB transcriptional corepressor 1 - tumor suppressor',
        'ATGCCGCCCAAAACCCCCCGAAAAACGGCCGCCACCATGAACTTCGCCAGCAGAGTTGAAGAGGAACTGCTGGAGAGCGACGAGCAGCTGGACGATGACAGAGATGAAGATGGAACCACCGAAGAAAATCTTCATGAAGACAAAATTTTAGAATTGGATGATTCAGAAGAAAGTGATGATGAAGAAATCAATGAAGAAGTTGAAGAGTCACCTGAAAATGATGAAACTATTAATGAAGACATCGATGATGCAGCATTGTCCAGTAGCAGTGGTAGTCCTAGTAACGAGGATATTAGCGATAATAGCAGCAGCAGTGGTCCCAGTCCTGAAGACAAAGAAGAAACTGATCCTGTGCCCAAAGGGAAAGTTGAAAATGATGATGAAGATGCCAGTCCAGATGATGATGATATTGAAGAAAGTATCTCTTCACAAGAAGAAGCTGAAGAACTTGTTGAAGTTGAAGAAGAAGAAGAAGAAGAGGAAGATGATGATCAAGATGAAGATGATGATGACAGTGAAGAAGAAGAAGAAGAAGAAGATGATGACGATGATGATGATG', 660, 46.82
    UNION ALL SELECT 'GENE_BRAF_HUMAN', 'BRAF', 'Homo sapiens', 'B-Raf proto-oncogene - V600E mutation target',
        'ATGGCGGCGCTGAGCGGTGGCGGTGGTGGCGGCGCGGAGCCGGGCCAGGCTCTGTTCAACGGGGACATGGAGCCCGAGGCCGGCGCCGGCGCCGGCGCCGCGGCCTCTTCGGCTGCGGACCCTGCCATTCCGGAGGAGGTGTGGAATATCAAACAAATGATTAAGTTGACACAGGAACATATAGAGGCCCTATTGGACAAATTTGGTGGGGAGCATAATCCACCATCAATATATCTGGAGGCCTATGAAGAATACACCAGCAAGCTAGATGCACTCCAACAAAGAGAACAACAGTTATTGGAATCTCTGGGGAACGGAACTGATTTTTCTGTTTCTAGCTCTGCATCAATGGATACCGTTACATCTTCTTCCTCTTCTAGCCTTTCAGTGCTACCTTCATCTCTTTCAGTTTTTCAAAACCTATTAAAGAAACATTTTCTCAATGACTACTCCAATCATGAGATTCCTGAGGCTCTTTCTTTAAAAGGAAAAGGATTTATTCTAGCTGTAGCAGATCAACCTGTAATTATCCATGGAGCAACTTATTACATCGGTGAAGGAATGGAAA', 612, 52.78
    UNION ALL SELECT 'GENE_ALK_HUMAN', 'ALK', 'Homo sapiens', 'ALK receptor tyrosine kinase - fusion target in NSCLC',
        'ATGGAACTTCTCTTGCTCTTGCTGCTCGCCCTTGCTGCACAAGGTTCTTCCAAGTGTACAGAGGGCAGGGCAAGTCTCATCCTTGGGAGAAGCTCAAGTCAGCTGTTGAGTGCTCAGATCAAATGCAGTGAAGATCCCTTTCTCTGCTCTGGTTCATCAGTGTGTCAGAAGATACTTGAAGATGGAAGCGTTCAGCAAAGTGATGAAGATGAAGATCCACAGCTGGAAGGCCTAGACATTGCCCTGTTATTTGATTTAGACACTGGAACTGCTGACACCCCAAGAGACATTTCTGCCACGTACCTGTATGCATATTTTGAATGTGCCAATGACCCCAGCAGCCAAAGAATCATTTGTTACAGTGCCTTCGGTAAGCTTGGAAATACTCTGAGTGATGCCAGCAATTGCTACCAGAAGAATGTCTTTACCCTTAATATTGATCACCCTGAATGTATCTGTCCAAGGGCAGAATATGTCATCTATATAGATGGTGACTTGCCACCTTTGGATATTGATGAATGTGCATTCTTGGATCAGTTTTCTTCA', 582, 44.85
    UNION ALL SELECT 'GENE_MET_HUMAN', 'MET', 'Homo sapiens', 'MET proto-oncogene - receptor tyrosine kinase',
        'ATGAAGGCCCCCGCTGTGCTTGCACCTGGCATCCTCGTGCTCCTGTTTACCTTGGTGCAGAGGAGCAATGGGGAGTGTAAAGAGGCACTAGCAGAATGTCAGTGCCTCTCTGAAAGTGGAATCAAGATTCCTGATGTGGACATACTCAACAAGTATTATAGCAAGAAGTATGGCTACTGCTCCCAGAAAGAATGTGAATTTCATTGCCAGATCCAGTTTCCTAATTCATCTCAGAACGGTTCATGCCGACAAGTGCAGTATGTTCGCAAGAGTGATACCAGCATTGTGAATCAGAACATCGATGAGACTCTGTGCTACAAGAAATGTCATAATGAATACTGTGCAATCAAGTGTGCAGACAACGTATCCTGTGCCGAATGTCGCCGAAGTCATAAATGCACTTCCTTTAATGTCTTCAATGTCAGCACAAATCAGTGTCCCTCGTGCAGGAAGAGCTATAAATGTACACCAGGAATTTCAGCAAACTGTCCAGAATGTGTCCGCCATGTTTGGGATGTTCACAATGAAGGTTGT', 612, 45.92
    UNION ALL SELECT 'GENE_ERBB2_HUMAN', 'ERBB2', 'Homo sapiens', 'Erb-b2 receptor tyrosine kinase 2 - HER2 amplification target',
        'ATGGAGCTGGCGGCCTTGTGCCGCTGGGGGCTCCTCCTCGCCCTCTTGCCCCCCGGAGCCGCGAGCACCCAAGTGTGCACCGGCACAGACATGAAGCTGCGGCTCCCTGCCAGTCCCGAGACCCACCTGGACATGCTCCGCCACCTCTACCAGGGCTGCCAGGTGGTGCAGGGAAACCTGGAACTCACCTACCTGCCCACCAATGCCAGCCTGTCCTTCCTGCAGGATATCCAGGAGGTGCAGGGCTACGTGCTCATCGCTCACAACCAAGTGAGGCAGGTCCCACTGCAGAGGCTGCGGATTGTGCGAGGCACCCAGCTCTTTGAGGACAACTATGCCCTGGCCGTGCTAGACAATGGAGACCCGCTGAACAATACCACCCCTGTCACAGGGGCCTCCCCAGGAGGCCTGCGGGAGCTGCAGCTTCGAAGCCTCACAGAGATCTTGAAAGGAGGGGTCTTGATCCAGCGGAACCCCCAGCTCTGCTACCAGGACACGATTTTGTGGAAGGACATCTTCCACAAGAACAACCAGCTGGCTCTCACACTGATAGACACCAACCGCTCTCGGGCCTGCCACCCCTGTTCTCCGATGT', 684, 58.19
    UNION ALL SELECT 'GENE_NRAS_HUMAN', 'NRAS', 'Homo sapiens', 'NRAS proto-oncogene - RAS pathway member',
        'ATGACTGAGTACAAACTGGTGGTGGTTGGAGCAGGTGGTGTTGGGAAAAGCGCACTGACAATCCAGCTAATCCAGAACCACTTTGTAGATGAATATGATCCCACCATAGAGGATTCTTACAGAAAGCAGGTTGTTGATGGAGAAACCTGTCTCTTGGATATTCTCGACACAGCTGGGCTAGAAGATGAGAAAATGCATACACTGATAGAAGAAATTAAAAGAAAATACATTGACTTGTTATTTGAGGATAATTACATGAGGACAGGAGCAGATGACTCCATGAAGAACAAGAAAGAACTAAATCGTGCCGTCTTTGCAAGCATCAAACCAAAGTTTTTAAGGTACAGAGAGAGTCAGGGAACTACTCCACTTGGCCATGATACACTTGTGAATGAAATAGCTAGTATTGAAATCAAGTTACAAAAGATAGAAGAACGAAGACTTTTAAAGGATGTAAACTATATGATTGAAGCATTTAGAACAA', 528, 40.72
    UNION ALL SELECT 'GENE_ARID1A_HUMAN', 'ARID1A', 'Homo sapiens', 'AT-rich interactive domain-containing protein 1A - tumor suppressor',
        'ATGGCTGCGGTGCTGCCTCCGCGGCCTCGGCGGCGGCCGCGGCCGCGGCCGCGGGGGCCGCTGCGGTCCGCCCCCCGCCCGCCGCGGCCGCCGCCGCCGCGGCGGCGGCGGCGGGCGGGGGCTCGCTGCGGCCGCCCCCGGCGCCCTCGGCCGCGGCGGCCGCGGCGGCCGCCGCCGCGGCGGCGCTGCGGCCGCCGCCGCGGCGGCGGCGCGGCGGCTGCGGCGGCCGCTGCGGCCGCGCCCGCCGCCGCCGCCGCCGCCGCGGCCGCCGCTGCGGCGGCGGCCGCCGCCGCGGCGGCTGCGGCGGCCGCCGCCGCCGCCGCCGCCGCCGCGGCCGCCGCCGCGGCGGCCGCGGCTGCGGCGGCGGCCGCCGCCGCCGCCGCCGCCGCCGCGGCGGCGGCCGCGGCGGCGGCGGCTGCGGCGGCTGCGGCGGCGGCCGCCGCCGCGGCGGCGGCGGCGGCTGCGGCGGCGGCCGCCGCCGCCGCCGCGGCGGCGGCGGCGGCCGCGGCTGCGGCGGCCGC', 576, 79.51
) src
ON tgt.sequence_id = src.seq_id
WHEN NOT MATCHED THEN INSERT (sequence_id, gene_name, organism, description, sequence, sequence_length, gc_content)
VALUES (src.seq_id, src.gene, src.org, src.descr, src.seq, src.len, src.gc);

-- Clinical Trial (JSON)
INSERT INTO LIFEARC_POC.UNSTRUCTURED_DATA.CLINICAL_TRIALS (trial_id, protocol_data)
SELECT 'LA-2024-001', PARSE_JSON('{
    "title": "Phase II Clinical Trial - Novel KRAS G12C Inhibitor in NSCLC",
    "phase": "Phase II",
    "indication": "Non-Small Cell Lung Cancer",
    "sponsor": "LifeArc Research",
    "status": "Active",
    "enrollment": {
        "target": 120,
        "current": 87,
        "sites": 12
    },
    "arms": [
        {"name": "ARM_A", "intervention": "LA-KRAS-001 200mg BID", "patients": 60},
        {"name": "ARM_B", "intervention": "LA-KRAS-001 400mg QD", "patients": 60}
    ],
    "primary_endpoints": [
        "Objective Response Rate",
        "Duration of Response"
    ],
    "biomarkers": [
        "ctDNA KRAS G12C VAF",
        "PD-L1 expression",
        "TMB score"
    ]
}')
WHERE NOT EXISTS (SELECT 1 FROM LIFEARC_POC.UNSTRUCTURED_DATA.CLINICAL_TRIALS WHERE trial_id = 'LA-2024-001');

-- Additional Clinical Trials (4 more to reach 5 total)
INSERT INTO LIFEARC_POC.UNSTRUCTURED_DATA.CLINICAL_TRIALS (trial_id, protocol_data)
SELECT 'LA-2024-002', PARSE_JSON('{
    "title": "Phase III Clinical Trial - BRCA1 DDR Inhibitor in Breast Cancer",
    "phase": "Phase III",
    "indication": "BRCA1-Mutant Breast Cancer",
    "sponsor": "LifeArc Research",
    "status": "Active",
    "enrollment": {"target": 450, "current": 312, "sites": 28},
    "arms": [
        {"name": "ARM_A", "intervention": "LA-DDR-001 100mg QD", "patients": 150},
        {"name": "ARM_B", "intervention": "LA-DDR-001 200mg QD", "patients": 150},
        {"name": "ARM_C", "intervention": "Placebo", "patients": 150}
    ],
    "primary_endpoints": ["Overall Survival", "Progression-Free Survival"],
    "biomarkers": ["BRCA1 mutation status", "HRD score", "ctDNA"]
}')
WHERE NOT EXISTS (SELECT 1 FROM LIFEARC_POC.UNSTRUCTURED_DATA.CLINICAL_TRIALS WHERE trial_id = 'LA-2024-002');

INSERT INTO LIFEARC_POC.UNSTRUCTURED_DATA.CLINICAL_TRIALS (trial_id, protocol_data)
SELECT 'LA-2024-003', PARSE_JSON('{
    "title": "Phase I Dose Escalation - Novel EGFR Inhibitor",
    "phase": "Phase I",
    "indication": "Advanced Solid Tumors",
    "sponsor": "LifeArc Research",
    "status": "Recruiting",
    "enrollment": {"target": 60, "current": 42, "sites": 8},
    "arms": [
        {"name": "DOSE_1", "intervention": "LA-EGFR-001 25mg QD", "patients": 15},
        {"name": "DOSE_2", "intervention": "LA-EGFR-001 50mg QD", "patients": 15},
        {"name": "DOSE_3", "intervention": "LA-EGFR-001 100mg QD", "patients": 15},
        {"name": "DOSE_4", "intervention": "LA-EGFR-001 200mg QD", "patients": 15}
    ],
    "primary_endpoints": ["Maximum Tolerated Dose", "Dose-Limiting Toxicities"],
    "biomarkers": ["EGFR mutation status", "T790M resistance"]
}')
WHERE NOT EXISTS (SELECT 1 FROM LIFEARC_POC.UNSTRUCTURED_DATA.CLINICAL_TRIALS WHERE trial_id = 'LA-2024-003');

INSERT INTO LIFEARC_POC.UNSTRUCTURED_DATA.CLINICAL_TRIALS (trial_id, protocol_data)
SELECT 'LA-2023-001', PARSE_JSON('{
    "title": "Phase II Basket Trial - Pan-Cancer MYC Inhibitor",
    "phase": "Phase II",
    "indication": "MYC-Amplified Solid Tumors",
    "sponsor": "LifeArc Research",
    "status": "Completed",
    "enrollment": {"target": 200, "current": 200, "sites": 15},
    "arms": [
        {"name": "ARM_A", "intervention": "LA-MYC-001 150mg BID", "patients": 200}
    ],
    "primary_endpoints": ["Disease Control Rate"],
    "biomarkers": ["MYC amplification", "MYC protein expression"]
}')
WHERE NOT EXISTS (SELECT 1 FROM LIFEARC_POC.UNSTRUCTURED_DATA.CLINICAL_TRIALS WHERE trial_id = 'LA-2023-001');

INSERT INTO LIFEARC_POC.UNSTRUCTURED_DATA.CLINICAL_TRIALS (trial_id, protocol_data)
SELECT 'LA-2023-002', PARSE_JSON('{
    "title": "Phase II Trial - TP53 Reactivation in Colorectal Cancer",
    "phase": "Phase II",
    "indication": "TP53-Mutant Colorectal Cancer",
    "sponsor": "LifeArc Research",
    "status": "Completed",
    "enrollment": {"target": 180, "current": 180, "sites": 12},
    "arms": [
        {"name": "ARM_A", "intervention": "LA-TP53-001 + FOLFOX", "patients": 90},
        {"name": "ARM_B", "intervention": "FOLFOX alone", "patients": 90}
    ],
    "primary_endpoints": ["Objective Response Rate", "Duration of Response"],
    "biomarkers": ["TP53 mutation type", "MSI status", "TMB"]
}')
WHERE NOT EXISTS (SELECT 1 FROM LIFEARC_POC.UNSTRUCTURED_DATA.CLINICAL_TRIALS WHERE trial_id = 'LA-2023-002');

-- Compound Library
INSERT INTO LIFEARC_POC.UNSTRUCTURED_DATA.COMPOUND_LIBRARY (compound_id, molecule_name, smiles, properties)
SELECT 'LA-001', 'Aspirin', 'CC(=O)OC1=CC=CC=C1C(=O)O',
    PARSE_JSON('{"logP": 1.19, "tpsa": 63.6, "rotatable_bonds": 3, "num_h_donors": 1, "num_h_acceptors": 4, "lipinski_violations": 0}')
WHERE NOT EXISTS (SELECT 1 FROM LIFEARC_POC.UNSTRUCTURED_DATA.COMPOUND_LIBRARY WHERE compound_id = 'LA-001');

INSERT INTO LIFEARC_POC.UNSTRUCTURED_DATA.COMPOUND_LIBRARY (compound_id, molecule_name, smiles, properties)
SELECT 'LA-002', 'Ibuprofen', 'CC(C)CC1=CC=C(C=C1)C(C)C(=O)O',
    PARSE_JSON('{"logP": 3.97, "tpsa": 37.3, "rotatable_bonds": 4, "num_h_donors": 1, "num_h_acceptors": 2, "lipinski_violations": 0}')
WHERE NOT EXISTS (SELECT 1 FROM LIFEARC_POC.UNSTRUCTURED_DATA.COMPOUND_LIBRARY WHERE compound_id = 'LA-002');

INSERT INTO LIFEARC_POC.UNSTRUCTURED_DATA.COMPOUND_LIBRARY (compound_id, molecule_name, smiles, properties)
SELECT 'LA-003', 'Paracetamol', 'CC(=O)NC1=CC=C(C=C1)O',
    PARSE_JSON('{"logP": 0.46, "tpsa": 49.33, "rotatable_bonds": 1, "num_h_donors": 2, "num_h_acceptors": 2, "lipinski_violations": 0}')
WHERE NOT EXISTS (SELECT 1 FROM LIFEARC_POC.UNSTRUCTURED_DATA.COMPOUND_LIBRARY WHERE compound_id = 'LA-003');

-- Additional Targeted Therapy Compounds (32 more)
MERGE INTO LIFEARC_POC.UNSTRUCTURED_DATA.COMPOUND_LIBRARY tgt
USING (
    SELECT 'LA-KRAS-001' AS cid, 'Sotorasib' AS name, 'C30H30FN5O3' AS smiles, PARSE_JSON('{"logP": 3.2, "tpsa": 78.4, "rotatable_bonds": 5, "num_h_donors": 2, "num_h_acceptors": 6, "lipinski_violations": 0, "target": "KRAS G12C"}') AS props
    UNION ALL SELECT 'LA-DDR-001', 'Olaparib', 'C24H23FN4O3', PARSE_JSON('{"logP": 1.7, "tpsa": 86.4, "rotatable_bonds": 6, "num_h_donors": 1, "num_h_acceptors": 7, "lipinski_violations": 0, "target": "PARP1/2"}')
    UNION ALL SELECT 'LA-EGFR-001', 'Osimertinib', 'C28H33N7O2', PARSE_JSON('{"logP": 3.8, "tpsa": 87.5, "rotatable_bonds": 7, "num_h_donors": 2, "num_h_acceptors": 8, "lipinski_violations": 0, "target": "EGFR T790M"}')
    UNION ALL SELECT 'LA-MYC-001', 'Omomyc', 'C25H28N6O2', PARSE_JSON('{"logP": 2.1, "tpsa": 92.3, "rotatable_bonds": 4, "num_h_donors": 3, "num_h_acceptors": 6, "lipinski_violations": 0, "target": "MYC"}')
    UNION ALL SELECT 'LA-TP53-001', 'APR-246', 'C8H11NO2', PARSE_JSON('{"logP": 0.8, "tpsa": 35.5, "rotatable_bonds": 2, "num_h_donors": 1, "num_h_acceptors": 3, "lipinski_violations": 0, "target": "p53 reactivator"}')
    UNION ALL SELECT 'LA-004', 'Erlotinib', 'C22H23N3O4', PARSE_JSON('{"logP": 2.7, "tpsa": 74.7, "rotatable_bonds": 10, "num_h_donors": 1, "num_h_acceptors": 6, "lipinski_violations": 0}')
    UNION ALL SELECT 'LA-005', 'Gefitinib', 'C22H24ClFN4O3', PARSE_JSON('{"logP": 3.3, "tpsa": 68.7, "rotatable_bonds": 8, "num_h_donors": 1, "num_h_acceptors": 7, "lipinski_violations": 0}')
    UNION ALL SELECT 'LA-006', 'Lapatinib', 'C29H26ClFN4O4S', PARSE_JSON('{"logP": 5.4, "tpsa": 114.7, "rotatable_bonds": 11, "num_h_donors": 2, "num_h_acceptors": 8, "lipinski_violations": 1}')
    UNION ALL SELECT 'LA-007', 'Vemurafenib', 'C23H18ClF2N3O3S', PARSE_JSON('{"logP": 4.7, "tpsa": 100.3, "rotatable_bonds": 5, "num_h_donors": 2, "num_h_acceptors": 5, "lipinski_violations": 0}')
    UNION ALL SELECT 'LA-008', 'Dabrafenib', 'C23H20F3N5O2S2', PARSE_JSON('{"logP": 4.1, "tpsa": 128.5, "rotatable_bonds": 6, "num_h_donors": 2, "num_h_acceptors": 7, "lipinski_violations": 0}')
    UNION ALL SELECT 'LA-009', 'Trametinib', 'C26H23FIN5O4', PARSE_JSON('{"logP": 2.9, "tpsa": 101.8, "rotatable_bonds": 4, "num_h_donors": 2, "num_h_acceptors": 7, "lipinski_violations": 0}')
    UNION ALL SELECT 'LA-010', 'Cobimetinib', 'C21H21F3IN3O2', PARSE_JSON('{"logP": 3.5, "tpsa": 64.5, "rotatable_bonds": 5, "num_h_donors": 2, "num_h_acceptors": 4, "lipinski_violations": 0}')
    UNION ALL SELECT 'LA-011', 'Crizotinib', 'C21H22Cl2FN5O', PARSE_JSON('{"logP": 3.7, "tpsa": 77.3, "rotatable_bonds": 5, "num_h_donors": 2, "num_h_acceptors": 5, "lipinski_violations": 0}')
    UNION ALL SELECT 'LA-012', 'Alectinib', 'C30H34N4O2', PARSE_JSON('{"logP": 5.2, "tpsa": 71.8, "rotatable_bonds": 5, "num_h_donors": 1, "num_h_acceptors": 5, "lipinski_violations": 1}')
    UNION ALL SELECT 'LA-013', 'Brigatinib', 'C29H39ClN7O2P', PARSE_JSON('{"logP": 4.8, "tpsa": 92.3, "rotatable_bonds": 8, "num_h_donors": 2, "num_h_acceptors": 8, "lipinski_violations": 0}')
    UNION ALL SELECT 'LA-014', 'Lorlatinib', 'C21H19FN6O2', PARSE_JSON('{"logP": 2.3, "tpsa": 72.4, "rotatable_bonds": 1, "num_h_donors": 2, "num_h_acceptors": 7, "lipinski_violations": 0}')
    UNION ALL SELECT 'LA-015', 'Entrectinib', 'C31H34F2N6O2', PARSE_JSON('{"logP": 5.1, "tpsa": 82.4, "rotatable_bonds": 7, "num_h_donors": 2, "num_h_acceptors": 7, "lipinski_violations": 1}')
    UNION ALL SELECT 'LA-016', 'Larotrectinib', 'C21H22F2N6O2', PARSE_JSON('{"logP": 2.5, "tpsa": 95.2, "rotatable_bonds": 4, "num_h_donors": 2, "num_h_acceptors": 7, "lipinski_violations": 0}')
    UNION ALL SELECT 'LA-017', 'Selumetinib', 'C17H15BrClFN4O3', PARSE_JSON('{"logP": 2.8, "tpsa": 98.7, "rotatable_bonds": 4, "num_h_donors": 3, "num_h_acceptors": 5, "lipinski_violations": 0}')
    UNION ALL SELECT 'LA-018', 'Binimetinib', 'C17H15BrF2N4O3', PARSE_JSON('{"logP": 2.4, "tpsa": 107.3, "rotatable_bonds": 5, "num_h_donors": 2, "num_h_acceptors": 6, "lipinski_violations": 0}')
    UNION ALL SELECT 'LA-019', 'Palbociclib', 'C24H29N7O2', PARSE_JSON('{"logP": 2.7, "tpsa": 103.2, "rotatable_bonds": 3, "num_h_donors": 2, "num_h_acceptors": 8, "lipinski_violations": 0}')
    UNION ALL SELECT 'LA-020', 'Ribociclib', 'C23H30N8O', PARSE_JSON('{"logP": 2.3, "tpsa": 95.7, "rotatable_bonds": 4, "num_h_donors": 2, "num_h_acceptors": 8, "lipinski_violations": 0}')
    UNION ALL SELECT 'LA-021', 'Abemaciclib', 'C27H32F2N8', PARSE_JSON('{"logP": 4.2, "tpsa": 75.3, "rotatable_bonds": 6, "num_h_donors": 1, "num_h_acceptors": 8, "lipinski_violations": 0}')
    UNION ALL SELECT 'LA-022', 'Alpelisib', 'C19H22F3N5O2S', PARSE_JSON('{"logP": 2.1, "tpsa": 118.9, "rotatable_bonds": 4, "num_h_donors": 3, "num_h_acceptors": 7, "lipinski_violations": 0}')
    UNION ALL SELECT 'LA-023', 'Idelalisib', 'C22H18FN7O', PARSE_JSON('{"logP": 3.4, "tpsa": 82.4, "rotatable_bonds": 4, "num_h_donors": 1, "num_h_acceptors": 7, "lipinski_violations": 0}')
    UNION ALL SELECT 'LA-024', 'Copanlisib', 'C23H28N8O4', PARSE_JSON('{"logP": 1.8, "tpsa": 134.7, "rotatable_bonds": 5, "num_h_donors": 2, "num_h_acceptors": 10, "lipinski_violations": 0}')
    UNION ALL SELECT 'LA-025', 'Duvelisib', 'C22H17ClN6O2S', PARSE_JSON('{"logP": 4.5, "tpsa": 116.5, "rotatable_bonds": 5, "num_h_donors": 2, "num_h_acceptors": 7, "lipinski_violations": 0}')
    UNION ALL SELECT 'LA-026', 'Everolimus', 'C53H83NO14', PARSE_JSON('{"logP": 5.9, "tpsa": 204.7, "rotatable_bonds": 10, "num_h_donors": 3, "num_h_acceptors": 14, "lipinski_violations": 3}')
    UNION ALL SELECT 'LA-027', 'Temsirolimus', 'C56H87NO16', PARSE_JSON('{"logP": 4.8, "tpsa": 231.5, "rotatable_bonds": 12, "num_h_donors": 3, "num_h_acceptors": 16, "lipinski_violations": 3}')
    UNION ALL SELECT 'LA-028', 'Niraparib', 'C19H20N4O', PARSE_JSON('{"logP": 2.8, "tpsa": 58.1, "rotatable_bonds": 3, "num_h_donors": 2, "num_h_acceptors": 4, "lipinski_violations": 0}')
    UNION ALL SELECT 'LA-029', 'Rucaparib', 'C19H18FN3O', PARSE_JSON('{"logP": 3.1, "tpsa": 52.3, "rotatable_bonds": 3, "num_h_donors": 2, "num_h_acceptors": 4, "lipinski_violations": 0}')
    UNION ALL SELECT 'LA-030', 'Talazoparib', 'C19H14F2N6O', PARSE_JSON('{"logP": 1.5, "tpsa": 90.2, "rotatable_bonds": 2, "num_h_donors": 2, "num_h_acceptors": 7, "lipinski_violations": 0}')
) src
ON tgt.compound_id = src.cid
WHEN NOT MATCHED THEN INSERT (compound_id, molecule_name, smiles, properties)
VALUES (src.cid, src.name, src.smiles, src.props);

-- =============================================================================
-- EXPANDED CLINICAL TRIAL RESULTS (10,000+ records)
-- =============================================================================
-- Generate 10,000 clinical trial results across 5 trials with realistic distribution
-- Trial Distribution:
--   LA-2024-001: ~2,000 patients (KRAS G12C NSCLC Phase II)
--   LA-2024-002: ~3,000 patients (BRCA1 DDR Breast Cancer Phase III)
--   LA-2024-003: ~500 patients (EGFR Dose Escalation Phase I)
--   LA-2023-001: ~2,000 patients (MYC Inhibitor Basket Phase II)
--   LA-2023-002: ~2,500 patients (TP53 Colorectal Phase II)

INSERT INTO LIFEARC_POC.DATA_SHARING.CLINICAL_TRIAL_RESULTS 
    (result_id, trial_id, patient_id, site_id, cohort, treatment_arm, 
     response_category, pfs_months, os_months, adverse_events, 
     biomarker_status, patient_age, patient_sex)
WITH 
-- Generate sequence numbers (10,000 rows)
seq AS (
    SELECT ROW_NUMBER() OVER (ORDER BY SEQ4()) AS n
    FROM TABLE(GENERATOR(ROWCOUNT => 10000))
),
-- Trial assignments with realistic distribution
trial_assign AS (
    SELECT 
        n,
        CASE 
            WHEN n <= 2000 THEN 'LA-2024-001'
            WHEN n <= 5000 THEN 'LA-2024-002'
            WHEN n <= 5500 THEN 'LA-2024-003'
            WHEN n <= 7500 THEN 'LA-2023-001'
            ELSE 'LA-2023-002'
        END AS trial_id
    FROM seq
)
SELECT 
    'R' || LPAD(t.n::VARCHAR, 5, '0') AS result_id,
    t.trial_id,
    'PAT-' || (10000 + t.n)::VARCHAR AS patient_id,
    -- Distribute across 14 global sites
    CASE MOD(t.n, 14)
        WHEN 0 THEN 'SITE-UK-001' WHEN 1 THEN 'SITE-UK-002'
        WHEN 2 THEN 'SITE-UK-003' WHEN 3 THEN 'SITE-UK-004'
        WHEN 4 THEN 'SITE-DE-001' WHEN 5 THEN 'SITE-DE-002'
        WHEN 6 THEN 'SITE-FR-001' WHEN 7 THEN 'SITE-FR-002'
        WHEN 8 THEN 'SITE-US-001' WHEN 9 THEN 'SITE-US-002'
        WHEN 10 THEN 'SITE-US-003' WHEN 11 THEN 'SITE-JP-001'
        WHEN 12 THEN 'SITE-AU-001' ELSE 'SITE-CA-001'
    END AS site_id,
    'Cohort_' || CHR(65 + MOD(t.n, 3)) AS cohort,
    -- Treatment arms vary by trial design
    CASE t.trial_id
        WHEN 'LA-2024-001' THEN CASE MOD(t.n, 2) WHEN 0 THEN 'ARM_A' ELSE 'ARM_B' END
        WHEN 'LA-2024-002' THEN CASE MOD(t.n, 3) WHEN 0 THEN 'ARM_A' WHEN 1 THEN 'ARM_B' ELSE 'ARM_C' END
        WHEN 'LA-2024-003' THEN CASE MOD(t.n, 4) WHEN 0 THEN 'DOSE_1' WHEN 1 THEN 'DOSE_2' WHEN 2 THEN 'DOSE_3' ELSE 'DOSE_4' END
        WHEN 'LA-2023-001' THEN 'ARM_A'
        ELSE CASE MOD(t.n, 2) WHEN 0 THEN 'ARM_A' ELSE 'ARM_B' END
    END AS treatment_arm,
    -- Response: ~12% CR, 28% PR, 35% SD, 25% PD (realistic for targeted therapies)
    CASE MOD(ABS(HASH(t.n)), 100)
        WHEN 0 THEN 'Complete_Response' WHEN 1 THEN 'Complete_Response' WHEN 2 THEN 'Complete_Response'
        WHEN 3 THEN 'Complete_Response' WHEN 4 THEN 'Complete_Response' WHEN 5 THEN 'Complete_Response'
        WHEN 6 THEN 'Complete_Response' WHEN 7 THEN 'Complete_Response' WHEN 8 THEN 'Complete_Response'
        WHEN 9 THEN 'Complete_Response' WHEN 10 THEN 'Complete_Response' WHEN 11 THEN 'Complete_Response'
        WHEN 12 THEN 'Partial_Response' WHEN 13 THEN 'Partial_Response' WHEN 14 THEN 'Partial_Response'
        WHEN 15 THEN 'Partial_Response' WHEN 16 THEN 'Partial_Response' WHEN 17 THEN 'Partial_Response'
        WHEN 18 THEN 'Partial_Response' WHEN 19 THEN 'Partial_Response' WHEN 20 THEN 'Partial_Response'
        WHEN 21 THEN 'Partial_Response' WHEN 22 THEN 'Partial_Response' WHEN 23 THEN 'Partial_Response'
        WHEN 24 THEN 'Partial_Response' WHEN 25 THEN 'Partial_Response' WHEN 26 THEN 'Partial_Response'
        WHEN 27 THEN 'Partial_Response' WHEN 28 THEN 'Partial_Response' WHEN 29 THEN 'Partial_Response'
        WHEN 30 THEN 'Partial_Response' WHEN 31 THEN 'Partial_Response' WHEN 32 THEN 'Partial_Response'
        WHEN 33 THEN 'Partial_Response' WHEN 34 THEN 'Partial_Response' WHEN 35 THEN 'Partial_Response'
        WHEN 36 THEN 'Partial_Response' WHEN 37 THEN 'Partial_Response' WHEN 38 THEN 'Partial_Response'
        WHEN 39 THEN 'Partial_Response' WHEN 40 THEN 'Stable_Disease' WHEN 41 THEN 'Stable_Disease'
        WHEN 42 THEN 'Stable_Disease' WHEN 43 THEN 'Stable_Disease' WHEN 44 THEN 'Stable_Disease'
        WHEN 45 THEN 'Stable_Disease' WHEN 46 THEN 'Stable_Disease' WHEN 47 THEN 'Stable_Disease'
        WHEN 48 THEN 'Stable_Disease' WHEN 49 THEN 'Stable_Disease' WHEN 50 THEN 'Stable_Disease'
        WHEN 51 THEN 'Stable_Disease' WHEN 52 THEN 'Stable_Disease' WHEN 53 THEN 'Stable_Disease'
        WHEN 54 THEN 'Stable_Disease' WHEN 55 THEN 'Stable_Disease' WHEN 56 THEN 'Stable_Disease'
        WHEN 57 THEN 'Stable_Disease' WHEN 58 THEN 'Stable_Disease' WHEN 59 THEN 'Stable_Disease'
        WHEN 60 THEN 'Stable_Disease' WHEN 61 THEN 'Stable_Disease' WHEN 62 THEN 'Stable_Disease'
        WHEN 63 THEN 'Stable_Disease' WHEN 64 THEN 'Stable_Disease' WHEN 65 THEN 'Stable_Disease'
        WHEN 66 THEN 'Stable_Disease' WHEN 67 THEN 'Stable_Disease' WHEN 68 THEN 'Stable_Disease'
        WHEN 69 THEN 'Stable_Disease' WHEN 70 THEN 'Stable_Disease' WHEN 71 THEN 'Stable_Disease'
        WHEN 72 THEN 'Stable_Disease' WHEN 73 THEN 'Stable_Disease' WHEN 74 THEN 'Stable_Disease'
        ELSE 'Progressive_Disease'
    END AS response_category,
    -- PFS: 1.5-18 months
    ROUND(1.5 + (MOD(ABS(HASH(t.n * 7)), 165) / 10.0), 1) AS pfs_months,
    -- OS: 3-36 months
    ROUND(3.0 + (MOD(ABS(HASH(t.n * 13)), 330) / 10.0), 1) AS os_months,
    -- Adverse events with realistic distribution
    CASE MOD(ABS(HASH(t.n * 17)), 100)
        WHEN 0 THEN 'None' WHEN 1 THEN 'None' WHEN 2 THEN 'None' WHEN 3 THEN 'None' WHEN 4 THEN 'None'
        WHEN 5 THEN 'None' WHEN 6 THEN 'None' WHEN 7 THEN 'None' WHEN 8 THEN 'None' WHEN 9 THEN 'None'
        WHEN 10 THEN 'None' WHEN 11 THEN 'None' WHEN 12 THEN 'None' WHEN 13 THEN 'None' WHEN 14 THEN 'None'
        WHEN 15 THEN 'None' WHEN 16 THEN 'None' WHEN 17 THEN 'None' WHEN 18 THEN 'None' WHEN 19 THEN 'None'
        WHEN 20 THEN 'None' WHEN 21 THEN 'None' WHEN 22 THEN 'None' WHEN 23 THEN 'None' WHEN 24 THEN 'None'
        WHEN 25 THEN 'Grade1_Fatigue' WHEN 26 THEN 'Grade1_Fatigue' WHEN 27 THEN 'Grade1_Fatigue'
        WHEN 28 THEN 'Grade1_Fatigue' WHEN 29 THEN 'Grade1_Fatigue' WHEN 30 THEN 'Grade1_Fatigue'
        WHEN 31 THEN 'Grade1_Fatigue' WHEN 32 THEN 'Grade1_Fatigue' WHEN 33 THEN 'Grade1_Fatigue'
        WHEN 34 THEN 'Grade1_Fatigue' WHEN 35 THEN 'Grade1_Fatigue' WHEN 36 THEN 'Grade1_Fatigue'
        WHEN 37 THEN 'Grade1_Fatigue' WHEN 38 THEN 'Grade1_Fatigue' WHEN 39 THEN 'Grade1_Fatigue'
        WHEN 40 THEN 'Grade1_Fatigue' WHEN 41 THEN 'Grade1_Fatigue' WHEN 42 THEN 'Grade1_Fatigue'
        WHEN 43 THEN 'Grade1_Fatigue' WHEN 44 THEN 'Grade1_Fatigue'
        WHEN 45 THEN 'Grade1_Nausea' WHEN 46 THEN 'Grade1_Nausea' WHEN 47 THEN 'Grade1_Nausea'
        WHEN 48 THEN 'Grade1_Nausea' WHEN 49 THEN 'Grade1_Nausea' WHEN 50 THEN 'Grade1_Nausea'
        WHEN 51 THEN 'Grade1_Nausea' WHEN 52 THEN 'Grade1_Nausea' WHEN 53 THEN 'Grade1_Nausea'
        WHEN 54 THEN 'Grade1_Nausea' WHEN 55 THEN 'Grade1_Nausea' WHEN 56 THEN 'Grade1_Nausea'
        WHEN 57 THEN 'Grade1_Nausea' WHEN 58 THEN 'Grade1_Nausea' WHEN 59 THEN 'Grade1_Nausea'
        WHEN 60 THEN 'Grade2_Fatigue' WHEN 61 THEN 'Grade2_Fatigue' WHEN 62 THEN 'Grade2_Fatigue'
        WHEN 63 THEN 'Grade2_Fatigue' WHEN 64 THEN 'Grade2_Fatigue' WHEN 65 THEN 'Grade2_Fatigue'
        WHEN 66 THEN 'Grade2_Fatigue' WHEN 67 THEN 'Grade2_Fatigue' WHEN 68 THEN 'Grade2_Fatigue'
        WHEN 69 THEN 'Grade2_Fatigue' WHEN 70 THEN 'Grade2_Fatigue' WHEN 71 THEN 'Grade2_Fatigue'
        WHEN 72 THEN 'Grade2_Rash' WHEN 73 THEN 'Grade2_Rash' WHEN 74 THEN 'Grade2_Rash'
        WHEN 75 THEN 'Grade2_Rash' WHEN 76 THEN 'Grade2_Rash' WHEN 77 THEN 'Grade2_Rash'
        WHEN 78 THEN 'Grade2_Rash' WHEN 79 THEN 'Grade2_Rash' WHEN 80 THEN 'Grade2_Rash'
        WHEN 81 THEN 'Grade2_Rash' WHEN 82 THEN 'Grade2_Diarrhea' WHEN 83 THEN 'Grade2_Diarrhea'
        WHEN 84 THEN 'Grade2_Diarrhea' WHEN 85 THEN 'Grade2_Diarrhea' WHEN 86 THEN 'Grade2_Diarrhea'
        WHEN 87 THEN 'Grade2_Diarrhea' WHEN 88 THEN 'Grade2_Diarrhea' WHEN 89 THEN 'Grade2_Diarrhea'
        WHEN 90 THEN 'Grade3_Hepatotoxicity' WHEN 91 THEN 'Grade3_Hepatotoxicity'
        WHEN 92 THEN 'Grade3_Hepatotoxicity' WHEN 93 THEN 'Grade3_Hepatotoxicity'
        WHEN 94 THEN 'Grade3_Hepatotoxicity' WHEN 95 THEN 'Grade3_Neutropenia'
        WHEN 96 THEN 'Grade3_Neutropenia' WHEN 97 THEN 'Grade3_Neutropenia'
        ELSE 'Grade4_Thrombocytopenia'
    END AS adverse_events,
    -- Biomarker matches trial target
    CASE t.trial_id
        WHEN 'LA-2024-001' THEN 'KRAS_G12C_POS'
        WHEN 'LA-2024-002' THEN 'BRCA1_MUT'
        WHEN 'LA-2024-003' THEN 'EGFR_MUT'
        WHEN 'LA-2023-001' THEN 'MYC_AMP'
        ELSE 'TP53_MUT'
    END AS biomarker_status,
    -- Age: 25-85 years
    25 + MOD(ABS(HASH(t.n * 23)), 60) AS patient_age,
    -- Sex: ~50/50
    CASE MOD(t.n, 2) WHEN 0 THEN 'F' ELSE 'M' END AS patient_sex
FROM trial_assign t
WHERE NOT EXISTS (
    SELECT 1 FROM LIFEARC_POC.DATA_SHARING.CLINICAL_TRIAL_RESULTS 
    WHERE result_id = 'R' || LPAD(t.n::VARCHAR, 5, '0')
);

-- Research Documents
INSERT INTO LIFEARC_POC.UNSTRUCTURED_DATA.RESEARCH_DOCUMENTS (doc_id, doc_type, title, content, keywords)
SELECT 'DOC001', 'Abstract', 'Novel BRCA1 DDR Inhibitors',
    'This study investigates novel DNA damage response (DDR) inhibitors targeting BRCA1-deficient tumors. We screened 10,000 compounds against BRCA1-null cell lines and identified 23 hits with IC50 < 1uM. Lead optimization yielded compound LA-DDR-001 with selective activity in BRCA1-mutant breast and ovarian cancer models. In vivo xenograft studies showed 60% tumor growth inhibition at well-tolerated doses.',
    ARRAY_CONSTRUCT('BRCA1', 'DDR', 'inhibitor', 'breast cancer', 'ovarian cancer')
WHERE NOT EXISTS (SELECT 1 FROM LIFEARC_POC.UNSTRUCTURED_DATA.RESEARCH_DOCUMENTS WHERE doc_id = 'DOC001');

INSERT INTO LIFEARC_POC.UNSTRUCTURED_DATA.RESEARCH_DOCUMENTS (doc_id, doc_type, title, content, keywords)
SELECT 'DOC002', 'Protocol', 'KRAS G12C Phase II Trial',
    'Protocol LA-2024-001: A randomized, open-label Phase II study evaluating LA-KRAS-001 in patients with KRAS G12C-mutant NSCLC. Primary endpoints: ORR and DoR. Secondary: PFS, OS, safety. Target enrollment: 120 patients across 12 sites.',
    ARRAY_CONSTRUCT('KRAS', 'G12C', 'NSCLC', 'Phase II', 'clinical trial')
WHERE NOT EXISTS (SELECT 1 FROM LIFEARC_POC.UNSTRUCTURED_DATA.RESEARCH_DOCUMENTS WHERE doc_id = 'DOC002');

INSERT INTO LIFEARC_POC.UNSTRUCTURED_DATA.RESEARCH_DOCUMENTS (doc_id, doc_type, title, content, authors, created_date, tags)
SELECT 'DOC003', 'Report', 'Compound Library Analysis 2024',
    'Annual review of LifeArc compound library. Total compounds: 45,000. New additions: 3,200. Quality metrics: 98% purity confirmed, 95% structural verification by NMR. High-throughput screening capacity: 100K compounds/week.',
    'LifeArc Chemistry Team', DATE('2024-03-01'), ARRAY_CONSTRUCT('compound library', 'screening', 'drug discovery', 'chemistry')
WHERE NOT EXISTS (SELECT 1 FROM LIFEARC_POC.UNSTRUCTURED_DATA.RESEARCH_DOCUMENTS WHERE doc_id = 'DOC003');

-- Additional Research Documents with rich scientific content
INSERT INTO LIFEARC_POC.UNSTRUCTURED_DATA.RESEARCH_DOCUMENTS 
    (doc_id, doc_type, title, content, authors, created_date, tags)
SELECT 'DOC004', 'Publication', 'KRAS G12C Inhibitors: From Bench to Bedside',
    'The development of covalent inhibitors targeting KRAS G12C represents a major breakthrough in oncology. For decades, KRAS was considered "undruggable" due to its smooth surface lacking traditional binding pockets. The discovery that the G12C mutant contains a reactive cysteine opened new therapeutic possibilities. Sotorasib (AMG 510) became the first FDA-approved KRAS G12C inhibitor in 2021, demonstrating a 37.1% objective response rate in the CodeBreaK 100 trial. Subsequent agents including adagrasib have shown similar efficacy with different pharmacokinetic profiles. Key challenges remain, including acquired resistance through secondary KRAS mutations (Y96D, R68S) and activation of bypass pathways (MET amplification, EGFR activation). Combination strategies targeting these resistance mechanisms are under active investigation.',
    'Dr. Sarah Chen, Dr. Michael Roberts', DATE('2024-06-15'), ARRAY_CONSTRUCT('KRAS', 'G12C', 'inhibitor', 'resistance', 'targeted_therapy')
WHERE NOT EXISTS (SELECT 1 FROM LIFEARC_POC.UNSTRUCTURED_DATA.RESEARCH_DOCUMENTS WHERE doc_id = 'DOC004');

INSERT INTO LIFEARC_POC.UNSTRUCTURED_DATA.RESEARCH_DOCUMENTS 
    (doc_id, doc_type, title, content, authors, created_date, tags)
SELECT 'DOC005', 'Review', 'PARP Inhibitors in BRCA-Mutant Cancers: A Comprehensive Review',
    'Poly(ADP-ribose) polymerase (PARP) inhibitors represent a paradigm shift in treating BRCA-mutant cancers through synthetic lethality. In cells with BRCA1/2 mutations, DNA double-strand break repair via homologous recombination is defective. PARP inhibition blocks single-strand break repair, forcing cells to rely on error-prone pathways leading to genomic instability and cell death. Four PARP inhibitors (olaparib, rucaparib, niraparib, talazoparib) are now approved for various indications including BRCA-mutant ovarian, breast, prostate, and pancreatic cancers. The SOLO-1 trial demonstrated remarkable benefit with olaparib maintenance in BRCA-mutant ovarian cancer (HR 0.30 for disease progression).',
    'Dr. Emma Williams, Dr. David Park', DATE('2024-05-22'), ARRAY_CONSTRUCT('PARP', 'BRCA', 'synthetic_lethality', 'olaparib', 'HR_deficiency')
WHERE NOT EXISTS (SELECT 1 FROM LIFEARC_POC.UNSTRUCTURED_DATA.RESEARCH_DOCUMENTS WHERE doc_id = 'DOC005');

INSERT INTO LIFEARC_POC.UNSTRUCTURED_DATA.RESEARCH_DOCUMENTS 
    (doc_id, doc_type, title, content, authors, created_date, tags)
SELECT 'DOC006', 'Clinical Protocol', 'LA-2024-002: Phase III BRCA1 DDR Inhibitor Study Protocol',
    'PROTOCOL SYNOPSIS: A Randomized, Double-Blind, Placebo-Controlled Phase III Study of LA-DDR-001 in Patients with BRCA1-Mutant Metastatic Breast Cancer. PRIMARY OBJECTIVE: To compare progression-free survival (PFS) between LA-DDR-001 and placebo arms. STUDY DESIGN: Multi-center, international, randomized 2:1 active to placebo. TARGET ENROLLMENT: 450 patients across 28 sites in US, UK, Germany, France, and Japan. ELIGIBILITY: Age 18+, ECOG 0-1, confirmed gBRCA1 mutation, measurable disease per RECIST 1.1. TREATMENT: LA-DDR-001 200mg QD or placebo until disease progression. STRATIFICATION: Prior lines (1-2 vs 3+), visceral metastases, HR status.',
    'LifeArc Clinical Development Team', DATE('2024-01-10'), ARRAY_CONSTRUCT('protocol', 'Phase_III', 'BRCA1', 'breast_cancer', 'DDR')
WHERE NOT EXISTS (SELECT 1 FROM LIFEARC_POC.UNSTRUCTURED_DATA.RESEARCH_DOCUMENTS WHERE doc_id = 'DOC006');

INSERT INTO LIFEARC_POC.UNSTRUCTURED_DATA.RESEARCH_DOCUMENTS 
    (doc_id, doc_type, title, content, authors, created_date, tags)
SELECT 'DOC007', 'Scientific Report', 'Genomic Profiling of NSCLC: Biomarker-Driven Treatment Selection',
    'Comprehensive genomic profiling (CGP) has transformed treatment selection in non-small cell lung cancer (NSCLC). This report summarizes LifeArc biomarker testing program outcomes across 5,000 NSCLC patients. KEY FINDINGS: EGFR mutations detected in 15% (exon 19 del 52%, L858R 38%, T790M 8%), KRAS mutations in 28% (G12C most common at 13%), ALK fusions in 5%, ROS1 fusions in 2%, BRAF V600E in 2%, MET amplification in 3%. Notable findings include co-occurring mutations in 18% of cases, with TP53 being the most frequent co-mutation (65%). CLINICAL IMPLICATIONS: 45% of patients had actionable mutations with FDA-approved therapies.',
    'Dr. Lisa Zhang, Dr. James Wilson, Dr. Maria Garcia', DATE('2024-07-01'), ARRAY_CONSTRUCT('NSCLC', 'genomic_profiling', 'biomarkers', 'EGFR', 'KRAS', 'ALK')
WHERE NOT EXISTS (SELECT 1 FROM LIFEARC_POC.UNSTRUCTURED_DATA.RESEARCH_DOCUMENTS WHERE doc_id = 'DOC007');

INSERT INTO LIFEARC_POC.UNSTRUCTURED_DATA.RESEARCH_DOCUMENTS 
    (doc_id, doc_type, title, content, authors, created_date, tags)
SELECT 'DOC008', 'Safety Report', 'LA-KRAS-001 Integrated Safety Analysis: 500 Patient Update',
    'EXECUTIVE SUMMARY: This integrated safety analysis covers 500 patients treated with LA-KRAS-001 across Phase I/II studies. TREATMENT EXPOSURE: Median duration 8.2 months. COMMON ADVERSE EVENTS (≥10%): Diarrhea (42%, Grade 3: 8%), nausea (38%, Grade 3: 2%), fatigue (35%, Grade 3: 5%), AST elevation (18%, Grade 3: 4%), ALT elevation (16%, Grade 3: 3%). SERIOUS ADVERSE EVENTS: Occurred in 25% of patients. Most common: pneumonitis (3%), hepatotoxicity (2%). DOSE MODIFICATIONS: 22% required dose reduction, 15% required dose interruption. DISCONTINUATIONS: 8%. RISK MANAGEMENT: Recommend baseline and periodic LFT monitoring.',
    'LifeArc Drug Safety Team', DATE('2024-08-15'), ARRAY_CONSTRUCT('safety', 'adverse_events', 'KRAS', 'hepatotoxicity', 'pneumonitis')
WHERE NOT EXISTS (SELECT 1 FROM LIFEARC_POC.UNSTRUCTURED_DATA.RESEARCH_DOCUMENTS WHERE doc_id = 'DOC008');

INSERT INTO LIFEARC_POC.UNSTRUCTURED_DATA.RESEARCH_DOCUMENTS 
    (doc_id, doc_type, title, content, authors, created_date, tags)
SELECT 'DOC009', 'Technical Note', 'FASTA File Processing Pipeline for Clinical Genomics',
    'This technical document describes the LifeArc FASTA processing pipeline implemented in Snowflake. OVERVIEW: The PARSE_FASTA UDF enables direct analysis of genomic sequences within the Snowflake data platform. IMPLEMENTATION: Python UDTF using Snowpark with regex-based sequence parsing. CAPABILITIES: Header parsing, sequence extraction, GC content calculation, sequence length validation. PERFORMANCE: Processes 1,000 sequences in <5 seconds on XS warehouse. USE CASES: QC of incoming sequence data, filtering by GC content, sequence statistics, integration with Cortex LLM for annotation.',
    'LifeArc Bioinformatics Team', DATE('2024-04-20'), ARRAY_CONSTRUCT('FASTA', 'bioinformatics', 'pipeline', 'Snowflake', 'UDF')
WHERE NOT EXISTS (SELECT 1 FROM LIFEARC_POC.UNSTRUCTURED_DATA.RESEARCH_DOCUMENTS WHERE doc_id = 'DOC009');

INSERT INTO LIFEARC_POC.UNSTRUCTURED_DATA.RESEARCH_DOCUMENTS 
    (doc_id, doc_type, title, content, authors, created_date, tags)
SELECT 'DOC010', 'Data Governance', 'LifeArc Clinical Data Governance Framework',
    'PURPOSE: This document establishes the data governance framework for LifeArc clinical trial data. DATA CLASSIFICATION: Level 1 (Public) - Aggregated trial statistics, Level 2 (Internal) - Protocol documents, compound properties, Level 3 (Confidential) - De-identified patient data, Level 4 (Highly Confidential) - Patient identifiers, genomic data. ACCESS CONTROLS: Role-based access with separation of duties. MASKING POLICIES: Patient IDs masked for non-admin roles, ages rounded to decades for partner sharing. ROW-LEVEL SECURITY: Site-based filtering. AUDIT LOGGING: All queries logged. COMPLIANCE: ICH E6(R2), 21 CFR Part 11, GDPR Article 89.',
    'LifeArc Data Governance Office', DATE('2024-02-28'), ARRAY_CONSTRUCT('governance', 'compliance', 'security', 'GDPR', 'audit')
WHERE NOT EXISTS (SELECT 1 FROM LIFEARC_POC.UNSTRUCTURED_DATA.RESEARCH_DOCUMENTS WHERE doc_id = 'DOC010');

-- =============================================================================
-- SECTION 10B: AUDIT & API LOG DATA (Demo meaningful governance/security signal)
-- =============================================================================

-- Data Access Audit Log (shows governance in action)
INSERT INTO LIFEARC_POC.GOVERNANCE.DATA_ACCESS_AUDIT_LOG 
    (query_id, user_name, role_name, query_text, tables_accessed, query_start_time, execution_status, rows_returned)
SELECT '01b8c3a2-1234-4567-8901-abcdef123456', 'SARAH.JONES@LIFEARC.ORG', 'CLINICAL_ANALYST', 
       'SELECT * FROM CLINICAL_TRIAL_RESULTS WHERE trial_id = ''LA-2024-001''', 
       ARRAY_CONSTRUCT('CLINICAL_TRIAL_RESULTS'), DATEADD(hour, -2, CURRENT_TIMESTAMP()), 'SUCCESS', 2008
UNION ALL SELECT '01b8c3a2-2345-4567-8901-abcdef123457', 'SARAH.JONES@LIFEARC.ORG', 'CLINICAL_ANALYST',
       'SELECT trial_id, COUNT(*) AS patients FROM CLINICAL_TRIAL_RESULTS GROUP BY trial_id',
       ARRAY_CONSTRUCT('CLINICAL_TRIAL_RESULTS'), DATEADD(hour, -1, CURRENT_TIMESTAMP()), 'SUCCESS', 5
UNION ALL SELECT '01b8c3a2-3456-4567-8901-abcdef123458', 'JOHN.SMITH@LIFEARC.ORG', 'CLINICAL_DATA_ADMIN',
       'SELECT patient_id, patient_age, response_category FROM CLINICAL_TRIAL_RESULTS LIMIT 100',
       ARRAY_CONSTRUCT('CLINICAL_TRIAL_RESULTS'), DATEADD(minute, -45, CURRENT_TIMESTAMP()), 'SUCCESS', 100
UNION ALL SELECT '01b8c3a2-4567-4567-8901-abcdef123459', 'LIFEARC_ML_SERVICE', 'LIFEARC_ML_PIPELINE_ROLE',
       'CALL GET_INFERENCE_BATCH(''LA-2024-001'', 100)',
       ARRAY_CONSTRUCT('CLINICAL_TRIAL_RESULTS'), DATEADD(minute, -30, CURRENT_TIMESTAMP()), 'SUCCESS', 100
UNION ALL SELECT '01b8c3a2-5678-4567-8901-abcdef123460', 'LIFEARC_ML_SERVICE', 'LIFEARC_ML_PIPELINE_ROLE',
       'CALL GET_INFERENCE_BATCH(''LA-2024-002'', 200)',
       ARRAY_CONSTRUCT('CLINICAL_TRIAL_RESULTS'), DATEADD(minute, -25, CURRENT_TIMESTAMP()), 'SUCCESS', 200
UNION ALL SELECT '01b8c3a2-6789-4567-8901-abcdef123461', 'MARIA.GARCIA@LIFEARC.ORG', 'GENOMICS_ANALYST',
       'SELECT * FROM GENE_SEQUENCES WHERE gene_name IN (''BRCA1'', ''TP53'', ''KRAS'')',
       ARRAY_CONSTRUCT('GENE_SEQUENCES'), DATEADD(hour, -3, CURRENT_TIMESTAMP()), 'SUCCESS', 3
UNION ALL SELECT '01b8c3a2-7890-4567-8901-abcdef123462', 'MARIA.GARCIA@LIFEARC.ORG', 'GENOMICS_ANALYST',
       'SELECT * FROM TABLE(PARSE_FASTA(''>BRCA1\nATGC...''))',
       ARRAY_CONSTRUCT('GENE_SEQUENCES'), DATEADD(hour, -2, CURRENT_TIMESTAMP()), 'SUCCESS', 1
UNION ALL SELECT '01b8c3a2-8901-4567-8901-abcdef123463', 'CHEN.WEI@LIFEARC.ORG', 'COMPOUND_CHEMIST',
       'SELECT * FROM COMPOUND_LIBRARY WHERE properties:lipinski_violations = 0',
       ARRAY_CONSTRUCT('COMPOUND_LIBRARY'), DATEADD(minute, -90, CURRENT_TIMESTAMP()), 'SUCCESS', 28
UNION ALL SELECT '01b8c3a2-0123-4567-8901-abcdef123465', 'EXTERNAL_PARTNER@PHARMA.COM', 'PARTNER_READ_ONLY',
       'SELECT patient_id FROM CLINICAL_TRIAL_RESULTS',
       ARRAY_CONSTRUCT('CLINICAL_TRIAL_RESULTS'), DATEADD(minute, -15, CURRENT_TIMESTAMP()), 'FAILED_ACCESS_DENIED', 0
UNION ALL SELECT '01b8c3a2-1234-4567-8901-abcdef123466', 'EXTERNAL_PARTNER@PHARMA.COM', 'PARTNER_READ_ONLY',
       'SELECT * FROM CLINICAL_RESULTS_PARTNER_VIEW WHERE trial_id = ''LA-2024-001''',
       ARRAY_CONSTRUCT('CLINICAL_RESULTS_PARTNER_VIEW'), DATEADD(minute, -10, CURRENT_TIMESTAMP()), 'SUCCESS', 2008
UNION ALL SELECT '01b8c3a2-2345-4567-8901-abcdef123467', 'ADMIN@LIFEARC.ORG', 'ACCOUNTADMIN',
       'SELECT * FROM TABLE(INFORMATION_SCHEMA.POLICY_REFERENCES(ref_entity_name => ''CLINICAL_TRIAL_RESULTS''))',
       ARRAY_CONSTRUCT('INFORMATION_SCHEMA'), DATEADD(minute, -5, CURRENT_TIMESTAMP()), 'SUCCESS', 3;

-- API Access Log (shows programmatic access patterns)
INSERT INTO LIFEARC_POC.GOVERNANCE.API_ACCESS_LOG 
    (log_id, api_key_id, endpoint, method, request_timestamp, response_status, response_time_ms, client_ip, user_agent, request_payload_size, response_payload_size)
SELECT 'API-LOG-001', 'KEY-001', '/api/v1/trials', 'GET', DATEADD(hour, -1, CURRENT_TIMESTAMP()), 'SUCCESS', 45, '192.168.1.100', 'LifeArc-Dashboard/2.0', 0, 15234
UNION ALL SELECT 'API-LOG-002', 'KEY-001', '/api/v1/trials/LA-2024-001/patients', 'GET', DATEADD(hour, -2, CURRENT_TIMESTAMP()), 'SUCCESS', 128, '192.168.1.100', 'LifeArc-Dashboard/2.0', 0, 45678
UNION ALL SELECT 'API-LOG-003', 'KEY-002', '/api/v1/compounds', 'POST', DATEADD(hour, -3, CURRENT_TIMESTAMP()), 'SUCCESS', 234, '10.0.0.50', 'Python/3.10', 2048, 512
UNION ALL SELECT 'API-LOG-004', 'KEY-003', '/api/v1/sequences/upload', 'POST', DATEADD(hour, -4, CURRENT_TIMESTAMP()), 'SUCCESS', 567, '172.16.0.25', 'curl/7.68', 102400, 256
UNION ALL SELECT 'API-LOG-005', 'KEY-INVALID', '/api/v1/trials', 'GET', DATEADD(hour, -5, CURRENT_TIMESTAMP()), 'FORBIDDEN', 12, '203.0.113.50', 'Unknown', 0, 128
UNION ALL SELECT 'API-LOG-006', 'KEY-001', '/api/v1/analytics/efficacy', 'GET', DATEADD(hour, -6, CURRENT_TIMESTAMP()), 'SUCCESS', 892, '192.168.1.100', 'LifeArc-Dashboard/2.0', 256, 89432
UNION ALL SELECT 'API-LOG-007', 'KEY-002', '/api/v1/compounds/search', 'POST', DATEADD(hour, -7, CURRENT_TIMESTAMP()), 'SUCCESS', 156, '10.0.0.50', 'Python/3.10', 512, 8192
UNION ALL SELECT 'API-LOG-008', 'KEY-004', '/api/v1/documents', 'GET', DATEADD(hour, -8, CURRENT_TIMESTAMP()), 'RATE_LIMITED', 5, '198.51.100.100', 'Postman/9.0', 0, 64
UNION ALL SELECT 'API-LOG-009', 'KEY-001', '/api/v1/patients/export', 'POST', DATEADD(hour, -9, CURRENT_TIMESTAMP()), 'SUCCESS', 2345, '192.168.1.100', 'LifeArc-Dashboard/2.0', 128, 524288
UNION ALL SELECT 'API-LOG-010', 'KEY-005', '/api/v1/trials/LA-2024-002/metrics', 'GET', DATEADD(hour, -10, CURRENT_TIMESTAMP()), 'SUCCESS', 67, '10.0.1.75', 'LifeArc-Mobile/1.5', 0, 4096
UNION ALL SELECT 'API-LOG-011', 'KEY-002', '/api/v1/sequences/blast', 'POST', DATEADD(hour, -11, CURRENT_TIMESTAMP()), 'TIMEOUT', 30000, '10.0.0.50', 'Python/3.10', 8192, 0
UNION ALL SELECT 'API-LOG-012', 'KEY-001', '/api/v1/reports/safety', 'GET', DATEADD(hour, -12, CURRENT_TIMESTAMP()), 'SUCCESS', 234, '192.168.1.100', 'LifeArc-Dashboard/2.0', 0, 32768
UNION ALL SELECT 'API-LOG-013', 'KEY-003', '/api/v1/admin/config', 'PUT', DATEADD(hour, -13, CURRENT_TIMESTAMP()), 'FORBIDDEN', 8, '172.16.0.25', 'curl/7.68', 1024, 64
UNION ALL SELECT 'API-LOG-014', 'KEY-001', '/api/v1/trials/LA-2024-003/enrollment', 'GET', DATEADD(hour, -14, CURRENT_TIMESTAMP()), 'SUCCESS', 89, '192.168.1.100', 'LifeArc-Dashboard/2.0', 0, 2048
UNION ALL SELECT 'API-LOG-015', 'KEY-006', '/api/v1/partner/submit', 'POST', DATEADD(hour, -15, CURRENT_TIMESTAMP()), 'SUCCESS', 456, '203.0.113.200', 'Partner-API/1.0', 16384, 512
UNION ALL SELECT 'API-LOG-016', 'KEY-002', '/api/v1/compounds/similarity', 'POST', DATEADD(hour, -16, CURRENT_TIMESTAMP()), 'SUCCESS', 789, '10.0.0.50', 'Python/3.10', 1024, 16384
UNION ALL SELECT 'API-LOG-017', 'KEY-001', '/api/v1/dashboard/summary', 'GET', DATEADD(hour, -17, CURRENT_TIMESTAMP()), 'SUCCESS', 345, '192.168.1.100', 'LifeArc-Dashboard/2.0', 0, 65536
UNION ALL SELECT 'API-LOG-018', 'KEY-007', '/api/v1/trials', 'DELETE', DATEADD(hour, -18, CURRENT_TIMESTAMP()), 'FORBIDDEN', 6, '198.51.100.50', 'Unknown', 0, 128;

-- Partner Data Staging (shows data sharing workflow)
INSERT INTO LIFEARC_POC.DATA_SHARING.PARTNER_DATA_STAGING 
    (file_name, file_upload_time, partner_id, data_type, raw_data, validation_status, validation_errors, processed_at)
SELECT 'pharma_partner_clinical_batch_001.csv', DATEADD(day, -7, CURRENT_TIMESTAMP()), 'PHARMA_PARTNER_A', 'clinical_results',
       PARSE_JSON('{"records": [{"patient_id": "EXT-001", "response": "PR", "pfs": 8.2}, {"patient_id": "EXT-002", "response": "SD", "pfs": 5.1}], "trial_id": "LA-2024-001"}'),
       'APPROVED', NULL, DATEADD(day, -6, CURRENT_TIMESTAMP())
UNION ALL SELECT 'biotech_genomics_upload.json', DATEADD(day, -5, CURRENT_TIMESTAMP()), 'BIOTECH_PARTNER_B', 'genomic_data',
       PARSE_JSON('{"sequences": [{"gene": "BRCA2", "variant": "c.5946del", "pathogenicity": "likely_pathogenic"}], "sample_count": 45}'),
       'APPROVED', NULL, DATEADD(day, -4, CURRENT_TIMESTAMP())
UNION ALL SELECT 'cro_safety_report_2024Q1.xlsx', DATEADD(day, -3, CURRENT_TIMESTAMP()), 'CRO_PARTNER_C', 'safety_data',
       PARSE_JSON('{"adverse_events": [{"ae_type": "Grade2_Nausea", "count": 12}, {"ae_type": "Grade3_Fatigue", "count": 3}], "trial_id": "LA-2024-002"}'),
       'APPROVED', NULL, DATEADD(day, -2, CURRENT_TIMESTAMP())
UNION ALL SELECT 'academic_lab_compounds.sdf', DATEADD(day, -1, CURRENT_TIMESTAMP()), 'ACADEMIC_PARTNER_D', 'compound_structures',
       PARSE_JSON('{"compounds": [{"name": "Novel-EGFR-01", "smiles": "CC1=CC=C(C=C1)NC(=O)C2=CC=CC=C2"}], "screening_id": "SCREEN-2024-001"}'),
       'PENDING', NULL, NULL
UNION ALL SELECT 'site_enrollment_update.csv', DATEADD(hour, -12, CURRENT_TIMESTAMP()), 'CRO_PARTNER_C', 'enrollment_data',
       PARSE_JSON('{"enrollments": [{"site_id": "SITE-DE-003", "patients_enrolled": 15, "patients_screened": 22}], "trial_id": "LA-2024-003"}'),
       'PENDING', NULL, NULL
UNION ALL SELECT 'invalid_patient_data.csv', DATEADD(day, -2, CURRENT_TIMESTAMP()), 'PHARMA_PARTNER_A', 'clinical_results',
       PARSE_JSON('{"records": [{"patient": "P001", "outcome": "good"}], "trial": "unknown"}'),
       'REJECTED', PARSE_JSON('["Missing required field: patient_id", "Invalid trial_id: unknown"]'), NULL
UNION ALL SELECT 'multi_site_clinical_batch.parquet', DATEADD(day, -10, CURRENT_TIMESTAMP()), 'CRO_PARTNER_C', 'clinical_results',
       PARSE_JSON('{"summary": {"total_records": 500, "sites": ["SITE-UK-001", "SITE-DE-001", "SITE-FR-001"], "trial_id": "LA-2023-002"}}'),
       'APPROVED', NULL, DATEADD(day, -9, CURRENT_TIMESTAMP())
UNION ALL SELECT 'biomarker_analysis_results.json', DATEADD(hour, -6, CURRENT_TIMESTAMP()), 'DIAGNOSTICS_PARTNER_E', 'biomarker_data',
       PARSE_JSON('{"analyses": [{"patient_id": "PAT-11001", "biomarker": "KRAS_G12C", "result": "POSITIVE", "method": "NGS"}], "lab_id": "LAB-EU-001"}'),
       'APPROVED', NULL, DATEADD(hour, -5, CURRENT_TIMESTAMP());

-- Site Access Mapping (for row-level security demo)
INSERT INTO LIFEARC_POC.GOVERNANCE.SITE_ACCESS_MAPPING (role_name, allowed_site_id)
SELECT column1, column2
FROM (
    SELECT 'UK_CLINICAL_TEAM', 'SITE-UK-001'
    UNION ALL SELECT 'UK_CLINICAL_TEAM', 'SITE-UK-002'
    UNION ALL SELECT 'UK_CLINICAL_TEAM', 'SITE-UK-003'
    UNION ALL SELECT 'UK_CLINICAL_TEAM', 'SITE-UK-004'
    UNION ALL SELECT 'US_CLINICAL_TEAM', 'SITE-US-001'
    UNION ALL SELECT 'US_CLINICAL_TEAM', 'SITE-US-002'
    UNION ALL SELECT 'US_CLINICAL_TEAM', 'SITE-US-003'
    UNION ALL SELECT 'EU_CLINICAL_TEAM', 'SITE-DE-001'
    UNION ALL SELECT 'EU_CLINICAL_TEAM', 'SITE-DE-002'
    UNION ALL SELECT 'EU_CLINICAL_TEAM', 'SITE-FR-001'
    UNION ALL SELECT 'EU_CLINICAL_TEAM', 'SITE-FR-002'
    UNION ALL SELECT 'APAC_CLINICAL_TEAM', 'SITE-JP-001'
    UNION ALL SELECT 'APAC_CLINICAL_TEAM', 'SITE-AU-001'
    UNION ALL SELECT 'GLOBAL_CLINICAL_TEAM', 'SITE-UK-001'
    UNION ALL SELECT 'GLOBAL_CLINICAL_TEAM', 'SITE-UK-002'
    UNION ALL SELECT 'GLOBAL_CLINICAL_TEAM', 'SITE-UK-003'
    UNION ALL SELECT 'GLOBAL_CLINICAL_TEAM', 'SITE-UK-004'
    UNION ALL SELECT 'GLOBAL_CLINICAL_TEAM', 'SITE-US-001'
    UNION ALL SELECT 'GLOBAL_CLINICAL_TEAM', 'SITE-US-002'
    UNION ALL SELECT 'GLOBAL_CLINICAL_TEAM', 'SITE-US-003'
    UNION ALL SELECT 'GLOBAL_CLINICAL_TEAM', 'SITE-DE-001'
    UNION ALL SELECT 'GLOBAL_CLINICAL_TEAM', 'SITE-DE-002'
    UNION ALL SELECT 'GLOBAL_CLINICAL_TEAM', 'SITE-FR-001'
    UNION ALL SELECT 'GLOBAL_CLINICAL_TEAM', 'SITE-FR-002'
    UNION ALL SELECT 'GLOBAL_CLINICAL_TEAM', 'SITE-JP-001'
    UNION ALL SELECT 'GLOBAL_CLINICAL_TEAM', 'SITE-AU-001'
    UNION ALL SELECT 'GLOBAL_CLINICAL_TEAM', 'SITE-CA-001'
) t
WHERE NOT EXISTS (SELECT 1 FROM LIFEARC_POC.GOVERNANCE.SITE_ACCESS_MAPPING WHERE role_name = t.column1 AND allowed_site_id = t.column2);

-- =============================================================================
-- SECTION 11: VERIFICATION QUERIES
-- =============================================================================

-- Verify deployment
SELECT 'DEPLOYMENT VERIFICATION' AS section;

SELECT 'Tables' AS object_type, COUNT(*) AS count 
FROM LIFEARC_POC.INFORMATION_SCHEMA.TABLES 
WHERE TABLE_SCHEMA NOT IN ('INFORMATION_SCHEMA');

SELECT 'Views' AS object_type, COUNT(*) AS count 
FROM LIFEARC_POC.INFORMATION_SCHEMA.VIEWS 
WHERE TABLE_SCHEMA NOT IN ('INFORMATION_SCHEMA');

SELECT 'UDFs' AS object_type, COUNT(*) AS count 
FROM LIFEARC_POC.INFORMATION_SCHEMA.FUNCTIONS 
WHERE FUNCTION_SCHEMA NOT IN ('INFORMATION_SCHEMA');

SELECT 'Procedures' AS object_type, COUNT(*) AS count 
FROM LIFEARC_POC.INFORMATION_SCHEMA.PROCEDURES 
WHERE PROCEDURE_SCHEMA NOT IN ('INFORMATION_SCHEMA');

-- Verify data counts (expected counts shown)
SELECT 'Gene Sequences' AS table_name, COUNT(*) AS rows_cnt, 15 AS expected FROM LIFEARC_POC.UNSTRUCTURED_DATA.GENE_SEQUENCES
UNION ALL SELECT 'Clinical Trials', COUNT(*), 5 FROM LIFEARC_POC.UNSTRUCTURED_DATA.CLINICAL_TRIALS
UNION ALL SELECT 'Compound Library', COUNT(*), 35 FROM LIFEARC_POC.UNSTRUCTURED_DATA.COMPOUND_LIBRARY
UNION ALL SELECT 'Clinical Results', COUNT(*), 10000 FROM LIFEARC_POC.DATA_SHARING.CLINICAL_TRIAL_RESULTS
UNION ALL SELECT 'Research Documents', COUNT(*), 10 FROM LIFEARC_POC.UNSTRUCTURED_DATA.RESEARCH_DOCUMENTS
UNION ALL SELECT 'Site Access Mappings', COUNT(*), 27 FROM LIFEARC_POC.GOVERNANCE.SITE_ACCESS_MAPPING
UNION ALL SELECT 'Audit Log', COUNT(*), 12 FROM LIFEARC_POC.GOVERNANCE.DATA_ACCESS_AUDIT_LOG
UNION ALL SELECT 'API Access Log', COUNT(*), 18 FROM LIFEARC_POC.GOVERNANCE.API_ACCESS_LOG
UNION ALL SELECT 'Partner Data Staging', COUNT(*), 8 FROM LIFEARC_POC.DATA_SHARING.PARTNER_DATA_STAGING;

-- Clinical trial distribution summary
SELECT 'CLINICAL TRIAL DISTRIBUTION' AS section;

SELECT trial_id, 
    COUNT(*) AS patients,
    COUNT(DISTINCT site_id) AS sites,
    ROUND(AVG(CASE WHEN response_category LIKE '%Response' THEN 1 ELSE 0 END)*100, 1) AS orr_pct
FROM LIFEARC_POC.DATA_SHARING.CLINICAL_TRIAL_RESULTS
GROUP BY trial_id
ORDER BY trial_id;

-- Quick functional test
SELECT 'FASTA Parser Test' AS test,
    CASE WHEN COUNT(*) > 0 THEN 'PASS' ELSE 'FAIL' END AS result
FROM TABLE(LIFEARC_POC.UNSTRUCTURED_DATA.PARSE_FASTA('>TEST\nATGCATGC'));

SELECT 'LLM Test' AS test, 
    CASE WHEN LENGTH(SNOWFLAKE.CORTEX.COMPLETE('llama3.1-8b', 'Say OK')) > 0 THEN 'PASS' ELSE 'FAIL' END AS result;

/*
================================================================================
 DEPLOYMENT COMPLETE
================================================================================
 
 Next Steps:
 1. Review verification output above
 2. Run DEMO_WALKTHROUGH.md queries to validate demo flow
 3. For production: Change service user passwords
 4. For production: Update network policy with actual IP ranges
 
================================================================================
*/
