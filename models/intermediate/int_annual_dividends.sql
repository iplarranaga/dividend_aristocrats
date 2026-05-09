with dividends as (
    select * from {{ ref('stg_dividends') }}
),

annual as (
    select
        ticker,
        year(dividend_date)  as dividend_year,
        sum(dividend_amount) as annual_dividend,
        count(*)             as payment_count
    from dividends
    group by ticker, year(dividend_date)
),

with_yoy as (
    select
        ticker,
        dividend_year,
        annual_dividend,
        payment_count,
        lag(annual_dividend) over (
            partition by ticker
            order by dividend_year
        ) as prior_year_dividend,
        case
            when lag(annual_dividend) over (
                partition by ticker order by dividend_year
            ) > 0
            then round(
                (
                    annual_dividend
                    / lag(annual_dividend) over (
                        partition by ticker order by dividend_year
                    )
                    - 1
                ) * 100,
                2
            )
        end as yoy_growth_pct
    from annual
)

select * from with_yoy
order by ticker, dividend_year
