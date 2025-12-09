-- ============================================================================
-- CRM Database System - Complete Rollback Script
-- Purpose: Drop all objects created by the CRM system for clean reinstall
-- Target PDB: lu_plsqlauca_25815
-- Oracle SQL Developer 24.3
-- ============================================================================

SET SERVEROUTPUT ON;
PROMPT ============================================================================
PROMPT CRM DATABASE SYSTEM - COMPLETE ROLLBACK
PROMPT ============================================================================
PROMPT This script will drop ALL CRM objects: tables, sequences, triggers,
PROMPT procedures, functions, packages, and roles.
PROMPT ============================================================================
PROMPT

-- ============================================================================
-- SECTION 1: DROP TRIGGERS (Must drop before tables)
-- ============================================================================

PROMPT ============================================================================
PROMPT SECTION 1: Dropping Triggers...
PROMPT ============================================================================

BEGIN
    FOR rec IN (SELECT trigger_name FROM user_triggers WHERE trigger_name LIKE 'TRG_%') LOOP
        EXECUTE IMMEDIATE 'DROP TRIGGER ' || rec.trigger_name;
        DBMS_OUTPUT.PUT_LINE('Dropped trigger: ' || rec.trigger_name);
    END LOOP;
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Error dropping triggers: ' || SQLERRM);
END;
/

-- ============================================================================
-- SECTION 2: DROP PACKAGES (Must drop before procedures/functions)
-- ============================================================================

PROMPT ============================================================================
PROMPT SECTION 2: Dropping Packages...
PROMPT ============================================================================

BEGIN
    FOR rec IN (SELECT object_name FROM user_objects WHERE object_type = 'PACKAGE BODY' AND object_name LIKE 'PKG_%') LOOP
        BEGIN
            EXECUTE IMMEDIATE 'DROP PACKAGE BODY ' || rec.object_name;
            DBMS_OUTPUT.PUT_LINE('Dropped package body: ' || rec.object_name);
        EXCEPTION
            WHEN OTHERS THEN
                DBMS_OUTPUT.PUT_LINE('Warning: Could not drop package body ' || rec.object_name || ': ' || SQLERRM);
        END;
    END LOOP;
    
    FOR rec IN (SELECT object_name FROM user_objects WHERE object_type = 'PACKAGE' AND object_name LIKE 'PKG_%') LOOP
        BEGIN
            EXECUTE IMMEDIATE 'DROP PACKAGE ' || rec.object_name;
            DBMS_OUTPUT.PUT_LINE('Dropped package: ' || rec.object_name);
        EXCEPTION
            WHEN OTHERS THEN
                DBMS_OUTPUT.PUT_LINE('Warning: Could not drop package ' || rec.object_name || ': ' || SQLERRM);
        END;
    END LOOP;
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Error dropping packages: ' || SQLERRM);
END;
/

-- ============================================================================
-- SECTION 3: DROP PROCEDURES
-- ============================================================================

PROMPT ============================================================================
PROMPT SECTION 3: Dropping Procedures...
PROMPT ============================================================================

BEGIN
    FOR rec IN (SELECT object_name FROM user_objects WHERE object_type = 'PROCEDURE' AND object_name LIKE 'PROC_%') LOOP
        BEGIN
            EXECUTE IMMEDIATE 'DROP PROCEDURE ' || rec.object_name;
            DBMS_OUTPUT.PUT_LINE('Dropped procedure: ' || rec.object_name);
        EXCEPTION
            WHEN OTHERS THEN
                DBMS_OUTPUT.PUT_LINE('Warning: Could not drop procedure ' || rec.object_name || ': ' || SQLERRM);
        END;
    END LOOP;
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Error dropping procedures: ' || SQLERRM);
END;
/

-- ============================================================================
-- SECTION 4: DROP FUNCTIONS
-- ============================================================================

PROMPT ============================================================================
PROMPT SECTION 4: Dropping Functions...
PROMPT ============================================================================

BEGIN
    FOR rec IN (SELECT object_name FROM user_objects WHERE object_type = 'FUNCTION' AND object_name LIKE 'FUNC_%') LOOP
        BEGIN
            EXECUTE IMMEDIATE 'DROP FUNCTION ' || rec.object_name;
            DBMS_OUTPUT.PUT_LINE('Dropped function: ' || rec.object_name);
        EXCEPTION
            WHEN OTHERS THEN
                DBMS_OUTPUT.PUT_LINE('Warning: Could not drop function ' || rec.object_name || ': ' || SQLERRM);
        END;
    END LOOP;
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Error dropping functions: ' || SQLERRM);
END;
/

-- ============================================================================
-- SECTION 5: DROP TABLES (In reverse dependency order)
-- ============================================================================

PROMPT ============================================================================
PROMPT SECTION 5: Dropping Tables (in reverse dependency order)...
PROMPT ============================================================================

-- Drop tables in reverse dependency order
BEGIN
    -- Drop dependent tables first
    FOR rec IN (
        SELECT table_name FROM user_tables 
        WHERE table_name IN ('FEEDBACK', 'ASSIGNMENTS', 'SERVICE_REQUESTS', 'TECHNICIANS', 
                             'PRODUCTS', 'CUSTOMERS', 'SLA_RULES')
        ORDER BY CASE table_name
            WHEN 'FEEDBACK' THEN 1
            WHEN 'ASSIGNMENTS' THEN 2
            WHEN 'SERVICE_REQUESTS' THEN 3
            WHEN 'TECHNICIANS' THEN 4
            WHEN 'PRODUCTS' THEN 5
            WHEN 'CUSTOMERS' THEN 6
            WHEN 'SLA_RULES' THEN 7
        END
    ) LOOP
        BEGIN
            EXECUTE IMMEDIATE 'DROP TABLE ' || rec.table_name || ' CASCADE CONSTRAINTS';
            DBMS_OUTPUT.PUT_LINE('Dropped table: ' || rec.table_name);
        EXCEPTION
            WHEN OTHERS THEN
                DBMS_OUTPUT.PUT_LINE('Warning: Could not drop table ' || rec.table_name || ': ' || SQLERRM);
        END;
    END LOOP;
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Error dropping tables: ' || SQLERRM);
END;
/

-- ============================================================================
-- SECTION 6: DROP SEQUENCES
-- ============================================================================

PROMPT ============================================================================
PROMPT SECTION 6: Dropping Sequences...
PROMPT ============================================================================

BEGIN
    FOR rec IN (
        SELECT sequence_name FROM user_sequences 
        WHERE sequence_name LIKE 'SEQ_%'
    ) LOOP
        BEGIN
            EXECUTE IMMEDIATE 'DROP SEQUENCE ' || rec.sequence_name;
            DBMS_OUTPUT.PUT_LINE('Dropped sequence: ' || rec.sequence_name);
        EXCEPTION
            WHEN OTHERS THEN
                DBMS_OUTPUT.PUT_LINE('Warning: Could not drop sequence ' || rec.sequence_name || ': ' || SQLERRM);
        END;
    END LOOP;
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Error dropping sequences: ' || SQLERRM);
END;
/

-- ============================================================================
-- SECTION 7: DROP ROLES (Optional - only if you have privileges)
-- ============================================================================

PROMPT ============================================================================
PROMPT SECTION 7: Dropping Roles (if you have privileges)...
PROMPT ============================================================================

-- Try to drop roles directly (they may not exist or may not be accessible to query)
-- List of CRM roles to attempt dropping
DECLARE
    TYPE role_array IS TABLE OF VARCHAR2(50);
    v_roles role_array := role_array('CRM_ADMIN', 'CRM_MANAGER', 'CRM_TECHNICIAN', 'CRM_CUSTOMER', 'CRM_ANALYST');
    v_dropped_count NUMBER := 0;
BEGIN
    FOR i IN 1 .. v_roles.COUNT LOOP
        BEGIN
            EXECUTE IMMEDIATE 'DROP ROLE ' || v_roles(i);
            DBMS_OUTPUT.PUT_LINE('Dropped role: ' || v_roles(i));
            v_dropped_count := v_dropped_count + 1;
        EXCEPTION
            WHEN OTHERS THEN
                IF SQLCODE = -1919 THEN
                    -- Role does not exist - that's OK, just continue
                    NULL;
                ELSIF SQLCODE = -1031 THEN
                    DBMS_OUTPUT.PUT_LINE('Note: Insufficient privileges to drop role ' || v_roles(i) || '. Ask DBA.');
                ELSE
                    -- Other errors - silently continue
                    NULL;
                END IF;
        END;
    END LOOP;
    
    IF v_dropped_count = 0 THEN
        DBMS_OUTPUT.PUT_LINE('Note: No CRM roles were dropped. They may not exist or you may lack privileges.');
    ELSE
        DBMS_OUTPUT.PUT_LINE('Dropped ' || v_dropped_count || ' role(s).');
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Note: Role dropping encountered an issue. This is normal if roles were not created or you lack privileges.');
END;
/

-- ============================================================================
-- SECTION 8: VERIFICATION
-- ============================================================================

PROMPT ============================================================================
PROMPT SECTION 8: Verification - Checking for remaining objects...
PROMPT ============================================================================

DECLARE
    v_count NUMBER;
BEGIN
    -- Check tables
    SELECT COUNT(*) INTO v_count FROM user_tables WHERE table_name IN ('FEEDBACK', 'ASSIGNMENTS', 'SERVICE_REQUESTS', 'TECHNICIANS', 'PRODUCTS', 'CUSTOMERS', 'SLA_RULES');
    IF v_count > 0 THEN
        DBMS_OUTPUT.PUT_LINE('WARNING: ' || v_count || ' CRM tables still exist!');
    ELSE
        DBMS_OUTPUT.PUT_LINE('✓ All CRM tables dropped successfully');
    END IF;
    
    -- Check sequences
    SELECT COUNT(*) INTO v_count FROM user_sequences WHERE sequence_name LIKE 'SEQ_%';
    IF v_count > 0 THEN
        DBMS_OUTPUT.PUT_LINE('WARNING: ' || v_count || ' CRM sequences still exist!');
    ELSE
        DBMS_OUTPUT.PUT_LINE('✓ All CRM sequences dropped successfully');
    END IF;
    
    -- Check triggers
    SELECT COUNT(*) INTO v_count FROM user_triggers WHERE trigger_name LIKE 'TRG_%';
    IF v_count > 0 THEN
        DBMS_OUTPUT.PUT_LINE('WARNING: ' || v_count || ' CRM triggers still exist!');
    ELSE
        DBMS_OUTPUT.PUT_LINE('✓ All CRM triggers dropped successfully');
    END IF;
    
    -- Check procedures
    SELECT COUNT(*) INTO v_count FROM user_objects WHERE object_type = 'PROCEDURE' AND object_name LIKE 'PROC_%';
    IF v_count > 0 THEN
        DBMS_OUTPUT.PUT_LINE('WARNING: ' || v_count || ' CRM procedures still exist!');
    ELSE
        DBMS_OUTPUT.PUT_LINE('✓ All CRM procedures dropped successfully');
    END IF;
    
    -- Check functions
    SELECT COUNT(*) INTO v_count FROM user_objects WHERE object_type = 'FUNCTION' AND object_name LIKE 'FUNC_%';
    IF v_count > 0 THEN
        DBMS_OUTPUT.PUT_LINE('WARNING: ' || v_count || ' CRM functions still exist!');
    ELSE
        DBMS_OUTPUT.PUT_LINE('✓ All CRM functions dropped successfully');
    END IF;
    
    -- Check packages
    SELECT COUNT(*) INTO v_count FROM user_objects WHERE object_type IN ('PACKAGE', 'PACKAGE BODY') AND object_name LIKE 'PKG_%';
    IF v_count > 0 THEN
        DBMS_OUTPUT.PUT_LINE('WARNING: ' || v_count || ' CRM packages still exist!');
    ELSE
        DBMS_OUTPUT.PUT_LINE('✓ All CRM packages dropped successfully');
    END IF;
    
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('Rollback verification complete!');
    
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Error during verification: ' || SQLERRM);
END;
/

-- ============================================================================
-- COMPLETION SUMMARY
-- ============================================================================

PROMPT ============================================================================
PROMPT ROLLBACK COMPLETE
PROMPT ============================================================================
PROMPT
PROMPT All CRM database objects have been dropped.
PROMPT You can now rerun the master script with your new tablespace.
PROMPT
PROMPT Next steps:
PROMPT   1. Verify all objects are dropped (check verification output above)
PROMPT   2. Run the master script: @00_master_script.sql
PROMPT   3. Your new tablespace (lu_plsqlauca_ts) will be used automatically
PROMPT
PROMPT ============================================================================

