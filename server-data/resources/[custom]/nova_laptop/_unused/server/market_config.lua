-- Server-only configuration. These are FICTIONAL shares and in-game funds.
Config.Market = {
    Enabled = true,
    CashMode = 'auto', -- auto: bank for QB/QBox/ESX, paper for standalone; bank / paper
    BankAccount = 'bank',
    PracticeStartingCash = 25000, -- dollars, once per character, paper mode only
    TickSeconds = 30,
    HistoryMinutes = 1440, -- bounded 1-minute OHLC history, 24 hours
    QuoteSeconds = 10,
    SpreadBps = 10, -- total bid/ask spread, 10 basis points = 0.10%
    FeeBps = 10, -- per fill, 0.10%
    MinFeeCents = 1,
    MaxOrderShares = 10000,
    MaxPositionShares = 1000000,
    MaxOrderValue = 1000000, -- dollars, per order
    MaxAccountValue = 100000000, -- dollars, equity cap for new deposits (market gains may exceed it)
    MinTransfer = 1, -- whole dollars for framework compatibility
    MaxTransfer = 500000,
    MaxHistory = 250, -- retained trade/transfer records per account
    Stocks = {
        { symbol = 'LFI', name = 'Lifeinvader', sector = 'Technology', color = '#ed4f61',
          price = 184.52, volatility = 0.0015, description = 'Social technology, advertising and digital connections across Los Santos.' },
        { symbol = 'BNL', name = 'Bean Machine', sector = 'Consumer', color = '#bb844c',
          price = 72.38, volatility = 0.0010, description = 'A familiar cup on every corner. Coffee shops, food service and retail products.' },
        { symbol = 'VAP', name = 'Vapid Motor Co.', sector = 'Automotive', color = '#478bed',
          price = 126.84, volatility = 0.0014, description = 'Cars, commercial vehicles and manufacturing for a city that never stops moving.' },
        { symbol = 'MAZ', name = 'Maze Financial', sector = 'Finance', color = '#e34248',
          price = 238.76, volatility = 0.0010, description = 'Consumer banking, business finance and financial services in San Andreas.' },
        { symbol = 'ROR', name = 'RON Energy', sector = 'Energy', color = '#f39c39',
          price = 93.16, volatility = 0.0017, description = 'Fuel distribution, energy infrastructure and roadside service stations.' },
        { symbol = 'ECO', name = 'eCola', sector = 'Consumer', color = '#d74247',
          price = 58.92, volatility = 0.0009, description = 'Beverages, bottling and distribution with a recognisable red label.' },
        { symbol = 'FLY', name = 'FlyUS', sector = 'Travel', color = '#528bd7',
          price = 46.25, volatility = 0.0018, description = 'Passenger aviation, cargo operations and connections beyond Los Santos.' },
        { symbol = 'RWC', name = 'Redwood', sector = 'Consumer', color = '#b76f56',
          price = 112.40, volatility = 0.0012, description = 'A diversified consumer-goods company with a long history in San Andreas.' }
    }
}
