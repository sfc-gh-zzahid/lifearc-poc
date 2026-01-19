
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  
    
    



select sequence_id
from LIFEARC_POC.PUBLIC_bronze.stg_gene_sequences
where sequence_id is null



  
  
      
    ) dbt_internal_test