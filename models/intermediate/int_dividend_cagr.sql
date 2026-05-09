-- CAGR 5y = (div_ref_year / div_ref_year-5)^(1/5) - 1
-- Año de referencia: último año completo (año actual - 1)

with annual as (
    select * from {{ ref('int_annual_dividends') }}
),

ref_year as (
    select year(current_date) - 1 as ref_yr
),

pivoted as (
    select
        a.ticker,
        max(case when a.dividend_year = r.ref_yr      then a.annual_dividend end) as div_yr0,
        max(case when a.dividend_year = r.ref_yr - 5  then a.annual_dividend end) as div_yr5,
        max(case when a.dividend_year = r.ref_yr - 10 then a.annual_dividend end) as div_yr10
    from annual a
    cross join ref_year r
    group by a.ticker
)

select
    ticker,
    div_yr0  as annual_dividend_current,
    div_yr5  as annual_dividend_5y_ago,
    div_yr10 as annual_dividend_10y_ago,
    case
        when div_yr5 > 0 and div_yr0 > 0
        then round(power(div_yr0 / div_yr5, 1.0 / 5) - 1, 6)
    end as dividend_cagr_5y,
    case
        when div_yr10 > 0 and div_yr0 > 0
        then round(power(div_yr0 / div_yr10, 1.0 / 10) - 1, 6)
    end as dividend_cagr_10y
from pivoted
