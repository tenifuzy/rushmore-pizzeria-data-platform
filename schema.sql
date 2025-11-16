
-- ============================================================
--   RUSHMORE PIZZERIA - DATABASE SCHEMA (PostgreSQL)
--   Part 1: Database Modelling (Design)
--   Author: <Your Name>
--   Date: <Insert Date>
-- ============================================================


-- =============================
-- 1. STORES TABLE
-- =============================
CREATE TABLE stores (
    store_id SERIAL PRIMARY KEY,
    address VARCHAR(255) NOT NULL,
    city VARCHAR(100) NOT NULL,
    phone_number VARCHAR(50) UNIQUE NOT NULL,
    opened_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);


-- =============================
-- 2. CUSTOMERS TABLE
-- =============================
CREATE TABLE customers (
    customer_id SERIAL PRIMARY KEY,
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    phone_number VARCHAR(20) UNIQUE NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);


-- =============================
-- 3. INGREDIENTS TABLE
-- =============================
CREATE TABLE ingredients (
    ingredient_id SERIAL PRIMARY KEY,
    name VARCHAR(100) UNIQUE NOT NULL,
    stock_quantity NUMERIC(10,2) NOT NULL DEFAULT 0,
    unit VARCHAR(20) NOT NULL
);


-- =============================
-- 4. MENU ITEMS TABLE
-- =============================
CREATE TABLE menu_items (
    item_id SERIAL PRIMARY KEY,
    name VARCHAR(150) NOT NULL,
    category VARCHAR(50) NOT NULL,
    size VARCHAR(20)
);


-- =============================
-- 5. ITEM_INGREDIENTS (Many-to-Many)
-- =============================
CREATE TABLE item_ingredients (
    item_ingredient_id SERIAL PRIMARY KEY,
    item_id INTEGER REFERENCES menu_items(item_id) ON DELETE CASCADE,
    ingredient_id INTEGER REFERENCES ingredients(ingredient_id) ON DELETE CASCADE,
    quantity_required NUMERIC(10,2) NOT NULL
);


-- =============================
-- 6. ORDERS TABLE
-- =============================
CREATE TABLE orders (
    order_id SERIAL PRIMARY KEY,
    customer_id INTEGER REFERENCES customers(customer_id) ON DELETE SET NULL,
    store_id INTEGER REFERENCES stores(store_id) ON DELETE RESTRICT,
    order_timestamp TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    total_amount NUMERIC(10,2) NOT NULL
);


-- =============================
-- 7. ORDER ITEMS TABLE
-- =============================
CREATE TABLE order_items (
    order_item_id SERIAL PRIMARY KEY,
    order_id INTEGER REFERENCES orders(order_id) ON DELETE CASCADE,
    item_id INTEGER REFERENCES menu_items(item_id) ON DELETE RESTRICT,
    quantity INTEGER NOT NULL,
    price_at_time_of_order NUMERIC(10,2) NOT NULL
);


-- =============================
-- OPTIONAL INDEXES (Recommended)
-- =============================
CREATE INDEX idx_orders_store_ts ON orders (store_id, order_timestamp);
CREATE INDEX idx_orders_customer ON orders (customer_id);
CREATE INDEX idx_order_items_item_id ON order_items (item_id);


-- ============================================================
-- END OF SCHEMA
-- ============================================================
