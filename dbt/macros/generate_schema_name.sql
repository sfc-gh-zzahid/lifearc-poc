-- LifeArc POC - Custom Schema Naming Macro
-- This macro generates schema names with a prefix based on the layer
-- Example: PUBLIC_bronze, PUBLIC_silver, PUBLIC_gold

{% macro generate_schema_name(custom_schema_name, node) -%}
    {%- set default_schema = target.schema -%}
    {%- if custom_schema_name is none -%}
        {{ default_schema }}
    {%- else -%}
        {{ default_schema }}_{{ custom_schema_name }}
    {%- endif -%}
{%- endmacro %}
