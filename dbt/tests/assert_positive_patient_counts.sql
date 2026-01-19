-- Test: Ensure clinical trial efficacy has positive patient counts
-- All trials should have at least one patient enrolled

SELECT *
FROM {{ ref('mart_trial_efficacy') }}
WHERE patient_count <= 0
   OR patient_count IS NULL
