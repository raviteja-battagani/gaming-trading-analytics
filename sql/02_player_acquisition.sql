-- ============================================================================
-- SEGMENT 2: PLAYER ACQUISITION
-- Who's signing up? Demographics and first deposit behavior
-- Source: Industry standard, Slotegrator
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 2.1 TOTAL PLAYER COUNT
-- ----------------------------------------------------------------------------
SELECT COUNT(*) AS total_players
FROM demographics_clean;


-- ----------------------------------------------------------------------------
-- 2.2 SIGNUPS BY COUNTRY
-- Which markets are we acquiring from?
-- ----------------------------------------------------------------------------
SELECT 
    CountryID,
    COUNT(*) AS player_count,
    ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM demographics_clean), 2) AS pct_of_total
FROM demographics_clean
WHERE CountryID IS NOT NULL
GROUP BY CountryID
ORDER BY player_count DESC
LIMIT 15;


-- ----------------------------------------------------------------------------
-- 2.3 AGE DISTRIBUTION
-- What age groups are we acquiring?
-- ----------------------------------------------------------------------------
SELECT 
    CASE 
        WHEN SystemAgeAsOfReg < 21 THEN 'Under 21'
        WHEN SystemAgeAsOfReg BETWEEN 21 AND 25 THEN '21-25'
        WHEN SystemAgeAsOfReg BETWEEN 26 AND 30 THEN '26-30'
        WHEN SystemAgeAsOfReg BETWEEN 31 AND 35 THEN '31-35'
        WHEN SystemAgeAsOfReg BETWEEN 36 AND 40 THEN '36-40'
        WHEN SystemAgeAsOfReg BETWEEN 41 AND 45 THEN '41-45'
        WHEN SystemAgeAsOfReg BETWEEN 46 AND 55 THEN '46-55'
        WHEN SystemAgeAsOfReg > 55 THEN '55+'
        ELSE 'Unknown'
    END AS age_group,
    COUNT(*) AS player_count,
    ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM demographics_clean), 2) AS pct
FROM demographics_clean
GROUP BY 1
ORDER BY 
    MIN(CASE 
        WHEN SystemAgeAsOfReg < 21 THEN 1
        WHEN SystemAgeAsOfReg BETWEEN 21 AND 25 THEN 2
        WHEN SystemAgeAsOfReg BETWEEN 26 AND 30 THEN 3
        WHEN SystemAgeAsOfReg BETWEEN 31 AND 35 THEN 4
        WHEN SystemAgeAsOfReg BETWEEN 36 AND 40 THEN 5
        WHEN SystemAgeAsOfReg BETWEEN 41 AND 45 THEN 6
        WHEN SystemAgeAsOfReg BETWEEN 46 AND 55 THEN 7
        WHEN SystemAgeAsOfReg > 55 THEN 8
        ELSE 9
    END);

-- ----------------------------------------------------------------------------
-- 2.4 GENDER DISTRIBUTION
-- ----------------------------------------------------------------------------
SELECT 
    Gender,
    COUNT(*) AS player_count,
    ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM demographics_clean), 2) AS pct
FROM demographics_clean
WHERE Gender IS NOT NULL
GROUP BY Gender
ORDER BY player_count DESC;


-- ----------------------------------------------------------------------------
-- 2.5 FTD CONVERSION (First Time Depositor)
-- What % of registered players made at least one deposit?
-- ----------------------------------------------------------------------------
WITH first_deposits AS (
    SELECT DISTINCT UserID
    FROM deposits_clean
    WHERE Status = 'S'
)
SELECT 
    (SELECT COUNT(*) FROM demographics_clean) AS total_signups,
    COUNT(DISTINCT fd.UserID) AS players_who_deposited,
    ROUND(100.0 * COUNT(DISTINCT fd.UserID) / (SELECT COUNT(*) FROM demographics_clean), 2) AS ftd_conversion_rate
FROM first_deposits fd;


-- ----------------------------------------------------------------------------
-- 2.6 AVERAGE FIRST DEPOSIT AMOUNT
-- ----------------------------------------------------------------------------
WITH first_deposit AS (
    SELECT 
        UserID,
        Amount,
        ROW_NUMBER() OVER (PARTITION BY UserID ORDER BY ProcessDate, ProcessTime) AS rn
    FROM deposits_clean
    WHERE Status = 'S'
)
SELECT 
    COUNT(*) AS players_with_deposits,
    ROUND(AVG(Amount)::NUMERIC, 2) AS avg_first_deposit,
    ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY Amount)::NUMERIC, 2) AS median_first_deposit,
    MIN(Amount) AS min_first_deposit,
    MAX(Amount) AS max_first_deposit
FROM first_deposit
WHERE rn = 1;


-- ----------------------------------------------------------------------------
-- 2.7 FIRST DEPOSIT BY PAYMENT METHOD
-- Which payment methods do new depositors prefer?
-- ----------------------------------------------------------------------------
WITH first_deposit AS (
    SELECT 
        UserID,
        PayMethCat,
        ROW_NUMBER() OVER (PARTITION BY UserID ORDER BY ProcessDate, ProcessTime) AS rn
    FROM deposits_clean
    WHERE Status = 'S'
)
SELECT 
    PayMethCat,
    COUNT(*) AS first_deposit_count,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS pct
FROM first_deposit
WHERE rn = 1
GROUP BY PayMethCat
ORDER BY first_deposit_count DESC;
-- ============================================================================
-- SEGMENT 2: PLAYER ACQUISITION
-- Who's signing up? Demographics and first deposit behavior
-- Source: Industry standard, Slotegrator
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 2.1 TOTAL PLAYER COUNT
-- ----------------------------------------------------------------------------
SELECT COUNT(*) AS total_players
FROM demographics_clean;


-- ----------------------------------------------------------------------------
-- 2.2 SIGNUPS BY COUNTRY
-- Which markets are we acquiring from?
-- ----------------------------------------------------------------------------
SELECT 
    CountryID,
    COUNT(*) AS player_count,
    ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM demographics_clean), 2) AS pct_of_total
FROM demographics_clean
WHERE CountryID IS NOT NULL
GROUP BY CountryID
ORDER BY player_count DESC
LIMIT 15;


-- ----------------------------------------------------------------------------
-- 2.3 AGE DISTRIBUTION
-- What age groups are we acquiring?
-- ----------------------------------------------------------------------------
SELECT 
    CASE 
        WHEN SystemAgeAsOfReg < 21 THEN 'Under 21'
        WHEN SystemAgeAsOfReg BETWEEN 21 AND 25 THEN '21-25'
        WHEN SystemAgeAsOfReg BETWEEN 26 AND 30 THEN '26-30'
        WHEN SystemAgeAsOfReg BETWEEN 31 AND 35 THEN '31-35'
        WHEN SystemAgeAsOfReg BETWEEN 36 AND 40 THEN '36-40'
        WHEN SystemAgeAsOfReg BETWEEN 41 AND 45 THEN '41-45'
        WHEN SystemAgeAsOfReg BETWEEN 46 AND 55 THEN '46-55'
        WHEN SystemAgeAsOfReg > 55 THEN '55+'
        ELSE 'Unknown'
    END AS age_group,
    COUNT(*) AS player_count,
    ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM demographics_clean), 2) AS pct
FROM demographics_clean
GROUP BY 1
ORDER BY 
    MIN(CASE 
        WHEN SystemAgeAsOfReg < 21 THEN 1
        WHEN SystemAgeAsOfReg BETWEEN 21 AND 25 THEN 2
        WHEN SystemAgeAsOfReg BETWEEN 26 AND 30 THEN 3
        WHEN SystemAgeAsOfReg BETWEEN 31 AND 35 THEN 4
        WHEN SystemAgeAsOfReg BETWEEN 36 AND 40 THEN 5
        WHEN SystemAgeAsOfReg BETWEEN 41 AND 45 THEN 6
        WHEN SystemAgeAsOfReg BETWEEN 46 AND 55 THEN 7
        WHEN SystemAgeAsOfReg > 55 THEN 8
        ELSE 9
    END);

-- ----------------------------------------------------------------------------
-- 2.4 GENDER DISTRIBUTION
-- ----------------------------------------------------------------------------
SELECT 
    Gender,
    COUNT(*) AS player_count,
    ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM demographics_clean), 2) AS pct
FROM demographics_clean
WHERE Gender IS NOT NULL
GROUP BY Gender
ORDER BY player_count DESC;


-- ----------------------------------------------------------------------------
-- 2.5 FTD CONVERSION (First Time Depositor)
-- What % of registered players made at least one deposit?
-- ----------------------------------------------------------------------------
WITH first_deposits AS (
    SELECT DISTINCT UserID
    FROM deposits_clean
    WHERE Status = 'S'
)
SELECT 
    (SELECT COUNT(*) FROM demographics_clean) AS total_signups,
    COUNT(DISTINCT fd.UserID) AS players_who_deposited,
    ROUND(100.0 * COUNT(DISTINCT fd.UserID) / (SELECT COUNT(*) FROM demographics_clean), 2) AS ftd_conversion_rate
FROM first_deposits fd;


-- ----------------------------------------------------------------------------
-- 2.6 AVERAGE FIRST DEPOSIT AMOUNT
-- ----------------------------------------------------------------------------
WITH first_deposit AS (
    SELECT 
        UserID,
        Amount,
        ROW_NUMBER() OVER (PARTITION BY UserID ORDER BY ProcessDate, ProcessTime) AS rn
    FROM deposits_clean
    WHERE Status = 'S'
)
SELECT 
    COUNT(*) AS players_with_deposits,
    ROUND(AVG(Amount)::NUMERIC, 2) AS avg_first_deposit,
    ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY Amount)::NUMERIC, 2) AS median_first_deposit,
    MIN(Amount) AS min_first_deposit,
    MAX(Amount) AS max_first_deposit
FROM first_deposit
WHERE rn = 1;


-- ----------------------------------------------------------------------------
-- 2.7 FIRST DEPOSIT BY PAYMENT METHOD
-- Which payment methods do new depositors prefer?
-- ----------------------------------------------------------------------------
WITH first_deposit AS (
    SELECT 
        UserID,
        PayMethCat,
        ROW_NUMBER() OVER (PARTITION BY UserID ORDER BY ProcessDate, ProcessTime) AS rn
    FROM deposits_clean
    WHERE Status = 'S'
)
SELECT 
    PayMethCat,
    COUNT(*) AS first_deposit_count,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS pct
FROM first_deposit
WHERE rn = 1
GROUP BY PayMethCat
ORDER BY first_deposit_count DESC;
