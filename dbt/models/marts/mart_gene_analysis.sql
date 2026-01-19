-- Mart model: Gene Analysis Summary (Gold layer)
-- Purpose: Analytics-ready gene sequence metrics

{{ config(
    materialized='table',
    tags=['gold', 'analytics']
) }}

SELECT
    gene_name,
    organism,
    COUNT(*) AS sequence_count,
    
    -- Sequence metrics
    ROUND(AVG(sequence_length), 0) AS avg_sequence_length,
    MIN(sequence_length) AS min_sequence_length,
    MAX(sequence_length) AS max_sequence_length,
    
    -- GC content analysis
    ROUND(AVG(gc_content), 2) AS avg_gc_content,
    ROUND(MIN(gc_content), 2) AS min_gc_content,
    ROUND(MAX(gc_content), 2) AS max_gc_content,
    
    -- Quality distribution
    SUM(CASE WHEN data_quality_flag = 'good' THEN 1 ELSE 0 END) AS good_quality_count,
    SUM(CASE WHEN data_quality_flag = 'adequate' THEN 1 ELSE 0 END) AS adequate_quality_count,
    SUM(CASE WHEN data_quality_flag = 'minimal' THEN 1 ELSE 0 END) AS minimal_quality_count,
    SUM(CASE WHEN data_quality_flag = 'too_short' THEN 1 ELSE 0 END) AS short_quality_count,
    
    -- Data quality percentage
    ROUND(AVG(CASE WHEN length_valid THEN 1 ELSE 0 END) * 100, 1) AS length_validation_rate,
    
    -- Latest upload
    MAX(created_at) AS last_upload,
    
    CURRENT_TIMESTAMP() AS _dbt_loaded_at

FROM {{ ref('stg_gene_sequences') }}
GROUP BY gene_name, organism
