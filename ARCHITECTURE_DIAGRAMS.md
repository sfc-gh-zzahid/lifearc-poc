# LifeArc POC - Architecture Diagrams

## 1. Overall Solution Architecture

```mermaid
flowchart TB
    subgraph External["External Sources"]
        GH[("GitHub Repository")]
        CRO["CRO Partners"]
        DS["Data Scientists"]
        EXEC["Executives"]
    end

    subgraph Snowflake["Snowflake Platform"]
        subgraph Ingestion["Data Ingestion"]
            GIT["Git Repository\n(LIFEARC_GIT_REPO)"]
            DBT["Native DBT Project\n(VERSION$8)"]
        end

        subgraph DataLayers["Data Layers (Medallion)"]
            BRONZE["Bronze Layer\n(PUBLIC_BRONZE)"]
            SILVER["Silver Layer\n(PUBLIC_SILVER)"]
            GOLD["Gold Layer\n(PUBLIC_GOLD)"]
        end

        subgraph AIDemo["AI Demo Schema"]
            COMPOUND["Compound Pipeline\n(29 rows)"]
            TRIALS["Clinical Trials\n(17 rows)"]
            PROGRAMS["Program ROI\n(9 rows)"]
            RESEARCH["Research Intel\n(8 rows)"]
            BOARD["Board Scorecard\n(8 rows)"]
        end

        subgraph Intelligence["Snowflake Intelligence"]
            SV["Semantic View"]
            CORTEX["Cortex LLM"]
            SEARCH["Cortex Search"]
        end

        subgraph ML["ML Pipeline"]
            FEATURES["Feature Store"]
            MODEL["Classification Model"]
            REGISTRY["Model Registry"]
            INFERENCE["Inference View"]
        end

        subgraph Governance["Data Governance"]
            TAGS["Classification Tags\n(PHI/PII)"]
            MASK["Masking Policies"]
            RAP["Row Access Policies"]
        end

        subgraph Apps["Streamlit Apps"]
            APP1["Intelligence Demo"]
            APP2["Unstructured Data Demo"]
        end

        subgraph Sharing["Secure Data Sharing"]
            SHARE["LIFEARC_CRO_SHARE\n(Zero-Copy)"]
        end
    end

    GH -->|Sync| GIT
    GIT -->|Deploy| DBT
    DBT -->|Transform| BRONZE
    BRONZE --> SILVER
    SILVER --> GOLD
    GOLD --> AIDemo
    
    AIDemo --> SV
    SV --> CORTEX
    RESEARCH --> SEARCH
    
    AIDemo --> FEATURES
    FEATURES --> MODEL
    MODEL --> REGISTRY
    REGISTRY --> INFERENCE
    
    AIDemo --> TAGS
    TAGS --> MASK
    MASK --> RAP
    
    CORTEX --> APP1
    SEARCH --> APP1
    APP2 --> CORTEX
    
    RAP --> SHARE
    SHARE -.->|Live Data| CRO
    
    APP1 --> EXEC
    INFERENCE --> DS

    style Snowflake fill:#29B5E8,color:#fff
    style Intelligence fill:#FF6B35,color:#fff
    style ML fill:#7B68EE,color:#fff
    style Governance fill:#2E8B57,color:#fff
    style Sharing fill:#FFD700,color:#000
```

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
flowchart TB
    subgraph User["User Interaction"]
        Q["Natural Language Question\n'Why are compounds failing?'"]
    end

    subgraph SemanticLayer["Semantic Layer"]
        SV["Semantic View\n(DRUG_DISCOVERY_SEMANTIC_VIEW)"]
        
        subgraph Tables["Logical Tables"]
            T1["compounds"]
            T2["trials"]
            T3["programs"]
            T4["research"]
            T5["scorecard"]
        end
        
        subgraph Relationships["Relationships"]
            R1["trials → compounds"]
            R2["scorecard → compounds"]
        end
        
        subgraph Measures["Facts & Dimensions"]
            F1["molecular_weight"]
            F2["response_rate"]
            F3["roi_multiple"]
            D1["therapeutic_area"]
            D2["drug_likeness"]
        end
    end

    subgraph Cortex["Cortex AI"]
        LLM["LLM (llama3.1-70b)\n• SQL Generation\n• Answer Synthesis"]
        CSS["Cortex Search Service\n• Semantic Search\n• Document Retrieval"]
    end

    subgraph DataLayer["Physical Tables"]
        PT1[("COMPOUND_PIPELINE_ANALYSIS")]
        PT2[("CLINICAL_TRIAL_PERFORMANCE")]
        PT3[("PROGRAM_ROI_SUMMARY")]
        PT4[("RESEARCH_INTELLIGENCE")]
        PT5[("BOARD_CANDIDATE_SCORECARD")]
    end

    subgraph Response["AI Response"]
        A["Data-Backed Answer\n+ Business Action"]
    end

    Q --> SV
    SV --> Tables
    Tables --> Relationships
    Relationships --> Measures
    
    Measures --> LLM
    T4 --> CSS
    
    LLM --> PT1
    LLM --> PT2
    LLM --> PT3
    CSS --> PT4
    LLM --> PT5
    
    PT1 --> A
    PT2 --> A
    PT3 --> A
    PT4 --> A
    PT5 --> A

    style SemanticLayer fill:#FF6B35,color:#fff
    style Cortex fill:#29B5E8,color:#fff
```

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
flowchart TB
    subgraph LifeArc["LifeArc Account"]
        subgraph Source["Source Data"]
            TRIALS[("Clinical Trial Results\n10,000+ rows")]
            GOV["Governance Layer\n• Masking Policies\n• Row Access"]
        end
        
        subgraph Share["Secure Share"]
            SHARE["LIFEARC_CRO_SHARE\n• Zero-copy\n• Live data\n• Governed"]
            VIEW["Partner View\n(Masked & Filtered)"]
        end
    end

    subgraph CRO1["CRO Partner A"]
        ACC1["Snowflake Account"]
        DB1[("Shared Database\nRead-only")]
    end

    subgraph CRO2["CRO Partner B"]
        ACC2["Snowflake Account"]
        DB2[("Shared Database\nRead-only")]
    end

    subgraph Competitor["Competitor Approach"]
        COPY["Data Copy Required"]
        ETL["ETL Pipeline"]
        STALE["Stale Data Risk"]
        SECURITY["Security Risk"]
    end

    TRIALS --> GOV
    GOV --> VIEW
    VIEW --> SHARE
    
    SHARE -.->|"Zero-Copy\nInstant Access"| ACC1
    SHARE -.->|"Zero-Copy\nInstant Access"| ACC2
    
    ACC1 --> DB1
    ACC2 --> DB2

    COPY -.->|"❌ Databricks"| ETL
    ETL -.-> STALE
    STALE -.-> SECURITY

    style LifeArc fill:#29B5E8,color:#fff
    style Share fill:#FFD700,color:#000
    style CRO1 fill:#98FB98,color:#000
    style CRO2 fill:#98FB98,color:#000
    style Competitor fill:#FF6347,color:#fff
```

---

## 6. Data Governance Architecture

```mermaid
flowchart TB
    subgraph Classification["Data Classification"]
        TAGS["Object Tags"]
        
        subgraph TagTypes["Tag Types"]
            T1["DATA_CLASSIFICATION\n• PHI\n• PII\n• CONFIDENTIAL\n• PUBLIC"]
            T2["DATA_DOMAIN\n• CLINICAL\n• GENOMICS\n• COMPOUND"]
            T3["RETENTION_PERIOD\n• 1_YEAR\n• 10_YEARS\n• INDEFINITE"]
        end
    end

    subgraph Protection["Data Protection"]
        subgraph Masking["Column Masking"]
            M1["MASK_PATIENT_ID\n→ SHA2 hash"]
            M2["MASK_AGE\n→ Age bands"]
        end
        
        subgraph RowAccess["Row Access"]
            RAP["SITE_BASED_ACCESS\n• Filter by user's site\n• Automatic enforcement"]
        end
    end

    subgraph Tables["Protected Tables"]
        CTR[("CLINICAL_TRIAL_RESULTS\n• patient_id: MASKED\n• patient_age: MASKED\n• site_id: ROW FILTERED")]
    end

    subgraph Audit["Audit & Compliance"]
        LOG[("Access Audit Log")]
        QUERY["Query History"]
        COMPLIANCE["Compliance Reports\n• HIPAA\n• GxP\n• 21 CFR Part 11"]
    end

    subgraph Roles["Role Hierarchy"]
        ADMIN["ACCOUNTADMIN"]
        ANALYST["DATA_ANALYST"]
        PARTNER["PARTNER_ROLE"]
    end

    TAGS --> T1
    TAGS --> T2
    TAGS --> T3
    
    T1 --> M1
    T1 --> M2
    T1 --> RAP
    
    M1 --> CTR
    M2 --> CTR
    RAP --> CTR
    
    CTR --> LOG
    LOG --> COMPLIANCE
    
    ADMIN -->|"Full Access"| CTR
    ANALYST -->|"Masked View"| CTR
    PARTNER -->|"Filtered + Masked"| CTR

    style Classification fill:#2E8B57,color:#fff
    style Protection fill:#4169E1,color:#fff
    style Audit fill:#8B4513,color:#fff
```

---

## 7. Unstructured Data Processing Architecture

```mermaid
flowchart LR
    subgraph Sources["Unstructured Sources"]
        FASTA["FASTA Files\n(Gene Sequences)"]
        SDF["SDF Files\n(Molecular Structures)"]
        JSON["JSON Files\n(Clinical Protocols)"]
        PDF["Research Documents"]
    end

    subgraph Processing["Snowflake Processing"]
        subgraph UDFs["Python UDFs"]
            PARSE["PARSE_FASTA\n• Extract sequences\n• Calculate GC content\n• Parse metadata"]
        end
        
        subgraph Variant["VARIANT Storage"]
            VAR["Semi-structured Data\n• Nested JSON\n• Flexible schema\n• Path notation"]
        end
        
        subgraph CortexAI["Cortex AI"]
            LLM["Cortex COMPLETE\n• Summarization\n• Entity extraction\n• Q&A"]
            SEARCH["Cortex Search\n• Semantic similarity\n• Document retrieval"]
        end
    end

    subgraph Storage["Structured Storage"]
        GENES[("GENE_SEQUENCES\n• sequence_id\n• gc_content\n• seq_length")]
        COMPOUNDS[("COMPOUND_LIBRARY\n• properties: VARIANT\n• mol_block: TEXT")]
        TRIALS[("CLINICAL_TRIALS\n• protocol_data: VARIANT")]
        RESEARCH[("RESEARCH_INTELLIGENCE\n• full_text\n• key_finding")]
    end

    subgraph Query["Query Patterns"]
        SQL1["SELECT gc_content\nFROM gene_sequences"]
        SQL2["SELECT properties:logP\nFROM compounds"]
        SQL3["LATERAL FLATTEN\n(protocol_data:arms)"]
        SQL4["Cortex Search\n'DNA repair inhibitors'"]
    end

    FASTA --> PARSE
    PARSE --> GENES
    
    SDF --> VAR
    VAR --> COMPOUNDS
    
    JSON --> VAR
    VAR --> TRIALS
    
    PDF --> LLM
    LLM --> RESEARCH
    RESEARCH --> SEARCH
    
    GENES --> SQL1
    COMPOUNDS --> SQL2
    TRIALS --> SQL3
    SEARCH --> SQL4

    style Processing fill:#29B5E8,color:#fff
    style CortexAI fill:#FF6B35,color:#fff
```

---

## 8. Snowflake vs Competitors Comparison

```mermaid
flowchart TB
    subgraph Snowflake["Snowflake ✓"]
        S1["✓ Zero-Copy Data Sharing"]
        S2["✓ Time Travel (90 days)"]
        S3["✓ Instant Cloning"]
        S4["✓ Cortex AI (data stays)"]
        S5["✓ Per-Second Billing"]
        S6["✓ Auto-Suspend"]
        S7["✓ Native Streamlit"]
    end

    subgraph Databricks["Databricks"]
        D1["✗ Delta Sharing copies data"]
        D2["⚠ Time Travel (30 days, config)"]
        D3["⚠ Clone requires setup"]
        D4["✗ AI requires external APIs"]
        D5["✗ Per-hour billing"]
        D6["⚠ Manual cluster management"]
        D7["⚠ Databricks Apps (newer)"]
    end

    subgraph Fabric["Microsoft Fabric"]
        F1["✗ No zero-copy sharing"]
        F2["✗ No Time Travel"]
        F3["✗ Full copy required"]
        F4["✗ Azure OpenAI (data leaves)"]
        F5["✗ Capacity-based billing"]
        F6["⚠ Limited auto-scaling"]
        F7["⚠ Power BI only"]
    end

    subgraph Winner["For Life Sciences"]
        W["Snowflake Wins\n• HIPAA compliance\n• GxP audit trails\n• Partner collaboration\n• Cost efficiency"]
    end

    S1 --> W
    S2 --> W
    S3 --> W
    S4 --> W

    style Snowflake fill:#29B5E8,color:#fff
    style Databricks fill:#FF3621,color:#fff
    style Fabric fill:#0078D4,color:#fff
    style Winner fill:#FFD700,color:#000
```

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

## 10. Complete System Context

```mermaid
C4Context
    title LifeArc Drug Discovery Platform - System Context

    Person(exec, "Executive", "VP R&D / CSO")
    Person(ds, "Data Scientist", "ML/Analytics")
    Person(cro, "CRO Partner", "External collaborator")
    
    System_Boundary(sf, "Snowflake Platform") {
        System(intelligence, "Snowflake Intelligence", "Talk to Your Data")
        System(ml, "ML Pipeline", "Drug-likeness prediction")
        System(gov, "Governance", "Tags, masking, audit")
        System(share, "Data Sharing", "Zero-copy collaboration")
    }
    
    System_Ext(github, "GitHub", "Source control")
    System_Ext(streamlit, "Streamlit Apps", "User interfaces")
    
    Rel(exec, intelligence, "Asks questions")
    Rel(ds, ml, "Trains models")
    Rel(cro, share, "Accesses shared data")
    
    Rel(github, sf, "Git sync")
    Rel(sf, streamlit, "Hosts apps")
    
    Rel(intelligence, gov, "Enforces policies")
    Rel(ml, gov, "Enforces policies")
    Rel(share, gov, "Enforces policies")
```

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
