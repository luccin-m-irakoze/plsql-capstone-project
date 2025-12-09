-- ============================================================================
-- CRM Database System - Schema Creation Script
-- Phase 1: Table Creation with Sequences, Constraints, and Indexes
-- Target PDB: lu_plsqlauca_25815
-- Oracle SQL Developer 24.3
-- ============================================================================

SET SERVEROUTPUT ON;
PROMPT Starting Phase 1: Schema Creation...
PROMPT Note: If you encounter ORA-01950 (tablespace quota) errors, ask your DBA to grant quota:
PROMPT ALTER USER your_username QUOTA UNLIMITED ON USERS;
PROMPT Or specify a tablespace in CREATE TABLE statements.

-- ============================================================================
-- 1.1 CREATE SEQUENCES
-- ============================================================================

PROMPT Creating sequences for primary keys...

-- Drop sequences if they exist (for clean reinstall)
BEGIN
    FOR rec IN (SELECT sequence_name FROM user_sequences WHERE sequence_name LIKE 'SEQ_%') LOOP
        EXECUTE IMMEDIATE 'DROP SEQUENCE ' || rec.sequence_name;
    END LOOP;
EXCEPTION
    WHEN OTHERS THEN NULL;
END;
/

CREATE SEQUENCE seq_customer_id
    START WITH 1
    INCREMENT BY 1
    NOCACHE
    NOCYCLE;

CREATE SEQUENCE seq_product_id
    START WITH 1
    INCREMENT BY 1
    NOCACHE
    NOCYCLE;

CREATE SEQUENCE seq_technician_id
    START WITH 1
    INCREMENT BY 1
    NOCACHE
    NOCYCLE;

CREATE SEQUENCE seq_sla_id
    START WITH 1
    INCREMENT BY 1
    NOCACHE
    NOCYCLE;

CREATE SEQUENCE seq_request_id
    START WITH 1
    INCREMENT BY 1
    NOCACHE
    NOCYCLE;

CREATE SEQUENCE seq_assignment_id
    START WITH 1
    INCREMENT BY 1
    NOCACHE
    NOCYCLE;

CREATE SEQUENCE seq_feedback_id
    START WITH 1
    INCREMENT BY 1
    NOCACHE
    NOCYCLE;

PROMPT Sequences created successfully.

-- ============================================================================
-- 1.2 DROP EXISTING TABLES (if any exist, for clean reinstall)
-- ============================================================================

PROMPT Dropping existing tables if they exist (for clean reinstall)...

BEGIN
    FOR rec IN (
        SELECT table_name FROM user_tables 
        WHERE table_name IN ('FEEDBACK', 'ASSIGNMENTS', 'SERVICE_REQUESTS', 'TECHNICIANS', 
                             'PRODUCTS', 'CUSTOMERS', 'SLA_RULES')
        ORDER BY CASE table_name
            WHEN 'FEEDBACK' THEN 1
            WHEN 'ASSIGNMENTS' THEN 2
            WHEN 'SERVICE_REQUESTS' THEN 3
            WHEN 'TECHNICIANS' THEN 4
            WHEN 'PRODUCTS' THEN 5
            WHEN 'CUSTOMERS' THEN 6
            WHEN 'SLA_RULES' THEN 7
        END
    ) LOOP
        BEGIN
            EXECUTE IMMEDIATE 'DROP TABLE ' || rec.table_name || ' CASCADE CONSTRAINTS';
            DBMS_OUTPUT.PUT_LINE('Dropped table: ' || rec.table_name);
        EXCEPTION
            WHEN OTHERS THEN
                NULL; -- Ignore errors
        END;
    END LOOP;
EXCEPTION
    WHEN OTHERS THEN
        NULL; -- Continue even if drop fails
END;
/

-- ============================================================================
-- 1.3 CREATE TABLES (in dependency order)
-- ============================================================================

-- Table 1: CUSTOMERS
PROMPT Creating table CUSTOMERS...

CREATE TABLE CUSTOMERS (
    customer_id NUMBER PRIMARY KEY,
    name VARCHAR2(100) NOT NULL,
    contact VARCHAR2(50),
    company VARCHAR2(100),
    tier VARCHAR2(20) CHECK (tier IN ('Bronze', 'Silver', 'Gold', 'Platinum'))
);

-- Indexes on CUSTOMERS
CREATE INDEX idx_customers_tier ON CUSTOMERS(tier);
CREATE INDEX idx_customers_company ON CUSTOMERS(company);

PROMPT Table CUSTOMERS created successfully.

-- Table 2: PRODUCTS
PROMPT Creating table PRODUCTS...

CREATE TABLE PRODUCTS (
    product_id NUMBER PRIMARY KEY,
    name VARCHAR2(100) NOT NULL,
    category VARCHAR2(50),
    price NUMBER(10,2) CHECK (price >= 0),
    stock NUMBER DEFAULT 0 CHECK (stock >= 0)
);

-- Index on PRODUCTS
CREATE INDEX idx_products_category ON PRODUCTS(category);

PROMPT Table PRODUCTS created successfully.

-- Table 3: TECHNICIANS
PROMPT Creating table TECHNICIANS...

CREATE TABLE TECHNICIANS (
    technician_id NUMBER PRIMARY KEY,
    name VARCHAR2(100) NOT NULL,
    skill_level VARCHAR2(20) CHECK (skill_level IN ('Junior', 'Mid', 'Senior', 'Expert')),
    availability VARCHAR2(10) DEFAULT 'Available' CHECK (availability IN ('Available', 'Busy', 'Offline'))
);

-- Indexes on TECHNICIANS
CREATE INDEX idx_technicians_availability ON TECHNICIANS(availability);
CREATE INDEX idx_technicians_skill_level ON TECHNICIANS(skill_level);

PROMPT Table TECHNICIANS created successfully.

-- Table 4: SLA_RULES
PROMPT Creating table SLA_RULES...

CREATE TABLE SLA_RULES (
    sla_id NUMBER PRIMARY KEY,
    priority_level VARCHAR2(20) UNIQUE NOT NULL CHECK (priority_level IN ('Low', 'Medium', 'High', 'Critical')),
    resolution_time_hours NUMBER NOT NULL CHECK (resolution_time_hours > 0)
);

PROMPT Table SLA_RULES created successfully.

-- Table 5: SERVICE_REQUESTS
PROMPT Creating table SERVICE_REQUESTS...

CREATE TABLE SERVICE_REQUESTS (
    request_id NUMBER PRIMARY KEY,
    customer_id NUMBER NOT NULL,
    product_id NUMBER,
    issue_type VARCHAR2(50),
    status VARCHAR2(20) DEFAULT 'Open' CHECK (status IN ('Open', 'Assigned', 'In Progress', 'Resolved', 'Closed')),
    priority VARCHAR2(20) DEFAULT 'Medium',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    resolved_at TIMESTAMP,
    CONSTRAINT fk_requests_customer FOREIGN KEY (customer_id) REFERENCES CUSTOMERS(customer_id) ON DELETE CASCADE,
    CONSTRAINT fk_requests_product FOREIGN KEY (product_id) REFERENCES PRODUCTS(product_id) ON DELETE SET NULL,
    CONSTRAINT fk_requests_priority FOREIGN KEY (priority) REFERENCES SLA_RULES(priority_level)
);

-- Indexes on SERVICE_REQUESTS
CREATE INDEX idx_requests_status ON SERVICE_REQUESTS(status);
CREATE INDEX idx_requests_priority ON SERVICE_REQUESTS(priority);
CREATE INDEX idx_requests_created_at ON SERVICE_REQUESTS(created_at);
CREATE INDEX idx_requests_customer_id ON SERVICE_REQUESTS(customer_id);

PROMPT Table SERVICE_REQUESTS created successfully.

-- Table 6: ASSIGNMENTS
PROMPT Creating table ASSIGNMENTS...

CREATE TABLE ASSIGNMENTS (
    assignment_id NUMBER PRIMARY KEY,
    request_id NUMBER NOT NULL UNIQUE,
    technician_id NUMBER NOT NULL,
    assigned_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_assignments_request FOREIGN KEY (request_id) REFERENCES SERVICE_REQUESTS(request_id) ON DELETE CASCADE,
    CONSTRAINT fk_assignments_technician FOREIGN KEY (technician_id) REFERENCES TECHNICIANS(technician_id) ON DELETE SET NULL
);

-- Indexes on ASSIGNMENTS
CREATE INDEX idx_assignments_technician_id ON ASSIGNMENTS(technician_id);
CREATE INDEX idx_assignments_assigned_at ON ASSIGNMENTS(assigned_at);

PROMPT Table ASSIGNMENTS created successfully.

-- Table 7: FEEDBACK
PROMPT Creating table FEEDBACK...

CREATE TABLE FEEDBACK (
    feedback_id NUMBER PRIMARY KEY,
    request_id NUMBER NOT NULL UNIQUE,
    rating NUMBER(2,1) CHECK (rating BETWEEN 1 AND 5),
    remarks VARCHAR2(500),
    submitted_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_feedback_request FOREIGN KEY (request_id) REFERENCES SERVICE_REQUESTS(request_id) ON DELETE CASCADE
);

-- Indexes on FEEDBACK
CREATE INDEX idx_feedback_rating ON FEEDBACK(rating);
-- Note: No need to index request_id as UNIQUE constraint already creates an index

PROMPT Table FEEDBACK created successfully.

-- ============================================================================
-- 1.4 INSERT DEFAULT SLA RULES
-- ============================================================================

PROMPT Inserting default SLA rules...

-- Insert SLA rules only if they don't already exist (using COUNT check for PL/SQL)
DECLARE
    v_count NUMBER;
BEGIN
    SELECT COUNT(*) INTO v_count FROM SLA_RULES WHERE priority_level = 'Low';
    IF v_count = 0 THEN
        INSERT INTO SLA_RULES (sla_id, priority_level, resolution_time_hours) VALUES (seq_sla_id.NEXTVAL, 'Low', 72);
    END IF;
    
    SELECT COUNT(*) INTO v_count FROM SLA_RULES WHERE priority_level = 'Medium';
    IF v_count = 0 THEN
        INSERT INTO SLA_RULES (sla_id, priority_level, resolution_time_hours) VALUES (seq_sla_id.NEXTVAL, 'Medium', 48);
    END IF;
    
    SELECT COUNT(*) INTO v_count FROM SLA_RULES WHERE priority_level = 'High';
    IF v_count = 0 THEN
        INSERT INTO SLA_RULES (sla_id, priority_level, resolution_time_hours) VALUES (seq_sla_id.NEXTVAL, 'High', 24);
    END IF;
    
    SELECT COUNT(*) INTO v_count FROM SLA_RULES WHERE priority_level = 'Critical';
    IF v_count = 0 THEN
        INSERT INTO SLA_RULES (sla_id, priority_level, resolution_time_hours) VALUES (seq_sla_id.NEXTVAL, 'Critical', 4);
    END IF;
    
    COMMIT;
END;
/

PROMPT Default SLA rules inserted successfully.

-- ============================================================================
-- 1.5 VERIFICATION
-- ============================================================================

PROMPT Verifying table creation...

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

PROMPT Phase 1 Complete: All tables, sequences, constraints, and indexes created successfully!
PROMPT Ready for Phase 2: Trigger Implementation.

