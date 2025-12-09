-- ============================================================================
-- CRM Database System - PL/SQL Functions
-- Phase 5: Standalone Functions
-- Target PDB: lu_plsqlauca_25815
-- Oracle SQL Developer 24.3
-- ============================================================================

SET SERVEROUTPUT ON;
PROMPT Starting Phase 5: Standalone Function Implementation...

-- ============================================================================
-- 5.1 RESOLUTION TIME FUNCTION
-- ============================================================================

PROMPT Creating function FUNC_AVG_RESOLUTION_TIME_PER_TECHNICIAN...

CREATE OR REPLACE FUNCTION FUNC_AVG_RESOLUTION_TIME_PER_TECHNICIAN(
    p_technician_id IN NUMBER,
    p_start_date IN DATE DEFAULT NULL,
    p_end_date IN DATE DEFAULT NULL
) RETURN NUMBER
    AS
        v_avg_hours NUMBER;
        v_start DATE;
        v_end DATE;
        v_tech_exists NUMBER;
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

        -- Validate technician exists
        SELECT COUNT(*)
        INTO v_tech_exists
        FROM TECHNICIANS
        WHERE technician_id = p_technician_id;
        
        IF v_tech_exists = 0 THEN
            RAISE_APPLICATION_ERROR(-20010, 'Technician ID ' || p_technician_id || ' does not exist');
        END IF;

    -- Calculate average resolution time in hours
    -- Only include resolved/closed requests with resolved_at timestamp
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

    -- Return rounded average (0 if no resolved requests found)
    RETURN ROUND(NVL(v_avg_hours, 0), 2);

EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Error in FUNC_AVG_RESOLUTION_TIME_PER_TECHNICIAN: ' || SQLERRM);
        RETURN NULL;
END FUNC_AVG_RESOLUTION_TIME_PER_TECHNICIAN;
/

PROMPT Function FUNC_AVG_RESOLUTION_TIME_PER_TECHNICIAN created successfully.

-- ============================================================================
-- 5.2 CUSTOMER SATISFACTION FUNCTION
-- ============================================================================

PROMPT Creating function FUNC_COMPUTE_CUSTOMER_SATISFACTION_SCORE...

CREATE OR REPLACE FUNCTION FUNC_COMPUTE_CUSTOMER_SATISFACTION_SCORE(
    p_customer_id IN NUMBER DEFAULT NULL
) RETURN NUMBER
AS
    v_avg_rating NUMBER(3,2);
    v_total_rating NUMBER;
    v_feedback_count NUMBER;
    v_customer_exists NUMBER;
BEGIN
    -- If customer_id is NULL, return overall average across all customers
    IF p_customer_id IS NULL THEN
        SELECT AVG(rating), SUM(rating), COUNT(*)
        INTO v_avg_rating, v_total_rating, v_feedback_count
        FROM FEEDBACK
        WHERE rating IS NOT NULL;

        -- Return overall average or 0 if no feedback exists
        RETURN ROUND(NVL(v_avg_rating, 0), 2);
    ELSE
        -- Validate customer exists
        SELECT COUNT(*)
        INTO v_customer_exists
        FROM CUSTOMERS
        WHERE customer_id = p_customer_id;
        
        IF v_customer_exists = 0 THEN
            RAISE_APPLICATION_ERROR(-20011, 'Customer ID ' || p_customer_id || ' does not exist');
        END IF;

        -- Calculate weighted average rating for specific customer
        -- Optional: Weight recent feedback higher
        -- For simplicity, using simple average
        SELECT AVG(f.rating), SUM(f.rating), COUNT(*)
        INTO v_avg_rating, v_total_rating, v_feedback_count
        FROM FEEDBACK f
        JOIN SERVICE_REQUESTS sr ON f.request_id = sr.request_id
        WHERE sr.customer_id = p_customer_id
          AND f.rating IS NOT NULL;

        -- Return average rating or 0 if no feedback exists
        RETURN ROUND(NVL(v_avg_rating, 0), 2);
    END IF;

EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Error in FUNC_COMPUTE_CUSTOMER_SATISFACTION_SCORE: ' || SQLERRM);
        RETURN NULL;
END FUNC_COMPUTE_CUSTOMER_SATISFACTION_SCORE;
/

PROMPT Function FUNC_COMPUTE_CUSTOMER_SATISFACTION_SCORE created successfully.

-- ============================================================================
-- 5.3 VERIFICATION
-- ============================================================================

PROMPT Verifying function creation...

SELECT object_name, object_type, status
FROM user_objects
WHERE object_name IN ('FUNC_AVG_RESOLUTION_TIME_PER_TECHNICIAN', 'FUNC_COMPUTE_CUSTOMER_SATISFACTION_SCORE')
  AND object_type = 'FUNCTION'
ORDER BY object_name;

PROMPT Phase 5 Complete: All standalone functions created successfully!
PROMPT Ready for Phase 6: Security Implementation.

