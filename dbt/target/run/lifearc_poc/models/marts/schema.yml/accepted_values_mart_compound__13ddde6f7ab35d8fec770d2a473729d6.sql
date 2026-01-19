
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  
    
    

with all_values as (

    select
        drug_likeness as value_field,
        count(*) as n_records

    from LIFEARC_POC.PUBLIC_gold.mart_compound_analysis
    group by drug_likeness

)

select *
from all_values
where value_field not in (
    'drug_like','borderline','non_drug_like'
)



  
  
      
    ) dbt_internal_test