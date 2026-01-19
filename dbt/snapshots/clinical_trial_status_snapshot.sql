-- Snapshot: Clinical Trial Status History (SCD Type 2)
-- Tracks changes to clinical trial status over time
-- Run with: dbt snapshot

{% snapshot clinical_trial_status_snapshot %}

{{
    config(
      target_schema='snapshots',
      unique_key='trial_id',
      strategy='check',
      check_cols=['status', 'phase', 'sponsor']
    )
}}

-- Track status changes for clinical trials
-- Extract fields from PROTOCOL_DATA JSON column
SELECT 
    trial_id,
    protocol_data:title::STRING AS trial_title,
    protocol_data:phase::STRING AS phase,
    protocol_data:status::STRING AS status,
    protocol_data:sponsor::STRING AS sponsor,
    protocol_data:indication::STRING AS indication,
    created_at,
    CURRENT_TIMESTAMP() AS _snapshot_check_time
FROM {{ source('unstructured_data', 'clinical_trials') }}

{% endsnapshot %}
