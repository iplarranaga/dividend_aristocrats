with source as (
    select * from {{ source('raw', 'raw_fundamentals') }}
),

seed as (
    select
        ticker,
        sector          as gics_sector,
        company_name    as seed_company_name,
        consecutive_years
    from {{ ref('aristocrats') }}
),

joined as (
    select
        r.ticker,
        coalesce(r.long_name, s.seed_company_name)  as company_name,
        s.gics_sector                               as sector,
        r.industry,
        s.consecutive_years,

        -- market metrics
        cast(r.market_cap as double)                as market_cap,
        cast(r.enterprise_value as double)          as enterprise_value,

        -- valuation ratios
        cast(r.trailing_pe as double)               as trailing_pe,
        cast(r.forward_pe as double)                as forward_pe,
        cast(r.price_to_book as double)             as price_to_book,
        cast(r.ebitda as double)                    as ebitda,
        cast(r.enterprise_to_ebitda as double)      as ev_to_ebitda,

        -- dividend metrics
        cast(r.dividend_yield as double)            as current_dividend_yield,
        cast(r.dividend_rate as double)             as annual_dividend_rate,
        cast(r.payout_ratio as double)              as payout_ratio,

        -- per-share
        cast(r.trailing_eps as double)              as trailing_eps,
        cast(r.book_value as double)                as book_value,

        -- price range
        cast(r.fifty_two_week_high as double)       as fifty_two_week_high,
        cast(r.fifty_two_week_low as double)        as fifty_two_week_low,

        r.currency,
        cast(r.extracted_at as timestamp)           as extracted_at

    from source r
    inner join seed s on r.ticker = s.ticker
)

select * from joined
