-- =============================================================
-- 04_star_schema.sql  |  Star schema for reporting
--
--                 dim_date
--                    |
--   dim_product -- fact_sales -- dim_store
--
-- One fact table (one row per transaction line, the "grain")
-- surrounded by descriptive dimension tables.
-- =============================================================
USE coffee_shop;

DROP TABLE IF EXISTS fact_sales;
DROP TABLE IF EXISTS dim_date;
DROP TABLE IF EXISTS dim_product;
DROP TABLE IF EXISTS dim_store;

-- ---------- dim_store (outlet) ----------
CREATE TABLE dim_store (
    store_id        TINYINT     PRIMARY KEY,
    store_location  VARCHAR(50) NOT NULL
);
INSERT INTO dim_store
SELECT DISTINCT store_id, store_location FROM sales_clean;

-- ---------- dim_product ----------
-- unit_price is deliberately NOT here: 15 products were sold at more
-- than one price, so price belongs to the sale (the fact), not the product.
CREATE TABLE dim_product (
    product_id        SMALLINT    PRIMARY KEY,
    product_detail    VARCHAR(80) NOT NULL,
    product_type      VARCHAR(50) NOT NULL,
    product_category  VARCHAR(50) NOT NULL,
    cup_size          VARCHAR(10) NOT NULL
);
INSERT INTO dim_product
SELECT DISTINCT
    product_id,
    product_detail,
    product_type,
    product_category,
    CASE
        WHEN product_detail LIKE '% Lg' THEN 'Large'
        WHEN product_detail LIKE '% Rg' THEN 'Regular'
        WHEN product_detail LIKE '% Sm' THEN 'Small'
        ELSE 'n/a'
    END
FROM sales_clean;

-- ---------- dim_date ----------
-- Built with a RECURSIVE CTE so every calendar day exists, even a day
-- with zero sales (important for time intelligence in Power BI).
CREATE TABLE dim_date (
    date_key      INT         PRIMARY KEY,      -- e.g. 20230115
    full_date     DATE        NOT NULL UNIQUE,
    year          SMALLINT    NOT NULL,
    quarter       TINYINT     NOT NULL,
    month_num     TINYINT     NOT NULL,
    month_name    VARCHAR(10) NOT NULL,
    month_short   CHAR(3)     NOT NULL,
    month_label   CHAR(7)     NOT NULL,         -- e.g. 2023-01 (YEAR_MONTH is a reserved word)
    day_of_month  TINYINT     NOT NULL,
    weekday_num   TINYINT     NOT NULL,         -- 1 = Monday ... 7 = Sunday
    weekday_name  VARCHAR(10) NOT NULL,
    is_weekend    TINYINT     NOT NULL
);

INSERT INTO dim_date
WITH RECURSIVE calendar AS (
    SELECT DATE('2023-01-01') AS d
    UNION ALL
    SELECT d + INTERVAL 1 DAY FROM calendar WHERE d < '2023-06-30'
)
SELECT
    CAST(DATE_FORMAT(d, '%Y%m%d') AS UNSIGNED),
    d,
    YEAR(d),
    QUARTER(d),
    MONTH(d),
    MONTHNAME(d),
    LEFT(MONTHNAME(d), 3),
    DATE_FORMAT(d, '%Y-%m'),
    DAY(d),
    WEEKDAY(d) + 1,
    DAYNAME(d),
    WEEKDAY(d) >= 5
FROM calendar;

-- ---------- fact_sales ----------
CREATE TABLE fact_sales (
    transaction_id    INT           PRIMARY KEY,
    date_key          INT           NOT NULL,
    transaction_time  TIME          NOT NULL,
    hour_of_day       TINYINT       NOT NULL,
    store_id          TINYINT       NOT NULL,
    product_id        SMALLINT      NOT NULL,
    transaction_qty   SMALLINT      NOT NULL,
    unit_price        DECIMAL(6,2)  NOT NULL,
    line_revenue      DECIMAL(10,2) NOT NULL,
    CONSTRAINT fk_fact_date    FOREIGN KEY (date_key)   REFERENCES dim_date(date_key),
    CONSTRAINT fk_fact_store   FOREIGN KEY (store_id)   REFERENCES dim_store(store_id),
    CONSTRAINT fk_fact_product FOREIGN KEY (product_id) REFERENCES dim_product(product_id)
);

INSERT INTO fact_sales
SELECT
    transaction_id,
    CAST(DATE_FORMAT(transaction_date, '%Y%m%d') AS UNSIGNED),
    transaction_time,
    HOUR(transaction_time),
    store_id,
    product_id,
    transaction_qty,
    unit_price,
    line_revenue
FROM sales_clean;

-- ---------- Checks ----------
SELECT 'dim_store'   AS tbl, COUNT(*) AS n FROM dim_store   UNION ALL   -- 3
SELECT 'dim_product',        COUNT(*)      FROM dim_product UNION ALL   -- 80
SELECT 'dim_date',           COUNT(*)      FROM dim_date    UNION ALL   -- 181
SELECT 'fact_sales',         COUNT(*)      FROM fact_sales;             -- 149116

-- The star schema must give the same answer as the flat table
SELECT d.month_name, s.store_location, SUM(f.line_revenue) AS revenue
FROM fact_sales f
JOIN dim_date  d ON d.date_key = f.date_key
JOIN dim_store s ON s.store_id = f.store_id
GROUP BY d.month_num, d.month_name, s.store_location
ORDER BY d.month_num, revenue DESC
LIMIT 3;

SELECT SUM(line_revenue) AS fact_total FROM fact_sales;   -- 698812.33
