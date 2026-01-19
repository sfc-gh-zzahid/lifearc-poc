
    
    

select
    doc_id as unique_field,
    count(*) as n_records

from LIFEARC_POC.UNSTRUCTURED_DATA.research_documents
where doc_id is not null
group by doc_id
having count(*) > 1


