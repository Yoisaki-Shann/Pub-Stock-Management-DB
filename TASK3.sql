-- Set the search path to the Pub_Stock_Management schema
SET search_path TO Pub_Stock_Management;
-- Q1 Non-correlated subquery
SELECT product_name
FROM Products
WHERE product_id NOT IN (
SELECT product_id
FROM Order_Details
);

-- Q2 Correlated subquery
SELECT p.product_name
FROM Products p
WHERE EXISTS (
SELECT 1
FROM Order_Details od
WHERE od.product_id = p.product_id
AND od.quantity > 50
);

-- Q3 CTE (WITH) QUERY
WITH order_totals AS (
SELECT
oi.order_id,
SUM(oi.quantity * oi.unit_price) AS order_total
FROM Order_Details oi
GROUP BY oi.order_id
)
SELECT o.order_id, o.order_date, o.status, ot.order_total
FROM Orders o
JOIN order_totals ot ON ot.order_id = o.order_id
ORDER BY ot.order_total DESC
LIMIT 5;

-- Q4 Window Function
SELECT product_name,
price,
RANK() OVER (ORDER BY price DESC) AS price_rank
FROM Products;

-- Q5 One additional Window Function query
SELECT product_name,
category,
price,
RANK() OVER (
PARTITION BY category
ORDER BY price DESC
) AS category_rank
FROM Products
ORDER BY category, category_rank;

-- Q6 Business Insight Query
SELECT p.product_name,
SUM(od.quantity) AS total_quantity_ordered
FROM Order_Details od
JOIN Products p ON p.product_id = od.product_id
GROUP BY p.product_name
ORDER BY total_quantity_ordered DESC
LIMIT 5;

-- Q7 stored procedure/function
CREATE OR REPLACE PROCEDURE update_product_price(
p_product_id INT,
p_new_price NUMERIC(10,2)
)
LANGUAGE plpgsql
AS $$
BEGIN
IF p_new_price IS NULL OR p_new_price <= 0 THEN
RAISE EXCEPTION 'New price must be > 0. Got: %', p_new_price;
END IF;
UPDATE products
SET price = p_new_price
WHERE product_id = p_product_id;
IF NOT FOUND THEN
RAISE EXCEPTION 'No product found with product_id = %', p_product_id;
END IF;
END;
$$;
-- calling the stored procedure
SELECT product_id, product_name, price FROM products WHERE product_id = 1;
CALL update_product_price(1, 10.99);
SELECT product_id, product_name, price FROM products WHERE product_id = 1;

-- Q8 Trigger
-- Create a table to store price change history
CREATE TABLE price_change_history (
    history_id SERIAL PRIMARY KEY,
    product_id INT,
    old_price NUMERIC,
    new_price NUMERIC,
    changed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
-- Create a trigger function
CREATE OR REPLACE FUNCTION log_price_change()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO price_change_history(product_id, old_price, new_price)
    VALUES (OLD.product_id, OLD.price, NEW.price);

    RETURN NEW;
END;
$$;
-- Create a trigger
CREATE TRIGGER trigger_price_updates
AFTER UPDATE ON products
FOR EACH ROW
WHEN (OLD.price IS DISTINCT FROM NEW.price)
EXECUTE FUNCTION log_price_change();
-- Testing the trigger
UPDATE products
SET price = 12.99
WHERE product_id = 1;
SELECT * FROM price_change_history;

-- Q9 Transaction begin, commit and rollback
BEGIN;
UPDATE products
SET price = 15.99
WHERE product_id = 1;
COMMIT;

BEGIN;
UPDATE products
SET price = 14.99
WHERE product_id = 1;
ROLLBACK;
-- checking the transaction
SELECT product_id, price
FROM Products
WHERE product_id = 1;

-- Q10 Recovery
-- Database Recovery is the process of restoring the database to a previous state before a failure occurred.

-- Q11 Performance tuning
-- 1. 
EXPLAIN ANALYZE
SELECT *
FROM Order_Details
WHERE product_id = 1;
-- 2. Add index and compare EXPLAIN ANALYZE
CREATE INDEX idx_product_id ON Order_Details(product_id);
-- 3. 
EXPLAIN ANALYZE
SELECT *
FROM Order_Details
WHERE product_id = 1;

-- Q12 Roles

-- Allow the roles to enter the Pub_Stock_Management schema
GRANT USAGE ON SCHEMA Pub_Stock_Management TO admin, staff;

-- Admin role
CREATE ROLE admin LOGIN PASSWORD 'admin123';
GRANT SELECT ON Employee TO admin;

-- Staff role
CREATE ROLE staff LOGIN PASSWORD 'staff123';
GRANT SELECT, INSERT ON Orders TO staff;
REVOKE DELETE ON Orders FROM staff;

-- demo
-- admin
SET ROLE admin;
SELECT * FROM Employee;
RESET ROLE;
-- staff
SET ROLE staff;
SELECT * FROM Orders LIMIT 5;
DELETE FROM Orders WHERE order_id = 1;
RESET ROLE;






