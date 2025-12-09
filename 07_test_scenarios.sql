-- ============================================================================
-- CRM Database System - Test Scenarios
-- Phase 7.2-7.4: SLA Violation Simulation, Feedback Integration, E2E Tests
-- Target PDB: lu_plsqlauca_25815
-- Oracle SQL Developer 24.3
-- ============================================================================

SET DEFINE OFF;
SET SERVEROUTPUT ON;
PROMPT Starting Phase 7.2-7.4: Test Scenarios Execution...

-- ============================================================================
-- 7.2 SLA VIOLATION SIMULATION
-- ============================================================================

PROMPT ====================================================================
PROMPT Test 7.2: SLA Violation Simulation
PROMPT ====================================================================

PROMPT Creating test requests with past timestamps to simulate SLA violations...

-- Create requests that will violate SLA
-- Low priority: 72 hours SLA - create request 73 hours ago
-- Medium priority: 48 hours SLA - create request 49 hours ago
-- High priority: 24 hours SLA - create request 25 hours ago
-- Critical priority: 4 hours SLA - create request 5 hours ago

DECLARE
    v_customer_id NUMBER;
    v_product_id NUMBER;
    v_request_id NUMBER;
    v_escalated_count NUMBER;
BEGIN
    -- Get first customer and product IDs
    SELECT MIN(customer_id) INTO v_customer_id FROM CUSTOMERS;
    SELECT MIN(product_id) INTO v_product_id FROM PRODUCTS;

    -- Create overdue Low priority request (73 hours ago)
    INSERT INTO SERVICE_REQUESTS (request_id, customer_id, product_id, issue_type, priority, status, created_at)
    VALUES (seq_request_id.NEXTVAL, v_customer_id, v_product_id, 'SLA Test - Low Priority', 'Low', 'Assigned', 
            CURRENT_TIMESTAMP - (73/24));

    -- Create overdue Medium priority request (49 hours ago)
    INSERT INTO SERVICE_REQUESTS (request_id, customer_id, product_id, issue_type, priority, status, created_at)
    VALUES (seq_request_id.NEXTVAL, v_customer_id, v_product_id, 'SLA Test - Medium Priority', 'Medium', 'In Progress', 
            CURRENT_TIMESTAMP - (49/24));

    -- Create overdue High priority request (25 hours ago)
    INSERT INTO SERVICE_REQUESTS (request_id, product_id, issue_type, priority, status, created_at)
    VALUES (seq_request_id.NEXTVAL, v_customer_id, v_product_id, 'SLA Test - High Priority', 'High', 'Assigned', 
            CURRENT_TIMESTAMP - (25/24));

    -- Create overdue Critical priority request (5 hours ago)
    INSERT INTO SERVICE_REQUESTS (request_id, customer_id, product_id, issue_type, priority, status, created_at)
    VALUES (seq_request_id.NEXTVAL, v_customer_id, v_product_id, 'SLA Test - Critical Priority', 'Critical', 'In Progress', 
            CURRENT_TIMESTAMP - (5/24));

    COMMIT;

    PROMPT Overdue requests created. Running escalation procedure...

    -- Run escalation procedure
    PKG_SLA_MONITORING.PROC_ESCALATE_OVERDUE_TICKETS(v_escalated_count);

    PROMPT Escalation completed. Escalated count: ' || v_escalated_count);

    -- Verify priority upgrades
    PROMPT Verifying priority upgrades...

    FOR rec IN (
        SELECT request_id, issue_type, priority, 
               EXTRACT(DAY FROM (CURRENT_TIMESTAMP - created_at)) * 24 +
               EXTRACT(HOUR FROM (CURRENT_TIMESTAMP - created_at)) AS hours_elapsed
        FROM SERVICE_REQUESTS
        WHERE issue_type LIKE 'SLA Test%'
        ORDER BY request_id
    ) LOOP
        DBMS_OUTPUT.PUT_LINE('  Request #' || rec.request_id || ': ' || rec.issue_type || 
                            ' | Priority: ' || rec.priority || 
                            ' | Hours elapsed: ' || ROUND(rec.hours_elapsed, 2));
    END LOOP;

END;
/

-- Verify SLA calculation accuracy
PROMPT Verifying SLA calculation accuracy...

SELECT sr.request_id, sr.priority, sla.resolution_time_hours,
       ROUND(EXTRACT(DAY FROM (CURRENT_TIMESTAMP - sr.created_at)) * 24 +
             EXTRACT(HOUR FROM (CURRENT_TIMESTAMP - sr.created_at)) +
             EXTRACT(MINUTE FROM (CURRENT_TIMESTAMP - sr.created_at)) / 60, 2) AS hours_elapsed,
       CASE 
           WHEN EXTRACT(DAY FROM (CURRENT_TIMESTAMP - sr.created_at)) * 24 +
                EXTRACT(HOUR FROM (CURRENT_TIMESTAMP - sr.created_at)) +
                EXTRACT(MINUTE FROM (CURRENT_TIMESTAMP - sr.created_at)) / 60 > sla.resolution_time_hours
           THEN 'VIOLATED'
           ELSE 'COMPLIANT'
       END AS sla_status
FROM SERVICE_REQUESTS sr
JOIN SLA_RULES sla ON sr.priority = sla.priority_level
WHERE sr.status NOT IN ('Closed', 'Resolved')
ORDER BY sr.request_id;

PROMPT SLA violation simulation test complete.

-- ============================================================================
-- 7.3 FEEDBACK INTEGRATION TEST
-- ============================================================================

PROMPT ====================================================================
PROMPT Test 7.3: Feedback Integration Test
PROMPT ====================================================================

DECLARE
    v_request_id NUMBER;
    v_status_before VARCHAR2(20);
    v_status_after VARCHAR2(20);
    v_technician_id NUMBER;
    v_availability_before VARCHAR2(10);
    v_availability_after VARCHAR2(10);
    v_satisfaction_score NUMBER;
BEGIN
    -- Find a resolved request without feedback
    SELECT sr.request_id, sr.status
    INTO v_request_id, v_status_before
    FROM SERVICE_REQUESTS sr
    LEFT JOIN FEEDBACK f ON sr.request_id = f.request_id
    WHERE sr.status = 'Resolved'
      AND f.request_id IS NULL
      AND ROWNUM = 1;

    PROMPT Testing feedback submission for Request #' || v_request_id);

    -- Get technician for this request
    SELECT technician_id INTO v_technician_id
    FROM ASSIGNMENTS
    WHERE request_id = v_request_id;

    SELECT availability INTO v_availability_before
    FROM TECHNICIANS
    WHERE technician_id = v_technician_id;

    PROMPT Status before feedback: ' || v_status_before);
    PROMPT Technician availability before: ' || v_availability_before);

    -- Submit feedback (trigger will update status to Closed)
    INSERT INTO FEEDBACK (feedback_id, request_id, rating, remarks)
    VALUES (seq_feedback_id.NEXTVAL, v_request_id, 4.5, 'Test feedback - excellent service');

    COMMIT;

    -- Verify status update
    SELECT status INTO v_status_after
    FROM SERVICE_REQUESTS
    WHERE request_id = v_request_id;

    SELECT availability INTO v_availability_after
    FROM TECHNICIANS
    WHERE technician_id = v_technician_id;

    PROMPT Status after feedback: ' || v_status_after);
    PROMPT Technician availability after: ' || v_availability_after);

    IF v_status_after = 'Closed' THEN
        PROMPT SUCCESS: Status automatically updated to Closed);
    ELSE
        PROMPT WARNING: Status not updated to Closed);
    END IF;

    -- Test customer satisfaction score calculation
    v_satisfaction_score := PKG_REPORTING.FUNC_CUSTOMER_SATISFACTION_SCORE(
        (SELECT customer_id FROM SERVICE_REQUESTS WHERE request_id = v_request_id)
    );

    PROMPT Customer satisfaction score: ' || v_satisfaction_score);

    -- Verify workload redistribution
    PROMPT Verifying workload redistribution after closure...

    SELECT COUNT(*) AS remaining_active
    INTO v_technician_id  -- Reusing variable
    FROM ASSIGNMENTS a
    JOIN SERVICE_REQUESTS sr ON a.request_id = sr.request_id
    WHERE a.technician_id = (
        SELECT technician_id FROM ASSIGNMENTS WHERE request_id = v_request_id
    )
    AND sr.status NOT IN ('Closed', 'Resolved');

    PROMPT Technician remaining active assignments: ' || v_technician_id);

EXCEPTION
    WHEN NO_DATA_FOUND THEN
        PROMPT No suitable request found for feedback test - creating one...

        -- Create a resolved request for testing
        INSERT INTO SERVICE_REQUESTS (request_id, customer_id, product_id, issue_type, priority, status, created_at, resolved_at)
        SELECT seq_request_id.NEXTVAL, MIN(customer_id), MIN(product_id), 'Feedback Test Request', 'Medium', 'Resolved',
               CURRENT_TIMESTAMP - 2, CURRENT_TIMESTAMP - 1
        FROM CUSTOMERS, PRODUCTS;

        SELECT seq_request_id.CURRVAL INTO v_request_id FROM DUAL;

        -- Assign technician
        INSERT INTO ASSIGNMENTS (assignment_id, request_id, technician_id, assigned_at)
        SELECT seq_assignment_id.NEXTVAL, v_request_id, MIN(technician_id), CURRENT_TIMESTAMP - 2
        FROM TECHNICIANS;

        COMMIT;

        PROMPT Created test request #' || v_request_id || ' for feedback test');
END;
/

PROMPT Feedback integration test complete.

-- ============================================================================
-- 7.4 END-TO-END WORKFLOW TEST
-- ============================================================================

PROMPT ====================================================================
PROMPT Test 7.4: End-to-End Workflow Test
PROMPT ====================================================================

DECLARE
    v_customer_id NUMBER;
    v_product_id NUMBER;
    v_request_id NUMBER;
    v_technician_id NUMBER;
    v_assignment_exists NUMBER;
BEGIN
    PROMPT Step 1: Create new customer...

    INSERT INTO CUSTOMERS (customer_id, name, contact, company, tier)
    VALUES (seq_customer_id.NEXTVAL, 'Test Customer E2E', 'test.e2e@email.com', 'E2E Test Corp', 'Gold');

    SELECT seq_customer_id.CURRVAL INTO v_customer_id FROM DUAL;
    PROMPT Created Customer ID: ' || v_customer_id);

    COMMIT;

    PROMPT Step 2: Create service request (auto-assignment should trigger)...

    SELECT MIN(product_id) INTO v_product_id FROM PRODUCTS;

    v_request_id := PKG_TICKET_MANAGEMENT.FUNC_CREATE_REQUEST(
        p_customer_id => v_customer_id,
        p_product_id => v_product_id,
        p_issue_type => 'E2E Test - System Integration',
        p_priority => 'High'
    );

    PROMPT Created Request ID: ' || v_request_id);

    -- Verify auto-assignment
    SELECT COUNT(*)
    INTO v_assignment_exists
    FROM ASSIGNMENTS
    WHERE request_id = v_request_id;

    IF v_assignment_exists > 0 THEN
        SELECT technician_id INTO v_technician_id
        FROM ASSIGNMENTS
        WHERE request_id = v_request_id;

        PROMPT SUCCESS: Request automatically assigned to Technician #' || v_technician_id);
    ELSE
        PROMPT WARNING: Request not automatically assigned);
    END IF;

    -- Verify status
    SELECT status INTO v_assignment_exists  -- Reusing variable
    FROM SERVICE_REQUESTS
    WHERE request_id = v_request_id;

    PROMPT Request status: ' || v_assignment_exists);

    PROMPT Step 3: Simulate work progress (status updates)...

    IF PKG_TICKET_MANAGEMENT.FUNC_UPDATE_STATUS(v_request_id, 'In Progress') THEN
        PROMPT SUCCESS: Status updated to In Progress);
    END IF;

    IF PKG_TICKET_MANAGEMENT.FUNC_UPDATE_STATUS(v_request_id, 'Resolved') THEN
        PROMPT SUCCESS: Status updated to Resolved);
    END IF;

    PROMPT Step 4: Submit feedback (should close request automatically)...

    INSERT INTO FEEDBACK (feedback_id, request_id, rating, remarks)
    VALUES (seq_feedback_id.NEXTVAL, v_request_id, 5.0, 'E2E Test - Perfect service!');

    COMMIT;

    SELECT status INTO v_assignment_exists
    FROM SERVICE_REQUESTS
    WHERE request_id = v_request_id;

    IF v_assignment_exists = 'Closed' THEN
        PROMPT SUCCESS: Request automatically closed after feedback);
    ELSE
        PROMPT WARNING: Request status is ' || v_assignment_exists || ' (expected Closed)');
    END IF;

    PROMPT Step 5: Generate reports and analytics...

    PROMPT Generating weekly report...
    PKG_REPORTING.PROC_GENERATE_WEEKLY_REPORT;

    PROMPT Generating customer analytics...
    PKG_REPORTING.PROC_CUSTOMER_ANALYTICS(v_customer_id);

    IF v_technician_id IS NOT NULL THEN
        PROMPT Generating technician performance report...
        PKG_REPORTING.PROC_TECHNICIAN_PERFORMANCE_REPORT(v_technician_id);
    END IF;

    -- Test SLA monitoring
    PROMPT Testing SLA monitoring...
    PKG_SLA_MONITORING.PROC_MONITOR_ACTIVE_REQUESTS;

    PROMPT End-to-end workflow test complete successfully!

EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Error in E2E test: ' || SQLERRM);
        RAISE;
END;
/

-- ============================================================================
-- ADDITIONAL VALIDATION TESTS
-- ============================================================================

PROMPT ====================================================================
PROMPT Additional Validation Tests
PROMPT ====================================================================

-- Test function calculations
PROMPT Testing function calculations...

DECLARE
    v_avg_time NUMBER;
    v_satisfaction NUMBER;
    v_technician_id NUMBER;
    v_customer_id NUMBER;
BEGIN
    -- Test average resolution time
    SELECT MIN(technician_id) INTO v_technician_id FROM TECHNICIANS;
    
    v_avg_time := FUNC_AVG_RESOLUTION_TIME_PER_TECHNICIAN(v_technician_id, NULL, NULL);
    PROMPT Average resolution time for Technician #' || v_technician_id || ': ' || 
           NVL(TO_CHAR(v_avg_time), 'N/A') || ' hours');

    -- Test customer satisfaction
    SELECT MIN(customer_id) INTO v_customer_id FROM CUSTOMERS;
    
    v_satisfaction := FUNC_COMPUTE_CUSTOMER_SATISFACTION_SCORE(v_customer_id);
    PROMPT Customer satisfaction score for Customer #' || v_customer_id || ': ' || 
           NVL(TO_CHAR(v_satisfaction), 'N/A') || ' / 5.0');

    -- Test overall satisfaction
    v_satisfaction := FUNC_COMPUTE_CUSTOMER_SATISFACTION_SCORE(NULL);
    PROMPT Overall customer satisfaction score: ' || 
           NVL(TO_CHAR(v_satisfaction), 'N/A') || ' / 5.0');

END;
/

-- Test SLA compliance checking
PROMPT Testing SLA compliance checking...

SELECT sr.request_id, sr.priority, sr.status,
       PKG_SLA_MONITORING.FUNC_CHECK_SLA_COMPLIANCE(sr.request_id) AS compliance_status,
       PKG_SLA_MONITORING.FUNC_GET_REMAINING_TIME(sr.request_id) AS hours_remaining
FROM SERVICE_REQUESTS sr
WHERE sr.status NOT IN ('Closed', 'Resolved')
  AND ROWNUM <= 5
ORDER BY sr.request_id;

PROMPT ====================================================================
PROMPT All test scenarios completed!
PROMPT ====================================================================

PROMPT Phase 7 Complete: All testing and validation scenarios executed!
PROMPT Ready for Phase 8: Documentation.
PROMPT Note: See 08_documentation.md for complete system documentation

