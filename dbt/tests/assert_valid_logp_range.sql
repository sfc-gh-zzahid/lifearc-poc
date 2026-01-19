-- Test: Ensure all compounds have valid molecular properties
-- Valid LogP range is typically -5 to 10 for drug candidates

SELECT 
    compound_id,
    molecule_name,
    logp
FROM {{ ref('stg_compounds') }}
WHERE logp IS NOT NULL
  AND (logp < -5 OR logp > 10)
