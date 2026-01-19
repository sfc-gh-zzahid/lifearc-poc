"""
LifeArc POC - Demo 4: Unstructured & Semi-Structured Data Handling
Demonstrates Snowflake capabilities for life sciences data types:
- FASTA/FASTQ genomic sequences
- SDF molecular structures
- JSON clinical trial data
- Text processing with Cortex LLM
"""

import streamlit as st
from snowflake.snowpark.context import get_active_session
import pandas as pd
import json
import re

# Page config
st.set_page_config(
    page_title="LifeArc - Unstructured Data Demo",
    page_icon="🧬",
    layout="wide"
)

# Get Snowflake session
session = get_active_session()

# Header
st.title("🧬 LifeArc: Unstructured Data Management")
st.markdown("*Demonstrating Snowflake capabilities for life sciences data types*")

# Sidebar navigation
st.sidebar.title("Navigation")
demo_section = st.sidebar.radio(
    "Select Demo",
    ["Overview", "FASTA/FASTQ Processing", "Molecular Data (SDF)", 
     "Clinical Trial JSON", "Cortex LLM Analysis", "Cortex Search"]
)

# ============================================
# SECTION: Overview
# ============================================
if demo_section == "Overview":
    st.header("Unstructured Data Capabilities")
    
    col1, col2 = st.columns(2)
    
    with col1:
        st.subheader("Data Types Covered")
        st.markdown("""
        | Data Type | Format | Use Case |
        |-----------|--------|----------|
        | **Genomics** | FASTA, FASTQ | Sequencing data, gene analysis |
        | **Molecular** | SDF, MOL | Drug discovery, compound libraries |
        | **Clinical** | JSON, HL7 FHIR | Trial protocols, patient data |
        | **Documents** | PDF, TXT | Research papers, reports |
        | **Imaging** | NIfTI, DICOM | Medical imaging metadata |
        """)
    
    with col2:
        st.subheader("Snowflake Features")
        st.markdown("""
        - **Stages**: Store unstructured files at scale
        - **Directory Tables**: Metadata management
        - **Snowpark**: Python UDFs for file parsing
        - **Cortex LLM**: AI-powered text analysis
        - **Cortex Search**: Semantic search across documents
        - **VARIANT**: Semi-structured JSON/XML handling
        """)
    
    st.info("""
    **Architecture Pattern**: Files stored in Snowflake internal stages with metadata 
    in structured tables. Snowpark UDFs parse files on-demand, while Cortex provides 
    AI capabilities for text analysis and semantic search.
    """)

# ============================================
# SECTION: FASTA/FASTQ Processing
# ============================================
elif demo_section == "FASTA/FASTQ Processing":
    st.header("🧬 Genomic Sequence Processing")
    
    st.markdown("""
    ### Architecture Pattern
    ```
    ┌─────────────┐    ┌──────────────┐    ┌─────────────────┐
    │ FASTA/FASTQ │───>│ Snowflake    │───>│ Metadata Table  │
    │ Files       │    │ Stage        │    │ (searchable)    │
    └─────────────┘    └──────────────┘    └─────────────────┘
                              │
                              ▼
                       ┌──────────────┐
                       │ Snowpark UDF │
                       │ (Parser)     │
                       └──────────────┘
    ```
    """)
    
    tab1, tab2, tab3 = st.tabs(["Sample Data", "Parsing UDF", "Query Sequences"])
    
    with tab1:
        st.subheader("Sample FASTA Data")
        # Create sample table
        setup_sql = """
        CREATE TABLE IF NOT EXISTS LIFEARC_POC.UNSTRUCTURED_DATA.GENE_SEQUENCES (
            sequence_id VARCHAR,
            gene_name VARCHAR,
            organism VARCHAR,
            description VARCHAR,
            sequence TEXT,
            sequence_length INTEGER,
            gc_content FLOAT,
            created_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
        )
        """
        
        if st.button("Setup Sequence Table"):
            try:
                session.sql(setup_sql).collect()
                st.success("Table created successfully!")
            except Exception as e:
                st.error(f"Error: {e}")
        
        # Sample data
        sample_fasta = """
>GENE_BRCA1_HUMAN | Human BRCA1 gene | DNA repair protein
ATGGATTTATCTGCTCTTCGCGTTGAAGAAGTACAAAATGTCATTAATGCTATGCAGAAA
ATCTTAGAGTGTCCCATCTGTCTGGAGTTGATCAAGGAACCTGTCTCCACAAAGTGTGAC
>GENE_TP53_HUMAN | Human TP53 gene | Tumor protein p53  
ATGGAGGAGCCGCAGTCAGATCCTAGCGTCGAGCCCCCTCTGAGTCAGGAAACATTTTCA
GACCTATGGAAACTACTTCCTGAAAACAACGTTCTGTCCCCCTTGCCGTCCCAAGCAATG
        """
        st.code(sample_fasta, language="text")
    
    with tab2:
        st.subheader("FASTA Parser UDF")
        st.markdown("Snowpark Python UDF to parse FASTA format and calculate metrics:")
        
        udf_code = '''
CREATE OR REPLACE FUNCTION LIFEARC_POC.UNSTRUCTURED_DATA.PARSE_FASTA(fasta_content VARCHAR)
RETURNS TABLE (
    sequence_id VARCHAR,
    gene_name VARCHAR, 
    description VARCHAR,
    sequence VARCHAR,
    seq_length INTEGER,
    gc_content FLOAT
)
LANGUAGE PYTHON
RUNTIME_VERSION = '3.11'
HANDLER = 'FastaParser'
AS $$
class FastaParser:
    def process(self, fasta_content):
        sequences = []
        current_id = None
        current_seq = []
        current_desc = ""
        
        for line in fasta_content.strip().split('\\n'):
            if line.startswith('>'):
                if current_id:
                    seq = ''.join(current_seq)
                    gc = self.calc_gc(seq)
                    gene = current_id.split('_')[1] if '_' in current_id else current_id
                    sequences.append((current_id, gene, current_desc, seq, len(seq), gc))
                
                parts = line[1:].split('|')
                current_id = parts[0].strip()
                current_desc = parts[1].strip() if len(parts) > 1 else ""
                current_seq = []
            else:
                current_seq.append(line.strip())
        
        # Last sequence
        if current_id:
            seq = ''.join(current_seq)
            gc = self.calc_gc(seq)
            gene = current_id.split('_')[1] if '_' in current_id else current_id
            sequences.append((current_id, gene, current_desc, seq, len(seq), gc))
        
        return sequences
    
    def calc_gc(self, seq):
        if not seq:
            return 0.0
        gc = sum(1 for c in seq.upper() if c in 'GC')
        return round(gc / len(seq) * 100, 2)
$$;
'''
        st.code(udf_code, language="sql")
        
        if st.button("Create Parser UDF"):
            try:
                session.sql(udf_code).collect()
                st.success("UDF created successfully!")
            except Exception as e:
                st.error(f"Error: {e}")
    
    with tab3:
        st.subheader("Query Parsed Sequences")
        
        # Demo query
        query = """
        SELECT 
            sequence_id,
            gene_name,
            description,
            seq_length AS sequence_length,
            gc_content,
            SUBSTRING(sequence, 1, 50) || '...' AS sequence_preview
        FROM TABLE(LIFEARC_POC.UNSTRUCTURED_DATA.PARSE_FASTA(
            '>GENE_BRCA1_HUMAN | Human BRCA1 gene | DNA repair protein
ATGGATTTATCTGCTCTTCGCGTTGAAGAAGTACAAAATGTCATTAATGCTATGCAGAAAATCTTAGAGTGTCCCATCTGTCTGGAGTTGATCAAGGAACCTGTCTCCACAAAGTGTGAC
>GENE_TP53_HUMAN | Human TP53 gene | Tumor protein p53
ATGGAGGAGCCGCAGTCAGATCCTAGCGTCGAGCCCCCTCTGAGTCAGGAAACATTTTCAGACCTATGGAAACTACTTCCTGAAAACAACGTTCTGTCCCCCTTGCCGTCCCAAGCAATG'
        ))
        """
        
        st.code(query, language="sql")
        
        if st.button("Run Query"):
            try:
                result = session.sql(query).to_pandas()
                st.dataframe(result, use_container_width=True)
            except Exception as e:
                st.error(f"Error: {e}")

# ============================================
# SECTION: Molecular Data (SDF)
# ============================================
elif demo_section == "Molecular Data (SDF)":
    st.header("⚗️ Molecular Structure Data (SDF)")
    
    st.markdown("""
    ### Use Case: Drug Discovery Compound Libraries
    Store molecular structures with properties for virtual screening and analysis.
    """)
    
    tab1, tab2 = st.tabs(["Schema Design", "Query Molecules"])
    
    with tab1:
        st.subheader("Compound Library Schema")
        
        schema_sql = """
CREATE TABLE IF NOT EXISTS LIFEARC_POC.UNSTRUCTURED_DATA.COMPOUND_LIBRARY (
    compound_id VARCHAR PRIMARY KEY,
    molecule_name VARCHAR,
    smiles VARCHAR,
    mol_block TEXT,                    -- Full SDF MOL block
    properties VARIANT,                -- Flexible properties as JSON
    molecular_weight FLOAT,
    molecular_formula VARCHAR,
    therapeutic_class VARCHAR,
    mechanism VARCHAR,
    created_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    updated_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

-- Sample insert with VARIANT properties
INSERT INTO LIFEARC_POC.UNSTRUCTURED_DATA.COMPOUND_LIBRARY 
(compound_id, molecule_name, smiles, molecular_weight, molecular_formula, 
 therapeutic_class, mechanism, properties)
SELECT 
    'LA-001',
    'Aspirin',
    'CC(=O)OC1=CC=CC=C1C(=O)O',
    180.16,
    'C9H8O4',
    'Anti-inflammatory',
    'COX-1 and COX-2 inhibitor',
    PARSE_JSON('{
        "logP": 1.19,
        "num_h_donors": 1,
        "num_h_acceptors": 4,
        "rotatable_bonds": 3,
        "tpsa": 63.6,
        "lipinski_violations": 0
    }');
        """
        st.code(schema_sql, language="sql")
        
        if st.button("Create Compound Library"):
            try:
                for stmt in schema_sql.split(';'):
                    if stmt.strip():
                        session.sql(stmt).collect()
                st.success("Compound library created!")
            except Exception as e:
                st.error(f"Error: {e}")
    
    with tab2:
        st.subheader("Query Compounds")
        
        query_options = st.selectbox(
            "Select Query",
            ["View All Compounds", "Filter by Properties", "Lipinski Rule of 5"]
        )
        
        if query_options == "View All Compounds":
            query = """
            SELECT 
                compound_id,
                molecule_name,
                smiles,
                molecular_weight,
                therapeutic_class,
                properties:logP::FLOAT AS logP,
                properties:tpsa::FLOAT AS tpsa
            FROM LIFEARC_POC.UNSTRUCTURED_DATA.COMPOUND_LIBRARY
            """
        elif query_options == "Filter by Properties":
            query = """
            SELECT 
                compound_id,
                molecule_name,
                molecular_weight,
                properties:logP::FLOAT AS logP,
                properties:num_h_donors::INT AS h_donors,
                properties:num_h_acceptors::INT AS h_acceptors
            FROM LIFEARC_POC.UNSTRUCTURED_DATA.COMPOUND_LIBRARY
            WHERE properties:logP::FLOAT < 5
              AND properties:num_h_donors::INT <= 5
            """
        else:
            query = """
            -- Lipinski Rule of 5 compliance check
            SELECT 
                compound_id,
                molecule_name,
                molecular_weight,
                properties:logP::FLOAT AS logP,
                properties:num_h_donors::INT AS h_donors,
                properties:num_h_acceptors::INT AS h_acceptors,
                CASE 
                    WHEN molecular_weight <= 500 
                     AND properties:logP::FLOAT <= 5
                     AND properties:num_h_donors::INT <= 5
                     AND properties:num_h_acceptors::INT <= 10
                    THEN 'COMPLIANT'
                    ELSE 'NON-COMPLIANT'
                END AS lipinski_status
            FROM LIFEARC_POC.UNSTRUCTURED_DATA.COMPOUND_LIBRARY
            """
        
        st.code(query, language="sql")
        
        if st.button("Run Molecule Query"):
            try:
                result = session.sql(query).to_pandas()
                st.dataframe(result, use_container_width=True)
            except Exception as e:
                st.error(f"Error: {e}")

# ============================================
# SECTION: Clinical Trial JSON
# ============================================
elif demo_section == "Clinical Trial JSON":
    st.header("📋 Semi-Structured Clinical Trial Data")
    
    st.markdown("""
    ### Use Case: Clinical Trial Protocol Management
    Store and query complex nested JSON structures using Snowflake VARIANT type.
    """)
    
    tab1, tab2, tab3 = st.tabs(["Store Protocol", "Query JSON", "Flatten Data"])
    
    with tab1:
        st.subheader("Clinical Trial Schema")
        
        schema_sql = """
CREATE TABLE IF NOT EXISTS LIFEARC_POC.UNSTRUCTURED_DATA.CLINICAL_TRIALS (
    trial_id VARCHAR PRIMARY KEY,
    protocol_data VARIANT,
    created_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

-- Insert sample protocol
INSERT INTO LIFEARC_POC.UNSTRUCTURED_DATA.CLINICAL_TRIALS (trial_id, protocol_data)
SELECT 'LA-2024-001', PARSE_JSON($$ 
{
  "title": "Phase II Clinical Trial - Novel KRAS G12C Inhibitor in NSCLC",
  "sponsor": "LifeArc Research",
  "status": "Active",
  "phase": "Phase II",
  "indication": "Non-Small Cell Lung Cancer",
  "enrollment": {"target": 120, "current": 87, "sites": 12},
  "primary_endpoints": ["Objective Response Rate", "Duration of Response"],
  "arms": [
    {"name": "Arm A", "intervention": "LA-KRAS-001 200mg BID", "patients": 60},
    {"name": "Arm B", "intervention": "LA-KRAS-001 400mg QD", "patients": 60}
  ],
  "biomarkers": ["ctDNA KRAS G12C VAF", "PD-L1 expression", "TMB score"]
}
$$);
        """
        
        st.code(schema_sql, language="sql")
        
        if st.button("Create Clinical Trial Table"):
            try:
                for stmt in schema_sql.split(';'):
                    if stmt.strip():
                        session.sql(stmt).collect()
                st.success("Clinical trial data loaded!")
            except Exception as e:
                st.error(f"Error: {e}")
    
    with tab2:
        st.subheader("Query Nested JSON")
        
        queries = {
            "Basic Protocol Info": """
SELECT 
    trial_id,
    protocol_data:title::VARCHAR AS title,
    protocol_data:phase::VARCHAR AS phase,
    protocol_data:status::VARCHAR AS status,
    protocol_data:indication::VARCHAR AS indication
FROM LIFEARC_POC.UNSTRUCTURED_DATA.CLINICAL_TRIALS
            """,
            "Enrollment Progress": """
SELECT 
    trial_id,
    protocol_data:enrollment.target::INT AS target_enrollment,
    protocol_data:enrollment.current::INT AS current_enrollment,
    protocol_data:enrollment.sites::INT AS active_sites,
    ROUND(protocol_data:enrollment.current / protocol_data:enrollment.target * 100, 1) 
        AS enrollment_pct
FROM LIFEARC_POC.UNSTRUCTURED_DATA.CLINICAL_TRIALS
            """,
            "Array Access - Endpoints": """
SELECT 
    trial_id,
    protocol_data:primary_endpoints[0]::VARCHAR AS primary_endpoint_1,
    protocol_data:primary_endpoints[1]::VARCHAR AS primary_endpoint_2,
    ARRAY_SIZE(protocol_data:biomarkers) AS num_biomarkers
FROM LIFEARC_POC.UNSTRUCTURED_DATA.CLINICAL_TRIALS
            """
        }
        
        selected_query = st.selectbox("Select Query Type", list(queries.keys()))
        st.code(queries[selected_query], language="sql")
        
        if st.button("Run JSON Query"):
            try:
                result = session.sql(queries[selected_query]).to_pandas()
                st.dataframe(result, use_container_width=True)
            except Exception as e:
                st.error(f"Error: {e}")
    
    with tab3:
        st.subheader("Flatten Nested Arrays")
        
        flatten_sql = """
-- Flatten treatment arms into rows
SELECT 
    ct.trial_id,
    ct.protocol_data:title::VARCHAR AS trial_title,
    arm.value:name::VARCHAR AS arm_name,
    arm.value:intervention::VARCHAR AS intervention,
    arm.value:patients::INT AS planned_patients
FROM LIFEARC_POC.UNSTRUCTURED_DATA.CLINICAL_TRIALS ct,
LATERAL FLATTEN(input => ct.protocol_data:arms) arm
        """
        
        st.code(flatten_sql, language="sql")
        
        if st.button("Flatten Arms"):
            try:
                result = session.sql(flatten_sql).to_pandas()
                st.dataframe(result, use_container_width=True)
            except Exception as e:
                st.error(f"Error: {e}")

# ============================================
# SECTION: Cortex LLM Analysis
# ============================================
elif demo_section == "Cortex LLM Analysis":
    st.header("🤖 Cortex LLM for Document Analysis")
    
    st.markdown("""
    ### Use Case: Research Document Intelligence
    Use Snowflake Cortex to analyze, summarize, and extract insights from research documents.
    """)
    
    tab1, tab2, tab3 = st.tabs(["Summarization", "Entity Extraction", "Q&A"])
    
    sample_abstract = """
    Discovery and Characterization of Novel Small Molecule Inhibitors of BRCA1-Associated DNA Repair Pathways.
    
    We conducted a high-throughput phenotypic screen of 250,000 compounds using isogenic BRCA1-wild type 
    and BRCA1-deficient cell lines. From our primary screen, we identified 847 initial hits (0.34% hit rate). 
    After stringent validation, 12 lead compounds emerged with selective cytotoxicity in BRCA1-mutant cells 
    (>10-fold selectivity) and IC50 values ranging from 50nM to 500nM.
    
    Target identification revealed three compounds (LA-DDR-001, LA-DDR-007, LA-DDR-012) engage a previously 
    uncharacterized member of the RAD51 paralog family. LA-DDR-012 was nominated as development candidate 
    based on best-in-class potency (IC50 = 52nM) and >100-fold selectivity over BRCA1-WT cells.
    
    IND-enabling studies planned for Q2 2025. First-in-human study planned for Q4 2025.
    """
    
    with tab1:
        st.subheader("Document Summarization")
        
        st.text_area("Research Abstract", sample_abstract, height=200, disabled=True)
        
        summary_sql = f"""
SELECT SNOWFLAKE.CORTEX.COMPLETE(
    'llama3.1-70b',
    'Summarize this research abstract in 3 bullet points for a scientific audience:

{sample_abstract}'
) AS summary
        """
        
        if st.button("Generate Summary"):
            try:
                result = session.sql(summary_sql).collect()
                st.success("Summary Generated:")
                st.markdown(result[0]['SUMMARY'])
            except Exception as e:
                st.error(f"Error: {e}")
    
    with tab2:
        st.subheader("Named Entity Extraction")
        
        extraction_sql = f"""
SELECT SNOWFLAKE.CORTEX.COMPLETE(
    'llama3.1-70b',
    'Extract the following entities from this research text and return as JSON:
- Compound IDs (list)
- Target protein/gene
- IC50 values
- Key milestones with dates

Text: {sample_abstract}

Return only valid JSON.'
) AS entities
        """
        
        if st.button("Extract Entities"):
            try:
                result = session.sql(extraction_sql).collect()
                st.success("Extracted Entities:")
                st.json(result[0]['ENTITIES'])
            except Exception as e:
                st.error(f"Error: {e}")
    
    with tab3:
        st.subheader("Question Answering")
        
        user_question = st.text_input(
            "Ask a question about the research:",
            value="What is the selectivity of the lead compound over wild-type cells?"
        )
        
        qa_sql = f"""
SELECT SNOWFLAKE.CORTEX.COMPLETE(
    'llama3.1-70b',
    'Based on this research abstract, answer the following question concisely:

Abstract: {sample_abstract}

Question: {user_question}

Answer:'
) AS answer
        """
        
        if st.button("Get Answer"):
            try:
                result = session.sql(qa_sql).collect()
                st.success("Answer:")
                st.write(result[0]['ANSWER'])
            except Exception as e:
                st.error(f"Error: {e}")

# ============================================
# SECTION: Cortex Search
# ============================================
elif demo_section == "Cortex Search":
    st.header("🔍 Cortex Search - Semantic Document Search")
    
    st.markdown("""
    ### Use Case: Research Knowledge Base
    Build a semantic search service over research documents, protocols, and reports.
    """)
    
    tab1, tab2 = st.tabs(["Setup Search Service", "Search Demo"])
    
    with tab1:
        st.subheader("Create Cortex Search Service")
        
        setup_sql = """
-- Step 1: Create documents table
CREATE TABLE IF NOT EXISTS LIFEARC_POC.UNSTRUCTURED_DATA.RESEARCH_DOCUMENTS (
    doc_id VARCHAR PRIMARY KEY,
    doc_type VARCHAR,
    title VARCHAR,
    content TEXT,
    authors VARCHAR,
    created_date DATE,
    tags ARRAY
);

-- Step 2: Load sample documents (using SELECT UNION ALL pattern for Snowflake)
INSERT INTO LIFEARC_POC.UNSTRUCTURED_DATA.RESEARCH_DOCUMENTS 
SELECT 'DOC001', 'Abstract', 'Novel BRCA1 DDR Inhibitors', 
 'Discovery of small molecule inhibitors targeting BRCA1-associated DNA repair pathways. We conducted a high-throughput phenotypic screen of 250,000 compounds.', 
 'Mitchell S, Chen J, Roberts E', '2024-11-01', ARRAY_CONSTRUCT('DDR', 'BRCA1', 'oncology')
UNION ALL
SELECT 'DOC002', 'Protocol', 'KRAS G12C Phase II Trial', 
 'Phase II clinical trial evaluating novel KRAS G12C inhibitor in NSCLC patients. The study will enroll 120 patients.', 
 'LifeArc Clinical Team', '2024-03-15', ARRAY_CONSTRUCT('KRAS', 'NSCLC', 'clinical');

-- Step 3: Create Cortex Search Service
CREATE OR REPLACE CORTEX SEARCH SERVICE LIFEARC_POC.UNSTRUCTURED_DATA.RESEARCH_SEARCH_SERVICE
ON content
WAREHOUSE = DEMO_WH
TARGET_LAG = '1 hour'
AS (
    SELECT 
        doc_id,
        doc_type,
        title,
        content,
        authors,
        created_date
    FROM LIFEARC_POC.UNSTRUCTURED_DATA.RESEARCH_DOCUMENTS
);
        """
        
        st.code(setup_sql, language="sql")
        
        if st.button("Setup Search Service"):
            try:
                for stmt in setup_sql.split(';'):
                    if stmt.strip():
                        session.sql(stmt).collect()
                st.success("Cortex Search Service created!")
            except Exception as e:
                st.error(f"Error: {e}")
    
    with tab2:
        st.subheader("Semantic Search")
        
        search_query = st.text_input(
            "Search research documents:",
            value="DNA repair pathway inhibitors"
        )
        
        # Alternative: Use Cortex LLM for semantic search when Cortex Search isn't available
        st.markdown("""
        **Option 1: Cortex Search Service (requires setup)**
        ```sql
        -- After creating the search service, query it:
        SELECT * FROM TABLE(
            SNOWFLAKE.CORTEX.SEARCH(
                'LIFEARC_POC.UNSTRUCTURED_DATA.RESEARCH_SEARCH_SERVICE',
                '{query: "DNA repair inhibitors", limit: 5}'
            )
        );
        ```
        
        **Option 2: Cortex LLM for similarity search (works now)**
        """)
        
        search_sql = f"""
-- Semantic search using Cortex LLM
SELECT 
    doc_id,
    title,
    doc_type,
    authors,
    SUBSTRING(content, 1, 200) AS content_preview,
    SNOWFLAKE.CORTEX.COMPLETE(
        'llama3.1-8b',
        'Rate the relevance (0-10) of this document to the query "{search_query}". 
        Document: ' || content || '
        Return only the number.'
    ) AS relevance_score
FROM LIFEARC_POC.UNSTRUCTURED_DATA.RESEARCH_DOCUMENTS
ORDER BY relevance_score DESC
        """
        
        st.code(search_sql, language="sql")
        
        if st.button("Search"):
            try:
                result = session.sql(search_sql).to_pandas()
                st.success("Search Results:")
                st.dataframe(result, use_container_width=True)
            except Exception as e:
                st.warning("Note: Ensure Cortex LLM is available in your account.")
                st.error(f"Error: {e}")

# Footer
st.sidebar.markdown("---")
st.sidebar.markdown("**LifeArc POC - Demo 4**")
st.sidebar.markdown("Snowflake Unstructured Data")
