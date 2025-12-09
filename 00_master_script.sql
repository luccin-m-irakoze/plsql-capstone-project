-- ============================================================================
-- CRM Database System - Master Execution Script
-- Oracle SQL Developer 24.3
-- Target PDB: lu_plsqlauca_25815
-- 
-- This script orchestrates the complete CRM database system implementation.
-- Execute all phases in order by running this master script.
-- 
-- Execution Order:
--   1. Schema Creation (tables, sequences, constraints, indexes)
--   2. Trigger Implementation (auto-assignment, feedback status updates)
--   3. Procedure Implementation (escalation, reporting)
--   4. Package Implementation (ticket management, SLA monitoring, reporting)
--   5. Function Implementation (resolution time, satisfaction score)
--   6. Security Implementation (roles, grants, privileges)
--   7. Test Data and Scenarios (sample data, validation tests)
-- ============================================================================

SET DEFINE OFF;
SET SERVEROUTPUT ON;
PROMPT ============================================================================
PROMPT CRM DATABASE SYSTEM - MASTER EXECUTION SCRIPT
PROMPT ============================================================================
PROMPT Target PDB: lu_plsqlauca_25815
PROMPT Oracle SQL Developer 24.3
PROMPT ============================================================================
PROMPT Starting execution...
PROMPT ============================================================================
PROMPT

-- ============================================================================
-- PHASE 1: Schema Creation
-- ============================================================================
PROMPT ============================================================================
PROMPT PHASE 1: Schema Creation
PROMPT ============================================================================
@01_create_tables.sql

-- ============================================================================
-- PHASE 2: Trigger Implementation
-- ============================================================================
PROMPT ============================================================================
PROMPT PHASE 2: Trigger Implementation
PROMPT ============================================================================
@02_triggers.sql

-- ============================================================================
-- PHASE 3: Procedure Implementation
-- ============================================================================
PROMPT ============================================================================
PROMPT PHASE 3: Procedure Implementation
PROMPT ============================================================================
@03_procedures.sql

-- ============================================================================
-- PHASE 4: Package Implementation
-- ============================================================================
PROMPT ============================================================================
PROMPT PHASE 4: Package Implementation
PROMPT ============================================================================
PROMPT 4.1: Ticket Management Package...
@04_package_ticket_mgmt.sql

PROMPT 4.2: SLA Monitoring Package...
@04_package_sla_monitor.sql

PROMPT 4.3: Reporting Package...
@04_package_reporting.sql

-- ============================================================================
-- PHASE 5: Function Implementation
-- ============================================================================
PROMPT ============================================================================
PROMPT PHASE 5: Function Implementation
PROMPT ============================================================================
@05_functions.sql

-- ============================================================================
-- PHASE 6: Security Implementation
-- ============================================================================
PROMPT ============================================================================
PROMPT PHASE 6: Security Implementation
PROMPT ============================================================================
@06_security.sql

-- ============================================================================
-- PHASE 7: Testing and Validation
-- ============================================================================
PROMPT ============================================================================
PROMPT PHASE 7: Testing and Validation
PROMPT ============================================================================
PROMPT 7.1: Test Data Population...
@07_test_data.sql

PROMPT 7.2-7.4: Test Scenarios...
@07_test_scenarios.sql

-- ============================================================================
-- COMPLETION SUMMARY
-- ============================================================================
PROMPT ============================================================================
PROMPT EXECUTION COMPLETE
PROMPT ============================================================================
PROMPT
PROMPT All phases have been executed successfully!
PROMPT
PROMPT System Summary:
PROMPT   - 7 Tables created (CUSTOMERS, PRODUCTS, TECHNICIANS, SLA_RULES,
PROMPT     SERVICE_REQUESTS, ASSIGNMENTS, FEEDBACK)
PROMPT   - 7 Sequences created
PROMPT   - 2 Triggers implemented (auto-assignment, feedback status update)
PROMPT   - 2 Standalone procedures created (escalation, weekly report)
PROMPT   - 3 Packages created (ticket management, SLA monitoring, reporting)
PROMPT   - 2 Standalone functions created (resolution time, satisfaction score)
PROMPT   - 5 Security roles created (CRM_ADMIN, CRM_MANAGER, CRM_TECHNICIAN,
PROMPT     CRM_CUSTOMER, CRM_ANALYST)
PROMPT   - Test data and scenarios executed
PROMPT
PROMPT Next Steps:
PROMPT   1. Review the documentation (08_documentation.md)
PROMPT   2. Verify test results in the output above
PROMPT   3. Assign roles to users as needed
PROMPT   4. Begin using the CRM system!
PROMPT
PROMPT ============================================================================

