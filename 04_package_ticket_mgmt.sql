-- ============================================================================
-- CRM Database System - Ticket Management Package
-- Phase 4.1: PKG_TICKET_MANAGEMENT Package
-- Target PDB: lu_plsqlauca_25815
-- Oracle SQL Developer 24.3
-- ============================================================================

SET SERVEROUTPUT ON;
PROMPT Creating package PKG_TICKET_MANAGEMENT...

-- ============================================================================
-- PACKAGE SPECIFICATION
-- ============================================================================

CREATE OR REPLACE PACKAGE PKG_TICKET_MANAGEMENT
AS
    -- Function: Create a new service request
    -- Returns: request_id of the newly created request
    FUNCTION FUNC_CREATE_REQUEST(
        p_customer_id IN NUMBER,
        p_product_id IN NUMBER,
        p_issue_type IN VARCHAR2,
        p_priority IN VARCHAR2 DEFAULT 'Medium'
    ) RETURN NUMBER;

    -- Function: Update request status
    -- Returns: TRUE if successful, FALSE otherwise
    FUNCTION FUNC_UPDATE_STATUS(
        p_request_id IN NUMBER,
        p_status IN VARCHAR2
    ) RETURN BOOLEAN;

    -- Procedure: Reassign a ticket to a different technician
    PROCEDURE PROC_REASSIGN_TICKET(
        p_request_id IN NUMBER,
        p_technician_id IN NUMBER
    );

    -- Procedure: Close a request with resolution notes
    PROCEDURE PROC_CLOSE_REQUEST(
        p_request_id IN NUMBER,
        p_resolution_notes IN VARCHAR2 DEFAULT NULL
    );

END PKG_TICKET_MANAGEMENT;
/

-- ============================================================================
-- PACKAGE BODY
-- ============================================================================

CREATE OR REPLACE PACKAGE BODY PKG_TICKET_MANAGEMENT
AS

    -- Function: Create a new service request
    FUNCTION FUNC_CREATE_REQUEST(
        p_customer_id IN NUMBER,
        p_product_id IN NUMBER,
        p_issue_type IN VARCHAR2,
        p_priority IN VARCHAR2 DEFAULT 'Medium'
    ) RETURN NUMBER
    IS
        v_request_id NUMBER;
        v_priority_exists NUMBER;
        v_customer_exists NUMBER;
        v_product_exists NUMBER;
    BEGIN
        -- Validate priority exists in SLA_RULES
        SELECT COUNT(*)
        INTO v_priority_exists
        FROM SLA_RULES
        WHERE priority_level = p_priority;

        IF v_priority_exists = 0 THEN
            RAISE_APPLICATION_ERROR(-20001, 'Invalid priority level: ' || p_priority);
        END IF;

        -- Validate customer exists
        SELECT COUNT(*)
        INTO v_customer_exists
        FROM CUSTOMERS
        WHERE customer_id = p_customer_id;
        
        IF v_customer_exists = 0 THEN
            RAISE_APPLICATION_ERROR(-20002, 'Customer ID ' || p_customer_id || ' does not exist');
        END IF;

        -- Validate product exists (if provided)
        IF p_product_id IS NOT NULL THEN
            SELECT COUNT(*)
            INTO v_product_exists
            FROM PRODUCTS
            WHERE product_id = p_product_id;
            
            IF v_product_exists = 0 THEN
                RAISE_APPLICATION_ERROR(-20003, 'Product ID ' || p_product_id || ' does not exist');
            END IF;
        END IF;

        -- Insert new service request
        INSERT INTO SERVICE_REQUESTS (
            request_id, customer_id, product_id, issue_type, priority, status, created_at
        ) VALUES (
            seq_request_id.NEXTVAL, p_customer_id, p_product_id, p_issue_type, 
            p_priority, 'Open', CURRENT_TIMESTAMP
        )
        RETURNING request_id INTO v_request_id;

        COMMIT;

        DBMS_OUTPUT.PUT_LINE('Service request ' || v_request_id || ' created successfully');
        
        -- Note: Auto-assignment trigger will handle assignment automatically
        
        RETURN v_request_id;

    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            DBMS_OUTPUT.PUT_LINE('Error creating request: ' || SQLERRM);
            RAISE;
    END FUNC_CREATE_REQUEST;

    -- Function: Update request status
    FUNCTION FUNC_UPDATE_STATUS(
        p_request_id IN NUMBER,
        p_status IN VARCHAR2
    ) RETURN BOOLEAN
    IS
        v_valid_status NUMBER;
        v_current_status VARCHAR2(20);
    BEGIN
        -- Validate status value
        SELECT COUNT(*)
        INTO v_valid_status
        FROM DUAL
        WHERE p_status IN ('Open', 'Assigned', 'In Progress', 'Resolved', 'Closed');

        IF v_valid_status = 0 THEN
            RAISE_APPLICATION_ERROR(-20004, 'Invalid status: ' || p_status);
        END IF;

        -- Get current status
        SELECT status
        INTO v_current_status
        FROM SERVICE_REQUESTS
        WHERE request_id = p_request_id;

        -- Update status
        UPDATE SERVICE_REQUESTS
        SET status = p_status,
            resolved_at = CASE 
                            WHEN p_status IN ('Resolved', 'Closed') AND resolved_at IS NULL 
                            THEN CURRENT_TIMESTAMP 
                            ELSE resolved_at 
                          END
        WHERE request_id = p_request_id;

        IF SQL%ROWCOUNT = 0 THEN
            RAISE_APPLICATION_ERROR(-20005, 'Request ID ' || p_request_id || ' does not exist');
        END IF;

        COMMIT;

        DBMS_OUTPUT.PUT_LINE('Request ' || p_request_id || ' status updated from ' || 
                            v_current_status || ' to ' || p_status);

        RETURN TRUE;

    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            ROLLBACK;
            RAISE_APPLICATION_ERROR(-20005, 'Request ID ' || p_request_id || ' does not exist');
        WHEN OTHERS THEN
            ROLLBACK;
            DBMS_OUTPUT.PUT_LINE('Error updating status: ' || SQLERRM);
            RETURN FALSE;
    END FUNC_UPDATE_STATUS;

    -- Procedure: Reassign a ticket to a different technician
    PROCEDURE PROC_REASSIGN_TICKET(
        p_request_id IN NUMBER,
        p_technician_id IN NUMBER
    )
    IS
        v_request_exists NUMBER;
        v_technician_exists NUMBER;
        v_current_tech_id NUMBER;
    BEGIN
        -- Validate request exists
        SELECT COUNT(*)
        INTO v_request_exists
        FROM SERVICE_REQUESTS
        WHERE request_id = p_request_id;

        IF v_request_exists = 0 THEN
            RAISE_APPLICATION_ERROR(-20006, 'Request ID ' || p_request_id || ' does not exist');
        END IF;

        -- Validate technician exists
        SELECT COUNT(*)
        INTO v_technician_exists
        FROM TECHNICIANS
        WHERE technician_id = p_technician_id;

        IF v_technician_exists = 0 THEN
            RAISE_APPLICATION_ERROR(-20007, 'Technician ID ' || p_technician_id || ' does not exist');
        END IF;

        -- Get current assignment
        SELECT technician_id
        INTO v_current_tech_id
        FROM ASSIGNMENTS
        WHERE request_id = p_request_id;

        -- Update assignment
        UPDATE ASSIGNMENTS
        SET technician_id = p_technician_id,
            assigned_at = CURRENT_TIMESTAMP
        WHERE request_id = p_request_id;

        IF SQL%ROWCOUNT = 0 THEN
            -- Create new assignment if none exists
            INSERT INTO ASSIGNMENTS (assignment_id, request_id, technician_id, assigned_at)
            VALUES (seq_assignment_id.NEXTVAL, p_request_id, p_technician_id, CURRENT_TIMESTAMP);
        END IF;

        -- Update request status to 'Assigned' if not already
        UPDATE SERVICE_REQUESTS
        SET status = 'Assigned'
        WHERE request_id = p_request_id
          AND status = 'Open';

        COMMIT;

        IF v_current_tech_id IS NOT NULL THEN
            DBMS_OUTPUT.PUT_LINE('Request ' || p_request_id || ' reassigned from Technician ' || 
                                v_current_tech_id || ' to Technician ' || p_technician_id);
        ELSE
            DBMS_OUTPUT.PUT_LINE('Request ' || p_request_id || ' assigned to Technician ' || p_technician_id);
        END IF;

    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            -- Assignment doesn't exist, create new one
            INSERT INTO ASSIGNMENTS (assignment_id, request_id, technician_id, assigned_at)
            VALUES (seq_assignment_id.NEXTVAL, p_request_id, p_technician_id, CURRENT_TIMESTAMP);
            COMMIT;
        WHEN OTHERS THEN
            ROLLBACK;
            DBMS_OUTPUT.PUT_LINE('Error reassigning ticket: ' || SQLERRM);
            RAISE;
    END PROC_REASSIGN_TICKET;

    -- Procedure: Close a request with resolution notes
    PROCEDURE PROC_CLOSE_REQUEST(
        p_request_id IN NUMBER,
        p_resolution_notes IN VARCHAR2 DEFAULT NULL
    )
    IS
        v_request_exists NUMBER;
    BEGIN
        -- Validate request exists
        SELECT COUNT(*)
        INTO v_request_exists
        FROM SERVICE_REQUESTS
        WHERE request_id = p_request_id;

        IF v_request_exists = 0 THEN
            RAISE_APPLICATION_ERROR(-20008, 'Request ID ' || p_request_id || ' does not exist');
        END IF;

        -- Update request status
        UPDATE SERVICE_REQUESTS
        SET status = 'Closed',
            resolved_at = NVL(resolved_at, CURRENT_TIMESTAMP)
        WHERE request_id = p_request_id;

        -- Note: Resolution notes could be stored in a separate table if needed
        -- For now, we'll just close the request
        -- If a NOTES table exists, it could be updated here

        COMMIT;

        DBMS_OUTPUT.PUT_LINE('Request ' || p_request_id || ' closed successfully');
        IF p_resolution_notes IS NOT NULL THEN
            DBMS_OUTPUT.PUT_LINE('Resolution notes: ' || p_resolution_notes);
        END IF;

    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            DBMS_OUTPUT.PUT_LINE('Error closing request: ' || SQLERRM);
            RAISE;
    END PROC_CLOSE_REQUEST;

END PKG_TICKET_MANAGEMENT;
/

PROMPT Package PKG_TICKET_MANAGEMENT created successfully.

-- Verification
SELECT object_name, object_type, status
FROM user_objects
WHERE object_name = 'PKG_TICKET_MANAGEMENT'
ORDER BY object_type;

