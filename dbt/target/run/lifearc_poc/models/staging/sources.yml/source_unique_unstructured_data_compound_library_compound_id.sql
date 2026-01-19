
    select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
  
    
    

select
    compound_id as unique_field,
    count(*) as n_records

from LIFEARC_POC.UNSTRUCTURED_DATA.compound_library
where compound_id is not null
group by compound_id
having count(*) > 1



  
  
      
    ) dbt_internal_test