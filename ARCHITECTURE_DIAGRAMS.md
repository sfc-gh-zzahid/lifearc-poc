# LifeArc POC - Architecture Diagrams

## 1. Overall Solution Architecture

```mermaid
flowchart LR
    subgraph Sources["🔗 External Sources"]
        direction TB
        GH[("GitHub\nDBT Code")]
        LAB[("Lab Systems\nClinical Data")]
        DOCS[("Documents\nResearch PDFs")]
    end

    subgraph Snowflake["❄️ SNOWFLAKE - Single Platform"]
        subgraph Ingestion["📥 Ingestion"]
            direction TB
            GIT["Git Repository"]
            STAGE["Internal Stages"]
        end

        subgraph Storage["💾 Medallion Storage"]
            direction TB
            BRONZE["🥉 Bronze"]
            SILVER["🥈 Silver"]
            GOLD["🥇 Gold"]
        end

        subgraph Intelligence["🧠 AI/ML (Data Stays Here)"]
            direction TB
            CORTEX["Cortex LLM\n+ Search"]
            MLPIPE["Snowflake ML"]
        end

        subgraph Governance["🔒 Governance"]
            direction TB
            TAGS["Tags + Policies"]
        end
    end

    subgraph Consumption["👥 Consumption"]
        direction TB
        APPS["📊 Streamlit Apps\n3 Deployed"]
        SHARE["🤝 Zero-Copy Share\nLIFEARC_CRO_SHARE"]
    end

    subgraph Users["🎯 Business Value"]
        direction TB
        EXEC["Executives\nData-Driven Decisions"]
        CRO["CRO Partners\nLive Collaboration"]
    end

    GH --> GIT
    LAB --> STAGE
    DOCS --> STAGE
    
    GIT --> BRONZE
    STAGE --> BRONZE
    BRONZE --> SILVER --> GOLD
    
    GOLD --> CORTEX
    GOLD --> MLPIPE
    GOLD --> TAGS
    
    CORTEX --> APPS
    MLPIPE --> APPS
    TAGS --> SHARE
    
    APPS --> EXEC
    SHARE -.->|"Zero-Copy\nReal-Time\nGoverned"| CRO

    style Snowflake fill:#29B5E8,color:#fff
    style Intelligence fill:#FF6B35,color:#fff
    style Governance fill:#2E8B57,color:#fff
```

**Key Message:** Everything runs in ONE platform. Data never leaves. AI is HIPAA-safe.

---

## 2. Medallion Architecture (DBT Pipeline)

```mermaid
flowchart LR
    subgraph Sources["Source Systems"]
        S1[("Clinical Data")]
        S2[("Compound Library")]
        S3[("Gene Sequences")]
    end

    subgraph Bronze["Bronze Layer (Staging)"]
        direction TB
        STG1["stg_clinical_results"]
        STG2["stg_compounds"]
        STG3["stg_gene_sequences"]
        SEED1["clinical_trial_phases"]
        SEED2["drug_likeness_thresholds"]
        SEED3["gene_types"]
    end

    subgraph Silver["Silver Layer (Intermediate)"]
        direction TB
        INT1["int_compound_properties\n• Lipinski calculations\n• Drug-likeness scoring"]
        INT2["int_trial_patient_outcomes\n• Response aggregation\n• Cohort analysis"]
    end

    subgraph Gold["Gold Layer (Marts)"]
        direction TB
        MART1["mart_compound_analysis\n• Pipeline health\n• Success predictions"]
        MART2["mart_trial_efficacy\n• Response rates\n• PFS/OS metrics"]
        MART3["mart_gene_analysis\n• GC content\n• Sequence metrics"]
    end

    subgraph Consumers["Data Consumers"]
        BI["BI Dashboards"]
        ML["ML Models"]
        ANALYST["Cortex Analyst"]
    end

    S1 --> STG1
    S2 --> STG2
    S3 --> STG3

    STG1 --> INT2
    STG2 --> INT1
    STG3 --> MART3

    SEED1 --> INT2
    SEED2 --> INT1
    SEED3 --> MART3

    INT1 --> MART1
    INT2 --> MART2

    MART1 --> BI
    MART2 --> ML
    MART3 --> ANALYST

    style Bronze fill:#CD7F32,color:#fff
    style Silver fill:#C0C0C0,color:#000
    style Gold fill:#FFD700,color:#000
```

---

## 3. Snowflake Intelligence Architecture

```mermaid
flowchart LR
    subgraph User["💬 User Question"]
        Q["'Why are CNS\ncompounds failing?'"]
    end

    subgraph Cortex["🧠 Cortex AI Engine"]
        direction TB
        LLM["LLM Interprets\nIntent"]
        SQLGEN["SQL Generation"]
    end

    subgraph Semantic["📊 Semantic Layer"]
        SV["Semantic View\nDefines Schema"]
        subgraph Tables["5 Logical Tables"]
            direction TB
            T1["compounds\n(29 rows)"]
            T2["trials\n(17 rows)"]
            T3["programs\n(9 rows)"]
        end
    end

    subgraph Data["💾 Query Execution"]
        direction TB
        PT1[("COMPOUND_PIPELINE\nANALYSIS")]
        PT2[("CLINICAL_TRIAL\nPERFORMANCE")]
        PT3[("PROGRAM_ROI\nSUMMARY")]
    end

    subgraph Answer["✅ Business Insight"]
        A["CNS: LogP=6.6\n(too hydrophobic)\n\nAction: Adjust\nchemistry guidelines"]
    end

    Q --> LLM
    LLM --> SQLGEN
    SQLGEN --> SV
    SV --> Tables
    Tables --> PT1
    Tables --> PT2
    Tables --> PT3
    PT1 --> A
    PT2 --> A
    PT3 --> A

    style Cortex fill:#29B5E8,color:#fff
    style Semantic fill:#FF6B35,color:#fff
    style Answer fill:#28A745,color:#fff
```

**Key Message:** Natural language → SQL → Data-backed answer. PHI never leaves Snowflake.

---

## 4. ML Pipeline Architecture

```mermaid
flowchart LR
    subgraph FeatureEng["1. Feature Engineering"]
        RAW[("Raw Compound Data")]
        FE["Feature Extraction\n• Molecular weight\n• LogP\n• TPSA\n• H-bond donors/acceptors"]
        FS[("Feature Store\nDRUG_LIKENESS_FEATURES")]
    end

    subgraph Training["2. Model Training"]
        TRAIN["Training Data\n(80% split)"]
        TEST["Test Data\n(20% split)"]
        SFML["Snowflake ML\nCLASSIFICATION"]
    end

    subgraph Registry["3. Model Registry"]
        REG[("MODEL_REGISTRY\n• Version control\n• Metrics\n• Lineage")]
        MODEL["DRUG_LIKENESS_MODEL\nv1.0 PRODUCTION"]
    end

    subgraph Inference["4. Batch Inference"]
        INF["COMPOUND_PREDICTIONS\nView"]
        PRED["Predictions\n• Drug-like probability\n• Classification"]
    end

    subgraph Monitor["5. Monitoring"]
        MON[("PREDICTION_MONITORING\n• Drift detection\n• Distribution tracking")]
    end

    RAW --> FE
    FE --> FS
    FS --> TRAIN
    FS --> TEST
    TRAIN --> SFML
    TEST --> SFML
    SFML --> MODEL
    MODEL --> REG
    MODEL --> INF
    FS --> INF
    INF --> PRED
    PRED --> MON

    style FeatureEng fill:#7B68EE,color:#fff
    style Training fill:#4169E1,color:#fff
    style Registry fill:#32CD32,color:#fff
    style Inference fill:#FF8C00,color:#fff
    style Monitor fill:#DC143C,color:#fff
```

---

## 5. Secure Data Sharing Architecture (Snowflake-Unique)

```mermaid
flowchart LR
    subgraph Source["📊 Source Data"]
        TRIALS[("Clinical Trial\nResults\n10,000+ rows")]
    end

    subgraph Governance["🔒 Governance"]
        direction TB
        MASK["Masking\nPolicies"]
        RAP["Row Access\nPolicies"]
    end

    subgraph Share["🤝 Secure Share"]
        SHARE["LIFEARC_CRO_SHARE"]
        VIEW["Partner View\nMasked & Filtered"]
    end

    subgraph Partners["👥 CRO Partners"]
        direction TB
        CRO1["Partner A\nSnowflake Account"]
        CRO2["Partner B\nSnowflake Account"]
        DB1[("Shared DB\nRead-only")]
        DB2[("Shared DB\nRead-only")]
    end

    subgraph Competitor["❌ Competitor Approach"]
        direction TB
        COPY["Data Copy"]
        ETL["ETL Pipeline"]
        STALE["Stale Data"]
        RISK["Security Risk"]
    end

    TRIALS --> MASK
    TRIALS --> RAP
    MASK --> VIEW
    RAP --> VIEW
    VIEW --> SHARE
    
    SHARE -.->|"✓ Zero-Copy\n✓ Live Data\n✓ Governed"| CRO1
    SHARE -.->|"✓ Zero-Copy\n✓ Live Data\n✓ Governed"| CRO2
    
    CRO1 --> DB1
    CRO2 --> DB2
    
    COPY -->|"Databricks\nFabric"| ETL
    ETL --> STALE
    STALE --> RISK

    style Source fill:#FFC107,color:#000
    style Governance fill:#2E8B57,color:#fff
    style Share fill:#29B5E8,color:#fff
    style Partners fill:#28A745,color:#fff
    style Competitor fill:#DC3545,color:#fff
```

---

## 6. Data Governance Architecture

```mermaid
flowchart LR
    subgraph Classification["🏷️ Classification"]
        direction TB
        T1["DATA_CLASSIFICATION\nPHI • PII • CONFIDENTIAL"]
        T2["DATA_DOMAIN\nCLINICAL • GENOMICS • COMPOUND"]
        T3["RETENTION_PERIOD\n1_YEAR • 10_YEARS • INDEFINITE"]
        T4["PII_TYPE\nPATIENT_ID • AGE • DOB"]
        T5["DATA_SENSITIVITY\nPUBLIC → HIGHLY_CONFIDENTIAL"]
    end

    subgraph Protection["🛡️ Protection"]
        direction TB
        M1["MASK_PATIENT_ID\n→ SHA2 hash"]
        M2["MASK_AGE\n→ Age bands"]
        RAP["SITE_BASED_ACCESS\n→ Row filtering"]
    end

    subgraph Tables["💾 Protected Tables"]
        CTR[("CLINICAL_TRIAL_RESULTS\n• patient_id: MASKED\n• patient_age: MASKED\n• site_id: ROW FILTERED")]
    end

    subgraph Roles["👥 Role Hierarchy"]
        direction TB
        ADMIN["ACCOUNTADMIN\nFull Access"]
        ANALYST["DATA_ANALYST\nMasked View"]
        PARTNER["PARTNER_ROLE\nFiltered + Masked"]
    end

    subgraph Audit["📋 Audit"]
        direction TB
        LOG[("Access Log")]
        COMPLIANCE["HIPAA • GxP\n21 CFR Part 11"]
    end

    T1 --> M1
    T1 --> M2
    T4 --> M1
    T4 --> M2
    T2 --> RAP
    
    M1 --> CTR
    M2 --> CTR
    RAP --> CTR
    
    ADMIN -->|Full| CTR
    ANALYST -->|Masked| CTR
    PARTNER -->|Filtered| CTR
    
    CTR --> LOG
    LOG --> COMPLIANCE

    style Classification fill:#2E8B57,color:#fff
    style Protection fill:#4169E1,color:#fff
    style Tables fill:#FFC107,color:#000
    style Roles fill:#6F42C1,color:#fff
    style Audit fill:#8B4513,color:#fff
```

---

## 7. Unstructured Data Processing Architecture

```mermaid
flowchart LR
    subgraph Sources["📁 Life Sciences Files"]
        direction TB
        FASTA["FASTA Files\nGene Sequences"]
        JSON["JSON Files\nClinical Protocols"]
        PDF["Research PDFs\nPublications"]
    end

    subgraph Processing["⚙️ Snowflake Processing"]
        direction TB
        subgraph Native["Native Capabilities"]
            PARSE["PARSE_FASTA UDF\nPython UDTF"]
            VAR["VARIANT Type\nJSON path notation"]
        end
        subgraph Cortex["Cortex AI"]
            LLM["CORTEX.COMPLETE\nSummarize, Extract"]
            SEARCH["Cortex Search\nSemantic retrieval"]
        end
    end

    subgraph Output["📊 Queryable Data"]
        direction TB
        GENES[("35 Molecules\nGC Content, Length")]
        TRIALS[("Clinical Trials\nprotocol_data:field")]
        INTEL[("Research Intel\nC797S 42%, MET 28%")]
    end

    subgraph Query["🔍 SQL Queries"]
        SQL1["SELECT gc_content\nFROM compounds"]
        SQL2["SELECT protocol:arms\nFROM trials"]
        SQL3["'EGFR resistance'\nCortex Search"]
    end

    FASTA --> PARSE --> GENES
    JSON --> VAR --> TRIALS
    PDF --> LLM --> INTEL
    INTEL --> SEARCH
    
    GENES --> SQL1
    TRIALS --> SQL2
    SEARCH --> SQL3

    style Processing fill:#29B5E8,color:#fff
    style Cortex fill:#FF6B35,color:#fff
    style Output fill:#28A745,color:#fff
```

**Key Message:** Unstructured → Structured → SQL-queryable. All in Snowflake, no external tools.

---

## 8. Snowflake vs Competitors - Why It Matters for LifeArc

```mermaid
flowchart LR
    subgraph Challenge["🎯 LifeArc Challenge"]
        direction TB
        C1["Share trial data\nwith CROs securely"]
        C2["AI on PHI data\n(HIPAA compliance)"]
        C3["Audit trail for\nregulatory (GxP)"]
        C4["Cost control\n(variable workloads)"]
    end

    subgraph Snowflake["❄️ Snowflake Solution"]
        direction TB
        S1["✅ Zero-Copy Share\nNo data duplication"]
        S2["✅ Cortex AI\nData stays in platform"]
        S3["✅ Time Travel\n90 days default"]
        S4["✅ Per-Second Billing\nAuto-suspend"]
    end

    subgraph Databricks["🔶 Databricks Gap"]
        direction TB
        D1["❌ Delta Sharing\nrequires data copy"]
        D2["❌ External APIs\ndata leaves platform"]
        D3["⚠️ 30 days\nrequires config"]
        D4["❌ Per-hour billing\ncluster overhead"]
    end

    subgraph Fabric["🔷 Fabric Gap"]
        direction TB
        F1["❌ No cross-org\nsharing"]
        F2["❌ Azure OpenAI\ndata leaves warehouse"]
        F3["❌ No native\nTime Travel"]
        F4["❌ Capacity-based\nno auto-suspend"]
    end

    C1 --> S1
    C2 --> S2
    C3 --> S3
    C4 --> S4
    
    S1 -.-x D1
    S2 -.-x D2
    S3 -.-x D3
    S4 -.-x D4
    
    S1 -.-x F1
    S2 -.-x F2
    S3 -.-x F3
    S4 -.-x F4

    style Challenge fill:#6C757D,color:#fff
    style Snowflake fill:#29B5E8,color:#fff
    style Databricks fill:#FF3621,color:#fff
    style Fabric fill:#0078D4,color:#fff
```

**Key Message:** Snowflake solves LifeArc's specific challenges. Competitors have architectural gaps.

---

## 9. Demo Flow Sequence

```mermaid
sequenceDiagram
    participant User as VP of R&D
    participant App as Streamlit App
    participant SV as Semantic View
    participant Cortex as Cortex AI
    participant Data as Data Tables
    
    Note over User,Data: Scene 1: Executive Dashboard
    User->>App: "Show pipeline summary"
    App->>Data: Query EXECUTIVE_PIPELINE_SUMMARY
    Data-->>App: 29 compounds, $903M invested
    App-->>User: Display KPIs
    
    Note over User,Data: Scene 2: Discovery Analysis
    User->>App: "Why are compounds failing?"
    App->>SV: Parse question
    SV->>Cortex: Generate SQL
    Cortex->>Data: Query COMPOUND_PIPELINE_ANALYSIS
    Data-->>Cortex: CNS: 0% drug-like, LogP > 5
    Cortex-->>App: "LogP is the primary failure reason"
    App-->>User: Action: Adjust chemistry guidelines
    
    Note over User,Data: Scene 3: Research Intelligence
    User->>App: "Search EGFR resistance"
    App->>Cortex: Cortex Search
    Cortex->>Data: Semantic search RESEARCH_INTELLIGENCE
    Data-->>Cortex: C797S mutation (42%), MET bypass (28%)
    Cortex-->>App: Ranked documents with findings
    App-->>User: Action: Pivot EGFR program
    
    Note over User,Data: Scene 4: Board Priorities
    User->>App: "Top 3 candidates for board"
    App->>SV: Parse question
    SV->>Data: Query BOARD_CANDIDATE_SCORECARD
    Data-->>App: Priority 1-3 with rationale
    App-->>User: Olaparib-LA, OmoMYC-LA, Ceralasertib-LA
```

---

## 10. The 9 Snowflake Differentiators - Executive Summary

```mermaid
flowchart LR
    subgraph Differentiators["❄️ 9 SNOWFLAKE DIFFERENTIATORS"]
        direction TB
        subgraph DataMgmt["Data Management"]
            D1["1️⃣ Zero-Copy Sharing\nLIFEARC_CRO_SHARE"]
            D2["2️⃣ Instant Cloning\nDev/Test in seconds"]
            D3["3️⃣ Time Travel\n90 days audit trail"]
        end
        subgraph AI["AI/ML"]
            D4["4️⃣ Cortex AI\nHIPAA-safe LLMs"]
            D5["5️⃣ Cortex Search\nSemantic retrieval"]
            D6["6️⃣ Native ML\nData never leaves"]
        end
        subgraph Platform["Platform"]
            D7["7️⃣ SQL Governance\nTags queryable"]
            D8["8️⃣ Streamlit Apps\n3 deployed"]
            D9["9️⃣ Per-Second Billing\n4 resource monitors"]
        end
    end

    subgraph Validated["✅ POC VALIDATED"]
        direction TB
        V1["93% tests passed\n42/45 checks"]
        V2["5 'Why' questions\nanswered"]
        V3["3 Streamlit apps\ndeployed"]
    end

    subgraph Value["💰 BUSINESS VALUE"]
        direction TB
        B1["CRO Collaboration\nReal-time, governed"]
        B2["Regulatory Ready\nGxP, HIPAA, 21 CFR 11"]
        B3["Cost Optimized\nAuto-suspend, no copies"]
    end

    Differentiators --> Validated
    Validated --> Value

    style Differentiators fill:#29B5E8,color:#fff
    style Validated fill:#28A745,color:#fff
    style Value fill:#FFD700,color:#000
```

**Key Message:** 9 capabilities competitors cannot match → Validated in POC → Real business value for LifeArc.

---

## Usage

These diagrams are rendered using [Mermaid](https://mermaid.js.org/). To view:

1. **GitHub**: Diagrams render automatically in GitHub markdown
2. **Snowsight**: Copy to a markdown cell in a notebook
3. **VS Code**: Install "Markdown Preview Mermaid Support" extension
4. **Online**: Paste at [mermaid.live](https://mermaid.live)

---

## Key Architecture Decisions

| Decision | Rationale |
|----------|-----------|
| **Semantic View over YAML** | Native Snowflake, SQL-manageable, no external files |
| **Cortex over external LLMs** | PHI stays in Snowflake, HIPAA compliance |
| **Zero-copy sharing** | No data duplication, real-time, auditable |
| **Native DBT Project** | Git-synced, version-controlled, no external orchestrator |
| **Snowflake ML** | Data never leaves, integrated with governance |
| **Object tags** | SQL-queryable compliance, automatic policy enforcement |
