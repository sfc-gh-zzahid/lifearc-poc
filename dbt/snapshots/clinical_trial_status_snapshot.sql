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
SELECT 
    trial_id,
    title AS trial_title,
    phase,
    status,
    sponsor,
    indication,
    start_date,
    CURRENT_TIMESTAMP() AS _snapshot_check_time
FROM {{ source('unstructured_data', 'clinical_trials') }}

{% endsnapshot %}
