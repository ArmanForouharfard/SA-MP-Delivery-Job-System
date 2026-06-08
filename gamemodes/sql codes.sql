-- Step 1: Create the database
CREATE DATABASE IF NOT EXISTS pawncourse2;
USE pawncourse2;

-- Step 2: Create products table
CREATE TABLE IF NOT EXISTS products (
    id INT NOT NULL AUTO_INCREMENT,
    name VARCHAR(50) NOT NULL,
    base_price INT NOT NULL,
    sensitivity INT NOT NULL DEFAULT 1,
    PRIMARY KEY (id)
);

-- Step 3: Create customers table
CREATE TABLE IF NOT EXISTS customers (
    id INT NOT NULL AUTO_INCREMENT,
    name VARCHAR(50) NOT NULL,
    pos_x FLOAT NOT NULL,
    pos_y FLOAT NOT NULL,
    pos_z FLOAT NOT NULL,
    PRIMARY KEY (id)
);

-- Step 4: Create delivery_history table (prevents repeats)
CREATE TABLE IF NOT EXISTS delivery_history (
    id INT NOT NULL AUTO_INCREMENT,
    player_name VARCHAR(24) NOT NULL,
    product_id INT NOT NULL,
    customer_id INT NOT NULL,
    delivered_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY unique_delivery (player_name, product_id, customer_id)
);

-- Step 5: Add sample data (4 products)
INSERT INTO products (name, base_price, sensitivity) VALUES
('Cigarettes', 200, 1),
('Pizza', 150, 2),
('Documents', 500, 3),
('Electronics', 350, 2);

-- Step 6: Add sample data (4 customers)
INSERT INTO customers (name, pos_x, pos_y, pos_z) VALUES
('Alex', -1846.35, 453.92, 37.30),
('Maria', 2314.82, -1481.90, 23.99),
('Joe', 648.55, -613.66, 16.33),
('Sarah', 1393.85, 212.25, 19.57);