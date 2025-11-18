-- ============================================================
--   RUSHMORE PIZZERIA - ROLE-BASED ACCESS CONTROL (RBAC)
--   Security Implementation for Database Access
-- ============================================================

-- =============================
-- 1. CREATE ROLES
-- =============================

-- Admin Role: Full database access
CREATE ROLE rushmore_admin;

-- Manager Role: Read/Write access to operational data
CREATE ROLE rushmore_manager;

-- Staff Role: Limited read/write access
CREATE ROLE rushmore_staff;

-- Analytics Role: Read-only access for reporting
CREATE ROLE rushmore_analytics;

-- Application Role: Programmatic access for applications
CREATE ROLE rushmore_app;

-- =============================
-- 2. GRANT PERMISSIONS
-- =============================

-- ADMIN ROLE: Full privileges
GRANT ALL PRIVILEGES ON DATABASE rushmore_db TO rushmore_admin;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO rushmore_admin;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO rushmore_admin;

-- MANAGER ROLE: Operational access
GRANT CONNECT ON DATABASE rushmore_db TO rushmore_manager;
GRANT SELECT, INSERT, UPDATE, DELETE ON stores, customers, menu_items, ingredients TO rushmore_manager;
GRANT SELECT, INSERT, UPDATE, DELETE ON orders, order_items, item_ingredients TO rushmore_manager;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO rushmore_manager;

-- STAFF ROLE: Limited operational access
GRANT CONNECT ON DATABASE rushmore_db TO rushmore_staff;
GRANT SELECT ON stores, customers, menu_items, ingredients TO rushmore_staff;
GRANT SELECT, INSERT, UPDATE ON orders, order_items TO rushmore_staff;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO rushmore_staff;

-- ANALYTICS ROLE: Read-only access
GRANT CONNECT ON DATABASE rushmore_db TO rushmore_analytics;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO rushmore_analytics;

-- APPLICATION ROLE: Programmatic access
GRANT CONNECT ON DATABASE rushmore_db TO rushmore_app;
GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA public TO rushmore_app;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO rushmore_app;

-- =============================
-- 3. CREATE USERS AND ASSIGN ROLES
-- =============================

-- Database Administrator
CREATE USER db_admin WITH PASSWORD 'SecureAdmin123!';
GRANT rushmore_admin TO db_admin;

-- Store Manager
CREATE USER store_manager WITH PASSWORD 'Manager456!';
GRANT rushmore_manager TO store_manager;

-- Store Staff
CREATE USER store_staff WITH PASSWORD 'Staff789!';
GRANT rushmore_staff TO store_staff;

-- Business Analyst
CREATE USER business_analyst WITH PASSWORD 'Analytics012!';
GRANT rushmore_analytics TO business_analyst;

-- Application Service Account
CREATE USER app_service WITH PASSWORD 'AppService345!';
GRANT rushmore_app TO app_service;

-- =============================
-- 4. ROW LEVEL SECURITY (RLS)
-- =============================

-- Enable RLS on sensitive tables
ALTER TABLE customers ENABLE ROW LEVEL SECURITY;
ALTER TABLE orders ENABLE ROW LEVEL SECURITY;

-- Policy: Staff can only see orders from their store
CREATE POLICY staff_store_orders ON orders
    FOR ALL TO rushmore_staff
    USING (store_id IN (
        SELECT store_id FROM stores 
        WHERE city = current_setting('app.user_store_city', true)
    ));

-- Policy: Managers can see all data
CREATE POLICY manager_all_access ON orders
    FOR ALL TO rushmore_manager
    USING (true);

-- =============================
-- 5. SECURITY FUNCTIONS
-- =============================

-- Function to set user context
CREATE OR REPLACE FUNCTION set_user_context(store_city TEXT)
RETURNS void AS $$
BEGIN
    PERFORM set_config('app.user_store_city', store_city, false);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permission to staff
GRANT EXECUTE ON FUNCTION set_user_context(TEXT) TO rushmore_staff;

-- =============================
-- 6. AUDIT LOGGING
-- =============================

-- Create audit log table
CREATE TABLE audit_log (
    log_id SERIAL PRIMARY KEY,
    table_name VARCHAR(50) NOT NULL,
    operation VARCHAR(10) NOT NULL,
    user_name VARCHAR(100) NOT NULL,
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    old_values JSONB,
    new_values JSONB
);

-- Audit trigger function
CREATE OR REPLACE FUNCTION audit_trigger_function()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'DELETE' THEN
        INSERT INTO audit_log (table_name, operation, user_name, old_values)
        VALUES (TG_TABLE_NAME, TG_OP, current_user, row_to_json(OLD));
        RETURN OLD;
    ELSIF TG_OP = 'UPDATE' THEN
        INSERT INTO audit_log (table_name, operation, user_name, old_values, new_values)
        VALUES (TG_TABLE_NAME, TG_OP, current_user, row_to_json(OLD), row_to_json(NEW));
        RETURN NEW;
    ELSIF TG_OP = 'INSERT' THEN
        INSERT INTO audit_log (table_name, operation, user_name, new_values)
        VALUES (TG_TABLE_NAME, TG_OP, current_user, row_to_json(NEW));
        RETURN NEW;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Create audit triggers
CREATE TRIGGER audit_customers AFTER INSERT OR UPDATE OR DELETE ON customers
    FOR EACH ROW EXECUTE FUNCTION audit_trigger_function();

CREATE TRIGGER audit_orders AFTER INSERT OR UPDATE OR DELETE ON orders
    FOR EACH ROW EXECUTE FUNCTION audit_trigger_function();

-- ============================================================
-- END OF RBAC CONFIGURATION
-- ============================================================