
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  
    
    



select result_id
from LIFEARC_POC.PUBLIC_bronze.stg_clinical_results
where result_id is null



  
  
      
    ) dbt_internal_test