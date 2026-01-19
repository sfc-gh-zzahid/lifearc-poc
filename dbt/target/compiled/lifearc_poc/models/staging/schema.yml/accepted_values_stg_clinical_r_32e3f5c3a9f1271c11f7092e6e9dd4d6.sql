
    
    

with all_values as (

    select
        adverse_severity as value_field,
        count(*) as n_records

    from LIFEARC_POC.PUBLIC_bronze.stg_clinical_results
    group by adverse_severity

)

select *
from all_values
where value_field not in (
    'none','mild','moderate','severe'
)


