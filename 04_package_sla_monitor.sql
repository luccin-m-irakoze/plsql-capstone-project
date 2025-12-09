-- ============================================================================
-- CRM Database System - SLA Monitoring Package
-- Phase 4.2: PKG_SLA_MONITORING Package
-- Target PDB: lu_plsqlauca_25815
-- Oracle SQL Developer 24.3
-- ============================================================================

SET SERVEROUTPUT ON;
PROMPT Creating package PKG_SLA_MONITORING...

-- ============================================================================
-- PACKAGE SPECIFICATION
-- ============================================================================

CREATE OR REPLACE PACKAGE PKG_SLA_MONITORING
AS
    -- Function: Check SLA compliance status for a request
    -- Returns: 'compliant', 'at_risk', or 'violated'
    FUNCTION FUNC_CHECK_SLA_COMPLIANCE(
        p_request_id IN NUMBER
    ) RETURN VARCHAR2;

    -- Function: Get remaining time until SLA deadline
    -- Returns: Hours remaining (negative if violated)
    FUNCTION FUNC_GET_REMAINING_TIME(
        p_request_id IN NUMBER
    ) RETURN NUMBER;

    -- Procedure: Escalate overdue tickets (from standalone procedure)
    PROCEDURE PROC_ESCALATE_OVERDUE_TICKETS(
        p_escalated_count OUT NUMBER
    );

    -- Procedure: Monitor active requests and output those at risk
    PROCEDURE PROC_MONITOR_ACTIVE_REQUESTS;

END PKG_SLA_MONITORING;
/

-- ============================================================================
-- PACKAGE BODY
-- ============================================================================

CREATE OR REPLACE PACKAGE BODY PKG_SLA_MONITORING
AS

    -- Function: Check SLA compliance status for a request
    FUNCTION FUNC_CHECK_SLA_COMPLIANCE(
        p_request_id IN NUMBER
    ) RETURN VARCHAR2
    IS
        v_hours_elapsed NUMBER;
        v_resolution_time NUMBER;
        v_hours_remaining NUMBER;
        v_percent_used NUMBER;
    BEGIN
        -- Calculate hours elapsed and resolution time
        SELECT EXTRACT(DAY FROM (CURRENT_TIMESTAMP - sr.created_at)) * 24 +
               EXTRACT(HOUR FROM (CURRENT_TIMESTAMP - sr.created_at)) +
               EXTRACT(MINUTE FROM (CURRENT_TIMESTAMP - sr.created_at)) / 60,
               sla.resolution_time_hours
        INTO v_hours_elapsed, v_resolution_time
        FROM SERVICE_REQUESTS sr
        JOIN SLA_RULES sla ON sr.priority = sla.priority_level
        WHERE sr.request_id = p_request_id
          AND sr.status NOT IN ('Closed', 'Resolved');

        v_hours_remaining := v_resolution_time - v_hours_elapsed;
        v_percent_used := (v_hours_elapsed / v_resolution_time) * 100;

        -- Determine compliance status
        IF v_hours_remaining < 0 THEN
            RETURN 'violated';
        ELSIF v_percent_used >= 80 THEN
            RETURN 'at_risk';
        ELSE
            RETURN 'compliant';
        END IF;

    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RETURN 'N/A'; -- Request not found or already closed
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('Error checking SLA compliance: ' || SQLERRM);
            RETURN 'ERROR';
    END FUNC_CHECK_SLA_COMPLIANCE;

    -- Function: Get remaining time until SLA deadline
    FUNCTION FUNC_GET_REMAINING_TIME(
        p_request_id IN NUMBER
    ) RETURN NUMBER
    IS
        v_hours_elapsed NUMBER;
        v_resolution_time NUMBER;
        v_hours_remaining NUMBER;
    BEGIN
        -- Calculate remaining time
        SELECT EXTRACT(DAY FROM (CURRENT_TIMESTAMP - sr.created_at)) * 24 +
               EXTRACT(HOUR FROM (CURRENT_TIMESTAMP - sr.created_at)) +
               EXTRACT(MINUTE FROM (CURRENT_TIMESTAMP - sr.created_at)) / 60,
               sla.resolution_time_hours
        INTO v_hours_elapsed, v_resolution_time
        FROM SERVICE_REQUESTS sr
        JOIN SLA_RULES sla ON sr.priority = sla.priority_level
        WHERE sr.request_id = p_request_id
          AND sr.status NOT IN ('Closed', 'Resolved');

        v_hours_remaining := v_resolution_time - v_hours_elapsed;
        RETURN ROUND(v_hours_remaining, 2);

    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RETURN NULL; -- Request not found or already closed
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('Error getting remaining time: ' || SQLERRM);
            RETURN NULL;
    END FUNC_GET_REMAINING_TIME;

    -- Procedure: Escalate overdue tickets
    PROCEDURE PROC_ESCALATE_OVERDUE_TICKETS(
        p_escalated_count OUT NUMBER
    )
    AS
        v_request_id NUMBER;
        v_current_priority VARCHAR2(20);
        v_new_priority VARCHAR2(20);
        v_resolution_time NUMBER;
        v_hours_elapsed NUMBER;
        v_escalated NUMBER := 0;
        
        CURSOR c_overdue_requests IS
            SELECT sr.request_id, sr.priority, sla.resolution_time_hours,
                   EXTRACT(DAY FROM (CURRENT_TIMESTAMP - sr.created_at)) * 24 +
                   EXTRACT(HOUR FROM (CURRENT_TIMESTAMP - sr.created_at)) +
                   EXTRACT(MINUTE FROM (CURRENT_TIMESTAMP - sr.created_at)) / 60 AS hours_elapsed
            FROM SERVICE_REQUESTS sr
            JOIN SLA_RULES sla ON sr.priority = sla.priority_level
            WHERE sr.status NOT IN ('Closed', 'Resolved')
              AND EXTRACT(DAY FROM (CURRENT_TIMESTAMP - sr.created_at)) * 24 +
                  EXTRACT(HOUR FROM (CURRENT_TIMESTAMP - sr.created_at)) +
                  EXTRACT(MINUTE FROM (CURRENT_TIMESTAMP - sr.created_at)) / 60 > sla.resolution_time_hours;

    BEGIN
        p_escalated_count := 0;

        FOR rec IN c_overdue_requests LOOP
            v_request_id := rec.request_id;
            v_current_priority := rec.priority;
            v_hours_elapsed := rec.hours_elapsed;
            
            -- Determine new priority (escalate one level)
            CASE v_current_priority
                WHEN 'Low' THEN v_new_priority := 'Medium';
                WHEN 'Medium' THEN v_new_priority := 'High';
                WHEN 'High' THEN v_new_priority := 'Critical';
                WHEN 'Critical' THEN v_new_priority := 'Critical'; -- Already at highest
                ELSE v_new_priority := v_current_priority;
            END CASE;

            -- Only escalate if priority can be upgraded
            IF v_new_priority != v_current_priority THEN
                -- Update priority
                UPDATE SERVICE_REQUESTS
                SET priority = v_new_priority
                WHERE request_id = v_request_id;
                
                v_escalated := v_escalated + 1;
                
                DBMS_OUTPUT.PUT_LINE('Escalated Request ' || v_request_id || 
                                    ' from ' || v_current_priority || 
                                    ' to ' || v_new_priority || 
                                    ' (Hours elapsed: ' || ROUND(v_hours_elapsed, 2) || ')');
            END IF;
        END LOOP;

        p_escalated_count := v_escalated;
        
        IF v_escalated = 0 THEN
            DBMS_OUTPUT.PUT_LINE('No overdue tickets found requiring escalation.');
        ELSE
            DBMS_OUTPUT.PUT_LINE('Total tickets escalated: ' || v_escalated);
        END IF;

        COMMIT;

    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            DBMS_OUTPUT.PUT_LINE('Error in escalation procedure: ' || SQLERRM);
            RAISE;
    END PROC_ESCALATE_OVERDUE_TICKETS;

    -- Procedure: Monitor active requests and output those at risk
    PROCEDURE PROC_MONITOR_ACTIVE_REQUESTS
    AS
        v_at_risk_count NUMBER := 0;
        v_violated_count NUMBER := 0;
    BEGIN
        DBMS_OUTPUT.PUT_LINE('==================================================================');
        DBMS_OUTPUT.PUT_LINE('SLA MONITORING REPORT - Active Requests');
        DBMS_OUTPUT.PUT_LINE('==================================================================');
        DBMS_OUTPUT.PUT_LINE('Generated: ' || TO_CHAR(SYSDATE, 'DD-MON-YYYY HH24:MI:SS'));
        DBMS_OUTPUT.PUT_LINE('');

        -- Requests at risk (80% or more of SLA time used)
        DBMS_OUTPUT.PUT_LINE('REQUESTS AT RISK (>=80% of SLA time used):');
        DBMS_OUTPUT.PUT_LINE('');

        FOR rec IN (
            SELECT sr.request_id, sr.priority, sr.status, c.name AS customer_name,
                   sla.resolution_time_hours,
                   EXTRACT(DAY FROM (CURRENT_TIMESTAMP - sr.created_at)) * 24 +
                   EXTRACT(HOUR FROM (CURRENT_TIMESTAMP - sr.created_at)) +
                   EXTRACT(MINUTE FROM (CURRENT_TIMESTAMP - sr.created_at)) / 60 AS hours_elapsed,
                   ROUND((EXTRACT(DAY FROM (CURRENT_TIMESTAMP - sr.created_at)) * 24 +
                          EXTRACT(HOUR FROM (CURRENT_TIMESTAMP - sr.created_at)) +
                          EXTRACT(MINUTE FROM (CURRENT_TIMESTAMP - sr.created_at)) / 60) / 
                         sla.resolution_time_hours * 100, 2) AS percent_used,
                   ROUND(sla.resolution_time_hours - 
                         (EXTRACT(DAY FROM (CURRENT_TIMESTAMP - sr.created_at)) * 24 +
                          EXTRACT(HOUR FROM (CURRENT_TIMESTAMP - sr.created_at)) +
                          EXTRACT(MINUTE FROM (CURRENT_TIMESTAMP - sr.created_at)) / 60), 2) AS hours_remaining
            FROM SERVICE_REQUESTS sr
            JOIN SLA_RULES sla ON sr.priority = sla.priority_level
            JOIN CUSTOMERS c ON sr.customer_id = c.customer_id
            WHERE sr.status NOT IN ('Closed', 'Resolved')
              AND (EXTRACT(DAY FROM (CURRENT_TIMESTAMP - sr.created_at)) * 24 +
                   EXTRACT(HOUR FROM (CURRENT_TIMESTAMP - sr.created_at)) +
                   EXTRACT(MINUTE FROM (CURRENT_TIMESTAMP - sr.created_at)) / 60) / 
                  sla.resolution_time_hours >= 0.8
            ORDER BY percent_used DESC, sr.priority DESC
        ) LOOP
            IF rec.hours_remaining < 0 THEN
                v_violated_count := v_violated_count + 1;
                DBMS_OUTPUT.PUT_LINE('  [VIOLATED] Request #' || rec.request_id || 
                                    ' | Priority: ' || rec.priority || 
                                    ' | Customer: ' || rec.customer_name ||
                                    ' | ' || ROUND(ABS(rec.hours_remaining), 2) || ' hours OVER SLA');
            ELSE
                v_at_risk_count := v_at_risk_count + 1;
                DBMS_OUTPUT.PUT_LINE('  [AT RISK] Request #' || rec.request_id || 
                                    ' | Priority: ' || rec.priority || 
                                    ' | Customer: ' || rec.customer_name ||
                                    ' | ' || rec.percent_used || '% used | ' || 
                                    ROUND(rec.hours_remaining, 2) || ' hours remaining');
            END IF;
        END LOOP;

        IF v_at_risk_count = 0 AND v_violated_count = 0 THEN
            DBMS_OUTPUT.PUT_LINE('  No requests at risk or violated.');
        END IF;

        DBMS_OUTPUT.PUT_LINE('');
        DBMS_OUTPUT.PUT_LINE('SUMMARY:');
        DBMS_OUTPUT.PUT_LINE('  At Risk: ' || v_at_risk_count);
        DBMS_OUTPUT.PUT_LINE('  Violated: ' || v_violated_count);
        DBMS_OUTPUT.PUT_LINE('');

        DBMS_OUTPUT.PUT_LINE('==================================================================');
        DBMS_OUTPUT.PUT_LINE('End of SLA Monitoring Report');
        DBMS_OUTPUT.PUT_LINE('==================================================================');

    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('Error in monitoring procedure: ' || SQLERRM);
            RAISE;
    END PROC_MONITOR_ACTIVE_REQUESTS;

END PKG_SLA_MONITORING;
/

PROMPT Package PKG_SLA_MONITORING created successfully.

-- Verification
SELECT object_name, object_type, status
FROM user_objects
WHERE object_name = 'PKG_SLA_MONITORING'
ORDER BY object_type;

