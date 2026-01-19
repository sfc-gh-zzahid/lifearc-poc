
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  
    
    

with all_values as (

    select
        response_code as value_field,
        count(*) as n_records

    from LIFEARC_POC.PUBLIC_bronze.stg_clinical_results
    group by response_code

)

select *
from all_values
where value_field not in (
    'CR','PR','SD','PD','UNKNOWN'
)



  
  
      
    ) dbt_internal_test