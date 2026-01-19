/*
================================================================================
LifeArc POC - End-to-End ML Demo
================================================================================
Demonstrates complete ML workflow in Snowflake:
1. Feature Engineering
2. Model Training (Snowflake ML Classification)
3. Model Registry
4. Batch Inference
5. Model Monitoring

Use Case: Predict drug-likeness from molecular properties
================================================================================
*/

-- ============================================================================
-- SETUP: Create ML Schema and Feature Store
-- ============================================================================

USE DATABASE LIFEARC_POC;
CREATE SCHEMA IF NOT EXISTS ML_DEMO;
USE SCHEMA ML_DEMO;

-- ============================================================================
-- STEP 1: FEATURE ENGINEERING
-- Create training dataset from compound properties
-- ============================================================================

CREATE OR REPLACE TABLE LIFEARC_POC.ML_DEMO.DRUG_LIKENESS_FEATURES AS
SELECT 
    compound_id,
    compound_name,
    therapeutic_area,
    target_gene,
    
    -- Molecular features (inputs)
    molecular_weight,
    logp,
    tpsa,
    hbd AS hydrogen_bond_donors,
    hba AS hydrogen_bond_acceptors,
    
    -- Derived features
    CASE 
        WHEN molecular_weight <= 500 THEN 1 ELSE 0 
    END AS mw_compliant,
    CASE 
        WHEN logp <= 5.0 THEN 1 ELSE 0 
    END AS logp_compliant,
    CASE 
        WHEN hbd <= 5 THEN 1 ELSE 0 
    END AS hbd_compliant,
    CASE 
        WHEN hba <= 10 THEN 1 ELSE 0 
    END AS hba_compliant,
    
    -- Target variable (binary classification)
    CASE 
        WHEN drug_likeness = 'drug_like' THEN 1 
        ELSE 0 
    END AS is_drug_like,
    
    -- Original label for reference
    drug_likeness,
    failure_reason,
    
    -- Metadata
    created_date,
    CURRENT_TIMESTAMP() AS feature_computed_at
    
FROM LIFEARC_POC.AI_DEMO.COMPOUND_PIPELINE_ANALYSIS;

-- Verify feature table
SELECT 
    COUNT(*) as total_compounds,
    SUM(is_drug_like) as drug_like_count,
    ROUND(AVG(is_drug_like) * 100, 1) as drug_like_pct
FROM LIFEARC_POC.ML_DEMO.DRUG_LIKENESS_FEATURES;

-- ============================================================================
-- STEP 2: MODEL TRAINING
-- Train classification model using Snowflake ML
-- ============================================================================

-- Create training view (80% of data)
CREATE OR REPLACE VIEW LIFEARC_POC.ML_DEMO.TRAINING_DATA AS
SELECT *
FROM LIFEARC_POC.ML_DEMO.DRUG_LIKENESS_FEATURES
WHERE MOD(ABS(HASH(compound_id)), 10) < 8;  -- 80% for training

-- Create test view (20% of data)
CREATE OR REPLACE VIEW LIFEARC_POC.ML_DEMO.TEST_DATA AS
SELECT *
FROM LIFEARC_POC.ML_DEMO.DRUG_LIKENESS_FEATURES
WHERE MOD(ABS(HASH(compound_id)), 10) >= 8;  -- 20% for testing

-- Train the classification model
CREATE OR REPLACE SNOWFLAKE.ML.CLASSIFICATION drug_likeness_model(
    INPUT_DATA => SYSTEM$REFERENCE('VIEW', 'LIFEARC_POC.ML_DEMO.TRAINING_DATA'),
    TARGET_COLNAME => 'IS_DRUG_LIKE',
    CONFIG_OBJECT => {
        'ON_ERROR': 'SKIP'
    }
);

-- ============================================================================
-- STEP 3: MODEL EVALUATION
-- Evaluate model performance on test data
-- ============================================================================

-- Generate predictions on test set
CREATE OR REPLACE TABLE LIFEARC_POC.ML_DEMO.TEST_PREDICTIONS AS
SELECT 
    t.*,
    drug_likeness_model!PREDICT(
        INPUT_DATA => OBJECT_CONSTRUCT(
            'MOLECULAR_WEIGHT', t.molecular_weight,
            'LOGP', t.logp,
            'TPSA', t.tpsa,
            'HYDROGEN_BOND_DONORS', t.hydrogen_bond_donors,
            'HYDROGEN_BOND_ACCEPTORS', t.hydrogen_bond_acceptors,
            'MW_COMPLIANT', t.mw_compliant,
            'LOGP_COMPLIANT', t.logp_compliant,
            'HBD_COMPLIANT', t.hbd_compliant,
            'HBA_COMPLIANT', t.hba_compliant
        )
    ) AS prediction_result
FROM LIFEARC_POC.ML_DEMO.TEST_DATA t;

-- Extract prediction and probability
CREATE OR REPLACE VIEW LIFEARC_POC.ML_DEMO.TEST_RESULTS AS
SELECT 
    compound_id,
    compound_name,
    therapeutic_area,
    is_drug_like AS actual,
    prediction_result:"class"::INT AS predicted,
    prediction_result:"probability"."1"::FLOAT AS prob_drug_like,
    CASE 
        WHEN is_drug_like = prediction_result:"class"::INT THEN 1 
        ELSE 0 
    END AS correct
FROM LIFEARC_POC.ML_DEMO.TEST_PREDICTIONS;

-- Calculate accuracy metrics
SELECT 
    COUNT(*) AS total_predictions,
    SUM(correct) AS correct_predictions,
    ROUND(AVG(correct) * 100, 1) AS accuracy_pct,
    SUM(CASE WHEN actual = 1 AND predicted = 1 THEN 1 ELSE 0 END) AS true_positives,
    SUM(CASE WHEN actual = 0 AND predicted = 0 THEN 1 ELSE 0 END) AS true_negatives,
    SUM(CASE WHEN actual = 0 AND predicted = 1 THEN 1 ELSE 0 END) AS false_positives,
    SUM(CASE WHEN actual = 1 AND predicted = 0 THEN 1 ELSE 0 END) AS false_negatives
FROM LIFEARC_POC.ML_DEMO.TEST_RESULTS;

-- ============================================================================
-- STEP 4: MODEL REGISTRY
-- Register model metadata for governance
-- ============================================================================

CREATE OR REPLACE TABLE LIFEARC_POC.ML_DEMO.MODEL_REGISTRY (
    model_id VARCHAR DEFAULT UUID_STRING(),
    model_name VARCHAR,
    model_version VARCHAR,
    model_type VARCHAR,
    description VARCHAR,
    feature_columns ARRAY,
    target_column VARCHAR,
    training_data_ref VARCHAR,
    training_rows INT,
    metrics VARIANT,
    status VARCHAR DEFAULT 'ACTIVE',
    created_by VARCHAR DEFAULT CURRENT_USER(),
    created_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    promoted_at TIMESTAMP_NTZ,
    PRIMARY KEY (model_id)
);

-- Register the trained model
INSERT INTO LIFEARC_POC.ML_DEMO.MODEL_REGISTRY 
(model_name, model_version, model_type, description, feature_columns, target_column, training_data_ref, training_rows, metrics, status)
SELECT 
    'drug_likeness_model',
    'v1.0',
    'CLASSIFICATION',
    'Predicts drug-likeness from Lipinski molecular properties',
    ARRAY_CONSTRUCT('molecular_weight', 'logp', 'tpsa', 'hydrogen_bond_donors', 'hydrogen_bond_acceptors', 'mw_compliant', 'logp_compliant', 'hbd_compliant', 'hba_compliant'),
    'is_drug_like',
    'LIFEARC_POC.ML_DEMO.TRAINING_DATA',
    (SELECT COUNT(*) FROM LIFEARC_POC.ML_DEMO.TRAINING_DATA),
    (SELECT OBJECT_CONSTRUCT(
        'accuracy', ROUND(AVG(correct) * 100, 1),
        'total_predictions', COUNT(*),
        'correct_predictions', SUM(correct),
        'true_positives', SUM(CASE WHEN actual = 1 AND predicted = 1 THEN 1 ELSE 0 END),
        'true_negatives', SUM(CASE WHEN actual = 0 AND predicted = 0 THEN 1 ELSE 0 END),
        'false_positives', SUM(CASE WHEN actual = 0 AND predicted = 1 THEN 1 ELSE 0 END),
        'false_negatives', SUM(CASE WHEN actual = 1 AND predicted = 0 THEN 1 ELSE 0 END)
    ) FROM LIFEARC_POC.ML_DEMO.TEST_RESULTS),
    'PRODUCTION';

-- View registered model
SELECT 
    model_name,
    model_version,
    model_type,
    status,
    training_rows,
    metrics:"accuracy"::FLOAT AS accuracy,
    created_by,
    created_at
FROM LIFEARC_POC.ML_DEMO.MODEL_REGISTRY;

-- ============================================================================
-- STEP 5: BATCH INFERENCE
-- Score new compounds for drug-likeness
-- ============================================================================

-- Create inference view for new compounds
CREATE OR REPLACE VIEW LIFEARC_POC.ML_DEMO.COMPOUND_PREDICTIONS AS
SELECT 
    f.compound_id,
    f.compound_name,
    f.therapeutic_area,
    f.target_gene,
    f.molecular_weight,
    f.logp,
    f.tpsa,
    f.hydrogen_bond_donors,
    f.hydrogen_bond_acceptors,
    f.drug_likeness AS actual_drug_likeness,
    f.is_drug_like AS actual_label,
    drug_likeness_model!PREDICT(
        INPUT_DATA => OBJECT_CONSTRUCT(
            'MOLECULAR_WEIGHT', f.molecular_weight,
            'LOGP', f.logp,
            'TPSA', f.tpsa,
            'HYDROGEN_BOND_DONORS', f.hydrogen_bond_donors,
            'HYDROGEN_BOND_ACCEPTORS', f.hydrogen_bond_acceptors,
            'MW_COMPLIANT', f.mw_compliant,
            'LOGP_COMPLIANT', f.logp_compliant,
            'HBD_COMPLIANT', f.hbd_compliant,
            'HBA_COMPLIANT', f.hba_compliant
        )
    ):"probability"."1"::FLOAT AS predicted_drug_like_prob,
    CASE 
        WHEN drug_likeness_model!PREDICT(
            INPUT_DATA => OBJECT_CONSTRUCT(
                'MOLECULAR_WEIGHT', f.molecular_weight,
                'LOGP', f.logp,
                'TPSA', f.tpsa,
                'HYDROGEN_BOND_DONORS', f.hydrogen_bond_donors,
                'HYDROGEN_BOND_ACCEPTORS', f.hydrogen_bond_acceptors,
                'MW_COMPLIANT', f.mw_compliant,
                'LOGP_COMPLIANT', f.logp_compliant,
                'HBD_COMPLIANT', f.hbd_compliant,
                'HBA_COMPLIANT', f.hba_compliant
            )
        ):"probability"."1"::FLOAT >= 0.5 THEN 'Likely Drug-Like'
        ELSE 'Likely Non-Drug-Like'
    END AS prediction
FROM LIFEARC_POC.ML_DEMO.DRUG_LIKENESS_FEATURES f;

-- View predictions
SELECT 
    compound_name,
    therapeutic_area,
    molecular_weight,
    logp,
    actual_drug_likeness,
    ROUND(predicted_drug_like_prob * 100, 1) AS drug_like_probability_pct,
    prediction
FROM LIFEARC_POC.ML_DEMO.COMPOUND_PREDICTIONS
ORDER BY predicted_drug_like_prob DESC;

-- ============================================================================
-- STEP 6: FEATURE IMPORTANCE (EXPLAIN)
-- Understand what drives predictions
-- ============================================================================

-- Get feature importance from model explanation
SELECT drug_likeness_model!EXPLAIN_FEATURE_IMPORTANCE() AS feature_importance;

-- ============================================================================
-- STEP 7: MODEL MONITORING
-- Track prediction distribution over time
-- ============================================================================

CREATE OR REPLACE TABLE LIFEARC_POC.ML_DEMO.PREDICTION_MONITORING (
    monitoring_id VARCHAR DEFAULT UUID_STRING(),
    model_name VARCHAR,
    model_version VARCHAR,
    prediction_date DATE,
    total_predictions INT,
    positive_predictions INT,
    negative_predictions INT,
    avg_probability FLOAT,
    created_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

-- Log today's predictions
INSERT INTO LIFEARC_POC.ML_DEMO.PREDICTION_MONITORING
(model_name, model_version, prediction_date, total_predictions, positive_predictions, negative_predictions, avg_probability)
SELECT 
    'drug_likeness_model',
    'v1.0',
    CURRENT_DATE(),
    COUNT(*),
    SUM(CASE WHEN prediction = 'Likely Drug-Like' THEN 1 ELSE 0 END),
    SUM(CASE WHEN prediction = 'Likely Non-Drug-Like' THEN 1 ELSE 0 END),
    ROUND(AVG(predicted_drug_like_prob), 3)
FROM LIFEARC_POC.ML_DEMO.COMPOUND_PREDICTIONS;

-- View monitoring data
SELECT * FROM LIFEARC_POC.ML_DEMO.PREDICTION_MONITORING;

-- ============================================================================
-- SUMMARY: ML Pipeline Objects Created
-- ============================================================================
/*
Objects created:

TABLES:
- ML_DEMO.DRUG_LIKENESS_FEATURES    - Feature store with engineered features
- ML_DEMO.TEST_PREDICTIONS          - Test set with predictions
- ML_DEMO.MODEL_REGISTRY            - Model metadata and versioning
- ML_DEMO.PREDICTION_MONITORING     - Prediction drift monitoring

VIEWS:
- ML_DEMO.TRAINING_DATA             - 80% split for training
- ML_DEMO.TEST_DATA                 - 20% split for testing
- ML_DEMO.TEST_RESULTS              - Test metrics calculation
- ML_DEMO.COMPOUND_PREDICTIONS      - Live inference view

MODELS:
- ML_DEMO.DRUG_LIKENESS_MODEL       - Snowflake ML Classification model

This demonstrates:
1. Feature Engineering     - Derived features from molecular properties
2. Model Training          - Snowflake ML Classification
3. Model Evaluation        - Accuracy, confusion matrix
4. Model Registry          - Version control, metadata
5. Batch Inference         - Predict on all compounds
6. Feature Importance      - Explainability
7. Model Monitoring        - Track prediction distribution
*/
