
  
    

create or replace transient table LIFEARC_POC.PUBLIC_gold.mart_trial_efficacy
    
    
    
    as (-- Mart model: Trial Efficacy Summary (Gold layer)
-- Purpose: Analytics-ready aggregated trial efficacy metrics



SELECT
    trial_id,
    trial_title,
    trial_phase,
    indication,
    sponsor,
    trial_status,
    treatment_arm,
    
    -- Patient counts
    COUNT(DISTINCT patient_id) AS patient_count,
    COUNT(DISTINCT site_id) AS site_count,
    
    -- Response metrics
    SUM(is_responder) AS responder_count,
    ROUND(AVG(is_responder) * 100, 1) AS objective_response_rate,
    
    -- Response breakdown
    SUM(CASE WHEN response_code = 'CR' THEN 1 ELSE 0 END) AS complete_response_count,
    SUM(CASE WHEN response_code = 'PR' THEN 1 ELSE 0 END) AS partial_response_count,
    SUM(CASE WHEN response_code = 'SD' THEN 1 ELSE 0 END) AS stable_disease_count,
    SUM(CASE WHEN response_code = 'PD' THEN 1 ELSE 0 END) AS progressive_disease_count,
    
    -- Survival metrics
    ROUND(AVG(pfs_months), 1) AS mean_pfs_months,
    ROUND(MEDIAN(pfs_months), 1) AS median_pfs_months,
    ROUND(AVG(os_months), 1) AS mean_os_months,
    ROUND(MEDIAN(os_months), 1) AS median_os_months,
    
    -- 6-month PFS rate
    ROUND(AVG(pfs_6month_flag) * 100, 1) AS pfs_6month_rate,
    
    -- 12-month OS rate
    ROUND(AVG(os_12month_flag) * 100, 1) AS os_12month_rate,
    
    -- Safety metrics
    SUM(CASE WHEN adverse_severity = 'severe' THEN 1 ELSE 0 END) AS severe_ae_count,
    ROUND(AVG(CASE WHEN adverse_severity = 'severe' THEN 1 ELSE 0 END) * 100, 1) AS severe_ae_rate,
    
    -- Demographics
    ROUND(AVG(age_decade), 0) AS mean_age_decade,
    ROUND(AVG(CASE WHEN patient_sex = 'F' THEN 1 ELSE 0 END) * 100, 1) AS female_pct,
    
    -- Timestamps
    MIN(created_at) AS first_result_at,
    MAX(created_at) AS last_result_at,
    CURRENT_TIMESTAMP() AS _dbt_loaded_at

FROM LIFEARC_POC.PUBLIC_silver.int_trial_patient_outcomes
GROUP BY 
    trial_id, trial_title, trial_phase, indication, 
    sponsor, trial_status, treatment_arm
    )
;


  