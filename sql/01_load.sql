-- =============================================================
-- 01_load.sql  |  Create the database and load the raw CSV
-- Coffee Shop Sales (Jan–Jun 2023, 3 outlets, 149,116 rows)
-- =============================================================
-- Before running in MySQL Workbench:
--   1. Edit the connection > Advanced > Others:  OPT_LOCAL_INFILE=1
--   2. Run once as root:  SET GLOBAL local_infile = 1;
--   3. Change the file path below to where you saved the CSV
--      (use forward slashes on Windows, e.g. C:/coffee/data/...).
-- =============================================================

DROP DATABASE IF EXISTS coffee_shop;
CREATE DATABASE coffee_shop CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE coffee_shop;

-- Staging table: everything lands as text first, so a bad value
-- can never make the load fail. We type and clean it in step 02.
CREATE TABLE stg_sales (
    transaction_id    VARCHAR(20),
    transaction_date  VARCHAR(20),
    transaction_time  VARCHAR(20),
    transaction_qty   VARCHAR(10),
    store_id          VARCHAR(10),
    store_location    VARCHAR(100),
    product_id        VARCHAR(10),
    unit_price        VARCHAR(20),
    product_category  VARCHAR(100),
    product_type      VARCHAR(100),
    product_detail    VARCHAR(100)
);

LOAD DATA LOCAL INFILE 'C:/coffee/data/coffee_shop_sales_raw.csv'
INTO TABLE stg_sales
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES;

-- Expect 149116
SELECT COUNT(*) AS rows_loaded FROM stg_sales;
