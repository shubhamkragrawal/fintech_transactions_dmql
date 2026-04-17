-- Roles creation

--   Creating Roles 
CREATE ROLE analyst_role;
CREATE ROLE app_user_role;

--  Grant Schema Access to Both Roles
GRANT USAGE ON SCHEMA dmql_base TO analyst_role;
GRANT USAGE ON SCHEMA dmql_base TO app_user_role;

--   Analyst Role — SELECT only 
GRANT SELECT ON ALL TABLES IN SCHEMA dmql_base TO analyst_role;

--   App User Role — SELECT, INSERT, UPDATE 
GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA dmql_base TO app_user_role;

--   Creating Physical Users 

-- Analyst user
CREATE USER analyst_user WITH PASSWORD 'Analyst_1234';
GRANT analyst_role TO analyst_user;

-- App user
CREATE USER app_user WITH PASSWORD 'AppUser_1234';
GRANT app_user_role TO app_user;

--  Future Tables Automatically Inherit Grants
ALTER DEFAULT PRIVILEGES IN SCHEMA dmql_base
    GRANT SELECT ON TABLES TO analyst_role;

ALTER DEFAULT PRIVILEGES IN SCHEMA dmql_base
    GRANT SELECT, INSERT, UPDATE ON TABLES TO app_user_role;


-- Check roles exist
SELECT rolname, rolcanlogin
FROM pg_roles
WHERE rolname IN ('analyst_role', 'app_user_role', 'analyst_user', 'app_user');

-- Check table privileges
SELECT grantee, table_name, privilege_type
FROM information_schema.role_table_grants
WHERE table_schema = 'dmql_base'
AND grantee IN ('analyst_role', 'app_user_role')
ORDER BY grantee, table_name, privilege_type;