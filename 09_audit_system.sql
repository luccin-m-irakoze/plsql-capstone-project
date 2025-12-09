-- ============================================================================
-- CRM Database System - Audit System Implementation
-- Phase 9: Audit Logging and Change Tracking
-- Target PDB: lu_plsqlauca_25815
-- Oracle SQL Developer 24.3
-- ============================================================================

SET SERVEROUTPUT ON;
PROMPT Starting Phase 9: Audit System Implementation...

-- ============================================================================
-- 9.1 CREATE AUDIT LOG SEQUENCE
-- ============================================================================

PROMPT Creating sequence for audit log IDs...

BEGIN
    FOR rec IN (SELECT sequence_name FROM user_sequences WHERE sequence_name = 'SEQ_AUDIT_LOG_ID') LOOP
        EXECUTE IMMEDIATE 'DROP SEQUENCE ' || rec.sequence_name;
        DBMS_OUTPUT.PUT_LINE('Dropped existing sequence: ' || rec.sequence_name);
    END LOOP;
EXCEPTION
    WHEN OTHERS THEN NULL;
END;
/

CREATE SEQUENCE seq_audit_log_id
    START WITH 1
    INCREMENT BY 1
    NOCACHE
    NOCYCLE;

PROMPT Sequence seq_audit_log_id created successfully.

-- ============================================================================
-- 9.2 CREATE AUDIT_LOG TABLE
-- ============================================================================

PROMPT Creating AUDIT_LOG table...

BEGIN
    EXECUTE IMMEDIATE 'DROP TABLE AUDIT_LOG CASCADE CONSTRAINTS';
    DBMS_OUTPUT.PUT_LINE('Dropped existing AUDIT_LOG table');
EXCEPTION
    WHEN OTHERS THEN NULL;
END;
/

CREATE TABLE AUDIT_LOG (
    audit_id NUMBER PRIMARY KEY,
    table_name VARCHAR2(50) NOT NULL,
    record_id NUMBER,
    operation VARCHAR2(10) NOT NULL CHECK (operation IN ('INSERT', 'UPDATE', 'DELETE')),
    column_name VARCHAR2(100),
    old_value VARCHAR2(4000),
    new_value VARCHAR2(4000),
    changed_by VARCHAR2(100) DEFAULT USER,
    changed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    session_id VARCHAR2(100),
    ip_address VARCHAR2(50),
    additional_info VARCHAR2(1000)
);

-- Indexes for performance
CREATE INDEX idx_audit_table_name ON AUDIT_LOG(table_name);
CREATE INDEX idx_audit_record_id ON AUDIT_LOG(record_id);
CREATE INDEX idx_audit_changed_at ON AUDIT_LOG(changed_at);
CREATE INDEX idx_audit_changed_by ON AUDIT_LOG(changed_by);
CREATE INDEX idx_audit_operation ON AUDIT_LOG(operation);
CREATE INDEX idx_audit_table_record ON AUDIT_LOG(table_name, record_id);

PROMPT Table AUDIT_LOG created successfully with indexes.

-- ============================================================================
-- 9.3 AUDIT TRIGGER FOR SERVICE_REQUESTS
-- ============================================================================

PROMPT Creating audit triggers for SERVICE_REQUESTS...

CREATE OR REPLACE TRIGGER TRG_AUDIT_SERVICE_REQUESTS
    AFTER INSERT OR UPDATE OR DELETE ON SERVICE_REQUESTS
    FOR EACH ROW
DECLARE
    v_operation VARCHAR2(10);
    v_record_id NUMBER;
BEGIN
    -- Determine operation type
    IF INSERTING THEN
        v_operation := 'INSERT';
        v_record_id := :NEW.request_id;
        
        -- Log all column values for new record
        INSERT INTO AUDIT_LOG (audit_id, table_name, record_id, operation, column_name, new_value, changed_by, changed_at)
        VALUES (seq_audit_log_id.NEXTVAL, 'SERVICE_REQUESTS', v_record_id, v_operation, 'ALL_COLUMNS', 
                'customer_id=' || :NEW.customer_id || '|product_id=' || NVL(TO_CHAR(:NEW.product_id), 'NULL') || 
                '|status=' || :NEW.status || '|priority=' || :NEW.priority || '|issue_type=' || NVL(:NEW.issue_type, 'NULL'),
                USER, CURRENT_TIMESTAMP);
                
    ELSIF UPDATING THEN
        v_operation := 'UPDATE';
        v_record_id := :NEW.request_id;
        
        -- Log only changed columns
        IF :OLD.status != :NEW.status THEN
            INSERT INTO AUDIT_LOG (audit_id, table_name, record_id, operation, column_name, old_value, new_value, changed_by, changed_at)
            VALUES (seq_audit_log_id.NEXTVAL, 'SERVICE_REQUESTS', v_record_id, v_operation, 'status', 
                    :OLD.status, :NEW.status, USER, CURRENT_TIMESTAMP);
        END IF;
        
        IF NVL(:OLD.priority, 'NULL') != NVL(:NEW.priority, 'NULL') THEN
            INSERT INTO AUDIT_LOG (audit_id, table_name, record_id, operation, column_name, old_value, new_value, changed_by, changed_at)
            VALUES (seq_audit_log_id.NEXTVAL, 'SERVICE_REQUESTS', v_record_id, v_operation, 'priority', 
                    :OLD.priority, :NEW.priority, USER, CURRENT_TIMESTAMP);
        END IF;
        
        IF NVL(:OLD.issue_type, 'NULL') != NVL(:NEW.issue_type, 'NULL') THEN
            INSERT INTO AUDIT_LOG (audit_id, table_name, record_id, operation, column_name, old_value, new_value, changed_by, changed_at)
            VALUES (seq_audit_log_id.NEXTVAL, 'SERVICE_REQUESTS', v_record_id, v_operation, 'issue_type', 
                    :OLD.issue_type, :NEW.issue_type, USER, CURRENT_TIMESTAMP);
        END IF;
        
        IF :OLD.resolved_at IS NULL AND :NEW.resolved_at IS NOT NULL THEN
            INSERT INTO AUDIT_LOG (audit_id, table_name, record_id, operation, column_name, old_value, new_value, changed_by, changed_at)
            VALUES (seq_audit_log_id.NEXTVAL, 'SERVICE_REQUESTS', v_record_id, v_operation, 'resolved_at', 
                    'NULL', TO_CHAR(:NEW.resolved_at, 'YYYY-MM-DD HH24:MI:SS'), USER, CURRENT_TIMESTAMP);
        END IF;
        
    ELSIF DELETING THEN
        v_operation := 'DELETE';
        v_record_id := :OLD.request_id;
        
        -- Log deletion
        INSERT INTO AUDIT_LOG (audit_id, table_name, record_id, operation, column_name, old_value, changed_by, changed_at)
        VALUES (seq_audit_log_id.NEXTVAL, 'SERVICE_REQUESTS', v_record_id, v_operation, 'RECORD_DELETED', 
                'customer_id=' || :OLD.customer_id || '|status=' || :OLD.status || '|priority=' || :OLD.priority,
                USER, CURRENT_TIMESTAMP);
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        -- Don't fail the transaction if audit logging fails
        DBMS_OUTPUT.PUT_LINE('Warning: Audit logging error for SERVICE_REQUESTS: ' || SQLERRM);
END;
/

PROMPT Trigger TRG_AUDIT_SERVICE_REQUESTS created successfully.

-- ============================================================================
-- 9.4 AUDIT TRIGGER FOR ASSIGNMENTS
-- ============================================================================

PROMPT Creating audit triggers for ASSIGNMENTS...

CREATE OR REPLACE TRIGGER TRG_AUDIT_ASSIGNMENTS
    AFTER INSERT OR UPDATE OR DELETE ON ASSIGNMENTS
    FOR EACH ROW
DECLARE
    v_operation VARCHAR2(10);
    v_record_id NUMBER;
BEGIN
    IF INSERTING THEN
        v_operation := 'INSERT';
        v_record_id := :NEW.assignment_id;
        
        INSERT INTO AUDIT_LOG (audit_id, table_name, record_id, operation, column_name, new_value, changed_by, changed_at)
        VALUES (seq_audit_log_id.NEXTVAL, 'ASSIGNMENTS', v_record_id, v_operation, 'ALL_COLUMNS', 
                'request_id=' || :NEW.request_id || '|technician_id=' || :NEW.technician_id,
                USER, CURRENT_TIMESTAMP);
                
    ELSIF UPDATING THEN
        v_operation := 'UPDATE';
        v_record_id := :NEW.assignment_id;
        
        IF :OLD.technician_id != :NEW.technician_id THEN
            INSERT INTO AUDIT_LOG (audit_id, table_name, record_id, operation, column_name, old_value, new_value, changed_by, changed_at)
            VALUES (seq_audit_log_id.NEXTVAL, 'ASSIGNMENTS', v_record_id, v_operation, 'technician_id', 
                    TO_CHAR(:OLD.technician_id), TO_CHAR(:NEW.technician_id), USER, CURRENT_TIMESTAMP);
        END IF;
        
    ELSIF DELETING THEN
        v_operation := 'DELETE';
        v_record_id := :OLD.assignment_id;
        
        INSERT INTO AUDIT_LOG (audit_id, table_name, record_id, operation, column_name, old_value, changed_by, changed_at)
        VALUES (seq_audit_log_id.NEXTVAL, 'ASSIGNMENTS', v_record_id, v_operation, 'RECORD_DELETED', 
                'request_id=' || :OLD.request_id || '|technician_id=' || :OLD.technician_id,
                USER, CURRENT_TIMESTAMP);
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Warning: Audit logging error for ASSIGNMENTS: ' || SQLERRM);
END;
/

PROMPT Trigger TRG_AUDIT_ASSIGNMENTS created successfully.

-- ============================================================================
-- 9.5 AUDIT TRIGGER FOR CUSTOMERS
-- ============================================================================

PROMPT Creating audit triggers for CUSTOMERS...

CREATE OR REPLACE TRIGGER TRG_AUDIT_CUSTOMERS
    AFTER INSERT OR UPDATE OR DELETE ON CUSTOMERS
    FOR EACH ROW
DECLARE
    v_operation VARCHAR2(10);
    v_record_id NUMBER;
BEGIN
    IF INSERTING THEN
        v_operation := 'INSERT';
        v_record_id := :NEW.customer_id;
        
        INSERT INTO AUDIT_LOG (audit_id, table_name, record_id, operation, column_name, new_value, changed_by, changed_at)
        VALUES (seq_audit_log_id.NEXTVAL, 'CUSTOMERS', v_record_id, v_operation, 'ALL_COLUMNS', 
                'name=' || :NEW.name || '|tier=' || NVL(:NEW.tier, 'NULL') || '|company=' || NVL(:NEW.company, 'NULL'),
                USER, CURRENT_TIMESTAMP);
                
    ELSIF UPDATING THEN
        v_operation := 'UPDATE';
        v_record_id := :NEW.customer_id;
        
        IF NVL(:OLD.name, 'NULL') != NVL(:NEW.name, 'NULL') THEN
            INSERT INTO AUDIT_LOG (audit_id, table_name, record_id, operation, column_name, old_value, new_value, changed_by, changed_at)
            VALUES (seq_audit_log_id.NEXTVAL, 'CUSTOMERS', v_record_id, v_operation, 'name', 
                    :OLD.name, :NEW.name, USER, CURRENT_TIMESTAMP);
        END IF;
        
        IF NVL(:OLD.tier, 'NULL') != NVL(:NEW.tier, 'NULL') THEN
            INSERT INTO AUDIT_LOG (audit_id, table_name, record_id, operation, column_name, old_value, new_value, changed_by, changed_at)
            VALUES (seq_audit_log_id.NEXTVAL, 'CUSTOMERS', v_record_id, v_operation, 'tier', 
                    :OLD.tier, :NEW.tier, USER, CURRENT_TIMESTAMP);
        END IF;
        
        IF NVL(:OLD.contact, 'NULL') != NVL(:NEW.contact, 'NULL') THEN
            INSERT INTO AUDIT_LOG (audit_id, table_name, record_id, operation, column_name, old_value, new_value, changed_by, changed_at)
            VALUES (seq_audit_log_id.NEXTVAL, 'CUSTOMERS', v_record_id, v_operation, 'contact', 
                    :OLD.contact, :NEW.contact, USER, CURRENT_TIMESTAMP);
        END IF;
        
    ELSIF DELETING THEN
        v_operation := 'DELETE';
        v_record_id := :OLD.customer_id;
        
        INSERT INTO AUDIT_LOG (audit_id, table_name, record_id, operation, column_name, old_value, changed_by, changed_at)
        VALUES (seq_audit_log_id.NEXTVAL, 'CUSTOMERS', v_record_id, v_operation, 'RECORD_DELETED', 
                'name=' || :OLD.name || '|tier=' || :OLD.tier,
                USER, CURRENT_TIMESTAMP);
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Warning: Audit logging error for CUSTOMERS: ' || SQLERRM);
END;
/

PROMPT Trigger TRG_AUDIT_CUSTOMERS created successfully.

-- ============================================================================
-- 9.6 AUDIT TRIGGER FOR TECHNICIANS
-- ============================================================================

PROMPT Creating audit triggers for TECHNICIANS...

CREATE OR REPLACE TRIGGER TRG_AUDIT_TECHNICIANS
    AFTER INSERT OR UPDATE OR DELETE ON TECHNICIANS
    FOR EACH ROW
DECLARE
    v_operation VARCHAR2(10);
    v_record_id NUMBER;
BEGIN
    IF INSERTING THEN
        v_operation := 'INSERT';
        v_record_id := :NEW.technician_id;
        
        INSERT INTO AUDIT_LOG (audit_id, table_name, record_id, operation, column_name, new_value, changed_by, changed_at)
        VALUES (seq_audit_log_id.NEXTVAL, 'TECHNICIANS', v_record_id, v_operation, 'ALL_COLUMNS', 
                'name=' || :NEW.name || '|skill_level=' || :NEW.skill_level || '|availability=' || :NEW.availability,
                USER, CURRENT_TIMESTAMP);
                
    ELSIF UPDATING THEN
        v_operation := 'UPDATE';
        v_record_id := :NEW.technician_id;
        
        IF NVL(:OLD.availability, 'NULL') != NVL(:NEW.availability, 'NULL') THEN
            INSERT INTO AUDIT_LOG (audit_id, table_name, record_id, operation, column_name, old_value, new_value, changed_by, changed_at)
            VALUES (seq_audit_log_id.NEXTVAL, 'TECHNICIANS', v_record_id, v_operation, 'availability', 
                    :OLD.availability, :NEW.availability, USER, CURRENT_TIMESTAMP);
        END IF;
        
        IF NVL(:OLD.skill_level, 'NULL') != NVL(:NEW.skill_level, 'NULL') THEN
            INSERT INTO AUDIT_LOG (audit_id, table_name, record_id, operation, column_name, old_value, new_value, changed_by, changed_at)
            VALUES (seq_audit_log_id.NEXTVAL, 'TECHNICIANS', v_record_id, v_operation, 'skill_level', 
                    :OLD.skill_level, :NEW.skill_level, USER, CURRENT_TIMESTAMP);
        END IF;
        
    ELSIF DELETING THEN
        v_operation := 'DELETE';
        v_record_id := :OLD.technician_id;
        
        INSERT INTO AUDIT_LOG (audit_id, table_name, record_id, operation, column_name, old_value, changed_by, changed_at)
        VALUES (seq_audit_log_id.NEXTVAL, 'TECHNICIANS', v_record_id, v_operation, 'RECORD_DELETED', 
                'name=' || :OLD.name || '|skill_level=' || :OLD.skill_level,
                USER, CURRENT_TIMESTAMP);
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Warning: Audit logging error for TECHNICIANS: ' || SQLERRM);
END;
/

PROMPT Trigger TRG_AUDIT_TECHNICIANS created successfully.

-- ============================================================================
-- 9.7 AUDIT TRIGGER FOR FEEDBACK
-- ============================================================================

PROMPT Creating audit triggers for FEEDBACK...

CREATE OR REPLACE TRIGGER TRG_AUDIT_FEEDBACK
    AFTER INSERT OR UPDATE OR DELETE ON FEEDBACK
    FOR EACH ROW
DECLARE
    v_operation VARCHAR2(10);
    v_record_id NUMBER;
BEGIN
    IF INSERTING THEN
        v_operation := 'INSERT';
        v_record_id := :NEW.feedback_id;
        
        INSERT INTO AUDIT_LOG (audit_id, table_name, record_id, operation, column_name, new_value, changed_by, changed_at)
        VALUES (seq_audit_log_id.NEXTVAL, 'FEEDBACK', v_record_id, v_operation, 'ALL_COLUMNS', 
                'request_id=' || :NEW.request_id || '|rating=' || TO_CHAR(:NEW.rating),
                USER, CURRENT_TIMESTAMP);
                
    ELSIF UPDATING THEN
        v_operation := 'UPDATE';
        v_record_id := :NEW.feedback_id;
        
        IF NVL(:OLD.rating, -1) != NVL(:NEW.rating, -1) THEN
            INSERT INTO AUDIT_LOG (audit_id, table_name, record_id, operation, column_name, old_value, new_value, changed_by, changed_at)
            VALUES (seq_audit_log_id.NEXTVAL, 'FEEDBACK', v_record_id, v_operation, 'rating', 
                    TO_CHAR(:OLD.rating), TO_CHAR(:NEW.rating), USER, CURRENT_TIMESTAMP);
        END IF;
        
    ELSIF DELETING THEN
        v_operation := 'DELETE';
        v_record_id := :OLD.feedback_id;
        
        INSERT INTO AUDIT_LOG (audit_id, table_name, record_id, operation, column_name, old_value, changed_by, changed_at)
        VALUES (seq_audit_log_id.NEXTVAL, 'FEEDBACK', v_record_id, v_operation, 'RECORD_DELETED', 
                'request_id=' || :OLD.request_id || '|rating=' || TO_CHAR(:OLD.rating),
                USER, CURRENT_TIMESTAMP);
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Warning: Audit logging error for FEEDBACK: ' || SQLERRM);
END;
/

PROMPT Trigger TRG_AUDIT_FEEDBACK created successfully.

-- ============================================================================
-- 9.8 AUDIT REPORTING PACKAGE
-- ============================================================================

PROMPT Creating audit reporting package PKG_AUDIT_REPORTING...

CREATE OR REPLACE PACKAGE PKG_AUDIT_REPORTING
AS
    -- Procedure: Get audit trail for a specific record
    PROCEDURE PROC_GET_RECORD_AUDIT_TRAIL(
        p_table_name IN VARCHAR2,
        p_record_id IN NUMBER
    );
    
    -- Procedure: Get audit trail for a specific user
    PROCEDURE PROC_GET_USER_AUDIT_TRAIL(
        p_username IN VARCHAR2,
        p_start_date IN DATE DEFAULT NULL,
        p_end_date IN DATE DEFAULT NULL
    );
    
    -- Procedure: Get audit trail for a specific table
    PROCEDURE PROC_GET_TABLE_AUDIT_TRAIL(
        p_table_name IN VARCHAR2,
        p_start_date IN DATE DEFAULT NULL,
        p_end_date IN DATE DEFAULT NULL
    );
    
    -- Function: Get change count for a record
    FUNCTION FUNC_GET_CHANGE_COUNT(
        p_table_name IN VARCHAR2,
        p_record_id IN NUMBER
    ) RETURN NUMBER;
    
    -- Procedure: Generate audit summary report
    PROCEDURE PROC_GENERATE_AUDIT_SUMMARY(
        p_start_date IN DATE DEFAULT NULL,
        p_end_date IN DATE DEFAULT NULL
    );
    
END PKG_AUDIT_REPORTING;
/

CREATE OR REPLACE PACKAGE BODY PKG_AUDIT_REPORTING
AS
    
    -- Procedure: Get audit trail for a specific record
    PROCEDURE PROC_GET_RECORD_AUDIT_TRAIL(
        p_table_name IN VARCHAR2,
        p_record_id IN NUMBER
    )
    IS
    BEGIN
        DBMS_OUTPUT.PUT_LINE('==================================================================');
        DBMS_OUTPUT.PUT_LINE('AUDIT TRAIL FOR ' || UPPER(p_table_name) || ' - Record ID: ' || p_record_id);
        DBMS_OUTPUT.PUT_LINE('==================================================================');
        DBMS_OUTPUT.PUT_LINE('');
        
        FOR rec IN (
            SELECT audit_id, operation, column_name, old_value, new_value, 
                   changed_by, TO_CHAR(changed_at, 'YYYY-MM-DD HH24:MI:SS') AS change_time
            FROM AUDIT_LOG
            WHERE table_name = UPPER(p_table_name)
              AND record_id = p_record_id
            ORDER BY changed_at DESC
        ) LOOP
            DBMS_OUTPUT.PUT_LINE('Change #' || rec.audit_id || ' - ' || rec.operation || ' at ' || rec.change_time);
            DBMS_OUTPUT.PUT_LINE('  Changed by: ' || rec.changed_by);
            IF rec.column_name != 'ALL_COLUMNS' AND rec.column_name != 'RECORD_DELETED' THEN
                DBMS_OUTPUT.PUT_LINE('  Column: ' || rec.column_name);
                DBMS_OUTPUT.PUT_LINE('  Old Value: ' || NVL(rec.old_value, 'NULL'));
                DBMS_OUTPUT.PUT_LINE('  New Value: ' || NVL(rec.new_value, 'NULL'));
            ELSIF rec.column_name = 'ALL_COLUMNS' THEN
                DBMS_OUTPUT.PUT_LINE('  New Record Values: ' || rec.new_value);
            ELSIF rec.column_name = 'RECORD_DELETED' THEN
                DBMS_OUTPUT.PUT_LINE('  Deleted Record Values: ' || rec.old_value);
            END IF;
            DBMS_OUTPUT.PUT_LINE('');
        END LOOP;
        
        DBMS_OUTPUT.PUT_LINE('==================================================================');
        
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('Error retrieving audit trail: ' || SQLERRM);
    END PROC_GET_RECORD_AUDIT_TRAIL;
    
    -- Procedure: Get audit trail for a specific user
    PROCEDURE PROC_GET_USER_AUDIT_TRAIL(
        p_username IN VARCHAR2,
        p_start_date IN DATE DEFAULT NULL,
        p_end_date IN DATE DEFAULT NULL
    )
    IS
        v_start DATE;
        v_end DATE;
        v_count NUMBER := 0;
    BEGIN
        v_end := NVL(p_end_date, SYSDATE);
        v_start := NVL(p_start_date, v_end - 30);
        
        DBMS_OUTPUT.PUT_LINE('==================================================================');
        DBMS_OUTPUT.PUT_LINE('AUDIT TRAIL FOR USER: ' || UPPER(p_username));
        DBMS_OUTPUT.PUT_LINE('Period: ' || TO_CHAR(v_start, 'YYYY-MM-DD') || ' to ' || TO_CHAR(v_end, 'YYYY-MM-DD'));
        DBMS_OUTPUT.PUT_LINE('==================================================================');
        DBMS_OUTPUT.PUT_LINE('');
        
        FOR rec IN (
            SELECT audit_id, table_name, record_id, operation, column_name, 
                   TO_CHAR(changed_at, 'YYYY-MM-DD HH24:MI:SS') AS change_time
            FROM AUDIT_LOG
            WHERE changed_by = UPPER(p_username)
              AND changed_at BETWEEN v_start AND v_end
            ORDER BY changed_at DESC
        ) LOOP
            v_count := v_count + 1;
            DBMS_OUTPUT.PUT_LINE(v_count || '. ' || rec.operation || ' on ' || rec.table_name || 
                                ' (ID: ' || rec.record_id || ') at ' || rec.change_time);
            IF rec.column_name IS NOT NULL THEN
                DBMS_OUTPUT.PUT_LINE('   Column: ' || rec.column_name);
            END IF;
        END LOOP;
        
        IF v_count = 0 THEN
            DBMS_OUTPUT.PUT_LINE('No audit records found for this user in the specified period.');
        ELSE
            DBMS_OUTPUT.PUT_LINE('');
            DBMS_OUTPUT.PUT_LINE('Total changes: ' || v_count);
        END IF;
        
        DBMS_OUTPUT.PUT_LINE('==================================================================');
        
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('Error retrieving user audit trail: ' || SQLERRM);
    END PROC_GET_USER_AUDIT_TRAIL;
    
    -- Procedure: Get audit trail for a specific table
    PROCEDURE PROC_GET_TABLE_AUDIT_TRAIL(
        p_table_name IN VARCHAR2,
        p_start_date IN DATE DEFAULT NULL,
        p_end_date IN DATE DEFAULT NULL
    )
    IS
        v_start DATE;
        v_end DATE;
        v_count NUMBER := 0;
    BEGIN
        v_end := NVL(p_end_date, SYSDATE);
        v_start := NVL(p_start_date, v_end - 30);
        
        DBMS_OUTPUT.PUT_LINE('==================================================================');
        DBMS_OUTPUT.PUT_LINE('AUDIT TRAIL FOR TABLE: ' || UPPER(p_table_name));
        DBMS_OUTPUT.PUT_LINE('Period: ' || TO_CHAR(v_start, 'YYYY-MM-DD') || ' to ' || TO_CHAR(v_end, 'YYYY-MM-DD'));
        DBMS_OUTPUT.PUT_LINE('==================================================================');
        DBMS_OUTPUT.PUT_LINE('');
        
        FOR rec IN (
            SELECT audit_id, record_id, operation, column_name, changed_by,
                   TO_CHAR(changed_at, 'YYYY-MM-DD HH24:MI:SS') AS change_time
            FROM AUDIT_LOG
            WHERE table_name = UPPER(p_table_name)
              AND changed_at BETWEEN v_start AND v_end
            ORDER BY changed_at DESC
        ) LOOP
            v_count := v_count + 1;
            DBMS_OUTPUT.PUT_LINE(v_count || '. ' || rec.operation || ' on Record ID: ' || rec.record_id || 
                                ' by ' || rec.changed_by || ' at ' || rec.change_time);
            IF rec.column_name IS NOT NULL AND rec.column_name NOT IN ('ALL_COLUMNS', 'RECORD_DELETED') THEN
                DBMS_OUTPUT.PUT_LINE('   Column: ' || rec.column_name);
            END IF;
        END LOOP;
        
        IF v_count = 0 THEN
            DBMS_OUTPUT.PUT_LINE('No audit records found for this table in the specified period.');
        ELSE
            DBMS_OUTPUT.PUT_LINE('');
            DBMS_OUTPUT.PUT_LINE('Total changes: ' || v_count);
        END IF;
        
        DBMS_OUTPUT.PUT_LINE('==================================================================');
        
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('Error retrieving table audit trail: ' || SQLERRM);
    END PROC_GET_TABLE_AUDIT_TRAIL;
    
    -- Function: Get change count for a record
    FUNCTION FUNC_GET_CHANGE_COUNT(
        p_table_name IN VARCHAR2,
        p_record_id IN NUMBER
    ) RETURN NUMBER
    IS
        v_count NUMBER;
    BEGIN
        SELECT COUNT(*)
        INTO v_count
        FROM AUDIT_LOG
        WHERE table_name = UPPER(p_table_name)
          AND record_id = p_record_id;
        
        RETURN v_count;
    EXCEPTION
        WHEN OTHERS THEN
            RETURN 0;
    END FUNC_GET_CHANGE_COUNT;
    
    -- Procedure: Generate audit summary report
    PROCEDURE PROC_GENERATE_AUDIT_SUMMARY(
        p_start_date IN DATE DEFAULT NULL,
        p_end_date IN DATE DEFAULT NULL
    )
    IS
        v_start DATE;
        v_end DATE;
    BEGIN
        v_end := NVL(p_end_date, SYSDATE);
        v_start := NVL(p_start_date, v_end - 30);
        
        DBMS_OUTPUT.PUT_LINE('==================================================================');
        DBMS_OUTPUT.PUT_LINE('AUDIT SUMMARY REPORT');
        DBMS_OUTPUT.PUT_LINE('Period: ' || TO_CHAR(v_start, 'YYYY-MM-DD') || ' to ' || TO_CHAR(v_end, 'YYYY-MM-DD'));
        DBMS_OUTPUT.PUT_LINE('Generated: ' || TO_CHAR(SYSDATE, 'YYYY-MM-DD HH24:MI:SS'));
        DBMS_OUTPUT.PUT_LINE('==================================================================');
        DBMS_OUTPUT.PUT_LINE('');
        
        DBMS_OUTPUT.PUT_LINE('CHANGES BY TABLE:');
        FOR rec IN (
            SELECT table_name, operation, COUNT(*) AS change_count
            FROM AUDIT_LOG
            WHERE changed_at BETWEEN v_start AND v_end
            GROUP BY table_name, operation
            ORDER BY table_name, operation
        ) LOOP
            DBMS_OUTPUT.PUT_LINE('  ' || rec.table_name || ' - ' || rec.operation || ': ' || rec.change_count);
        END LOOP;
        
        DBMS_OUTPUT.PUT_LINE('');
        DBMS_OUTPUT.PUT_LINE('CHANGES BY USER:');
        FOR rec IN (
            SELECT changed_by, COUNT(*) AS change_count
            FROM AUDIT_LOG
            WHERE changed_at BETWEEN v_start AND v_end
            GROUP BY changed_by
            ORDER BY change_count DESC
        ) LOOP
            DBMS_OUTPUT.PUT_LINE('  ' || rec.changed_by || ': ' || rec.change_count || ' changes');
        END LOOP;
        
        DBMS_OUTPUT.PUT_LINE('');
        DBMS_OUTPUT.PUT_LINE('TOTAL CHANGES: ' || 
            (SELECT COUNT(*) FROM AUDIT_LOG WHERE changed_at BETWEEN v_start AND v_end));
        
        DBMS_OUTPUT.PUT_LINE('==================================================================');
        
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('Error generating audit summary: ' || SQLERRM);
    END PROC_GENERATE_AUDIT_SUMMARY;
    
END PKG_AUDIT_REPORTING;
/

PROMPT Package PKG_AUDIT_REPORTING created successfully.

-- ============================================================================
-- 9.9 GRANT PRIVILEGES FOR AUDIT SYSTEM
-- ============================================================================

PROMPT Granting privileges on audit objects...

BEGIN
    -- Grant SELECT on AUDIT_LOG to roles (if they exist)
    BEGIN
        EXECUTE IMMEDIATE 'GRANT SELECT ON AUDIT_LOG TO CRM_ADMIN';
        EXECUTE IMMEDIATE 'GRANT SELECT ON AUDIT_LOG TO CRM_MANAGER';
        EXECUTE IMMEDIATE 'GRANT SELECT ON AUDIT_LOG TO CRM_ANALYST';
        EXECUTE IMMEDIATE 'GRANT EXECUTE ON PKG_AUDIT_REPORTING TO CRM_ADMIN';
        EXECUTE IMMEDIATE 'GRANT EXECUTE ON PKG_AUDIT_REPORTING TO CRM_MANAGER';
        EXECUTE IMMEDIATE 'GRANT EXECUTE ON PKG_AUDIT_REPORTING TO CRM_ANALYST';
        DBMS_OUTPUT.PUT_LINE('Audit privileges granted to roles successfully.');
    EXCEPTION
        WHEN OTHERS THEN
            IF SQLCODE = -1917 THEN
                DBMS_OUTPUT.PUT_LINE('Note: Roles do not exist. Audit system will still function.');
            ELSE
                DBMS_OUTPUT.PUT_LINE('Warning: Some privilege grants may have failed: ' || SQLERRM);
            END IF;
    END;
END;
/

-- ============================================================================
-- 9.10 VERIFICATION
-- ============================================================================

PROMPT Verifying audit system implementation...

SELECT 'AUDIT_LOG' AS object_name, 'TABLE' AS object_type, COUNT(*) AS row_count FROM AUDIT_LOG
UNION ALL
SELECT 'seq_audit_log_id', 'SEQUENCE', NULL FROM DUAL
UNION ALL
SELECT trigger_name, 'TRIGGER', NULL 
FROM user_triggers 
WHERE trigger_name LIKE 'TRG_AUDIT_%'
UNION ALL
SELECT object_name, object_type, NULL
FROM user_objects
WHERE object_name = 'PKG_AUDIT_REPORTING'
  AND object_type IN ('PACKAGE', 'PACKAGE BODY');

PROMPT 
PROMPT Audit triggers created:
SELECT trigger_name, status, trigger_type, triggering_event
FROM user_triggers
WHERE trigger_name LIKE 'TRG_AUDIT_%'
ORDER BY trigger_name;

PROMPT 
PROMPT Phase 9 Complete: Audit system implemented successfully!
PROMPT 
PROMPT Audit System Summary:
PROMPT   - AUDIT_LOG table created with indexes
PROMPT   - seq_audit_log_id sequence created
PROMPT   - 5 Audit triggers created (SERVICE_REQUESTS, ASSIGNMENTS, CUSTOMERS, TECHNICIANS, FEEDBACK)
PROMPT   - PKG_AUDIT_REPORTING package created for querying audit history
PROMPT 
PROMPT Usage Examples:
PROMPT   - Get audit trail for a record:
PROMPT     EXEC PKG_AUDIT_REPORTING.PROC_GET_RECORD_AUDIT_TRAIL('SERVICE_REQUESTS', 1);
PROMPT   - Get audit trail for a user:
PROMPT     EXEC PKG_AUDIT_REPORTING.PROC_GET_USER_AUDIT_TRAIL('USERNAME');
PROMPT   - Generate audit summary:
PROMPT     EXEC PKG_AUDIT_REPORTING.PROC_GENERATE_AUDIT_SUMMARY;
PROMPT 
PROMPT Ready for production use!

