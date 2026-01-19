/*
================================================================================
LIFEARC - USE CASE 2: MLOps WORKFLOWS WITH SNOWFLAKE
================================================================================

Reference Architecture: Designing ML Pipelines aligned with Snowflake

Current State:
- GitHub repos organized as Python packages
- Mix of notebooks and reusable modules
- Varied implementation per dataset/product

Challenges:
- Hierarchical/nested data structures
- Group-level, sequence-based transformations
- Logic more naturally expressed procedurally

================================================================================
*/


-- ============================================================================
-- ARCHITECTURE DIAGRAM (ASCII)
-- ============================================================================

/*
                          MLOps WORKFLOW ARCHITECTURE WITH SNOWFLAKE
    ┌─────────────────────────────────────────────────────────────────────────────────────────┐
    │                                                                                         │
    │  ┌─────────────────────────────────────────────────────────────────────────────────┐   │
    │  │                              DATA INGESTION LAYER                                │   │
    │  │                                                                                  │   │
    │  │  Source Systems ──► Snowpipe / Azure Data Factory ──► RAW Tables (Landing)      │   │
    │  │                                                                                  │   │
    │  └─────────────────────────────────────────────────────────────────────────────────┘   │
    │                                        │                                               │
    │                                        ▼                                               │
    │  ┌─────────────────────────────────────────────────────────────────────────────────┐   │
    │  │                          FEATURE ENGINEERING LAYER                               │   │
    │  │                                                                                  │   │
    │  │  ┌──────────────────────┐  ┌──────────────────────┐  ┌──────────────────────┐  │   │
    │  │  │   SQL-Based (Best)   │  │  Snowpark Python     │  │  External Python     │  │   │
    │  │  │                      │  │                      │  │  (when needed)       │  │   │
    │  │  │  • Aggregations      │  │  • Complex UDFs      │  │                      │  │   │
    │  │  │  • Window functions  │  │  • Pandas operations │  │  • Custom libraries  │  │   │
    │  │  │  • Joins, filters    │  │  • Nested data       │  │  • GPU processing    │  │   │
    │  │  │  • Time-series       │  │  • Procedural logic  │  │  • Specialized algos │  │   │
    │  │  │                      │  │  • ML preprocessing  │  │                      │  │   │
    │  │  │  80% of transforms   │  │  15% of transforms   │  │  5% of transforms    │  │   │
    │  │  └──────────────────────┘  └──────────────────────┘  └──────────────────────┘  │   │
    │  │                                        │                                        │   │
    │  │                                        ▼                                        │   │
    │  │                            ┌──────────────────────┐                             │   │
    │  │                            │    FEATURE STORE     │                             │   │
    │  │                            │   (Snowflake Tables) │                             │   │
    │  │                            │                      │                             │   │
    │  │                            │  • Point-in-time     │                             │   │
    │  │                            │  • Versioned         │                             │   │
    │  │                            │  • Documented        │                             │   │
    │  │                            └──────────────────────┘                             │   │
    │  └─────────────────────────────────────────────────────────────────────────────────┘   │
    │                                        │                                               │
    │                                        ▼                                               │
    │  ┌─────────────────────────────────────────────────────────────────────────────────┐   │
    │  │                            MODEL TRAINING LAYER                                  │   │
    │  │                                                                                  │   │
    │  │  ┌─────────────────────────┐            ┌─────────────────────────┐             │   │
    │  │  │  SNOWFLAKE ML (Simple)  │            │  EXTERNAL (Complex)     │             │   │
    │  │  │                         │            │                         │             │   │
    │  │  │  • Classification       │            │  • Azure ML Studio      │             │   │
    │  │  │  • Regression           │    OR      │  • Deep Learning        │             │   │
    │  │  │  • Time-series forecast │  ◄────────►│  • Custom architectures │             │   │
    │  │  │  • Anomaly detection    │            │  • GPU training         │             │   │
    │  │  │                         │            │                         │             │   │
    │  │  │  Data stays in SF       │            │  Data exported via      │             │   │
    │  │  │                         │            │  Snowpark or connector  │             │   │
    │  │  └─────────────────────────┘            └─────────────────────────┘             │   │
    │  │                                        │                                        │   │
    │  └─────────────────────────────────────────────────────────────────────────────────┘   │
    │                                        │                                               │
    │                                        ▼                                               │
    │  ┌─────────────────────────────────────────────────────────────────────────────────┐   │
    │  │                         MODEL REGISTRY & DEPLOYMENT                              │   │
    │  │                                                                                  │   │
    │  │      ┌───────────────────────────────────────────────────────────────────┐      │   │
    │  │      │              SNOWFLAKE MODEL REGISTRY                             │      │   │
    │  │      │                                                                   │      │   │
    │  │      │  • Version control      • Lineage tracking    • Access control    │      │   │
    │  │      │  • Metadata storage     • Stage transitions   • Audit logging     │      │   │
    │  │      └───────────────────────────────────────────────────────────────────┘      │   │
    │  │                                        │                                        │   │
    │  │                    ┌───────────────────┼───────────────────┐                    │   │
    │  │                    ▼                   ▼                   ▼                    │   │
    │  │         ┌──────────────────┐ ┌──────────────────┐ ┌──────────────────┐         │   │
    │  │         │  Batch Inference │ │ Real-time (UDF)  │ │  External API    │         │   │
    │  │         │  (SQL/Snowpark)  │ │ (Snowflake)      │ │  (Azure ML)      │         │   │
    │  │         └──────────────────┘ └──────────────────┘ └──────────────────┘         │   │
    │  │                                                                                  │   │
    │  └─────────────────────────────────────────────────────────────────────────────────┘   │
    │                                                                                         │
    │  ┌─────────────────────────────────────────────────────────────────────────────────┐   │
    │  │                          ORCHESTRATION & MONITORING                              │   │
    │  │                                                                                  │   │
    │  │  • Snowflake Tasks (scheduled jobs)    • Model performance monitoring           │   │
    │  │  • Streams (CDC)                       • Data drift detection                   │   │
    │  │  • Azure Data Factory                  • Alert & notification                   │   │
    │  │                                                                                  │   │
    │  └─────────────────────────────────────────────────────────────────────────────────┘   │
    └─────────────────────────────────────────────────────────────────────────────────────────┘


DECISION FRAMEWORK: Where to Process?
=====================================

    ┌─────────────────────────────────────────────────────────────────────────────────────────┐
    │                                                                                         │
    │   NATIVE SNOWFLAKE SQL                    │   SNOWPARK PYTHON                          │
    │   ═══════════════════                     │   ═══════════════                          │
    │                                           │                                             │
    │   ✓ Aggregations                          │   ✓ Complex UDFs                           │
    │   ✓ Window functions                      │   ✓ Iterative algorithms                   │
    │   ✓ Joins and filters                     │   ✓ Custom ML preprocessing               │
    │   ✓ Time-series (via functions)           │   ✓ Hierarchical data traversal           │
    │   ✓ Pivoting/unpivoting                   │   ✓ Graph-like operations                 │
    │   ✓ Pattern matching                      │   ✓ External library integration          │
    │   ✓ Statistical functions                 │   ✓ Sequence-based logic                  │
    │                                           │                                             │
    │   → Runs directly on warehouse            │   → Runs on warehouse with Python runtime  │
    │   → Most performant option                │   → Good for complex logic                 │
    │   → Prefer this when possible             │   → Still keeps data in Snowflake          │
    │                                           │                                             │
    ├───────────────────────────────────────────┼─────────────────────────────────────────────┤
    │                                           │                                             │
    │   SNOWFLAKE ML FUNCTIONS                  │   EXTERNAL (Azure ML)                      │
    │   ══════════════════════                  │   ════════════════════                     │
    │                                           │                                             │
    │   ✓ Classification                        │   ✓ Deep learning                          │
    │   ✓ Regression                            │   ✓ Custom neural networks                 │
    │   ✓ Time-series forecasting               │   ✓ GPU-intensive training                 │
    │   ✓ Anomaly detection                     │   ✓ Large-scale distributed training       │
    │   ✓ Contribution analysis                 │   ✓ Specialized domain models              │
    │                                           │                                             │
    │   → Built-in, no data movement            │   → Export data from Snowflake             │
    │   → Auto-tuned hyperparameters            │   → Train in Azure ML compute              │
    │   → SQL-based interface                   │   → Register model back to Snowflake       │
    │                                           │                                             │
    └─────────────────────────────────────────────────────────────────────────────────────────┘

*/


-- ============================================================================
-- PATTERN 1: SQL-BASED FEATURE ENGINEERING
-- ============================================================================

USE DATABASE LIFEARC_POC;
CREATE SCHEMA IF NOT EXISTS ML_FEATURES;

-- Example: Clinical trial feature engineering with window functions
CREATE OR REPLACE VIEW LIFEARC_POC.ML_FEATURES.PATIENT_RESPONSE_FEATURES AS
SELECT 
    result_id,
    trial_id,
    patient_id,
    cohort,
    treatment_arm,
    biomarker_status,
    
    -- Numeric features
    pfs_months,
    os_months,
    
    -- Categorical encoding
    CASE response_category
        WHEN 'Complete_Response' THEN 4
        WHEN 'Partial_Response' THEN 3
        WHEN 'Stable_Disease' THEN 2
        WHEN 'Progressive_Disease' THEN 1
        ELSE 0
    END AS response_score,
    
    -- Window functions for cohort statistics
    AVG(pfs_months) OVER (PARTITION BY cohort) AS cohort_avg_pfs,
    STDDEV(pfs_months) OVER (PARTITION BY cohort) AS cohort_std_pfs,
    
    -- Relative performance vs cohort
    (pfs_months - AVG(pfs_months) OVER (PARTITION BY cohort)) / 
        NULLIF(STDDEV(pfs_months) OVER (PARTITION BY cohort), 0) AS pfs_zscore,
    
    -- Treatment arm comparison
    pfs_months - AVG(pfs_months) OVER (PARTITION BY treatment_arm) AS pfs_vs_arm_avg,
    
    -- Ranking within cohort
    PERCENT_RANK() OVER (PARTITION BY cohort ORDER BY pfs_months) AS pfs_percentile
    
FROM LIFEARC_POC.DATA_SHARING.CLINICAL_TRIAL_RESULTS;


-- ============================================================================
-- PATTERN 2: SNOWPARK PYTHON FOR COMPLEX LOGIC
-- ============================================================================

/*
Example Snowpark Python for hierarchical data processing:

from snowflake.snowpark import Session
from snowflake.snowpark.functions import col, udf
from snowflake.snowpark.types import StructType, StructField, StringType, FloatType
import pandas as pd

# Create session (use key-pair auth in production)
session = Session.builder.configs(connection_parameters).create()

# Register a Python UDF for sequence-based feature extraction
@udf(
    name="extract_sequence_features",
    is_permanent=True,
    stage_location="@LIFEARC_POC.ML_FEATURES.UDF_STAGE",
    packages=["pandas", "numpy"]
)
def extract_sequence_features(sequence: str) -> dict:
    """Extract features from DNA sequence."""
    if not sequence:
        return {}
    
    seq = sequence.upper()
    length = len(seq)
    
    # Nucleotide composition
    a_count = seq.count('A')
    t_count = seq.count('T')
    g_count = seq.count('G')
    c_count = seq.count('C')
    
    gc_content = (g_count + c_count) / length if length > 0 else 0
    
    # Dinucleotide frequencies (example)
    dinucs = ['AA', 'AT', 'AG', 'AC', 'TA', 'TT', 'TG', 'TC', 
              'GA', 'GT', 'GG', 'GC', 'CA', 'CT', 'CG', 'CC']
    dinuc_freq = {}
    for dinuc in dinucs:
        count = sum(1 for i in range(len(seq)-1) if seq[i:i+2] == dinuc)
        dinuc_freq[dinuc] = count / (length - 1) if length > 1 else 0
    
    return {
        'length': length,
        'gc_content': gc_content,
        'a_fraction': a_count / length,
        't_fraction': t_count / length,
        'g_fraction': g_count / length,
        'c_fraction': c_count / length,
        **dinuc_freq
    }

# Use in SQL after registration:
# SELECT extract_sequence_features(sequence) FROM gene_sequences;
*/

-- Create UDF stage
CREATE STAGE IF NOT EXISTS LIFEARC_POC.ML_FEATURES.UDF_STAGE;


-- ============================================================================
-- PATTERN 3: HIERARCHICAL DATA HANDLING
-- ============================================================================

-- Example: Flatten nested JSON and compute group-level features
CREATE OR REPLACE VIEW LIFEARC_POC.ML_FEATURES.TRIAL_ARM_FEATURES AS
WITH arm_data AS (
    SELECT 
        ct.trial_id,
        arm.value:name::VARCHAR AS arm_name,
        arm.value:intervention::VARCHAR AS intervention,
        arm.value:patients::INT AS planned_patients,
        arm.index AS arm_index
    FROM LIFEARC_POC.UNSTRUCTURED_DATA.CLINICAL_TRIALS ct,
    LATERAL FLATTEN(input => ct.protocol_data:arms) arm
),
arm_results AS (
    SELECT 
        r.trial_id,
        r.treatment_arm,
        COUNT(*) AS actual_patients,
        AVG(r.pfs_months) AS avg_pfs,
        AVG(r.os_months) AS avg_os,
        SUM(CASE WHEN r.response_category IN ('Complete_Response', 'Partial_Response') 
            THEN 1 ELSE 0 END) * 100.0 / COUNT(*) AS response_rate
    FROM LIFEARC_POC.DATA_SHARING.CLINICAL_TRIAL_RESULTS r
    GROUP BY r.trial_id, r.treatment_arm
)
SELECT 
    a.trial_id,
    a.arm_name,
    a.intervention,
    a.planned_patients,
    r.actual_patients,
    a.planned_patients - COALESCE(r.actual_patients, 0) AS enrollment_gap,
    r.avg_pfs,
    r.avg_os,
    r.response_rate
FROM arm_data a
LEFT JOIN arm_results r 
    ON a.trial_id = r.trial_id 
    AND a.arm_name = r.treatment_arm;


-- ============================================================================
-- PATTERN 4: SNOWFLAKE ML FUNCTIONS
-- ============================================================================

-- Example: Time-series forecasting with built-in ML
/*
-- Create forecasting model
CREATE OR REPLACE SNOWFLAKE.ML.FORECAST patient_enrollment_forecast (
    INPUT_DATA => TABLE(
        SELECT 
            DATE_TRUNC('week', created_at) AS ds,
            COUNT(*) AS y
        FROM clinical_data
        GROUP BY ds
    ),
    TIMESTAMP_COLNAME => 'ds',
    TARGET_COLNAME => 'y'
);

-- Generate predictions
SELECT * FROM TABLE(patient_enrollment_forecast!FORECAST(
    FORECASTING_PERIODS => 12,  -- 12 weeks ahead
    CONFIG_OBJECT => {'prediction_interval': 0.95}
));
*/

-- Example: Anomaly detection
/*
CREATE OR REPLACE SNOWFLAKE.ML.ANOMALY_DETECTION adverse_event_detector (
    INPUT_DATA => TABLE(
        SELECT 
            patient_id,
            event_date,
            event_severity,
            lab_value_1,
            lab_value_2
        FROM adverse_events
    ),
    TIMESTAMP_COLNAME => 'event_date',
    TARGET_COLNAME => 'event_severity',
    LABEL_COLNAME => ''  -- Unsupervised
);
*/


-- ============================================================================
-- PATTERN 5: FEATURE STORE IMPLEMENTATION
-- ============================================================================

-- Create feature store table with point-in-time lookup
CREATE OR REPLACE TABLE LIFEARC_POC.ML_FEATURES.FEATURE_STORE (
    feature_set_id VARCHAR,
    entity_id VARCHAR,           -- patient_id, trial_id, etc.
    entity_type VARCHAR,         -- PATIENT, TRIAL, COMPOUND
    feature_name VARCHAR,
    feature_value VARIANT,
    feature_type VARCHAR,        -- NUMERIC, CATEGORICAL, ARRAY
    computed_at TIMESTAMP_NTZ,
    valid_from TIMESTAMP_NTZ,
    valid_to TIMESTAMP_NTZ,
    version INT,
    PRIMARY KEY (feature_set_id, entity_id, feature_name, version)
);

-- Function to get point-in-time features
CREATE OR REPLACE FUNCTION LIFEARC_POC.ML_FEATURES.GET_FEATURES_AS_OF(
    p_entity_id VARCHAR,
    p_as_of_timestamp TIMESTAMP_NTZ
)
RETURNS TABLE (
    feature_name VARCHAR,
    feature_value VARIANT,
    feature_type VARCHAR
)
AS
$$
    SELECT 
        feature_name,
        feature_value,
        feature_type
    FROM LIFEARC_POC.ML_FEATURES.FEATURE_STORE
    WHERE entity_id = p_entity_id
      AND p_as_of_timestamp BETWEEN valid_from AND COALESCE(valid_to, '9999-12-31'::TIMESTAMP_NTZ)
    QUALIFY ROW_NUMBER() OVER (
        PARTITION BY feature_name 
        ORDER BY version DESC
    ) = 1
$$;


-- ============================================================================
-- PATTERN 6: MODEL REGISTRY IN SNOWFLAKE
-- ============================================================================

CREATE OR REPLACE TABLE LIFEARC_POC.ML_FEATURES.MODEL_REGISTRY (
    model_id VARCHAR PRIMARY KEY DEFAULT UUID_STRING(),
    model_name VARCHAR NOT NULL,
    model_version VARCHAR NOT NULL,
    model_type VARCHAR,          -- CLASSIFICATION, REGRESSION, FORECAST
    framework VARCHAR,           -- SNOWFLAKE_ML, SKLEARN, PYTORCH, TENSORFLOW
    
    -- Storage
    model_stage VARCHAR,         -- Stage location for model artifacts
    model_path VARCHAR,
    
    -- Metadata
    training_data_ref VARCHAR,   -- Reference to training dataset
    feature_columns ARRAY,
    target_column VARCHAR,
    hyperparameters VARIANT,
    
    -- Performance metrics
    training_metrics VARIANT,
    validation_metrics VARIANT,
    test_metrics VARIANT,
    
    -- Lifecycle
    status VARCHAR DEFAULT 'DEVELOPMENT',  -- DEVELOPMENT, STAGING, PRODUCTION, ARCHIVED
    created_by VARCHAR DEFAULT CURRENT_USER(),
    created_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    promoted_to_prod_at TIMESTAMP_NTZ,
    archived_at TIMESTAMP_NTZ,
    
    UNIQUE (model_name, model_version)
);

-- Model lineage table
CREATE OR REPLACE TABLE LIFEARC_POC.ML_FEATURES.MODEL_LINEAGE (
    lineage_id VARCHAR DEFAULT UUID_STRING(),
    model_id VARCHAR REFERENCES LIFEARC_POC.ML_FEATURES.MODEL_REGISTRY(model_id),
    parent_model_id VARCHAR,
    lineage_type VARCHAR,        -- RETRAIN, FINE_TUNE, DERIVED
    changes_description TEXT,
    created_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);


-- ============================================================================
-- ORCHESTRATION: TASKS AND STREAMS
-- ============================================================================

-- Stream to capture new data for retraining
CREATE OR REPLACE STREAM LIFEARC_POC.ML_FEATURES.NEW_CLINICAL_DATA_STREAM
ON TABLE LIFEARC_POC.DATA_SHARING.CLINICAL_TRIAL_RESULTS;

-- Task to refresh features on new data
/*
CREATE OR REPLACE TASK LIFEARC_POC.ML_FEATURES.REFRESH_FEATURES_TASK
    WAREHOUSE = DEMO_WH
    SCHEDULE = 'USING CRON 0 2 * * * UTC'  -- Daily at 2 AM UTC
    WHEN SYSTEM$STREAM_HAS_DATA('LIFEARC_POC.ML_FEATURES.NEW_CLINICAL_DATA_STREAM')
AS
    CALL LIFEARC_POC.ML_FEATURES.REFRESH_ALL_FEATURES();

-- Start the task
ALTER TASK LIFEARC_POC.ML_FEATURES.REFRESH_FEATURES_TASK RESUME;
*/


-- ============================================================================
-- KEY RECOMMENDATIONS FOR LIFEARC
-- ============================================================================

/*
MLOps RECOMMENDATIONS:

1. FEATURE ENGINEERING STRATEGY
   - 80% of transforms should be SQL-based (most performant)
   - Use Snowpark Python for complex procedural logic
   - Reserve external compute (Azure ML) for GPU/deep learning only
   - Build reusable feature libraries in SQL + Python

2. HANDLING HIERARCHICAL DATA
   - Use LATERAL FLATTEN for nested JSON
   - Create intermediate views for complex hierarchies
   - Snowpark UDFs for recursive/graph operations
   - Consider pre-flattening for frequently accessed structures

3. SEQUENCE-BASED PROCESSING
   - Window functions for time-series patterns
   - Snowpark UDFs for custom sequence algorithms
   - Batch processing via stored procedures

4. FEATURE STORE PATTERN
   - Centralize all features in Snowflake
   - Implement point-in-time lookup for training reproducibility
   - Version features with audit trail
   - Document feature definitions

5. MODEL MANAGEMENT
   - Use Snowflake Model Registry for versioning
   - Track lineage between models
   - Implement staging → production promotion workflow
   - Store metrics for comparison

6. INTEGRATION WITH EXISTING GITHUB REPOS
   - Package SQL transforms as dbt models
   - Use Snowpark Python for existing Python logic
   - Gradual migration: start with new projects
   - Maintain Python packages for complex algorithms

7. RECOMMENDED WORKFLOW

   GitHub Repo Structure:
   ├── dbt/                    # SQL-based transforms
   │   ├── models/
   │   └── tests/
   ├── snowpark/               # Python UDFs and procedures
   │   ├── features/
   │   └── models/
   ├── notebooks/              # Exploration and prototyping
   └── deployment/             # CI/CD configs

*/
