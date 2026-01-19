-- Test: Ensure clinical trial efficacy has positive patient counts
-- All trials should have at least one patient enrolled

SELECT *
FROM {{ ref('mart_trial_efficacy') }}
WHERE total_patients <= 0
   OR total_patients IS NULL
