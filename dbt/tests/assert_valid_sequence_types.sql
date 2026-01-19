-- Test: Ensure gene sequences have valid organism values
-- Only allow recognized organisms

SELECT 
    sequence_id,
    gene_name,
    organism
FROM {{ ref('stg_gene_sequences') }}
WHERE organism IS NULL
   OR TRIM(organism) = ''
