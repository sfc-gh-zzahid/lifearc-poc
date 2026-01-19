# Snowflake Intelligence Demo: LifeArc Drug Discovery

## Executive Summary

**Persona**: VP of R&D / Chief Scientific Officer at LifeArc  
**Goal**: Understand WHY certain drug candidates succeed or fail, and make data-driven portfolio decisions  
**Schema**: `LIFEARC_POC.AI_DEMO`

---

## Demo Data Summary

| Table | Records | Purpose |
|-------|---------|---------|
| `COMPOUND_PIPELINE_ANALYSIS` | 29 | Compound properties, drug-likeness, R&D investment |
| `CLINICAL_TRIAL_PERFORMANCE` | 17 | Trial outcomes, patient data, biomarker usage |
| `PROGRAM_ROI_SUMMARY` | 9 | Program-level ROI and recommendations |
| `RESEARCH_INTELLIGENCE` | 8 | Research documents for semantic search |
| `BOARD_CANDIDATE_SCORECARD` | 8 | Executive prioritization scorecard |
| `EXECUTIVE_PIPELINE_SUMMARY` | View | High-level KPIs |

---

## The "Why" Questions (Demo Script)

### Question 1: Discovery & Prioritization
> **"Why are some of our compounds failing drug-likeness screening while others pass?"**

**Expected Answer**: 
- 41% of compounds (12/29) fail drug-likeness
- LogP > 5.0 is the primary failure reason (affects 9 compounds)
- CNS programs have 0% drug-like compounds vs 85% for BRCA program
- KRAS program has 40% drug-like rate due to molecular weight issues

**Sample Query**:
```sql
SELECT 
    therapeutic_area,
    program_name,
    COUNT(*) as total_compounds,
    SUM(CASE WHEN drug_likeness = 'drug_like' THEN 1 ELSE 0 END) as drug_like_count,
    ROUND(AVG(logp), 2) as avg_logp
FROM LIFEARC_POC.AI_DEMO.COMPOUND_PIPELINE_ANALYSIS
GROUP BY therapeutic_area, program_name
ORDER BY drug_like_count DESC;
```

**Business Action**: Adjust medicinal chemistry guidelines - Set hard LogP ceiling at 4.5 for all programs

---

### Question 2: Clinical Pipeline Performance
> **"Why is our BRCA1 program showing better clinical outcomes than our KRAS program?"**

**Expected Answer**:
- BRCA1 trials: 52.9% avg response rate, 13 months PFS
- KRAS trials: 32.1% avg response rate, 6.4 months PFS
- Key difference: 100% of BRCA1 trials use ctDNA confirmation vs 33% for KRAS
- Biomarker-selected trials have 1.6x higher response rates

**Sample Query**:
```sql
SELECT 
    target_gene,
    ctdna_confirmation,
    COUNT(*) as trials,
    ROUND(AVG(response_rate_pct), 1) as avg_response_rate
FROM LIFEARC_POC.AI_DEMO.CLINICAL_TRIAL_PERFORMANCE
WHERE target_gene IN ('BRCA1', 'KRAS')
GROUP BY target_gene, ctdna_confirmation
ORDER BY target_gene, ctdna_confirmation;
```

**Business Action**: Mandate ctDNA confirmation for all KRAS trial enrollment

---

### Question 3: Resource Allocation
> **"How should we reallocate R&D budget based on our pipeline success rates by therapeutic area?"**

**Expected Answer**:
- Oncology: 21.6x avg ROI, 59% success rate, $590M invested
- Autoimmune: 9.2x avg ROI, 35% success rate, $148M invested  
- CNS: 2.8x avg ROI, 16.5% success rate, $165M invested

**Recommendation**:
- EXPAND: BRCA DDR Program (+$40M), MYC Inhibitor Program (+$30M)
- REDUCE: JAK Program (-$42M), EGFR Program (-$25M)
- TERMINATE: IL-17 Program, Amyloid Program, Tau Program
- Net reallocation: $107M from low-ROI to high-ROI programs

**Sample Query**:
```sql
SELECT 
    therapeutic_area,
    SUM(total_investment_millions) as current_investment,
    AVG(historical_success_rate) as success_rate,
    AVG(roi_multiple) as roi,
    LISTAGG(DISTINCT recommendation, ', ') as actions
FROM LIFEARC_POC.AI_DEMO.PROGRAM_ROI_SUMMARY
GROUP BY therapeutic_area
ORDER BY roi DESC;
```

**Business Action**: Present reallocation proposal to CFO - Shift $107M from autoimmune/CNS to oncology

---

### Question 4: Research Document Intelligence (Unstructured)
> **"What competitive intelligence from our research documents suggests we should change our EGFR strategy?"**

**Expected Answer**:
- 2 high-impact documents flag EGFR resistance concerns
- C797S mutation affects 42% of patients on third-gen TKIs
- MET amplification bypass in 28% of resistant tumors
- Cross-resistance observed across all current-gen inhibitors

**Recommendations from research**:
1. Pivot to fourth-generation irreversible inhibitors
2. Evaluate MET inhibitor combinations
3. Deprioritize LA-EGFR-002, LA-EGFR-003, LA-EGFR-004

**Sample Query**:
```sql
SELECT 
    doc_title,
    key_finding,
    recommended_action
FROM LIFEARC_POC.AI_DEMO.RESEARCH_INTELLIGENCE
WHERE target_gene = 'EGFR' 
  AND competitive_impact = 'High'
ORDER BY publication_date DESC;
```

**Business Action**: Pivot EGFR program to next-generation designs with alternate binding mechanisms

---

### Question 5: Integrated Decision
> **"Given all our data, which 3 candidates should we prioritize for the next board presentation?"**

**Expected Answer**:

| Priority | Compound | Target | Why |
|----------|----------|--------|-----|
| 1 | Olaparib-LA | BRCA1 | 85% predicted success, 72% ORR, best-in-class, $1.2B peak sales |
| 2 | OmoMYC-LA | MYC | 78% success, first-in-class, $3.5B peak sales, 18-24 month window |
| 3 | Ceralasertib-LA | ATR | 65% success, orphan drug, fast-track eligible, synergy with BRCA |

**Sample Query**:
```sql
SELECT 
    board_recommendation,
    compound_name,
    target_gene,
    predicted_success_pct,
    competitive_position,
    peak_sales_millions,
    strategic_rationale
FROM LIFEARC_POC.AI_DEMO.BOARD_CANDIDATE_SCORECARD
WHERE board_recommendation LIKE 'Priority%'
ORDER BY board_recommendation;
```

**Business Action**: Prepare board presentation with investment thesis for each Priority candidate

---

## Demo Flow (12 minutes)

```
┌─────────────────────────────────────────────────────────────────┐
│  SCENE 1: Executive Dashboard (1 min)                          │
│  "Show me our pipeline summary"                                 │
│  → Query EXECUTIVE_PIPELINE_SUMMARY                             │
│  → Highlight: 29 compounds, $903M invested, 14.7x avg ROI      │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│  SCENE 2: The Discovery Problem (2 min)                         │
│  "Why are compounds failing screening?"                         │
│  → Query COMPOUND_PIPELINE_ANALYSIS                             │
│  → Show: LogP distribution, 41% failure rate                    │
│  → Drill: CNS has 0% drug-like vs BRCA at 100%                 │
│  → Action: Chemistry guidelines adjustment                      │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│  SCENE 3: Clinical Performance Gap (3 min)                      │
│  "Why is BRCA outperforming KRAS?"                              │
│  → Query CLINICAL_TRIAL_PERFORMANCE                             │
│  → Show: 52.9% vs 32.1% response rates                          │
│  → Insight: ctDNA confirmation is the key differentiator        │
│  → Drill: KRAS trials without ctDNA have 28% vs 35% with       │
│  → Action: Mandate ctDNA for all KRAS enrollment               │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│  SCENE 4: Budget Reallocation (2 min)                           │
│  "How should we reallocate R&D budget?"                         │
│  → Query PROGRAM_ROI_SUMMARY                                    │
│  → Show: ROI by therapeutic area (Oncology 21.6x vs CNS 2.8x)  │
│  → Drill: Expand/Reduce/Terminate recommendations               │
│  → Action: $107M reallocation proposal                          │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│  SCENE 5: Competitive Intelligence (2 min)                      │
│  "What does research say about EGFR resistance?"                │
│  → Query RESEARCH_INTELLIGENCE (semantic search)                │
│  → Show: C797S mutation in 42%, MET bypass in 28%              │
│  → Surface: Key publications with recommended actions           │
│  → Action: EGFR program pivot recommendation                    │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│  SCENE 6: Board Prioritization (2 min)                          │
│  "Which 3 candidates for the board?"                            │
│  → Query BOARD_CANDIDATE_SCORECARD                              │
│  → Show: Ranked candidates with strategic rationale             │
│  → Highlight: Priority 1-3 with investment thesis               │
│  → Action: Board presentation preparation                       │
└─────────────────────────────────────────────────────────────────┘
```

---

## Key Insights to Highlight

### The "Aha" Moments

1. **Biomarker Selection Drives Outcomes**: BRCA1's 100% ctDNA usage vs KRAS's 33% explains the performance gap
2. **Chemistry Problems Are Systematic**: CNS programs have 0% drug-like compounds - not random failures
3. **ROI Varies 8x Across Therapeutic Areas**: Oncology at 21.6x vs CNS at 2.8x
4. **Competitive Intel Requires Action**: 5 high-impact documents need immediate strategic response
5. **First-Mover Advantage Window**: MYC program has 18-24 month window before competitors

### Data-Driven Decisions

| Question | Insight | Decision | Value |
|----------|---------|----------|-------|
| Compound failures | LogP > 5 causes 70% of failures | Adjust chemistry guidelines | Avoid $50M in failed candidates |
| Trial performance | ctDNA confirmation drives outcomes | Mandate for KRAS trials | Improve response rate 25% |
| Budget allocation | 8x ROI difference by area | Reallocate $107M | Additional $300M NPV |
| EGFR strategy | Resistance mechanisms emerging | Pivot program design | Avoid competitive losses |
| Board priorities | Risk-adjusted ranking | Focus resources on top 3 | $5.5B peak sales potential |

---

## Technical Setup

### Tables Created
```sql
USE DATABASE LIFEARC_POC;
USE SCHEMA AI_DEMO;

-- Verify all tables exist
SHOW TABLES IN SCHEMA AI_DEMO;
```

### Sample Validation Queries
```sql
-- Overall data summary
SELECT 
    'COMPOUND_PIPELINE_ANALYSIS' as table_name, COUNT(*) as rows FROM AI_DEMO.COMPOUND_PIPELINE_ANALYSIS
UNION ALL SELECT 'CLINICAL_TRIAL_PERFORMANCE', COUNT(*) FROM AI_DEMO.CLINICAL_TRIAL_PERFORMANCE
UNION ALL SELECT 'PROGRAM_ROI_SUMMARY', COUNT(*) FROM AI_DEMO.PROGRAM_ROI_SUMMARY  
UNION ALL SELECT 'RESEARCH_INTELLIGENCE', COUNT(*) FROM AI_DEMO.RESEARCH_INTELLIGENCE
UNION ALL SELECT 'BOARD_CANDIDATE_SCORECARD', COUNT(*) FROM AI_DEMO.BOARD_CANDIDATE_SCORECARD;
```

---

## Snowflake Intelligence Configuration

### Structured Data Tables
- `COMPOUND_PIPELINE_ANALYSIS` - Drug discovery metrics
- `CLINICAL_TRIAL_PERFORMANCE` - Clinical outcomes
- `PROGRAM_ROI_SUMMARY` - Investment metrics
- `BOARD_CANDIDATE_SCORECARD` - Executive summary

### Unstructured Data for Semantic Search
- `RESEARCH_INTELLIGENCE.full_text` - Full document text for Cortex Search
- Enable semantic search on `key_finding` and `full_text` columns

### Suggested Cortex Search Service
```sql
CREATE OR REPLACE CORTEX SEARCH SERVICE LIFEARC_POC.AI_DEMO.RESEARCH_SEARCH_SERVICE
  ON full_text
  WAREHOUSE = DEMO_WH
  TARGET_LAG = '1 hour'
  AS (
    SELECT 
      doc_id,
      doc_title,
      doc_type,
      target_gene,
      therapeutic_area,
      key_finding,
      recommended_action,
      full_text
    FROM LIFEARC_POC.AI_DEMO.RESEARCH_INTELLIGENCE
  );
```

---

## Success Metrics

Demo is successful if:
1. All 5 "Why" questions return meaningful, actionable insights
2. Drill-through from summary → detail works seamlessly
3. Unstructured search surfaces relevant competitive intelligence
4. Business actions are clear and data-supported
5. Executive can understand strategic implications without technical explanation
