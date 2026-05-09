# Dividend Aristocrats — dbt Analytics Pipeline

> **S&P 500 Dividend Aristocrats** financial analysis pipeline built with **dbt Core + DuckDB**.  
> Zero cost, fully local, reproducible end-to-end.

[![dbt](https://img.shields.io/badge/dbt-1.11.9-orange)](https://www.getdbt.com/)
[![DuckDB](https://img.shields.io/badge/DuckDB-1.5.2-yellow)](https://duckdb.org/)
[![Python](https://img.shields.io/badge/Python-3.12%2B-blue)](https://www.python.org/)
[![Tests](https://img.shields.io/badge/tests-46%20passing-brightgreen)](#tests)
[![License: MIT](https://img.shields.io/badge/License-MIT-lightgrey)](LICENSE)

---

## What is this?

The **S&P 500 Dividend Aristocrats** are ~65 companies in the S&P 500 that have increased their dividend for **25+ consecutive years**. This project builds a complete analytics pipeline on top of that universe:

- Historical prices and dividends extracted from **yfinance**
- Transformed with **dbt** into clean, tested, analysis-ready tables
- Stored in a local **DuckDB** file — no database server needed
- Documented with **dbt docs** and published to GitHub Pages

### Key analytical outputs

| Mart | What it answers |
|---|---|
| `mart_aristocrats_overview` | Full picture: price, valuation, yield, CAGR for all 58 companies |
| `mart_dividend_growth` | Who grows their dividend fastest? CAGR 5y/10y + YoY stats |
| `mart_valuation` | PE, EV/EBITDA, payout ratio with sector-relative context |
| `mart_sectors` | Which sectors dominate? Aggregated metrics by GICS sector |
| `mart_buy_signals` | **Entry signal**: companies where current yield > 5-year historical average |

---

## Architecture

```
┌──────────────────────────────────────────────────┐
│  scripts/extract.py  (yfinance → Parquet)         │
│                                                    │
│  data/raw_prices.parquet        145,870 rows       │
│  data/raw_dividends.parquet      10,073 rows       │
│  data/raw_fundamentals.parquet       58 rows       │
└───────────────────┬──────────────────────────────┘
                    │  DuckDB external tables
                    ▼
┌──────────────────────────────────────────────────┐
│  SOURCES  (Parquet via dbt-duckdb external)       │
│  raw.raw_prices · raw.raw_dividends               │
│  raw.raw_fundamentals                             │
└───────────────────┬──────────────────────────────┘
                    │
                    ▼
┌──────────────────────────────────────────────────┐
│  STAGING  (views)                                 │
│  stg_prices · stg_dividends · stg_fundamentals    │
│  Cleaning, type casting, GICS sector normalization│
└───────────────────┬──────────────────────────────┘
                    │
                    ▼
┌──────────────────────────────────────────────────┐
│  INTERMEDIATE  (views)                            │
│  int_annual_dividends   annual totals + YoY       │
│  int_dividend_cagr      CAGR 5y / 10y             │
│  int_yield_history      yield + 5y rolling avg    │
└───────────────────┬──────────────────────────────┘
                    │
                    ▼
┌──────────────────────────────────────────────────┐
│  MARTS  (tables)                                  │
│  mart_aristocrats_overview                        │
│  mart_dividend_growth                             │
│  mart_valuation                                   │
│  mart_sectors                                     │
│  mart_buy_signals   ← entry signal model          │
└──────────────────────────────────────────────────┘
```

---

## Prerequisites

- Python 3.11 or 3.12 recommended (see note below for 3.14)
- Git

> **Python 3.14 note**: dbt-core 1.11.x ships with `mashumaro<3.15` which has a bug on Python 3.14. After installing requirements, run:
> ```bash
> pip install "mashumaro[msgpack]==3.17" --force-reinstall --no-deps
> ```

---

## Quick start

```bash
# 1. Clone the repo
git clone https://github.com/iplarranaga/dividend_aristocrats.git
cd dividend_aristocrats

# 2. Install Python dependencies
pip install -r requirements.txt

# 3. Extract data from yfinance (~3 min, 58 tickers)
python scripts/extract.py

# 4. Load the seed and run the full pipeline
dbt seed --profiles-dir .
dbt run  --profiles-dir .
dbt test --profiles-dir .

# 5. (Optional) Open dbt docs
dbt docs generate --profiles-dir .
dbt docs serve   --profiles-dir .
```

After step 4, query any mart directly:

```sql
-- Using DuckDB CLI
duckdb dividend_aristocrats.duckdb
SELECT * FROM main_marts.mart_buy_signals ORDER BY yield_premium_pct DESC;
```

---

## Project structure

```
dividend_aristocrats/
├── dbt_project.yml           # dbt project config
├── profiles.yml              # DuckDB connection (local file, portable)
├── requirements.txt
│
├── scripts/
│   └── extract.py            # yfinance → Parquet extractor
│
├── seeds/
│   └── aristocrats.csv       # 58 tickers with sector + consecutive years
│
├── data/                     # Generated Parquet files (gitignored)
│   ├── raw_prices.parquet
│   ├── raw_dividends.parquet
│   └── raw_fundamentals.parquet
│
├── models/
│   ├── staging/
│   │   ├── _sources.yml      # External Parquet sources + freshness
│   │   ├── _stg_models.yml   # Column tests
│   │   ├── stg_prices.sql
│   │   ├── stg_dividends.sql
│   │   └── stg_fundamentals.sql
│   │
│   ├── intermediate/
│   │   ├── _int_models.yml
│   │   ├── int_annual_dividends.sql
│   │   ├── int_dividend_cagr.sql
│   │   └── int_yield_history.sql
│   │
│   └── marts/
│       ├── _mart_models.yml
│       ├── mart_aristocrats_overview.sql
│       ├── mart_dividend_growth.sql
│       ├── mart_valuation.sql
│       ├── mart_sectors.sql
│       └── mart_buy_signals.sql
│
└── tests/
    └── generic/
        ├── not_negative.sql       # yield and dividends never < 0
        └── between_values.sql     # payout ratio 0–200% (warn above)
```

---

## Methodology

### Dividend CAGR

```
CAGR 5y = (annual_dividend_2024 / annual_dividend_2019) ^ (1/5) − 1
```

Reference year is `YEAR(CURRENT_DATE) − 1` (most recent complete year).

### Buy signal — yield vs. historical average

A company emits a **buy signal** when its current yield exceeds its own 5-year historical average yield:

```
signal: current_yield > yield_5y_rolling_avg
premium: (current_yield / yield_5y_rolling_avg − 1) × 100
```

This is a mean-reversion signal: if the yield is above its historical baseline, the stock is "cheap" relative to its own dividend history. It does **not** replace fundamental analysis — always check payout ratio and CAGR alongside the signal.

### Sector classification

Sectors follow the **GICS** nomenclature from the `seeds/aristocrats.csv` seed file, which takes precedence over Yahoo Finance's sector labels (which use a different naming convention).

---

## Key findings (as of extraction date)

### Top dividend growers — CAGR 5y

| Ticker | Company | CAGR 5y | CAGR 10y |
|---|---|---|---|
| ROST | Ross Stores | 41.6% | 13.2% |
| NDSN | Nordson | 20.9% | 15.8% |
| LOW | Lowe's | 15.9% | 16.5% |
| AFL | Aflac | 15.7% | 11.4% |
| CTAS | Cintas | 13.9% | 20.4% |

### Buy signals (yield premium over 5y avg)

| Ticker | Sector | Current Yield | 5y Avg Yield | Premium |
|---|---|---|---|---|
| FDS | IT | 2.08% | 0.92% | +127% |
| MKC | Consumer Staples | 3.97% | 2.09% | +90% |
| BRO | Financials | 1.14% | 0.61% | +88% |
| BDX | Health Care | 2.81% | 1.53% | +83% |
| ROP | Industrials | 1.06% | 0.59% | +79% |

### Sectors at a glance

| Sector | Companies | Median PE | Avg Yield | Avg CAGR 5y |
|---|---|---|---|---|
| Consumer Staples | 14 | 21.4x | 3.66% | 4.7% |
| Industrials | 11 | 30.7x | 1.46% | 8.0% |
| Materials | 7 | 31.2x | 2.28% | 5.1% |
| Health Care | 6 | 25.9x | 2.75% | 5.6% |
| Financials | 5 | 11.3x | 2.36% | 6.6% |

---

## Tests

```
46 tests total
  45 PASS
   1 WARN  (payout_ratio > 200% for ABBV, GPC, O, AMCR — real-world edge cases)
   0 ERROR
```

Custom generic tests:
- **`not_negative`** — dividend amounts and yields are never negative
- **`between_values(0, 2.0)`** — payout ratio in reasonable range (warn above 200%)

Source freshness thresholds:
- Warn if data is older than **7 days**
- Error if data is older than **30 days**

Run freshness check:
```bash
dbt source freshness --profiles-dir .
```

---

## dbt docs

Generated docs are published to GitHub Pages:

👉 **[https://iplarranaga.github.io/dividend_aristocrats](https://iplarranaga.github.io/dividend_aristocrats)**

To generate and serve locally:
```bash
dbt docs generate --profiles-dir .
dbt docs serve   --profiles-dir .
# Opens at http://localhost:8080
```

---

## Data sources

| Source | Provider | Method | License |
|---|---|---|---|
| Historical prices (OHLCV) | Yahoo Finance | `yfinance` Python library | Fair use |
| Dividend history | Yahoo Finance | `yfinance` Python library | Fair use |
| Company fundamentals | Yahoo Finance | `yfinance` Python library | Fair use |
| Aristocrats list | `seeds/aristocrats.csv` | Hand-curated, public domain | — |

> **Disclaimer**: This project is for educational and portfolio purposes only. It does not constitute investment advice. Data from Yahoo Finance may be delayed or inaccurate. Always verify with official sources before making investment decisions.

---

## License

MIT — see [LICENSE](LICENSE) for details.
