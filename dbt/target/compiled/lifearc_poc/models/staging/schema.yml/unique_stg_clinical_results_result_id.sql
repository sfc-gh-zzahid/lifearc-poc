
    
    

select
    result_id as unique_field,
    count(*) as n_records

from LIFEARC_POC.PUBLIC_bronze.stg_clinical_results
where result_id is not null
group by result_id
having count(*) > 1


