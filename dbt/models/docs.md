{% docs __overview__ %}
# LifeArc POC - Data Pipeline Documentation

Welcome to the LifeArc Proof of Concept data pipeline documentation.

## Architecture

This dbt project implements a **Bronze → Silver → Gold** medallion architecture:

| Layer | Schema | Purpose | Materialization |
|-------|--------|---------|-----------------|
| **Bronze** | `PUBLIC_bronze` | Raw data staging, light cleaning | Views |
| **Silver** | `PUBLIC_silver` | Business logic, enrichment | Tables |
| **Gold** | `PUBLIC_gold` | Analytics-ready aggregations | Tables |

## Data Domains

### Compound Library
Molecular structures from LifeArc's drug discovery screening library.
- SMILES notation for computational chemistry
- Drug-likeness assessments (Lipinski's Rule of Five)
- Molecular properties (LogP, TPSA, H-bond donors/acceptors)

### Clinical Trials
Clinical trial data including outcomes and efficacy metrics.
- Trial phases and status tracking
- Patient enrollment and completion rates
- Efficacy measurements and response rates

### Gene Sequences
Genomic sequence data for research analysis.
- DNA/RNA sequence information
- Gene annotations and metadata
- Sequence quality metrics

## Getting Started

```bash
# Run all models and tests
dbt build

# Generate documentation
dbt docs generate
dbt docs serve
```

{% enddocs %}

{% docs stg_compounds %}
## Compound Library Staging Model

**Source:** `UNSTRUCTURED_DATA.COMPOUND_LIBRARY`  
**Layer:** Bronze (Staging)  
**Materialization:** View

### Business Context
Contains molecular structures from LifeArc's compound screening library used in drug discovery research. Each compound includes:
- Chemical structure in SMILES notation
- Molecular block (3D structure) data
- Calculated molecular properties

### Key Transformations
- Trims whitespace from text fields
- Extracts molecular properties from JSON
- Adds data quality flags for completeness checks

### Downstream Usage
- `int_compound_properties` - Drug-likeness enrichment
- `mart_compound_analysis` - Analytics aggregations
{% enddocs %}

{% docs stg_clinical_results %}
## Clinical Results Staging Model

**Source:** `DATA_SHARING.CLINICAL_TRIAL_RESULTS`  
**Layer:** Bronze (Staging)  
**Materialization:** View

### Business Context
Clinical trial outcome measurements from patient studies. Each record represents a single measurement for a patient in a trial.

### Key Fields
- `result_id` - Unique measurement identifier
- `trial_id` - Link to parent clinical trial
- `patient_id` - Anonymized patient identifier
- `measurement_type` - Type of efficacy measurement
- `measurement_value` - Numeric outcome value
{% enddocs %}

{% docs stg_gene_sequences %}
## Gene Sequences Staging Model

**Source:** `UNSTRUCTURED_DATA.GENE_SEQUENCES`  
**Layer:** Bronze (Staging)  
**Materialization:** View

### Business Context
Genomic sequence data including DNA, RNA, and protein sequences for research analysis.

### Key Fields
- `sequence_id` - Unique identifier
- `gene_name` - Gene symbol/name
- `sequence_type` - DNA, RNA, PROTEIN, etc.
- `sequence` - Actual nucleotide/amino acid sequence
{% enddocs %}

{% docs int_compound_properties %}
## Compound Properties Intermediate Model

**Layer:** Silver (Intermediate)  
**Materialization:** Table

### Business Context
Enriches compound data with drug-likeness assessments based on Lipinski's Rule of Five and other pharmaceutical guidelines.

### Key Calculations
- **Drug Likeness Classification:**
  - `drug_like` - Passes Rule of Five
  - `borderline` - 1 violation
  - `non_drug_like` - Multiple violations

- **Predicted Absorption:**
  - Based on Topological Polar Surface Area (TPSA)
  - High: TPSA < 60
  - Moderate: 60 ≤ TPSA ≤ 140
  - Low: TPSA > 140

- **BBB Penetration:**
  - Blood-brain barrier crossing prediction
  - Based on TPSA < 90 and LogP between 1-3
{% enddocs %}

{% docs mart_compound_analysis %}
## Compound Analysis Mart

**Layer:** Gold (Mart)  
**Materialization:** Table

### Business Context
Analytics-ready summary of compound library by drug-likeness category. Used for portfolio analysis and screening prioritization.

### Key Metrics
- `compound_count` - Number of compounds per category
- `avg_logp` - Average partition coefficient
- `pct_with_smiles` - Data completeness metric
- `ro5_compliant_count` - Rule of Five compliance
{% enddocs %}

{% docs mart_trial_efficacy %}
## Trial Efficacy Mart

**Layer:** Gold (Mart)  
**Materialization:** Table

### Business Context
Clinical trial performance summary for executive dashboards and portfolio reviews.

### Key Metrics
- `total_patients` - Enrolled patient count
- `avg_efficacy_score` - Mean treatment response
- `response_rate` - Percentage of positive outcomes
{% enddocs %}

{% docs mart_gene_analysis %}
## Gene Analysis Mart

**Layer:** Gold (Mart)  
**Materialization:** Table

### Business Context
Gene sequence analytics for research prioritization and target identification.

### Key Metrics
- Sequence counts by type
- Average sequence lengths
- Quality score distributions
{% enddocs %}
