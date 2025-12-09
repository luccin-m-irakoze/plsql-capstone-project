# CRM Database System - PL/SQL Practicum
## Project Documentation

### Project Overview
**Title**: CRM Database System – PL/SQL Practicum  
**Organization**: Vision Technologies Company (IT services + product sales)  
**Environment**: Oracle SQL Developer 24.3  
**Database**: PDB lu_plsqlauca_25815  
**Scope**: Database-side implementation (schemas, PL/SQL logic, automation)

---

## 1. Database Schema

### 1.1 Schema Diagram

```
CUSTOMERS (customer_id PK, name, contact, company, tier)
    │
    │ (1:N)
    │
    ▼
SERVICE_REQUESTS (request_id PK, customer_id FK, product_id FK, issue_type, 
                  status, priority FK, created_at, resolved_at)
    │
    ├──► (1:1) ASSIGNMENTS (assignment_id PK, request_id FK, technician_id FK, assigned_at)
    │                 │
    │                 │ (N:1)
    │                 │
    │                 ▼
    │         TECHNICIANS (technician_id PK, name, skill_level, availability)
    │
    ├──► (1:1) FEEDBACK (feedback_id PK, request_id FK, rating, remarks, submitted_at)
    │
    │ (N:1)
    │
    ▼
PRODUCTS (product_id PK, name, category, price, stock)

SERVICE_REQUESTS.priority ──► (N:1) SLA_RULES (sla_id PK, priority_level UK, resolution_time_hours)
```
###1.1.1 ERD Diagram



### 1.2 Table Descriptions

#### CUSTOMERS
Stores customer information for Vision Technologies Company.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| customer_id | NUMBER | PRIMARY KEY | Unique customer identifier |
| name | VARCHAR2(100) | NOT NULL | Customer name |
| contact | VARCHAR2(50) | | Email or phone contact |
| company | VARCHAR2(100) | | Company name |
| tier | VARCHAR2(20) | CHECK | Customer tier: Bronze, Silver, Gold, Platinum |

**Indexes**: `idx_customers_tier`, `idx_customers_company`

#### PRODUCTS
Stores product catalog for sales.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| product_id | NUMBER | PRIMARY KEY | Unique product identifier |
| name | VARCHAR2(100) | NOT NULL | Product name |
| category | VARCHAR2(50) | | Product category |
| price | NUMBER(10,2) | CHECK >= 0 | Product price |
| stock | NUMBER | DEFAULT 0, CHECK >= 0 | Available stock quantity |

**Indexes**: `idx_products_category`

#### TECHNICIANS
Stores technician information and availability.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| technician_id | NUMBER | PRIMARY KEY | Unique technician identifier |
| name | VARCHAR2(100) | NOT NULL | Technician name |
| skill_level | VARCHAR2(20) | CHECK | Skill level: Junior, Mid, Senior, Expert |
| availability | VARCHAR2(10) | DEFAULT 'Available', CHECK | Status: Available, Busy, Offline |

**Indexes**: `idx_technicians_availability`, `idx_technicians_skill_level`

#### SLA_RULES
Defines Service Level Agreement rules for each priority level.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| sla_id | NUMBER | PRIMARY KEY | Unique SLA rule identifier |
| priority_level | VARCHAR2(20) | UNIQUE, NOT NULL, CHECK | Priority: Low, Medium, High, Critical |
| resolution_time_hours | NUMBER | NOT NULL, CHECK > 0 | Hours allowed for resolution |

**Default Data**:
- Low: 72 hours
- Medium: 48 hours
- High: 24 hours
- Critical: 4 hours

#### SERVICE_REQUESTS
Core table storing service requests/tickets.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| request_id | NUMBER | PRIMARY KEY | Unique request identifier |
| customer_id | NUMBER | NOT NULL, FK | Reference to CUSTOMERS |
| product_id | NUMBER | FK | Reference to PRODUCTS (nullable) |
| issue_type | VARCHAR2(50) | | Description of the issue |
| status | VARCHAR2(20) | DEFAULT 'Open', CHECK | Status: Open, Assigned, In Progress, Resolved, Closed |
| priority | VARCHAR2(20) | DEFAULT 'Medium', FK | Reference to SLA_RULES |
| created_at | TIMESTAMP | DEFAULT CURRENT_TIMESTAMP | Request creation timestamp |
| resolved_at | TIMESTAMP | | Resolution timestamp |

**Indexes**: `idx_requests_status`, `idx_requests_priority`, `idx_requests_created_at`, `idx_requests_customer_id`

#### ASSIGNMENTS
Links service requests to technicians.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| assignment_id | NUMBER | PRIMARY KEY | Unique assignment identifier |
| request_id | NUMBER | NOT NULL, UNIQUE, FK | Reference to SERVICE_REQUESTS (one per request) |
| technician_id | NUMBER | NOT NULL, FK | Reference to TECHNICIANS |
| assigned_at | TIMESTAMP | DEFAULT CURRENT_TIMESTAMP | Assignment timestamp |

**Indexes**: `idx_assignments_technician_id`, `idx_assignments_assigned_at`

#### FEEDBACK
Stores customer feedback for resolved requests.

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| feedback_id | NUMBER | PRIMARY KEY | Unique feedback identifier |
| request_id | NUMBER | NOT NULL, UNIQUE, FK | Reference to SERVICE_REQUESTS (one per request) |
| rating | NUMBER(2,1) | CHECK 1-5 | Customer rating (1.0 to 5.0) |
| remarks | VARCHAR2(500) | | Customer comments |
| submitted_at | TIMESTAMP | DEFAULT CURRENT_TIMESTAMP | Feedback submission timestamp |

**Indexes**: `idx_feedback_rating`, `idx_feedback_request_id`

---

## 2. PL/SQL Components

### 2.1 Triggers

#### TRG_AUTO_ASSIGN_TECHNICIAN

**Type**: COMPOUND TRIGGER

**Note**: This trigger uses a **Compound Trigger** design pattern to avoid Oracle's mutating table restrictions. The trigger is split into two sections that execute at different times during the INSERT statement.
**Event**: AFTER INSERT on SERVICE_REQUESTS  
**Condition**: WHEN (NEW.status = 'Open')

**Functionality**:
- Automatically assigns an available technician based on:
  1. Skill level matching (priority-based mapping: Low→Junior, Medium→Mid, High→Senior, Critical→Expert)
  2. Current workload (minimum active assignments)
  3. Availability status
- Creates assignment record
- Updates request status to 'Assigned'
- Updates technician availability to 'Busy' if workload threshold (5 assignments) reached

**Algorithm**:
- Selects technician with matching or higher skill level
- Prioritizes technicians with fewer active assignments
- Creates assignment record in ASSIGNMENTS table
- Updates request status to 'Assigned' (after INSERT completes via AFTER STATEMENT section)

**Implementation Details**:
- **Compound Trigger Structure**: 
  - `AFTER EACH ROW`: Finds technician, creates assignment (avoids mutating SERVICE_REQUESTS)
  - `AFTER STATEMENT`: Updates SERVICE_REQUESTS status and technician availability (safe)
- **Why Compound Trigger**: Oracle prevents triggers from modifying the table they fire on. This pattern defers the UPDATE until the INSERT statement completes.

#### TRG_UPDATE_STATUS_ON_FEEDBACK
**Event**: AFTER INSERT on FEEDBACK

**Functionality**:
- Updates SERVICE_REQUESTS status to 'Closed'
- Sets resolved_at timestamp if not already set
- Updates TECHNICIANS availability to 'Available' if no other active assignments exist

---

### 2.2 Standalone Procedures

#### PROC_ESCALATE_OVERDUE_TICKETS
**Purpose**: Identify and escalate requests violating SLA

**Parameters**:
- `p_escalated_count` (OUT NUMBER): Number of tickets escalated

**Logic**:
- Finds requests where elapsed time > resolution_time_hours from SLA_RULES
- Escalates priority: Low→Medium, Medium→High, High→Critical
- Updates priority in SERVICE_REQUESTS
- Returns count of escalated tickets

**Usage**:
```sql
DECLARE
    v_count NUMBER;
BEGIN
    PROC_ESCALATE_OVERDUE_TICKETS(v_count);
    DBMS_OUTPUT.PUT_LINE('Escalated: ' || v_count);
END;
/
```

#### PROC_GENERATE_WEEKLY_REPORT
**Purpose**: Generate comprehensive weekly statistics

**Parameters**:
- `p_start_date` (DATE, DEFAULT NULL): Start date (default: 7 days ago)
- `p_end_date` (DATE, DEFAULT NULL): End date (default: today)

**Output** (via DBMS_OUTPUT):
- Total requests by status
- Requests by priority distribution
- Average resolution time per priority
- Technician workload summary
- Customer satisfaction metrics

**Usage**:
```sql
BEGIN
    PROC_GENERATE_WEEKLY_REPORT; -- Last 7 days
    -- OR
    PROC_GENERATE_WEEKLY_REPORT(SYSDATE - 14, SYSDATE); -- Last 14 days
END;
/
```

---

### 2.3 Packages

#### PKG_TICKET_MANAGEMENT

**FUNC_CREATE_REQUEST**
- **Parameters**: `p_customer_id`, `p_product_id`, `p_issue_type`, `p_priority` (default 'Medium')
- **Returns**: `request_id` (NUMBER)
- **Functionality**: Creates new service request with validation

**FUNC_UPDATE_STATUS**
- **Parameters**: `p_request_id`, `p_status`
- **Returns**: BOOLEAN
- **Functionality**: Updates request status, sets resolved_at if status is Resolved/Closed

**PROC_REASSIGN_TICKET**
- **Parameters**: `p_request_id`, `p_technician_id`
- **Functionality**: Reassigns ticket to different technician, creates assignment if none exists

**PROC_CLOSE_REQUEST**
- **Parameters**: `p_request_id`, `p_resolution_notes` (optional)
- **Functionality**: Closes request with resolution notes

**Usage Example**:
```sql
DECLARE
    v_request_id NUMBER;
BEGIN
    v_request_id := PKG_TICKET_MANAGEMENT.FUNC_CREATE_REQUEST(
        1, 1, 'System crash', 'High'
    );
    PKG_TICKET_MANAGEMENT.FUNC_UPDATE_STATUS(v_request_id, 'In Progress');
END;
/
```

#### PKG_SLA_MONITORING

**FUNC_CHECK_SLA_COMPLIANCE**
- **Parameters**: `p_request_id`
- **Returns**: VARCHAR2 ('compliant', 'at_risk', 'violated')
- **Functionality**: Checks if request is within SLA (at_risk if >=80% time used)

**FUNC_GET_REMAINING_TIME**
- **Parameters**: `p_request_id`
- **Returns**: NUMBER (hours remaining, negative if violated)
- **Functionality**: Calculates hours remaining until SLA deadline

**PROC_ESCALATE_OVERDUE_TICKETS**
- **Parameters**: `p_escalated_count` (OUT NUMBER)
- **Functionality**: Same as standalone procedure (consolidated in package)

**PROC_MONITOR_ACTIVE_REQUESTS**
- **Parameters**: None
- **Functionality**: Outputs list of requests at risk or violated with details

**Usage Example**:
```sql
DECLARE
    v_status VARCHAR2(20);
    v_hours NUMBER;
BEGIN
    v_status := PKG_SLA_MONITORING.FUNC_CHECK_SLA_COMPLIANCE(1);
    v_hours := PKG_SLA_MONITORING.FUNC_GET_REMAINING_TIME(1);
    PKG_SLA_MONITORING.PROC_MONITOR_ACTIVE_REQUESTS;
END;
/
```

#### PKG_REPORTING

**FUNC_AVG_RESOLUTION_TIME**
- **Parameters**: `p_technician_id`, `p_start_date` (optional), `p_end_date` (optional)
- **Returns**: NUMBER (average hours)
- **Functionality**: Calculates average resolution time for technician

**FUNC_CUSTOMER_SATISFACTION_SCORE**
- **Parameters**: `p_customer_id` (optional, NULL for overall average)
- **Returns**: NUMBER (1.00 to 5.00)
- **Functionality**: Computes average customer satisfaction rating

**PROC_GENERATE_WEEKLY_REPORT**
- Same as standalone procedure (consolidated in package)

**PROC_TECHNICIAN_PERFORMANCE_REPORT**
- **Parameters**: `p_technician_id`
- **Functionality**: Generates detailed performance report for technician

**PROC_CUSTOMER_ANALYTICS**
- **Parameters**: `p_customer_id`
- **Functionality**: Generates analytics report for customer

**Usage Example**:
```sql
BEGIN
    PKG_REPORTING.PROC_TECHNICIAN_PERFORMANCE_REPORT(1);
    PKG_REPORTING.PROC_CUSTOMER_ANALYTICS(1);
END;
/
```

---

### 2.4 Standalone Functions

#### FUNC_AVG_RESOLUTION_TIME_PER_TECHNICIAN
**Parameters**: 
- `p_technician_id` (NUMBER)
- `p_start_date` (DATE, optional, default: 30 days ago)
- `p_end_date` (DATE, optional, default: today)

**Returns**: NUMBER (average hours)

**Functionality**: Calculates average resolution time for technician in specified period

#### FUNC_COMPUTE_CUSTOMER_SATISFACTION_SCORE
**Parameters**: 
- `p_customer_id` (NUMBER, optional, NULL for overall average)

**Returns**: NUMBER(3,2) (1.00 to 5.00)

**Functionality**: Computes average satisfaction score from feedback ratings

---

## 3. Security Model

### 3.1 Roles

#### CRM_ADMIN
**Privileges**: Full access to all tables and PL/SQL objects
- SELECT, INSERT, UPDATE, DELETE on all tables
- EXECUTE on all procedures, functions, and packages
- Full sequence access

#### CRM_MANAGER
**Privileges**: Read/write access to operational tables and management procedures
- SELECT, INSERT, UPDATE on CUSTOMERS, SERVICE_REQUESTS, ASSIGNMENTS, FEEDBACK
- SELECT on PRODUCTS, TECHNICIANS, SLA_RULES
- EXECUTE on management and reporting packages

#### CRM_TECHNICIAN
**Privileges**: Read requests, update own assignments and status
- SELECT on all tables
- UPDATE on SERVICE_REQUESTS (status updates)
- UPDATE on ASSIGNMENTS
- EXECUTE on PKG_TICKET_MANAGEMENT

#### CRM_CUSTOMER
**Privileges**: Read own requests, submit feedback
- SELECT on CUSTOMERS, PRODUCTS, SERVICE_REQUESTS, FEEDBACK
- INSERT on FEEDBACK

#### CRM_ANALYST
**Privileges**: Read-only access for reporting and analytics
- SELECT on all tables
- EXECUTE on reporting procedures and functions

### 3.2 Granting Roles

To assign a role to a user:
```sql
GRANT CRM_MANAGER TO username;
```

---

## 4. Testing Procedures

### 4.1 Test Data Population
Script `07_test_data.sql` includes:
- 12 customers (various tiers)
- 9 products (multiple categories)
- 6 technicians (various skill levels)
- 15+ service requests (various statuses, priorities, dates)
- Multiple assignments
- 5 feedback records

### 4.2 Test Scenarios
Script `07_test_scenarios.sql` includes:

1. **SLA Violation Simulation**: Creates overdue requests and tests escalation
2. **Feedback Integration Test**: Verifies automatic status updates
3. **End-to-End Workflow Test**: Complete workflow from customer creation to feedback
4. **Function Validation**: Tests calculation functions
5. **SLA Compliance Checking**: Validates SLA monitoring functions

### 4.3 Running Tests

Execute test scripts in order:
```sql
@07_test_data.sql
@07_test_scenarios.sql
```

---

## 5. Usage Examples

### 5.1 Creating a New Service Request
```sql
DECLARE
    v_request_id NUMBER;
BEGIN
    v_request_id := PKG_TICKET_MANAGEMENT.FUNC_CREATE_REQUEST(
        p_customer_id => 1,
        p_product_id => 1,
        p_issue_type => 'Server down',
        p_priority => 'Critical'
    );
    DBMS_OUTPUT.PUT_LINE('Request created: ' || v_request_id);
END;
/
```

### 5.2 Checking SLA Compliance
```sql
SELECT request_id, priority,
       PKG_SLA_MONITORING.FUNC_CHECK_SLA_COMPLIANCE(request_id) AS compliance,
       PKG_SLA_MONITORING.FUNC_GET_REMAINING_TIME(request_id) AS hours_remaining
FROM SERVICE_REQUESTS
WHERE status NOT IN ('Closed', 'Resolved');
```

### 5.3 Generating Reports
```sql
-- Weekly report
BEGIN
    PKG_REPORTING.PROC_GENERATE_WEEKLY_REPORT;
END;
/

-- Technician performance
BEGIN
    PKG_REPORTING.PROC_TECHNICIAN_PERFORMANCE_REPORT(1);
END;
/

-- Customer analytics
BEGIN
    PKG_REPORTING.PROC_CUSTOMER_ANALYTICS(1);
END;
/
```

### 5.4 Escalating Overdue Tickets
```sql
DECLARE
    v_count NUMBER;
BEGIN
    PKG_SLA_MONITORING.PROC_ESCALATE_OVERDUE_TICKETS(v_count);
    DBMS_OUTPUT.PUT_LINE('Escalated tickets: ' || v_count);
END;
/
```

---

## 6. Best Practices

1. **Modularity**: Code organized into packages for related functionality
2. **Error Handling**: All procedures/functions include exception handling
3. **Naming Conventions**: 
   - Procedures: `PROC_*`
   - Functions: `FUNC_*`
   - Triggers: `TRG_*`
   - Packages: `PKG_*`
4. **Comments**: All PL/SQL objects include header comments
5. **Constraints**: CHECK constraints and foreign keys enforce data integrity
6. **Indexes**: Strategic indexes on foreign keys and frequently queried columns

---

## 7. Maintenance

### 7.1 Regular Tasks
- Run `PROC_ESCALATE_OVERDUE_TICKETS` periodically (suggested: hourly or via scheduled job)
- Generate weekly reports using `PROC_GENERATE_WEEKLY_REPORT`
- Monitor SLA compliance using `PROC_MONITOR_ACTIVE_REQUESTS`

### 7.2 Scheduled Jobs (Optional)
Create DBMS_SCHEDULER jobs for:
- Automatic escalation: Run hourly
- Weekly reports: Run every Monday

Example:
```sql
BEGIN
    DBMS_SCHEDULER.CREATE_JOB(
        job_name => 'CRM_ESCALATION_JOB',
        job_type => 'PLSQL_BLOCK',
        job_action => 'BEGIN PKG_SLA_MONITORING.PROC_ESCALATE_OVERDUE_TICKETS(NULL); END;',
        start_date => SYSTIMESTAMP,
        repeat_interval => 'FREQ=HOURLY',
        enabled => TRUE
    );
END;
/
```

---

## 8. File Structure

```
Final Project/
├── 00_master_script.sql          (orchestrates all scripts)
├── 01_create_tables.sql          (schema creation)
├── 02_triggers.sql               (auto-assignment, feedback triggers)
├── 03_procedures.sql             (escalation, reporting - before packaging)
├── 04_package_ticket_mgmt.sql    (ticket management package)
├── 04_package_sla_monitor.sql    (SLA monitoring package)
├── 04_package_reporting.sql      (reporting package)
├── 05_functions.sql              (standalone functions)
├── 06_security.sql               (roles, grants, privileges)
├── 07_test_data.sql              (sample data inserts)
├── 07_test_scenarios.sql         (test cases and validation)
├── 08_documentation.md           (this file)
├── 99_rollback_all.sql           (cleanup script for reinstall)
├── ERRORS_AND_FIXES_COMPLETE.md  (complete error history and solutions)
└── QUICK_TEST.sql                (test queries with correct syntax)
```

---

## 9. Troubleshooting

### Common Issues

1. **Auto-assignment not working**: 
   - Check if technicians exist and are available
   - Verify trigger is ENABLED: `SELECT trigger_name, status FROM user_triggers WHERE trigger_name = 'TRG_AUTO_ASSIGN_TECHNICIAN';`
   - Note: Uses compound trigger pattern to avoid mutating table errors

2. **Trigger errors**: 
   - All triggers use compound trigger pattern for complex operations
   - Verify table dependencies are created in correct order
   - Check trigger status: `SELECT trigger_name, status, trigger_type FROM user_triggers;`

3. **SLA calculation incorrect**: 
   - Check SLA_RULES table has correct data: `SELECT * FROM SLA_RULES;`
   - Verify 4 rows exist (Low, Medium, High, Critical)

4. **Object already exists errors**: 
   - Run rollback script: `@99_rollback_all.sql`
   - Or rerun master script (includes automatic cleanup)

5. **Role creation errors**: 
   - Expected if you don't have DBA privileges
   - System functions without roles - this is normal
   - See `ERRORS_AND_FIXES_COMPLETE.md` for details

### Error Resolution

For complete error documentation and fixes, see: **`ERRORS_AND_FIXES_COMPLETE.md`**

**Quick Reference**:
- **ORA-04091 (Mutating Table)**: ✅ Fixed with compound trigger
- **ORA-00955 (Object Exists)**: ✅ Fixed with automatic drop logic  
- **PLS-00204 (EXISTS Error)**: ✅ Fixed by using COUNT(*) pattern
- **ORA-01917 (Role Doesn't Exist)**: ⚠️ Expected for non-DBA users

### Verification Queries

```sql
-- Check table counts
SELECT 'CUSTOMERS' AS table_name, COUNT(*) FROM CUSTOMERS
UNION ALL SELECT 'PRODUCTS', COUNT(*) FROM PRODUCTS
UNION ALL SELECT 'TECHNICIANS', COUNT(*) FROM TECHNICIANS
UNION ALL SELECT 'SERVICE_REQUESTS', COUNT(*) FROM SERVICE_REQUESTS;

-- Check trigger status
SELECT trigger_name, status FROM user_triggers;

-- Check package status
SELECT object_name, object_type, status FROM user_objects 
WHERE object_type IN ('PACKAGE', 'PACKAGE BODY');
```

---

## 10. Recent Updates and Implementation Improvements

### Version 2.0 Updates

**Compound Trigger Implementation**:
- `TRG_AUTO_ASSIGN_TECHNICIAN` converted to compound trigger (Oracle 11g+)
- Resolved ORA-04091 mutating table errors
- Follows Oracle best practices for complex trigger scenarios

**Error Handling Enhancements**:
- Comprehensive exception handling throughout all scripts
- Graceful degradation when DBA privileges unavailable
- Idempotent scripts allow safe reruns

**Clean Installation Process**:
- Automatic object cleanup in schema creation scripts
- Robust rollback script for complete system removal
- Master script orchestrates entire installation seamlessly

**Testing and Verification**:
- `QUICK_TEST.sql` provides properly formatted test queries
- All test data loads successfully with auto-assignment working
- Complete system validation queries included

**Documentation**:
- Comprehensive error history: `ERRORS_AND_FIXES_COMPLETE.md`
- Updated troubleshooting guide with common issues
- Technical implementation notes for advanced scenarios

---

## 11. Future Enhancements

Potential improvements:
1. Row-level security for customer/technician data access
2. Audit table for tracking changes
3. Email notifications on escalation
4. Dashboard views for reporting
5. Advanced workload balancing algorithms
6. Integration with external systems

---

**End of Documentation**

For complete error history and troubleshooting, see: `ERRORS_AND_FIXES_COMPLETE.md`



