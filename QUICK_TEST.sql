-- ============================================================================
-- Quick Test Script for CRM System
-- Tests auto-assignment functionality
-- ============================================================================

SET SERVEROUTPUT ON;

PROMPT ============================================================================
PROMPT Test 1: Creating a new service request (should auto-assign)
PROMPT ============================================================================

DECLARE
    v_req_id NUMBER;
    v_customer_id NUMBER;
    v_product_id NUMBER;
    v_technician_id NUMBER;
BEGIN
    -- Get customer and product IDs first
    SELECT MIN(customer_id) INTO v_customer_id FROM CUSTOMERS;
    SELECT MIN(product_id) INTO v_product_id FROM PRODUCTS;
    
    -- Create the request (status will be 'Open', trigger should assign it)
    v_req_id := PKG_TICKET_MANAGEMENT.FUNC_CREATE_REQUEST(
        v_customer_id,
        v_product_id,
        'Quick Test Request - Auto Assignment',
        'High'
    );
    
    DBMS_OUTPUT.PUT_LINE('✓ Created request ID: ' || v_req_id);
    
    -- Wait a moment for trigger to process
    COMMIT;
    
    -- Check if it was auto-assigned
    SELECT technician_id INTO v_technician_id
    FROM ASSIGNMENTS
    WHERE request_id = v_req_id;
    
    IF v_technician_id IS NOT NULL THEN
        DBMS_OUTPUT.PUT_LINE('✓ SUCCESS: Request was automatically assigned to Technician ' || v_technician_id);
    ELSE
        DBMS_OUTPUT.PUT_LINE('✗ WARNING: Request was NOT automatically assigned');
    END IF;
    
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        DBMS_OUTPUT.PUT_LINE('✗ Request was created but NOT assigned (no available technician)');
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('✗ Error: ' || SQLERRM);
END;
/

PROMPT 
PROMPT ============================================================================
PROMPT Test 2: Check request status and assignment
PROMPT ============================================================================

SELECT 
    sr.request_id, 
    sr.status, 
    sr.priority,
    sr.issue_type,
    a.technician_id,
    t.name AS technician_name
FROM SERVICE_REQUESTS sr
LEFT JOIN ASSIGNMENTS a ON sr.request_id = a.request_id
LEFT JOIN TECHNICIANS t ON a.technician_id = t.technician_id
WHERE sr.request_id = (SELECT MAX(request_id) FROM SERVICE_REQUESTS)
ORDER BY sr.request_id DESC;

PROMPT 
PROMPT ============================================================================
PROMPT Test 3: Test SLA monitoring functions
PROMPT ============================================================================

DECLARE
    v_request_id NUMBER;
    v_hours_remaining NUMBER;
    v_is_compliant VARCHAR2(20);  -- Fixed: Changed from VARCHAR2(1) to VARCHAR2(20)
                                  -- Function returns: 'compliant', 'at_risk', 'violated', 'N/A', or 'ERROR'
BEGIN
    -- Get a recent request
    SELECT MAX(request_id) INTO v_request_id FROM SERVICE_REQUESTS;
    
    -- Check SLA compliance
    v_is_compliant := PKG_SLA_MONITORING.FUNC_CHECK_SLA_COMPLIANCE(v_request_id);
    v_hours_remaining := PKG_SLA_MONITORING.FUNC_GET_REMAINING_TIME(v_request_id);
    
    DBMS_OUTPUT.PUT_LINE('Request ID: ' || v_request_id);
    DBMS_OUTPUT.PUT_LINE('SLA Compliance Status: ' || v_is_compliant);
    DBMS_OUTPUT.PUT_LINE('Hours Remaining: ' || NVL(TO_CHAR(v_hours_remaining), 'N/A'));
    
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        DBMS_OUTPUT.PUT_LINE('No service requests found in the system.');
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Error testing SLA: ' || SQLERRM);
        DBMS_OUTPUT.PUT_LINE('SQLCODE: ' || SQLCODE);
END;
/

PROMPT 
PROMPT ============================================================================
PROMPT Test 4: Test reporting functions
PROMPT ============================================================================

DECLARE
    v_avg_time NUMBER;
    v_satisfaction NUMBER;
    v_tech_id NUMBER;
    v_cust_id NUMBER;
BEGIN
    -- Get sample IDs
    SELECT MIN(technician_id) INTO v_tech_id FROM TECHNICIANS;
    SELECT MIN(customer_id) INTO v_cust_id FROM CUSTOMERS;
    
    -- Test average resolution time
    BEGIN
        v_avg_time := FUNC_AVG_RESOLUTION_TIME_PER_TECHNICIAN(v_tech_id);
        DBMS_OUTPUT.PUT_LINE('Average Resolution Time for Technician ' || v_tech_id || ': ' || 
                            NVL(TO_CHAR(v_avg_time), 'No data') || ' hours');
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('Could not calculate avg resolution time: ' || SQLERRM);
    END;
    
    -- Test satisfaction score
    BEGIN
        v_satisfaction := FUNC_COMPUTE_CUSTOMER_SATISFACTION_SCORE(v_cust_id);
        DBMS_OUTPUT.PUT_LINE('Customer Satisfaction Score for Customer ' || v_cust_id || ': ' || 
                            NVL(TO_CHAR(v_satisfaction), 'No data'));
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('Could not calculate satisfaction score: ' || SQLERRM);
    END;
    
END;
/

PROMPT 
PROMPT ============================================================================
PROMPT All tests completed!
PROMPT ============================================================================

