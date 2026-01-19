/*
================================================================================
LifeArc Drug Discovery Pipeline - Semantic View
================================================================================
Purpose: Enable natural language queries for drug discovery analytics
Schema: LIFEARC_POC.AI_DEMO
Tables: 5 core tables covering compounds, trials, programs, research, and board priorities

Business Context:
- VP of R&D / Chief Scientific Officer persona
- Focus on "Why" questions for portfolio decisions
- Supports drill-through from summary to detail

Usage:
- Connect to this semantic view from Snowflake Intelligence
- Ask natural language questions about drug discovery pipeline
================================================================================
*/

CREATE OR REPLACE SEMANTIC VIEW LIFEARC_POC.AI_DEMO.DRUG_DISCOVERY_SEMANTIC_VIEW

TABLES (
    compounds AS LIFEARC_POC.AI_DEMO.COMPOUND_PIPELINE_ANALYSIS PRIMARY KEY (compound_id) WITH SYNONYMS = ('molecules', 'drugs', 'candidates') COMMENT = 'Drug candidates with molecular properties and drug-likeness assessments',
    trials AS LIFEARC_POC.AI_DEMO.CLINICAL_TRIAL_PERFORMANCE PRIMARY KEY (trial_id) WITH SYNONYMS = ('studies', 'clinical studies') COMMENT = 'Clinical trial outcomes',
    programs AS LIFEARC_POC.AI_DEMO.PROGRAM_ROI_SUMMARY PRIMARY KEY (program_id) WITH SYNONYMS = ('R&D programs', 'pipelines') COMMENT = 'R&D program summaries with ROI projections',
    research AS LIFEARC_POC.AI_DEMO.RESEARCH_INTELLIGENCE PRIMARY KEY (doc_id) WITH SYNONYMS = ('documents', 'publications') COMMENT = 'Research documents and competitive intelligence',
    scorecard AS LIFEARC_POC.AI_DEMO.BOARD_CANDIDATE_SCORECARD PRIMARY KEY (candidate_id) WITH SYNONYMS = ('priorities', 'board candidates') COMMENT = 'Executive scorecard for board presentation'
)

RELATIONSHIPS (
    trials_to_compounds AS trials(compound_id) REFERENCES compounds(compound_id),
    scorecard_to_compounds AS scorecard(compound_id) REFERENCES compounds(compound_id)
)

FACTS (
    -- Compound molecular properties (for drug-likeness analysis)
    compounds.molecular_weight AS compounds.molecular_weight WITH SYNONYMS = ('MW') COMMENT = 'Molecular weight in Daltons',
    compounds.logp AS compounds.logp WITH SYNONYMS = ('lipophilicity') COMMENT = 'Partition coefficient',
    compounds.tpsa AS compounds.tpsa COMMENT = 'Topological polar surface area',
    compounds.hbd AS compounds.hbd WITH SYNONYMS = ('HBD') COMMENT = 'Hydrogen bond donors',
    compounds.hba AS compounds.hba WITH SYNONYMS = ('HBA') COMMENT = 'Hydrogen bond acceptors',
    compounds.predicted_success_pct AS compounds.predicted_success_pct COMMENT = 'Predicted success probability 0-100',
    compounds.r_and_d_spend_millions AS compounds.r_and_d_spend_millions WITH SYNONYMS = ('R&D investment') COMMENT = 'R&D investment in millions USD',
    
    -- Trial outcomes (for clinical performance analysis)
    trials.enrolled_patients AS trials.enrolled_patients WITH SYNONYMS = ('enrollment') COMMENT = 'Patients enrolled',
    trials.completed_patients AS trials.completed_patients COMMENT = 'Patients completed treatment',
    trials.response_rate_pct AS trials.response_rate_pct WITH SYNONYMS = ('ORR') COMMENT = 'Objective response rate pct',
    trials.pfs_months AS trials.pfs_months WITH SYNONYMS = ('PFS') COMMENT = 'Progression-free survival months',
    trials.os_months AS trials.os_months WITH SYNONYMS = ('OS') COMMENT = 'Overall survival months',
    trials.serious_adverse_events AS trials.serious_adverse_events WITH SYNONYMS = ('SAEs') COMMENT = 'Serious adverse event count',
    trials.trial_cost_millions AS trials.trial_cost_millions COMMENT = 'Trial cost in millions USD',
    
    -- Program ROI metrics
    programs.total_compounds AS programs.total_compounds COMMENT = 'Total compounds in program',
    programs.compounds_in_clinic AS programs.compounds_in_clinic COMMENT = 'Compounds in clinical trials',
    programs.compounds_drug_like AS programs.compounds_drug_like COMMENT = 'Drug-like compounds',
    programs.phase_transition_rate AS programs.phase_transition_rate COMMENT = 'Phase advancement rate pct',
    programs.historical_success_rate AS programs.historical_success_rate COMMENT = 'Historical success rate pct',
    programs.total_investment_millions AS programs.total_investment_millions COMMENT = 'Total program investment millions USD',
    programs.projected_revenue_millions AS programs.projected_revenue_millions COMMENT = 'Projected revenue millions USD',
    programs.roi_multiple AS programs.roi_multiple WITH SYNONYMS = ('ROI') COMMENT = 'Return on investment multiple',
    
    -- Board scorecard metrics
    scorecard.predicted_success_pct AS scorecard.predicted_success_pct COMMENT = 'Predicted success probability',
    scorecard.time_to_market_years AS scorecard.time_to_market_years COMMENT = 'Years to market approval',
    scorecard.peak_sales_millions AS scorecard.peak_sales_millions COMMENT = 'Peak annual sales millions USD',
    scorecard.investment_required_millions AS scorecard.investment_required_millions COMMENT = 'Remaining investment millions USD'
)

DIMENSIONS (
    -- Compound dimensions
    compounds.compound_id AS compounds.compound_id COMMENT = 'Unique compound identifier',
    compounds.compound_name AS compounds.compound_name WITH SYNONYMS = ('drug name', 'molecule name') COMMENT = 'Human-readable compound name',
    compounds.target_gene AS compounds.target_gene WITH SYNONYMS = ('gene target', 'molecular target') COMMENT = 'Gene target',
    compounds.therapeutic_area AS compounds.therapeutic_area WITH SYNONYMS = ('disease area') COMMENT = 'Therapeutic area: Oncology, Autoimmune, CNS',
    compounds.program_name AS compounds.program_name WITH SYNONYMS = ('R&D program') COMMENT = 'R&D program name',
    compounds.phase AS compounds.phase WITH SYNONYMS = ('development stage') COMMENT = 'Development phase',
    compounds.drug_likeness AS compounds.drug_likeness WITH SYNONYMS = ('Ro5 compliance') COMMENT = 'Drug-likeness: drug_like, borderline, non_drug_like',
    compounds.failure_reason AS compounds.failure_reason COMMENT = 'Reason for drug-likeness failure',
    compounds.created_date AS compounds.created_date COMMENT = 'Date compound was added to pipeline',
    
    -- Trial dimensions
    trials.trial_id AS trials.trial_id COMMENT = 'Unique trial identifier',
    trials.trial_name AS trials.trial_name WITH SYNONYMS = ('study name') COMMENT = 'Full trial name',
    trials.compound_name AS trials.compound_name COMMENT = 'Compound being tested',
    trials.target_gene AS trials.target_gene COMMENT = 'Gene target for trial compound',
    trials.therapeutic_area AS trials.therapeutic_area COMMENT = 'Therapeutic area for trial',
    trials.phase AS trials.phase WITH SYNONYMS = ('clinical phase') COMMENT = 'Clinical phase: Phase I, Phase II, Phase III',
    trials.status AS trials.status COMMENT = 'Trial status: Active, Completed, Recruiting, Terminated',
    trials.indication AS trials.indication WITH SYNONYMS = ('disease') COMMENT = 'Disease indication',
    trials.biomarker_selection AS trials.biomarker_selection COMMENT = 'Biomarker-based patient selection: YES, NO',
    trials.ctdna_confirmation AS trials.ctdna_confirmation WITH SYNONYMS = ('liquid biopsy') COMMENT = 'ctDNA confirmation required: YES, NO',
    trials.start_date AS trials.start_date COMMENT = 'Trial start date',
    trials.completion_date AS trials.completion_date COMMENT = 'Trial completion date',
    
    -- Program dimensions
    programs.program_id AS programs.program_id COMMENT = 'Unique program identifier',
    programs.program_name AS programs.program_name COMMENT = 'R&D program name',
    programs.therapeutic_area AS programs.therapeutic_area COMMENT = 'Therapeutic area for program',
    programs.target_gene AS programs.target_gene COMMENT = 'Primary gene target for program',
    programs.recommendation AS programs.recommendation WITH SYNONYMS = ('investment recommendation') COMMENT = 'Recommendation: EXPAND, MAINTAIN, REDUCE, TERMINATE',
    programs.rationale AS programs.rationale COMMENT = 'Rationale for recommendation',
    
    -- Research dimensions (with Cortex Search for semantic search)
    research.doc_id AS research.doc_id COMMENT = 'Unique document identifier',
    research.doc_title AS research.doc_title WITH SYNONYMS = ('title') COMMENT = 'Document title',
    research.doc_type AS research.doc_type COMMENT = 'Document type: Publication, Internal Report',
    research.source AS research.source WITH SYNONYMS = ('journal') COMMENT = 'Document source',
    research.publication_date AS research.publication_date COMMENT = 'Publication date',
    research.target_gene AS research.target_gene COMMENT = 'Gene target discussed',
    research.therapeutic_area AS research.therapeutic_area COMMENT = 'Therapeutic area covered',
    research.key_finding AS research.key_finding WITH SYNONYMS = ('main finding') COMMENT = 'Key finding from document',
    research.competitive_impact AS research.competitive_impact COMMENT = 'Competitive impact: High, Medium',
    research.action_required AS research.action_required COMMENT = 'Action required: YES, NO',
    research.recommended_action AS research.recommended_action COMMENT = 'Recommended strategic action',
    research.full_text AS research.full_text WITH CORTEX SEARCH SERVICE LIFEARC_POC.AI_DEMO.RESEARCH_SEARCH_SERVICE,
    
    -- Board scorecard dimensions
    scorecard.candidate_id AS scorecard.candidate_id COMMENT = 'Unique candidate identifier',
    scorecard.compound_name AS scorecard.compound_name COMMENT = 'Compound name',
    scorecard.target_gene AS scorecard.target_gene COMMENT = 'Gene target',
    scorecard.therapeutic_area AS scorecard.therapeutic_area COMMENT = 'Therapeutic area',
    scorecard.current_phase AS scorecard.current_phase COMMENT = 'Current development phase',
    scorecard.competitive_position AS scorecard.competitive_position WITH SYNONYMS = ('market position') COMMENT = 'Position: First-in-class, Best-in-class, Fast-follower, Follow-on',
    scorecard.risk_factors AS scorecard.risk_factors WITH SYNONYMS = ('risks') COMMENT = 'Key risk factors',
    scorecard.strategic_rationale AS scorecard.strategic_rationale WITH SYNONYMS = ('investment thesis') COMMENT = 'Strategic rationale',
    scorecard.board_recommendation AS scorecard.board_recommendation WITH SYNONYMS = ('priority') COMMENT = 'Board recommendation: Priority 1, 2, 3, Watch List, Terminate'
)

AI_SQL_GENERATION 'For compound failure questions: focus on logp, molecular_weight, drug_likeness. For trial comparisons: highlight biomarker_selection and ctdna_confirmation. For ROI questions: compare roi_multiple across therapeutic areas.'

AI_QUESTION_CATEGORIZATION 'COMPOUND_SCREENING: molecular properties, drug-likeness. CLINICAL_PERFORMANCE: trial outcomes, response rates. PORTFOLIO_ROI: investments, ROI. COMPETITIVE_INTEL: research findings. BOARD_PRIORITIES: candidate prioritization.';
