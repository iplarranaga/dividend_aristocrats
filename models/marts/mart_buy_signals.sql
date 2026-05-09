-- Señal de entrada: yield actual > media de yield histórico 5 años
-- Lógica: si el yield está por encima de su propia media histórica,
-- la acción cotiza más barata de lo habitual en términos de dividendo.

with fundamentals as (
    select * from {{ ref('stg_fundamentals') }}
),

yield_recent as (
    -- Tomamos el 5y rolling avg del año más reciente con datos completos
    select ticker, dividend_year, yield_5y_rolling_avg
    from {{ ref('int_yield_history') }}
    qualify row_number() over (partition by ticker order by dividend_year desc) = 1
),

cagr as (
    select ticker, dividend_cagr_5y, annual_dividend_current
    from {{ ref('int_dividend_cagr') }}
),

latest_price as (
    select ticker, close_price as current_price, price_date
    from {{ ref('stg_prices') }}
    qualify row_number() over (partition by ticker order by price_date desc) = 1
)

select
    f.ticker,
    f.company_name,
    f.sector,
    f.consecutive_years,

    -- precio actual y contexto técnico
    p.current_price,
    f.fifty_two_week_low,
    f.fifty_two_week_high,
    round(p.current_price / nullif(f.fifty_two_week_high, 0) - 1, 4) as pct_off_52w_high,

    -- señal de yield
    round(f.current_dividend_yield * 100, 3)    as current_yield_pct,
    round(y.yield_5y_rolling_avg * 100, 3)      as yield_5y_avg_pct,
    round(
        (f.current_dividend_yield / nullif(y.yield_5y_rolling_avg, 0) - 1) * 100,
        2
    )                                           as yield_premium_pct,

    -- calidad del dividendo
    round(f.payout_ratio * 100, 2)              as payout_ratio_pct,
    round(c.dividend_cagr_5y * 100, 2)          as cagr_5y_pct,
    round(c.annual_dividend_current, 4)         as annual_dividend

from fundamentals f
inner join yield_recent y on f.ticker = y.ticker
left join cagr c          on f.ticker = c.ticker
left join latest_price p  on f.ticker = p.ticker
where f.current_dividend_yield > y.yield_5y_rolling_avg
  and y.yield_5y_rolling_avg is not null
  and f.current_dividend_yield is not null
order by yield_premium_pct desc
