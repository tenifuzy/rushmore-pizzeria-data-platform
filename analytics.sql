-- analytics.sql
-- RushMore Pizzeria - Analytics Queries (Part 5)

---------------------------------------------------------
-- 1. Total sales revenue per store
---------------------------------------------------------
SELECT
  s.store_id,
  s.address,
  s.city,
  COALESCE(SUM(o.total_amount), 0) AS total_sales
FROM stores s
LEFT JOIN orders o ON s.store_id = o.store_id
GROUP BY s.store_id, s.address, s.city
ORDER BY total_sales DESC;

---------------------------------------------------------
-- 2. Top 10 most valuable customers (by total spending)
---------------------------------------------------------
SELECT
  c.customer_id,
  c.first_name || ' ' || c.last_name AS customer_name,
  c.email,
  COALESCE(SUM(o.total_amount), 0) AS total_spent,
  COUNT(o.order_id) AS num_orders
FROM customers c
LEFT JOIN orders o ON c.customer_id = o.customer_id
GROUP BY c.customer_id, customer_name, c.email
ORDER BY total_spent DESC
LIMIT 10;

---------------------------------------------------------
-- 3. Most popular menu item by quantity sold
---------------------------------------------------------
SELECT
  mi.item_id,
  mi.name,
  mi.category,
  SUM(oi.quantity) AS total_qty_sold
FROM menu_items mi
JOIN order_items oi ON mi.item_id = oi.item_id
GROUP BY mi.item_id, mi.name, mi.category
ORDER BY total_qty_sold DESC
LIMIT 1;

---------------------------------------------------------
-- 4. Average order value
---------------------------------------------------------
SELECT
  ROUND(AVG(total_amount)::numeric, 2) AS avg_order_value,
  COUNT(order_id) AS total_orders
FROM orders;

---------------------------------------------------------
-- 5. Busiest hours of the day for orders
---------------------------------------------------------
SELECT
  EXTRACT(HOUR FROM order_timestamp) AS hour_of_day,
  COUNT(*) AS orders_count
FROM orders
GROUP BY hour_of_day
ORDER BY orders_count DESC;
