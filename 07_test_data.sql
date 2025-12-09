-- ============================================================================
-- CRM Database System - Test Data Population
-- Phase 7.1: Sample Data Inserts
-- Target PDB: lu_plsqlauca_25815
-- Oracle SQL Developer 24.3
-- ============================================================================

SET SERVEROUTPUT ON;
PROMPT Starting Phase 7.1: Test Data Population...

-- ============================================================================
-- CLEANUP EXISTING DATA (Optional - uncomment if needed)
-- ============================================================================

-- DELETE FROM FEEDBACK;
-- DELETE FROM ASSIGNMENTS;
-- DELETE FROM SERVICE_REQUESTS;
-- DELETE FROM TECHNICIANS;
-- DELETE FROM PRODUCTS;
-- DELETE FROM CUSTOMERS;
-- COMMIT;

-- ============================================================================
-- 7.1.1 INSERT CUSTOMERS (10-15 customers)
-- ============================================================================

PROMPT Inserting customers...

INSERT INTO CUSTOMERS (customer_id, name, contact, company, tier) VALUES
(seq_customer_id.NEXTVAL, 'John Smith', 'john.smith@email.com', 'Acme Corp', 'Gold');
INSERT INTO CUSTOMERS (customer_id, name, contact, company, tier) VALUES
(seq_customer_id.NEXTVAL, 'Sarah Johnson', 'sarah.j@email.com', 'TechSolutions Inc', 'Platinum');
INSERT INTO CUSTOMERS (customer_id, name, contact, company, tier) VALUES
(seq_customer_id.NEXTVAL, 'Michael Brown', 'm.brown@email.com', 'Global Systems', 'Silver');
INSERT INTO CUSTOMERS (customer_id, name, contact, company, tier) VALUES
(seq_customer_id.NEXTVAL, 'Emily Davis', 'emily.davis@email.com', 'DataWorks LLC', 'Bronze');
INSERT INTO CUSTOMERS (customer_id, name, contact, company, tier) VALUES
(seq_customer_id.NEXTVAL, 'David Wilson', 'd.wilson@email.com', 'Innovation Labs', 'Gold');
INSERT INTO CUSTOMERS (customer_id, name, contact, company, tier) VALUES
(seq_customer_id.NEXTVAL, 'Lisa Anderson', 'lisa.a@email.com', 'Cloud Services Co', 'Platinum');
INSERT INTO CUSTOMERS (customer_id, name, contact, company, tier) VALUES
(seq_customer_id.NEXTVAL, 'Robert Taylor', 'robert.t@email.com', 'Digital Dynamics', 'Silver');
INSERT INTO CUSTOMERS (customer_id, name, contact, company, tier) VALUES
(seq_customer_id.NEXTVAL, 'Jennifer Martinez', 'j.martinez@email.com', 'SecureNet Systems', 'Bronze');
INSERT INTO CUSTOMERS (customer_id, name, contact, company, tier) VALUES
(seq_customer_id.NEXTVAL, 'William Lee', 'w.lee@email.com', 'Future Tech', 'Gold');
INSERT INTO CUSTOMERS (customer_id, name, contact, company, tier) VALUES
(seq_customer_id.NEXTVAL, 'Amanda White', 'amanda.w@email.com', 'Enterprise Solutions', 'Platinum');
INSERT INTO CUSTOMERS (customer_id, name, contact, company, tier) VALUES
(seq_customer_id.NEXTVAL, 'Christopher Harris', 'chris.h@email.com', 'Software Innovations', 'Silver');
INSERT INTO CUSTOMERS (customer_id, name, contact, company, tier) VALUES
(seq_customer_id.NEXTVAL, 'Michelle Clark', 'michelle.c@email.com', 'IT Services Group', 'Bronze');

COMMIT;
PROMPT 12 customers inserted.

-- ============================================================================
-- 7.1.2 INSERT PRODUCTS (8-10 products)
-- ============================================================================

PROMPT Inserting products...

INSERT INTO PRODUCTS (product_id, name, category, price, stock) VALUES
(seq_product_id.NEXTVAL, 'Enterprise Server 2024', 'Hardware', 5000.00, 25);
INSERT INTO PRODUCTS (product_id, name, category, price, stock) VALUES
(seq_product_id.NEXTVAL, 'Database Management Suite', 'Software', 3000.00, 100);
INSERT INTO PRODUCTS (product_id, name, category, price, stock) VALUES
(seq_product_id.NEXTVAL, 'Network Router Pro', 'Hardware', 1200.00, 50);
INSERT INTO PRODUCTS (product_id, name, category, price, stock) VALUES
(seq_product_id.NEXTVAL, 'Security Software Premium', 'Software', 2500.00, 200);
INSERT INTO PRODUCTS (product_id, name, category, price, stock) VALUES
(seq_product_id.NEXTVAL, 'Cloud Storage Service', 'Service', 500.00, 999);
INSERT INTO PRODUCTS (product_id, name, category, price, stock) VALUES
(seq_product_id.NEXTVAL, 'Backup Solution Enterprise', 'Software', 4500.00, 75);
INSERT INTO PRODUCTS (product_id, name, category, price, stock) VALUES
(seq_product_id.NEXTVAL, 'Workstation Desktop', 'Hardware', 1500.00, 30);
INSERT INTO PRODUCTS (product_id, name, category, price, stock) VALUES
(seq_product_id.NEXTVAL, 'Monitoring Dashboard', 'Software', 1800.00, 150);
INSERT INTO PRODUCTS (product_id, name, category, price, stock) VALUES
(seq_product_id.NEXTVAL, 'IT Support Package', 'Service', 2000.00, 999);

COMMIT;
PROMPT 9 products inserted.

-- ============================================================================
-- 7.1.3 INSERT TECHNICIANS (5-6 technicians)
-- ============================================================================

PROMPT Inserting technicians...

INSERT INTO TECHNICIANS (technician_id, name, skill_level, availability) VALUES
(seq_technician_id.NEXTVAL, 'James Anderson', 'Expert', 'Available');
INSERT INTO TECHNICIANS (technician_id, name, skill_level, availability) VALUES
(seq_technician_id.NEXTVAL, 'Patricia Thompson', 'Senior', 'Available');
INSERT INTO TECHNICIANS (technician_id, name, skill_level, availability) VALUES
(seq_technician_id.NEXTVAL, 'Richard Garcia', 'Senior', 'Available');
INSERT INTO TECHNICIANS (technician_id, name, skill_level, availability) VALUES
(seq_technician_id.NEXTVAL, 'Mary Rodriguez', 'Mid', 'Available');
INSERT INTO TECHNICIANS (technician_id, name, skill_level, availability) VALUES
(seq_technician_id.NEXTVAL, 'Joseph Martinez', 'Mid', 'Available');
INSERT INTO TECHNICIANS (technician_id, name, skill_level, availability) VALUES
(seq_technician_id.NEXTVAL, 'Nancy Lewis', 'Junior', 'Available');

COMMIT;
PROMPT 6 technicians inserted.

-- ============================================================================
-- 7.1.4 INSERT SERVICE REQUESTS (20-30 requests with various statuses)
-- ============================================================================

PROMPT Inserting service requests...
PROMPT Note: Auto-assignment trigger will assign technicians automatically for 'Open' status requests.

-- Open requests (will be auto-assigned)
INSERT INTO SERVICE_REQUESTS (request_id, customer_id, product_id, issue_type, priority, status, created_at)
SELECT seq_request_id.NEXTVAL, customer_id, product_id, 'Server not responding', 'High', 'Open', CURRENT_TIMESTAMP - 2
FROM (SELECT MIN(customer_id) AS customer_id FROM CUSTOMERS),
     (SELECT MIN(product_id) AS product_id FROM PRODUCTS);

INSERT INTO SERVICE_REQUESTS (request_id, customer_id, product_id, issue_type, priority, status, created_at)
SELECT seq_request_id.NEXTVAL, customer_id, product_id, 'Database connection timeout', 'Critical', 'Open', CURRENT_TIMESTAMP - 1
FROM (SELECT customer_id FROM (SELECT customer_id FROM CUSTOMERS ORDER BY customer_id) WHERE ROWNUM = 2),
     (SELECT product_id FROM (SELECT product_id FROM PRODUCTS ORDER BY product_id) WHERE ROWNUM = 2);

INSERT INTO SERVICE_REQUESTS (request_id, customer_id, product_id, issue_type, priority, status, created_at)
SELECT seq_request_id.NEXTVAL, customer_id, product_id, 'Network slow', 'Low', 'Open', CURRENT_TIMESTAMP - 0.5
FROM (SELECT customer_id FROM (SELECT customer_id FROM CUSTOMERS ORDER BY customer_id) WHERE ROWNUM <= 3 ORDER BY customer_id DESC FETCH FIRST 1 ROW ONLY),
     (SELECT product_id FROM (SELECT product_id FROM PRODUCTS ORDER BY product_id) WHERE ROWNUM <= 3 ORDER BY product_id DESC FETCH FIRST 1 ROW ONLY);

-- Assigned requests
INSERT INTO SERVICE_REQUESTS (request_id, customer_id, product_id, issue_type, priority, status, created_at)
SELECT seq_request_id.NEXTVAL, customer_id, product_id, 'Security update needed', 'Medium', 'Assigned', CURRENT_TIMESTAMP - 3
FROM (SELECT customer_id FROM (SELECT customer_id FROM CUSTOMERS ORDER BY customer_id) WHERE ROWNUM <= 4 ORDER BY customer_id DESC FETCH FIRST 1 ROW ONLY),
     (SELECT product_id FROM (SELECT product_id FROM PRODUCTS ORDER BY product_id) WHERE ROWNUM <= 4 ORDER BY product_id DESC FETCH FIRST 1 ROW ONLY);

INSERT INTO SERVICE_REQUESTS (request_id, customer_id, product_id, issue_type, priority, status, created_at)
SELECT seq_request_id.NEXTVAL, customer_id, product_id, 'Storage quota exceeded', 'High', 'Assigned', CURRENT_TIMESTAMP - 2.5
FROM (SELECT customer_id FROM (SELECT customer_id FROM CUSTOMERS ORDER BY customer_id) WHERE ROWNUM <= 5 ORDER BY customer_id DESC FETCH FIRST 1 ROW ONLY),
     (SELECT product_id FROM (SELECT product_id FROM PRODUCTS ORDER BY product_id) WHERE ROWNUM <= 5 ORDER BY product_id DESC FETCH FIRST 1 ROW ONLY);

-- In Progress requests
INSERT INTO SERVICE_REQUESTS (request_id, customer_id, product_id, issue_type, priority, status, created_at)
SELECT seq_request_id.NEXTVAL, customer_id, product_id, 'Backup failed', 'High', 'In Progress', CURRENT_TIMESTAMP - 4
FROM (SELECT customer_id FROM (SELECT customer_id FROM CUSTOMERS ORDER BY customer_id) WHERE ROWNUM <= 6 ORDER BY customer_id DESC FETCH FIRST 1 ROW ONLY),
     (SELECT product_id FROM (SELECT product_id FROM PRODUCTS ORDER BY product_id) WHERE ROWNUM <= 6 ORDER BY product_id DESC FETCH FIRST 1 ROW ONLY);

INSERT INTO SERVICE_REQUESTS (request_id, customer_id, product_id, issue_type, priority, status, created_at)
SELECT seq_request_id.NEXTVAL, customer_id, product_id, 'Desktop crash', 'Medium', 'In Progress', CURRENT_TIMESTAMP - 1.5
FROM (SELECT customer_id FROM (SELECT customer_id FROM CUSTOMERS ORDER BY customer_id) WHERE ROWNUM <= 7 ORDER BY customer_id DESC FETCH FIRST 1 ROW ONLY),
     (SELECT product_id FROM (SELECT product_id FROM PRODUCTS ORDER BY product_id) WHERE ROWNUM <= 7 ORDER BY product_id DESC FETCH FIRST 1 ROW ONLY);

-- Resolved requests (with past created_at and resolved_at)
INSERT INTO SERVICE_REQUESTS (request_id, customer_id, product_id, issue_type, priority, status, created_at, resolved_at)
SELECT seq_request_id.NEXTVAL, customer_id, product_id, 'Dashboard not loading', 'Low', 'Resolved', CURRENT_TIMESTAMP - 10, CURRENT_TIMESTAMP - 9
FROM (SELECT customer_id FROM (SELECT customer_id FROM CUSTOMERS ORDER BY customer_id) WHERE ROWNUM <= 8 ORDER BY customer_id DESC FETCH FIRST 1 ROW ONLY),
     (SELECT product_id FROM (SELECT product_id FROM PRODUCTS ORDER BY product_id) WHERE ROWNUM <= 8 ORDER BY product_id DESC FETCH FIRST 1 ROW ONLY);

INSERT INTO SERVICE_REQUESTS (request_id, customer_id, product_id, issue_type, priority, status, created_at, resolved_at)
SELECT seq_request_id.NEXTVAL, customer_id, product_id, 'Support package inquiry', 'Low', 'Resolved', CURRENT_TIMESTAMP - 8, CURRENT_TIMESTAMP - 7
FROM (SELECT customer_id FROM (SELECT customer_id FROM CUSTOMERS ORDER BY customer_id) WHERE ROWNUM <= 9 ORDER BY customer_id DESC FETCH FIRST 1 ROW ONLY),
     (SELECT product_id FROM (SELECT product_id FROM PRODUCTS ORDER BY product_id) WHERE ROWNUM <= 9 ORDER BY product_id DESC FETCH FIRST 1 ROW ONLY);

-- Closed requests
INSERT INTO SERVICE_REQUESTS (request_id, customer_id, product_id, issue_type, priority, status, created_at, resolved_at)
SELECT seq_request_id.NEXTVAL, customer_id, product_id, 'Server configuration issue', 'Medium', 'Closed', CURRENT_TIMESTAMP - 15, CURRENT_TIMESTAMP - 14
FROM (SELECT customer_id FROM (SELECT customer_id FROM CUSTOMERS ORDER BY customer_id) WHERE ROWNUM <= 10 ORDER BY customer_id DESC FETCH FIRST 1 ROW ONLY),
     (SELECT MIN(product_id) AS product_id FROM PRODUCTS);

INSERT INTO SERVICE_REQUESTS (request_id, customer_id, product_id, issue_type, priority, status, created_at, resolved_at)
SELECT seq_request_id.NEXTVAL, customer_id, product_id, 'Database backup needed', 'High', 'Closed', CURRENT_TIMESTAMP - 12, CURRENT_TIMESTAMP - 11
FROM (SELECT customer_id FROM (SELECT customer_id FROM CUSTOMERS ORDER BY customer_id) WHERE ROWNUM <= 11 ORDER BY customer_id DESC FETCH FIRST 1 ROW ONLY),
     (SELECT product_id FROM (SELECT product_id FROM PRODUCTS ORDER BY product_id) WHERE ROWNUM = 2);

INSERT INTO SERVICE_REQUESTS (request_id, customer_id, product_id, issue_type, priority, status, created_at, resolved_at)
SELECT seq_request_id.NEXTVAL, customer_id, product_id, 'Router configuration', 'Low', 'Closed', CURRENT_TIMESTAMP - 20, CURRENT_TIMESTAMP - 19
FROM (SELECT customer_id FROM (SELECT customer_id FROM CUSTOMERS ORDER BY customer_id) WHERE ROWNUM <= 12 ORDER BY customer_id DESC FETCH FIRST 1 ROW ONLY),
     (SELECT product_id FROM (SELECT product_id FROM PRODUCTS ORDER BY product_id) WHERE ROWNUM <= 3 ORDER BY product_id DESC FETCH FIRST 1 ROW ONLY);

-- More requests with various dates for SLA testing
INSERT INTO SERVICE_REQUESTS (request_id, customer_id, product_id, issue_type, priority, status, created_at)
SELECT seq_request_id.NEXTVAL, customer_id, product_id, 'Security patch required', 'Medium', 'Open', CURRENT_TIMESTAMP - 2
FROM (SELECT MIN(customer_id) AS customer_id FROM CUSTOMERS),
     (SELECT product_id FROM (SELECT product_id FROM PRODUCTS ORDER BY product_id) WHERE ROWNUM <= 4 ORDER BY product_id DESC FETCH FIRST 1 ROW ONLY);

INSERT INTO SERVICE_REQUESTS (request_id, customer_id, product_id, issue_type, priority, status, created_at)
SELECT seq_request_id.NEXTVAL, customer_id, product_id, 'Cloud sync issue', 'Low', 'Assigned', CURRENT_TIMESTAMP - 1
FROM (SELECT customer_id FROM (SELECT customer_id FROM CUSTOMERS ORDER BY customer_id) WHERE ROWNUM = 2),
     (SELECT product_id FROM (SELECT product_id FROM PRODUCTS ORDER BY product_id) WHERE ROWNUM <= 5 ORDER BY product_id DESC FETCH FIRST 1 ROW ONLY);

COMMIT;

-- Now manually create assignments for requests that are not 'Open'
-- (Open requests should have been auto-assigned by trigger)

PROMPT Creating assignments for non-Open requests...

-- Assign technicians to non-Open requests using a simple approach
-- Match each request with a technician in round-robin fashion

DECLARE
    CURSOR c_requests IS
        SELECT request_id, created_at, status
        FROM SERVICE_REQUESTS
        WHERE status IN ('Assigned', 'In Progress', 'Resolved', 'Closed')
          AND NOT EXISTS (SELECT 1 FROM ASSIGNMENTS a WHERE a.request_id = SERVICE_REQUESTS.request_id)
        ORDER BY request_id;
    
    v_tech_cursor SYS_REFCURSOR;
    v_technician_id NUMBER;
    v_tech_count NUMBER;
    v_counter NUMBER := 0;
BEGIN
    -- Get technician count
    SELECT COUNT(*) INTO v_tech_count FROM TECHNICIANS;
    
    -- Open cursor for technicians
    OPEN v_tech_cursor FOR 
        SELECT technician_id FROM TECHNICIANS ORDER BY technician_id;
    
    FOR rec IN c_requests LOOP
        -- Get next technician in round-robin
        FETCH v_tech_cursor INTO v_technician_id;
        IF v_tech_cursor%NOTFOUND THEN
            CLOSE v_tech_cursor;
            OPEN v_tech_cursor FOR 
                SELECT technician_id FROM TECHNICIANS ORDER BY technician_id;
            FETCH v_tech_cursor INTO v_technician_id;
        END IF;
        
        -- Insert assignment
        INSERT INTO ASSIGNMENTS (assignment_id, request_id, technician_id, assigned_at)
        VALUES (seq_assignment_id.NEXTVAL, rec.request_id, v_technician_id, rec.created_at);
        
        v_counter := v_counter + 1;
    END LOOP;
    
    CLOSE v_tech_cursor;
    
    COMMIT;
    DBMS_OUTPUT.PUT_LINE('Created ' || v_counter || ' assignments for non-Open requests');
    
EXCEPTION
    WHEN OTHERS THEN
        IF v_tech_cursor%ISOPEN THEN
            CLOSE v_tech_cursor;
        END IF;
        DBMS_OUTPUT.PUT_LINE('Error creating assignments: ' || SQLERRM);
        RAISE;
END;
/

COMMIT;

-- ============================================================================
-- 7.1.5 INSERT FEEDBACK (for closed/resolved requests)
-- ============================================================================

PROMPT Inserting feedback records...

-- Feedback for resolved/closed requests (triggers will update status to Closed)
-- Select up to 5 resolved/closed requests that don't have feedback yet
INSERT INTO FEEDBACK (feedback_id, request_id, rating, remarks, submitted_at)
SELECT seq_feedback_id.NEXTVAL, sr.request_id, 
       CASE 
           WHEN ROWNUM = 1 THEN 4.5
           WHEN ROWNUM = 2 THEN 5.0
           WHEN ROWNUM = 3 THEN 4.0
           WHEN ROWNUM = 4 THEN 4.8
           WHEN ROWNUM = 5 THEN 3.5
       END AS rating,
       CASE 
           WHEN ROWNUM = 1 THEN 'Quick response, issue resolved promptly'
           WHEN ROWNUM = 2 THEN 'Excellent service, very helpful'
           WHEN ROWNUM = 3 THEN 'Good service, minor delay'
           WHEN ROWNUM = 4 THEN 'Professional and efficient'
           WHEN ROWNUM = 5 THEN 'Service was adequate'
       END AS remarks,
       CASE 
           WHEN ROWNUM = 1 THEN CURRENT_TIMESTAMP - 8.5
           WHEN ROWNUM = 2 THEN CURRENT_TIMESTAMP - 6.5
           WHEN ROWNUM = 3 THEN CURRENT_TIMESTAMP - 13
           WHEN ROWNUM = 4 THEN CURRENT_TIMESTAMP - 10
           WHEN ROWNUM = 5 THEN CURRENT_TIMESTAMP - 18
       END AS submitted_at
FROM (
    SELECT sr.request_id, sr.resolved_at, sr.created_at
    FROM SERVICE_REQUESTS sr
    LEFT JOIN FEEDBACK f ON sr.request_id = f.request_id
    WHERE sr.status IN ('Resolved', 'Closed')
      AND f.request_id IS NULL
    ORDER BY sr.request_id
    FETCH FIRST 5 ROWS ONLY
) sr;

COMMIT;
PROMPT 5 feedback records inserted.

-- ============================================================================
-- 7.1.6 VERIFICATION
-- ============================================================================

PROMPT Verifying test data...

SELECT 'CUSTOMERS' AS table_name, COUNT(*) AS row_count FROM CUSTOMERS
UNION ALL
SELECT 'PRODUCTS', COUNT(*) FROM PRODUCTS
UNION ALL
SELECT 'TECHNICIANS', COUNT(*) FROM TECHNICIANS
UNION ALL
SELECT 'SLA_RULES', COUNT(*) FROM SLA_RULES
UNION ALL
SELECT 'SERVICE_REQUESTS', COUNT(*) FROM SERVICE_REQUESTS
UNION ALL
SELECT 'ASSIGNMENTS', COUNT(*) FROM ASSIGNMENTS
UNION ALL
SELECT 'FEEDBACK', COUNT(*) FROM FEEDBACK;

PROMPT Phase 7.1 Complete: Test data populated successfully!
PROMPT Ready for Phase 7.2: Test Scenarios.

