-- Task 3
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
    SELECT oi.order_id,
        SUM(oi.quantity * oi.unit_price) AS order_total
    FROM Order_Details oi
    GROUP BY oi.order_id
)
SELECT o.order_id,
    o.order_date,
    o.status,
    ot.order_total
FROM Orders o
    JOIN order_totals ot ON ot.order_id = o.order_id
ORDER BY ot.order_total DESC
LIMIT 5;
-- Q4 Window Function
SELECT product_name,
    price,
    RANK() OVER (
        ORDER BY price DESC
    ) AS price_rank
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
ORDER BY category,
    category_rank;
-- Q6 Business Insight Query
SELECT p.product_name,
    SUM(od.quantity) AS total_quantity_ordered
FROM Order_Details od
    JOIN Products p ON p.product_id = od.product_id
GROUP BY p.product_name
ORDER BY total_quantity_ordered DESC
LIMIT 5;
-- Q7 stored procedure/function
CREATE OR REPLACE PROCEDURE update_product_price(p_product_id INT, p_new_price NUMERIC(10, 2)) LANGUAGE plpgsql AS $$ BEGIN IF p_new_price IS NULL
    OR p_new_price <= 0 THEN RAISE EXCEPTION 'New price must be > 0. Got: %',
    p_new_price;
END IF;
UPDATE products
SET price = p_new_price
WHERE product_id = p_product_id;
IF NOT FOUND THEN RAISE EXCEPTION 'No product found with product_id = %',
p_product_id;
END IF;
END;
$$;
-- calling the stored procedure
SELECT product_id,
    product_name,
    price
FROM products
WHERE product_id = 1;
CALL update_product_price(1, 10.99);
SELECT product_id,
    product_name,
    price
FROM products
WHERE product_id = 1;
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
CREATE OR REPLACE FUNCTION log_price_change() RETURNS TRIGGER LANGUAGE plpgsql AS $$ BEGIN
INSERT INTO price_change_history(product_id, old_price, new_price)
VALUES (OLD.product_id, OLD.price, NEW.price);
RETURN NEW;
END;
$$;
-- Create a trigger
CREATE TRIGGER trigger_price_updates
AFTER
UPDATE ON products FOR EACH ROW
    WHEN (
        OLD.price IS DISTINCT
        FROM NEW.price
    ) EXECUTE FUNCTION log_price_change();
-- Testing the trigger
UPDATE products
SET price = 12.99
WHERE product_id = 1;
SELECT *
FROM price_change_history;
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
SELECT product_id,
    price
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
GRANT USAGE ON SCHEMA Pub_Stock_Management TO admin,
    staff;
-- Admin role
CREATE ROLE admin LOGIN PASSWORD 'admin123';
GRANT SELECT ON Employee TO admin;
-- Staff role
CREATE ROLE staff LOGIN PASSWORD 'staff123';
GRANT SELECT,
    INSERT ON Orders TO staff;
REVOKE DELETE ON Orders
FROM staff;
-- demo
-- admin
SET ROLE admin;
SELECT *
FROM Employee;
RESET ROLE;
-- staff
SET ROLE staff;
SELECT *
FROM Orders
LIMIT 5;
DELETE FROM Orders
WHERE order_id = 1;
RESET ROLE;
-- =========================================================
-- Pub Stock Management - PostgreSQL script
-- Schema: Pub_Stock_Management
-- Safe to re-run (drops and recreates schema)
-- =========================================================
DROP SCHEMA IF EXISTS Pub_Stock_Management CASCADE;
CREATE SCHEMA Pub_Stock_Management;
SET search_path TO Pub_Stock_Management;
-- ==========================================================
-- CREATE TABLES
-- ==========================================================
-- Create Products table
CREATE TABLE Products (
    product_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    product_name VARCHAR(100) NOT NULL,
    category VARCHAR(50),
    price NUMERIC(10, 2) NOT NULL CHECK(price >= 0)
);
-- Create Supplier table
CREATE TABLE Supplier (
    supplier_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    supplier_name VARCHAR(100) NOT NULL,
    contact_email VARCHAR(100),
    phone VARCHAR(30)
);
-- Create Employee table
CREATE TABLE Employee (
    employee_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    employee_name VARCHAR(100) NOT NULL,
    role VARCHAR(50)
);
-- Create Orders table
CREATE TABLE Orders (
    order_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    supplier_id INT NOT NULL REFERENCES Supplier(supplier_id),
    employee_id INT NOT NULL REFERENCES Employee(employee_id),
    order_date DATE NOT NULL,
    status VARCHAR(20) NOT NULL CHECK (status IN ('NEW', 'PAID', 'SHIPPED', 'CANCELLED'))
);
-- Create Stocks table
CREATE TABLE Stocks (
    stock_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    product_id INT REFERENCES Products(product_id),
    quantity INT NOT NULL
);
-- Create Order_Details table
CREATE TABLE Order_Details (
    order_detail_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    order_id INT REFERENCES Orders(order_id),
    product_id INT REFERENCES Products(product_id),
    quantity INT NOT NULL,
    unit_price NUMERIC(10, 2) NOT NULL CHECK(unit_price >= 0)
);
-- Create Payments table
CREATE TABLE Payments (
    payment_id INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    order_id INT NOT NULL REFERENCES Orders(order_id) ON DELETE CASCADE,
    payment_date DATE NOT NULL,
    amount NUMERIC(10, 2) NOT NULL CHECK (amount >= 0),
    method VARCHAR(20) NOT NULL CHECK (method IN ('CARD', 'CASH', 'BANK')),
    status VARCHAR(20) NOT NULL CHECK (status IN ('PENDING', 'SUCCESS', 'FAILED'))
);
-- ==========================================================
-- POPULATE DATA (INSERT STATEMENTS)
-- ==========================================================
-- 1. Populate Supplier (10 records)
INSERT INTO Supplier (supplier_name, contact_email, phone)
VALUES (
        'Dublin Brewing Co.',
        'orders@dublinbrewing.com',
        '01-234-5678'
    ),
    (
        'Cork Distilleries',
        'sales@corkdistill.ie',
        '021-987-6543'
    ),
    (
        'Green Valley Produce',
        'info@greenvalley.ie',
        '045-123-4567'
    ),
    (
        'Prime Meats Ireland',
        'butcher@primemeats.com',
        '01-444-5555'
    ),
    (
        'Ocean Fresh Seafood',
        'daily-catch@oceanfresh.ie',
        '061-222-3333'
    ),
    (
        'The Baking Oven',
        'bread@bakingoven.com',
        '01-888-9999'
    ),
    (
        'Select Wines Ltd.',
        'sommelier@selectwines.ie',
        '01-777-6666'
    ),
    (
        'Soft Drinks Direct',
        'bottles@softdrinks.com',
        '01-333-2222'
    ),
    (
        'Coffee Roast Masters',
        'beans@roastmasters.ie',
        '01-555-1111'
    ),
    (
        'Hygiene Supplies Pro',
        'cleaning@hygienepro.com',
        '01-666-0000'
    );
-- 2. Populate Employee (8 records)
INSERT INTO Employee (employee_name, role)
VALUES ('John Smith', 'Manager'),
    ('Sarah O''Connor', 'Assistant Manager'),
    ('Michael Ryan', 'Head Chef'),
    ('Emma Byrne', 'Bartender'),
    ('David Murphy', 'Bartender'),
    ('Lucy Kelly', 'Server'),
    ('Robert Walsh', 'Server'),
    ('Sophie Doyle', 'Kitchen Porter');
-- 3. Populate Products (20 records)
INSERT INTO Products (product_name, category, price)
VALUES ('Guinness Pint', 'Beverage', 5.80),
    ('Heineken Pint', 'Beverage', 6.20),
    ('Bulmers Cider', 'Beverage', 6.00),
    ('Jameson Whiskey Shot', 'Beverage', 5.50),
    ('House White Wine', 'Beverage', 7.50),
    ('House Red Wine', 'Beverage', 7.50),
    ('Coca Cola 330ml', 'Beverage', 3.20),
    ('Still Water 500ml', 'Beverage', 2.50),
    ('Beef Burger & Chips', 'Food', 15.50),
    ('Fish and Chips', 'Food', 16.00),
    ('Shepherd''s Pie', 'Food', 14.50),
    ('Chicken Wings (Large)', 'Food', 12.00),
    ('Caesar Salad', 'Food', 11.50),
    ('Steak Sandwich', 'Food', 17.50),
    ('Bacon & Cabbage', 'Food', 15.00),
    ('Tayto Crisps (Cheese & Onion)', 'Snack', 1.50),
    ('Salted Peanuts', 'Snack', 2.00),
    ('Garlic Bread', 'Snack', 5.50),
    ('Apple Crumble', 'Snack', 6.50),
    ('Chocolate Brownie', 'Snack', 6.50);
-- 4. Populate Stocks (20 records)
INSERT INTO Stocks (product_id, quantity)
VALUES (1, 450),
    (2, 400),
    (3, 350),
    (4, 100),
    (5, 80),
    (6, 80),
    (7, 200),
    (8, 150),
    (9, 100),
    (10, 80),
    (11, 60),
    (12, 120),
    (13, 50),
    (14, 40),
    (15, 30),
    (16, 100),
    (17, 100),
    (18, 150),
    (19, 40),
    (20, 40);
-- 5. Populate Orders (200 records)
INSERT INTO Orders (supplier_id, employee_id, order_date, status)
VALUES (1, 1, '2026-01-01', 'PAID'),
    (2, 2, '2026-01-01', 'SHIPPED'),
    (3, 3, '2026-01-02', 'PAID'),
    (4, 4, '2026-01-02', 'PAID'),
    (5, 5, '2026-01-03', 'SHIPPED'),
    (6, 6, '2026-01-03', 'PAID'),
    (7, 7, '2026-01-04', 'SHIPPED'),
    (8, 8, '2026-01-04', 'PAID'),
    (9, 1, '2026-01-05', 'PAID'),
    (10, 2, '2026-01-05', 'SHIPPED'),
    (1, 3, '2026-01-06', 'PAID'),
    (2, 4, '2026-01-06', 'PAID'),
    (3, 5, '2026-01-07', 'SHIPPED'),
    (4, 6, '2026-01-07', 'PAID'),
    (5, 7, '2026-01-08', 'PAID'),
    (6, 8, '2026-01-08', 'SHIPPED'),
    (7, 1, '2026-01-09', 'PAID'),
    (8, 2, '2026-01-09', 'PAID'),
    (9, 3, '2026-01-10', 'SHIPPED'),
    (10, 4, '2026-01-10', 'PAID'),
    (1, 5, '2026-01-11', 'PAID'),
    (2, 6, '2026-01-11', 'CANCELLED'),
    (3, 7, '2026-01-12', 'PAID'),
    (4, 8, '2026-01-12', 'SHIPPED'),
    (5, 1, '2026-01-13', 'PAID'),
    (6, 2, '2026-01-13', 'PAID'),
    (7, 3, '2026-01-14', 'SHIPPED'),
    (8, 4, '2026-01-14', 'PAID'),
    (9, 5, '2026-01-15', 'PAID'),
    (10, 6, '2026-01-15', 'SHIPPED'),
    (1, 7, '2026-01-16', 'PAID'),
    (2, 8, '2026-01-16', 'PAID'),
    (3, 1, '2026-01-17', 'SHIPPED'),
    (4, 2, '2026-01-17', 'PAID'),
    (5, 3, '2026-01-18', 'PAID'),
    (6, 4, '2026-01-18', 'CANCELLED'),
    (7, 5, '2026-01-19', 'PAID'),
    (8, 6, '2026-01-19', 'SHIPPED'),
    (9, 7, '2026-01-20', 'PAID'),
    (10, 8, '2026-01-20', 'PAID'),
    (1, 1, '2026-01-21', 'SHIPPED'),
    (2, 2, '2026-01-21', 'PAID'),
    (3, 3, '2026-01-22', 'PAID'),
    (4, 4, '2026-01-22', 'SHIPPED'),
    (5, 5, '2026-01-23', 'PAID'),
    (6, 6, '2026-01-23', 'PAID'),
    (7, 7, '2026-01-24', 'SHIPPED'),
    (8, 8, '2026-01-24', 'PAID'),
    (9, 1, '2026-01-25', 'PAID'),
    (10, 2, '2026-01-25', 'CANCELLED'),
    (1, 3, '2026-01-26', 'PAID'),
    (2, 4, '2026-01-26', 'SHIPPED'),
    (3, 5, '2026-01-27', 'PAID'),
    (4, 6, '2026-01-27', 'PAID'),
    (5, 7, '2026-01-28', 'SHIPPED'),
    (6, 8, '2026-01-28', 'PAID'),
    (7, 1, '2026-01-29', 'PAID'),
    (8, 2, '2026-01-29', 'SHIPPED'),
    (9, 3, '2026-01-30', 'PAID'),
    (10, 4, '2026-01-30', 'PAID'),
    (1, 5, '2026-01-31', 'SHIPPED'),
    (2, 6, '2026-01-31', 'PAID'),
    (3, 7, '2026-02-01', 'PAID'),
    (4, 8, '2026-02-01', 'CANCELLED'),
    (5, 1, '2026-02-02', 'PAID'),
    (6, 2, '2026-02-02', 'SHIPPED'),
    (7, 3, '2026-02-03', 'PAID'),
    (8, 4, '2026-02-03', 'PAID'),
    (9, 5, '2026-02-04', 'SHIPPED'),
    (10, 6, '2026-02-04', 'PAID'),
    (1, 7, '2026-02-05', 'PAID'),
    (2, 8, '2026-02-05', 'SHIPPED'),
    (3, 1, '2026-02-06', 'PAID'),
    (4, 2, '2026-02-06', 'PAID'),
    (5, 3, '2026-02-07', 'SHIPPED'),
    (6, 4, '2026-02-07', 'PAID'),
    (7, 5, '2026-02-08', 'PAID'),
    (8, 6, '2026-02-08', 'CANCELLED'),
    (9, 7, '2026-02-09', 'PAID'),
    (10, 8, '2026-02-09', 'SHIPPED'),
    (1, 1, '2026-02-10', 'PAID'),
    (2, 2, '2026-02-10', 'PAID'),
    (3, 3, '2026-02-11', 'SHIPPED'),
    (4, 4, '2026-02-11', 'PAID'),
    (5, 5, '2026-02-12', 'PAID'),
    (6, 6, '2026-02-12', 'SHIPPED'),
    (7, 7, '2026-02-13', 'PAID'),
    (8, 8, '2026-02-13', 'PAID'),
    (9, 1, '2026-02-14', 'SHIPPED'),
    (10, 2, '2026-02-14', 'PAID'),
    (1, 3, '2026-02-15', 'PAID'),
    (2, 4, '2026-02-15', 'CANCELLED'),
    (3, 5, '2026-02-16', 'PAID'),
    (4, 6, '2026-02-16', 'SHIPPED'),
    (5, 7, '2026-02-17', 'PAID'),
    (6, 8, '2026-02-17', 'PAID'),
    (7, 1, '2026-02-18', 'SHIPPED'),
    (8, 2, '2026-02-18', 'PAID'),
    (9, 3, '2026-02-19', 'PAID'),
    (10, 4, '2026-02-19', 'SHIPPED'),
    (1, 5, '2026-02-20', 'PAID'),
    (2, 6, '2026-02-20', 'PAID'),
    (3, 7, '2026-02-21', 'SHIPPED'),
    (4, 8, '2026-02-21', 'PAID'),
    (5, 1, '2026-02-22', 'PAID'),
    (6, 2, '2026-02-22', 'CANCELLED'),
    (7, 3, '2026-02-23', 'PAID'),
    (8, 4, '2026-02-23', 'SHIPPED'),
    (9, 5, '2026-02-24', 'PAID'),
    (10, 6, '2026-02-24', 'PAID'),
    (1, 7, '2026-02-25', 'SHIPPED'),
    (2, 8, '2026-02-25', 'PAID'),
    (3, 1, '2026-02-26', 'PAID'),
    (4, 2, '2026-02-26', 'SHIPPED'),
    (5, 3, '2026-02-27', 'PAID'),
    (6, 4, '2026-02-27', 'PAID'),
    (7, 5, '2026-02-28', 'SHIPPED'),
    (8, 6, '2026-02-28', 'PAID'),
    (9, 7, '2026-03-01', 'PAID'),
    (10, 8, '2026-03-01', 'SHIPPED'),
    (1, 1, '2026-03-02', 'PAID'),
    (2, 2, '2026-03-02', 'PAID'),
    (3, 3, '2026-03-03', 'NEW'),
    (4, 4, '2026-03-03', 'PAID'),
    (5, 5, '2026-03-04', 'SHIPPED'),
    (6, 6, '2026-03-04', 'PAID'),
    (7, 7, '2026-03-05', 'PAID'),
    (8, 8, '2026-03-05', 'NEW'),
    (9, 1, '2026-03-06', 'SHIPPED'),
    (10, 2, '2026-03-06', 'PAID'),
    (1, 3, '2026-03-07', 'PAID'),
    (2, 4, '2026-03-07', 'NEW'),
    (3, 5, '2026-03-08', 'PAID'),
    (4, 6, '2026-03-08', 'SHIPPED'),
    (5, 7, '2026-03-09', 'PAID'),
    (6, 8, '2026-03-09', 'PAID'),
    (7, 1, '2026-03-10', 'NEW'),
    (8, 2, '2026-03-10', 'PAID'),
    (9, 3, '2026-03-11', 'SHIPPED'),
    (10, 4, '2026-03-11', 'PAID'),
    (1, 5, '2026-03-12', 'PAID'),
    (2, 6, '2026-03-12', 'NEW'),
    (3, 7, '2026-03-13', 'PAID'),
    (4, 8, '2026-03-13', 'SHIPPED'),
    (5, 1, '2026-03-14', 'PAID'),
    (6, 2, '2026-03-14', 'PAID'),
    (7, 3, '2026-03-15', 'NEW'),
    (8, 4, '2026-03-15', 'PAID'),
    (9, 5, '2026-03-16', 'PAID'),
    (10, 6, '2026-03-16', 'SHIPPED'),
    (1, 7, '2026-03-17', 'PAID'),
    (2, 8, '2026-03-17', 'PAID'),
    (3, 1, '2026-03-18', 'NEW'),
    (4, 2, '2026-03-18', 'PAID'),
    (5, 3, '2026-03-19', 'SHIPPED'),
    (6, 4, '2026-03-19', 'PAID'),
    (7, 5, '2026-03-20', 'PAID'),
    (8, 6, '2026-03-20', 'NEW'),
    (9, 7, '2026-03-21', 'PAID'),
    (10, 8, '2026-03-21', 'SHIPPED'),
    (1, 1, '2026-03-22', 'PAID'),
    (2, 2, '2026-03-22', 'PAID'),
    (3, 3, '2026-03-23', 'NEW'),
    (4, 4, '2026-03-23', 'PAID'),
    (5, 5, '2026-03-24', 'SHIPPED'),
    (6, 6, '2026-03-24', 'PAID'),
    (7, 7, '2026-03-25', 'PAID'),
    (8, 8, '2026-03-25', 'NEW'),
    (9, 1, '2026-03-26', 'SHIPPED'),
    (10, 2, '2026-03-26', 'PAID'),
    (1, 3, '2026-03-27', 'PAID'),
    (2, 4, '2026-03-27', 'NEW'),
    (3, 5, '2026-03-28', 'PAID'),
    (4, 6, '2026-03-28', 'SHIPPED'),
    (5, 7, '2026-03-29', 'PAID'),
    (6, 8, '2026-03-29', 'NEW'),
    (7, 1, '2026-01-01', 'PAID'),
    (8, 2, '2026-01-01', 'SHIPPED'),
    (9, 3, '2026-01-02', 'PAID'),
    (10, 4, '2026-01-02', 'PAID'),
    (1, 5, '2026-01-03', 'SHIPPED'),
    (2, 6, '2026-01-03', 'PAID'),
    (3, 7, '2026-01-04', 'PAID'),
    (4, 8, '2026-01-04', 'SHIPPED'),
    (5, 1, '2026-01-05', 'PAID'),
    (6, 2, '2026-01-05', 'PAID'),
    (7, 3, '2026-01-06', 'SHIPPED'),
    (8, 4, '2026-01-06', 'PAID'),
    (9, 5, '2026-01-07', 'PAID'),
    (10, 6, '2026-01-07', 'CANCELLED'),
    (1, 7, '2026-01-08', 'PAID'),
    (2, 8, '2026-01-08', 'SHIPPED'),
    (3, 1, '2026-01-09', 'PAID'),
    (4, 2, '2026-01-09', 'PAID'),
    (5, 3, '2026-01-10', 'SHIPPED'),
    (6, 4, '2026-01-10', 'PAID'),
    (7, 5, '2026-01-11', 'PAID'),
    (8, 6, '2026-01-11', 'SHIPPED'),
    (9, 7, '2026-01-12', 'PAID'),
    (10, 8, '2026-01-12', 'PAID');
-- 6. Populate Order_Details (200 records)
INSERT INTO Order_Details (order_id, product_id, quantity, unit_price)
VALUES (1, 1, 10, 5.80),
    (2, 2, 8, 6.20),
    (3, 3, 5, 6.00),
    (4, 4, 12, 5.50),
    (5, 5, 4, 7.50),
    (6, 6, 6, 7.50),
    (7, 7, 24, 3.20),
    (8, 8, 20, 2.50),
    (9, 9, 10, 15.50),
    (10, 10, 8, 16.00),
    (11, 11, 15, 14.50),
    (12, 12, 20, 12.00),
    (13, 13, 10, 11.50),
    (14, 14, 5, 17.50),
    (15, 15, 8, 15.00),
    (16, 16, 30, 1.50),
    (17, 17, 25, 2.00),
    (18, 18, 12, 5.50),
    (19, 19, 10, 6.50),
    (20, 20, 10, 6.50),
    (21, 1, 5, 5.80),
    (22, 2, 4, 6.20),
    (23, 3, 10, 6.00),
    (24, 4, 10, 5.50),
    (25, 5, 2, 7.50),
    (26, 6, 8, 7.50),
    (27, 7, 12, 3.20),
    (28, 8, 10, 2.50),
    (29, 9, 5, 15.50),
    (30, 10, 4, 16.00),
    (31, 11, 6, 14.50),
    (32, 12, 10, 12.00),
    (33, 13, 12, 11.50),
    (34, 14, 5, 17.50),
    (35, 15, 5, 15.00),
    (36, 16, 15, 1.50),
    (37, 17, 15, 2.00),
    (38, 18, 5, 5.50),
    (39, 19, 8, 6.50),
    (40, 20, 8, 6.50),
    (41, 1, 8, 5.80),
    (42, 2, 6, 6.20),
    (43, 3, 8, 6.00),
    (44, 4, 5, 5.50),
    (45, 5, 10, 7.50),
    (46, 6, 10, 7.50),
    (47, 7, 20, 3.20),
    (48, 8, 20, 2.50),
    (49, 9, 8, 15.50),
    (50, 10, 6, 16.00),
    (51, 11, 10, 14.50),
    (52, 12, 12, 12.00),
    (53, 13, 8, 11.50),
    (54, 14, 4, 17.50),
    (55, 15, 4, 15.00),
    (56, 16, 20, 1.50),
    (57, 17, 20, 2.00),
    (58, 18, 10, 5.50),
    (59, 19, 6, 6.50),
    (60, 20, 6, 6.50),
    (61, 1, 12, 5.80),
    (62, 2, 10, 6.20),
    (63, 3, 12, 6.00),
    (64, 4, 20, 5.50),
    (65, 5, 5, 7.50),
    (66, 6, 5, 7.50),
    (67, 7, 15, 3.20),
    (68, 8, 15, 2.50),
    (69, 9, 12, 15.50),
    (70, 10, 10, 16.00),
    (71, 11, 15, 14.50),
    (72, 12, 15, 12.00),
    (73, 13, 10, 11.50),
    (74, 14, 6, 17.50),
    (75, 15, 6, 15.00),
    (76, 16, 25, 1.50),
    (77, 17, 25, 2.00),
    (78, 18, 12, 5.50),
    (79, 19, 10, 6.50),
    (80, 20, 10, 6.50),
    (81, 1, 15, 5.80),
    (82, 2, 12, 6.20),
    (83, 3, 15, 6.00),
    (84, 4, 25, 5.50),
    (85, 5, 6, 7.50),
    (86, 6, 6, 7.50),
    (87, 7, 24, 3.20),
    (88, 8, 24, 2.50),
    (89, 9, 15, 15.50),
    (90, 10, 12, 16.00),
    (91, 11, 20, 14.50),
    (92, 12, 20, 12.00),
    (93, 13, 12, 11.50),
    (94, 14, 8, 17.50),
    (95, 15, 8, 15.00),
    (96, 16, 30, 1.50),
    (97, 17, 30, 2.00),
    (98, 18, 15, 5.50),
    (99, 19, 12, 6.50),
    (100, 20, 12, 6.50),
    (101, 1, 10, 5.80),
    (102, 2, 8, 6.20),
    (103, 3, 5, 6.00),
    (104, 4, 12, 5.50),
    (105, 5, 4, 7.50),
    (106, 6, 6, 7.50),
    (107, 7, 24, 3.20),
    (108, 8, 20, 2.50),
    (109, 9, 10, 15.50),
    (110, 10, 8, 16.00),
    (111, 11, 15, 14.50),
    (112, 12, 20, 12.00),
    (113, 13, 10, 11.50),
    (114, 14, 5, 17.50),
    (115, 15, 8, 15.00),
    (116, 16, 30, 1.50),
    (117, 17, 25, 2.00),
    (118, 18, 12, 5.50),
    (119, 19, 10, 6.50),
    (120, 20, 10, 6.50),
    (121, 1, 5, 5.80),
    (122, 2, 4, 6.20),
    (123, 3, 10, 6.00),
    (124, 4, 10, 5.50),
    (125, 5, 2, 7.50),
    (126, 6, 8, 7.50),
    (127, 7, 12, 3.20),
    (128, 8, 10, 2.50),
    (129, 9, 5, 15.50),
    (130, 10, 4, 16.00),
    (131, 11, 6, 14.50),
    (132, 12, 10, 12.00),
    (133, 13, 12, 11.50),
    (134, 14, 5, 17.50),
    (135, 15, 5, 15.00),
    (136, 16, 15, 1.50),
    (137, 17, 15, 2.00),
    (138, 18, 5, 5.50),
    (139, 19, 8, 6.50),
    (140, 20, 8, 6.50),
    (141, 1, 8, 5.80),
    (142, 2, 6, 6.20),
    (143, 3, 8, 6.00),
    (144, 4, 5, 5.50),
    (145, 5, 10, 7.50),
    (146, 6, 10, 7.50),
    (147, 7, 20, 3.20),
    (148, 8, 20, 2.50),
    (149, 9, 8, 15.50),
    (150, 10, 6, 16.00),
    (151, 11, 10, 14.50),
    (152, 12, 12, 12.00),
    (153, 13, 8, 11.50),
    (154, 14, 4, 17.50),
    (155, 15, 4, 15.00),
    (156, 16, 20, 1.50),
    (157, 17, 20, 2.00),
    (158, 18, 10, 5.50),
    (159, 19, 6, 6.50),
    (160, 20, 6, 6.50),
    (161, 1, 12, 5.80),
    (162, 2, 10, 6.20),
    (163, 3, 12, 6.00),
    (164, 4, 20, 5.50),
    (165, 5, 5, 7.50),
    (166, 6, 5, 7.50),
    (167, 7, 15, 3.20),
    (168, 8, 15, 2.50),
    (169, 9, 12, 15.50),
    (170, 10, 10, 16.00),
    (171, 11, 15, 14.50),
    (172, 12, 15, 12.00),
    (173, 13, 10, 11.50),
    (174, 14, 6, 17.50),
    (175, 15, 6, 15.00),
    (176, 16, 25, 1.50),
    (177, 17, 25, 2.00),
    (178, 18, 12, 5.50),
    (179, 19, 10, 6.50),
    (180, 20, 10, 6.50),
    (181, 1, 15, 5.80),
    (182, 2, 12, 6.20),
    (183, 3, 15, 6.00),
    (184, 4, 25, 5.50),
    (185, 5, 6, 7.50),
    (186, 6, 6, 7.50),
    (187, 7, 24, 3.20),
    (188, 8, 24, 2.50),
    (189, 9, 15, 15.50),
    (190, 10, 12, 16.00),
    (191, 11, 20, 14.50),
    (192, 12, 20, 12.00),
    (193, 13, 12, 11.50),
    (194, 14, 8, 17.50),
    (195, 15, 8, 15.00),
    (196, 16, 30, 1.50),
    (197, 17, 30, 2.00),
    (198, 18, 15, 5.50),
    (199, 19, 12, 6.50),
    (200, 20, 12, 6.50);
-- 7. Populate Payments (200 records)
INSERT INTO Payments (order_id, payment_date, amount, method, status)
VALUES (1, '2026-01-01', 58.00, 'CARD', 'SUCCESS'),
    (2, '2026-01-01', 49.60, 'CASH', 'SUCCESS'),
    (3, '2026-01-02', 30.00, 'BANK', 'SUCCESS'),
    (4, '2026-01-02', 66.00, 'CARD', 'SUCCESS'),
    (5, '2026-01-03', 30.00, 'CASH', 'SUCCESS'),
    (6, '2026-01-03', 45.00, 'BANK', 'SUCCESS'),
    (7, '2026-01-04', 76.80, 'CARD', 'SUCCESS'),
    (8, '2026-01-04', 50.00, 'CASH', 'SUCCESS'),
    (9, '2026-01-05', 155.00, 'BANK', 'SUCCESS'),
    (10, '2026-01-05', 128.00, 'CARD', 'SUCCESS'),
    (11, '2026-01-06', 217.50, 'CASH', 'SUCCESS'),
    (12, '2026-01-06', 240.00, 'BANK', 'SUCCESS'),
    (13, '2026-01-07', 115.00, 'CARD', 'SUCCESS'),
    (14, '2026-01-07', 87.50, 'CASH', 'SUCCESS'),
    (15, '2026-01-08', 120.00, 'BANK', 'SUCCESS'),
    (16, '2026-01-08', 45.00, 'CARD', 'SUCCESS'),
    (17, '2026-01-09', 50.00, 'CASH', 'SUCCESS'),
    (18, '2026-01-09', 66.00, 'BANK', 'SUCCESS'),
    (19, '2026-01-10', 65.00, 'CARD', 'SUCCESS'),
    (20, '2026-01-10', 65.00, 'CASH', 'SUCCESS'),
    (21, '2026-01-11', 29.00, 'BANK', 'SUCCESS'),
    (22, '2026-01-11', 24.80, 'CARD', 'SUCCESS'),
    (23, '2026-01-12', 60.00, 'CASH', 'SUCCESS'),
    (24, '2026-01-12', 55.00, 'BANK', 'SUCCESS'),
    (25, '2026-01-13', 15.00, 'CARD', 'SUCCESS'),
    (26, '2026-01-13', 60.00, 'CASH', 'SUCCESS'),
    (27, '2026-01-14', 38.40, 'BANK', 'SUCCESS'),
    (28, '2026-01-14', 25.00, 'CARD', 'SUCCESS'),
    (29, '2026-01-15', 77.50, 'CASH', 'SUCCESS'),
    (30, '2026-01-15', 64.00, 'BANK', 'SUCCESS'),
    (31, '2026-01-16', 87.00, 'CARD', 'SUCCESS'),
    (32, '2026-01-16', 120.00, 'CASH', 'SUCCESS'),
    (33, '2026-01-17', 138.00, 'BANK', 'SUCCESS'),
    (34, '2026-01-17', 87.50, 'CARD', 'SUCCESS'),
    (35, '2026-01-18', 75.00, 'CASH', 'SUCCESS'),
    (36, '2026-01-18', 22.50, 'BANK', 'SUCCESS'),
    (37, '2026-01-19', 30.00, 'CARD', 'SUCCESS'),
    (38, '2026-01-19', 27.50, 'CASH', 'SUCCESS'),
    (39, '2026-01-20', 52.00, 'BANK', 'SUCCESS'),
    (40, '2026-01-20', 52.00, 'CARD', 'SUCCESS'),
    (41, '2026-01-21', 46.40, 'CASH', 'SUCCESS'),
    (42, '2026-01-21', 37.20, 'BANK', 'SUCCESS'),
    (43, '2026-01-22', 48.00, 'CARD', 'SUCCESS'),
    (44, '2026-01-22', 27.50, 'CASH', 'SUCCESS'),
    (45, '2026-01-23', 75.00, 'BANK', 'SUCCESS'),
    (46, '2026-01-23', 75.00, 'CARD', 'SUCCESS'),
    (47, '2026-01-24', 64.00, 'CASH', 'SUCCESS'),
    (48, '2026-01-24', 50.00, 'BANK', 'SUCCESS'),
    (49, '2026-01-25', 124.00, 'CARD', 'SUCCESS'),
    (50, '2026-01-25', 96.00, 'CASH', 'SUCCESS'),
    (51, '2026-01-26', 145.00, 'BANK', 'SUCCESS'),
    (52, '2026-01-26', 144.00, 'CARD', 'SUCCESS'),
    (53, '2026-01-27', 92.00, 'CASH', 'SUCCESS'),
    (54, '2026-01-27', 70.00, 'BANK', 'SUCCESS'),
    (55, '2026-01-28', 60.00, 'CARD', 'SUCCESS'),
    (56, '2026-01-28', 30.00, 'CASH', 'SUCCESS'),
    (57, '2026-01-29', 40.00, 'BANK', 'SUCCESS'),
    (58, '2026-01-29', 55.00, 'CARD', 'SUCCESS'),
    (59, '2026-01-30', 39.00, 'CASH', 'SUCCESS'),
    (60, '2026-01-30', 39.00, 'BANK', 'SUCCESS'),
    (61, '2026-01-31', 69.60, 'CARD', 'SUCCESS'),
    (62, '2026-01-31', 62.00, 'CASH', 'SUCCESS'),
    (63, '2026-02-01', 72.00, 'BANK', 'SUCCESS'),
    (64, '2026-02-01', 110.00, 'CARD', 'SUCCESS'),
    (65, '2026-02-02', 37.50, 'CASH', 'SUCCESS'),
    (66, '2026-02-02', 37.50, 'BANK', 'SUCCESS'),
    (67, '2026-02-03', 48.00, 'CARD', 'SUCCESS'),
    (68, '2026-02-03', 37.50, 'CASH', 'SUCCESS'),
    (69, '2026-02-04', 186.00, 'BANK', 'SUCCESS'),
    (70, '2026-02-04', 160.00, 'CARD', 'SUCCESS'),
    (71, '2026-02-05', 217.50, 'CASH', 'SUCCESS'),
    (72, '2026-02-05', 180.00, 'BANK', 'SUCCESS'),
    (73, '2026-02-06', 115.00, 'CARD', 'SUCCESS'),
    (74, '2026-02-06', 105.00, 'CASH', 'SUCCESS'),
    (75, '2026-02-07', 90.00, 'BANK', 'SUCCESS'),
    (76, '2026-02-07', 37.50, 'CARD', 'SUCCESS'),
    (77, '2026-02-08', 50.00, 'CASH', 'SUCCESS'),
    (78, '2026-02-08', 66.00, 'BANK', 'SUCCESS'),
    (79, '2026-02-09', 65.00, 'CARD', 'SUCCESS'),
    (80, '2026-02-09', 65.00, 'CASH', 'SUCCESS'),
    (81, '2026-02-10', 87.00, 'BANK', 'SUCCESS'),
    (82, '2026-02-10', 74.40, 'CARD', 'SUCCESS'),
    (83, '2026-02-11', 90.00, 'CASH', 'SUCCESS'),
    (84, '2026-02-11', 137.50, 'BANK', 'SUCCESS'),
    (85, '2026-02-12', 45.00, 'CARD', 'SUCCESS'),
    (86, '2026-02-12', 45.00, 'CASH', 'SUCCESS'),
    (87, '2026-02-13', 76.80, 'BANK', 'SUCCESS'),
    (88, '2026-02-13', 60.00, 'CARD', 'SUCCESS'),
    (89, '2026-02-14', 232.50, 'CASH', 'SUCCESS'),
    (90, '2026-02-14', 192.00, 'BANK', 'SUCCESS'),
    (91, '2026-02-15', 290.00, 'CARD', 'SUCCESS'),
    (92, '2026-02-15', 240.00, 'CASH', 'SUCCESS'),
    (93, '2026-02-16', 138.00, 'BANK', 'SUCCESS'),
    (94, '2026-02-16', 140.00, 'CARD', 'SUCCESS'),
    (95, '2026-02-17', 120.00, 'CASH', 'SUCCESS'),
    (96, '2026-02-17', 45.00, 'BANK', 'SUCCESS'),
    (97, '2026-02-18', 60.00, 'CARD', 'SUCCESS'),
    (98, '2026-02-18', 82.50, 'CASH', 'SUCCESS'),
    (99, '2026-02-19', 78.00, 'BANK', 'SUCCESS'),
    (100, '2026-02-19', 78.00, 'CARD', 'SUCCESS'),
    (101, '2026-02-20', 58.00, 'CASH', 'SUCCESS'),
    (102, '2026-02-20', 49.60, 'BANK', 'SUCCESS'),
    (103, '2026-02-21', 30.00, 'CARD', 'SUCCESS'),
    (104, '2026-02-21', 66.00, 'CASH', 'SUCCESS'),
    (105, '2026-02-22', 30.00, 'BANK', 'SUCCESS'),
    (106, '2026-02-22', 45.00, 'CARD', 'SUCCESS'),
    (107, '2026-02-23', 76.80, 'CASH', 'SUCCESS'),
    (108, '2026-02-23', 50.00, 'BANK', 'SUCCESS'),
    (109, '2026-02-24', 155.00, 'CARD', 'SUCCESS'),
    (110, '2026-02-24', 128.00, 'CASH', 'SUCCESS'),
    (111, '2026-02-25', 217.50, 'BANK', 'SUCCESS'),
    (112, '2026-02-25', 240.00, 'CARD', 'SUCCESS'),
    (113, '2026-02-26', 115.00, 'CASH', 'SUCCESS'),
    (114, '2026-02-26', 87.50, 'BANK', 'SUCCESS'),
    (115, '2026-02-27', 120.00, 'CARD', 'SUCCESS'),
    (116, '2026-02-27', 45.00, 'CASH', 'SUCCESS'),
    (117, '2026-02-28', 50.00, 'BANK', 'SUCCESS'),
    (118, '2026-02-28', 66.00, 'CARD', 'SUCCESS'),
    (119, '2026-03-01', 65.00, 'CASH', 'SUCCESS'),
    (120, '2026-03-01', 65.00, 'BANK', 'SUCCESS'),
    (121, '2026-03-02', 29.00, 'CARD', 'SUCCESS'),
    (122, '2026-03-02', 24.80, 'CASH', 'SUCCESS'),
    (123, '2026-03-03', 60.00, 'BANK', 'SUCCESS'),
    (124, '2026-03-03', 55.00, 'CARD', 'SUCCESS'),
    (125, '2026-03-04', 15.00, 'CASH', 'SUCCESS'),
    (126, '2026-03-04', 60.00, 'BANK', 'SUCCESS'),
    (127, '2026-03-05', 38.40, 'CARD', 'SUCCESS'),
    (128, '2026-03-05', 25.00, 'CASH', 'SUCCESS'),
    (129, '2026-03-06', 77.50, 'BANK', 'SUCCESS'),
    (130, '2026-03-06', 64.00, 'CARD', 'SUCCESS'),
    (131, '2026-03-07', 87.00, 'CASH', 'SUCCESS'),
    (132, '2026-03-07', 120.00, 'BANK', 'SUCCESS'),
    (133, '2026-03-08', 138.00, 'CARD', 'SUCCESS'),
    (134, '2026-03-08', 87.50, 'CASH', 'SUCCESS'),
    (135, '2026-03-09', 75.00, 'BANK', 'SUCCESS'),
    (136, '2026-03-09', 22.50, 'CARD', 'SUCCESS'),
    (137, '2026-03-10', 30.00, 'CASH', 'SUCCESS'),
    (138, '2026-03-10', 27.50, 'BANK', 'SUCCESS'),
    (139, '2026-03-11', 52.00, 'CARD', 'SUCCESS'),
    (140, '2026-03-11', 52.00, 'CASH', 'SUCCESS'),
    (141, '2026-03-12', 46.40, 'BANK', 'SUCCESS'),
    (142, '2026-03-12', 37.20, 'CARD', 'SUCCESS'),
    (143, '2026-03-13', 48.00, 'CASH', 'SUCCESS'),
    (144, '2026-03-13', 27.50, 'BANK', 'SUCCESS'),
    (145, '2026-03-14', 75.00, 'CARD', 'SUCCESS'),
    (146, '2026-03-14', 75.00, 'CASH', 'SUCCESS'),
    (147, '2026-03-15', 64.00, 'BANK', 'SUCCESS'),
    (148, '2026-03-15', 50.00, 'CARD', 'SUCCESS'),
    (149, '2026-03-16', 124.00, 'CASH', 'SUCCESS'),
    (150, '2026-03-16', 96.00, 'BANK', 'SUCCESS'),
    (151, '2026-03-17', 145.00, 'CARD', 'SUCCESS'),
    (152, '2026-03-17', 144.00, 'CASH', 'SUCCESS'),
    (153, '2026-03-18', 92.00, 'BANK', 'SUCCESS'),
    (154, '2026-03-18', 70.00, 'CARD', 'SUCCESS'),
    (155, '2026-03-19', 60.00, 'CASH', 'SUCCESS'),
    (156, '2026-03-19', 30.00, 'BANK', 'SUCCESS'),
    (157, '2026-03-20', 40.00, 'CARD', 'SUCCESS'),
    (158, '2026-03-20', 55.00, 'CASH', 'SUCCESS'),
    (159, '2026-03-21', 39.00, 'BANK', 'SUCCESS'),
    (160, '2026-03-21', 39.00, 'CARD', 'SUCCESS'),
    (161, '2026-03-22', 69.60, 'CASH', 'SUCCESS'),
    (162, '2026-03-22', 62.00, 'BANK', 'SUCCESS'),
    (163, '2026-03-23', 72.00, 'CARD', 'SUCCESS'),
    (164, '2026-03-23', 110.00, 'CASH', 'SUCCESS'),
    (165, '2026-03-24', 37.50, 'BANK', 'SUCCESS'),
    (166, '2026-03-24', 37.50, 'CARD', 'SUCCESS'),
    (167, '2026-03-25', 48.00, 'CASH', 'SUCCESS'),
    (168, '2026-03-25', 37.50, 'BANK', 'SUCCESS'),
    (169, '2026-03-26', 186.00, 'CARD', 'SUCCESS'),
    (170, '2026-03-26', 160.00, 'CASH', 'SUCCESS'),
    (171, '2026-03-27', 217.50, 'BANK', 'SUCCESS'),
    (172, '2026-03-27', 180.00, 'CARD', 'SUCCESS'),
    (173, '2026-03-28', 115.00, 'CASH', 'SUCCESS'),
    (174, '2026-03-28', 105.00, 'BANK', 'SUCCESS'),
    (175, '2026-03-29', 90.00, 'CARD', 'SUCCESS'),
    (176, '2026-03-29', 37.50, 'CASH', 'SUCCESS'),
    (177, '2026-01-01', 50.00, 'BANK', 'SUCCESS'),
    (178, '2026-01-01', 66.00, 'CARD', 'SUCCESS'),
    (179, '2026-01-02', 65.00, 'CASH', 'SUCCESS'),
    (180, '2026-01-02', 65.00, 'BANK', 'SUCCESS'),
    (181, '2026-01-03', 87.00, 'CARD', 'SUCCESS'),
    (182, '2026-01-03', 74.40, 'CASH', 'SUCCESS'),
    (183, '2026-01-04', 90.00, 'BANK', 'SUCCESS'),
    (184, '2026-01-04', 137.50, 'CARD', 'SUCCESS'),
    (185, '2026-01-05', 45.00, 'CASH', 'SUCCESS'),
    (186, '2026-01-05', 45.00, 'BANK', 'SUCCESS'),
    (187, '2026-01-06', 76.80, 'CARD', 'SUCCESS'),
    (188, '2026-01-06', 60.00, 'CASH', 'SUCCESS'),
    (189, '2026-01-07', 232.50, 'BANK', 'SUCCESS'),
    (190, '2026-01-07', 192.00, 'CARD', 'SUCCESS'),
    (191, '2026-01-08', 290.00, 'CASH', 'SUCCESS'),
    (192, '2026-01-08', 240.00, 'BANK', 'SUCCESS'),
    (193, '2026-01-09', 138.00, 'CARD', 'SUCCESS'),
    (194, '2026-01-09', 140.00, 'CASH', 'SUCCESS'),
    (195, '2026-01-10', 120.00, 'BANK', 'SUCCESS'),
    (196, '2026-01-10', 45.00, 'CARD', 'SUCCESS'),
    (197, '2026-01-11', 60.00, 'CASH', 'SUCCESS'),
    (198, '2026-01-11', 82.50, 'BANK', 'SUCCESS'),
    (199, '2026-01-12', 78.00, 'CARD', 'SUCCESS'),
    (200, '2026-01-12', 78.00, 'CASH', 'SUCCESS');