-- Test: Ensure no duplicate compound entries by molecule name
-- Each compound should have a unique molecule_name

SELECT 
    molecule_name,
    COUNT(*) AS duplicate_count
FROM {{ ref('stg_compounds') }}
WHERE molecule_name IS NOT NULL
GROUP BY molecule_name
HAVING COUNT(*) > 1
