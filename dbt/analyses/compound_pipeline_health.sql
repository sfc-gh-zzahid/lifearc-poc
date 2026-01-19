-- Analysis: Compound Pipeline Health Check
-- Run with: dbt run-operation compile --select analysis/compound_pipeline_health.sql
-- Or view in dbt docs

-- This analysis provides a quick health check of the compound pipeline

WITH source_counts AS (
    SELECT 
        'raw_compounds' AS layer,
        COUNT(*) AS record_count
    FROM {{ source('unstructured_data', 'compound_library') }}
    
    UNION ALL
    
    SELECT 
        'stg_compounds' AS layer,
        COUNT(*) AS record_count
    FROM {{ ref('stg_compounds') }}
    
    UNION ALL
    
    SELECT 
        'int_compound_properties' AS layer,
        COUNT(*) AS record_count  
    FROM {{ ref('int_compound_properties') }}
),

quality_metrics AS (
    SELECT
        'drug_like_compounds' AS metric,
        COUNT(*) AS value
    FROM {{ ref('int_compound_properties') }}
    WHERE drug_likeness = 'drug_like'
    
    UNION ALL
    
    SELECT
        'compounds_with_smiles' AS metric,
        COUNT(*) AS value
    FROM {{ ref('stg_compounds') }}
    WHERE has_smiles = TRUE
)

SELECT * FROM source_counts
UNION ALL
SELECT metric AS layer, value AS record_count FROM quality_metrics
ORDER BY layer
