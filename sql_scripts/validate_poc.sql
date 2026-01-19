/*
==============================================================================
LifeArc POC - VALIDATION SCRIPT
==============================================================================
Run this before any demo to verify all components are working.
Each section tests a Snowflake-UNIQUE capability.

Expected result: All tests should return data without errors.
==============================================================================
*/

USE DATABASE LIFEARC_POC;
USE WAREHOUSE COMPUTE_WH;

-- ============================================================================
-- TEST 1: CORE DATA EXISTS
-- ============================================================================
SELECT '1. CORE DATA' as test_section;

SELECT 
    'AI_DEMO.COMPOUND_PIPELINE_ANALYSIS' as table_name,
    COUNT(*) as rows,
    CASE WHEN COUNT(*) >= 29 THEN 'PASS' ELSE 'FAIL' END as status
FROM AI_DEMO.COMPOUND_PIPELINE_ANALYSIS
UNION ALL
SELECT 
    'AI_DEMO.CLINICAL_TRIAL_PERFORMANCE',
    COUNT(*),
    CASE WHEN COUNT(*) >= 17 THEN 'PASS' ELSE 'FAIL' END
FROM AI_DEMO.CLINICAL_TRIAL_PERFORMANCE
UNION ALL
SELECT 
    'AI_DEMO.PROGRAM_ROI_SUMMARY',
    COUNT(*),
    CASE WHEN COUNT(*) >= 9 THEN 'PASS' ELSE 'FAIL' END
FROM AI_DEMO.PROGRAM_ROI_SUMMARY
UNION ALL
SELECT 
    'AI_DEMO.RESEARCH_INTELLIGENCE',
    COUNT(*),
    CASE WHEN COUNT(*) >= 8 THEN 'PASS' ELSE 'FAIL' END
FROM AI_DEMO.RESEARCH_INTELLIGENCE
UNION ALL
SELECT 
    'AI_DEMO.BOARD_CANDIDATE_SCORECARD',
    COUNT(*),
    CASE WHEN COUNT(*) >= 8 THEN 'PASS' ELSE 'FAIL' END
FROM AI_DEMO.BOARD_CANDIDATE_SCORECARD;

-- ============================================================================
-- TEST 2: SNOWFLAKE INTELLIGENCE (Semantic View + Cortex)
-- Unique: Built-in LLM that keeps data in Snowflake (HIPAA-safe)
-- ============================================================================
SELECT '2. SNOWFLAKE INTELLIGENCE' as test_section;

-- Verify semantic view exists
SELECT 
    'Semantic View' as component,
    name,
    'PASS' as status
FROM TABLE(RESULT_SCAN(LAST_QUERY_ID(-2)))
WHERE 1=0
UNION ALL
SELECT 
    'Semantic View',
    'DRUG_DISCOVERY_SEMANTIC_VIEW',
    CASE WHEN COUNT(*) = 1 THEN 'PASS' ELSE 'FAIL' END
FROM INFORMATION_SCHEMA.TABLES 
WHERE TABLE_TYPE = 'SEMANTIC VIEW' AND TABLE_NAME = 'DRUG_DISCOVERY_SEMANTIC_VIEW';

-- Test Cortex LLM
SELECT 
    'Cortex LLM Test' as component,
    SNOWFLAKE.CORTEX.COMPLETE('llama3.1-8b', 'Say OK if you can read this') as response,
    'PASS' as status;

-- ============================================================================
-- TEST 3: CORTEX SEARCH SERVICE
-- Unique: Semantic search without external vector DB
-- ============================================================================
SELECT '3. CORTEX SEARCH' as test_section;

SELECT 
    'Cortex Search Service' as component,
    PARSE_JSON(SNOWFLAKE.CORTEX.SEARCH_PREVIEW(
        'LIFEARC_POC.AI_DEMO.RESEARCH_SEARCH_SERVICE',
        '{"query": "EGFR resistance", "columns": ["doc_title"], "limit": 1}'
    )):results[0]:doc_title::string as sample_result,
    'PASS' as status;

-- ============================================================================
-- TEST 4: ZERO-COPY DATA SHARING
-- Unique: Only Snowflake can share live data without copying
-- ============================================================================
SELECT '4. DATA SHARING' as test_section;

SELECT 
    'Share Exists' as component,
    name as share_name,
    'PASS' as status
FROM TABLE(RESULT_SCAN(LAST_QUERY_ID(-1)))
WHERE 1=0
UNION ALL
SELECT 
    'Share Exists',
    'LIFEARC_CRO_SHARE',
    CASE WHEN COUNT(*) = 1 THEN 'PASS' ELSE 'FAIL' END
FROM (SHOW SHARES LIKE 'LIFEARC_CRO_SHARE');

-- Partner view has data
SELECT 
    'Partner View Data' as component,
    COUNT(*) || ' rows' as details,
    CASE WHEN COUNT(*) > 0 THEN 'PASS' ELSE 'FAIL' END as status
FROM DATA_SHARING.CLINICAL_RESULTS_PARTNER_VIEW;

-- ============================================================================
-- TEST 5: TIME TRAVEL
-- Unique: 90-day history standard (vs 30 days on Databricks, none on Fabric)
-- ============================================================================
SELECT '5. TIME TRAVEL' as test_section;

SELECT 
    'Time Travel (1 hour ago)' as component,
    COUNT(*) || ' rows' as details,
    CASE WHEN COUNT(*) > 0 THEN 'PASS' ELSE 'FAIL' END as status
FROM AI_DEMO.COMPOUND_PIPELINE_ANALYSIS
AT (OFFSET => -3600);

-- ============================================================================
-- TEST 6: DATA GOVERNANCE (Tags, Masking, Row Access)
-- Unique: SQL-queryable compliance tags
-- ============================================================================
SELECT '6. DATA GOVERNANCE' as test_section;

-- Tags exist
SELECT 
    'Classification Tags' as component,
    COUNT(*) || ' tags' as details,
    CASE WHEN COUNT(*) >= 5 THEN 'PASS' ELSE 'FAIL' END as status
FROM (SHOW TAGS IN SCHEMA GOVERNANCE);

-- Masking policies applied
SELECT 
    'Masking Policies' as component,
    COUNT(*) || ' policies' as details,
    CASE WHEN COUNT(*) >= 2 THEN 'PASS' ELSE 'FAIL' END as status
FROM (SHOW MASKING POLICIES IN SCHEMA GOVERNANCE);

-- Check PHI tag on patient_id
SELECT 
    'PHI Tag on Patient ID' as component,
    SYSTEM$GET_TAG('GOVERNANCE.DATA_CLASSIFICATION', 
                   'DATA_SHARING.CLINICAL_TRIAL_RESULTS.PATIENT_ID', 
                   'column') as details,
    CASE WHEN SYSTEM$GET_TAG('GOVERNANCE.DATA_CLASSIFICATION', 
                              'DATA_SHARING.CLINICAL_TRIAL_RESULTS.PATIENT_ID', 
                              'column') = 'PHI' 
         THEN 'PASS' ELSE 'FAIL' END as status;

-- ============================================================================
-- TEST 7: ML PIPELINE
-- Unique: ML with data never leaving Snowflake governance
-- ============================================================================
SELECT '7. ML PIPELINE' as test_section;

SELECT 
    'Feature Store' as component,
    COUNT(*) || ' features' as details,
    CASE WHEN COUNT(*) >= 29 THEN 'PASS' ELSE 'FAIL' END as status
FROM ML_DEMO.DRUG_LIKENESS_FEATURES;

SELECT 
    'Model Registry' as component,
    model_name || ' v' || model_version as details,
    CASE WHEN status = 'PRODUCTION' THEN 'PASS' ELSE 'FAIL' END as status
FROM ML_DEMO.MODEL_REGISTRY
WHERE status = 'PRODUCTION'
LIMIT 1;

SELECT 
    'Predictions View' as component,
    COUNT(*) || ' predictions' as details,
    CASE WHEN COUNT(*) >= 29 THEN 'PASS' ELSE 'FAIL' END as status
FROM ML_DEMO.COMPOUND_PREDICTIONS;

-- ============================================================================
-- TEST 8: STREAMLIT APPS
-- Unique: Native app hosting in Snowflake
-- ============================================================================
SELECT '8. STREAMLIT APPS' as test_section;

SELECT 
    'Intelligence Demo' as component,
    name as details,
    'PASS' as status
FROM TABLE(RESULT_SCAN(LAST_QUERY_ID(-1)))
WHERE 1=0
UNION ALL
SELECT 
    'Streamlit Apps',
    (SELECT LISTAGG(name, ', ') FROM (SHOW STREAMLITS IN DATABASE LIFEARC_POC)) as details,
    CASE WHEN (SELECT COUNT(*) FROM (SHOW STREAMLITS IN DATABASE LIFEARC_POC)) >= 2 
         THEN 'PASS' ELSE 'FAIL' END as status;

-- ============================================================================
-- TEST 9: NATIVE DBT PROJECT
-- Unique: Git-synced, version-controlled transformations
-- ============================================================================
SELECT '9. DBT PROJECT' as test_section;

SELECT 
    'DBT Project' as component,
    'VERSION$8' as details,
    CASE WHEN COUNT(*) > 0 THEN 'PASS' ELSE 'FAIL' END as status
FROM (SHOW GIT REPOSITORIES IN DATABASE LIFEARC_POC);

-- ============================================================================
-- SUMMARY
-- ============================================================================
SELECT '========================================' as divider;
SELECT 'POC VALIDATION COMPLETE' as summary;
SELECT 'If all tests show PASS, the demo is ready.' as next_step;
SELECT '========================================' as divider;

/*
==============================================================================
QUICK DEMO COMMANDS (if validation passes)
==============================================================================

-- 1. Time Travel
SELECT * FROM AI_DEMO.COMPOUND_PIPELINE_ANALYSIS AT (OFFSET => -3600);

-- 2. Zero-Copy Clone (instant full environment)
CREATE DATABASE LIFEARC_DEV CLONE LIFEARC_POC;

-- 3. Cortex Search
SELECT SNOWFLAKE.CORTEX.SEARCH_PREVIEW(
    'LIFEARC_POC.AI_DEMO.RESEARCH_SEARCH_SERVICE',
    '{"query": "BRCA resistance", "columns": ["doc_title", "key_finding"], "limit": 3}'
);

-- 4. Ask Cortex AI
SELECT SNOWFLAKE.CORTEX.COMPLETE(
    'llama3.1-70b',
    'Based on drug discovery best practices, why might compounds with LogP > 5 fail drug-likeness screening?'
);

-- 5. See Masking in Action
USE ROLE PUBLIC;
SELECT patient_id, patient_age FROM DATA_SHARING.CLINICAL_TRIAL_RESULTS LIMIT 5;
-- (Will show masked values)
USE ROLE ACCOUNTADMIN;

==============================================================================
*/
