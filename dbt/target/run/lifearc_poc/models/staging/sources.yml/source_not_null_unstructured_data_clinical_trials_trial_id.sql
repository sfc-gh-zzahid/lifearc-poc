
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  
    
    



select trial_id
from LIFEARC_POC.UNSTRUCTURED_DATA.clinical_trials
where trial_id is null



  
  
      
    ) dbt_internal_test