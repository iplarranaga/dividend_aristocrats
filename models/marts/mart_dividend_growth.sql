with fundamentals as (
    select ticker, company_name, sector, consecutive_years
    from {{ ref('stg_fundamentals') }}
),

cagr as (
    select * from {{ ref('int_dividend_cagr') }}
),

annual as (
    select * from {{ ref('int_annual_dividends') }}
),

-- Dividendo anual más reciente
latest_annual as (
    select ticker, annual_dividend as latest_annual_dividend, dividend_year
    from annual
    qualify row_number() over (partition by ticker order by dividend_year desc) = 1
),

-- Stats de crecimiento YoY de los últimos 5 años completos
yoy_stats as (
    select
        ticker,
        round(avg(yoy_growth_pct), 2)                            as avg_yoy_5y_pct,
        round(min(yoy_growth_pct), 2)                            as min_yoy_5y_pct,
        round(max(yoy_growth_pct), 2)                            as max_yoy_5y_pct,
        count(case when yoy_growth_pct > 0 then 1 end)           as years_positive_growth
    from (
        select ticker, yoy_growth_pct,
               row_number() over (partition by ticker order by dividend_year desc) as rn
        from annual
        where yoy_growth_pct is not null
    ) ranked
    where rn <= 5
    group by ticker
)

select
    f.ticker,
    f.company_name,
    f.sector,
    f.consecutive_years,

    -- dividendo actual y base
    round(l.latest_annual_dividend, 4)          as annual_dividend_current,
    l.dividend_year                             as ref_year,
    round(c.annual_dividend_5y_ago, 4)          as annual_dividend_5y_ago,
    round(c.annual_dividend_10y_ago, 4)         as annual_dividend_10y_ago,

    -- CAGR
    round(c.dividend_cagr_5y * 100, 2)          as cagr_5y_pct,
    round(c.dividend_cagr_10y * 100, 2)         as cagr_10y_pct,

    -- estadísticas YoY recientes
    s.avg_yoy_5y_pct,
    s.min_yoy_5y_pct,
    s.max_yoy_5y_pct,
    s.years_positive_growth

from fundamentals f
left join cagr c          on f.ticker = c.ticker
left join latest_annual l on f.ticker = l.ticker
left join yoy_stats s     on f.ticker = s.ticker
order by cagr_5y_pct desc nulls last
