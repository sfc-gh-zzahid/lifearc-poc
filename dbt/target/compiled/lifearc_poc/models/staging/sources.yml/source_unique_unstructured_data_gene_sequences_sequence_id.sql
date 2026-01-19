
    
    

select
    sequence_id as unique_field,
    count(*) as n_records

from LIFEARC_POC.UNSTRUCTURED_DATA.gene_sequences
where sequence_id is not null
group by sequence_id
having count(*) > 1


