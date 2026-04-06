# Poker Trading Analytics

**SQL-driven analysis of player behavior, trading performance, and fraud detection for an online poker platform.**

[![SQL](https://img.shields.io/badge/SQL-PostgreSQL-336791?logo=postgresql)](https://www.postgresql.org/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

---

##  Project Overview

This project analyzes **6 years of transactional data** (Feb 2015 – Jul 2020) from a European online poker platform, using pure SQL to answer business questions that Trading and Product teams care about.

### Dataset
- **Source:** "Second Session at the Virtual Poker Table" — The Transparency Project
- **Sponsor:** Division on Addiction, Cambridge Health Alliance (Harvard Medical School) & Entain plc
- **Scale:** 5,028 players | 467K+ transactions | €32.8M total handle

---

##  Key Findings

| Metric | Value | Insight |
|--------|-------|---------|
| **Total GGR (Rake)** | €1.09M | Platform revenue over 6 years |
| **Total Handle** | €32.8M | Total amount wagered |
| **Cash Game Hold %** | 2.34% | Industry standard (2-5%) |
| **Tournament Hold %** | 11.22% | Higher fee structure typical for MTTs |
| **ARPU (Lifetime)** | €161 | Average revenue per player |
| **Deposit Retention** | 54% | €5.27M of €9.69M never withdrawn |
| **Players Who Never Withdrew** | 65% | Strong revenue retention |
| **VIP Concentration** | Top 5% → 64% | Small segment drives majority of deposits |

---

## Project Structure

```
poker-trading-analytics/
├── README.md
├── sql/
│   ├── 00_create_tables.sql      # Schema definition
│   ├── 01_financial_performance.sql   # GGR, Handle, Hold %, ARPU
│   ├── 02_player_acquisition.sql      # Signups, demographics, FTD
│   ├── 03_retention_churn.sql         # Lifespan, MAU, churn rates
│   ├── 04_vip_analysis.sql            # High-value player identification
│   ├── 05_fraud_risk.sql              # Suspicious pattern detection
│   ├── 06_payments.sql                # Deposit/withdrawal analysis
│   ├── 07_trading_performance.sql     # Margin, profitability, player P&L
│   ├── 08_funnel_analysis.sql         # Conversion funnel metrics
│   └── 09_window_functions.sql        # Advanced SQL techniques
├── data/
│   └── (see Data Source section)
└── results/
    └── exported_csvs/
```

---

## Analysis Segments

### 1. Financial Performance
Core KPIs every gaming operator reports to investors.

```sql
-- Gross Gaming Revenue by Game Type
SELECT 
    'Cash Games' AS game_type,
    SUM(StakesC) - SUM(WinningsC) AS ggr,
    ROUND(100.0 * (SUM(StakesC) - SUM(WinningsC)) / NULLIF(SUM(StakesC), 0), 2) AS hold_pct
FROM cashgames_clean;
```

| Game Type | GGR | Hold % |
|-----------|-----|--------|
| Cash Games | €681,253 | 2.34% |
| Tournaments | €410,850 | 11.22% |

---

### 2. Player Acquisition
Who's signing up and making first deposits?

```sql
-- FTD Conversion Rate
WITH first_deposits AS (
    SELECT DISTINCT UserID FROM deposits_clean WHERE Status = 'S'
)
SELECT 
    ROUND(100.0 * COUNT(DISTINCT fd.UserID) / 
    (SELECT COUNT(*) FROM demographics_clean), 2) AS ftd_conversion_rate
FROM first_deposits fd;
```

---

### 3. Retention & Churn
Player lifespan and activity patterns.

```sql
-- Monthly Active Players (MAU)
SELECT 
    DATE_TRUNC('month', Date) AS month,
    COUNT(DISTINCT UserID) AS monthly_active_players
FROM cashgames_clean
GROUP BY DATE_TRUNC('month', Date)
ORDER BY month;
```

**Finding:** Platform activity declined ~80% from 2015 to 2020, indicating significant player migration to larger operators.

---

### 4. VIP Analysis
High-value player identification and behavior.

```sql
-- Top 5% Revenue Concentration
WITH player_deposits AS (
    SELECT UserID, SUM(Amount) AS total_deposited
    FROM deposits_clean WHERE Status = 'S'
    GROUP BY UserID
),
ranked AS (
    SELECT *, NTILE(20) OVER (ORDER BY total_deposited DESC) AS percentile
    FROM player_deposits
)
SELECT 
    CASE WHEN percentile = 1 THEN 'Top 5%' ELSE 'Other' END AS segment,
    ROUND(100.0 * SUM(total_deposited) / (SELECT SUM(total_deposited) FROM player_deposits), 2) AS pct_of_deposits
FROM ranked
GROUP BY CASE WHEN percentile = 1 THEN 'Top 5%' ELSE 'Other' END;
```

**Finding:** Top 5% of players drive 64% of total deposits — classic VIP concentration.

---

### 5. Fraud & Risk Detection
Identifying suspicious patterns for compliance teams.

```sql
-- Composite Fraud Risk Score
-- Flags: High deposit failure, quick withdrawal, low play ratio
SELECT UserID, 
    COALESCE(deposit_fail_flag, 0) + 
    COALESCE(quick_withdraw_flag, 0) + 
    COALESCE(low_play_flag, 0) AS total_flags
FROM ...
WHERE total_flags >= 2;
```

**Flags Identified:**
- High deposit failure rate (>50%)
- Withdrawal within 1 day of first deposit
- Deposited but barely played (<50% stake ratio)
- Abnormally high win rate (>20% ROI)

---

### 6. Payments Analysis
Deposit/withdrawal health and payment method performance.

| Payment Category | Success Rate | Volume |
|------------------|--------------|--------|
| eWallet | 98.2% | High |
| Debit/Credit Card | 94.1% | High |
| Bank Transfer | 91.3% | Medium |
| Mobile Carrier | 8% | Low |

**Finding:** Mobile carrier billing has 92% failure rate — flag for product team.

---

### 7. Trading Performance
Margin analysis and player profitability distribution.

```sql
-- Player Profitability Distribution
WITH player_pnl AS (
    SELECT UserID, SUM(WinningsC) - SUM(StakesC) AS net_profit
    FROM cashgames_clean GROUP BY UserID
)
SELECT 
    CASE WHEN net_profit > 0 THEN 'Profitable' ELSE 'Losing' END AS status,
    COUNT(*) AS players,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS pct
FROM player_pnl GROUP BY 1;
```

**Finding:** 91% of players lose money — expected for poker where rake ensures house always wins.

---

### 8. Funnel Analysis
Player journey from signup to VIP.

```
Signup (5,028) → Deposit (4,232) → Play (3,891) → Repeat (2,104) → Withdraw (1,486)
   100%            84%              77%            42%              30%
```

**Key Drop-off:** 58% of players never return after first session.

---

### 9. Window Functions
Demonstrating advanced SQL proficiency.

```sql
-- Running Total with PARTITION BY
SELECT 
    UserID, ProcessDate, Amount,
    SUM(Amount) OVER (PARTITION BY UserID ORDER BY ProcessDate) AS running_total
FROM deposits_clean
WHERE Status = 'S';

-- Month-over-Month Change with LAG
SELECT 
    month,
    ggr,
    LAG(ggr) OVER (ORDER BY month) AS prev_month,
    ROUND(100.0 * (ggr - LAG(ggr) OVER (ORDER BY month)) / 
          NULLIF(ABS(LAG(ggr) OVER (ORDER BY month)), 0), 2) AS mom_change_pct
FROM monthly_ggr;
```

**Techniques Used:**
- `RANK()`, `DENSE_RANK()`, `NTILE()`
- `LAG()`, `LEAD()`
- `SUM() OVER (PARTITION BY ... ORDER BY ...)`
- `FIRST_VALUE()`, `LAST_VALUE()`
- `ROWS BETWEEN` for moving averages

---

## 🛠️ Technical Stack

| Component | Technology |
|-----------|------------|
| Database | PostgreSQL 16 |
| IDE | pgAdmin 4 |
| Analysis | Pure SQL (76 queries) |
| Visualization | Tableau / Power BI (separate project) |

---

## 📊 Data Schema

```
demographics_clean     → 5,016 rows  (UserID, Age, Gender, Country)
cashgames_clean        → 51,763 rows (UserID, Date, Stakes, Winnings)
tournaments_clean      → 82,831 rows (UserID, Date, Buy-ins, Winnings)
deposits_clean         → 295,088 rows (UserID, Amount, PayMethod, Status)
withdrawals_clean      → 32,307 rows (UserID, Amount, PayMethod, Status)
```

---

## 🎯 Business Applications

This analysis framework applies directly to:
- **Trading Operations** — Margin monitoring, hold % tracking
- **Risk & Compliance** — Fraud detection, AML flags
- **Product Analytics** — Funnel optimization, feature impact
- **VIP Management** — High-value player identification
- **Marketing** — CAC/LTV analysis, cohort retention

---

## 📚 Data Source

**Dataset:** "Second Session at the Virtual Poker Table"  
**Provider:** The Transparency Project  
**Institution:** Division on Addiction, Cambridge Health Alliance (Harvard Medical School)  
**Sponsor:** Entain plc  
**Period:** February 2015 – July 2020  

---

## 👤 Author

**Ravi Teja Battagani**  
MS Computer Science | Southern Illinois University Carbondale  
Former Associate, Trading Operations | Entain (Ivy Comptech)  

[![LinkedIn](https://img.shields.io/badge/LinkedIn-Connect-blue?logo=linkedin)](https://linkedin.com/in/yourprofile)
[![GitHub](https://img.shields.io/badge/GitHub-Follow-black?logo=github)](https://github.com/yourprofile)

---

## 📄 License

This project is for educational and portfolio purposes. Dataset used under academic research provisions.
