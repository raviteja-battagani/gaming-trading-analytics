-- ============================================================================
-- SEGMENT 7: TRADING PERFORMANCE
-- Core trading metrics - stakes, winnings, margin, hold %
-- Source: BetMGM JD, Your Entain experience
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 7.1 TOTAL STAKES VS TOTAL WINNINGS (Trading Margin)
-- This is the "rake" or house edge
-- ----------------------------------------------------------------------------
SELECT 
    'Cash Games' AS game_type,
    ROUND(SUM(StakesC), 2) AS total_stakes,
    ROUND(SUM(WinningsC), 2) AS total_winnings,
    ROUND(SUM(StakesC) - SUM(WinningsC), 2) AS trading_margin,
    ROUND(100.0 * (SUM(StakesC) - SUM(WinningsC)) / NULLIF(SUM(StakesC), 0), 2) AS margin_pct
FROM cashgames_clean

UNION ALL

SELECT 
    'Tournaments' AS game_type,
    ROUND(SUM(StakesT), 2) AS total_stakes,
    ROUND(SUM(WinningsT), 2) AS total_winnings,
    ROUND(SUM(StakesT) - SUM(WinningsT), 2) AS trading_margin,
    ROUND(100.0 * (SUM(StakesT) - SUM(WinningsT)) / NULLIF(SUM(StakesT), 0), 2) AS margin_pct
FROM tournaments_clean;


-- ----------------------------------------------------------------------------
-- 7.2 MONTHLY TRADING MARGIN TREND
-- For time series visualization
-- ----------------------------------------------------------------------------
SELECT 
    DATE_TRUNC('month', Date) AS month,
    'Cash Games' AS game_type,
    ROUND(SUM(StakesC), 2) AS stakes,
    ROUND(SUM(WinningsC), 2) AS winnings,
    ROUND(SUM(StakesC) - SUM(WinningsC), 2) AS margin,
    ROUND(100.0 * (SUM(StakesC) - SUM(WinningsC)) / NULLIF(SUM(StakesC), 0), 2) AS margin_pct
FROM cashgames_clean
GROUP BY DATE_TRUNC('month', Date)

UNION ALL

SELECT 
    DATE_TRUNC('month', Date) AS month,
    'Tournaments' AS game_type,
    ROUND(SUM(StakesT), 2) AS stakes,
    ROUND(SUM(WinningsT), 2) AS winnings,
    ROUND(SUM(StakesT) - SUM(WinningsT), 2) AS margin,
    ROUND(100.0 * (SUM(StakesT) - SUM(WinningsT)) / NULLIF(SUM(StakesT), 0), 2) AS margin_pct
FROM tournaments_clean
GROUP BY DATE_TRUNC('month', Date)
ORDER BY month, game_type;


-- ----------------------------------------------------------------------------
-- 7.3 PLAYER PROFITABILITY DISTRIBUTION
-- How many players are profitable vs losing?
-- ----------------------------------------------------------------------------
WITH player_pnl AS (
    SELECT 
        c.UserID,
        COALESCE(SUM(c.WinningsC) - SUM(c.StakesC), 0) + 
        COALESCE((SELECT SUM(WinningsT) - SUM(StakesT) FROM tournaments_clean t WHERE t.UserID = c.UserID), 0) AS net_profit
    FROM cashgames_clean c
    GROUP BY c.UserID
)
SELECT 
    CASE 
        WHEN net_profit > 0 THEN 'Profitable'
        WHEN net_profit = 0 THEN 'Break Even'
        ELSE 'Losing'
    END AS player_status,
    COUNT(*) AS player_count,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS pct
FROM player_pnl
GROUP BY 1
ORDER BY player_count DESC;


-- ----------------------------------------------------------------------------
-- 7.4 TOP WINNING PLAYERS
-- Players with highest net profit
-- ----------------------------------------------------------------------------
WITH player_pnl AS (
    SELECT 
        UserID,
        SUM(WinningsC) - SUM(StakesC) AS net_profit,
        SUM(StakesC) AS total_stakes,
        COUNT(*) AS play_days
    FROM cashgames_clean
    GROUP BY UserID
)
SELECT 
    UserID,
    ROUND(net_profit, 2) AS net_profit,
    ROUND(total_stakes, 2) AS total_stakes,
    play_days,
    ROUND(100.0 * net_profit / NULLIF(total_stakes, 0), 2) AS roi_pct
FROM player_pnl
WHERE net_profit > 0
ORDER BY net_profit DESC
LIMIT 20;


-- ----------------------------------------------------------------------------
-- 7.5 TOP LOSING PLAYERS (Revenue Generators for House)
-- Players who lost the most (house revenue)
-- ----------------------------------------------------------------------------
WITH player_pnl AS (
    SELECT 
        UserID,
        SUM(WinningsC) - SUM(StakesC) AS net_profit,
        SUM(StakesC) AS total_stakes,
        COUNT(*) AS play_days
    FROM cashgames_clean
    GROUP BY UserID
)
SELECT 
    UserID,
    ROUND(ABS(net_profit), 2) AS amount_lost,
    ROUND(total_stakes, 2) AS total_stakes,
    play_days,
    ROUND(100.0 * ABS(net_profit) / NULLIF(total_stakes, 0), 2) AS loss_pct
FROM player_pnl
WHERE net_profit < 0
ORDER BY net_profit ASC
LIMIT 20;


-- ----------------------------------------------------------------------------
-- 7.6 PLAYER PROFITABILITY BY AGE GROUP
-- Do older players lose more?
-- ----------------------------------------------------------------------------
SELECT 
    age_group,
    player_count,
    avg_profit_loss,
    total_profit_loss
FROM (
    SELECT 
        CASE
            WHEN d.SystemAgeAsOfReg < 25 THEN 'Under 25'
            WHEN d.SystemAgeAsOfReg BETWEEN 25 AND 34 THEN '25-34'
            WHEN d.SystemAgeAsOfReg BETWEEN 35 AND 44 THEN '35-44'
            WHEN d.SystemAgeAsOfReg BETWEEN 45 AND 54 THEN '45-54'
            ELSE '55+'
        END AS age_group,
        CASE
            WHEN d.SystemAgeAsOfReg < 25 THEN 1
            WHEN d.SystemAgeAsOfReg BETWEEN 25 AND 34 THEN 2
            WHEN d.SystemAgeAsOfReg BETWEEN 35 AND 44 THEN 3
            WHEN d.SystemAgeAsOfReg BETWEEN 45 AND 54 THEN 4
            ELSE 5
        END AS sort_order,
        COUNT(*) AS player_count,
        ROUND(AVG(p.net_profit), 2) AS avg_profit_loss,
        ROUND(SUM(p.net_profit), 2) AS total_profit_loss
    FROM player_pnl p
    JOIN demographics_clean d ON p.UserID = d.UserID
    WHERE d.SystemAgeAsOfReg IS NOT NULL
    GROUP BY 1, 2
) sub
ORDER BY sort_order;


-- ----------------------------------------------------------------------------
-- 7.7 PLAYER PROFITABILITY BY COUNTRY
-- Which markets generate most house revenue?
-- ----------------------------------------------------------------------------
WITH player_pnl AS (
    SELECT 
        c.UserID,
        SUM(c.StakesC) - SUM(c.WinningsC) AS house_revenue
    FROM cashgames_clean c
    GROUP BY c.UserID
)
SELECT 
    d.CountryID,
    COUNT(*) AS player_count,
    ROUND(SUM(p.house_revenue), 2) AS total_house_revenue,
    ROUND(AVG(p.house_revenue), 2) AS avg_revenue_per_player
FROM player_pnl p
JOIN demographics_clean d ON p.UserID = d.UserID
WHERE d.CountryID IS NOT NULL
GROUP BY d.CountryID
ORDER BY total_house_revenue DESC
LIMIT 15;


-- ----------------------------------------------------------------------------
-- 7.8 CASH GAMES VS TOURNAMENTS - PLAYER PREFERENCE
-- What % of players play each type?
-- ----------------------------------------------------------------------------
WITH cash_players AS (
    SELECT DISTINCT UserID FROM cashgames_clean
),
tournament_players AS (
    SELECT DISTINCT UserID FROM tournaments_clean
)
SELECT 
    'Cash Games Only' AS player_type,
    COUNT(*) AS player_count
FROM cash_players c
WHERE c.UserID NOT IN (SELECT UserID FROM tournament_players)

UNION ALL

SELECT 
    'Tournaments Only' AS player_type,
    COUNT(*) AS player_count
FROM tournament_players t
WHERE t.UserID NOT IN (SELECT UserID FROM cash_players)

UNION ALL

SELECT 
    'Both (Hybrid)' AS player_type,
    COUNT(*) AS player_count
FROM cash_players c
WHERE c.UserID IN (SELECT UserID FROM tournament_players);


-- ----------------------------------------------------------------------------
-- 7.9 AVERAGE SESSION SIZE (Windows/Tables)
-- How many tables do players typically play?
-- ----------------------------------------------------------------------------
SELECT 
    ROUND(AVG(Windows), 1) AS avg_windows_per_session,
ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY Windows)::numeric, 1) AS median_windows,    MIN(Windows) AS min_windows,
    MAX(Windows) AS max_windows
FROM cashgames_clean;



-- ----------------------------------------------------------------------------
-- 7.10 PEAK PLAYING DAYS
-- Which days of week have most activity?
-- ----------------------------------------------------------------------------
SELECT 
    EXTRACT(DOW FROM Date) AS day_of_week,
    CASE EXTRACT(DOW FROM Date)
        WHEN 0 THEN 'Sunday'
        WHEN 1 THEN 'Monday'
        WHEN 2 THEN 'Tuesday'
        WHEN 3 THEN 'Wednesday'
        WHEN 4 THEN 'Thursday'
        WHEN 5 THEN 'Friday'
        WHEN 6 THEN 'Saturday'
    END AS day_name,
    COUNT(DISTINCT UserID) AS unique_players,
    ROUND(SUM(StakesC), 2) AS total_stakes
FROM cashgames_clean
GROUP BY EXTRACT(DOW FROM Date)
ORDER BY day_of_week;
