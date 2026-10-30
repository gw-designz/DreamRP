Market = {}
local state, failed
local storageKey = 'nova:market:v1'
local function integer(value, min, max)
    return type(value) == 'number' and value == value and value % 1 == 0 and value >= min and value <= max
end
Market.IsInteger = integer
local function round(n) return math.floor(n + 0.5) end
local function clamp(n, lo, hi) return math.max(lo, math.min(hi, n)) end
local function now() return os.time() end

local function save()
    local encoded = json.encode(state)
    SetResourceKvp(storageKey, encoded)
    if GetResourceKvpString(storageKey) ~= encoded then error('Market storage write failed.') end
end

local function seed(spec, time)
    local price = round(spec.price * 100)
    local minute = math.floor(time / 60) * 60
    local candles, cursor = {}, price
    -- Initial fictional history is generated once. Subsequent candles record ticks.
    for i = Config.Market.HistoryMinutes, 1, -1 do
        local previous = clamp(round(cursor * (1 + (math.random() * 2 - 1) * spec.volatility * 1.8)), 100, 100000000)
        candles[i] = { t = minute - (Config.Market.HistoryMinutes - i) * 60,
            o = previous, h = math.max(previous, cursor), l = math.min(previous, cursor), c = cursor }
        cursor = previous
    end
    return { symbol = spec.symbol, name = spec.name, sector = spec.sector, color = spec.color,
        description = spec.description, priceCents = price, volatility = spec.volatility,
        active = true, candles = candles }
end

function Market.Init()
    assert(integer(Config.Market.TickSeconds, 5, 3600), 'TickSeconds must be an integer between 5 and 3600.')
    assert(integer(Config.Market.HistoryMinutes, 60, 2880), 'HistoryMinutes must be between 60 and 2880.')
    assert(integer(Config.Market.SpreadBps, 0, 1000) and integer(Config.Market.FeeBps, 0, 1000), 'Invalid trading fees.')
    assert(integer(Config.Market.MinFeeCents, 0, 1000000), 'Invalid minimum fee.')
    assert(integer(Config.Market.QuoteSeconds, 2, 30), 'QuoteSeconds must be between 2 and 30.')
    assert(integer(Config.Market.MaxOrderShares, 1, 1000000) and integer(Config.Market.MaxPositionShares, 1, 1000000), 'Invalid share limits.')
    assert(integer(Config.Market.PracticeStartingCash, 0, 100000000), 'Invalid practice starting balance.')
    assert(integer(Config.Market.MaxHistory, 1, 1000), 'MaxHistory must be between 1 and 1000.')
    assert(#Config.Market.Stocks > 0 and #Config.Market.Stocks <= 32, 'Configure between 1 and 32 stocks.')
    local raw = GetResourceKvpString(storageKey)
    if raw then
        local ok, decoded = pcall(json.decode, raw)
        if not ok or type(decoded) ~= 'table' or decoded.version ~= 1 or type(decoded.stocks) ~= 'table' then
            error('Saved market data is unreadable. Restore the KVP backup; it will not be reset automatically.')
        end
        state = decoded
    else state = { version = 1, revision = 1, updatedAt = now(), stocks = {} } end
    local seen = {}
    for _, stock in pairs(state.stocks) do stock.active = false end
    for _, spec in ipairs(Config.Market.Stocks) do
        assert(type(spec.symbol) == 'string' and spec.symbol:match('^[A-Z][A-Z0-9]*$') and #spec.symbol <= 8 and not seen[spec.symbol], 'Stock symbols must be unique uppercase IDs.')
        assert(type(spec.price) == 'number' and spec.price >= 1 and spec.price <= 1000000, 'Invalid starting stock price.')
        assert(type(spec.volatility) == 'number' and spec.volatility >= 0 and spec.volatility <= 0.02, 'Invalid stock volatility.')
        seen[spec.symbol] = true
        local stock = state.stocks[spec.symbol] or seed(spec, now())
        assert(integer(stock.priceCents, 100, 100000000) and type(stock.candles) == 'table' and #stock.candles > 0, 'Invalid persisted stock.')
        stock.name, stock.sector, stock.color, stock.description = spec.name, spec.sector, spec.color, spec.description
        stock.volatility, stock.active = spec.volatility, true
        state.stocks[spec.symbol] = stock
    end
    save()
end

function Market.Tick()
    if failed then error(failed) end
    if not state then Market.Init() end
    local time = now()
    if time - state.updatedAt < Config.Market.TickSeconds then return end
    -- One bounded update after downtime; restarting cannot fast-forward thousands of ticks.
    local common = (math.random() * 2 - 1) * 0.00035
    for _, stock in pairs(state.stocks) do
        if stock.active then
            local move = common + (math.random() * 2 - 1) * stock.volatility
            local old = stock.priceCents
            stock.priceCents = clamp(round(old * (1 + move)), 100, 100000000)
            local last, minute = stock.candles[#stock.candles], math.floor(time / 60) * 60
            if last and last.t == minute then
                last.h, last.l, last.c = math.max(last.h, stock.priceCents), math.min(last.l, stock.priceCents), stock.priceCents
            else
                stock.candles[#stock.candles + 1] = { t = minute, o = old, h = math.max(old, stock.priceCents), l = math.min(old, stock.priceCents), c = stock.priceCents }
                while #stock.candles > Config.Market.HistoryMinutes do table.remove(stock.candles, 1) end
            end
        end
    end
    state.updatedAt, state.revision = time, state.revision + 1
    local ok, err = pcall(save)
    if not ok then failed = 'Market persistence failed; trading is paused until the resource is restarted.'; error(err) end
end

function Market.Get(symbol)
    Market.Tick()
    if type(symbol) ~= 'string' or #symbol > 8 then return nil end
    return state.stocks[symbol]
end

function Market.Prices(stock)
    local half = Config.Market.SpreadBps / 20000
    return math.floor(stock.priceCents * (1 - half)), math.ceil(stock.priceCents * (1 + half))
end

function Market.Quotes()
    Market.Tick()
    local quotes = {}
    for _, stock in pairs(state.stocks) do
        local candles, time = stock.candles, now() - 86400
        local reference = candles[1].o
        local high, low, spark = stock.priceCents, stock.priceCents, {}
        local stride = math.max(1, math.floor(#candles / 28))
        for i, c in ipairs(candles) do
            if c.t <= time then reference = c.c end
            if c.t >= time then high, low = math.max(high, c.h), math.min(low, c.l) end
            if i % stride == 0 then spark[#spark + 1] = c.c end
        end
        spark[#spark + 1] = stock.priceCents
        local bid, ask = Market.Prices(stock)
        quotes[#quotes + 1] = { symbol = stock.symbol, name = stock.name, sector = stock.sector,
            description = stock.description, color = stock.color, active = stock.active,
            priceCents = stock.priceCents, bidCents = bid, askCents = ask,
            changeCents = stock.priceCents - reference, changePct = (stock.priceCents - reference) / reference * 100,
            highCents = high, lowCents = low, openCents = reference, spark = spark }
    end
    table.sort(quotes, function(a, b) return a.symbol < b.symbol end)
    return quotes, state.revision, state.updatedAt
end

function Market.Chart(symbol, period)
    local stock = Market.Get(symbol)
    if not stock then return nil, 'Unknown stock.' end
    local periods = { ['1H'] = 3600, ['6H'] = 21600, ['1D'] = 86400 }
    if not periods[period] then return nil, 'Unknown chart range.' end
    local filtered, result = {}, {}
    for _, candle in ipairs(stock.candles) do
        if candle.t >= now() - periods[period] then filtered[#filtered + 1] = candle end
    end
    local step = math.max(1, math.ceil(#filtered / 100))
    for i = 1, #filtered, step do
        local first = filtered[i]
        local bar = { t = first.t, o = first.o, h = first.h, l = first.l, c = first.c }
        for j = i, math.min(i + step - 1, #filtered) do
            local c = filtered[j]; bar.h, bar.l, bar.c = math.max(bar.h, c.h), math.min(bar.l, c.l), c.c
        end
        result[#result + 1] = bar
    end
    return { symbol = symbol, period = period, candles = result, updatedAt = state.updatedAt * 1000 }
end

function Market.Revision() Market.Tick(); return state.revision end

CreateThread(function()
    while true do
        if Config.Market.Enabled then
            local ok, err = pcall(Market.Tick)
            if not ok then print(('[nova_laptop] Market: %s'):format(err)) end
        end
        Wait(Config.Market.TickSeconds * 1000)
    end
end)
