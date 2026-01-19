-- LifeArc POC - Data Quality Macros

-- Test that a column has no future dates
{% macro test_no_future_dates(model, column_name) %}
    SELECT *
    FROM {{ model }}
    WHERE {{ column_name }} > CURRENT_TIMESTAMP()
{% endmacro %}

-- Test referential integrity between tables
{% macro test_referential_integrity(model, column_name, parent_model, parent_column) %}
    SELECT child.*
    FROM {{ model }} child
    LEFT JOIN {{ parent_model }} parent
        ON child.{{ column_name }} = parent.{{ parent_column }}
    WHERE parent.{{ parent_column }} IS NULL
      AND child.{{ column_name }} IS NOT NULL
{% endmacro %}

-- Test that numeric values are within expected range
{% macro test_value_in_range(model, column_name, min_value, max_value) %}
    SELECT *
    FROM {{ model }}
    WHERE {{ column_name }} < {{ min_value }}
       OR {{ column_name }} > {{ max_value }}
{% endmacro %}
