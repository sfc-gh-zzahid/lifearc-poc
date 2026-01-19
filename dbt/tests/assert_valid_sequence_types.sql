-- Test: Ensure gene sequences have valid sequence types
-- Only allow recognized gene types

SELECT 
    sequence_id,
    gene_name,
    sequence_type
FROM {{ ref('stg_gene_sequences') }}
WHERE sequence_type NOT IN ('DNA', 'RNA', 'PROTEIN', 'cDNA', 'mRNA')
  AND sequence_type IS NOT NULL
