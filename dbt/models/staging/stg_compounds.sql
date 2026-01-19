-- Staging model: Compound Library (Bronze layer)
-- Purpose: Clean and standardize raw compound data

{{ config(
    materialized='view',
    tags=['bronze', 'chemistry']
) }}

SELECT
    compound_id,
    TRIM(molecule_name) AS molecule_name,
    TRIM(smiles) AS smiles,
    mol_block,
    properties,
    created_at,
    -- Extract key properties from JSON
    properties:logP::FLOAT AS logp,
    properties:tpsa::FLOAT AS tpsa,
    properties:rotatable_bonds::INT AS rotatable_bonds,
    properties:num_h_donors::INT AS h_bond_donors,
    properties:num_h_acceptors::INT AS h_bond_acceptors,
    properties:lipinski_violations::INT AS lipinski_violations,
    -- Data quality flags
    CASE WHEN smiles IS NOT NULL THEN TRUE ELSE FALSE END AS has_smiles,
    CASE WHEN mol_block IS NOT NULL THEN TRUE ELSE FALSE END AS has_mol_block,
    CASE WHEN properties IS NOT NULL THEN TRUE ELSE FALSE END AS has_properties
FROM {{ source('unstructured_data', 'compound_library') }}
WHERE compound_id IS NOT NULL
