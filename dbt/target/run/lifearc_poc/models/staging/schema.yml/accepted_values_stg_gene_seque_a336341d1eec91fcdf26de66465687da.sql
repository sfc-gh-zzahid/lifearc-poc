
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  
    
    

with all_values as (

    select
        data_quality_flag as value_field,
        count(*) as n_records

    from LIFEARC_POC.PUBLIC_bronze.stg_gene_sequences
    group by data_quality_flag

)

select *
from all_values
where value_field not in (
    'too_short','minimal','adequate','good'
)



  
  
      
    ) dbt_internal_test