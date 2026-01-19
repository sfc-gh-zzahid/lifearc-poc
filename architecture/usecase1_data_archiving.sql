/*
================================================================================
LIFEARC - USE CASE 1: ENTERPRISE DATA ARCHIVING ARCHITECTURE
================================================================================

Reference Architecture: Snowflake + Azure Blob Storage for Enterprise Archives

Current State:
- Platform: Ctera
- Volume: ~250TB and growing
- Mix of structured and unstructured data

Target State:
- Snowflake: Metadata, indexing, access control, search
- Azure Blob Storage: Cold/archive tier for large files
- Unified discovery and governance layer

================================================================================
*/


-- ============================================================================
-- ARCHITECTURE DIAGRAM (ASCII)
-- ============================================================================

/*
                                    ENTERPRISE DATA ARCHIVING ARCHITECTURE
    ┌─────────────────────────────────────────────────────────────────────────────────────────┐
    │                                                                                         │
    │   ┌─────────────────┐                         ┌──────────────────────────────────────┐ │
    │   │  Source Systems │                         │           AZURE BLOB STORAGE          │ │
    │   │                 │                         │                                       │ │
    │   │  • File Servers │                         │  ┌─────────┐  ┌─────────┐  ┌───────┐ │ │
    │   │  • SharePoint   │                         │  │   HOT   │  │  COOL   │  │ARCHIVE│ │ │
    │   │  • Lab Systems  │                         │  │  Tier   │  │  Tier   │  │ Tier  │ │ │
    │   │  • Research DBs │                         │  │ <30days │  │30d-180d │  │ >180d │ │ │
    │   └────────┬────────┘                         │  └─────────┘  └─────────┘  └───────┘ │ │
    │            │                                  │         ▲           ▲          ▲     │ │
    │            ▼                                  │         │ Lifecycle Policies   │     │ │
    │   ┌─────────────────┐                         │         └─────────────────────────┘  │ │
    │   │   Azure Data    │─────────────────────────│──────────────────────────────────────┘ │
    │   │    Factory      │      Large Files        │                                        │
    │   │  (Orchestrator) │                         │                                        │
    │   └────────┬────────┘                         │                                        │
    │            │                                  │                                        │
    │            │ Metadata + Small Files           │                                        │
    │            ▼                                  │                                        │
    │   ┌───────────────────────────────────────────────────────────────────────────────────┤
    │   │                              SNOWFLAKE                                            │
    │   │                                                                                   │
    │   │  ┌──────────────────┐  ┌──────────────────┐  ┌──────────────────────────────┐   │
    │   │  │  ARCHIVE_CATALOG │  │ EXTERNAL STAGES   │  │     SEARCH & DISCOVERY       │   │
    │   │  │  (Metadata Table)│  │ (Azure Blob Refs) │  │                              │   │
    │   │  │                  │  │                   │  │  • Cortex Search Service     │   │
    │   │  │  • file_path     │  │  @archive_hot     │  │  • Full-text indexing        │   │
    │   │  │  • file_size     │  │  @archive_cool    │  │  • Semantic search           │   │
    │   │  │  • checksum      │  │  @archive_archive │  │  • Tag-based filtering       │   │
    │   │  │  • created_date  │  │                   │  │                              │   │
    │   │  │  • data_owner    │  │                   │  └──────────────────────────────┘   │
    │   │  │  • retention     │  │                   │                                      │
    │   │  │  • tags (VARIANT)│  └───────────────────┘  ┌──────────────────────────────┐   │
    │   │  │  • content_hash  │                         │     ACCESS CONTROL           │   │
    │   │  │  • blob_url      │◄────────────────────────│                              │   │
    │   │  └──────────────────┘       Presigned URLs    │  • Row Access Policies       │   │
    │   │                                               │  • Masking Policies          │   │
    │   │                                               │  • Role Hierarchy            │   │
    │   │                                               │  • Audit Logging             │   │
    │   │                                               └──────────────────────────────┘   │
    │   │                                                                                   │
    │   └───────────────────────────────────────────────────────────────────────────────────┘
    │                                                                                         │
    │   ┌─────────────────────────────────────────────────────────────────────────────────┐ │
    │   │                                USER ACCESS                                       │ │
    │   │                                                                                  │ │
    │   │   ┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌───────────────┐   │ │
    │   │   │  Snowsight  │    │  Streamlit  │    │    API      │    │ Direct Query  │   │ │
    │   │   │  (Browse)   │    │   (Search)  │    │  (Automate) │    │  (Analytics)  │   │ │
    │   │   └─────────────┘    └─────────────┘    └─────────────┘    └───────────────┘   │ │
    │   │                                                                                  │ │
    │   └─────────────────────────────────────────────────────────────────────────────────┘ │
    └─────────────────────────────────────────────────────────────────────────────────────────┘


KEY DESIGN DECISIONS:
=====================

1. STORAGE TIERING
   - Hot (Azure): Frequently accessed files, recent uploads
   - Cool (Azure): Infrequent access, 30-180 days
   - Archive (Azure): Long-term retention, >180 days
   - Cost optimization via lifecycle policies

2. METADATA IN SNOWFLAKE
   - Single source of truth for file inventory
   - Rich tagging and classification
   - Full governance and access control
   - Searchable via Cortex Search

3. FILE ACCESS PATTERN
   - User searches in Snowflake → Gets blob URL
   - Presigned URLs for secure, time-limited access
   - No need to copy files into Snowflake

4. EXTERNAL STAGES
   - Direct query of files in Azure Blob
   - Directory tables for file listing
   - Transparent tiering abstraction

*/


-- ============================================================================
-- IMPLEMENTATION: ARCHIVE CATALOG SCHEMA
-- ============================================================================

USE DATABASE LIFEARC_POC;
CREATE SCHEMA IF NOT EXISTS ARCHIVE;

-- Core archive catalog table
CREATE OR REPLACE TABLE LIFEARC_POC.ARCHIVE.FILE_CATALOG (
    file_id VARCHAR PRIMARY KEY DEFAULT UUID_STRING(),
    
    -- File identification
    original_path VARCHAR NOT NULL,
    file_name VARCHAR NOT NULL,
    file_extension VARCHAR,
    
    -- Storage location
    storage_tier VARCHAR NOT NULL,  -- HOT, COOL, ARCHIVE
    blob_container VARCHAR NOT NULL,
    blob_path VARCHAR NOT NULL,
    blob_url VARCHAR,
    
    -- File metadata
    file_size_bytes BIGINT,
    checksum_md5 VARCHAR,
    checksum_sha256 VARCHAR,
    mime_type VARCHAR,
    
    -- Business metadata
    data_owner VARCHAR,
    department VARCHAR,
    project_code VARCHAR,
    data_classification VARCHAR,  -- PUBLIC, INTERNAL, CONFIDENTIAL, RESTRICTED
    
    -- Dates
    original_created_date TIMESTAMP_NTZ,
    original_modified_date TIMESTAMP_NTZ,
    archived_date TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    last_accessed_date TIMESTAMP_NTZ,
    retention_until DATE,
    
    -- Flexible metadata
    tags VARIANT,
    custom_metadata VARIANT,
    
    -- Content indexing
    content_preview TEXT,  -- First 1000 chars for text files
    content_indexed BOOLEAN DEFAULT FALSE,
    
    -- Audit
    created_by VARCHAR DEFAULT CURRENT_USER(),
    created_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    updated_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

-- Create indexes via clustering
ALTER TABLE LIFEARC_POC.ARCHIVE.FILE_CATALOG
CLUSTER BY (storage_tier, data_classification, department);

-- Create search service for discovery
/*
CREATE OR REPLACE CORTEX SEARCH SERVICE LIFEARC_POC.ARCHIVE.FILE_SEARCH_SERVICE
ON content_preview
ATTRIBUTES department, data_classification, file_extension, tags
WAREHOUSE = DEMO_WH
TARGET_LAG = '1 hour'
AS (
    SELECT 
        file_id,
        file_name,
        original_path,
        file_extension,
        data_owner,
        department,
        data_classification,
        content_preview,
        tags,
        archived_date
    FROM LIFEARC_POC.ARCHIVE.FILE_CATALOG
    WHERE content_indexed = TRUE
);
*/


-- ============================================================================
-- EXTERNAL STAGES FOR AZURE BLOB ACCESS
-- ============================================================================

-- Note: Replace with your actual Azure storage integration
/*
-- Create storage integration
CREATE OR REPLACE STORAGE INTEGRATION LIFEARC_AZURE_ARCHIVE_INT
    TYPE = EXTERNAL_STAGE
    STORAGE_PROVIDER = 'AZURE'
    ENABLED = TRUE
    AZURE_TENANT_ID = '<tenant_id>'
    STORAGE_ALLOWED_LOCATIONS = (
        'azure://lifearchive.blob.core.windows.net/hot/',
        'azure://lifearchive.blob.core.windows.net/cool/',
        'azure://lifearchive.blob.core.windows.net/archive/'
    );

-- Create external stages for each tier
CREATE OR REPLACE STAGE LIFEARC_POC.ARCHIVE.ARCHIVE_HOT
    STORAGE_INTEGRATION = LIFEARC_AZURE_ARCHIVE_INT
    URL = 'azure://lifearchive.blob.core.windows.net/hot/'
    DIRECTORY = (ENABLE = TRUE);

CREATE OR REPLACE STAGE LIFEARC_POC.ARCHIVE.ARCHIVE_COOL
    STORAGE_INTEGRATION = LIFEARC_AZURE_ARCHIVE_INT
    URL = 'azure://lifearchive.blob.core.windows.net/cool/'
    DIRECTORY = (ENABLE = TRUE);

CREATE OR REPLACE STAGE LIFEARC_POC.ARCHIVE.ARCHIVE_COLD
    STORAGE_INTEGRATION = LIFEARC_AZURE_ARCHIVE_INT
    URL = 'azure://lifearchive.blob.core.windows.net/archive/'
    DIRECTORY = (ENABLE = TRUE);
*/


-- ============================================================================
-- FILE ACCESS PATTERNS
-- ============================================================================

-- Generate presigned URL for file access
CREATE OR REPLACE FUNCTION LIFEARC_POC.ARCHIVE.GET_FILE_ACCESS_URL(
    p_file_id VARCHAR,
    p_expiry_hours INT DEFAULT 24
)
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
    SELECT 
        -- In production, this would call an external function
        -- to generate Azure SAS token or presigned URL
        blob_url || '?expiry=' || p_expiry_hours || 'h'
    FROM LIFEARC_POC.ARCHIVE.FILE_CATALOG
    WHERE file_id = p_file_id
$$;

-- Log file access for audit
CREATE OR REPLACE TABLE LIFEARC_POC.ARCHIVE.ACCESS_LOG (
    log_id VARCHAR DEFAULT UUID_STRING(),
    file_id VARCHAR,
    accessed_by VARCHAR DEFAULT CURRENT_USER(),
    accessed_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    access_type VARCHAR,  -- VIEW, DOWNLOAD, SEARCH
    ip_address VARCHAR,
    session_id VARCHAR
);

-- Procedure to request file access
CREATE OR REPLACE PROCEDURE LIFEARC_POC.ARCHIVE.REQUEST_FILE_ACCESS(
    p_file_id VARCHAR
)
RETURNS VARIANT
LANGUAGE SQL
AS
$$
DECLARE
    v_access_url VARCHAR;
    v_file_info VARIANT;
BEGIN
    -- Update last accessed date
    UPDATE LIFEARC_POC.ARCHIVE.FILE_CATALOG
    SET last_accessed_date = CURRENT_TIMESTAMP()
    WHERE file_id = p_file_id;
    
    -- Log access
    INSERT INTO LIFEARC_POC.ARCHIVE.ACCESS_LOG (file_id, access_type)
    VALUES (p_file_id, 'DOWNLOAD');
    
    -- Get file info and URL
    SELECT OBJECT_CONSTRUCT(
        'file_name', file_name,
        'file_size_bytes', file_size_bytes,
        'storage_tier', storage_tier,
        'access_url', LIFEARC_POC.ARCHIVE.GET_FILE_ACCESS_URL(p_file_id, 24)
    )
    INTO v_file_info
    FROM LIFEARC_POC.ARCHIVE.FILE_CATALOG
    WHERE file_id = p_file_id;
    
    RETURN v_file_info;
END;
$$;


-- ============================================================================
-- COST OPTIMIZATION QUERIES
-- ============================================================================

-- Storage tier distribution
SELECT 
    storage_tier,
    COUNT(*) AS file_count,
    SUM(file_size_bytes) / POWER(1024, 4) AS total_size_tb,
    ROUND(SUM(file_size_bytes) * 100.0 / SUM(SUM(file_size_bytes)) OVER (), 2) AS pct_of_total
FROM LIFEARC_POC.ARCHIVE.FILE_CATALOG
GROUP BY storage_tier;

-- Files eligible for tier migration (cool → archive)
SELECT 
    file_id,
    file_name,
    storage_tier,
    file_size_bytes,
    last_accessed_date,
    DATEDIFF(day, last_accessed_date, CURRENT_DATE()) AS days_since_access
FROM LIFEARC_POC.ARCHIVE.FILE_CATALOG
WHERE storage_tier = 'COOL'
  AND DATEDIFF(day, last_accessed_date, CURRENT_DATE()) > 180
ORDER BY file_size_bytes DESC
LIMIT 100;

-- Monthly archive growth trend
SELECT 
    DATE_TRUNC('month', archived_date) AS archive_month,
    COUNT(*) AS files_archived,
    SUM(file_size_bytes) / POWER(1024, 3) AS size_gb
FROM LIFEARC_POC.ARCHIVE.FILE_CATALOG
GROUP BY archive_month
ORDER BY archive_month DESC;


-- ============================================================================
-- KEY RECOMMENDATIONS FOR LIFEARC
-- ============================================================================

/*
ARCHITECTURE RECOMMENDATIONS:

1. STORAGE STRATEGY
   - Use Azure Blob lifecycle management for automatic tiering
   - Hot tier: Active project files (< 30 days)
   - Cool tier: Reference data (30-180 days)  
   - Archive tier: Long-term retention (> 180 days)
   - Estimated cost savings: 60-80% vs keeping all in hot tier

2. METADATA MANAGEMENT
   - Snowflake as single catalog for all archived data
   - Rich tagging for discovery and compliance
   - Cortex Search for natural language queries
   - Version history via CDC streams

3. ACCESS PATTERNS
   - Presigned URLs for secure, audited file access
   - No file duplication - access in place
   - Row access policies for department isolation
   - Complete audit trail in Snowflake

4. DATA GOVERNANCE
   - Classification tags (PUBLIC, INTERNAL, CONFIDENTIAL, RESTRICTED)
   - Retention policies enforced via automated jobs
   - Data lineage tracking
   - Compliance reporting from single location

5. MIGRATION APPROACH (from Ctera)
   - Phase 1: Parallel operation, new data to Snowflake/Azure
   - Phase 2: Batch migration of historical data
   - Phase 3: Decommission Ctera
   - Use Azure Data Factory for orchestration

6. SIZING ESTIMATES (250TB)
   - Hot tier (10%): 25TB @ ~$0.018/GB = ~$450/month
   - Cool tier (30%): 75TB @ ~$0.01/GB = ~$750/month
   - Archive tier (60%): 150TB @ ~$0.002/GB = ~$300/month
   - Snowflake metadata: < 100GB
   - Total estimated: ~$1,500-2,000/month storage

*/
