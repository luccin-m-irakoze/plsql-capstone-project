-- ============================================================================
-- CRM Database System - Reporting Package
-- Phase 4.3: PKG_REPORTING Package
-- Target PDB: lu_plsqlauca_25815
-- Oracle SQL Developer 24.3
-- ============================================================================

SET SERVEROUTPUT ON;
PROMPT Creating package PKG_REPORTING...

-- ============================================================================
-- PACKAGE SPECIFICATION
-- ============================================================================

CREATE OR REPLACE PACKAGE PKG_REPORTING
AS
    -- Function: Calculate average resolution time per technician
    FUNCTION FUNC_AVG_RESOLUTION_TIME(
        p_technician_id IN NUMBER,
        p_start_date IN DATE DEFAULT NULL,
        p_end_date IN DATE DEFAULT NULL
    ) RETURN NUMBER;

    -- Function: Compute customer satisfaction score
    FUNCTION FUNC_CUSTOMER_SATISFACTION_SCORE(
        p_customer_id IN NUMBER
    ) RETURN NUMBER;

    -- Procedure: Generate weekly report (from standalone procedure)
    PROCEDURE PROC_GENERATE_WEEKLY_REPORT(
        p_start_date IN DATE DEFAULT NULL,
        p_end_date IN DATE DEFAULT NULL
    );

    -- Procedure: Generate technician performance report
    PROCEDURE PROC_TECHNICIAN_PERFORMANCE_REPORT(
        p_technician_id IN NUMBER
    );

    -- Procedure: Generate customer analytics
    PROCEDURE PROC_CUSTOMER_ANALYTICS(
        p_customer_id IN NUMBER
    );

END PKG_REPORTING;
/

-- ============================================================================
-- PACKAGE BODY
-- ============================================================================

CREATE OR REPLACE PACKAGE BODY PKG_REPORTING
AS

    -- Function: Calculate average resolution time per technician
    FUNCTION FUNC_AVG_RESOLUTION_TIME(
        p_technician_id IN NUMBER,
        p_start_date IN DATE DEFAULT NULL,
        p_end_date IN DATE DEFAULT NULL
    ) RETURN NUMBER
    IS
        v_avg_hours NUMBER;
        v_start DATE;
        v_end DATE;
    BEGIN
        -- Set default date range if not provided
        IF p_end_date IS NULL THEN
            v_end := TRUNC(SYSDATE);
        ELSE
            v_end := TRUNC(p_end_date);
        END IF;

        IF p_start_date IS NULL THEN
            v_start := v_end - 30; -- Default: last 30 days
        ELSE
            v_start := TRUNC(p_start_date);
        END IF;

        -- Calculate average resolution time in hours
        SELECT AVG(EXTRACT(DAY FROM (sr.resolved_at - sr.created_at)) * 24 +
                   EXTRACT(HOUR FROM (sr.resolved_at - sr.created_at)) +
                   EXTRACT(MINUTE FROM (sr.resolved_at - sr.created_at)) / 60)
        INTO v_avg_hours
        FROM SERVICE_REQUESTS sr
        JOIN ASSIGNMENTS a ON sr.request_id = a.request_id
        WHERE a.technician_id = p_technician_id
          AND sr.status IN ('Closed', 'Resolved')
          AND sr.resolved_at IS NOT NULL
          AND TRUNC(sr.created_at) BETWEEN v_start AND v_end;

        RETURN ROUND(NVL(v_avg_hours, 0), 2);

    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('Error calculating average resolution time: ' || SQLERRM);
            RETURN NULL;
    END FUNC_AVG_RESOLUTION_TIME;

    -- Function: Compute customer satisfaction score
    FUNCTION FUNC_CUSTOMER_SATISFACTION_SCORE(
        p_customer_id IN NUMBER
    ) RETURN NUMBER
    IS
        v_avg_rating NUMBER;
    BEGIN
        -- If customer_id is NULL, return overall average
        IF p_customer_id IS NULL THEN
            SELECT AVG(rating)
            INTO v_avg_rating
            FROM FEEDBACK;
        ELSE
            -- Calculate average rating for specific customer
            SELECT AVG(f.rating)
            INTO v_avg_rating
            FROM FEEDBACK f
            JOIN SERVICE_REQUESTS sr ON f.request_id = sr.request_id
            WHERE sr.customer_id = p_customer_id;
        END IF;

        RETURN ROUND(NVL(v_avg_rating, 0), 2);

    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('Error computing satisfaction score: ' || SQLERRM);
            RETURN NULL;
    END FUNC_CUSTOMER_SATISFACTION_SCORE;

    -- Procedure: Generate weekly report
    PROCEDURE PROC_GENERATE_WEEKLY_REPORT(
        p_start_date IN DATE DEFAULT NULL,
        p_end_date IN DATE DEFAULT NULL
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

        -- Average Resolution Time
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

    -- Procedure: Generate technician performance report
    PROCEDURE PROC_TECHNICIAN_PERFORMANCE_REPORT(
        p_technician_id IN NUMBER
    )
    AS
        v_tech_name VARCHAR2(100);
        v_skill_level VARCHAR2(20);
        v_availability VARCHAR2(10);
        v_total_assigned NUMBER;
        v_total_resolved NUMBER;
        v_avg_resolution_time NUMBER;
        v_avg_rating NUMBER;
    BEGIN
        -- Get technician info
        SELECT name, skill_level, availability
        INTO v_tech_name, v_skill_level, v_availability
        FROM TECHNICIANS
        WHERE technician_id = p_technician_id;

        -- Get statistics
        SELECT COUNT(*)
        INTO v_total_assigned
        FROM ASSIGNMENTS
        WHERE technician_id = p_technician_id;

        SELECT COUNT(*)
        INTO v_total_resolved
        FROM ASSIGNMENTS a
        JOIN SERVICE_REQUESTS sr ON a.request_id = sr.request_id
        WHERE a.technician_id = p_technician_id
          AND sr.status IN ('Closed', 'Resolved');

        v_avg_resolution_time := FUNC_AVG_RESOLUTION_TIME(p_technician_id, NULL, NULL);

        -- Get average rating from feedback
        SELECT AVG(f.rating)
        INTO v_avg_rating
        FROM FEEDBACK f
        JOIN ASSIGNMENTS a ON f.request_id = a.request_id
        WHERE a.technician_id = p_technician_id;

        -- Display report
        DBMS_OUTPUT.PUT_LINE('==================================================================');
        DBMS_OUTPUT.PUT_LINE('TECHNICIAN PERFORMANCE REPORT');
        DBMS_OUTPUT.PUT_LINE('==================================================================');
        DBMS_OUTPUT.PUT_LINE('Technician ID: ' || p_technician_id);
        DBMS_OUTPUT.PUT_LINE('Name: ' || v_tech_name);
        DBMS_OUTPUT.PUT_LINE('Skill Level: ' || v_skill_level);
        DBMS_OUTPUT.PUT_LINE('Availability: ' || v_availability);
        DBMS_OUTPUT.PUT_LINE('Generated: ' || TO_CHAR(SYSDATE, 'DD-MON-YYYY HH24:MI:SS'));
        DBMS_OUTPUT.PUT_LINE('==================================================================');
        DBMS_OUTPUT.PUT_LINE('');
        DBMS_OUTPUT.PUT_LINE('STATISTICS:');
        DBMS_OUTPUT.PUT_LINE('  Total Assignments: ' || v_total_assigned);
        DBMS_OUTPUT.PUT_LINE('  Total Resolved: ' || v_total_resolved);
        IF v_total_assigned > 0 THEN
            DBMS_OUTPUT.PUT_LINE('  Resolution Rate: ' || ROUND((v_total_resolved / v_total_assigned) * 100, 2) || '%');
        END IF;
        DBMS_OUTPUT.PUT_LINE('  Average Resolution Time: ' || NVL(TO_CHAR(v_avg_resolution_time), 'N/A') || ' hours');
        DBMS_OUTPUT.PUT_LINE('  Average Customer Rating: ' || NVL(TO_CHAR(ROUND(v_avg_rating, 2)), 'N/A') || ' / 5.0');
        DBMS_OUTPUT.PUT_LINE('');
        DBMS_OUTPUT.PUT_LINE('==================================================================');
        DBMS_OUTPUT.PUT_LINE('End of Report');
        DBMS_OUTPUT.PUT_LINE('==================================================================');

    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            DBMS_OUTPUT.PUT_LINE('Technician ID ' || p_technician_id || ' not found.');
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('Error generating technician report: ' || SQLERRM);
            RAISE;
    END PROC_TECHNICIAN_PERFORMANCE_REPORT;

    -- Procedure: Generate customer analytics
    PROCEDURE PROC_CUSTOMER_ANALYTICS(
        p_customer_id IN NUMBER
    )
    AS
        v_customer_name VARCHAR2(100);
        v_company VARCHAR2(100);
        v_tier VARCHAR2(20);
        v_total_requests NUMBER;
        v_open_requests NUMBER;
        v_closed_requests NUMBER;
        v_avg_rating NUMBER;
        v_total_feedback NUMBER;
    BEGIN
        -- Get customer info
        SELECT name, company, tier
        INTO v_customer_name, v_company, v_tier
        FROM CUSTOMERS
        WHERE customer_id = p_customer_id;

        -- Get statistics
        SELECT COUNT(*)
        INTO v_total_requests
        FROM SERVICE_REQUESTS
        WHERE customer_id = p_customer_id;

        SELECT COUNT(*)
        INTO v_open_requests
        FROM SERVICE_REQUESTS
        WHERE customer_id = p_customer_id
          AND status NOT IN ('Closed', 'Resolved');

        SELECT COUNT(*)
        INTO v_closed_requests
        FROM SERVICE_REQUESTS
        WHERE customer_id = p_customer_id
          AND status IN ('Closed', 'Resolved');

        v_avg_rating := FUNC_CUSTOMER_SATISFACTION_SCORE(p_customer_id);

        SELECT COUNT(*)
        INTO v_total_feedback
        FROM FEEDBACK f
        JOIN SERVICE_REQUESTS sr ON f.request_id = sr.request_id
        WHERE sr.customer_id = p_customer_id;

        -- Display report
        DBMS_OUTPUT.PUT_LINE('==================================================================');
        DBMS_OUTPUT.PUT_LINE('CUSTOMER ANALYTICS REPORT');
        DBMS_OUTPUT.PUT_LINE('==================================================================');
        DBMS_OUTPUT.PUT_LINE('Customer ID: ' || p_customer_id);
        DBMS_OUTPUT.PUT_LINE('Name: ' || v_customer_name);
        DBMS_OUTPUT.PUT_LINE('Company: ' || NVL(v_company, 'N/A'));
        DBMS_OUTPUT.PUT_LINE('Tier: ' || v_tier);
        DBMS_OUTPUT.PUT_LINE('Generated: ' || TO_CHAR(SYSDATE, 'DD-MON-YYYY HH24:MI:SS'));
        DBMS_OUTPUT.PUT_LINE('==================================================================');
        DBMS_OUTPUT.PUT_LINE('');
        DBMS_OUTPUT.PUT_LINE('REQUEST STATISTICS:');
        DBMS_OUTPUT.PUT_LINE('  Total Requests: ' || v_total_requests);
        DBMS_OUTPUT.PUT_LINE('  Open Requests: ' || v_open_requests);
        DBMS_OUTPUT.PUT_LINE('  Closed Requests: ' || v_closed_requests);
        DBMS_OUTPUT.PUT_LINE('');
        DBMS_OUTPUT.PUT_LINE('SATISFACTION METRICS:');
        DBMS_OUTPUT.PUT_LINE('  Total Feedback: ' || v_total_feedback);
        DBMS_OUTPUT.PUT_LINE('  Average Rating: ' || NVL(TO_CHAR(ROUND(v_avg_rating, 2)), 'N/A') || ' / 5.0');
        DBMS_OUTPUT.PUT_LINE('');
        DBMS_OUTPUT.PUT_LINE('==================================================================');
        DBMS_OUTPUT.PUT_LINE('End of Report');
        DBMS_OUTPUT.PUT_LINE('==================================================================');

    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            DBMS_OUTPUT.PUT_LINE('Customer ID ' || p_customer_id || ' not found.');
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('Error generating customer analytics: ' || SQLERRM);
            RAISE;
    END PROC_CUSTOMER_ANALYTICS;

END PKG_REPORTING;
/

PROMPT Package PKG_REPORTING created successfully.

-- Verification
SELECT object_name, object_type, status
FROM user_objects
WHERE object_name = 'PKG_REPORTING'
ORDER BY object_type;

