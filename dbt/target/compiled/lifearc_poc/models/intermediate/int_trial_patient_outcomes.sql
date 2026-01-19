-- Intermediate model: Trial Patient Outcomes (Silver layer)
-- Purpose: Join patient results with trial metadata for analysis



WITH clinical_results AS (
    SELECT * FROM LIFEARC_POC.PUBLIC_bronze.stg_clinical_results
),

trial_info AS (
    SELECT
        trial_id,
        protocol_data:title::VARCHAR AS trial_title,
        protocol_data:phase::VARCHAR AS trial_phase,
        protocol_data:indication::VARCHAR AS indication,
        protocol_data:sponsor::VARCHAR AS sponsor,
        protocol_data:status::VARCHAR AS trial_status,
        protocol_data:enrollment.target::INT AS target_enrollment,
        protocol_data:enrollment.current::INT AS current_enrollment
    FROM LIFEARC_POC.UNSTRUCTURED_DATA.clinical_trials
)

SELECT
    cr.result_id,
    cr.trial_id,
    ti.trial_title,
    ti.trial_phase,
    ti.indication,
    ti.sponsor,
    ti.trial_status,
    cr.patient_id,
    cr.site_id,
    cr.cohort,
    cr.treatment_arm,
    cr.response_category,
    cr.response_code,
    cr.pfs_months,
    cr.os_months,
    cr.adverse_events,
    cr.adverse_severity,
    cr.biomarker_status,
    cr.age_decade,
    cr.patient_sex,
    cr.created_at,
    -- Calculated metrics
    CASE 
        WHEN cr.response_code IN ('CR', 'PR') THEN 1 
        ELSE 0 
    END AS is_responder,
    CASE 
        WHEN cr.pfs_months >= 6 THEN 1 
        ELSE 0 
    END AS pfs_6month_flag,
    CASE 
        WHEN cr.os_months >= 12 THEN 1 
        ELSE 0 
    END AS os_12month_flag,
    -- Current timestamp for SCD
    CURRENT_TIMESTAMP() AS _dbt_loaded_at
FROM clinical_results cr
LEFT JOIN trial_info ti ON cr.trial_id = ti.trial_id