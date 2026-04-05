-- ============================================================================
-- SEGMENT 5: FRAUD & RISK DETECTION
-- Identifying suspicious patterns, potential bots, collusion, money laundering
-- Source: PokerStars, SEON, ResearchGate papers, GamblingNerd
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 5.1 DEPOSIT FAILURE RATE BY PAYMENT METHOD
-- High failure rates may indicate fraud or payment issues
-- Mobile carrier billing had 92% failure rate in Python analysis
-- ----------------------------------------------------------------------------
SELECT 
    PayMethCat,
    COUNT(*) AS total_attempts,
    SUM(CASE WHEN Status = 'S' THEN 1 ELSE 0 END) AS successful,
    SUM(CASE WHEN Status = 'F' THEN 1 ELSE 0 END) AS failed,
    ROUND(100.0 * SUM(CASE WHEN Status = 'F' THEN 1 ELSE 0 END) / COUNT(*), 2) AS failure_rate_pct
FROM deposits_clean
GROUP BY PayMethCat
ORDER BY failure_rate_pct DESC;


-- ----------------------------------------------------------------------------
-- 5.2 PLAYERS WITH HIGH DEPOSIT FAILURE RATE
-- Flag players with >50% deposit failures (potential fraud)
-- ----------------------------------------------------------------------------
SELECT 
    UserID,
    COUNT(*) AS total_deposits,
    SUM(CASE WHEN Status = 'S' THEN 1 ELSE 0 END) AS successful,
    SUM(CASE WHEN Status = 'F' THEN 1 ELSE 0 END) AS failed,
    ROUND(100.0 * SUM(CASE WHEN Status = 'F' THEN 1 ELSE 0 END) / COUNT(*), 2) AS failure_rate
FROM deposits_clean
GROUP BY UserID
HAVING COUNT(*) >= 5  -- Minimum 5 attempts
   AND 100.0 * SUM(CASE WHEN Status = 'F' THEN 1 ELSE 0 END) / COUNT(*) > 50
ORDER BY failure_rate DESC;


-- ----------------------------------------------------------------------------
-- 5.3 WITHDRAWAL REVERSAL RATE BY PAYMENT METHOD
-- High reversal rates may indicate money laundering or fraud
-- ----------------------------------------------------------------------------
SELECT 
    PayMethCat,
    COUNT(*) AS total_attempts,
    SUM(CASE WHEN Status = 'S' THEN 1 ELSE 0 END) AS successful,
    SUM(CASE WHEN Status = 'R' THEN 1 ELSE 0 END) AS reversed,
    ROUND(100.0 * SUM(CASE WHEN Status = 'R' THEN 1 ELSE 0 END) / COUNT(*), 2) AS reversal_rate_pct
FROM withdrawals_clean
GROUP BY PayMethCat
ORDER BY reversal_rate_pct DESC;


-- ----------------------------------------------------------------------------
-- 5.4 PLAYERS WITH HIGH WITHDRAWAL REVERSAL RATE
-- Flag players with >70% reversal rate
-- ----------------------------------------------------------------------------
SELECT 
    UserID,
    COUNT(*) AS total_withdrawals,
    SUM(CASE WHEN Status = 'S' THEN 1 ELSE 0 END) AS successful,
    SUM(CASE WHEN Status = 'R' THEN 1 ELSE 0 END) AS reversed,
    ROUND(100.0 * SUM(CASE WHEN Status = 'R' THEN 1 ELSE 0 END) / COUNT(*), 2) AS reversal_rate
FROM withdrawals_clean
GROUP BY UserID
HAVING COUNT(*) >= 3  -- Minimum 3 attempts
   AND 100.0 * SUM(CASE WHEN Status = 'R' THEN 1 ELSE 0 END) / COUNT(*) > 70
ORDER BY reversal_rate DESC;


-- ----------------------------------------------------------------------------
-- 5.5 QUICK WITHDRAWAL AFTER FIRST DEPOSIT
-- Players who withdrew within 1 day of first deposit (bonus abuse / AML signal)
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
    fd.UserID,
    fd.first_deposit_date,
    fw.first_withdrawal_date,
    fw.first_withdrawal_date - fd.first_deposit_date AS days_to_withdraw
FROM first_deposit fd
JOIN first_withdrawal fw ON fd.UserID = fw.UserID
WHERE fw.first_withdrawal_date - fd.first_deposit_date <= 1
ORDER BY days_to_withdraw;


-- ----------------------------------------------------------------------------
-- 5.6 DEPOSITED HIGH BUT BARELY PLAYED
-- Money laundering signal: deposit money but don't play
-- ----------------------------------------------------------------------------
WITH player_deposits AS (
    SELECT 
        UserID,
        SUM(Amount) AS total_deposited
    FROM deposits_clean
    WHERE Status = 'S'
    GROUP BY UserID
    HAVING SUM(Amount) >= 100  -- Deposited at least 100
),
player_stakes AS (
    SELECT 
        UserID,
        COALESCE(SUM(StakesC), 0) AS total_stakes
    FROM cashgames_clean
    GROUP BY UserID
)
SELECT 
    pd.UserID,
    pd.total_deposited,
    COALESCE(ps.total_stakes, 0) AS total_stakes,
    ROUND(100.0 * COALESCE(ps.total_stakes, 0) / pd.total_deposited, 2) AS play_ratio_pct
FROM player_deposits pd
LEFT JOIN player_stakes ps ON pd.UserID = ps.UserID
WHERE COALESCE(ps.total_stakes, 0) / pd.total_deposited < 0.5  -- Played less than 50% of deposits
ORDER BY pd.total_deposited DESC;


-- ----------------------------------------------------------------------------
-- 5.7 ABNORMALLY HIGH WIN RATE (Potential Bot / Advantage Play)
-- Players with win rate significantly above average
-- ----------------------------------------------------------------------------
WITH player_performance AS (
    SELECT 
        UserID,
        SUM(StakesC) AS total_stakes,
        SUM(WinningsC) AS total_winnings,
        SUM(WinningsC) - SUM(StakesC) AS net_profit,
        COUNT(*) AS play_days
    FROM cashgames_clean
    GROUP BY UserID
    HAVING SUM(StakesC) > 100  -- Minimum stakes
),
avg_performance AS (
    SELECT AVG(100.0 * (total_winnings - total_stakes) / total_stakes) AS avg_return_pct
    FROM player_performance
    WHERE total_stakes > 0
)
SELECT 
    pp.UserID,
    pp.total_stakes,
    pp.total_winnings,
    pp.net_profit,
    pp.play_days,
    ROUND(100.0 * pp.net_profit / pp.total_stakes, 2) AS return_pct
FROM player_performance pp
WHERE pp.total_stakes > 0
  AND 100.0 * pp.net_profit / pp.total_stakes > 20  -- Winning more than 20%
ORDER BY return_pct DESC
LIMIT 50;


-- ----------------------------------------------------------------------------
-- 5.8 COMPOSITE FRAUD RISK SCORE
-- Players flagged on multiple criteria
-- ----------------------------------------------------------------------------
WITH deposit_failure_flag AS (
    SELECT UserID, 1 AS flag
    FROM deposits_clean
    GROUP BY UserID
    HAVING COUNT(*) >= 5 
       AND 100.0 * SUM(CASE WHEN Status = 'F' THEN 1 ELSE 0 END) / COUNT(*) > 50
),
withdrawal_reversal_flag AS (
    SELECT UserID, 1 AS flag
    FROM withdrawals_clean
    GROUP BY UserID
    HAVING COUNT(*) >= 3 
       AND 100.0 * SUM(CASE WHEN Status = 'R' THEN 1 ELSE 0 END) / COUNT(*) > 70
),
quick_withdrawal_flag AS (
    SELECT fd.UserID, 1 AS flag
    FROM (
        SELECT UserID, MIN(ProcessDate) AS first_deposit_date
        FROM deposits_clean WHERE Status = 'S' GROUP BY UserID
    ) fd
    JOIN (
        SELECT UserID, MIN(ProcessDate) AS first_withdrawal_date
        FROM withdrawals_clean WHERE Status = 'S' GROUP BY UserID
    ) fw ON fd.UserID = fw.UserID
    WHERE fw.first_withdrawal_date - fd.first_deposit_date <= 1
),
low_play_flag AS (
    SELECT pd.UserID, 1 AS flag
    FROM (
        SELECT UserID, SUM(Amount) AS total_deposited
        FROM deposits_clean WHERE Status = 'S' GROUP BY UserID HAVING SUM(Amount) >= 100
    ) pd
    LEFT JOIN (
        SELECT UserID, COALESCE(SUM(StakesC), 0) AS total_stakes FROM cashgames_clean GROUP BY UserID
    ) ps ON pd.UserID = ps.UserID
    WHERE COALESCE(ps.total_stakes, 0) / pd.total_deposited < 0.5
)
SELECT 
    d.UserID,
    COALESCE(df.flag, 0) AS deposit_failure_flag,
    COALESCE(wr.flag, 0) AS withdrawal_reversal_flag,
    COALESCE(qw.flag, 0) AS quick_withdrawal_flag,
    COALESCE(lp.flag, 0) AS low_play_flag,
    COALESCE(df.flag, 0) + COALESCE(wr.flag, 0) + COALESCE(qw.flag, 0) + COALESCE(lp.flag, 0) AS total_flags
FROM demographics_clean d
LEFT JOIN deposit_failure_flag df ON d.UserID = df.UserID
LEFT JOIN withdrawal_reversal_flag wr ON d.UserID = wr.UserID
LEFT JOIN quick_withdrawal_flag qw ON d.UserID = qw.UserID
LEFT JOIN low_play_flag lp ON d.UserID = lp.UserID
WHERE COALESCE(df.flag, 0) + COALESCE(wr.flag, 0) + COALESCE(qw.flag, 0) + COALESCE(lp.flag, 0) >= 2
ORDER BY total_flags DESC, d.UserID;


-- ----------------------------------------------------------------------------
-- 5.9 FRAUD FLAGS BY COUNTRY
-- Which countries have more suspicious activity?
-- ----------------------------------------------------------------------------
WITH flagged_players AS (
    SELECT 
        d.UserID,
        d.CountryID
    FROM demographics_clean d
    WHERE d.UserID IN (
        -- Quick withdrawal flag
        SELECT fd.UserID
        FROM (SELECT UserID, MIN(ProcessDate) AS fd FROM deposits_clean WHERE Status = 'S' GROUP BY UserID) fd
        JOIN (SELECT UserID, MIN(ProcessDate) AS fw FROM withdrawals_clean WHERE Status = 'S' GROUP BY UserID) fw 
        ON fd.UserID = fw.UserID
        WHERE fw.fw - fd.fd <= 1
    )
    OR d.UserID IN (
        -- High deposit failure
        SELECT UserID FROM deposits_clean
        GROUP BY UserID
        HAVING COUNT(*) >= 5 AND 100.0 * SUM(CASE WHEN Status = 'F' THEN 1 ELSE 0 END) / COUNT(*) > 50
    )
)
SELECT 
    d.CountryID,
    COUNT(DISTINCT d.UserID) AS total_players,
    COUNT(DISTINCT fp.UserID) AS flagged_players,
    ROUND(100.0 * COUNT(DISTINCT fp.UserID) / COUNT(DISTINCT d.UserID), 2) AS flag_rate_pct
FROM demographics_clean d
LEFT JOIN flagged_players fp ON d.UserID = fp.UserID
WHERE d.CountryID IS NOT NULL
GROUP BY d.CountryID
HAVING COUNT(DISTINCT d.UserID) >= 50  -- Countries with at least 50 players
ORDER BY flag_rate_pct DESC;
