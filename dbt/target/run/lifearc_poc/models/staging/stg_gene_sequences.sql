
  create or replace   view LIFEARC_POC.PUBLIC_bronze.stg_gene_sequences
  
  
  
  
  as (
    -- Staging model: Gene Sequences (Bronze layer)
-- Purpose: Clean and standardize raw gene sequence data



SELECT
    sequence_id,
    TRIM(UPPER(gene_name)) AS gene_name,
    TRIM(UPPER(organism)) AS organism,
    UPPER(REPLACE(sequence, ' ', '')) AS sequence,  -- Remove any spaces
    sequence_length,
    ROUND(gc_content, 2) AS gc_content,
    created_at,
    description,
    -- Data quality flags
    CASE 
        WHEN sequence_length < 100 THEN 'too_short'
        WHEN sequence_length < 500 THEN 'minimal'
        WHEN sequence_length < 1000 THEN 'adequate'
        ELSE 'good'
    END AS data_quality_flag,
    -- Computed fields
    LENGTH(sequence) AS computed_length,
    CASE WHEN LENGTH(sequence) = sequence_length THEN TRUE ELSE FALSE END AS length_valid
FROM LIFEARC_POC.UNSTRUCTURED_DATA.gene_sequences
WHERE sequence IS NOT NULL
  AND sequence_id IS NOT NULL
  );

