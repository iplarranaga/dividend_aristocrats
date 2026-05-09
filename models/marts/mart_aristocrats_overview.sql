with fundamentals as (
    select * from {{ ref('stg_fundamentals') }}
),

cagr as (
    select * from {{ ref('int_dividend_cagr') }}
),

latest_price as (
    select ticker, close_price as current_price, price_date
    from {{ ref('stg_prices') }}
    qualify row_number() over (partition by ticker order by price_date desc) = 1
),

yield_avg as (
    select ticker, yield_5y_rolling_avg as yield_5y_avg
    from {{ ref('int_yield_history') }}
    qualify row_number() over (partition by ticker order by dividend_year desc) = 1
)

select
    f.ticker,
    f.company_name,
    f.sector,
    f.industry,
    f.consecutive_years,

    -- precio
    p.current_price,
    p.price_date                                                        as price_as_of,
    f.fifty_two_week_low,
    f.fifty_two_week_high,
    round(p.current_price / nullif(f.fifty_two_week_high, 0) - 1, 4)  as pct_off_52w_high,

    -- tamaño
    f.market_cap,

    -- valoración
    round(f.trailing_pe, 2)       as trailing_pe,
    round(f.forward_pe, 2)        as forward_pe,
    round(f.ev_to_ebitda, 2)      as ev_to_ebitda,
    round(f.price_to_book, 2)     as price_to_book,

    -- dividendo
    round(f.current_dividend_yield * 100, 3)    as current_yield_pct,
    round(y.yield_5y_avg * 100, 3)              as yield_5y_avg_pct,
    f.annual_dividend_rate,
    round(f.payout_ratio * 100, 2)              as payout_ratio_pct,

    -- crecimiento
    round(c.dividend_cagr_5y * 100, 2)          as cagr_5y_pct,
    round(c.dividend_cagr_10y * 100, 2)         as cagr_10y_pct,

    f.extracted_at

from fundamentals f
left join cagr c         on f.ticker = c.ticker
left join latest_price p on f.ticker = p.ticker
left join yield_avg y    on f.ticker = y.ticker
order by f.sector, f.ticker
