-- Yield anual = dividendo_anual / precio_cierre_fin_de_año
-- Incluye media móvil de 5 años para detectar señales de entrada

with annual_divs as (
    select * from {{ ref('int_annual_dividends') }}
),

-- Último precio de cierre de cada año por ticker
year_end_prices as (
    select
        ticker,
        year(price_date) as price_year,
        close_price      as year_end_price
    from {{ ref('stg_prices') }}
    qualify row_number() over (
        partition by ticker, year(price_date)
        order by price_date desc
    ) = 1
),

yield_by_year as (
    select
        d.ticker,
        d.dividend_year,
        d.annual_dividend,
        p.year_end_price,
        case
            when p.year_end_price > 0
            then round(d.annual_dividend / p.year_end_price, 6)
        end as dividend_yield
    from annual_divs d
    left join year_end_prices p
        on d.ticker    = p.ticker
        and d.dividend_year = p.price_year
),

with_rolling as (
    select
        ticker,
        dividend_year,
        annual_dividend,
        year_end_price,
        dividend_yield,
        round(
            avg(dividend_yield) over (
                partition by ticker
                order by dividend_year
                rows between 4 preceding and current row
            ),
            6
        ) as yield_5y_rolling_avg
    from yield_by_year
    where dividend_yield is not null
)

select * from with_rolling
order by ticker, dividend_year
