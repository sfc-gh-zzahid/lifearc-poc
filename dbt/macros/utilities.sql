-- LifeArc POC - Utility Macros

-- Convert cents to dollars with proper rounding
{% macro cents_to_dollars(column_name, precision=2) %}
    ROUND({{ column_name }} / 100.0, {{ precision }})
{% endmacro %}

-- Add standard audit columns to any model
{% macro audit_columns() %}
    CURRENT_TIMESTAMP() AS _loaded_at,
    '{{ invocation_id }}' AS _dbt_invocation_id
{% endmacro %}

-- Safe divide to avoid division by zero errors
{% macro safe_divide(numerator, denominator, default_value=0) %}
    CASE 
        WHEN {{ denominator }} = 0 OR {{ denominator }} IS NULL THEN {{ default_value }}
        ELSE {{ numerator }} / {{ denominator }}
    END
{% endmacro %}

-- Calculate percentage with null handling
{% macro calculate_percentage(part, whole, decimals=1) %}
    ROUND(
        {{ safe_divide(part ~ ' * 100.0', whole, 0) }},
        {{ decimals }}
    )
{% endmacro %}
