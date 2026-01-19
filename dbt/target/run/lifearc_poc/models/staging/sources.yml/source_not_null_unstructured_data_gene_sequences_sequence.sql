
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  
    
    



select sequence
from LIFEARC_POC.UNSTRUCTURED_DATA.gene_sequences
where sequence is null



  
  
      
    ) dbt_internal_test