
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  
    
    



select trial_id
from LIFEARC_POC.DATA_SHARING.clinical_trial_results
where trial_id is null



  
  
      
    ) dbt_internal_test