-- Crypto (LCN exchange): server-owned coin prices that drift every few minutes, holdings per
-- character, buy with bank money, withdraw (sell) to the bank, transfer coins by phone number.
-- Prices, balances and amounts are always computed here; the client only sends what it wants.
local CFG = Config.Crypto or {}
local COINS = CFG.Coins or {}

Schema.Register([[CREATE TABLE IF NOT EXISTS `oph3z_phone_np_crypto_prices` (
    `coin` VARCHAR(16) NOT NULL,
    `price` DOUBLE NOT NULL DEFAULT 0,
    `history` TEXT DEFAULT NULL,
    `updated_at` INT UNSIGNED NOT NULL DEFAULT 0,
    PRIMARY KEY (`coin`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])

Schema.Register([[CREATE TABLE IF NOT EXISTS `oph3z_phone_np_crypto` (
    `cid` VARCHAR(64) NOT NULL,
    `coin` VARCHAR(16) NOT NULL,
    `amount` DOUBLE NOT NULL DEFAULT 0,
    PRIMARY KEY (`cid`, `coin`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])

Schema.Register([[CREATE TABLE IF NOT EXISTS `oph3z_phone_np_crypto_tx` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `cid` VARCHAR(64) NOT NULL,
    `coin` VARCHAR(16) NOT NULL,
    `kind` VARCHAR(12) NOT NULL,
    `amount` DOUBLE NOT NULL DEFAULT 0,
    `usd` INT NOT NULL DEFAULT 0,
    `party` VARCHAR(64) DEFAULT NULL,
    `ts` INT UNSIGNED NOT NULL DEFAULT 0,
    PRIMARY KEY (`id`),
    KEY `idx_cid` (`cid`, `id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]])

local HISTORY = 48
local prices = {} -- coin -> { price, history = { ... } }
local loaded = false

local function coinDef(id)
    for _, c in ipairs(COINS) do
        if c.id == id then return c end
    end
    return nil
end

local function round(n, d)
    local m = 10 ^ (d or 2)
    return math.floor(n * m + 0.5) / m
end

local function load()
    if loaded then return end
    Sql.Wait()
    for _, row in ipairs(Sql.Query('SELECT `coin`, `price`, `history` FROM `oph3z_phone_np_crypto_prices`')) do
        prices[row.coin] = { price = tonumber(row.price) or 0, history = Sql.Decode(row.history, {}) }
    end
    for _, c in ipairs(COINS) do
        if not prices[c.id] or (prices[c.id].price or 0) <= 0 then
            prices[c.id] = { price = c.price or 100, history = { c.price or 100 } }
            Sql.Execute('INSERT INTO `oph3z_phone_np_crypto_prices` (`coin`, `price`, `history`, `updated_at`) VALUES (?, ?, ?, ?) ' ..
                'ON DUPLICATE KEY UPDATE `price` = VALUES(`price`), `history` = VALUES(`history`)',
                { c.id, prices[c.id].price, json.encode(prices[c.id].history), os.time() })
        end
    end
    loaded = true
end

-- Box-Muller normal sample
local function gauss()
    local u1, u2 = math.random(), math.random()
    if u1 < 1e-9 then u1 = 1e-9 end
    return math.sqrt(-2 * math.log(u1)) * math.cos(2 * math.pi * u2)
end

local function tick()
    load()
    for _, c in ipairs(COINS) do
        local p = prices[c.id]
        local vol = tonumber(c.volatility) or 0.03
        local next = p.price * (1 + gauss() * vol)
        next = math.max(tonumber(c.min) or 1, math.min(tonumber(c.max) or 1e9, next))
        p.price = round(next, 2)
        p.history[#p.history + 1] = p.price
        while #p.history > HISTORY do table.remove(p.history, 1) end
        Sql.Execute('UPDATE `oph3z_phone_np_crypto_prices` SET `price` = ?, `history` = ?, `updated_at` = ? WHERE `coin` = ?',
            { p.price, json.encode(p.history), os.time(), c.id })
    end
end

CreateThread(function()
    Sql.Wait()
    load()
    local minutes = math.max(1, tonumber(CFG.TickMinutes) or 10)
    while true do
        Wait(minutes * 60000)
        pcall(tick)
    end
end)

local function holdings(cid)
    local out = {}
    for _, row in ipairs(Sql.Query('SELECT `coin`, `amount` FROM `oph3z_phone_np_crypto` WHERE `cid` = ?', { cid })) do
        if (tonumber(row.amount) or 0) > 0.0000001 then out[row.coin] = tonumber(row.amount) end
    end
    return out
end

local function holding(cid, coin)
    return tonumber(Sql.Scalar('SELECT `amount` FROM `oph3z_phone_np_crypto` WHERE `cid` = ? AND `coin` = ?', { cid, coin })) or 0
end

local function addHolding(cid, coin, delta)
    Sql.Execute('INSERT INTO `oph3z_phone_np_crypto` (`cid`, `coin`, `amount`) VALUES (?, ?, ?) ' ..
        'ON DUPLICATE KEY UPDATE `amount` = GREATEST(0, `amount` + VALUES(`amount`))', { cid, coin, delta })
end

local function logTx(cid, coin, kind, amount, usd, party)
    Sql.Execute('INSERT INTO `oph3z_phone_np_crypto_tx` (`cid`, `coin`, `kind`, `amount`, `usd`, `party`, `ts`) VALUES (?, ?, ?, ?, ?, ?, ?)',
        { cid, coin, kind, amount, math.floor(usd or 0), party, os.time() })
end

local function coinList()
    load()
    local out = {}
    for _, c in ipairs(COINS) do
        local p = prices[c.id]
        local first = p.history[1] or p.price
        out[#out + 1] = {
            id = c.id, label = c.label, symbol = c.symbol or c.id:upper(), icon = c.icon,
            price = p.price, change = first > 0 and round((p.price - first) / first * 100, 2) or 0,
            history = p.history,
        }
    end
    return out
end

local fee = function() return math.max(0, tonumber(CFG.FeePercent) or 0) / 100 end
-- per-player lock so two quick requests can't spend the same balance twice
local busy = {}

NP.cb('crypto:home', function(src, cid)
    Sql.Wait()
    return { ok = true, coins = coinList(), holdings = holdings(cid), balance = Bank.Get(cid), name = NP.name(src), fee = fee() * 100, minPurchase = tonumber(CFG.MinPurchase) or 1 }
end)

NP.cb('crypto:history', function(src, cid)
    Sql.Wait()
    return { ok = true, items = Sql.Query('SELECT `id`, `coin`, `kind`, `amount`, `usd`, `party`, `ts` FROM `oph3z_phone_np_crypto_tx` WHERE `cid` = ? ORDER BY `id` DESC LIMIT 50', { cid }) }
end)

NP.cb('crypto:buy', function(src, cid, data)
    local c = coinDef(tostring(data.coin or ''))
    local usd = math.floor(tonumber(data.usd) or 0)
    if not c then return { ok = false, reason = 'coin' } end
    if usd < (tonumber(CFG.MinPurchase) or 1) or usd > (tonumber(CFG.MaxPurchase) or 1000000) then return { ok = false, reason = 'amount' } end
    if busy[src] then return { ok = false, reason = 'slow' } end
    busy[src] = true
    load()
    local price = prices[c.id].price
    local amount = round((usd * (1 - fee())) / price, 6)
    local ok = NP.charge(cid, usd, 'LCN Exchange', ('Bought %s %s'):format(amount, c.symbol or c.id:upper()))
    if ok then
        addHolding(cid, c.id, amount)
        logTx(cid, c.id, 'buy', amount, usd)
    end
    busy[src] = nil
    if not ok then return { ok = false, reason = 'funds' } end
    return { ok = true, amount = amount, holdings = holdings(cid), balance = Bank.Get(cid) }
end)

NP.cb('crypto:sell', function(src, cid, data)
    local c = coinDef(tostring(data.coin or ''))
    local amount = round(tonumber(data.amount) or 0, 6)
    if not c then return { ok = false, reason = 'coin' } end
    if amount <= 0 then return { ok = false, reason = 'amount' } end
    if busy[src] then return { ok = false, reason = 'slow' } end
    busy[src] = true
    load()
    Sql.Wait()
    local have = holding(cid, c.id)
    if amount > have + 0.0000001 then
        busy[src] = nil
        return { ok = false, reason = 'coins' }
    end
    amount = math.min(amount, have)
    local usd = math.floor(amount * prices[c.id].price * (1 - fee()))
    if usd < 1 then
        busy[src] = nil
        return { ok = false, reason = 'amount' }
    end
    addHolding(cid, c.id, -amount)
    local paid = NP.pay(cid, usd, 'LCN Exchange', ('Sold %s %s'):format(amount, c.symbol or c.id:upper()))
    if not paid then addHolding(cid, c.id, amount) end
    if paid then logTx(cid, c.id, 'sell', amount, usd) end
    busy[src] = nil
    if not paid then return { ok = false, reason = 'failed' } end
    return { ok = true, usd = usd, holdings = holdings(cid), balance = Bank.Get(cid) }
end)

NP.cb('crypto:transfer', function(src, cid, data)
    local c = coinDef(tostring(data.coin or ''))
    local amount = round(tonumber(data.amount) or 0, 6)
    if not c then return { ok = false, reason = 'coin' } end
    if amount <= 0 then return { ok = false, reason = 'amount' } end
    local digits = DB.Digits(data.number or '')
    local target = digits ~= '' and DB.GetCitizenIdByNumber(digits) or nil
    if not target then return { ok = false, reason = 'notfound' } end
    if target == cid then return { ok = false, reason = 'self' } end
    if busy[src] then return { ok = false, reason = 'slow' } end
    busy[src] = true
    Sql.Wait()
    local have = holding(cid, c.id)
    if amount > have + 0.0000001 then
        busy[src] = nil
        return { ok = false, reason = 'coins' }
    end
    addHolding(cid, c.id, -amount)
    addHolding(target, c.id, amount)
    local myName = NP.name(src)
    logTx(cid, c.id, 'sent', amount, 0, NP.number(target))
    logTx(target, c.id, 'received', amount, 0, NP.number(cid))
    NP.notify(target, 'crypto', 'LCN Exchange', ('%s sent you %s %s.'):format(myName, amount, c.symbol or c.id:upper()))
    busy[src] = nil
    return { ok = true, holdings = holdings(cid) }
end)

AddEventHandler('playerDropped', function() busy[source] = nil end)
