-- ==========================================
-- 1. CUSTOMERS TABLE
-- ==========================================
DROP TABLE IF EXISTS customers;

CREATE TABLE customers (
    user_id INT NOT NULL,  -- Must be NOT NULL for Primary Key
    join_date DATE,
    country VARCHAR(50),
    prime_status VARCHAR(10)
);

ALTER TABLE customers 
ADD CONSTRAINT PK_customers PRIMARY KEY NONCLUSTERED (user_id) NOT ENFORCED;

INSERT INTO customers (user_id, join_date, country, prime_status) VALUES
(101, '2021-01-15', 'USA', 'Active'),
(102, '2021-02-20', 'UK', 'Inactive'),
(103, '2022-03-05', 'USA', 'Active'),
(104, '2022-04-12', 'India', 'Active'),
(105, '2023-05-25', 'Canada', 'Inactive');


-- ==========================================
-- 2. PRODUCTS TABLE
-- ==========================================
DROP TABLE IF EXISTS products;

CREATE TABLE products (
    product_id INT NOT NULL, -- Must be NOT NULL for Primary Key
    product_name VARCHAR(100),
    category VARCHAR(50),
    price DECIMAL(10, 2)
);

ALTER TABLE products 
ADD CONSTRAINT PK_products PRIMARY KEY NONCLUSTERED (product_id) NOT ENFORCED;

INSERT INTO products (product_id, product_name, category, price) VALUES
(501, 'HP Omen', 'Electronics', 1200.00),
(502, 'Wireless Headset', 'Electronics', 250.00),
(503, 'Vacuum Cleaner', 'Electronics', 350.00),
(504, 'Refrigerator', 'Appliance', 800.00),
(505, 'Washing Machine', 'Appliance', 450.00),
(506, 'Microwave', 'Appliance', 150.00);


-- ==========================================
-- 3. ORDERS TABLE
-- ==========================================
DROP TABLE IF EXISTS orders;

CREATE TABLE orders (
    order_id INT NOT NULL, 
    user_id INT,
    product_id INT,
    order_timestamp DATETIME2(0), -- Changed to DATETIME
    quantity INT,
    delivery_date DATE,
    order_status VARCHAR(20)
);

ALTER TABLE orders 
ADD CONSTRAINT PK_orders PRIMARY KEY NONCLUSTERED (order_id) NOT ENFORCED;

INSERT INTO orders (order_id, user_id, product_id, order_timestamp, quantity, delivery_date, order_status) VALUES
(1001, 101, 501, '2022-06-01 08:30:00', 1, '2022-06-05', 'Delivered'),
(1002, 102, 504, '2022-08-15 10:15:00', 1, '2022-08-20', 'Delivered'),
(1003, 103, 505, '2023-02-10 14:00:00', 2, '2023-02-15', 'Delivered'),
(1004, 104, 502, '2023-07-05 09:45:00', 3, '2023-07-10', 'Delivered'),
(1005, 101, 506, '2023-10-01 11:20:00', 1, '2023-10-03', 'Delivered'),
(1006, 101, 503, '2023-10-01 15:45:00', 1, '2023-10-05', 'Delivered'), -- Same day purchase!
(1007, 101, 502, '2023-10-03 08:00:00', 2, '2023-10-06', 'Delivered'),
(1008, 105, 501, '2023-11-15 18:30:00', 1, NULL, 'Pending'),
(1009, 102, 504, '2024-01-10 12:00:00', 1, '2024-01-15', 'Delivered'),
(1010, 103, 506, '2023-02-11 10:00:00', 2, '2023-02-14', 'Delivered'), -- 3-day consecutive streak w/ 1003 & 1011 (Q3) + Appliance revenue tie (Q1)
(1011, 103, 506, '2023-02-12 10:00:00', 3, '2023-02-15', 'Delivered'); -- completes the 3-day streak (Feb 10-11-12)


-- ==========================================
-- 4. REVIEWS TABLE
-- ==========================================
DROP TABLE IF EXISTS reviews;

CREATE TABLE reviews (
    review_id INT NOT NULL, -- Must be NOT NULL for Primary Key
    order_id INT,
    product_id INT,
    user_id INT,
    submit_date DATE,
    stars INT
);

ALTER TABLE reviews 
ADD CONSTRAINT PK_reviews PRIMARY KEY NONCLUSTERED (review_id) NOT ENFORCED;

INSERT INTO reviews (review_id, order_id, product_id, user_id, submit_date, stars) VALUES
(8001, 1001, 501, 101, '2022-06-10', 4),
(8002, 1002, 504, 102, '2022-08-25', 5),
(8003, 1005, 506, 101, '2023-10-05', 2),
(8004, 1006, 503, 101, '2023-10-08', 4),
(8005, 1009, 504, 102, '2024-01-20', 5);


-- ==========================================
-- 5. INVENTORY TABLE
-- ==========================================
DROP TABLE IF EXISTS inventory;

CREATE TABLE inventory (
    item_id INT NOT NULL, -- Must be NOT NULL for Primary Key
    item_type VARCHAR(50),
    square_footage DECIMAL(10, 2)
);

ALTER TABLE inventory 
ADD CONSTRAINT PK_inventory PRIMARY KEY NONCLUSTERED (item_id) NOT ENFORCED;

INSERT INTO inventory (item_id, item_type, square_footage) VALUES
(1, 'prime_eligible', 150.00),
(2, 'prime_eligible', 200.00),
(3, 'prime_eligible', 205.20),
(4, 'not_prime', 50.00),
(5, 'not_prime', 30.50),
(6, 'not_prime', 48.00);