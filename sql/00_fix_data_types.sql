-- ============================================================================
-- FIX DATA TYPES
-- Run this FIRST if columns were imported as TEXT
-- ============================================================================

-- ============================================================================
-- DEMOGRAPHICS_CLEAN
-- ============================================================================
ALTER TABLE demographics_clean
    ALTER COLUMN UserID TYPE INTEGER USING UserID::INTEGER,
    ALTER COLUMN SystemAgeAsOfReg TYPE INTEGER USING NULLIF(SystemAgeAsOfReg, '')::INTEGER,
    ALTER COLUMN CountryID TYPE INTEGER USING NULLIF(CountryID, '')::INTEGER;

-- ============================================================================
-- CASHGAMES_CLEAN
-- ============================================================================
ALTER TABLE cashgames_clean
    ALTER COLUMN UserID TYPE INTEGER USING UserID::INTEGER,
    ALTER COLUMN Date TYPE DATE USING Date::DATE,
    ALTER COLUMN Windows TYPE INTEGER USING Windows::INTEGER,
    ALTER COLUMN StakesC TYPE NUMERIC(12,2) USING StakesC::NUMERIC(12,2),
    ALTER COLUMN WinningsC TYPE NUMERIC(12,2) USING WinningsC::NUMERIC(12,2);

-- ============================================================================
-- TOURNAMENTS_CLEAN
-- ============================================================================
ALTER TABLE tournaments_clean
    ALTER COLUMN UserID TYPE INTEGER USING UserID::INTEGER,
    ALTER COLUMN Date TYPE DATE USING Date::DATE,
    ALTER COLUMN Trnmnts TYPE INTEGER USING Trnmnts::INTEGER,
    ALTER COLUMN StakesT TYPE NUMERIC(12,5) USING StakesT::NUMERIC(12,5),
    ALTER COLUMN WinningsT TYPE NUMERIC(12,5) USING WinningsT::NUMERIC(12,5);

-- ============================================================================
-- DEPOSITS_CLEAN
-- ============================================================================
ALTER TABLE deposits_clean
    ALTER COLUMN UserID TYPE INTEGER USING UserID::INTEGER,
    ALTER COLUMN DepositID TYPE INTEGER USING DepositID::INTEGER,
    ALTER COLUMN SummaryDate TYPE DATE USING SummaryDate::DATE,
    ALTER COLUMN ProcessDate TYPE DATE USING ProcessDate::DATE,
    ALTER COLUMN ProcessTime TYPE TIME USING ProcessTime::TIME,
    ALTER COLUMN Amount TYPE NUMERIC(12,2) USING Amount::NUMERIC(12,2);

-- ============================================================================
-- WITHDRAWALS_CLEAN
-- ============================================================================
ALTER TABLE withdrawals_clean
    ALTER COLUMN UserID TYPE INTEGER USING UserID::INTEGER,
    ALTER COLUMN WithdrawalID TYPE INTEGER USING WithdrawalID::INTEGER,
    ALTER COLUMN SummaryDate TYPE DATE USING SummaryDate::DATE,
    ALTER COLUMN ProcessDate TYPE DATE USING ProcessDate::DATE,
    ALTER COLUMN ProcessTime TYPE TIME USING ProcessTime::TIME,
    ALTER COLUMN Amount TYPE NUMERIC(12,2) USING Amount::NUMERIC(12,2);

-- ============================================================================
-- VERIFY
-- ============================================================================
SELECT 'demographics_clean' AS tbl, COUNT(*) AS rows FROM demographics_clean
UNION ALL
SELECT 'cashgames_clean', COUNT(*) FROM cashgames_clean
UNION ALL
SELECT 'tournaments_clean', COUNT(*) FROM tournaments_clean
UNION ALL
SELECT 'deposits_clean', COUNT(*) FROM deposits_clean
UNION ALL
SELECT 'withdrawals_clean', COUNT(*) FROM withdrawals_clean;
