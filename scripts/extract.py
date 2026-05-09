#!/usr/bin/env python3
"""
Extract prices, dividends and fundamentals for S&P 500 Dividend Aristocrats.
Outputs three Parquet files to data/.

Usage:
    python scripts/extract.py            # full run (~58 tickers, ~3 min)
    python scripts/extract.py --dry-run  # first 3 tickers only, for testing
"""

import argparse
import sys
import time
from datetime import datetime, timezone
from pathlib import Path

import pandas as pd
import yfinance as yf

ROOT = Path(__file__).parent.parent
DATA_DIR = ROOT / "data"
SEEDS_DIR = ROOT / "seeds"
SLEEP_SECONDS = 0.5  # polite delay between tickers


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _strip_tz(series: pd.Series) -> pd.Series:
    """Convert tz-aware DatetimeSeries to naive UTC, then normalize to midnight."""
    s = pd.to_datetime(series)
    if s.dt.tz is not None:
        s = s.dt.tz_convert(None)
    return s.dt.normalize()


# ---------------------------------------------------------------------------
# Fetchers
# ---------------------------------------------------------------------------

def fetch_prices(ticker: str) -> pd.DataFrame:
    df = yf.Ticker(ticker).history(period="10y", auto_adjust=True)
    if df.empty:
        return pd.DataFrame()
    df = df.reset_index()
    df.columns = df.columns.str.lower().str.replace(" ", "_")
    df["date"] = _strip_tz(df["date"])
    df["ticker"] = ticker
    cols = [c for c in ["ticker", "date", "open", "high", "low", "close", "volume"] if c in df.columns]
    return df[cols]


def fetch_dividends(ticker: str) -> pd.DataFrame:
    divs = yf.Ticker(ticker).dividends
    if divs.empty:
        return pd.DataFrame()
    df = divs.reset_index()
    df.columns = ["date", "amount"]
    df["date"] = _strip_tz(df["date"])
    df["ticker"] = ticker
    return df[["ticker", "date", "amount"]]


def fetch_fundamentals(ticker: str, consecutive_years: int) -> dict:
    info = yf.Ticker(ticker).info
    return {
        "ticker":                ticker,
        "long_name":             info.get("longName"),
        "sector":                info.get("sector"),
        "industry":              info.get("industry"),
        "consecutive_years":     consecutive_years,
        "market_cap":            info.get("marketCap"),
        "trailing_pe":           info.get("trailingPE"),
        "forward_pe":            info.get("forwardPE"),
        "price_to_book":         info.get("priceToBook"),
        "enterprise_value":      info.get("enterpriseValue"),
        "ebitda":                info.get("ebitda"),
        "enterprise_to_ebitda":  info.get("enterpriseToEbitda"),
        "payout_ratio":          info.get("payoutRatio"),
        "dividend_yield":        info.get("dividendYield"),
        "dividend_rate":         info.get("dividendRate"),
        "trailing_eps":          info.get("trailingEps"),
        "book_value":            info.get("bookValue"),
        "fifty_two_week_high":   info.get("fiftyTwoWeekHigh"),
        "fifty_two_week_low":    info.get("fiftyTwoWeekLow"),
        "currency":              info.get("currency", "USD"),
        "extracted_at":          datetime.now(timezone.utc).isoformat(),
    }


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--dry-run", action="store_true", help="Process first 3 tickers only")
    args = parser.parse_args()

    DATA_DIR.mkdir(exist_ok=True)
    companies = pd.read_csv(SEEDS_DIR / "aristocrats.csv")

    if args.dry_run:
        companies = companies.head(3)
        print("DRY RUN — processing first 3 tickers only\n")

    n = len(companies)
    print(f"Extracting data for {n} Dividend Aristocrats...")
    print(f"{'':4} {'ticker':<7} {'company':<42} {'prices':>7} {'divs':>5}")
    print("-" * 68)

    all_prices: list[pd.DataFrame] = []
    all_divs: list[pd.DataFrame] = []
    all_fundamentals: list[dict] = []
    failed: list[str] = []

    for i, row in enumerate(companies.itertuples(), 1):
        ticker = row.ticker
        label = f"[{i:2d}/{n}] {ticker:<7} {row.company_name[:42]:<42}"
        print(f"  {label}", end="", flush=True)

        try:
            prices = fetch_prices(ticker)
            divs = fetch_dividends(ticker)
            fundamentals = fetch_fundamentals(ticker, row.consecutive_years)

            if not prices.empty:
                all_prices.append(prices)
            if not divs.empty:
                all_divs.append(divs)
            all_fundamentals.append(fundamentals)

            print(f" {len(prices):7,d} {len(divs):5,d}")
        except Exception as exc:
            print(f" FAILED — {exc}")
            failed.append(ticker)

        if i < n:
            time.sleep(SLEEP_SECONDS)

    # -------------------------------------------------------------------------
    # Save
    # -------------------------------------------------------------------------
    if not all_prices:
        print("\nNo data collected. Exiting.", file=sys.stderr)
        sys.exit(1)

    df_prices = pd.concat(all_prices, ignore_index=True)
    df_divs = pd.concat(all_divs, ignore_index=True)
    df_fundamentals = pd.DataFrame(all_fundamentals)

    df_prices.to_parquet(DATA_DIR / "raw_prices.parquet", index=False)
    df_divs.to_parquet(DATA_DIR / "raw_dividends.parquet", index=False)
    df_fundamentals.to_parquet(DATA_DIR / "raw_fundamentals.parquet", index=False)

    print("\n" + "=" * 68)
    print(f"  raw_prices.parquet       → {len(df_prices):>8,d} rows")
    print(f"  raw_dividends.parquet    → {len(df_divs):>8,d} rows")
    print(f"  raw_fundamentals.parquet → {len(df_fundamentals):>8,d} rows")

    if failed:
        print(f"\n  Failed ({len(failed)}): {', '.join(failed)}")

    print("\nDone.")


if __name__ == "__main__":
    main()
