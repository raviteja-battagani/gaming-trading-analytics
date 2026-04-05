-- ============================================================================
-- SEGMENT 1: FINANCIAL PERFORMANCE
-- Core KPIs every betting company reports to investors
-- Source: BetMGM FY24 Report, Altenar, EveryMatrix
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1.1 GROSS GAMING REVENUE (GGR) - Total
-- GGR = Total Stakes - Total Winnings (what the house keeps)
-- ----------------------------------------------------------------------------
SELECT 
    'Cash Games' AS game_type,
    SUM(StakesC) AS total_stakes,
    SUM(WinningsC) AS total_winnings,
    SUM(StakesC) - SUM(WinningsC) AS ggr,
    ROUND(100.0 * (SUM(StakesC) - SUM(WinningsC)) / NULLIF(SUM(StakesC), 0), 2) AS hold_pct
FROM cashgames_clean

UNION ALL

SELECT 
    'Tournaments' AS game_type,
    SUM(StakesT) AS total_stakes,
    SUM(WinningsT) AS total_winnings,
    SUM(StakesT) - SUM(WinningsT) AS ggr,
    ROUND(100.0 * (SUM(StakesT) - SUM(WinningsT)) / NULLIF(SUM(StakesT), 0), 2) AS hold_pct
FROM tournaments_clean;


-- ----------------------------------------------------------------------------
-- 1.2 TOTAL HANDLE (Amount Wagered)
-- BetMGM reported "$13.1B handle" in FY24
-- ----------------------------------------------------------------------------
SELECT
    SUM(StakesC) + (SELECT SUM(StakesT) FROM tournaments_clean) AS total_handle,
    SUM(StakesC) AS cash_game_handle,
    (SELECT SUM(StakesT) FROM tournaments_clean) AS tournament_handle
FROM cashgames_clean;


-- ----------------------------------------------------------------------------
-- 1.3 HOLD PERCENTAGE BY GAME TYPE
-- BetMGM reported "8.6% hold" - this is the house edge
-- ----------------------------------------------------------------------------
SELECT 
    'Cash Games' AS game_type,
    ROUND(100.0 * (SUM(StakesC) - SUM(WinningsC)) / NULLIF(SUM(StakesC), 0), 2) AS hold_pct
FROM cashgames_clean

UNION ALL

SELECT 
    'Tournaments' AS game_type,
    ROUND(100.0 * (SUM(StakesT) - SUM(WinningsT)) / NULLIF(SUM(StakesT), 0), 2) AS hold_pct
FROM tournaments_clean;


-- ----------------------------------------------------------------------------
-- 1.4 MONTHLY GGR TREND
-- Time series for Tableau visualization
-- ----------------------------------------------------------------------------
SELECT 
    DATE_TRUNC('month', Date) AS month,
    SUM(StakesC) AS stakes,
    SUM(WinningsC) AS winnings,
    SUM(StakesC) - SUM(WinningsC) AS ggr,
    ROUND(100.0 * (SUM(StakesC) - SUM(WinningsC)) / NULLIF(SUM(StakesC), 0), 2) AS hold_pct
FROM cashgames_clean
GROUP BY DATE_TRUNC('month', Date)
ORDER BY month;


-- ----------------------------------------------------------------------------
-- 1.5 ARPU (Average Revenue Per User)
-- ARPU = Total GGR / Number of Active Players
-- ----------------------------------------------------------------------------
WITH player_ggr AS (
    SELECT 
        UserID,
        SUM(StakesC) - SUM(WinningsC) AS player_ggr
    FROM cashgames_clean
    GROUP BY UserID
)
SELECT 
    COUNT(DISTINCT UserID) AS total_players,
    SUM(player_ggr) AS total_ggr,
    ROUND(SUM(player_ggr) / COUNT(DISTINCT UserID), 2) AS arpu
FROM player_ggr;


-- ----------------------------------------------------------------------------
-- 1.6 NET GAMING REVENUE PROXY
-- NGR = GGR - Bonuses (we don't have bonus data, so this is GGR)
-- Net deposits - withdrawals as proxy for platform revenue
-- ----------------------------------------------------------------------------
WITH deposit_totals AS (
    SELECT SUM(Amount) AS total_deposits
    FROM deposits_clean
    WHERE Status = 'S'
),
withdrawal_totals AS (
    SELECT SUM(Amount) AS total_withdrawals
    FROM withdrawals_clean
    WHERE Status = 'S'
)
SELECT 
    d.total_deposits,
    w.total_withdrawals,
    d.total_deposits - w.total_withdrawals AS net_to_platform
FROM deposit_totals d, withdrawal_totals w;
