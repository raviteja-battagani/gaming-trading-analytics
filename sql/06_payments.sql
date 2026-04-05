-- ============================================================================
-- SEGMENT 6: PAYMENTS & TRANSACTIONS
-- Deposit/withdrawal health, payment method performance, cash flow
-- Source: Industry standard, Your Entain experience
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 6.1 DEPOSIT SUCCESS RATE BY PAYMENT METHOD
-- ----------------------------------------------------------------------------
SELECT 
    PayMethCat,
    COUNT(*) AS total_transactions,
    SUM(CASE WHEN Status = 'S' THEN 1 ELSE 0 END) AS successful,
    ROUND(100.0 * SUM(CASE WHEN Status = 'S' THEN 1 ELSE 0 END) / COUNT(*), 2) AS success_rate_pct,
    ROUND(SUM(CASE WHEN Status = 'S' THEN Amount ELSE 0 END), 2) AS successful_amount
FROM deposits_clean
GROUP BY PayMethCat
ORDER BY total_transactions DESC;


-- ----------------------------------------------------------------------------
-- 6.2 WITHDRAWAL SUCCESS RATE BY PAYMENT METHOD
-- ----------------------------------------------------------------------------
SELECT 
    PayMethCat,
    COUNT(*) AS total_transactions,
    SUM(CASE WHEN Status = 'S' THEN 1 ELSE 0 END) AS successful,
    SUM(CASE WHEN Status = 'R' THEN 1 ELSE 0 END) AS reversed,
    ROUND(100.0 * SUM(CASE WHEN Status = 'S' THEN 1 ELSE 0 END) / COUNT(*), 2) AS success_rate_pct,
    ROUND(SUM(CASE WHEN Status = 'S' THEN Amount ELSE 0 END), 2) AS successful_amount
FROM withdrawals_clean
GROUP BY PayMethCat
ORDER BY total_transactions DESC;


-- ----------------------------------------------------------------------------
-- 6.3 TOTAL DEPOSITS VS TOTAL WITHDRAWALS (Net Cash Flow)
-- ----------------------------------------------------------------------------
SELECT 
    'Deposits' AS transaction_type,
    COUNT(*) AS total_transactions,
    SUM(CASE WHEN Status = 'S' THEN 1 ELSE 0 END) AS successful_count,
    ROUND(SUM(CASE WHEN Status = 'S' THEN Amount ELSE 0 END), 2) AS successful_amount
FROM deposits_clean

UNION ALL

SELECT 
    'Withdrawals' AS transaction_type,
    COUNT(*) AS total_transactions,
    SUM(CASE WHEN Status = 'S' THEN 1 ELSE 0 END) AS successful_count,
    ROUND(SUM(CASE WHEN Status = 'S' THEN Amount ELSE 0 END), 2) AS successful_amount
FROM withdrawals_clean;


-- ----------------------------------------------------------------------------
-- 6.4 NET REVENUE TO PLATFORM
-- ----------------------------------------------------------------------------
WITH deposits_total AS (
    SELECT ROUND(SUM(Amount), 2) AS total_deposits
    FROM deposits_clean
    WHERE Status = 'S'
),
withdrawals_total AS (
    SELECT ROUND(SUM(Amount), 2) AS total_withdrawals
    FROM withdrawals_clean
    WHERE Status = 'S'
)
SELECT 
    d.total_deposits,
    w.total_withdrawals,
    d.total_deposits - w.total_withdrawals AS net_to_platform,
    ROUND(100.0 * (d.total_deposits - w.total_withdrawals) / d.total_deposits, 2) AS retention_pct
FROM deposits_total d, withdrawals_total w;


-- ----------------------------------------------------------------------------
-- 6.5 AVERAGE DEPOSIT & WITHDRAWAL AMOUNTS
-- ----------------------------------------------------------------------------
SELECT 
    'Deposits' AS type,
    COUNT(*) AS count,
    ROUND(AVG(Amount)::NUMERIC, 2) AS avg_amount,
    ROUND((PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY Amount))::NUMERIC, 2) AS median_amount,
    ROUND(MIN(Amount)::NUMERIC, 2) AS min_amount,
    ROUND(MAX(Amount)::NUMERIC, 2) AS max_amount
FROM deposits_clean
WHERE Status = 'S'

UNION ALL

SELECT 
    'Withdrawals' AS type,
    COUNT(*) AS count,
    ROUND(AVG(Amount)::NUMERIC, 2) AS avg_amount,
    ROUND((PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY Amount))::NUMERIC, 2) AS median_amount,
    ROUND(MIN(Amount)::NUMERIC, 2) AS min_amount,
    ROUND(MAX(Amount)::NUMERIC, 2) AS max_amount
FROM withdrawals_clean
WHERE Status = 'S';


-- ----------------------------------------------------------------------------
-- 6.6 MEDIAN TIME TO FIRST WITHDRAWAL
-- How long after first deposit do players withdraw?
-- ----------------------------------------------------------------------------
WITH first_deposit AS (
    SELECT 
        UserID,
        MIN(ProcessDate) AS first_deposit_date
    FROM deposits_clean
    WHERE Status = 'S'
    GROUP BY UserID
),
first_withdrawal AS (
    SELECT 
        UserID,
        MIN(ProcessDate) AS first_withdrawal_date
    FROM withdrawals_clean
    WHERE Status = 'S'
    GROUP BY UserID
)
SELECT 
    COUNT(*) AS players_who_withdrew,
    ROUND(AVG(fw.first_withdrawal_date - fd.first_deposit_date)::NUMERIC, 1) AS avg_days_to_withdrawal,
    ROUND((PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY fw.first_withdrawal_date - fd.first_deposit_date))::NUMERIC, 1) AS median_days_to_withdrawal
FROM first_deposit fd
JOIN first_withdrawal fw ON fd.UserID = fw.UserID;


-- ----------------------------------------------------------------------------
-- 6.7 PLAYERS WHO DEPOSITED BUT NEVER WITHDREW
-- Key insight: 65% of depositors never withdraw
-- ----------------------------------------------------------------------------
WITH depositors AS (
    SELECT DISTINCT UserID
    FROM deposits_clean
    WHERE Status = 'S'
),
withdrawers AS (
    SELECT DISTINCT UserID
    FROM withdrawals_clean
    WHERE Status = 'S'
)
SELECT 
    COUNT(DISTINCT d.UserID) AS total_depositors,
    COUNT(DISTINCT w.UserID) AS depositors_who_withdrew,
    COUNT(DISTINCT d.UserID) - COUNT(DISTINCT w.UserID) AS never_withdrew,
    ROUND(100.0 * (COUNT(DISTINCT d.UserID) - COUNT(DISTINCT w.UserID)) / COUNT(DISTINCT d.UserID), 2) AS never_withdrew_pct
FROM depositors d
LEFT JOIN withdrawers w ON d.UserID = w.UserID;


-- ----------------------------------------------------------------------------
-- 6.8 MONTHLY DEPOSIT & WITHDRAWAL TRENDS
-- ----------------------------------------------------------------------------
SELECT 
    'Deposits' AS type,
    DATE_TRUNC('month', ProcessDate) AS month,
    SUM(CASE WHEN Status = 'S' THEN Amount ELSE 0 END) AS amount,
    COUNT(CASE WHEN Status = 'S' THEN 1 END) AS count
FROM deposits_clean
GROUP BY DATE_TRUNC('month', ProcessDate)

UNION ALL

SELECT 
    'Withdrawals' AS type,
    DATE_TRUNC('month', ProcessDate) AS month,
    SUM(CASE WHEN Status = 'S' THEN Amount ELSE 0 END) AS amount,
    COUNT(CASE WHEN Status = 'S' THEN 1 END) AS count
FROM withdrawals_clean
GROUP BY DATE_TRUNC('month', ProcessDate)

ORDER BY month, type;


-- ----------------------------------------------------------------------------
-- 6.9 PEAK DEPOSIT HOURS
-- When do players deposit most?
-- ----------------------------------------------------------------------------
SELECT 
    EXTRACT(HOUR FROM ProcessTime) AS hour_of_day,
    COUNT(*) AS deposit_count,
    ROUND(SUM(CASE WHEN Status = 'S' THEN Amount ELSE 0 END), 2) AS deposit_amount
FROM deposits_clean
GROUP BY EXTRACT(HOUR FROM ProcessTime)
ORDER BY deposit_amount DESC;


-- ----------------------------------------------------------------------------
-- 6.10 PEAK DEPOSIT DAYS OF WEEK
-- ----------------------------------------------------------------------------
SELECT 
    EXTRACT(DOW FROM ProcessDate) AS day_of_week,
    CASE EXTRACT(DOW FROM ProcessDate)
        WHEN 0 THEN 'Sunday'
        WHEN 1 THEN 'Monday'
        WHEN 2 THEN 'Tuesday'
        WHEN 3 THEN 'Wednesday'
        WHEN 4 THEN 'Thursday'
        WHEN 5 THEN 'Friday'
        WHEN 6 THEN 'Saturday'
    END AS day_name,
    COUNT(*) AS deposit_count,
    ROUND(SUM(CASE WHEN Status = 'S' THEN Amount ELSE 0 END), 2) AS deposit_amount
FROM deposits_clean
GROUP BY EXTRACT(DOW FROM ProcessDate)
ORDER BY day_of_week;


-- ----------------------------------------------------------------------------
-- 6.11 DEPOSIT AMOUNT DISTRIBUTION
-- Buckets for Tableau visualization
-- ----------------------------------------------------------------------------
SELECT 
    CASE 
        WHEN Amount < 10 THEN '< €10'
        WHEN Amount BETWEEN 10 AND 20 THEN '€10-20'
        WHEN Amount BETWEEN 20 AND 50 THEN '€20-50'
        WHEN Amount BETWEEN 50 AND 100 THEN '€50-100'
        WHEN Amount BETWEEN 100 AND 500 THEN '€100-500'
        WHEN Amount BETWEEN 500 AND 1000 THEN '€500-1000'
        ELSE '€1000+'
    END AS deposit_bucket,
    COUNT(*) AS count,
    ROUND(SUM(Amount)::NUMERIC, 2) AS total_amount
FROM deposits_clean
WHERE Status = 'S'
GROUP BY 1
ORDER BY 
    CASE 
        WHEN MIN(Amount) < 10 THEN 1
        WHEN MIN(Amount) < 20 THEN 2
        WHEN MIN(Amount) < 50 THEN 3
        WHEN MIN(Amount) < 100 THEN 4
        WHEN MIN(Amount) < 500 THEN 5
        WHEN MIN(Amount) < 1000 THEN 6
        ELSE 7
    END;
