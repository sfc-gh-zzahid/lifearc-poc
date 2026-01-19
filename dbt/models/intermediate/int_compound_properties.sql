-- Intermediate model: Compound Properties Analysis (Silver layer)
-- Purpose: Enrich compound data with drug-likeness assessments

{{ config(
    materialized='table',
    tags=['silver', 'chemistry']
) }}

SELECT
    compound_id,
    molecule_name,
    smiles,
    has_smiles,
    has_mol_block,
    has_properties,
    logp,
    tpsa,
    rotatable_bonds,
    h_bond_donors,
    h_bond_acceptors,
    lipinski_violations,
    created_at,
    -- Lipinski's Rule of Five assessment
    CASE 
        WHEN logp <= 5 
         AND tpsa <= 140 
         AND h_bond_donors <= 5 
         AND h_bond_acceptors <= 10 
         AND lipinski_violations = 0 
        THEN 'drug_like'
        WHEN lipinski_violations <= 1 
        THEN 'borderline'
        ELSE 'non_drug_like'
    END AS drug_likeness,
    -- Absorption estimation (simplified)
    CASE 
        WHEN tpsa < 60 THEN 'high'
        WHEN tpsa <= 140 THEN 'moderate'
        ELSE 'low'
    END AS predicted_absorption,
    -- BBB penetration estimate
    CASE 
        WHEN tpsa < 90 AND logp BETWEEN 1 AND 3 THEN 'likely'
        ELSE 'unlikely'
    END AS bbb_penetration,
    -- Current timestamp
    CURRENT_TIMESTAMP() AS _dbt_loaded_at
FROM {{ ref('stg_compounds') }}
