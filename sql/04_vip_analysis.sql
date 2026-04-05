-- ============================================================================
-- SEGMENT 4: VIP / HIGH-VALUE PLAYER ANALYSIS
-- Who are the whales? How much do they drive?
-- Source: Watson & Kale research, GR8 Tech, Smartico
-- "3% of patrons generate 90% of table revenue" - Watson & Kale (2003)
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 4.1 PLAYER TOTAL DEPOSITS (Ranked)
-- Who are the top depositors?
-- ----------------------------------------------------------------------------
SELECT 
    UserID,
    COUNT(*) AS deposit_count,
    SUM(Amount) AS total_deposited,
    ROUND(AVG(Amount), 2) AS avg_deposit,
    RANK() OVER (ORDER BY SUM(Amount) DESC) AS deposit_rank
FROM deposits_clean
WHERE Status = 'S'
GROUP BY UserID
ORDER BY total_deposited DESC
LIMIT 20;


-- ----------------------------------------------------------------------------
-- 4.2 TOP 5% DEPOSITORS - Revenue Concentration
-- What % of revenue do top 5% drive?
-- ----------------------------------------------------------------------------
WITH player_deposits AS (
    SELECT 
        UserID,
        SUM(Amount) AS total_deposited
    FROM deposits_clean
    WHERE Status = 'S'
    GROUP BY UserID
),
ranked_players AS (
    SELECT 
        UserID,
        total_deposited,
        NTILE(20) OVER (ORDER BY total_deposited DESC) AS percentile_bucket
    FROM player_deposits
),
segmented AS (
    SELECT 
        CASE 
            WHEN percentile_bucket = 1 THEN 'Top 5%'
            WHEN percentile_bucket <= 4 THEN 'Top 6-20%'
            WHEN percentile_bucket <= 10 THEN 'Top 21-50%'
            ELSE 'Bottom 50%'
        END AS segment,
        CASE 
            WHEN percentile_bucket = 1 THEN 1
            WHEN percentile_bucket <= 4 THEN 2
            WHEN percentile_bucket <= 10 THEN 3
            ELSE 4
        END AS sort_order,
        total_deposited
    FROM ranked_players
)
SELECT 
    segment,
    COUNT(*) AS player_count,
    ROUND(SUM(total_deposited)::NUMERIC, 2) AS segment_deposits,
    ROUND(100.0 * SUM(total_deposited) / (SELECT SUM(total_deposited) FROM player_deposits), 2) AS pct_of_total_deposits
FROM segmented
GROUP BY segment, sort_order
ORDER BY sort_order;
    


-- ----------------------------------------------------------------------------
-- 4.3 VIP IDENTIFICATION
-- Players with deposits > 95th percentile
-- ----------------------------------------------------------------------------
WITH player_deposits AS (
    SELECT 
        UserID,
        SUM(Amount) AS total_deposited
    FROM deposits_clean
    WHERE Status = 'S'
    GROUP BY UserID
),
thresholds AS (
    SELECT PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY total_deposited) AS p95_threshold
    FROM player_deposits
)
SELECT 
    pd.UserID,
    pd.total_deposited,
    d.SystemAgeAsOfReg AS age,
    d.Gender,
    d.CountryID,
    'VIP' AS segment
FROM player_deposits pd
JOIN demographics_clean d ON pd.UserID = d.UserID
CROSS JOIN thresholds t
WHERE pd.total_deposited >= t.p95_threshold
ORDER BY pd.total_deposited DESC;


-- ----------------------------------------------------------------------------
-- 4.4 VIP PROFILE
-- Demographics of VIP players
-- ----------------------------------------------------------------------------
WITH player_deposits AS (
    SELECT 
        UserID,
        SUM(Amount) AS total_deposited
    FROM deposits_clean
    WHERE Status = 'S'
    GROUP BY UserID
),
vip_threshold AS (
    SELECT PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY total_deposited) AS threshold
    FROM player_deposits
),
vip_players AS (
    SELECT UserID, total_deposited
    FROM player_deposits
    WHERE total_deposited >= (SELECT threshold FROM vip_threshold)
)
SELECT 
    'VIP' AS segment,
    COUNT(*) AS player_count,
    ROUND(AVG(d.SystemAgeAsOfReg), 1) AS avg_age,
    ROUND(100.0 * SUM(CASE WHEN d.Gender = 'M' THEN 1 ELSE 0 END) / COUNT(*), 1) AS male_pct,
    ROUND(AVG(v.total_deposited), 2) AS avg_deposits,
    ROUND(SUM(v.total_deposited), 2) AS total_deposits
FROM vip_players v
JOIN demographics_clean d ON v.UserID = d.UserID;


-- ----------------------------------------------------------------------------
-- 4.5 VIP STAKES COMPARISON
-- How much more do VIPs wager vs regular players?
-- ----------------------------------------------------------------------------
WITH player_deposits AS (
    SELECT 
        UserID,
        SUM(Amount) AS total_deposited
    FROM deposits_clean
    WHERE Status = 'S'
    GROUP BY UserID
),
vip_threshold AS (
    SELECT PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY total_deposited) AS threshold
    FROM player_deposits
),
player_stakes AS (
    SELECT 
        UserID,
        SUM(StakesC) AS total_stakes
    FROM cashgames_clean
    GROUP BY UserID
)
SELECT 
    CASE 
        WHEN pd.total_deposited >= (SELECT threshold FROM vip_threshold) THEN 'VIP'
        ELSE 'Regular'
    END AS segment,
    COUNT(DISTINCT pd.UserID) AS player_count,
    ROUND(AVG(ps.total_stakes), 2) AS avg_stakes,
    ROUND(SUM(ps.total_stakes), 2) AS total_stakes,
    ROUND(100.0 * SUM(ps.total_stakes) / (SELECT SUM(total_stakes) FROM player_stakes), 2) AS pct_of_stakes
FROM player_deposits pd
LEFT JOIN player_stakes ps ON pd.UserID = ps.UserID
GROUP BY 
    CASE 
        WHEN pd.total_deposited >= (SELECT threshold FROM vip_threshold) THEN 'VIP'
        ELSE 'Regular'
    END;


-- ----------------------------------------------------------------------------
-- 4.6 VIP AT RISK (Inactive VIPs)
-- High-value players who haven't played recently
-- ----------------------------------------------------------------------------
WITH player_deposits AS (
    SELECT 
        UserID,
        SUM(Amount) AS total_deposited
    FROM deposits_clean
    WHERE Status = 'S'
    GROUP BY UserID
),
vip_threshold AS (
    SELECT PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY total_deposited) AS threshold
    FROM player_deposits
),
vip_players AS (
    SELECT UserID, total_deposited
    FROM player_deposits
    WHERE total_deposited >= (SELECT threshold FROM vip_threshold)
),
last_activity AS (
    SELECT 
        UserID,
        MAX(Date) AS last_play
    FROM (
        SELECT UserID, Date FROM cashgames_clean
        UNION ALL
        SELECT UserID, Date FROM tournaments_clean
    ) all_play
    GROUP BY UserID
),
data_end AS (
    SELECT MAX(Date) AS max_date
    FROM (
        SELECT MAX(Date) AS Date FROM cashgames_clean
        UNION ALL
        SELECT MAX(Date) FROM tournaments_clean
    ) d
)
SELECT 
    v.UserID,
    v.total_deposited,
    la.last_play,
    (SELECT max_date FROM data_end) - la.last_play AS days_inactive,
    CASE 
        WHEN (SELECT max_date FROM data_end) - la.last_play > 90 THEN 'Churned'
        WHEN (SELECT max_date FROM data_end) - la.last_play > 60 THEN 'At High Risk'
        WHEN (SELECT max_date FROM data_end) - la.last_play > 30 THEN 'At Risk'
        ELSE 'Active'
    END AS status
FROM vip_players v
LEFT JOIN last_activity la ON v.UserID = la.UserID
ORDER BY v.total_deposited DESC;


-- ----------------------------------------------------------------------------
-- 4.7 CUSTOMER LIFETIME VALUE (CLV) ESTIMATE
-- CLV = ARPU * Average Lifespan
-- ----------------------------------------------------------------------------
WITH player_revenue AS (
    SELECT 
        UserID,
        SUM(StakesC) - SUM(WinningsC) AS player_ggr
    FROM cashgames_clean
    GROUP BY UserID
),
player_lifespan AS (
    SELECT 
        UserID,
        (MAX(Date) - MIN(Date)) / 30.0 AS lifespan_months
    FROM (
        SELECT UserID, Date FROM cashgames_clean
        UNION ALL
        SELECT UserID, Date FROM tournaments_clean
    ) all_play
    GROUP BY UserID
)
SELECT 
    pr.UserID,
    pr.player_ggr AS total_revenue,
    ROUND(pl.lifespan_months, 1) AS lifespan_months,
    ROUND(pr.player_ggr / NULLIF(pl.lifespan_months, 0), 2) AS monthly_arpu,
    RANK() OVER (ORDER BY pr.player_ggr DESC) AS revenue_rank
FROM player_revenue pr
JOIN player_lifespan pl ON pr.UserID = pl.UserID
WHERE pl.lifespan_months > 0
ORDER BY total_revenue DESC
LIMIT 20;
