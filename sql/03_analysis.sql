-- =============================================================
-- 03_analysis.sql  |  Business questions, answered in SQL
-- Concepts: GROUP BY, CTEs (WITH ...), window functions
--           (LAG, RANK, ROW_NUMBER, SUM() OVER, AVG() OVER)
-- Works on MySQL 8.0+ (window functions need 8.0).
-- =============================================================
-- IMPORTANT DATA NOTE: there is no receipt/basket ID. Each row is ONE
-- transaction line (one product, qty 1–8). So "average ticket" here
-- means average revenue per transaction line, not per customer receipt.
-- =============================================================
USE coffee_shop;

-- -------------------------------------------------------------
-- Q1. Monthly revenue trend + month-over-month growth %
--     CTE = a named temporary result you can query like a table.
--     LAG() = "look at the previous row" without a self-join.
-- -------------------------------------------------------------
WITH monthly AS (
    SELECT
        DATE_FORMAT(transaction_date, '%Y-%m') AS month,
        SUM(line_revenue)                      AS revenue,
        COUNT(*)                               AS transactions,
        SUM(transaction_qty)                   AS units
    FROM sales_clean
    GROUP BY DATE_FORMAT(transaction_date, '%Y-%m')
)
SELECT
    month,
    revenue,
    transactions,
    units,
    LAG(revenue) OVER (ORDER BY month)                       AS prev_revenue,
    ROUND(100 * (revenue - LAG(revenue) OVER (ORDER BY month))
              / LAG(revenue) OVER (ORDER BY month), 1)       AS mom_growth_pct
FROM monthly
ORDER BY month;

-- -------------------------------------------------------------
-- Q2. Monthly revenue by outlet, with each outlet's share of the month
--     SUM() OVER (PARTITION BY month) = month total on every row.
-- -------------------------------------------------------------
WITH store_month AS (
    SELECT
        DATE_FORMAT(transaction_date, '%Y-%m') AS month,
        store_location,
        SUM(line_revenue)                      AS revenue
    FROM sales_clean
    GROUP BY month, store_location
)
SELECT
    month,
    store_location,
    revenue,
    ROUND(100 * revenue / SUM(revenue) OVER (PARTITION BY month), 1) AS share_of_month_pct
FROM store_month
ORDER BY month, revenue DESC;

-- -------------------------------------------------------------
-- Q3. Top 10 products by revenue, with share of total
--     RANK() handles ties; SUM() OVER () with empty brackets = grand total.
-- -------------------------------------------------------------
WITH product_rev AS (
    SELECT
        product_detail,
        product_category,
        SUM(line_revenue)    AS revenue,
        SUM(transaction_qty) AS units
    FROM sales_clean
    GROUP BY product_detail, product_category
)
SELECT *
FROM (
    SELECT
        RANK() OVER (ORDER BY revenue DESC)                 AS revenue_rank,
        product_detail,
        product_category,
        revenue,
        units,
        ROUND(100 * revenue / SUM(revenue) OVER (), 2)      AS share_pct
    FROM product_rev
) ranked
WHERE revenue_rank <= 10
ORDER BY revenue_rank;

-- -------------------------------------------------------------
-- Q4. Revenue by category (the big picture behind Q3)
-- -------------------------------------------------------------
SELECT
    product_category,
    SUM(line_revenue)                                         AS revenue,
    ROUND(100 * SUM(line_revenue) / SUM(SUM(line_revenue)) OVER (), 1) AS share_pct
FROM sales_clean
GROUP BY product_category
ORDER BY revenue DESC;

-- -------------------------------------------------------------
-- Q5. Best-selling product in EACH category
--     ROW_NUMBER() OVER (PARTITION BY ...) = "top-N per group" pattern.
-- -------------------------------------------------------------
WITH ranked AS (
    SELECT
        product_category,
        product_detail,
        SUM(line_revenue) AS revenue,
        ROW_NUMBER() OVER (PARTITION BY product_category
                           ORDER BY SUM(line_revenue) DESC) AS rn
    FROM sales_clean
    GROUP BY product_category, product_detail
)
SELECT product_category, product_detail, revenue
FROM ranked
WHERE rn = 1
ORDER BY revenue DESC;

-- -------------------------------------------------------------
-- Q6. Busiest days of the week
--     Average per day (not just total) because some weekdays occur
--     more often than others in a 181-day period.
-- -------------------------------------------------------------
WITH daily AS (
    SELECT
        transaction_date,
        SUM(line_revenue) AS revenue,
        COUNT(*)          AS transactions
    FROM sales_clean
    GROUP BY transaction_date
)
SELECT
    DAYNAME(transaction_date)          AS weekday,
    COUNT(*)                           AS days_in_period,
    ROUND(AVG(revenue), 2)             AS avg_daily_revenue,
    ROUND(AVG(transactions), 0)        AS avg_daily_transactions
FROM daily
GROUP BY DAYNAME(transaction_date), WEEKDAY(transaction_date)
ORDER BY WEEKDAY(transaction_date);   -- Monday first

-- -------------------------------------------------------------
-- Q7. Busiest hours of the day
-- -------------------------------------------------------------
SELECT
    HOUR(transaction_time)                                     AS hour_of_day,
    COUNT(*)                                                   AS transactions,
    SUM(line_revenue)                                          AS revenue,
    ROUND(100 * SUM(line_revenue) / SUM(SUM(line_revenue)) OVER (), 1) AS share_pct
FROM sales_clean
GROUP BY HOUR(transaction_time)
ORDER BY hour_of_day;

-- -------------------------------------------------------------
-- Q8. Peak hour per outlet (ROW_NUMBER again)
-- -------------------------------------------------------------
WITH store_hour AS (
    SELECT
        store_location,
        HOUR(transaction_time) AS hour_of_day,
        COUNT(*)               AS transactions,
        ROW_NUMBER() OVER (PARTITION BY store_location
                           ORDER BY COUNT(*) DESC) AS rn
    FROM sales_clean
    GROUP BY store_location, HOUR(transaction_time)
)
SELECT store_location, hour_of_day AS peak_hour, transactions
FROM store_hour
WHERE rn = 1;

-- -------------------------------------------------------------
-- Q9. Average ticket size (revenue per transaction line)
--     overall, by outlet, and by month
-- -------------------------------------------------------------
SELECT 'All outlets' AS scope,
       ROUND(SUM(line_revenue) / COUNT(*), 2)        AS avg_ticket,
       ROUND(SUM(transaction_qty) / COUNT(*), 2)     AS avg_items_per_txn
FROM sales_clean
UNION ALL
SELECT store_location,
       ROUND(SUM(line_revenue) / COUNT(*), 2),
       ROUND(SUM(transaction_qty) / COUNT(*), 2)
FROM sales_clean
GROUP BY store_location;

SELECT
    DATE_FORMAT(transaction_date, '%Y-%m')  AS month,
    ROUND(SUM(line_revenue) / COUNT(*), 2)  AS avg_ticket
FROM sales_clean
GROUP BY month
ORDER BY month;

-- -------------------------------------------------------------
-- Q10. Running total of revenue (year-to-date) and 7-day moving average
--      SUM() OVER (ORDER BY ...) = running total.
--      ROWS BETWEEN 6 PRECEDING AND CURRENT ROW = 7-day window.
-- -------------------------------------------------------------
WITH daily AS (
    SELECT transaction_date, SUM(line_revenue) AS revenue
    FROM sales_clean
    GROUP BY transaction_date
)
SELECT
    transaction_date,
    revenue,
    SUM(revenue) OVER (ORDER BY transaction_date)             AS running_total_ytd,
    SUM(revenue) OVER (PARTITION BY DATE_FORMAT(transaction_date, '%Y-%m')
                       ORDER BY transaction_date)             AS running_total_mtd,
    ROUND(AVG(revenue) OVER (ORDER BY transaction_date
                             ROWS BETWEEN 6 PRECEDING AND CURRENT ROW), 2) AS moving_avg_7d
FROM daily
ORDER BY transaction_date;

-- -------------------------------------------------------------
-- Q11. Pareto: how many products make up 80% of revenue?
--      Running share of revenue, products sorted best to worst.
-- -------------------------------------------------------------
WITH product_rev AS (
    SELECT product_detail, SUM(line_revenue) AS revenue
    FROM sales_clean
    GROUP BY product_detail
),
cumulative AS (
    SELECT
        product_detail,
        revenue,
        ROW_NUMBER() OVER (ORDER BY revenue DESC)                     AS product_rank,
        SUM(revenue) OVER (ORDER BY revenue DESC, product_detail)
            / SUM(revenue) OVER ()                                    AS cum_share
    FROM product_rev
)
SELECT
    MIN(product_rank) AS products_needed_for_80pct,
    (SELECT COUNT(*) FROM product_rev) AS total_products
FROM cumulative
WHERE cum_share >= 0.80;

-- -------------------------------------------------------------
-- Q12. Revenue per trading day by month
--      Sanity check on Q1: February looks like a -6.8% drop, but it
--      only has 28 days. Per day, February actually GREW vs January.
-- -------------------------------------------------------------
SELECT
    DATE_FORMAT(transaction_date, '%Y-%m')                              AS month,
    COUNT(DISTINCT transaction_date)                                    AS trading_days,
    ROUND(SUM(line_revenue) / COUNT(DISTINCT transaction_date), 2)      AS revenue_per_day
FROM sales_clean
GROUP BY month
ORDER BY month;
