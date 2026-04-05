-- ============================================================================
-- SEGMENT 8: FUNNEL ANALYSIS
-- Track player journey: Signup → Deposit → Play → Retain → VIP
-- This connects all segments into a cohesive story
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 8.1 FULL PLAYER FUNNEL
-- Signup → First Deposit → First Play → Repeat Play → Withdrawal
-- ----------------------------------------------------------------------------
WITH funnel AS (
    SELECT 
        d.UserID,
        1 AS signed_up,
        CASE WHEN dep.UserID IS NOT NULL THEN 1 ELSE 0 END AS made_deposit,
        CASE WHEN cg.UserID IS NOT NULL OR t.UserID IS NOT NULL THEN 1 ELSE 0 END AS made_first_play,
        CASE WHEN cg.play_days > 1 OR t.play_days > 1 THEN 1 ELSE 0 END AS made_repeat_play,
        CASE WHEN w.UserID IS NOT NULL THEN 1 ELSE 0 END AS made_withdrawal
    FROM demographics_clean d
    LEFT JOIN (
        SELECT DISTINCT UserID FROM deposits_clean WHERE Status = 'S'
    ) dep ON d.UserID = dep.UserID
    LEFT JOIN (
        SELECT UserID, COUNT(DISTINCT Date) AS play_days FROM cashgames_clean GROUP BY UserID
    ) cg ON d.UserID = cg.UserID
    LEFT JOIN (
        SELECT UserID, COUNT(DISTINCT Date) AS play_days FROM tournaments_clean GROUP BY UserID
    ) t ON d.UserID = t.UserID
    LEFT JOIN (
        SELECT DISTINCT UserID FROM withdrawals_clean WHERE Status = 'S'
    ) w ON d.UserID = w.UserID
)
SELECT 
    'Signed Up' AS stage,
    SUM(signed_up) AS count,
    100.0 AS pct_of_signups,
    100.0 AS pct_of_prev_stage
FROM funnel
UNION ALL
SELECT 
    'Made Deposit' AS stage,
    SUM(made_deposit) AS count,
    ROUND(100.0 * SUM(made_deposit) / SUM(signed_up), 2) AS pct_of_signups,
    ROUND(100.0 * SUM(made_deposit) / SUM(signed_up), 2) AS pct_of_prev_stage
FROM funnel
UNION ALL
SELECT 
    'Made First Play' AS stage,
    SUM(made_first_play) AS count,
    ROUND(100.0 * SUM(made_first_play) / SUM(signed_up), 2) AS pct_of_signups,
    ROUND(100.0 * SUM(made_first_play) / NULLIF(SUM(made_deposit), 0), 2) AS pct_of_prev_stage
FROM funnel
UNION ALL
SELECT 
    'Made Repeat Play' AS stage,
    SUM(made_repeat_play) AS count,
    ROUND(100.0 * SUM(made_repeat_play) / SUM(signed_up), 2) AS pct_of_signups,
    ROUND(100.0 * SUM(made_repeat_play) / NULLIF(SUM(made_first_play), 0), 2) AS pct_of_prev_stage
FROM funnel
UNION ALL
SELECT 
    'Made Withdrawal' AS stage,
    SUM(made_withdrawal) AS count,
    ROUND(100.0 * SUM(made_withdrawal) / SUM(signed_up), 2) AS pct_of_signups,
    ROUND(100.0 * SUM(made_withdrawal) / NULLIF(SUM(made_repeat_play), 0), 2) AS pct_of_prev_stage
FROM funnel;


-- ----------------------------------------------------------------------------
-- 8.2 FUNNEL BY COUNTRY
-- Which countries convert best through the funnel?
-- ----------------------------------------------------------------------------
WITH funnel AS (
    SELECT 
        d.UserID,
        d.CountryID,
        1 AS signed_up,
        CASE WHEN dep.UserID IS NOT NULL THEN 1 ELSE 0 END AS made_deposit,
        CASE WHEN cg.UserID IS NOT NULL OR t.UserID IS NOT NULL THEN 1 ELSE 0 END AS made_first_play
    FROM demographics_clean d
    LEFT JOIN (SELECT DISTINCT UserID FROM deposits_clean WHERE Status = 'S') dep ON d.UserID = dep.UserID
    LEFT JOIN (SELECT DISTINCT UserID FROM cashgames_clean) cg ON d.UserID = cg.UserID
    LEFT JOIN (SELECT DISTINCT UserID FROM tournaments_clean) t ON d.UserID = t.UserID
)
SELECT 
    CountryID,
    COUNT(*) AS signups,
    SUM(made_deposit) AS depositors,
    SUM(made_first_play) AS players,
    ROUND(100.0 * SUM(made_deposit) / COUNT(*), 2) AS deposit_conversion_pct,
    ROUND(100.0 * SUM(made_first_play) / NULLIF(SUM(made_deposit), 0), 2) AS play_conversion_pct
FROM funnel
WHERE CountryID IS NOT NULL
GROUP BY CountryID
HAVING COUNT(*) >= 50
ORDER BY deposit_conversion_pct DESC;


-- ----------------------------------------------------------------------------
-- 8.3 FUNNEL BY AGE GROUP
-- Which age groups convert best?
-- ----------------------------------------------------------------------------
WITH funnel AS (
    SELECT 
        d.UserID,
        CASE 
            WHEN d.SystemAgeAsOfReg < 25 THEN 'Under 25'
            WHEN d.SystemAgeAsOfReg BETWEEN 25 AND 34 THEN '25-34'
            WHEN d.SystemAgeAsOfReg BETWEEN 35 AND 44 THEN '35-44'
            WHEN d.SystemAgeAsOfReg BETWEEN 45 AND 54 THEN '45-54'
            ELSE '55+'
        END AS age_group,
        1 AS signed_up,
        CASE WHEN dep.UserID IS NOT NULL THEN 1 ELSE 0 END AS made_deposit,
        CASE WHEN cg.UserID IS NOT NULL THEN 1 ELSE 0 END AS made_play
    FROM demographics_clean d
    LEFT JOIN (SELECT DISTINCT UserID FROM deposits_clean WHERE Status = 'S') dep ON d.UserID = dep.UserID
    LEFT JOIN (SELECT DISTINCT UserID FROM cashgames_clean) cg ON d.UserID = cg.UserID
)
SELECT 
    age_group,
    COUNT(*) AS signups,
    SUM(made_deposit) AS depositors,
    SUM(made_play) AS players,
    ROUND(100.0 * SUM(made_deposit) / COUNT(*), 2) AS deposit_conversion_pct,
    ROUND(100.0 * SUM(made_play) / NULLIF(SUM(made_deposit), 0), 2) AS play_conversion_pct
FROM funnel
WHERE age_group IS NOT NULL AND age_group != '55+'
GROUP BY age_group
ORDER BY 
    CASE age_group
        WHEN 'Under 25' THEN 1
        WHEN '25-34' THEN 2
        WHEN '35-44' THEN 3
        WHEN '45-54' THEN 4
        ELSE 5
    END;


-- ----------------------------------------------------------------------------
-- 8.4 FUNNEL BY PAYMENT METHOD
-- Does first payment method affect conversion?
-- ----------------------------------------------------------------------------
WITH first_deposit_method AS (
    SELECT 
        UserID,
        PayMethCat,
        ROW_NUMBER() OVER (PARTITION BY UserID ORDER BY ProcessDate, ProcessTime) AS rn
    FROM deposits_clean
    WHERE Status = 'S'
),
funnel AS (
    SELECT 
        fdm.UserID,
        fdm.PayMethCat,
        1 AS deposited,
        CASE WHEN cg.UserID IS NOT NULL THEN 1 ELSE 0 END AS played
    FROM first_deposit_method fdm
    LEFT JOIN (SELECT DISTINCT UserID FROM cashgames_clean) cg ON fdm.UserID = cg.UserID
    WHERE fdm.rn = 1
)
SELECT 
    PayMethCat,
    COUNT(*) AS depositors,
    SUM(played) AS players,
    ROUND(100.0 * SUM(played) / COUNT(*), 2) AS play_conversion_pct
FROM funnel
GROUP BY PayMethCat
HAVING COUNT(*) >= 50
ORDER BY play_conversion_pct DESC;


-- ----------------------------------------------------------------------------
-- 8.5 TIME TO FIRST PLAY (After First Deposit)
-- How quickly do depositors start playing?
-- ----------------------------------------------------------------------------
WITH first_deposit AS (
    SELECT UserID, MIN(ProcessDate) AS first_deposit_date
    FROM deposits_clean
    WHERE Status = 'S'
    GROUP BY UserID
),
first_play AS (
    SELECT UserID, MIN(Date) AS first_play_date
    FROM (
        SELECT UserID, Date FROM cashgames_clean
        UNION ALL
        SELECT UserID, Date FROM tournaments_clean
    ) all_play
    GROUP BY UserID
),
time_to_play AS (
    SELECT 
        fd.UserID,
        fp.first_play_date - fd.first_deposit_date AS days_to_play
    FROM first_deposit fd
    JOIN first_play fp ON fd.UserID = fp.UserID
)
SELECT 
    CASE 
        WHEN days_to_play = 0 THEN 'Same Day'
        WHEN days_to_play = 1 THEN 'Next Day'
        WHEN days_to_play BETWEEN 2 AND 7 THEN '2-7 Days'
        WHEN days_to_play BETWEEN 8 AND 30 THEN '8-30 Days'
        ELSE '30+ Days'
    END AS time_to_first_play,
    COUNT(*) AS player_count,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS pct
FROM time_to_play
GROUP BY 
    CASE 
        WHEN days_to_play = 0 THEN 'Same Day'
        WHEN days_to_play = 1 THEN 'Next Day'
        WHEN days_to_play BETWEEN 2 AND 7 THEN '2-7 Days'
        WHEN days_to_play BETWEEN 8 AND 30 THEN '8-30 Days'
        ELSE '30+ Days'
    END
ORDER BY 
    MIN(days_to_play);WITH first_deposit AS (
    SELECT UserID, MIN(ProcessDate) AS first_deposit_date
    FROM deposits_clean
    WHERE Status = 'S'
    GROUP BY UserID
),
first_play AS (
    SELECT UserID, MIN(Date) AS first_play_date
    FROM (
        SELECT UserID, Date FROM cashgames_clean
        UNION ALL
        SELECT UserID, Date FROM tournaments_clean
    ) all_play
    GROUP BY UserID
),
time_to_play AS (
    SELECT 
        fd.UserID,
        fp.first_play_date - fd.first_deposit_date AS days_to_play
    FROM first_deposit fd
    JOIN first_play fp ON fd.UserID = fp.UserID
)
SELECT 
    CASE 
        WHEN days_to_play = 0 THEN 'Same Day'
        WHEN days_to_play = 1 THEN 'Next Day'
        WHEN days_to_play BETWEEN 2 AND 7 THEN '2-7 Days'
        WHEN days_to_play BETWEEN 8 AND 30 THEN '8-30 Days'
        ELSE '30+ Days'
    END AS time_to_first_play,
    COUNT(*) AS player_count,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS pct
FROM time_to_play
GROUP BY 
    CASE 
        WHEN days_to_play = 0 THEN 'Same Day'
        WHEN days_to_play = 1 THEN 'Next Day'
        WHEN days_to_play BETWEEN 2 AND 7 THEN '2-7 Days'
        WHEN days_to_play BETWEEN 8 AND 30 THEN '8-30 Days'
        ELSE '30+ Days'
    END
ORDER BY 
    MIN(days_to_play);WITH first_deposit AS (
    SELECT UserID, MIN(ProcessDate) AS first_deposit_date
    FROM deposits_clean
    WHERE Status = 'S'
    GROUP BY UserID
),
first_play AS (
    SELECT UserID, MIN(Date) AS first_play_date
    FROM (
        SELECT UserID, Date FROM cashgames_clean
        UNION ALL
        SELECT UserID, Date FROM tournaments_clean
    ) all_play
    GROUP BY UserID
),
time_to_play AS (
    SELECT 
        fd.UserID,
        fp.first_play_date - fd.first_deposit_date AS days_to_play
    FROM first_deposit fd
    JOIN first_play fp ON fd.UserID = fp.UserID
)
SELECT 
    CASE 
        WHEN days_to_play = 0 THEN 'Same Day'
        WHEN days_to_play = 1 THEN 'Next Day'
        WHEN days_to_play BETWEEN 2 AND 7 THEN '2-7 Days'
        WHEN days_to_play BETWEEN 8 AND 30 THEN '8-30 Days'
        ELSE '30+ Days'
    END AS time_to_first_play,
    COUNT(*) AS player_count,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS pct
FROM time_to_play
GROUP BY 
    CASE 
        WHEN days_to_play = 0 THEN 'Same Day'
        WHEN days_to_play = 1 THEN 'Next Day'
        WHEN days_to_play BETWEEN 2 AND 7 THEN '2-7 Days'
        WHEN days_to_play BETWEEN 8 AND 30 THEN '8-30 Days'
        ELSE '30+ Days'
    END
ORDER BY 
    MIN(days_to_play);


-- ----------------------------------------------------------------------------
-- 8.6 FUNNEL TO VIP
-- What % of players become high-value?
-- ----------------------------------------------------------------------------
WITH player_deposits AS (
    SELECT UserID, SUM(Amount) AS total_deposited
    FROM deposits_clean
    WHERE Status = 'S'
    GROUP BY UserID
),
vip_threshold AS (
    SELECT PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY total_deposited) AS threshold
    FROM player_deposits
)
SELECT 
    'All Signups' AS stage, 
    COUNT(*) AS count,
    100.0 AS pct
FROM demographics_clean

UNION ALL

SELECT 
    'Made Deposit' AS stage,
    COUNT(DISTINCT UserID) AS count,
    ROUND(100.0 * COUNT(DISTINCT UserID) / (SELECT COUNT(*) FROM demographics_clean), 2) AS pct
FROM deposits_clean
WHERE Status = 'S'

UNION ALL

SELECT 
    'Became VIP (Top 5%)' AS stage,
    COUNT(*) AS count,
    ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM demographics_clean), 2) AS pct
FROM player_deposits
WHERE total_deposited >= (SELECT threshold FROM vip_threshold);


-- ----------------------------------------------------------------------------
-- 8.7 DROP-OFF ANALYSIS
-- Where do we lose the most players?
-- ----------------------------------------------------------------------------
WITH funnel_counts AS (
    SELECT 
        (SELECT COUNT(*) FROM demographics_clean) AS signups,
        (SELECT COUNT(DISTINCT UserID) FROM deposits_clean WHERE Status = 'S') AS depositors,
        (SELECT COUNT(DISTINCT UserID) FROM cashgames_clean) + 
        (SELECT COUNT(DISTINCT UserID) FROM tournaments_clean WHERE UserID NOT IN (SELECT DISTINCT UserID FROM cashgames_clean)) AS players,
        (SELECT COUNT(DISTINCT UserID) FROM withdrawals_clean WHERE Status = 'S') AS withdrawers
)
SELECT 
    'Signup → Deposit' AS stage,
    signups AS from_count,
    depositors AS to_count,
    signups - depositors AS dropped,
    ROUND(100.0 * (signups - depositors) / signups, 2) AS drop_rate_pct
FROM funnel_counts

UNION ALL

SELECT 
    'Deposit → Play' AS stage,
    depositors AS from_count,
    players AS to_count,
    depositors - players AS dropped,
    ROUND(100.0 * (depositors - players) / NULLIF(depositors, 0), 2) AS drop_rate_pct
FROM funnel_counts

UNION ALL

SELECT 
    'Play → Withdraw' AS stage,
    players AS from_count,
    withdrawers AS to_count,
    players - withdrawers AS dropped,
    ROUND(100.0 * (players - withdrawers) / NULLIF(players, 0), 2) AS drop_rate_pct
FROM funnel_counts;
