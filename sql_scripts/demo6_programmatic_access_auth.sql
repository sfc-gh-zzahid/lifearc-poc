/*
================================================================================
LIFEARC POC - DEMO 6: PROGRAMMATIC ACCESS & AUTHENTICATION
================================================================================

This script demonstrates Snowflake's programmatic access patterns:

1. Key-Pair Authentication
2. OAuth Integration
3. Service Account Best Practices
4. Network Policies
5. API Access Patterns
6. Secrets Management

Use Case Context:
- Automated ML pipelines accessing Snowflake
- Service-to-service authentication
- External application integration
- Secure CI/CD deployments

================================================================================
*/

USE ROLE ACCOUNTADMIN;
USE WAREHOUSE DEMO_WH;
USE DATABASE LIFEARC_POC;
USE SCHEMA AUTH_ACCESS;


-- ============================================================================
-- SECTION 1: SERVICE ACCOUNT SETUP
-- ============================================================================

/*
Best Practice: Create dedicated service accounts for each application/pipeline
rather than using personal accounts.
*/

-- Create a dedicated role for ML pipelines
CREATE OR REPLACE ROLE LIFEARC_ML_PIPELINE_ROLE
    COMMENT = 'Role for automated ML pipeline service accounts';

-- Create a dedicated role for data integration services
CREATE OR REPLACE ROLE LIFEARC_ETL_SERVICE_ROLE
    COMMENT = 'Role for ETL/data integration service accounts';

-- Create service account user for ML pipelines
-- In production, replace with your actual RSA public key
CREATE OR REPLACE USER LIFEARC_ML_SERVICE
    DEFAULT_ROLE = LIFEARC_ML_PIPELINE_ROLE
    DEFAULT_WAREHOUSE = DEMO_WH
    DEFAULT_NAMESPACE = LIFEARC_POC.UNSTRUCTURED_DATA
    COMMENT = 'Service account for LifeArc ML pipeline automation'
    -- RSA_PUBLIC_KEY will be set separately
    MUST_CHANGE_PASSWORD = FALSE;

-- Create service account for ETL processes
CREATE OR REPLACE USER LIFEARC_ETL_SERVICE
    DEFAULT_ROLE = LIFEARC_ETL_SERVICE_ROLE
    DEFAULT_WAREHOUSE = DEMO_WH
    DEFAULT_NAMESPACE = LIFEARC_POC.DATA_SHARING
    COMMENT = 'Service account for LifeArc ETL automation'
    MUST_CHANGE_PASSWORD = FALSE;

-- Grant roles to service accounts
GRANT ROLE LIFEARC_ML_PIPELINE_ROLE TO USER LIFEARC_ML_SERVICE;
GRANT ROLE LIFEARC_ETL_SERVICE_ROLE TO USER LIFEARC_ETL_SERVICE;

-- Grant necessary privileges to ML role
GRANT USAGE ON DATABASE LIFEARC_POC TO ROLE LIFEARC_ML_PIPELINE_ROLE;
GRANT USAGE ON SCHEMA LIFEARC_POC.UNSTRUCTURED_DATA TO ROLE LIFEARC_ML_PIPELINE_ROLE;
GRANT SELECT ON ALL TABLES IN SCHEMA LIFEARC_POC.UNSTRUCTURED_DATA TO ROLE LIFEARC_ML_PIPELINE_ROLE;
GRANT SELECT ON FUTURE TABLES IN SCHEMA LIFEARC_POC.UNSTRUCTURED_DATA TO ROLE LIFEARC_ML_PIPELINE_ROLE;
GRANT USAGE ON WAREHOUSE DEMO_WH TO ROLE LIFEARC_ML_PIPELINE_ROLE;

-- Grant necessary privileges to ETL role
GRANT USAGE ON DATABASE LIFEARC_POC TO ROLE LIFEARC_ETL_SERVICE_ROLE;
GRANT USAGE ON SCHEMA LIFEARC_POC.DATA_SHARING TO ROLE LIFEARC_ETL_SERVICE_ROLE;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA LIFEARC_POC.DATA_SHARING TO ROLE LIFEARC_ETL_SERVICE_ROLE;
GRANT USAGE ON WAREHOUSE DEMO_WH TO ROLE LIFEARC_ETL_SERVICE_ROLE;


-- ============================================================================
-- SECTION 2: KEY-PAIR AUTHENTICATION SETUP
-- ============================================================================

/*
Key-pair authentication is the recommended approach for service accounts.
It eliminates the need to store passwords and provides better security.

STEPS TO GENERATE KEY PAIR (run locally):
=========================================

# 1. Generate private key (encrypted with passphrase)
openssl genrsa 2048 | openssl pkcs8 -topk8 -v2 des3 \
    -inform PEM -out rsa_key.p8

# 2. Generate public key from private key
openssl rsa -in rsa_key.p8 -pubout -out rsa_key.pub

# 3. View public key (for setting in Snowflake)
cat rsa_key.pub

# 4. Store private key securely (e.g., Azure Key Vault, AWS Secrets Manager)
*/

-- Set public key for service account (replace with actual public key)
-- Format: single line, no header/footer, no newlines
/*
ALTER USER LIFEARC_ML_SERVICE SET RSA_PUBLIC_KEY = 
'MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA0n59eHKx...YOUR_KEY_HERE';
*/

-- You can also set a second key for key rotation without downtime
/*
ALTER USER LIFEARC_ML_SERVICE SET RSA_PUBLIC_KEY_2 = 
'MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA...YOUR_ROTATED_KEY';
*/

-- Verify key is set
DESC USER LIFEARC_ML_SERVICE;


-- ============================================================================
-- SECTION 3: OAUTH INTEGRATION
-- ============================================================================

/*
OAuth allows integration with external identity providers and enables
token-based authentication for applications.
*/

-- Create OAuth security integration for custom applications
CREATE OR REPLACE SECURITY INTEGRATION LIFEARC_CUSTOM_OAUTH
    TYPE = OAUTH
    ENABLED = TRUE
    OAUTH_CLIENT = CUSTOM
    OAUTH_CLIENT_TYPE = 'CONFIDENTIAL'
    OAUTH_REDIRECT_URI = 'https://app.lifearc.org/oauth/callback'
    OAUTH_ISSUE_REFRESH_TOKENS = TRUE
    OAUTH_REFRESH_TOKEN_VALIDITY = 86400  -- 24 hours
    COMMENT = 'OAuth integration for LifeArc internal applications';

-- Create OAuth integration for Azure AD (if using Azure ML)
/*
CREATE OR REPLACE SECURITY INTEGRATION LIFEARC_AZURE_AD_OAUTH
    TYPE = EXTERNAL_OAUTH
    ENABLED = TRUE
    EXTERNAL_OAUTH_TYPE = AZURE
    EXTERNAL_OAUTH_ISSUER = 'https://sts.windows.net/<tenant-id>/'
    EXTERNAL_OAUTH_JWS_KEYS_URL = 'https://login.microsoftonline.com/<tenant-id>/discovery/v2.0/keys'
    EXTERNAL_OAUTH_TOKEN_USER_MAPPING_CLAIM = 'upn'
    EXTERNAL_OAUTH_SNOWFLAKE_USER_MAPPING_ATTRIBUTE = 'LOGIN_NAME'
    EXTERNAL_OAUTH_AUDIENCE_LIST = ('https://<account>.snowflakecomputing.com')
    COMMENT = 'Azure AD OAuth integration for Azure ML Studio';
*/

-- View integration details
DESC SECURITY INTEGRATION LIFEARC_CUSTOM_OAUTH;


-- ============================================================================
-- SECTION 4: NETWORK POLICIES
-- ============================================================================

/*
Network policies restrict connections to specific IP addresses/ranges,
adding an extra layer of security for service accounts.
*/

-- Create network policy for ML pipeline (restrict to specific IPs)
CREATE OR REPLACE NETWORK POLICY LIFEARC_ML_NETWORK_POLICY
    ALLOWED_IP_LIST = (
        '10.0.0.0/8',           -- Internal Azure network
        '172.16.0.0/12',        -- Internal network range
        '52.142.0.0/16'         -- Azure ML compute IPs (example)
    )
    BLOCKED_IP_LIST = ()
    COMMENT = 'Network policy for ML pipeline service accounts';

-- Create network policy for ETL services
CREATE OR REPLACE NETWORK POLICY LIFEARC_ETL_NETWORK_POLICY
    ALLOWED_IP_LIST = (
        '10.0.0.0/8',           -- Internal network
        '192.168.1.0/24'        -- On-premises ETL servers
    )
    COMMENT = 'Network policy for ETL service accounts';

-- Apply network policy to service account
-- ALTER USER LIFEARC_ML_SERVICE SET NETWORK_POLICY = LIFEARC_ML_NETWORK_POLICY;
-- ALTER USER LIFEARC_ETL_SERVICE SET NETWORK_POLICY = LIFEARC_ETL_NETWORK_POLICY;

-- View network policies
SHOW NETWORK POLICIES;


-- ============================================================================
-- SECTION 5: API ACCESS PATTERNS
-- ============================================================================

/*
Create API-friendly views and stored procedures for external applications.
*/

-- Create a stored procedure for ML inference data retrieval
CREATE OR REPLACE PROCEDURE LIFEARC_POC.AUTH_ACCESS.GET_INFERENCE_BATCH(
    batch_size INT,
    model_type VARCHAR
)
RETURNS TABLE (
    record_id VARCHAR,
    features VARIANT,
    created_at TIMESTAMP_NTZ
)
LANGUAGE SQL
AS
$$
    -- This would query your feature store and return inference-ready data
    SELECT 
        result_id AS record_id,
        OBJECT_CONSTRUCT(
            'biomarker_status', biomarker_status,
            'treatment_arm', treatment_arm,
            'cohort', cohort
        ) AS features,
        created_at
    FROM LIFEARC_POC.DATA_SHARING.CLINICAL_TRIAL_RESULTS
    LIMIT batch_size
$$;

-- Create a procedure for logging API access
CREATE OR REPLACE TABLE LIFEARC_POC.AUTH_ACCESS.API_ACCESS_LOG (
    log_id VARCHAR DEFAULT UUID_STRING(),
    endpoint VARCHAR,
    user_name VARCHAR,
    role_name VARCHAR,
    request_params VARIANT,
    response_status VARCHAR,
    execution_time_ms INT,
    created_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

CREATE OR REPLACE PROCEDURE LIFEARC_POC.AUTH_ACCESS.LOG_API_CALL(
    endpoint VARCHAR,
    request_params VARIANT,
    response_status VARCHAR,
    execution_time_ms INT
)
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
    INSERT INTO LIFEARC_POC.AUTH_ACCESS.API_ACCESS_LOG 
    (endpoint, user_name, role_name, request_params, response_status, execution_time_ms)
    VALUES (endpoint, CURRENT_USER(), CURRENT_ROLE(), request_params, response_status, execution_time_ms);
    RETURN 'LOGGED';
$$;


-- ============================================================================
-- SECTION 6: SECRETS MANAGEMENT WITH SNOWFLAKE
-- ============================================================================

/*
Best practices for managing secrets in Snowflake:
1. Use SECRET objects for API keys, passwords
2. Use external secrets managers (Azure Key Vault, AWS Secrets Manager)
3. Never store secrets in plain text in code
*/

-- Create secret for external API access (e.g., external model serving endpoint)
CREATE OR REPLACE SECRET LIFEARC_POC.AUTH_ACCESS.EXTERNAL_MODEL_API_KEY
    TYPE = GENERIC_STRING
    SECRET_STRING = 'placeholder-replace-in-production'
    COMMENT = 'API key for external model serving endpoint';

-- Create secret for OAuth credentials
CREATE OR REPLACE SECRET LIFEARC_POC.AUTH_ACCESS.OAUTH_CLIENT_SECRET
    TYPE = GENERIC_STRING
    SECRET_STRING = 'placeholder-replace-in-production'
    COMMENT = 'OAuth client secret for custom applications';

-- Note: In production, use external secrets managers with Snowflake integration
/*
CREATE OR REPLACE SECRET LIFEARC_POC.AUTH_ACCESS.AZURE_KEYVAULT_SECRET
    TYPE = AZURE_KEY_VAULT_SECRET
    SECRET_NAME = 'snowflake-api-key'
    API_AUTHENTICATION = LIFEARC_AZURE_INTEGRATION;
*/

-- Grant access to secrets for specific roles
GRANT USAGE ON SECRET LIFEARC_POC.AUTH_ACCESS.EXTERNAL_MODEL_API_KEY 
    TO ROLE LIFEARC_ML_PIPELINE_ROLE;


-- ============================================================================
-- SECTION 7: PROGRAMMATIC CONNECTION EXAMPLES
-- ============================================================================

/*
Below are code examples for different connection methods.
These are for reference - not executable in SQL worksheet.
*/

-- ============================================================================
-- PYTHON: Key-Pair Authentication
-- ============================================================================
/*
# Python code for key-pair authentication

import snowflake.connector
from cryptography.hazmat.backends import default_backend
from cryptography.hazmat.primitives import serialization

# Load private key
with open("rsa_key.p8", "rb") as key_file:
    p_key = serialization.load_pem_private_key(
        key_file.read(),
        password='your_passphrase'.encode(),
        backend=default_backend()
    )

# Get the raw bytes of the private key
pkb = p_key.private_bytes(
    encoding=serialization.Encoding.DER,
    format=serialization.PrivateFormat.PKCS8,
    encryption_algorithm=serialization.NoEncryption()
)

# Connect to Snowflake
conn = snowflake.connector.connect(
    user='LIFEARC_ML_SERVICE',
    account='your_account',
    private_key=pkb,
    warehouse='DEMO_WH',
    database='LIFEARC_POC',
    schema='UNSTRUCTURED_DATA'
)

# Execute query
cur = conn.cursor()
cur.execute("SELECT * FROM GENE_SEQUENCES LIMIT 10")
results = cur.fetchall()
*/

-- ============================================================================
-- PYTHON: Snowpark Session with Key-Pair
-- ============================================================================
/*
# Snowpark with key-pair authentication

from snowflake.snowpark import Session
from cryptography.hazmat.backends import default_backend
from cryptography.hazmat.primitives import serialization

# Load private key
with open("rsa_key.p8", "rb") as key_file:
    p_key = serialization.load_pem_private_key(
        key_file.read(),
        password='your_passphrase'.encode(),
        backend=default_backend()
    )

pkb = p_key.private_bytes(
    encoding=serialization.Encoding.DER,
    format=serialization.PrivateFormat.PKCS8,
    encryption_algorithm=serialization.NoEncryption()
)

connection_parameters = {
    "account": "your_account",
    "user": "LIFEARC_ML_SERVICE",
    "private_key": pkb,
    "warehouse": "DEMO_WH",
    "database": "LIFEARC_POC",
    "schema": "UNSTRUCTURED_DATA"
}

session = Session.builder.configs(connection_parameters).create()

# Use Snowpark DataFrame API
df = session.table("GENE_SEQUENCES")
df.show()
*/

-- ============================================================================
-- PYTHON: OAuth Token Authentication
-- ============================================================================
/*
# OAuth token-based connection

import snowflake.connector
import requests

# Get OAuth token from your identity provider
token_response = requests.post(
    'https://your-idp/oauth/token',
    data={
        'grant_type': 'client_credentials',
        'client_id': 'your_client_id',
        'client_secret': 'your_client_secret',
        'scope': 'session:role:LIFEARC_ML_PIPELINE_ROLE'
    }
)
oauth_token = token_response.json()['access_token']

# Connect with OAuth token
conn = snowflake.connector.connect(
    user='LIFEARC_ML_SERVICE',
    account='your_account',
    authenticator='oauth',
    token=oauth_token,
    warehouse='DEMO_WH',
    database='LIFEARC_POC'
)
*/


-- ============================================================================
-- SECTION 8: MONITORING & TROUBLESHOOTING
-- ============================================================================

-- View login history for service accounts
SELECT 
    event_timestamp,
    user_name,
    client_ip,
    reported_client_type,
    first_authentication_factor,
    is_success,
    error_code,
    error_message
FROM SNOWFLAKE.ACCOUNT_USAGE.LOGIN_HISTORY
WHERE user_name IN ('LIFEARC_ML_SERVICE', 'LIFEARC_ETL_SERVICE')
ORDER BY event_timestamp DESC
LIMIT 50;

-- View authentication methods used
SELECT 
    user_name,
    first_authentication_factor,
    COUNT(*) AS login_count,
    COUNT(CASE WHEN is_success = 'YES' THEN 1 END) AS success_count,
    COUNT(CASE WHEN is_success = 'NO' THEN 1 END) AS failure_count
FROM SNOWFLAKE.ACCOUNT_USAGE.LOGIN_HISTORY
WHERE event_timestamp > DATEADD(day, -30, CURRENT_TIMESTAMP())
GROUP BY user_name, first_authentication_factor
ORDER BY login_count DESC;

-- Check session activity for service accounts
SELECT 
    user_name,
    session_id,
    created_on,
    authentication_method,
    client_application_id
FROM SNOWFLAKE.ACCOUNT_USAGE.SESSIONS
WHERE user_name IN ('LIFEARC_ML_SERVICE', 'LIFEARC_ETL_SERVICE')
  AND created_on > DATEADD(day, -7, CURRENT_TIMESTAMP())
ORDER BY created_on DESC
LIMIT 20;


-- ============================================================================
-- SECTION 9: BEST PRACTICES SUMMARY
-- ============================================================================

/*
KEY RECOMMENDATIONS FOR LIFEARC:

1. SERVICE ACCOUNTS
   - Create dedicated service accounts per application/pipeline
   - Use descriptive naming: LIFEARC_<SYSTEM>_SERVICE
   - Set default role, warehouse, and namespace
   - Never share service accounts between applications

2. KEY-PAIR AUTHENTICATION
   - Use RSA 2048-bit or higher keys
   - Encrypt private keys with passphrases
   - Store private keys in secrets managers (Azure Key Vault)
   - Implement key rotation (use RSA_PUBLIC_KEY_2 for rotation)
   - Never commit private keys to source control

3. NETWORK POLICIES
   - Restrict service accounts to known IP ranges
   - Use VNet/private endpoints where possible
   - Regularly review and update allowed IP lists

4. OAUTH INTEGRATION
   - Use external OAuth for user authentication (Azure AD)
   - Use key-pair for service-to-service
   - Set appropriate token lifetimes
   - Enable MFA where possible for user accounts

5. MONITORING
   - Monitor LOGIN_HISTORY for failed attempts
   - Set up alerts for unusual access patterns
   - Review API access logs regularly
   - Audit privilege grants periodically

6. SECRETS MANAGEMENT
   - Never store secrets in code or config files
   - Use Snowflake SECRET objects or external managers
   - Rotate secrets regularly
   - Audit secret access
*/


-- ============================================================================
-- CLEANUP (Run if needed)
-- ============================================================================

/*
-- Drop service accounts
DROP USER IF EXISTS LIFEARC_ML_SERVICE;
DROP USER IF EXISTS LIFEARC_ETL_SERVICE;

-- Drop roles
DROP ROLE IF EXISTS LIFEARC_ML_PIPELINE_ROLE;
DROP ROLE IF EXISTS LIFEARC_ETL_SERVICE_ROLE;

-- Drop network policies
DROP NETWORK POLICY IF EXISTS LIFEARC_ML_NETWORK_POLICY;
DROP NETWORK POLICY IF EXISTS LIFEARC_ETL_NETWORK_POLICY;

-- Drop security integrations
DROP SECURITY INTEGRATION IF EXISTS LIFEARC_CUSTOM_OAUTH;

-- Drop secrets
DROP SECRET IF EXISTS LIFEARC_POC.AUTH_ACCESS.EXTERNAL_MODEL_API_KEY;
DROP SECRET IF EXISTS LIFEARC_POC.AUTH_ACCESS.OAUTH_CLIENT_SECRET;
*/


-- ============================================================================
-- DEMO SCRIPT - WALKTHROUGH ORDER
-- ============================================================================

/*
1. Explain service account best practices
2. Walk through key-pair authentication setup
3. Show OAuth integration options (custom & Azure AD)
4. Demonstrate network policies
5. Show programmatic connection code examples
6. Review monitoring queries
7. Discuss secrets management
8. Q&A on integration with Azure ML Studio

KEY MESSAGES FOR LIFEARC:
- Key-pair auth is most secure for automated pipelines
- OAuth enables SSO integration with Azure AD
- Network policies add defense-in-depth
- Full audit trail for compliance
- Integrates seamlessly with existing Azure infrastructure
*/
