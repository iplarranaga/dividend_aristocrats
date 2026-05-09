with fundamentals as (
    select * from {{ ref('stg_fundamentals') }}
),

cagr as (
    select * from {{ ref('int_dividend_cagr') }}
)

select
    f.sector,
    count(distinct f.ticker)                                                    as company_count,
    round(avg(f.consecutive_years), 1)                                          as avg_consecutive_years,
    round(min(f.consecutive_years), 0)                                          as min_consecutive_years,
    round(max(f.consecutive_years), 0)                                          as max_consecutive_years,

    -- valoración sectorial
    round(percentile_cont(0.5) within group (order by f.trailing_pe), 2)        as median_trailing_pe,
    round(percentile_cont(0.5) within group (order by f.ev_to_ebitda), 2)       as median_ev_ebitda,
    round(percentile_cont(0.5) within group (order by f.payout_ratio) * 100, 2) as median_payout_ratio_pct,

    -- dividendo sectorial
    round(avg(f.current_dividend_yield) * 100, 3)                               as avg_yield_pct,
    round(min(f.current_dividend_yield) * 100, 3)                               as min_yield_pct,
    round(max(f.current_dividend_yield) * 100, 3)                               as max_yield_pct,

    -- crecimiento del dividendo
    round(avg(c.dividend_cagr_5y) * 100, 2)                                     as avg_cagr_5y_pct,
    round(avg(c.dividend_cagr_10y) * 100, 2)                                    as avg_cagr_10y_pct,

    -- lista de empresas del sector
    string_agg(f.ticker, ', ' order by f.ticker)                                as tickers

from fundamentals f
left join cagr c on f.ticker = c.ticker
group by f.sector
order by company_count desc
