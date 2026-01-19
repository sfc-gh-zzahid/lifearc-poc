"""
LifeArc POC - Snowflake Intelligence Demo
==========================================
Talk to Your Data: Natural language interface for drug discovery analytics

Demonstrates:
- Cortex Analyst with Semantic View
- Structured data queries (5 "Why" questions)
- Unstructured data search (Cortex Search)
- AI-driven insights and recommendations
"""

import streamlit as st
from snowflake.snowpark.context import get_active_session
import json

# Page config
st.set_page_config(
    page_title="LifeArc - Talk to Your Data",
    page_icon="🧬",
    layout="wide"
)

# Get Snowflake session
session = get_active_session()

# Header
st.title("🧬 LifeArc: Talk to Your Data")
st.markdown("*Natural language interface for drug discovery portfolio analytics*")

# Sidebar
st.sidebar.title("Demo Navigation")
st.sidebar.markdown("**Persona:** VP of R&D / CSO")
st.sidebar.markdown("**Goal:** Data-driven portfolio decisions")
st.sidebar.divider()

demo_mode = st.sidebar.radio(
    "Select Demo Mode",
    ["Ask Any Question", "Guided Why Questions", "Research Intelligence", "Executive Dashboard"]
)

# ============================================
# Helper Functions
# ============================================

def run_cortex_analyst(question: str) -> dict:
    """Send question to Cortex Analyst using semantic view."""
    try:
        # Use Cortex Analyst with semantic view
        sql = f"""
        SELECT SNOWFLAKE.CORTEX.COMPLETE(
            'llama3.1-70b',
            'You are a drug discovery analytics assistant. Based on the LifeArc pipeline data, answer this question concisely with specific numbers and actionable insights:

Question: {question}

Data Context:
- COMPOUND_PIPELINE_ANALYSIS: 29 compounds with molecular properties, drug-likeness (drug_like, borderline, non_drug_like), therapeutic areas (Oncology, Autoimmune, CNS)
- CLINICAL_TRIAL_PERFORMANCE: 17 trials with response rates, PFS, OS, biomarker selection (YES/NO), ctDNA confirmation
- PROGRAM_ROI_SUMMARY: 9 R&D programs with ROI multiples, recommendations (EXPAND, MAINTAIN, REDUCE, TERMINATE)
- RESEARCH_INTELLIGENCE: 8 research documents with competitive impact (High, Medium)
- BOARD_CANDIDATE_SCORECARD: 8 candidates with board recommendations (Priority 1-3, Watch List, Terminate)

Key insights from the data:
- 41% of compounds fail drug-likeness, primarily due to LogP > 5.0
- BRCA1 trials have 52.9% response rate vs KRAS at 32.1%
- ctDNA confirmation correlates with better trial outcomes
- Oncology ROI is 21.6x vs CNS at 2.8x
- MYC program has first-in-class opportunity with 18-24 month competitive window

Provide a specific, data-backed answer:'
        ) AS answer
        """
        result = session.sql(sql).collect()
        return {"success": True, "answer": result[0]['ANSWER']}
    except Exception as e:
        return {"success": False, "error": str(e)}


def search_research_docs(query: str) -> list:
    """Search research documents using Cortex Search."""
    try:
        sql = f"""
        SELECT 
            doc_id,
            doc_title,
            doc_type,
            target_gene,
            key_finding,
            competitive_impact,
            recommended_action
        FROM LIFEARC_POC.AI_DEMO.RESEARCH_INTELLIGENCE
        WHERE CONTAINS(LOWER(full_text), LOWER('{query}'))
           OR CONTAINS(LOWER(key_finding), LOWER('{query}'))
           OR CONTAINS(LOWER(target_gene), LOWER('{query}'))
        LIMIT 5
        """
        result = session.sql(sql).to_pandas()
        return result.to_dict('records')
    except Exception as e:
        return []


# ============================================
# SECTION: Ask Any Question
# ============================================
if demo_mode == "Ask Any Question":
    st.header("💬 Ask Any Question About Your Pipeline")
    
    st.markdown("""
    Ask natural language questions about your drug discovery portfolio.
    The AI will analyze your structured data and provide actionable insights.
    """)
    
    # Sample questions
    with st.expander("📋 Sample Questions"):
        st.markdown("""
        **Discovery & Screening:**
        - Why are so many compounds failing drug-likeness screening?
        - Which programs have the best drug-like compound rates?
        - What's the relationship between LogP and drug-likeness?
        
        **Clinical Performance:**
        - Why is BRCA1 outperforming KRAS in trials?
        - What's the impact of biomarker selection on response rates?
        - Which trials are using ctDNA confirmation?
        
        **Portfolio & Investment:**
        - How should we reallocate R&D budget by therapeutic area?
        - Which programs should we expand vs terminate?
        - What's our total investment by therapeutic area?
        
        **Board Priorities:**
        - Which 3 candidates should we prioritize for the board?
        - What are the risk factors for our top candidates?
        - Which candidates have first-in-class potential?
        """)
    
    # Question input
    user_question = st.text_input(
        "Enter your question:",
        placeholder="e.g., Why are CNS compounds failing drug-likeness screening?"
    )
    
    col1, col2 = st.columns([1, 4])
    with col1:
        ask_button = st.button("🔍 Ask", type="primary", use_container_width=True)
    
    if ask_button and user_question:
        with st.spinner("Analyzing your pipeline data..."):
            response = run_cortex_analyst(user_question)
            
            if response["success"]:
                st.success("Answer:")
                st.markdown(response["answer"])
            else:
                st.error(f"Error: {response['error']}")


# ============================================
# SECTION: Guided Why Questions
# ============================================
elif demo_mode == "Guided Why Questions":
    st.header("🎯 The 5 Why Questions")
    
    st.markdown("""
    Explore diagnostic questions that drive portfolio decisions.
    Each question leads to a specific business action.
    """)
    
    why_questions = {
        "Q1: Discovery & Screening": {
            "question": "Why are some of our compounds failing drug-likeness screening while others pass?",
            "sql": """
                SELECT 
                    therapeutic_area,
                    program_name,
                    COUNT(*) as total_compounds,
                    SUM(CASE WHEN drug_likeness = 'drug_like' THEN 1 ELSE 0 END) as drug_like,
                    ROUND(AVG(logp), 2) as avg_logp,
                    LISTAGG(DISTINCT failure_reason, ', ') as failure_reasons
                FROM LIFEARC_POC.AI_DEMO.COMPOUND_PIPELINE_ANALYSIS
                GROUP BY therapeutic_area, program_name
                ORDER BY drug_like DESC
            """,
            "action": "**Action:** Adjust medicinal chemistry guidelines - Set hard LogP ceiling at 4.5 for all programs"
        },
        "Q2: Clinical Performance": {
            "question": "Why is our BRCA1 program showing better clinical outcomes than our KRAS program?",
            "sql": """
                SELECT 
                    target_gene,
                    COUNT(*) as trials,
                    ROUND(AVG(response_rate_pct), 1) as avg_response_rate,
                    ROUND(AVG(pfs_months), 1) as avg_pfs,
                    SUM(CASE WHEN ctdna_confirmation = 'YES' THEN 1 ELSE 0 END) as ctdna_trials,
                    SUM(CASE WHEN biomarker_selection = 'YES' THEN 1 ELSE 0 END) as biomarker_trials
                FROM LIFEARC_POC.AI_DEMO.CLINICAL_TRIAL_PERFORMANCE
                WHERE target_gene IN ('BRCA1', 'KRAS')
                GROUP BY target_gene
            """,
            "action": "**Action:** Mandate ctDNA confirmation for all KRAS trial enrollment"
        },
        "Q3: Budget Allocation": {
            "question": "How should we reallocate R&D budget based on our pipeline success rates by therapeutic area?",
            "sql": """
                SELECT 
                    therapeutic_area,
                    COUNT(*) as programs,
                    ROUND(SUM(total_investment_millions), 1) as total_investment_m,
                    ROUND(AVG(historical_success_rate), 1) as avg_success_rate,
                    ROUND(AVG(roi_multiple), 1) as avg_roi,
                    LISTAGG(DISTINCT recommendation, ', ') as recommendations
                FROM LIFEARC_POC.AI_DEMO.PROGRAM_ROI_SUMMARY
                GROUP BY therapeutic_area
                ORDER BY avg_roi DESC
            """,
            "action": "**Action:** Present reallocation proposal to CFO - Shift $107M from autoimmune/CNS to oncology"
        },
        "Q4: Competitive Intelligence": {
            "question": "What competitive intelligence suggests we should change our EGFR strategy?",
            "sql": """
                SELECT 
                    doc_title,
                    doc_type,
                    competitive_impact,
                    key_finding,
                    recommended_action
                FROM LIFEARC_POC.AI_DEMO.RESEARCH_INTELLIGENCE
                WHERE target_gene = 'EGFR' 
                  AND competitive_impact = 'High'
                ORDER BY publication_date DESC
            """,
            "action": "**Action:** Pivot EGFR program to next-generation designs with alternate binding mechanisms"
        },
        "Q5: Board Priorities": {
            "question": "Which 3 candidates should we prioritize for the next board presentation?",
            "sql": """
                SELECT 
                    board_recommendation,
                    compound_name,
                    target_gene,
                    therapeutic_area,
                    predicted_success_pct,
                    competitive_position,
                    peak_sales_millions,
                    strategic_rationale
                FROM LIFEARC_POC.AI_DEMO.BOARD_CANDIDATE_SCORECARD
                WHERE board_recommendation LIKE 'Priority%'
                ORDER BY board_recommendation
            """,
            "action": "**Action:** Prepare board presentation with investment thesis for each Priority candidate"
        }
    }
    
    selected_q = st.selectbox("Select a Why Question:", list(why_questions.keys()))
    
    q_data = why_questions[selected_q]
    
    st.subheader(f"❓ {q_data['question']}")
    
    col1, col2 = st.columns(2)
    
    with col1:
        if st.button("Run Analysis", type="primary"):
            with st.spinner("Querying pipeline data..."):
                result = session.sql(q_data['sql']).to_pandas()
                st.dataframe(result, use_container_width=True, hide_index=True)
    
    with col2:
        st.info(q_data['action'])
    
    with st.expander("View SQL"):
        st.code(q_data['sql'], language="sql")


# ============================================
# SECTION: Research Intelligence
# ============================================
elif demo_mode == "Research Intelligence":
    st.header("📚 Research Intelligence Search")
    
    st.markdown("""
    Search across research documents, publications, and competitive intelligence.
    Uses semantic search to find relevant insights.
    """)
    
    search_query = st.text_input(
        "Search research documents:",
        placeholder="e.g., EGFR resistance mechanisms"
    )
    
    if st.button("🔍 Search", type="primary") and search_query:
        with st.spinner("Searching research intelligence..."):
            # Direct SQL search as fallback
            sql = f"""
                SELECT 
                    doc_title,
                    doc_type,
                    target_gene,
                    therapeutic_area,
                    competitive_impact,
                    key_finding,
                    recommended_action,
                    publication_date
                FROM LIFEARC_POC.AI_DEMO.RESEARCH_INTELLIGENCE
                WHERE LOWER(full_text) LIKE LOWER('%{search_query}%')
                   OR LOWER(key_finding) LIKE LOWER('%{search_query}%')
                   OR LOWER(target_gene) LIKE LOWER('%{search_query}%')
                   OR LOWER(doc_title) LIKE LOWER('%{search_query}%')
                ORDER BY 
                    CASE WHEN competitive_impact = 'High' THEN 1 ELSE 2 END,
                    publication_date DESC
            """
            
            try:
                results = session.sql(sql).to_pandas()
                
                if len(results) > 0:
                    st.success(f"Found {len(results)} relevant documents")
                    
                    for _, row in results.iterrows():
                        with st.container():
                            col1, col2 = st.columns([3, 1])
                            with col1:
                                st.markdown(f"### {row['DOC_TITLE']}")
                                st.markdown(f"**{row['DOC_TYPE']}** | {row['TARGET_GENE']} | {row['THERAPEUTIC_AREA']}")
                            with col2:
                                impact_color = "🔴" if row['COMPETITIVE_IMPACT'] == 'High' else "🟡"
                                st.markdown(f"{impact_color} **{row['COMPETITIVE_IMPACT']} Impact**")
                            
                            st.markdown(f"**Key Finding:** {row['KEY_FINDING']}")
                            st.markdown(f"**Recommended Action:** {row['RECOMMENDED_ACTION']}")
                            st.divider()
                else:
                    st.warning("No documents found. Try a different search term.")
                    
            except Exception as e:
                st.error(f"Search error: {e}")
    
    # Show all documents
    with st.expander("View All Research Documents"):
        all_docs = session.sql("""
            SELECT 
                doc_title,
                doc_type,
                target_gene,
                therapeutic_area,
                competitive_impact,
                action_required
            FROM LIFEARC_POC.AI_DEMO.RESEARCH_INTELLIGENCE
            ORDER BY publication_date DESC
        """).to_pandas()
        st.dataframe(all_docs, use_container_width=True, hide_index=True)


# ============================================
# SECTION: Executive Dashboard
# ============================================
elif demo_mode == "Executive Dashboard":
    st.header("📊 Executive Pipeline Dashboard")
    
    # KPI Row
    col1, col2, col3, col4 = st.columns(4)
    
    # Get summary stats
    stats = session.sql("""
        SELECT 
            (SELECT COUNT(*) FROM LIFEARC_POC.AI_DEMO.COMPOUND_PIPELINE_ANALYSIS) as total_compounds,
            (SELECT COUNT(*) FROM LIFEARC_POC.AI_DEMO.CLINICAL_TRIAL_PERFORMANCE WHERE status = 'Active') as active_trials,
            (SELECT ROUND(SUM(total_investment_millions), 0) FROM LIFEARC_POC.AI_DEMO.PROGRAM_ROI_SUMMARY) as total_investment,
            (SELECT ROUND(AVG(roi_multiple), 1) FROM LIFEARC_POC.AI_DEMO.PROGRAM_ROI_SUMMARY) as avg_roi
    """).collect()[0]
    
    with col1:
        st.metric("Total Compounds", stats['TOTAL_COMPOUNDS'])
    with col2:
        st.metric("Active Trials", stats['ACTIVE_TRIALS'])
    with col3:
        st.metric("Total Investment", f"${stats['TOTAL_INVESTMENT']}M")
    with col4:
        st.metric("Avg ROI Multiple", f"{stats['AVG_ROI']}x")
    
    st.divider()
    
    # Two-column layout
    col1, col2 = st.columns(2)
    
    with col1:
        st.subheader("Drug-Likeness by Therapeutic Area")
        dl_data = session.sql("""
            SELECT 
                therapeutic_area,
                drug_likeness,
                COUNT(*) as count
            FROM LIFEARC_POC.AI_DEMO.COMPOUND_PIPELINE_ANALYSIS
            GROUP BY therapeutic_area, drug_likeness
            ORDER BY therapeutic_area, drug_likeness
        """).to_pandas()
        st.dataframe(dl_data, use_container_width=True, hide_index=True)
    
    with col2:
        st.subheader("Program ROI Summary")
        roi_data = session.sql("""
            SELECT 
                program_name,
                therapeutic_area,
                roi_multiple,
                recommendation
            FROM LIFEARC_POC.AI_DEMO.PROGRAM_ROI_SUMMARY
            ORDER BY roi_multiple DESC
        """).to_pandas()
        st.dataframe(roi_data, use_container_width=True, hide_index=True)
    
    st.divider()
    
    # Board Priorities
    st.subheader("🎯 Board Priority Candidates")
    
    priorities = session.sql("""
        SELECT 
            board_recommendation,
            compound_name,
            target_gene,
            predicted_success_pct,
            competitive_position,
            peak_sales_millions,
            investment_required_millions
        FROM LIFEARC_POC.AI_DEMO.BOARD_CANDIDATE_SCORECARD
        WHERE board_recommendation IN ('Priority 1', 'Priority 2', 'Priority 3')
        ORDER BY board_recommendation
    """).to_pandas()
    
    for _, row in priorities.iterrows():
        with st.container():
            cols = st.columns([1, 2, 1, 1, 1])
            cols[0].markdown(f"**{row['BOARD_RECOMMENDATION']}**")
            cols[1].markdown(f"{row['COMPOUND_NAME']} ({row['TARGET_GENE']})")
            cols[2].markdown(f"{row['PREDICTED_SUCCESS_PCT']}% success")
            cols[3].markdown(f"{row['COMPETITIVE_POSITION']}")
            cols[4].markdown(f"${row['PEAK_SALES_MILLIONS']}M peak")


# Footer
st.sidebar.divider()
st.sidebar.markdown("---")
st.sidebar.markdown("**LifeArc POC**")
st.sidebar.markdown("Snowflake Intelligence Demo")
st.sidebar.markdown("*Schema: LIFEARC_POC.AI_DEMO*")
