
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  
    
    



select gene_name
from LIFEARC_POC.PUBLIC_gold.mart_gene_analysis
where gene_name is null



  
  
      
    ) dbt_internal_test