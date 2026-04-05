-- ============================================================================
-- POKER TRADING ANALYTICS - DATABASE SCHEMA
-- Dataset: "Second Session at the Virtual Poker Table" - The Transparency Project
-- Source: Division on Addiction, Cambridge Health Alliance (Harvard Medical School)
-- Sponsor: Entain plc
-- Period: February 2015 - January 2021
-- ============================================================================

-- Drop tables if they exist (for clean reload)
DROP TABLE IF EXISTS withdrawals CASCADE;
DROP TABLE IF EXISTS deposits CASCADE;
DROP TABLE IF EXISTS tournaments CASCADE;
DROP TABLE IF EXISTS cashgames CASCADE;
DROP TABLE IF EXISTS demographics CASCADE;

-- ============================================================================
-- TABLE 1: DEMOGRAPHICS (Player Master)
-- One row per player
-- ============================================================================
CREATE TABLE demographics (
    userid          INTEGER PRIMARY KEY,
    age_at_reg      INTEGER,           -- Age when registered
    gender          VARCHAR(10),       -- M/F
    countryid       INTEGER            -- Country code
);

-- ============================================================================
-- TABLE 2: CASH GAMES (Daily aggregates)
-- One row per player per day they played cash games
-- ============================================================================
CREATE TABLE cashgames (
    userid          INTEGER,
    play_date       DATE,
    windows         INTEGER,           -- Number of tables/sessions
    stakes          NUMERIC(12,2),     -- Total amount wagered
    winnings        NUMERIC(12,2),     -- Total winnings
    PRIMARY KEY (userid, play_date)
);

-- ============================================================================
-- TABLE 3: TOURNAMENTS (Daily aggregates)
-- One row per player per day they played tournaments
-- ============================================================================
CREATE TABLE tournaments (
    userid          INTEGER,
    play_date       DATE,
    num_tournaments INTEGER,           -- Number of tournaments entered
    stakes          NUMERIC(12,2),     -- Total buy-ins
    winnings        NUMERIC(12,2),     -- Total winnings
    PRIMARY KEY (userid, play_date)
);

-- ============================================================================
-- TABLE 4: DEPOSITS (Transaction level)
-- One row per deposit transaction
-- ============================================================================
CREATE TABLE deposits (
    userid          INTEGER,
    deposit_id      INTEGER,
    summary_date    DATE,
    process_date    DATE,
    process_time    TIME,
    pay_method      VARCHAR(50),       -- Specific payment method
    pay_method_cat  VARCHAR(50),       -- Payment category
    card_type       VARCHAR(10),       -- Card type
    amount          NUMERIC(12,2),     -- Deposit amount
    status          CHAR(1),           -- S=Success, F=Failed
    PRIMARY KEY (deposit_id)
);

-- ============================================================================
-- TABLE 5: WITHDRAWALS (Transaction level)
-- One row per withdrawal transaction
-- ============================================================================
CREATE TABLE withdrawals (
    userid          INTEGER,
    withdrawal_id   INTEGER,
    summary_date    DATE,
    process_date    DATE,
    process_time    TIME,
    pay_method      VARCHAR(50),       -- Specific payment method
    pay_method_cat  VARCHAR(50),       -- Payment category
    card_type       VARCHAR(10),       -- Card type
    amount          NUMERIC(12,2),     -- Withdrawal amount
    status          CHAR(1),           -- S=Success, R=Reversed/Rejected
    PRIMARY KEY (withdrawal_id)
);

-- ============================================================================
-- INDEXES for query performance
-- ============================================================================
CREATE INDEX idx_cashgames_userid ON cashgames(userid);
CREATE INDEX idx_cashgames_date ON cashgames(play_date);
CREATE INDEX idx_tournaments_userid ON tournaments(userid);
CREATE INDEX idx_tournaments_date ON tournaments(play_date);
CREATE INDEX idx_deposits_userid ON deposits(userid);
CREATE INDEX idx_deposits_date ON deposits(process_date);
CREATE INDEX idx_deposits_status ON deposits(status);
CREATE INDEX idx_withdrawals_userid ON withdrawals(userid);
CREATE INDEX idx_withdrawals_date ON withdrawals(process_date);
CREATE INDEX idx_withdrawals_status ON withdrawals(status);

-- ============================================================================
-- COMMENTS
-- ============================================================================
COMMENT ON TABLE demographics IS 'Player master table - one row per registered user';
COMMENT ON TABLE cashgames IS 'Daily cash game activity - stakes and winnings per player per day';
COMMENT ON TABLE tournaments IS 'Daily tournament activity - buy-ins and winnings per player per day';
COMMENT ON TABLE deposits IS 'Individual deposit transactions with payment method and status';
COMMENT ON TABLE withdrawals IS 'Individual withdrawal transactions with payment method and status';
