/*
================================================================================
LIFEARC - USE CASE 3: INTEGRATION WITH AZURE ML STUDIO
================================================================================

Reference Architecture: Snowflake as Data & Feature Store for Azure ML

Current Azure ML Setup:
- Compute on VMs
- Azure Blob Storage
- Model registry and data registry
- Model deployment and lifecycle management

Goal: 
- Snowflake as centralized data and feature store
- Minimize disruption to existing ML workflows
- Clear data lineage between Snowflake and Azure ML

================================================================================
*/


-- ============================================================================
-- ARCHITECTURE DIAGRAM (ASCII)
-- ============================================================================

/*
                    SNOWFLAKE + AZURE ML STUDIO INTEGRATION ARCHITECTURE
    ┌─────────────────────────────────────────────────────────────────────────────────────────┐
    │                                                                                         │
    │  ┌─────────────────────────────────────────────────────────────────────────────────┐   │
    │  │                              DATA SOURCES                                        │   │
    │  │                                                                                  │   │
    │  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────────┐│   │
    │  │  │   Lab       │  │  Clinical   │  │  Genomics   │  │   External Partners     ││   │
    │  │  │   Systems   │  │   Systems   │  │   Data      │  │   (via Data Sharing)    ││   │
    │  │  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘  └────────────┬────────────┘│   │
    │  │         └─────────────────┴────────────────┴─────────────────────┘             │   │
    │  └─────────────────────────────────────────────┬───────────────────────────────────┘   │
    │                                                │                                       │
    │                                                ▼                                       │
    │  ┌─────────────────────────────────────────────────────────────────────────────────┐   │
    │  │                                                                                 │   │
    │  │                              SNOWFLAKE                                          │   │
    │  │                    (Central Data & Feature Store)                               │   │
    │  │                                                                                 │   │
    │  │  ┌───────────────────┐  ┌───────────────────┐  ┌───────────────────────────┐   │   │
    │  │  │   RAW LAYER       │  │  CURATED LAYER    │  │    FEATURE STORE          │   │   │
    │  │  │                   │  │                   │  │                           │   │   │
    │  │  │  • Landing tables │  │  • Cleaned data   │  │  • ML-ready features      │   │   │
    │  │  │  • JSON/VARIANT   │  │  • Joined views   │  │  • Point-in-time lookup   │   │   │
    │  │  │  • Full history   │  │  • Business logic │  │  • Versioned              │   │   │
    │  │  └───────────────────┘  └───────────────────┘  └───────────────────────────┘   │   │
    │  │                                                            │                    │   │
    │  │  ┌──────────────────────────────────────────────────────────────────────────┐  │   │
    │  │  │                        DATA ACCESS LAYER                                  │  │   │
    │  │  │                                                                          │  │   │
    │  │  │  ┌──────────────────┐  ┌──────────────────┐  ┌──────────────────────┐   │  │   │
    │  │  │  │ Snowflake Python │  │  JDBC/ODBC       │  │  External Stages     │   │  │   │
    │  │  │  │ Connector        │  │  Connectors      │  │  (Azure Blob)        │   │  │   │
    │  │  │  └────────┬─────────┘  └────────┬─────────┘  └──────────┬───────────┘   │  │   │
    │  │  │           └──────────────────────┼──────────────────────┘               │  │   │
    │  │  └──────────────────────────────────┼──────────────────────────────────────┘  │   │
    │  └─────────────────────────────────────┼─────────────────────────────────────────┘   │
    │                                        │                                             │
    │                    Data flows to Azure │ (read-only from ML perspective)            │
    │                                        ▼                                             │
    │  ┌─────────────────────────────────────────────────────────────────────────────────┐ │
    │  │                                                                                  │ │
    │  │                             AZURE ML STUDIO                                      │ │
    │  │                                                                                  │ │
    │  │  ┌─────────────────────────────────────────────────────────────────────────┐    │ │
    │  │  │                         DATA ACCESS                                      │    │ │
    │  │  │                                                                          │    │ │
    │  │  │  Option A: Direct Query (small-medium data)                              │    │ │
    │  │  │  ════════════════════════════════════════                                │    │ │
    │  │  │  • snowflake-connector-python in training scripts                        │    │ │
    │  │  │  • Query features directly from Snowflake                                │    │ │
    │  │  │  • Best for: < 10GB datasets, real-time features                        │    │ │
    │  │  │                                                                          │    │ │
    │  │  │  Option B: Export to Azure Blob (large data)                            │    │ │
    │  │  │  ════════════════════════════════════════                                │    │ │
    │  │  │  • COPY INTO → Azure Blob → Azure ML Datastore                          │    │ │
    │  │  │  • Scheduled refresh via Snowflake Tasks                                 │    │ │
    │  │  │  • Best for: > 10GB, GPU training, distributed processing               │    │ │
    │  │  │                                                                          │    │ │
    │  │  │  Option C: Snowpark ML (train in Snowflake)                             │    │ │
    │  │  │  ════════════════════════════════════════                                │    │ │
    │  │  │  • Train simple models directly in Snowflake                            │    │ │
    │  │  │  • Export trained model to Azure ML for serving                         │    │ │
    │  │  │  • Best for: Classification, regression, forecasting                    │    │ │
    │  │  │                                                                          │    │ │
    │  │  └─────────────────────────────────────────────────────────────────────────┘    │ │
    │  │                                        │                                         │ │
    │  │                                        ▼                                         │ │
    │  │  ┌─────────────────────────────────────────────────────────────────────────┐    │ │
    │  │  │                      TRAINING & EXPERIMENTATION                          │    │ │
    │  │  │                                                                          │    │ │
    │  │  │  ┌──────────────────┐  ┌──────────────────┐  ┌────────────────────┐     │    │ │
    │  │  │  │  Azure Compute   │  │  Experiments     │  │  Hyperparameter    │     │    │ │
    │  │  │  │  (VMs/Clusters)  │  │  Tracking        │  │  Tuning            │     │    │ │
    │  │  │  └──────────────────┘  └──────────────────┘  └────────────────────┘     │    │ │
    │  │  │                                                                          │    │ │
    │  │  └─────────────────────────────────────────────────────────────────────────┘    │ │
    │  │                                        │                                         │ │
    │  │                                        ▼                                         │ │
    │  │  ┌─────────────────────────────────────────────────────────────────────────┐    │ │
    │  │  │                         MODEL REGISTRY                                   │    │ │
    │  │  │                                                                          │    │ │
    │  │  │  • Azure ML Model Registry (primary for deployment)                      │    │ │
    │  │  │  • Sync metadata to Snowflake for lineage                               │    │ │
    │  │  │  • Track: training data version, features used, metrics                 │    │ │
    │  │  │                                                                          │    │ │
    │  │  └─────────────────────────────────────────────────────────────────────────┘    │ │
    │  │                                        │                                         │ │
    │  │                                        ▼                                         │ │
    │  │  ┌─────────────────────────────────────────────────────────────────────────┐    │ │
    │  │  │                         DEPLOYMENT                                       │    │ │
    │  │  │                                                                          │    │ │
    │  │  │  ┌───────────────────┐  ┌───────────────────┐  ┌───────────────────┐    │    │ │
    │  │  │  │ Real-time (AKS)   │  │ Batch (Snowflake) │  │ Managed Endpoint  │    │    │ │
    │  │  │  │ (Low latency)     │  │ (Import model)    │  │ (Azure ML)        │    │    │ │
    │  │  │  └───────────────────┘  └───────────────────┘  └───────────────────┘    │    │ │
    │  │  │                                                                          │    │ │
    │  │  └─────────────────────────────────────────────────────────────────────────┘    │ │
    │  │                                                                                  │ │
    │  └──────────────────────────────────────────────────────────────────────────────────┘ │
    │                                        │                                             │
    │                    Predictions written │ back to Snowflake                           │
    │                                        ▼                                             │
    │  ┌─────────────────────────────────────────────────────────────────────────────────┐ │
    │  │                         SNOWFLAKE (Predictions Store)                           │ │
    │  │                                                                                  │ │
    │  │  • Store batch predictions                                                       │ │
    │  │  • Monitor model performance over time                                          │ │
    │  │  • Compare predictions vs actuals                                               │ │
    │  │  • Data drift detection                                                         │ │
    │  │                                                                                  │ │
    │  └─────────────────────────────────────────────────────────────────────────────────┘ │
    └─────────────────────────────────────────────────────────────────────────────────────────┘

*/


-- ============================================================================
-- IMPLEMENTATION: DATA EXPORT TO AZURE ML
-- ============================================================================

USE DATABASE LIFEARC_POC;
CREATE SCHEMA IF NOT EXISTS AZURE_ML_INTEGRATION;

-- Azure storage integration for ML data exchange
/*
CREATE OR REPLACE STORAGE INTEGRATION LIFEARC_AZURE_ML_INT
    TYPE = EXTERNAL_STAGE
    STORAGE_PROVIDER = 'AZURE'
    ENABLED = TRUE
    AZURE_TENANT_ID = '<your_tenant_id>'
    STORAGE_ALLOWED_LOCATIONS = (
        'azure://lifearcmldata.blob.core.windows.net/training-data/',
        'azure://lifearcmldata.blob.core.windows.net/predictions/'
    );

-- Grant usage to ML role
GRANT USAGE ON INTEGRATION LIFEARC_AZURE_ML_INT TO ROLE LIFEARC_ML_PIPELINE_ROLE;
*/

-- Stage for exporting training data
/*
CREATE OR REPLACE STAGE LIFEARC_POC.AZURE_ML_INTEGRATION.ML_TRAINING_STAGE
    STORAGE_INTEGRATION = LIFEARC_AZURE_ML_INT
    URL = 'azure://lifearcmldata.blob.core.windows.net/training-data/'
    FILE_FORMAT = (TYPE = PARQUET);
*/

-- Stage for importing predictions
/*
CREATE OR REPLACE STAGE LIFEARC_POC.AZURE_ML_INTEGRATION.ML_PREDICTIONS_STAGE
    STORAGE_INTEGRATION = LIFEARC_AZURE_ML_INT
    URL = 'azure://lifearcmldata.blob.core.windows.net/predictions/'
    FILE_FORMAT = (TYPE = PARQUET);
*/


-- ============================================================================
-- EXPORT PATTERNS FOR AZURE ML
-- ============================================================================

-- Create view specifically formatted for ML training
CREATE OR REPLACE VIEW LIFEARC_POC.AZURE_ML_INTEGRATION.TRAINING_DATASET_V1 AS
SELECT 
    -- ID for tracking
    result_id,
    
    -- Features (numeric)
    pfs_months,
    os_months,
    
    -- Features (categorical - one-hot encoded)
    IFF(treatment_arm = 'ARM_A', 1, 0) AS is_arm_a,
    IFF(treatment_arm = 'ARM_B', 1, 0) AS is_arm_b,
    IFF(cohort = 'Cohort_A', 1, 0) AS is_cohort_a,
    IFF(cohort = 'Cohort_B', 1, 0) AS is_cohort_b,
    IFF(patient_sex = 'F', 1, 0) AS is_female,
    IFF(biomarker_status LIKE '%POS%', 1, 0) AS is_biomarker_positive,
    
    -- Target variable
    IFF(response_category IN ('Complete_Response', 'Partial_Response'), 1, 0) AS responded,
    
    -- Metadata for tracking
    CURRENT_TIMESTAMP() AS exported_at,
    'v1' AS dataset_version
    
FROM LIFEARC_POC.DATA_SHARING.CLINICAL_TRIAL_RESULTS
WHERE response_category IS NOT NULL;

-- Procedure to export training data to Azure Blob
CREATE OR REPLACE PROCEDURE LIFEARC_POC.AZURE_ML_INTEGRATION.EXPORT_TRAINING_DATA(
    dataset_name VARCHAR,
    version VARCHAR
)
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
DECLARE
    export_path VARCHAR;
    row_count INT;
BEGIN
    export_path := dataset_name || '/v' || version || '/data_';
    
    -- Export to parquet format
    EXECUTE IMMEDIATE '
    COPY INTO @LIFEARC_POC.AZURE_ML_INTEGRATION.ML_TRAINING_STAGE/' || :export_path || '
    FROM LIFEARC_POC.AZURE_ML_INTEGRATION.TRAINING_DATASET_V1
    FILE_FORMAT = (TYPE = PARQUET)
    HEADER = TRUE
    OVERWRITE = TRUE
    ';
    
    -- Log export
    SELECT COUNT(*) INTO row_count FROM LIFEARC_POC.AZURE_ML_INTEGRATION.TRAINING_DATASET_V1;
    
    INSERT INTO LIFEARC_POC.AZURE_ML_INTEGRATION.DATA_EXPORT_LOG 
    (dataset_name, version, export_path, row_count)
    VALUES (dataset_name, version, export_path, row_count);
    
    RETURN 'Exported ' || row_count || ' rows to ' || export_path;
END;
$$;

-- Export tracking table
CREATE OR REPLACE TABLE LIFEARC_POC.AZURE_ML_INTEGRATION.DATA_EXPORT_LOG (
    export_id VARCHAR DEFAULT UUID_STRING(),
    dataset_name VARCHAR,
    version VARCHAR,
    export_path VARCHAR,
    row_count INT,
    exported_by VARCHAR DEFAULT CURRENT_USER(),
    exported_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);


-- ============================================================================
-- IMPORT PATTERNS: PREDICTIONS BACK TO SNOWFLAKE
-- ============================================================================

-- Table to store predictions from Azure ML
CREATE OR REPLACE TABLE LIFEARC_POC.AZURE_ML_INTEGRATION.PREDICTIONS (
    prediction_id VARCHAR DEFAULT UUID_STRING(),
    result_id VARCHAR,                    -- FK to original data
    model_id VARCHAR,                     -- Model that made prediction
    model_version VARCHAR,
    
    -- Prediction outputs
    predicted_class INT,
    prediction_probability FLOAT,
    prediction_confidence VARCHAR,        -- HIGH, MEDIUM, LOW
    
    -- Feature values at prediction time (for drift detection)
    feature_snapshot VARIANT,
    
    -- Metadata
    predicted_at TIMESTAMP_NTZ,
    imported_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

-- Procedure to import predictions from Azure ML
CREATE OR REPLACE PROCEDURE LIFEARC_POC.AZURE_ML_INTEGRATION.IMPORT_PREDICTIONS(
    model_id VARCHAR,
    model_version VARCHAR
)
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
DECLARE
    import_path VARCHAR;
    row_count INT;
BEGIN
    import_path := 'predictions/' || model_id || '/' || model_version || '/';
    
    -- Import from parquet
    EXECUTE IMMEDIATE '
    COPY INTO LIFEARC_POC.AZURE_ML_INTEGRATION.PREDICTIONS 
    (result_id, predicted_class, prediction_probability, predicted_at)
    FROM @LIFEARC_POC.AZURE_ML_INTEGRATION.ML_PREDICTIONS_STAGE/' || :import_path || '
    FILE_FORMAT = (TYPE = PARQUET)
    MATCH_BY_COLUMN_NAME = CASE_INSENSITIVE
    ';
    
    -- Update model info
    UPDATE LIFEARC_POC.AZURE_ML_INTEGRATION.PREDICTIONS
    SET model_id = model_id,
        model_version = model_version
    WHERE model_id IS NULL;
    
    RETURN 'Import complete';
END;
$$;


-- ============================================================================
-- MODEL LINEAGE: TRACK DATA→MODEL→PREDICTIONS
-- ============================================================================

CREATE OR REPLACE TABLE LIFEARC_POC.AZURE_ML_INTEGRATION.MODEL_LINEAGE (
    lineage_id VARCHAR DEFAULT UUID_STRING(),
    
    -- Model info (synced from Azure ML)
    model_id VARCHAR,
    model_name VARCHAR,
    model_version VARCHAR,
    azure_ml_run_id VARCHAR,
    
    -- Training data reference
    snowflake_dataset_name VARCHAR,
    snowflake_dataset_version VARCHAR,
    training_data_query TEXT,
    training_data_row_count INT,
    feature_columns ARRAY,
    target_column VARCHAR,
    
    -- Training metadata
    training_started_at TIMESTAMP_NTZ,
    training_completed_at TIMESTAMP_NTZ,
    hyperparameters VARIANT,
    
    -- Metrics
    metrics VARIANT,
    
    -- Lifecycle
    created_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    created_by VARCHAR DEFAULT CURRENT_USER()
);

-- View joining predictions with actual outcomes for monitoring
CREATE OR REPLACE VIEW LIFEARC_POC.AZURE_ML_INTEGRATION.PREDICTION_ACCURACY AS
SELECT 
    p.prediction_id,
    p.result_id,
    p.model_id,
    p.model_version,
    p.predicted_class,
    p.prediction_probability,
    
    -- Actual outcome
    IFF(r.response_category IN ('Complete_Response', 'Partial_Response'), 1, 0) AS actual_class,
    
    -- Accuracy metrics
    IFF(p.predicted_class = IFF(r.response_category IN ('Complete_Response', 'Partial_Response'), 1, 0), 
        1, 0) AS is_correct,
    
    p.predicted_at,
    r.created_at AS actual_recorded_at,
    DATEDIFF(day, p.predicted_at, r.created_at) AS days_to_outcome

FROM LIFEARC_POC.AZURE_ML_INTEGRATION.PREDICTIONS p
JOIN LIFEARC_POC.DATA_SHARING.CLINICAL_TRIAL_RESULTS r
    ON p.result_id = r.result_id;


-- ============================================================================
-- PYTHON CODE: AZURE ML INTEGRATION EXAMPLES
-- ============================================================================

/*
================================================================================
AZURE ML TRAINING SCRIPT WITH SNOWFLAKE CONNECTOR
================================================================================

# File: train_model.py (runs in Azure ML Compute)

import snowflake.connector
import pandas as pd
from sklearn.ensemble import RandomForestClassifier
from sklearn.model_selection import train_test_split
import mlflow
import mlflow.sklearn
import os

# Get credentials from Azure ML environment (stored as secrets)
SNOWFLAKE_ACCOUNT = os.environ['SNOWFLAKE_ACCOUNT']
SNOWFLAKE_USER = os.environ['SNOWFLAKE_USER']
SNOWFLAKE_PRIVATE_KEY = os.environ['SNOWFLAKE_PRIVATE_KEY']

def get_snowflake_connection():
    """Create Snowflake connection using key-pair auth."""
    from cryptography.hazmat.backends import default_backend
    from cryptography.hazmat.primitives import serialization
    
    # Load private key from environment
    p_key = serialization.load_pem_private_key(
        SNOWFLAKE_PRIVATE_KEY.encode(),
        password=None,
        backend=default_backend()
    )
    
    pkb = p_key.private_bytes(
        encoding=serialization.Encoding.DER,
        format=serialization.PrivateFormat.PKCS8,
        encryption_algorithm=serialization.NoEncryption()
    )
    
    return snowflake.connector.connect(
        user=SNOWFLAKE_USER,
        account=SNOWFLAKE_ACCOUNT,
        private_key=pkb,
        warehouse='DEMO_WH',
        database='LIFEARC_POC',
        schema='AZURE_ML_INTEGRATION'
    )

def load_training_data():
    """Load training data from Snowflake."""
    conn = get_snowflake_connection()
    
    query = """
    SELECT * FROM TRAINING_DATASET_V1
    """
    
    df = pd.read_sql(query, conn)
    conn.close()
    
    return df

def train_model(df):
    """Train classification model."""
    feature_cols = ['pfs_months', 'os_months', 'is_arm_a', 'is_arm_b', 
                    'is_cohort_a', 'is_cohort_b', 'is_female', 'is_biomarker_positive']
    
    X = df[feature_cols]
    y = df['responded']
    
    X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2)
    
    model = RandomForestClassifier(n_estimators=100, random_state=42)
    model.fit(X_train, y_train)
    
    # Log with MLflow
    with mlflow.start_run():
        mlflow.log_params({
            'n_estimators': 100,
            'features': feature_cols,
            'snowflake_dataset': 'TRAINING_DATASET_V1'
        })
        
        accuracy = model.score(X_test, y_test)
        mlflow.log_metric('accuracy', accuracy)
        
        mlflow.sklearn.log_model(model, 'model')
    
    return model

if __name__ == '__main__':
    df = load_training_data()
    model = train_model(df)


================================================================================
AZURE ML PIPELINE WITH SNOWFLAKE DATA SOURCE
================================================================================

# File: pipeline.py (Azure ML Pipeline definition)

from azure.ai.ml import MLClient, Input, Output, command
from azure.ai.ml.dsl import pipeline
from azure.identity import DefaultAzureCredential

# Connect to Azure ML workspace
ml_client = MLClient(
    DefaultAzureCredential(),
    subscription_id="<subscription_id>",
    resource_group_name="lifearc-ml-rg",
    workspace_name="lifearc-ml-workspace"
)

@pipeline(description="LifeArc ML Pipeline with Snowflake data")
def lifearc_ml_pipeline(snowflake_query: str):
    # Step 1: Extract data from Snowflake
    extract_data = command(
        name="extract_from_snowflake",
        command="python extract_data.py --query '${{inputs.query}}'",
        inputs={"query": snowflake_query},
        outputs={"data": Output(type="uri_folder")},
        environment="lifearc-ml-env:1"
    )
    
    # Step 2: Train model
    train_model = command(
        name="train_model",
        command="python train.py --data ${{inputs.data}}",
        inputs={"data": extract_data.outputs.data},
        outputs={"model": Output(type="mlflow_model")},
        environment="lifearc-ml-env:1"
    )
    
    # Step 3: Register model
    register_model = command(
        name="register_model",
        command="python register.py --model ${{inputs.model}}",
        inputs={"model": train_model.outputs.model},
        environment="lifearc-ml-env:1"
    )
    
    return {"model": train_model.outputs.model}

# Submit pipeline
pipeline_job = ml_client.jobs.create_or_update(
    lifearc_ml_pipeline(
        snowflake_query="SELECT * FROM LIFEARC_POC.AZURE_ML_INTEGRATION.TRAINING_DATASET_V1"
    )
)

*/


-- ============================================================================
-- MONITORING: DATA DRIFT AND MODEL PERFORMANCE
-- ============================================================================

-- Compare feature distributions over time
CREATE OR REPLACE VIEW LIFEARC_POC.AZURE_ML_INTEGRATION.FEATURE_DRIFT_MONITOR AS
WITH training_stats AS (
    SELECT 
        'training' AS data_type,
        AVG(pfs_months) AS mean_pfs,
        STDDEV(pfs_months) AS std_pfs,
        AVG(os_months) AS mean_os,
        STDDEV(os_months) AS std_os,
        AVG(is_female) AS pct_female,
        COUNT(*) AS sample_size
    FROM LIFEARC_POC.AZURE_ML_INTEGRATION.TRAINING_DATASET_V1
),
recent_stats AS (
    SELECT 
        'recent' AS data_type,
        AVG(pfs_months) AS mean_pfs,
        STDDEV(pfs_months) AS std_pfs,
        AVG(os_months) AS mean_os,
        STDDEV(os_months) AS std_os,
        AVG(IFF(patient_sex = 'F', 1, 0)) AS pct_female,
        COUNT(*) AS sample_size
    FROM LIFEARC_POC.DATA_SHARING.CLINICAL_TRIAL_RESULTS
    WHERE created_at > DATEADD(day, -30, CURRENT_TIMESTAMP())
)
SELECT 
    t.data_type AS training_data,
    r.data_type AS recent_data,
    ABS(t.mean_pfs - r.mean_pfs) / NULLIF(t.std_pfs, 0) AS pfs_drift_zscore,
    ABS(t.mean_os - r.mean_os) / NULLIF(t.std_os, 0) AS os_drift_zscore,
    ABS(t.pct_female - r.pct_female) AS female_pct_diff,
    CASE 
        WHEN ABS(t.mean_pfs - r.mean_pfs) / NULLIF(t.std_pfs, 0) > 2 THEN 'HIGH'
        WHEN ABS(t.mean_pfs - r.mean_pfs) / NULLIF(t.std_pfs, 0) > 1 THEN 'MEDIUM'
        ELSE 'LOW'
    END AS drift_alert_level
FROM training_stats t
CROSS JOIN recent_stats r;

-- Model performance tracking over time
CREATE OR REPLACE VIEW LIFEARC_POC.AZURE_ML_INTEGRATION.MODEL_PERFORMANCE_TREND AS
SELECT 
    model_id,
    model_version,
    DATE_TRUNC('week', predicted_at) AS week,
    COUNT(*) AS predictions,
    SUM(is_correct) AS correct_predictions,
    SUM(is_correct) * 100.0 / COUNT(*) AS accuracy_pct,
    AVG(prediction_probability) AS avg_confidence
FROM LIFEARC_POC.AZURE_ML_INTEGRATION.PREDICTION_ACCURACY
GROUP BY model_id, model_version, DATE_TRUNC('week', predicted_at)
ORDER BY week DESC;


-- ============================================================================
-- KEY RECOMMENDATIONS FOR LIFEARC
-- ============================================================================

/*
AZURE ML + SNOWFLAKE INTEGRATION RECOMMENDATIONS:

1. DATA ACCESS PATTERN SELECTION
   
   Use Direct Query (Snowflake Connector) when:
   - Dataset < 10GB
   - Need real-time feature access
   - Iterating on feature engineering
   - Interactive exploration
   
   Use Export to Azure Blob when:
   - Dataset > 10GB  
   - GPU training required
   - Distributed training needed
   - Batch training jobs
   - Need data versioning in blob

2. AUTHENTICATION
   - Use key-pair authentication for service accounts
   - Store private keys in Azure Key Vault
   - Create dedicated Snowflake service account for ML
   - Network policy: allow Azure ML IP ranges

3. DATA VERSIONING
   - Tag training data exports with version
   - Store training data query in model metadata
   - Enable time travel for reproducibility
   - Log Snowflake query ID with each export

4. MODEL REGISTRY STRATEGY
   - Primary: Azure ML Model Registry (for deployment)
   - Secondary: Sync metadata to Snowflake (for lineage)
   - Store: features used, data version, metrics

5. PREDICTION STORAGE
   - Write predictions back to Snowflake
   - Store feature snapshot for drift detection
   - Enable performance monitoring over time
   - Compare predicted vs actual

6. RECOMMENDED WORKFLOW

   ┌────────────────────────────────────────────────────────────────┐
   │  1. Data Scientists query Snowflake for exploration           │
   │  2. Feature engineering in Snowflake (SQL/Snowpark)           │
   │  3. Export versioned dataset to Azure Blob                    │
   │  4. Train model in Azure ML Compute                           │
   │  5. Log experiment to Azure ML + Snowflake                    │
   │  6. Deploy model (Azure ML endpoint or Snowflake UDF)         │
   │  7. Write predictions back to Snowflake                       │
   │  8. Monitor performance and drift in Snowflake                │
   └────────────────────────────────────────────────────────────────┘

7. MINIMAL DISRUPTION APPROACH
   - Keep existing Azure ML pipelines
   - Replace Azure Blob data sources with Snowflake queries
   - Add Snowflake connector to training environments
   - Gradual migration: new projects start with Snowflake
   - Existing projects migrate data source only

*/
