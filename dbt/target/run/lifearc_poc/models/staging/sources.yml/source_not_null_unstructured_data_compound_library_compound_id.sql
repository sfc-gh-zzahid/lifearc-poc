
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  
    
    



select compound_id
from LIFEARC_POC.UNSTRUCTURED_DATA.compound_library
where compound_id is null



  
  
      
    ) dbt_internal_test