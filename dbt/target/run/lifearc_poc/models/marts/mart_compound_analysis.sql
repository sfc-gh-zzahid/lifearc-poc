
  
    

create or replace transient table LIFEARC_POC.PUBLIC_gold.mart_compound_analysis
    
    
    
    as (-- Mart model: Compound Library Summary (Gold layer)
-- Purpose: Analytics-ready compound analysis metrics



SELECT
    -- Drug-likeness category
    drug_likeness,
    predicted_absorption,
    bbb_penetration,
    
    -- Counts
    COUNT(*) AS compound_count,
    
    -- Property averages
    ROUND(AVG(logp), 2) AS avg_logp,
    ROUND(AVG(tpsa), 2) AS avg_tpsa,
    ROUND(AVG(rotatable_bonds), 1) AS avg_rotatable_bonds,
    ROUND(AVG(h_bond_donors), 1) AS avg_h_bond_donors,
    ROUND(AVG(h_bond_acceptors), 1) AS avg_h_bond_acceptors,
    
    -- Data completeness
    ROUND(AVG(CASE WHEN has_smiles THEN 1 ELSE 0 END) * 100, 1) AS pct_with_smiles,
    ROUND(AVG(CASE WHEN has_mol_block THEN 1 ELSE 0 END) * 100, 1) AS pct_with_mol_block,
    
    -- Lipinski violations distribution
    ROUND(AVG(lipinski_violations), 2) AS avg_lipinski_violations,
    SUM(CASE WHEN lipinski_violations = 0 THEN 1 ELSE 0 END) AS ro5_compliant_count,
    
    CURRENT_TIMESTAMP() AS _dbt_loaded_at

FROM LIFEARC_POC.PUBLIC_silver.int_compound_properties
GROUP BY drug_likeness, predicted_absorption, bbb_penetration
    )
;


  