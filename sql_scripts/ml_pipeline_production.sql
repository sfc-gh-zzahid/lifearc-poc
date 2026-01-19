/*
================================================================================
LifeArc POC - Production ML Pipeline Demo
================================================================================
Demonstrates complete ML workflow using NATIVE Snowflake ML capabilities.

This SQL script provides SQL-based equivalents and setup for the Python notebook.
For the full interactive experience, use: notebooks/ml_lifecycle_complete.ipynb

SNOWFLAKE ML COMPONENTS USED:
- Snowflake Feature Store (native API)
- Snowflake Model Registry (native, not custom table)
- ML Functions (Classification, Forecasting)
- ML Observability
- ML Lineage

================================================================================
*/

USE DATABASE LIFEARC_POC;
USE WAREHOUSE COMPUTE_WH;

-- ============================================================================
-- PART 1: SETUP SCHEMAS
-- ============================================================================

-- Feature Store schema (Feature Store is just a schema with special objects)
CREATE SCHEMA IF NOT EXISTS ML_FEATURE_STORE;

-- ML Demo schema for models and monitoring
CREATE SCHEMA IF NOT EXISTS ML_DEMO;

-- ============================================================================
-- PART 2: CREATE FEATURE TABLES (SQL-based features)
-- These feed into the Python Feature Store API
-- ============================================================================

-- Patient-level features derived from clinical data
CREATE OR REPLACE VIEW ML_FEATURE_STORE.PATIENT_CLINICAL_FEATURES_SOURCE AS
SELECT 
    PATIENT_ID,
    TRIAL_ID,
    
    -- Demographics
    PATIENT_AGE,
    CASE WHEN PATIENT_AGE < 50 THEN 'YOUNG'
         WHEN PATIENT_AGE < 65 THEN 'MIDDLE'
         ELSE 'SENIOR' END AS AGE_GROUP,
    
    -- Biomarker features
    BIOMARKER_STATUS,
    CASE WHEN BIOMARKER_STATUS = 'POSITIVE' THEN 1 ELSE 0 END AS BIOMARKER_POSITIVE,
    
    -- ctDNA features  
    CTDNA_CONFIRMATION,
    CASE WHEN CTDNA_CONFIRMATION = 'YES' THEN 1 ELSE 0 END AS CTDNA_CONFIRMED,
    
    -- Treatment features
    TREATMENT_ARM,
    CASE TREATMENT_ARM 
        WHEN 'Combination' THEN 3
        WHEN 'Experimental' THEN 2
        WHEN 'Standard' THEN 1
        ELSE 0 END AS TREATMENT_INTENSITY,
    
    -- Cohort
    COHORT,
    
    -- Outcomes (for training only, not inference)
    RESPONSE_CATEGORY,
    PFS_MONTHS,
    OS_MONTHS,
    
    -- Timestamp for point-in-time correctness
    CURRENT_TIMESTAMP() AS FEATURE_TIMESTAMP
    
FROM DATA_SHARING.CLINICAL_TRIAL_RESULTS;

-- Trial-level aggregate features
CREATE OR REPLACE VIEW ML_FEATURE_STORE.TRIAL_AGGREGATE_FEATURES_SOURCE AS
SELECT 
    TRIAL_ID,
    
    -- Trial performance metrics
    COUNT(*) AS TRIAL_ENROLLMENT,
    AVG(PFS_MONTHS) AS TRIAL_AVG_PFS,
    STDDEV(PFS_MONTHS) AS TRIAL_STD_PFS,
    AVG(OS_MONTHS) AS TRIAL_AVG_OS,
    
    -- Response rates
    SUM(CASE WHEN RESPONSE_CATEGORY IN ('Complete_Response', 'Partial_Response') 
        THEN 1 ELSE 0 END) * 100.0 / COUNT(*) AS TRIAL_RESPONSE_RATE,
    
    -- Biomarker prevalence
    SUM(CASE WHEN BIOMARKER_STATUS = 'POSITIVE' THEN 1 ELSE 0 END) * 100.0 / COUNT(*) 
        AS TRIAL_BIOMARKER_POSITIVE_PCT,
    
    -- ctDNA usage
    SUM(CASE WHEN CTDNA_CONFIRMATION = 'YES' THEN 1 ELSE 0 END) * 100.0 / COUNT(*) 
        AS TRIAL_CTDNA_USAGE_PCT,
    
    CURRENT_TIMESTAMP() AS FEATURE_TIMESTAMP
    
FROM DATA_SHARING.CLINICAL_TRIAL_RESULTS
GROUP BY TRIAL_ID;

-- ============================================================================
-- PART 3: TRAINING DATA PREPARATION
-- ============================================================================

-- Combined training dataset with all features
CREATE OR REPLACE VIEW ML_DEMO.TRAINING_DATASET AS
SELECT 
    p.PATIENT_ID,
    p.TRIAL_ID,
    
    -- Patient features
    p.PATIENT_AGE,
    p.AGE_GROUP,
    p.BIOMARKER_STATUS,
    p.BIOMARKER_POSITIVE,
    p.CTDNA_CONFIRMATION,
    p.CTDNA_CONFIRMED,
    p.TREATMENT_ARM,
    p.TREATMENT_INTENSITY,
    p.COHORT,
    
    -- Trial features
    t.TRIAL_ENROLLMENT,
    t.TRIAL_AVG_PFS,
    t.TRIAL_RESPONSE_RATE,
    t.TRIAL_BIOMARKER_POSITIVE_PCT,
    t.TRIAL_CTDNA_USAGE_PCT,
    
    -- Target variable
    p.RESPONSE_CATEGORY,
    CASE p.RESPONSE_CATEGORY
        WHEN 'Complete_Response' THEN 3
        WHEN 'Partial_Response' THEN 2
        WHEN 'Stable_Disease' THEN 1
        WHEN 'Progressive_Disease' THEN 0
        ELSE -1 END AS RESPONSE_LABEL,
    CASE WHEN p.RESPONSE_CATEGORY IN ('Complete_Response', 'Partial_Response') 
        THEN 1 ELSE 0 END AS IS_RESPONDER

FROM ML_FEATURE_STORE.PATIENT_CLINICAL_FEATURES_SOURCE p
JOIN ML_FEATURE_STORE.TRIAL_AGGREGATE_FEATURES_SOURCE t 
    ON p.TRIAL_ID = t.TRIAL_ID
WHERE p.RESPONSE_CATEGORY IS NOT NULL;

-- ============================================================================
-- PART 4: SNOWFLAKE ML CLASSIFICATION
-- Train model using native Snowflake ML
-- ============================================================================

-- Create classification model for response prediction
-- NOTE: This creates a model object in the Model Registry automatically
CREATE OR REPLACE SNOWFLAKE.ML.CLASSIFICATION CLINICAL_RESPONSE_MODEL(
    INPUT_DATA => SYSTEM$REFERENCE('VIEW', 'LIFEARC_POC.ML_DEMO.TRAINING_DATASET'),
    TARGET_COLNAME => 'IS_RESPONDER',
    CONFIG_OBJECT => {
        'ON_ERROR': 'SKIP',
        'MAX_ITERATIONS': 100
    }
);

-- ============================================================================
-- PART 5: MODEL EVALUATION
-- ============================================================================

-- Generate predictions
CREATE OR REPLACE VIEW ML_DEMO.MODEL_PREDICTIONS AS
SELECT 
    t.*,
    CLINICAL_RESPONSE_MODEL!PREDICT(
        INPUT_DATA => OBJECT_CONSTRUCT(
            'PATIENT_AGE', t.PATIENT_AGE,
            'BIOMARKER_POSITIVE', t.BIOMARKER_POSITIVE,
            'CTDNA_CONFIRMED', t.CTDNA_CONFIRMED,
            'TREATMENT_INTENSITY', t.TREATMENT_INTENSITY,
            'TRIAL_ENROLLMENT', t.TRIAL_ENROLLMENT,
            'TRIAL_AVG_PFS', t.TRIAL_AVG_PFS,
            'TRIAL_RESPONSE_RATE', t.TRIAL_RESPONSE_RATE,
            'TRIAL_BIOMARKER_POSITIVE_PCT', t.TRIAL_BIOMARKER_POSITIVE_PCT,
            'TRIAL_CTDNA_USAGE_PCT', t.TRIAL_CTDNA_USAGE_PCT
        )
    ) AS PREDICTION_RESULT
FROM ML_DEMO.TRAINING_DATASET t;

-- Extract predictions and calculate metrics
CREATE OR REPLACE VIEW ML_DEMO.MODEL_EVALUATION AS
SELECT 
    PATIENT_ID,
    IS_RESPONDER AS ACTUAL,
    PREDICTION_RESULT:"class"::INT AS PREDICTED,
    PREDICTION_RESULT:"probability"."1"::FLOAT AS PROBABILITY,
    CASE WHEN IS_RESPONDER = PREDICTION_RESULT:"class"::INT THEN 1 ELSE 0 END AS CORRECT
FROM ML_DEMO.MODEL_PREDICTIONS;

-- Model performance summary
SELECT 
    COUNT(*) AS TOTAL_PREDICTIONS,
    SUM(CORRECT) AS CORRECT_PREDICTIONS,
    ROUND(AVG(CORRECT) * 100, 2) AS ACCURACY_PCT,
    SUM(CASE WHEN ACTUAL = 1 AND PREDICTED = 1 THEN 1 ELSE 0 END) AS TRUE_POSITIVES,
    SUM(CASE WHEN ACTUAL = 0 AND PREDICTED = 0 THEN 1 ELSE 0 END) AS TRUE_NEGATIVES,
    SUM(CASE WHEN ACTUAL = 0 AND PREDICTED = 1 THEN 1 ELSE 0 END) AS FALSE_POSITIVES,
    SUM(CASE WHEN ACTUAL = 1 AND PREDICTED = 0 THEN 1 ELSE 0 END) AS FALSE_NEGATIVES
FROM ML_DEMO.MODEL_EVALUATION;

-- ============================================================================
-- PART 6: FEATURE IMPORTANCE
-- ============================================================================

-- Get feature importance from the model
SELECT CLINICAL_RESPONSE_MODEL!EXPLAIN_FEATURE_IMPORTANCE() AS FEATURE_IMPORTANCE;

-- ============================================================================
-- PART 7: MODEL MONITORING
-- ============================================================================

-- Create monitoring table
CREATE OR REPLACE TABLE ML_DEMO.MODEL_MONITORING (
    MONITORING_ID VARCHAR DEFAULT UUID_STRING(),
    MODEL_NAME VARCHAR,
    MODEL_VERSION VARCHAR,
    MONITORING_DATE DATE,
    TOTAL_PREDICTIONS INT,
    POSITIVE_PREDICTIONS INT,
    NEGATIVE_PREDICTIONS INT,
    POSITIVE_RATE FLOAT,
    AVG_PROBABILITY FLOAT,
    FEATURE_STATS VARIANT,
    CREATED_AT TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    PRIMARY KEY (MONITORING_ID)
);

-- Log current prediction statistics
INSERT INTO ML_DEMO.MODEL_MONITORING 
(MODEL_NAME, MODEL_VERSION, MONITORING_DATE, TOTAL_PREDICTIONS, 
 POSITIVE_PREDICTIONS, NEGATIVE_PREDICTIONS, POSITIVE_RATE, AVG_PROBABILITY)
SELECT 
    'CLINICAL_RESPONSE_MODEL',
    'V1',
    CURRENT_DATE(),
    COUNT(*),
    SUM(CASE WHEN PREDICTED = 1 THEN 1 ELSE 0 END),
    SUM(CASE WHEN PREDICTED = 0 THEN 1 ELSE 0 END),
    ROUND(AVG(CASE WHEN PREDICTED = 1 THEN 1.0 ELSE 0.0 END), 4),
    ROUND(AVG(PROBABILITY), 4)
FROM ML_DEMO.MODEL_EVALUATION;

-- ============================================================================
-- PART 8: DRIFT DETECTION QUERIES
-- ============================================================================

-- Prediction drift detection
CREATE OR REPLACE VIEW ML_DEMO.PREDICTION_DRIFT AS
WITH baseline AS (
    SELECT AVG(POSITIVE_RATE) AS baseline_rate
    FROM ML_DEMO.MODEL_MONITORING
    WHERE MODEL_NAME = 'CLINICAL_RESPONSE_MODEL'
      AND MONITORING_DATE < CURRENT_DATE() - 7
),
current_period AS (
    SELECT AVG(POSITIVE_RATE) AS current_rate
    FROM ML_DEMO.MODEL_MONITORING
    WHERE MODEL_NAME = 'CLINICAL_RESPONSE_MODEL'
      AND MONITORING_DATE >= CURRENT_DATE() - 7
)
SELECT 
    b.baseline_rate,
    c.current_rate,
    ABS(c.current_rate - b.baseline_rate) AS drift_magnitude,
    CASE 
        WHEN ABS(c.current_rate - b.baseline_rate) > 0.1 THEN 'ALERT: Significant drift'
        WHEN ABS(c.current_rate - b.baseline_rate) > 0.05 THEN 'WARNING: Moderate drift'
        ELSE 'OK: Within normal range'
    END AS drift_status
FROM baseline b, current_period c;

-- ============================================================================
-- PART 9: SCHEDULED MONITORING TASK
-- ============================================================================

-- Stored procedure to log daily statistics
CREATE OR REPLACE PROCEDURE ML_DEMO.LOG_DAILY_MONITORING()
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
BEGIN
    INSERT INTO ML_DEMO.MODEL_MONITORING 
    (MODEL_NAME, MODEL_VERSION, MONITORING_DATE, TOTAL_PREDICTIONS, 
     POSITIVE_PREDICTIONS, NEGATIVE_PREDICTIONS, POSITIVE_RATE, AVG_PROBABILITY)
    SELECT 
        'CLINICAL_RESPONSE_MODEL',
        'V1',
        CURRENT_DATE(),
        COUNT(*),
        SUM(CASE WHEN PREDICTED = 1 THEN 1 ELSE 0 END),
        SUM(CASE WHEN PREDICTED = 0 THEN 1 ELSE 0 END),
        ROUND(AVG(CASE WHEN PREDICTED = 1 THEN 1.0 ELSE 0.0 END), 4),
        ROUND(AVG(PROBABILITY), 4)
    FROM ML_DEMO.MODEL_EVALUATION;
    
    RETURN 'Monitoring statistics logged successfully';
END;
$$;

-- Create scheduled task (uncomment to enable)
/*
CREATE OR REPLACE TASK ML_DEMO.DAILY_MODEL_MONITORING
    WAREHOUSE = COMPUTE_WH
    SCHEDULE = 'USING CRON 0 8 * * * UTC'  -- Daily at 8 AM UTC
AS
    CALL ML_DEMO.LOG_DAILY_MONITORING();

-- Enable the task
ALTER TASK ML_DEMO.DAILY_MODEL_MONITORING RESUME;
*/

-- ============================================================================
-- PART 10: PRODUCTION INFERENCE PATTERN
-- ============================================================================

-- View for production inference
-- This can be called by downstream systems
CREATE OR REPLACE VIEW ML_DEMO.PRODUCTION_INFERENCE AS
SELECT 
    p.PATIENT_ID,
    p.TRIAL_ID,
    p.TREATMENT_ARM,
    p.BIOMARKER_STATUS,
    p.CTDNA_CONFIRMATION,
    CLINICAL_RESPONSE_MODEL!PREDICT(
        INPUT_DATA => OBJECT_CONSTRUCT(
            'PATIENT_AGE', p.PATIENT_AGE,
            'BIOMARKER_POSITIVE', p.BIOMARKER_POSITIVE,
            'CTDNA_CONFIRMED', p.CTDNA_CONFIRMED,
            'TREATMENT_INTENSITY', p.TREATMENT_INTENSITY,
            'TRIAL_ENROLLMENT', t.TRIAL_ENROLLMENT,
            'TRIAL_AVG_PFS', t.TRIAL_AVG_PFS,
            'TRIAL_RESPONSE_RATE', t.TRIAL_RESPONSE_RATE,
            'TRIAL_BIOMARKER_POSITIVE_PCT', t.TRIAL_BIOMARKER_POSITIVE_PCT,
            'TRIAL_CTDNA_USAGE_PCT', t.TRIAL_CTDNA_USAGE_PCT
        )
    ):"probability"."1"::FLOAT AS RESPONSE_PROBABILITY,
    CASE 
        WHEN CLINICAL_RESPONSE_MODEL!PREDICT(
            INPUT_DATA => OBJECT_CONSTRUCT(
                'PATIENT_AGE', p.PATIENT_AGE,
                'BIOMARKER_POSITIVE', p.BIOMARKER_POSITIVE,
                'CTDNA_CONFIRMED', p.CTDNA_CONFIRMED,
                'TREATMENT_INTENSITY', p.TREATMENT_INTENSITY,
                'TRIAL_ENROLLMENT', t.TRIAL_ENROLLMENT,
                'TRIAL_AVG_PFS', t.TRIAL_AVG_PFS,
                'TRIAL_RESPONSE_RATE', t.TRIAL_RESPONSE_RATE,
                'TRIAL_BIOMARKER_POSITIVE_PCT', t.TRIAL_BIOMARKER_POSITIVE_PCT,
                'TRIAL_CTDNA_USAGE_PCT', t.TRIAL_CTDNA_USAGE_PCT
            )
        ):"probability"."1"::FLOAT >= 0.6 THEN 'LIKELY_RESPONDER'
        WHEN CLINICAL_RESPONSE_MODEL!PREDICT(
            INPUT_DATA => OBJECT_CONSTRUCT(
                'PATIENT_AGE', p.PATIENT_AGE,
                'BIOMARKER_POSITIVE', p.BIOMARKER_POSITIVE,
                'CTDNA_CONFIRMED', p.CTDNA_CONFIRMED,
                'TREATMENT_INTENSITY', p.TREATMENT_INTENSITY,
                'TRIAL_ENROLLMENT', t.TRIAL_ENROLLMENT,
                'TRIAL_AVG_PFS', t.TRIAL_AVG_PFS,
                'TRIAL_RESPONSE_RATE', t.TRIAL_RESPONSE_RATE,
                'TRIAL_BIOMARKER_POSITIVE_PCT', t.TRIAL_BIOMARKER_POSITIVE_PCT,
                'TRIAL_CTDNA_USAGE_PCT', t.TRIAL_CTDNA_USAGE_PCT
            )
        ):"probability"."1"::FLOAT >= 0.4 THEN 'UNCERTAIN'
        ELSE 'UNLIKELY_RESPONDER'
    END AS RESPONSE_PREDICTION
FROM ML_FEATURE_STORE.PATIENT_CLINICAL_FEATURES_SOURCE p
JOIN ML_FEATURE_STORE.TRIAL_AGGREGATE_FEATURES_SOURCE t 
    ON p.TRIAL_ID = t.TRIAL_ID;

-- ============================================================================
-- SUMMARY: Objects Created
-- ============================================================================

/*
ML_FEATURE_STORE schema:
├── PATIENT_CLINICAL_FEATURES_SOURCE (View) - Patient-level features
└── TRIAL_AGGREGATE_FEATURES_SOURCE (View) - Trial-level aggregate features

ML_DEMO schema:
├── TRAINING_DATASET (View) - Combined features for training
├── CLINICAL_RESPONSE_MODEL (ML Model) - Native Snowflake ML Classification
├── MODEL_PREDICTIONS (View) - Raw predictions
├── MODEL_EVALUATION (View) - Predictions with accuracy metrics
├── MODEL_MONITORING (Table) - Drift tracking
├── PREDICTION_DRIFT (View) - Drift detection
├── LOG_DAILY_MONITORING (Procedure) - Monitoring automation
└── PRODUCTION_INFERENCE (View) - Production scoring

KEY DIFFERENCES FROM PREVIOUS VERSION:
1. Uses NATIVE Snowflake ML Classification (not custom model table)
2. Feature Store schema prepared for Python API
3. Proper monitoring with drift detection
4. Production inference view for downstream systems
5. No custom model registry table (use native Model Registry)

For full Feature Store and Model Registry functionality, use the Python notebook:
notebooks/ml_lifecycle_complete.ipynb
*/
