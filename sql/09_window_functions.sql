-- ============================================================================
-- SEGMENT 9: WINDOW FUNCTIONS
-- Advanced SQL: RANK, LAG, LEAD, SUM OVER, PARTITION BY
-- This proves you know "real" SQL, not just basics
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 9.1 RANK PLAYERS BY TOTAL DEPOSITS
-- RANK() OVER (ORDER BY ...)
-- ----------------------------------------------------------------------------
SELECT 
    UserID,
    SUM(Amount) AS total_deposited,
    RANK() OVER (ORDER BY SUM(Amount) DESC) AS deposit_rank,
    DENSE_RANK() OVER (ORDER BY SUM(Amount) DESC) AS dense_rank,
    NTILE(10) OVER (ORDER BY SUM(Amount) DESC) AS decile
FROM deposits_clean
WHERE Status = 'S'
GROUP BY UserID
ORDER BY total_deposited DESC
LIMIT 20;


-- ----------------------------------------------------------------------------
-- 9.2 RANK PLAYERS BY DEPOSITS WITHIN EACH COUNTRY
-- PARTITION BY + RANK
-- ----------------------------------------------------------------------------
WITH player_deposits AS (
    SELECT 
        d.UserID,
        d.CountryID,
        SUM(dep.Amount) AS total_deposited
    FROM demographics_clean d
    JOIN deposits_clean dep ON d.UserID = dep.UserID
    WHERE dep.Status = 'S' AND d.CountryID IS NOT NULL
    GROUP BY d.UserID, d.CountryID
)
SELECT 
    UserID,
    CountryID,
    total_deposited,
    RANK() OVER (PARTITION BY CountryID ORDER BY total_deposited DESC) AS rank_in_country
FROM player_deposits
WHERE total_deposited > 0
ORDER BY CountryID, rank_in_country
LIMIT 50;


-- ----------------------------------------------------------------------------
-- 9.3 RUNNING TOTAL OF DEPOSITS PER PLAYER
-- SUM() OVER (PARTITION BY ... ORDER BY ...)
-- ----------------------------------------------------------------------------
SELECT 
    UserID,
    ProcessDate,
    Amount,
    SUM(Amount) OVER (PARTITION BY UserID ORDER BY ProcessDate, ProcessTime) AS running_total,
    COUNT(*) OVER (PARTITION BY UserID ORDER BY ProcessDate, ProcessTime) AS deposit_number
FROM deposits_clean
WHERE Status = 'S' AND UserID IN (SELECT UserID FROM deposits_clean GROUP BY UserID HAVING COUNT(*) >= 10 LIMIT 5)
ORDER BY UserID, ProcessDate, ProcessTime;


-- ----------------------------------------------------------------------------
-- 9.4 DAYS SINCE PREVIOUS DEPOSIT (LAG)
-- LAG() OVER (PARTITION BY ... ORDER BY ...)
-- ----------------------------------------------------------------------------
WITH deposit_gaps AS (
    SELECT 
        UserID,
        ProcessDate,
        Amount,
        LAG(ProcessDate) OVER (PARTITION BY UserID ORDER BY ProcessDate, ProcessTime) AS prev_deposit_date,
        ProcessDate - LAG(ProcessDate) OVER (PARTITION BY UserID ORDER BY ProcessDate, ProcessTime) AS days_since_prev
    FROM deposits_clean
    WHERE Status = 'S'
)
SELECT 
    UserID,
    ProcessDate,
    Amount,
    prev_deposit_date,
    days_since_prev
FROM deposit_gaps
WHERE days_since_prev IS NOT NULL
ORDER BY UserID, ProcessDate
LIMIT 50;


-- ----------------------------------------------------------------------------
-- 9.5 AVERAGE DAYS BETWEEN DEPOSITS PER PLAYER
-- Aggregating LAG results
-- ----------------------------------------------------------------------------
WITH deposit_gaps AS (
    SELECT 
        UserID,
        ProcessDate - LAG(ProcessDate) OVER (PARTITION BY UserID ORDER BY ProcessDate, ProcessTime) AS days_gap
    FROM deposits_clean
    WHERE Status = 'S'
)
SELECT 
    UserID,
    COUNT(*) AS num_gaps,
    ROUND(AVG(days_gap), 1) AS avg_days_between_deposits,
    MIN(days_gap) AS min_gap,
    MAX(days_gap) AS max_gap
FROM deposit_gaps
WHERE days_gap IS NOT NULL
GROUP BY UserID
HAVING COUNT(*) >= 5
ORDER BY avg_days_between_deposits
LIMIT 20;


-- ----------------------------------------------------------------------------
-- 9.6 MONTH-OVER-MONTH DEPOSIT CHANGE
-- LAG for time series comparison
-- ----------------------------------------------------------------------------
WITH monthly_deposits AS (
    SELECT 
        DATE_TRUNC('month', ProcessDate) AS month,
        SUM(Amount) AS monthly_total
    FROM deposits_clean
    WHERE Status = 'S'
    GROUP BY DATE_TRUNC('month', ProcessDate)
)
SELECT 
    month,
    monthly_total,
    LAG(monthly_total) OVER (ORDER BY month) AS prev_month_total,
    monthly_total - LAG(monthly_total) OVER (ORDER BY month) AS mom_change,
    ROUND(100.0 * (monthly_total - LAG(monthly_total) OVER (ORDER BY month)) / 
          NULLIF(LAG(monthly_total) OVER (ORDER BY month), 0), 2) AS mom_change_pct
FROM monthly_deposits
ORDER BY month;


-- ----------------------------------------------------------------------------
-- 9.7 MONTH-OVER-MONTH GGR CHANGE
-- Trading margin trend with LAG
-- ----------------------------------------------------------------------------
WITH monthly_ggr AS (
    SELECT 
        DATE_TRUNC('month', Date) AS month,
        SUM(StakesC) - SUM(WinningsC) AS monthly_ggr
    FROM cashgames_clean
    GROUP BY DATE_TRUNC('month', Date)
)
SELECT 
    month,
    ROUND(monthly_ggr, 2) AS ggr,
    ROUND(LAG(monthly_ggr) OVER (ORDER BY month), 2) AS prev_month_ggr,
    ROUND(monthly_ggr - LAG(monthly_ggr) OVER (ORDER BY month), 2) AS mom_change,
    ROUND(100.0 * (monthly_ggr - LAG(monthly_ggr) OVER (ORDER BY month)) / 
          NULLIF(ABS(LAG(monthly_ggr) OVER (ORDER BY month)), 0), 2) AS mom_change_pct
FROM monthly_ggr
ORDER BY month;


-- ----------------------------------------------------------------------------
-- 9.8 CUMULATIVE MONTHLY DEPOSITS (Running Total by Month)
-- SUM() OVER (ORDER BY ...) without PARTITION
-- ----------------------------------------------------------------------------
WITH monthly_deposits AS (
    SELECT 
        DATE_TRUNC('month', ProcessDate) AS month,
        SUM(Amount) AS monthly_total
    FROM deposits_clean
    WHERE Status = 'S'
    GROUP BY DATE_TRUNC('month', ProcessDate)
)
SELECT 
    month,
    monthly_total,
    SUM(monthly_total) OVER (ORDER BY month) AS cumulative_deposits
FROM monthly_deposits
ORDER BY month;


-- ----------------------------------------------------------------------------
-- 9.9 PLAYER'S FIRST AND LAST DEPOSIT (FIRST_VALUE, LAST_VALUE)
-- ----------------------------------------------------------------------------
WITH player_deposits AS (
    SELECT 
        UserID,
        ProcessDate,
        Amount,
        FIRST_VALUE(Amount) OVER (PARTITION BY UserID ORDER BY ProcessDate, ProcessTime) AS first_deposit,
        FIRST_VALUE(ProcessDate) OVER (PARTITION BY UserID ORDER BY ProcessDate, ProcessTime) AS first_deposit_date,
        LAST_VALUE(Amount) OVER (PARTITION BY UserID ORDER BY ProcessDate, ProcessTime 
            ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) AS last_deposit,
        LAST_VALUE(ProcessDate) OVER (PARTITION BY UserID ORDER BY ProcessDate, ProcessTime 
            ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING) AS last_deposit_date
    FROM deposits_clean
    WHERE Status = 'S'
)
SELECT DISTINCT
    UserID,
    first_deposit_date,
    first_deposit AS first_deposit_amount,
    last_deposit_date,
    last_deposit AS last_deposit_amount
FROM player_deposits
ORDER BY UserID
LIMIT 20;


-- ----------------------------------------------------------------------------
-- 9.10 MOVING AVERAGE (3-Month) OF GGR
-- AVG() OVER (ORDER BY ... ROWS BETWEEN)
-- ----------------------------------------------------------------------------
WITH monthly_ggr AS (
    SELECT 
        DATE_TRUNC('month', Date) AS month,
        SUM(StakesC) - SUM(WinningsC) AS monthly_ggr
    FROM cashgames_clean
    GROUP BY DATE_TRUNC('month', Date)
)
SELECT 
    month,
    ROUND(monthly_ggr, 2) AS ggr,
    ROUND(AVG(monthly_ggr) OVER (ORDER BY month ROWS BETWEEN 2 PRECEDING AND CURRENT ROW), 2) AS moving_avg_3m
FROM monthly_ggr
ORDER BY month;


-- ----------------------------------------------------------------------------
-- 9.11 PERCENT OF TOTAL (Window Aggregate)
-- Calculate each player's % contribution
-- ----------------------------------------------------------------------------
WITH player_deposits AS (
    SELECT 
        UserID,
        SUM(Amount) AS total_deposited
    FROM deposits_clean
    WHERE Status = 'S'
    GROUP BY UserID
)
SELECT 
    UserID,
    total_deposited,
    ROUND(100.0 * total_deposited / SUM(total_deposited) OVER (), 4) AS pct_of_total,
    SUM(total_deposited) OVER (ORDER BY total_deposited DESC) AS running_total,
    ROUND(100.0 * SUM(total_deposited) OVER (ORDER BY total_deposited DESC) / 
          SUM(total_deposited) OVER (), 2) AS cumulative_pct
FROM player_deposits
ORDER BY total_deposited DESC
LIMIT 30;


-- ----------------------------------------------------------------------------
-- 9.12 ROW_NUMBER FOR DEDUPLICATION / IDENTIFYING FIRST RECORD
-- Common use case in data cleaning
-- ----------------------------------------------------------------------------
WITH ranked_deposits AS (
    SELECT 
        UserID,
        DepositID,
        ProcessDate,
        Amount,
        PayMethCat,
        ROW_NUMBER() OVER (PARTITION BY UserID ORDER BY ProcessDate, ProcessTime) AS deposit_sequence
    FROM deposits_clean
    WHERE Status = 'S'
)
SELECT *
FROM ranked_deposits
WHERE deposit_sequence = 1  -- First deposit only
ORDER BY UserID
LIMIT 20;
