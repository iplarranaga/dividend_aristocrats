with source as (
    select * from {{ source('raw', 'raw_dividends') }}
),

renamed as (
    select
        ticker,
        cast(date as date)      as dividend_date,
        cast(amount as double)  as dividend_amount
    from source
    where amount is not null
      and amount > 0
)

select * from renamed
