-- ============================================================================
-- SEGMENT 3: PLAYER RETENTION & CHURN
-- Who stays? Who leaves? How long do they play?
-- Source: Altenar, EveryMatrix, Smartico, GR8 Tech
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 3.1 PLAYER ACTIVITY WINDOW
-- First and last activity date per player
-- ----------------------------------------------------------------------------
WITH player_activity AS (
    SELECT UserID, MIN(Date) AS first_play, MAX(Date) AS last_play
    FROM cashgames_clean
    GROUP BY UserID
    
    UNION ALL
    
    SELECT UserID, MIN(Date) AS first_play, MAX(Date) AS last_play
    FROM tournaments_clean
    GROUP BY UserID
)
SELECT 
    UserID,
    MIN(first_play) AS first_activity,
    MAX(last_play) AS last_activity,
    MAX(last_play) - MIN(first_play) AS days_active
FROM player_activity
GROUP BY UserID
ORDER BY days_active DESC
LIMIT 20;


-- ----------------------------------------------------------------------------
-- 3.2 AVERAGE PLAYER LIFESPAN
-- How long do players stay active on average?
-- ----------------------------------------------------------------------------
WITH player_lifespan AS (
    SELECT 
        UserID,
        MIN(Date) AS first_play,
        MAX(Date) AS last_play,
        MAX(Date) - MIN(Date) AS lifespan_days
    FROM (
        SELECT UserID, Date FROM cashgames_clean
        UNION ALL
        SELECT UserID, Date FROM tournaments_clean
    ) all_play
    GROUP BY UserID
)
SELECT 
    COUNT(*) AS total_players,
    ROUND(AVG(lifespan_days)::NUMERIC, 0) AS avg_lifespan_days,
    ROUND((PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY lifespan_days))::NUMERIC, 0) AS median_lifespan_days,
    MIN(lifespan_days) AS min_lifespan,
    MAX(lifespan_days) AS max_lifespan
FROM player_lifespan;
-- ----------------------------------------------------------------------------
-- 3.3 RETENTION BUCKETS
-- Categorize players by how long they remained active
-- ----------------------------------------------------------------------------
WITH player_lifespan AS (
    SELECT 
        UserID,
        MAX(Date) - MIN(Date) AS lifespan_days
    FROM (
        SELECT UserID, Date FROM cashgames_clean
        UNION ALL
        SELECT UserID, Date FROM tournaments_clean
    ) all_play
    GROUP BY UserID
)
SELECT 
    CASE 
        WHEN lifespan_days = 0 THEN '1 day only'
        WHEN lifespan_days BETWEEN 1 AND 7 THEN '2-7 days'
        WHEN lifespan_days BETWEEN 8 AND 30 THEN '8-30 days'
        WHEN lifespan_days BETWEEN 31 AND 90 THEN '1-3 months'
        WHEN lifespan_days BETWEEN 91 AND 180 THEN '3-6 months'
        WHEN lifespan_days BETWEEN 181 AND 365 THEN '6-12 months'
        ELSE '12+ months'
    END AS retention_bucket,
    COUNT(*) AS player_count,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS pct
FROM player_lifespan
GROUP BY 
    CASE 
        WHEN lifespan_days = 0 THEN '1 day only'
        WHEN lifespan_days BETWEEN 1 AND 7 THEN '2-7 days'
        WHEN lifespan_days BETWEEN 8 AND 30 THEN '8-30 days'
        WHEN lifespan_days BETWEEN 31 AND 90 THEN '1-3 months'
        WHEN lifespan_days BETWEEN 91 AND 180 THEN '3-6 months'
        WHEN lifespan_days BETWEEN 181 AND 365 THEN '6-12 months'
        ELSE '12+ months'
    END
ORDER BY 
    MIN(lifespan_days);


-- ----------------------------------------------------------------------------
-- 3.4 MONTHLY ACTIVE PLAYERS (MAU)
-- Trend of unique players per month
-- ----------------------------------------------------------------------------
SELECT 
    DATE_TRUNC('month', Date) AS month,
    COUNT(DISTINCT UserID) AS monthly_active_players
FROM (
    SELECT UserID, Date FROM cashgames_clean
    UNION ALL
    SELECT UserID, Date FROM tournaments_clean
) all_play
GROUP BY DATE_TRUNC('month', Date)
ORDER BY month;


-- ----------------------------------------------------------------------------
-- 3.5 PLAYER CHURN IDENTIFICATION
-- Players inactive for 90+ days as of last data date
-- ----------------------------------------------------------------------------
WITH player_lifespan AS (
    SELECT 
        UserID,
        MAX(Date) - MIN(Date) AS lifespan_days
    FROM (
        SELECT UserID, Date FROM cashgames_clean
        UNION ALL
        SELECT UserID, Date FROM tournaments_clean
    ) all_play
    GROUP BY UserID
),
bucketed AS (
    SELECT 
        CASE 
            WHEN lifespan_days = 0 THEN '1 day only'
            WHEN lifespan_days BETWEEN 1 AND 7 THEN '2-7 days'
            WHEN lifespan_days BETWEEN 8 AND 30 THEN '8-30 days'
            WHEN lifespan_days BETWEEN 31 AND 90 THEN '1-3 months'
            WHEN lifespan_days BETWEEN 91 AND 180 THEN '3-6 months'
            WHEN lifespan_days BETWEEN 181 AND 365 THEN '6-12 months'
            ELSE '12+ months'
        END AS retention_bucket,
        CASE 
            WHEN lifespan_days = 0 THEN 1
            WHEN lifespan_days BETWEEN 1 AND 7 THEN 2
            WHEN lifespan_days BETWEEN 8 AND 30 THEN 3
            WHEN lifespan_days BETWEEN 31 AND 90 THEN 4
            WHEN lifespan_days BETWEEN 91 AND 180 THEN 5
            WHEN lifespan_days BETWEEN 181 AND 365 THEN 6
            ELSE 7
        END AS sort_order
    FROM player_lifespan
)
SELECT 
    retention_bucket,
    COUNT(*) AS player_count,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS pct
FROM bucketed
GROUP BY retention_bucket, sort_order
ORDER BY sort_order;


-- ----------------------------------------------------------------------------
-- 3.6 DAYS BETWEEN SESSIONS
-- How frequently do players return?
-- ----------------------------------------------------------------------------
WITH play_dates AS (
    SELECT DISTINCT UserID, Date
    FROM (
        SELECT UserID, Date FROM cashgames_clean
        UNION ALL
        SELECT UserID, Date FROM tournaments_clean
    ) all_play
),
days_between AS (
    SELECT 
        UserID,
        Date,
        LAG(Date) OVER (PARTITION BY UserID ORDER BY Date) AS prev_date,
        Date - LAG(Date) OVER (PARTITION BY UserID ORDER BY Date) AS days_gap
    FROM play_dates
)
SELECT 
    ROUND(AVG(days_gap)::NUMERIC, 1) AS avg_days_between_sessions,
    ROUND((PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY days_gap))::NUMERIC, 1) AS median_days_between,
    MIN(days_gap) AS min_gap,
    MAX(days_gap) AS max_gap
FROM days_between
WHERE days_gap IS NOT NULL AND days_gap > 0;


-- ----------------------------------------------------------------------------
-- 3.7 COHORT RETENTION (By First Play Month)
-- Do newer cohorts retain better?
-- ----------------------------------------------------------------------------
WITH player_first_month AS (
    SELECT 
        UserID,
        DATE_TRUNC('month', MIN(Date)) AS cohort_month
    FROM (
        SELECT UserID, Date FROM cashgames_clean
        UNION ALL
        SELECT UserID, Date FROM tournaments_clean
    ) all_play
    GROUP BY UserID
),
player_months_active AS (
    SELECT DISTINCT 
        UserID,
        DATE_TRUNC('month', Date) AS active_month
    FROM (
        SELECT UserID, Date FROM cashgames_clean
        UNION ALL
        SELECT UserID, Date FROM tournaments_clean
    ) all_play
)
SELECT 
    pfm.cohort_month,
    COUNT(DISTINCT pfm.UserID) AS cohort_size,
    COUNT(DISTINCT CASE WHEN pma.active_month = pfm.cohort_month + INTERVAL '1 month' THEN pfm.UserID END) AS month_1_retained,
    ROUND(100.0 * COUNT(DISTINCT CASE WHEN pma.active_month = pfm.cohort_month + INTERVAL '1 month' THEN pfm.UserID END) / COUNT(DISTINCT pfm.UserID), 2) AS month_1_retention_pct
FROM player_first_month pfm
LEFT JOIN player_months_active pma ON pfm.UserID = pma.UserID
GROUP BY pfm.cohort_month
ORDER BY pfm.cohort_month;
