
  create or replace   view LIFEARC_POC.PUBLIC_bronze.stg_clinical_results
  
  
  
  
  as (
    -- Staging model: Clinical Trial Results (Bronze layer)
-- Purpose: Clean and standardize raw clinical trial result data



SELECT
    result_id,
    trial_id,
    patient_id,
    site_id,
    TRIM(UPPER(cohort)) AS cohort,
    TRIM(UPPER(treatment_arm)) AS treatment_arm,
    TRIM(INITCAP(REPLACE(response_category, '_', ' '))) AS response_category,
    pfs_months,
    os_months,
    adverse_events,
    biomarker_status,
    patient_age,
    patient_sex,
    created_at,
    -- Derived fields
    CASE 
        WHEN response_category ILIKE '%complete%' THEN 'CR'
        WHEN response_category ILIKE '%partial%' THEN 'PR'
        WHEN response_category ILIKE '%stable%' THEN 'SD'
        WHEN response_category ILIKE '%progressive%' THEN 'PD'
        ELSE 'UNKNOWN'
    END AS response_code,
    CASE 
        WHEN adverse_events ILIKE '%grade3%' OR adverse_events ILIKE '%grade4%' THEN 'severe'
        WHEN adverse_events ILIKE '%grade2%' THEN 'moderate'
        WHEN adverse_events ILIKE '%grade1%' THEN 'mild'
        ELSE 'none'
    END AS adverse_severity,
    -- Age grouping (for anonymization)
    FLOOR(patient_age / 10) * 10 AS age_decade,
    -- Data quality
    CASE WHEN pfs_months IS NOT NULL AND os_months IS NOT NULL THEN TRUE ELSE FALSE END AS has_survival_data
FROM LIFEARC_POC.DATA_SHARING.clinical_trial_results
WHERE result_id IS NOT NULL
  );

