-- ============================================================================
-- CRM Database System - PL/SQL Triggers
-- Phase 2: Auto-Assignment and Feedback Status Update Triggers
-- Target PDB: lu_plsqlauca_25815
-- Oracle SQL Developer 24.3
-- ============================================================================

SET SERVEROUTPUT ON;
PROMPT Starting Phase 2: Trigger Implementation...

-- ============================================================================
-- 2.1 AUTO-ASSIGNMENT TRIGGER (Using Compound Trigger to avoid mutating table)
-- ============================================================================

PROMPT Creating trigger TRG_AUTO_ASSIGN_TECHNICIAN...

CREATE OR REPLACE TRIGGER TRG_AUTO_ASSIGN_TECHNICIAN
    FOR INSERT ON SERVICE_REQUESTS
    COMPOUND TRIGGER
    
    -- Collection to store request IDs and technician IDs that need status updates
    TYPE t_request_info IS RECORD (
        request_id NUMBER,
        technician_id NUMBER
    );
    TYPE t_request_array IS TABLE OF t_request_info INDEX BY PLS_INTEGER;
    g_requests t_request_array;
    g_count NUMBER := 0;
    
    AFTER EACH ROW IS
        v_technician_id NUMBER;
        v_skill_required VARCHAR2(20);
        v_max_workload NUMBER := 5;
    BEGIN
        -- Only process if status is 'Open'
        IF :NEW.status = 'Open' THEN
            -- Determine required skill level based on priority
            CASE :NEW.priority
                WHEN 'Low' THEN v_skill_required := 'Junior';
                WHEN 'Medium' THEN v_skill_required := 'Mid';
                WHEN 'High' THEN v_skill_required := 'Senior';
                WHEN 'Critical' THEN v_skill_required := 'Expert';
                ELSE v_skill_required := 'Mid';
            END CASE;

            -- Find best available technician (avoid querying SERVICE_REQUESTS)
            BEGIN
                SELECT t.technician_id
                INTO v_technician_id
                FROM TECHNICIANS t
                LEFT JOIN (
                    SELECT a.technician_id, COUNT(*) AS assignment_count
                    FROM ASSIGNMENTS a
                    GROUP BY a.technician_id
                ) workload ON t.technician_id = workload.technician_id
                WHERE t.availability = 'Available'
                  AND (
                      (v_skill_required = 'Junior' AND t.skill_level IN ('Junior', 'Mid', 'Senior', 'Expert'))
                      OR (v_skill_required = 'Mid' AND t.skill_level IN ('Mid', 'Senior', 'Expert'))
                      OR (v_skill_required = 'Senior' AND t.skill_level IN ('Senior', 'Expert'))
                      OR (v_skill_required = 'Expert' AND t.skill_level = 'Expert')
                  )
                  AND (workload.assignment_count IS NULL OR workload.assignment_count < v_max_workload)
                ORDER BY 
                    CASE t.skill_level
                        WHEN 'Junior' THEN 4
                        WHEN 'Mid' THEN 3
                        WHEN 'Senior' THEN 2
                        WHEN 'Expert' THEN 1
                    END,
                    NVL(workload.assignment_count, 0) ASC,
                    t.technician_id ASC
                FETCH FIRST 1 ROW ONLY;

                -- Store request info for processing in AFTER STATEMENT
                IF v_technician_id IS NOT NULL THEN
                    g_count := g_count + 1;
                    g_requests(g_count).request_id := :NEW.request_id;
                    g_requests(g_count).technician_id := v_technician_id;
                    
                    -- Insert assignment immediately (this is safe - different table)
                    INSERT INTO ASSIGNMENTS (assignment_id, request_id, technician_id, assigned_at)
                    VALUES (seq_assignment_id.NEXTVAL, :NEW.request_id, v_technician_id, CURRENT_TIMESTAMP);
                    
                    DBMS_OUTPUT.PUT_LINE('Request ' || :NEW.request_id || ' automatically assigned to Technician ' || v_technician_id);
                ELSE
                    DBMS_OUTPUT.PUT_LINE('Warning: No available technician found for Request ' || :NEW.request_id);
                END IF;
            EXCEPTION
                WHEN NO_DATA_FOUND THEN
                    DBMS_OUTPUT.PUT_LINE('Warning: No available technician found for Request ' || :NEW.request_id);
            END;
        END IF;
    END AFTER EACH ROW;
    
    AFTER STATEMENT IS
        v_active_count NUMBER;
    BEGIN
        -- Update status and technician availability AFTER the statement completes
        -- Now SERVICE_REQUESTS is no longer mutating
        FOR i IN 1 .. g_count LOOP
            BEGIN
                -- Update request status to 'Assigned' (now safe - table is no longer mutating)
                UPDATE SERVICE_REQUESTS
                SET status = 'Assigned'
                WHERE request_id = g_requests(i).request_id;

                -- Update technician availability if workload threshold reached
                SELECT COUNT(*)
                INTO v_active_count
                FROM ASSIGNMENTS
                WHERE technician_id = g_requests(i).technician_id;

                IF v_active_count >= 5 THEN
                    UPDATE TECHNICIANS
                    SET availability = 'Busy'
                    WHERE technician_id = g_requests(i).technician_id;
                END IF;
            EXCEPTION
                WHEN OTHERS THEN
                    NULL; -- Ignore errors in AFTER STATEMENT
            END;
        END LOOP;
        
        -- Reset collection for next statement
        g_count := 0;
    END AFTER STATEMENT;
    
END TRG_AUTO_ASSIGN_TECHNICIAN;
/

PROMPT Trigger TRG_AUTO_ASSIGN_TECHNICIAN created successfully.

-- ============================================================================
-- 2.2 FEEDBACK STATUS UPDATE TRIGGER
-- ============================================================================

PROMPT Creating trigger TRG_UPDATE_STATUS_ON_FEEDBACK...

CREATE OR REPLACE TRIGGER TRG_UPDATE_STATUS_ON_FEEDBACK
    AFTER INSERT ON FEEDBACK
    FOR EACH ROW
DECLARE
    v_technician_id NUMBER;
    v_remaining_active NUMBER;
BEGIN
    -- Update SERVICE_REQUESTS status to 'Closed'
    -- This is safe because we're inserting into FEEDBACK, not SERVICE_REQUESTS
    UPDATE SERVICE_REQUESTS
    SET status = 'Closed',
        resolved_at = NVL(resolved_at, CURRENT_TIMESTAMP)
    WHERE request_id = :NEW.request_id;

    -- Get the assigned technician for this request
    BEGIN
        SELECT technician_id
        INTO v_technician_id
        FROM ASSIGNMENTS
        WHERE request_id = :NEW.request_id;

        -- Check if technician has other active assignments
        IF v_technician_id IS NOT NULL THEN
            SELECT COUNT(*)
            INTO v_remaining_active
            FROM ASSIGNMENTS a
            JOIN SERVICE_REQUESTS sr ON a.request_id = sr.request_id
            WHERE a.technician_id = v_technician_id
              AND sr.request_id != :NEW.request_id
              AND sr.status NOT IN ('Closed', 'Resolved');

            -- If no other active assignments, set technician to 'Available'
            IF v_remaining_active = 0 THEN
                UPDATE TECHNICIANS
                SET availability = 'Available'
                WHERE technician_id = v_technician_id;

                DBMS_OUTPUT.PUT_LINE('Technician ' || v_technician_id || ' set to Available (no active assignments)');
            END IF;
        END IF;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            NULL; -- No technician assigned, that's OK
    END;

    DBMS_OUTPUT.PUT_LINE('Request ' || :NEW.request_id || ' status updated to Closed after feedback submission');

EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Error in feedback status update: ' || SQLERRM);
        -- Don't raise - allow feedback to be inserted
END TRG_UPDATE_STATUS_ON_FEEDBACK;
/

PROMPT Trigger TRG_UPDATE_STATUS_ON_FEEDBACK created successfully.

-- ============================================================================
-- 2.3 VERIFICATION
-- ============================================================================

PROMPT Verifying trigger creation...

SELECT trigger_name, status, trigger_type, triggering_event
FROM user_triggers
WHERE trigger_name IN ('TRG_AUTO_ASSIGN_TECHNICIAN', 'TRG_UPDATE_STATUS_ON_FEEDBACK')
ORDER BY trigger_name;

PROMPT Phase 2 Complete: All triggers created successfully!
PROMPT Ready for Phase 3: Procedure Implementation.
