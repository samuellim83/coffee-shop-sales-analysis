-- =============================================================
-- 02_clean.sql  |  Profile, type and clean the data
-- =============================================================
USE coffee_shop;

-- ---------- 1. Profiling: what is wrong with the raw data? ----------

-- 1a. Missing / blank values per column (all 0 in this dataset)
SELECT
    SUM(transaction_id   IS NULL OR transaction_id   = '') AS null_id,
    SUM(transaction_date IS NULL OR transaction_date = '') AS null_date,
    SUM(transaction_time IS NULL OR transaction_time = '') AS null_time,
    SUM(transaction_qty  IS NULL OR transaction_qty  = '') AS null_qty,
    SUM(unit_price       IS NULL OR unit_price       = '') AS null_price,
    SUM(product_detail   IS NULL OR product_detail   = '') AS null_detail
FROM stg_sales;

-- 1b. Duplicate transaction IDs (0)
SELECT transaction_id, COUNT(*) AS n
FROM stg_sales
GROUP BY transaction_id
HAVING COUNT(*) > 1;

-- 1c. Leading/trailing spaces (finds 'Scottish Cream Scone ' – 1,952 rows)
--     NOTE: compare lengths, not strings. With PAD SPACE collations
--     'abc ' = 'abc' is TRUE, so  product_detail <> TRIM(product_detail)
--     would silently find nothing.
SELECT CONCAT('[', product_detail, ']') AS value_with_brackets, COUNT(*) AS n
FROM stg_sales
WHERE CHAR_LENGTH(product_detail) <> CHAR_LENGTH(TRIM(product_detail))
GROUP BY product_detail;

-- 1d. Same product sold at more than one price (15 products – a real
--     pricing fact, not an error; so price stays on the sales row,
--     NOT in the product table)
SELECT product_id, product_detail,
       COUNT(DISTINCT unit_price) AS price_points,
       MIN(CAST(unit_price AS DECIMAL(6,2))) AS min_price,
       MAX(CAST(unit_price AS DECIMAL(6,2))) AS max_price
FROM stg_sales
GROUP BY product_id, product_detail
HAVING COUNT(DISTINCT unit_price) > 1
ORDER BY CAST(product_id AS UNSIGNED);

-- 1e. Each store_id maps to exactly one location (3 rows)
SELECT store_id, store_location, COUNT(*) AS n
FROM stg_sales GROUP BY store_id, store_location;

-- ---------- 2. Build the clean, typed table ----------
DROP TABLE IF EXISTS sales_clean;
CREATE TABLE sales_clean (
    transaction_id    INT           NOT NULL PRIMARY KEY,
    transaction_date  DATE          NOT NULL,
    transaction_time  TIME          NOT NULL,
    transaction_qty   SMALLINT      NOT NULL,
    store_id          TINYINT       NOT NULL,
    store_location    VARCHAR(50)   NOT NULL,
    product_id        SMALLINT      NOT NULL,
    unit_price        DECIMAL(6,2)  NOT NULL,
    product_category  VARCHAR(50)   NOT NULL,
    product_type      VARCHAR(50)   NOT NULL,
    product_detail    VARCHAR(80)   NOT NULL,
    -- derived column: revenue for this line
    line_revenue      DECIMAL(10,2) AS (transaction_qty * unit_price) STORED
);

INSERT INTO sales_clean
    (transaction_id, transaction_date, transaction_time, transaction_qty,
     store_id, store_location, product_id, unit_price,
     product_category, product_type, product_detail)
SELECT
    CAST(TRIM(transaction_id) AS UNSIGNED),
    STR_TO_DATE(TRIM(transaction_date), '%Y-%m-%d'),
    CAST(TRIM(transaction_time) AS TIME),
    CAST(TRIM(transaction_qty) AS UNSIGNED),
    CAST(TRIM(store_id) AS UNSIGNED),
    TRIM(store_location),
    CAST(TRIM(product_id) AS UNSIGNED),
    CAST(TRIM(unit_price) AS DECIMAL(6,2)),
    TRIM(product_category),
    TRIM(product_type),
    TRIM(product_detail)            -- fixes 'Scottish Cream Scone '
FROM stg_sales;

-- ---------- 3. Validation: the clean table must reconcile ----------
SELECT
    COUNT(*)                         AS row_count,        -- 149116
    MIN(transaction_date)            AS first_day,        -- 2023-01-01
    MAX(transaction_date)            AS last_day,         -- 2023-06-30
    SUM(line_revenue)                AS total_revenue,    -- 698812.33
    SUM(transaction_qty)             AS total_units,      -- 214470
    SUM(unit_price <= 0)             AS bad_prices,       -- 0
    SUM(transaction_qty <= 0)        AS bad_qty,          -- 0
    COUNT(DISTINCT product_detail)   AS products          -- 80
FROM sales_clean;

-- Helpful indexes for the analysis queries
CREATE INDEX ix_sales_date    ON sales_clean (transaction_date);
CREATE INDEX ix_sales_store   ON sales_clean (store_id);
CREATE INDEX ix_sales_product ON sales_clean (product_id);
