# Pub Stock Management (PostgreSQL)

A coursework database for managing pub stock: products, suppliers, employees, orders, order lines, stock levels and payments. It also contains a set of SQL queries (Task 3) demonstrating subqueries, CTEs, window functions, stored procedures, triggers, transactions, indexing and role-based access.

## Quick start

Requires **PostgreSQL 11 or later** (the backup file was made with 18.1).

1. Create a database and load the schema and sample data (run the whole file once):
   ```bash
   createdb pub_stock
   psql -d pub_stock -f sql/01_schema_and_data.sql
   ```
2. Open `sql/02_queries_task3.sql` in pgAdmin, DBeaver or psql.
3. In your session, run:
   ```sql
   SET search_path TO Pub_Stock_Management;
   ```
4. Run the queries **one at a time**: highlight one Q block and execute it, in order.

## Repository layout

| Path | Purpose |
|---|---|
| `sql/01_schema_and_data.sql` | Drops and recreates the `Pub_Stock_Management` schema, creates the tables and inserts sample data. Safe to re-run (resets all data). |
| `sql/02_queries_task3.sql` | Task 3 queries Q1-Q12. Run block by block. |
| `original_submission/` | Files exactly as submitted, kept for reference (if included). |

## Database design

All tables live in the `Pub_Stock_Management` schema and use identity primary keys.

| Table | Key columns | Notes |
|---|---|---|
| `Products` | `product_id`, `product_name`, `category`, `price` | `price >= 0` |
| `Supplier` | `supplier_id`, `supplier_name`, `contact_email`, `phone` | |
| `Employee` | `employee_id`, `employee_name`, `role` | |
| `Orders` | `order_id`, `supplier_id`, `employee_id`, `order_date`, `status` | `status`: NEW, PAID, SHIPPED, CANCELLED |
| `Order_Details` | `order_detail_id`, `order_id`, `product_id`, `quantity`, `unit_price` | one row per product on an order |
| `Stocks` | `stock_id`, `product_id`, `quantity` | current stock per product |
| `Payments` | `payment_id`, `order_id`, `payment_date`, `amount`, `method`, `status` | `method`: CARD, CASH, BANK; `status`: PENDING, SUCCESS, FAILED. Deleted with their order (`ON DELETE CASCADE`). |

Relationships: an `Order` belongs to one `Supplier` and one `Employee`; an `Order` has many `Order_Details` and `Payments`; each `Order_Details` and `Stocks` row refers to a `Product`.

## Query index (Task 3)

| # | Topic | What it does |
|---|---|---|
| Q1 | Non-correlated subquery | Products that have never been ordered |
| Q2 | Correlated subquery | Products ordered in a quantity above 50 on at least one line |
| Q3 | CTE | Top 5 orders by total value |
| Q4 | Window function | Ranks all products by price |
| Q5 | Window function | Ranks products by price within each category |
| Q6 | Business insight | Top 5 most ordered products |
| Q7 | Stored procedure | `update_product_price(id, new_price)` with validation |
| Q8 | Trigger | Logs price changes to `price_change_history` |
| Q9 | Transactions | `COMMIT` keeps a change, `ROLLBACK` discards one |
| Q10 | Recovery | Explanation plus `pg_dump` / `pg_restore` example |
| Q11 | Performance tuning | `EXPLAIN ANALYZE` before and after adding an index |
| Q12 | Roles | `admin` (read Employee) and `staff` (read/insert Orders, no delete) |

## Things to know

- Q7-Q9 change the price of product 1. Re-run `01_schema_and_data.sql` to reset.
- Q12 creates the roles `admin` and `staff` with **demo-only passwords**. Roles are cluster-wide, so they stay after the schema is rebuilt.
- In Q12 the final `DELETE` as `staff` is **expected to fail** with `permission denied for table orders`. That demonstrates the restriction.
- Q11: on a small table PostgreSQL may keep using a sequential scan even after the index exists.

## Troubleshooting

| Problem | Fix |
|---|---|
| `relation "employee" does not exist` | The session isn't using the schema. Run `SET search_path TO Pub_Stock_Management;` in the same tab, or write `Pub_Stock_Management.Employee`. |
| Later queries fail with permission errors | A previous `SET ROLE` is still active. Run `RESET ROLE;`. |
| `role "admin" does not exist` on `GRANT` | Run the `DO` block at the start of Q12 first. |
| `pg_restore` fails on the `.backup` file | The dump is from PostgreSQL 18.1; use `pg_restore` 18 or newer, or use the SQL script instead. |

## Notes
The queries and database design are my own coursework I Submitted. I used Claude (an AI assistant)
afterwards to review the scripts, fix errors (e.g. role creation order), make them
re-runnable, and draft this README.