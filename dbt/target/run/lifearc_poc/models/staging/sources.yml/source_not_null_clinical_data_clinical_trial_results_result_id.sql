
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  
    
    



select result_id
from LIFEARC_POC.DATA_SHARING.clinical_trial_results
where result_id is null



  
  
      
    ) dbt_internal_test