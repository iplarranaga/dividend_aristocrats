with fundamentals as (
    select * from {{ ref('stg_fundamentals') }}
),

-- Mediana por sector para contextualizar cada empresa
sector_medians as (
    select
        sector,
        round(percentile_cont(0.5) within group (order by trailing_pe), 2)   as sector_median_pe,
        round(percentile_cont(0.5) within group (order by ev_to_ebitda), 2)  as sector_median_ev_ebitda,
        round(avg(current_dividend_yield) * 100, 3)                          as sector_avg_yield_pct
    from fundamentals
    group by sector
)

select
    f.ticker,
    f.company_name,
    f.sector,
    f.market_cap,

    -- ratios de valoración
    round(f.trailing_pe, 2)                     as trailing_pe,
    round(f.forward_pe, 2)                      as forward_pe,
    round(f.ev_to_ebitda, 2)                    as ev_to_ebitda,
    round(f.price_to_book, 2)                   as price_to_book,

    -- contexto sectorial
    s.sector_median_pe,
    s.sector_median_ev_ebitda,
    case
        when f.trailing_pe is not null and s.sector_median_pe is not null
        then round(f.trailing_pe / s.sector_median_pe - 1, 4)
    end                                         as pe_vs_sector_pct,
    f.trailing_pe < s.sector_median_pe          as below_sector_median_pe,

    -- dividendo y rentabilidad
    round(f.current_dividend_yield * 100, 3)    as current_yield_pct,
    round(f.payout_ratio * 100, 2)              as payout_ratio_pct,
    round(f.trailing_eps, 4)                    as trailing_eps,
    round(f.book_value, 4)                      as book_value,

    -- precio
    f.fifty_two_week_low,
    f.fifty_two_week_high

from fundamentals f
left join sector_medians s on f.sector = s.sector
order by f.sector, f.trailing_pe nulls last
