# LifeArc POC - DBT Project

## Overview

This DBT project implements a Bronze → Silver → Gold data pipeline pattern for the LifeArc POC.

```
Bronze (Raw)         Silver (Cleaned)           Gold (Analytics)
─────────────       ─────────────────          ────────────────
stg_gene_sequences  int_trial_patient_outcomes mart_trial_efficacy
stg_compounds       int_compound_properties    mart_compound_analysis
stg_clinical_results                           mart_gene_analysis
```

## Directory Structure

```
dbt/
├── dbt_project.yml           # Project configuration
├── profiles.yml.example      # Sample connection profile
├── README.md                 # This file
├── models/
│   ├── staging/              # Bronze layer (raw → cleaned)
│   │   ├── sources.yml       # Source definitions
│   │   ├── schema.yml        # Model tests
│   │   ├── stg_gene_sequences.sql
│   │   ├── stg_compounds.sql
│   │   └── stg_clinical_results.sql
│   ├── intermediate/         # Silver layer (joined/enriched)
│   │   ├── int_trial_patient_outcomes.sql
│   │   └── int_compound_properties.sql
│   └── marts/                # Gold layer (analytics-ready)
│       ├── schema.yml
│       ├── mart_trial_efficacy.sql
│       ├── mart_compound_analysis.sql
│       └── mart_gene_analysis.sql
├── seeds/                    # Static reference data
├── tests/                    # Custom data tests
└── macros/                   # Reusable SQL macros
```

## Setup

### 1. Install DBT
```bash
pip install dbt-snowflake
```

### 2. Configure Connection
Copy `profiles.yml.example` to `~/.dbt/profiles.yml` and update with your credentials:

```yaml
lifearc_snowflake:
  target: dev
  outputs:
    dev:
      type: snowflake
      account: your_account
      user: your_user
      password: your_password
      role: ACCOUNTADMIN
      database: LIFEARC_POC
      warehouse: DEMO_WH
      schema: PUBLIC
```

### 3. Test Connection
```bash
cd dbt
dbt debug
```

## Usage

### Run All Models
```bash
dbt run
```

### Run by Layer
```bash
# Bronze only
dbt run --select tag:bronze

# Silver only
dbt run --select tag:silver

# Gold only
dbt run --select tag:gold
```

### Run Tests
```bash
dbt test
```

### Generate Documentation
```bash
dbt docs generate
dbt docs serve
```

### Build (run + test)
```bash
dbt build
```

## Data Flow

### Bronze Layer (Staging)
- **stg_gene_sequences**: Cleaned gene data with quality flags
- **stg_compounds**: Normalized compound data with extracted properties
- **stg_clinical_results**: Standardized clinical results with derived fields

### Silver Layer (Intermediate)
- **int_trial_patient_outcomes**: Patient results joined with trial metadata
- **int_compound_properties**: Compounds enriched with drug-likeness assessments

### Gold Layer (Marts)
- **mart_trial_efficacy**: Aggregated trial efficacy metrics (ORR, PFS, OS)
- **mart_compound_analysis**: Compound library analysis by drug-likeness
- **mart_gene_analysis**: Gene sequence summary metrics

## Target Schemas

| Layer | Schema | Description |
|-------|--------|-------------|
| Bronze | LIFEARC_POC.BRONZE | Raw cleaned data |
| Silver | LIFEARC_POC.SILVER | Joined/enriched data |
| Gold | LIFEARC_POC.GOLD | Analytics-ready aggregates |

## Tests Included

- Primary key uniqueness
- Not null constraints
- Accepted values for categorical fields
- Source freshness (optional)

## Adding New Models

1. Create SQL file in appropriate `models/` subdirectory
2. Add schema definition in `schema.yml`
3. Add source if new table in `sources.yml`
4. Run `dbt run --select new_model_name`
5. Test with `dbt test --select new_model_name`

## Version History

- **1.0.0** (2026-01-19): Initial release with bronze/silver/gold pipeline
