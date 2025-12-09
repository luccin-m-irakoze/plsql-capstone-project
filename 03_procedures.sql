-- ============================================================================
-- CRM Database System - PL/SQL Procedures
-- Phase 3: Escalation and Reporting Procedures
-- Target PDB: lu_plsqlauca_25815
-- Oracle SQL Developer 24.3
-- ============================================================================

SET SERVEROUTPUT ON;
PROMPT Starting Phase 3: Procedure Implementation...

-- ============================================================================
-- 3.1 ESCALATION PROCEDURE
-- ============================================================================

PROMPT Creating procedure PROC_ESCALATE_OVERDUE_TICKETS...

CREATE OR REPLACE PROCEDURE PROC_ESCALATE_OVERDUE_TICKETS
(
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

            -- Optionally add escalation indicator in status
            -- For now, we'll leave status as is but priority is escalated
            
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
/

PROMPT Procedure PROC_ESCALATE_OVERDUE_TICKETS created successfully.

-- ============================================================================
-- 3.2 WEEKLY REPORT PROCEDURE
-- ============================================================================

PROMPT Creating procedure PROC_GENERATE_WEEKLY_REPORT...

CREATE OR REPLACE PROCEDURE PROC_GENERATE_WEEKLY_REPORT
(
    p_start_date DATE DEFAULT NULL,
    p_end_date DATE DEFAULT NULL
)
AS
    v_start DATE;
    v_end DATE;
    v_total_requests NUMBER;
    v_open_count NUMBER;
    v_assigned_count NUMBER;
    v_in_progress_count NUMBER;
    v_resolved_count NUMBER;
    v_closed_count NUMBER;
    v_low_count NUMBER;
    v_medium_count NUMBER;
    v_high_count NUMBER;
    v_critical_count NUMBER;
    v_avg_resolution_time NUMBER;
    v_total_feedback NUMBER;
    v_avg_rating NUMBER;
BEGIN
    -- Set default date range (last 7 days) if not provided
    IF p_end_date IS NULL THEN
        v_end := TRUNC(SYSDATE);
    ELSE
        v_end := TRUNC(p_end_date);
    END IF;

    IF p_start_date IS NULL THEN
        v_start := v_end - 7;
    ELSE
        v_start := TRUNC(p_start_date);
    END IF;

    DBMS_OUTPUT.PUT_LINE('==================================================================');
    DBMS_OUTPUT.PUT_LINE('CRM WEEKLY REPORT');
    DBMS_OUTPUT.PUT_LINE('==================================================================');
    DBMS_OUTPUT.PUT_LINE('Report Period: ' || TO_CHAR(v_start, 'DD-MON-YYYY') || ' to ' || TO_CHAR(v_end, 'DD-MON-YYYY'));
    DBMS_OUTPUT.PUT_LINE('Generated: ' || TO_CHAR(SYSDATE, 'DD-MON-YYYY HH24:MI:SS'));
    DBMS_OUTPUT.PUT_LINE('==================================================================');
    DBMS_OUTPUT.PUT_LINE('');

    -- Total requests in period
    SELECT COUNT(*)
    INTO v_total_requests
    FROM SERVICE_REQUESTS
    WHERE TRUNC(created_at) BETWEEN v_start AND v_end;

    DBMS_OUTPUT.PUT_LINE('TOTAL REQUESTS: ' || v_total_requests);
    DBMS_OUTPUT.PUT_LINE('');

    -- Requests by Status
    SELECT COUNT(*) INTO v_open_count FROM SERVICE_REQUESTS WHERE status = 'Open' AND TRUNC(created_at) BETWEEN v_start AND v_end;
    SELECT COUNT(*) INTO v_assigned_count FROM SERVICE_REQUESTS WHERE status = 'Assigned' AND TRUNC(created_at) BETWEEN v_start AND v_end;
    SELECT COUNT(*) INTO v_in_progress_count FROM SERVICE_REQUESTS WHERE status = 'In Progress' AND TRUNC(created_at) BETWEEN v_start AND v_end;
    SELECT COUNT(*) INTO v_resolved_count FROM SERVICE_REQUESTS WHERE status = 'Resolved' AND TRUNC(created_at) BETWEEN v_start AND v_end;
    SELECT COUNT(*) INTO v_closed_count FROM SERVICE_REQUESTS WHERE status = 'Closed' AND TRUNC(created_at) BETWEEN v_start AND v_end;

    DBMS_OUTPUT.PUT_LINE('REQUESTS BY STATUS:');
    DBMS_OUTPUT.PUT_LINE('  Open:        ' || v_open_count);
    DBMS_OUTPUT.PUT_LINE('  Assigned:    ' || v_assigned_count);
    DBMS_OUTPUT.PUT_LINE('  In Progress: ' || v_in_progress_count);
    DBMS_OUTPUT.PUT_LINE('  Resolved:    ' || v_resolved_count);
    DBMS_OUTPUT.PUT_LINE('  Closed:      ' || v_closed_count);
    DBMS_OUTPUT.PUT_LINE('');

    -- Requests by Priority
    SELECT COUNT(*) INTO v_low_count FROM SERVICE_REQUESTS WHERE priority = 'Low' AND TRUNC(created_at) BETWEEN v_start AND v_end;
    SELECT COUNT(*) INTO v_medium_count FROM SERVICE_REQUESTS WHERE priority = 'Medium' AND TRUNC(created_at) BETWEEN v_start AND v_end;
    SELECT COUNT(*) INTO v_high_count FROM SERVICE_REQUESTS WHERE priority = 'High' AND TRUNC(created_at) BETWEEN v_start AND v_end;
    SELECT COUNT(*) INTO v_critical_count FROM SERVICE_REQUESTS WHERE priority = 'Critical' AND TRUNC(created_at) BETWEEN v_start AND v_end;

    DBMS_OUTPUT.PUT_LINE('REQUESTS BY PRIORITY:');
    DBMS_OUTPUT.PUT_LINE('  Low:      ' || v_low_count);
    DBMS_OUTPUT.PUT_LINE('  Medium:   ' || v_medium_count);
    DBMS_OUTPUT.PUT_LINE('  High:     ' || v_high_count);
    DBMS_OUTPUT.PUT_LINE('  Critical: ' || v_critical_count);
    DBMS_OUTPUT.PUT_LINE('');

    -- Average Resolution Time (for closed/resolved requests)
    SELECT AVG(EXTRACT(DAY FROM (resolved_at - created_at)) * 24 +
               EXTRACT(HOUR FROM (resolved_at - created_at)) +
               EXTRACT(MINUTE FROM (resolved_at - created_at)) / 60)
    INTO v_avg_resolution_time
    FROM SERVICE_REQUESTS
    WHERE status IN ('Closed', 'Resolved')
      AND resolved_at IS NOT NULL
      AND TRUNC(created_at) BETWEEN v_start AND v_end;

    DBMS_OUTPUT.PUT_LINE('AVERAGE RESOLUTION TIME:');
    IF v_avg_resolution_time IS NOT NULL THEN
        DBMS_OUTPUT.PUT_LINE('  ' || ROUND(v_avg_resolution_time, 2) || ' hours');
    ELSE
        DBMS_OUTPUT.PUT_LINE('  No resolved requests in this period');
    END IF;
    DBMS_OUTPUT.PUT_LINE('');

    -- Technician Workload Summary
    DBMS_OUTPUT.PUT_LINE('TECHNICIAN WORKLOAD SUMMARY:');
    FOR rec IN (
        SELECT t.technician_id, t.name, t.availability,
               COUNT(a.assignment_id) AS active_assignments
        FROM TECHNICIANS t
        LEFT JOIN ASSIGNMENTS a ON t.technician_id = a.technician_id
        LEFT JOIN SERVICE_REQUESTS sr ON a.request_id = sr.request_id
          AND sr.status NOT IN ('Closed', 'Resolved')
        GROUP BY t.technician_id, t.name, t.availability
        ORDER BY active_assignments DESC
    ) LOOP
        DBMS_OUTPUT.PUT_LINE('  ' || rec.name || ' (ID: ' || rec.technician_id || '): ' || 
                            rec.active_assignments || ' active assignments [' || rec.availability || ']');
    END LOOP;
    DBMS_OUTPUT.PUT_LINE('');

    -- Customer Satisfaction Metrics
    SELECT COUNT(*), AVG(rating)
    INTO v_total_feedback, v_avg_rating
    FROM FEEDBACK f
    JOIN SERVICE_REQUESTS sr ON f.request_id = sr.request_id
    WHERE TRUNC(f.submitted_at) BETWEEN v_start AND v_end;

    DBMS_OUTPUT.PUT_LINE('CUSTOMER SATISFACTION METRICS:');
    DBMS_OUTPUT.PUT_LINE('  Total Feedback Received: ' || NVL(v_total_feedback, 0));
    IF v_avg_rating IS NOT NULL THEN
        DBMS_OUTPUT.PUT_LINE('  Average Rating: ' || ROUND(v_avg_rating, 2) || ' / 5.0');
    ELSE
        DBMS_OUTPUT.PUT_LINE('  Average Rating: No feedback available');
    END IF;
    DBMS_OUTPUT.PUT_LINE('');

    DBMS_OUTPUT.PUT_LINE('==================================================================');
    DBMS_OUTPUT.PUT_LINE('End of Report');
    DBMS_OUTPUT.PUT_LINE('==================================================================');

EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Error generating weekly report: ' || SQLERRM);
        RAISE;
END PROC_GENERATE_WEEKLY_REPORT;
/

PROMPT Procedure PROC_GENERATE_WEEKLY_REPORT created successfully.

-- ============================================================================
-- 3.3 VERIFICATION
-- ============================================================================

PROMPT Verifying procedure creation...

SELECT object_name, object_type, status
FROM user_objects
WHERE object_name IN ('PROC_ESCALATE_OVERDUE_TICKETS', 'PROC_GENERATE_WEEKLY_REPORT')
  AND object_type = 'PROCEDURE'
ORDER BY object_name;

PROMPT Phase 3 Complete: All procedures created successfully!
PROMPT Ready for Phase 4: Package Implementation.

