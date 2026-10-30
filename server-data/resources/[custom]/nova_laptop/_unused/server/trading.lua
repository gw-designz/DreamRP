Trading = {}
local locks, quotes = {}, {}
local integer = Market.IsInteger
local function failure(text) return { ok = false, error = text } end
local function cents(dollars) return math.floor(dollars * 100 + 0.5) end
local function validId(id) return type(id) == 'string' and #id >= 8 and #id <= 64 and id:match('^[%w_-]+$') end
local function modeFor(context)
    local mode = Config.Market.CashMode
    if mode == 'auto' then mode = context.framework == 'standalone' and 'paper' or 'bank' end
    assert(mode == 'bank' or mode == 'paper', 'Invalid market cash mode.')
    return mode
end
local function keyFor(context) return 'nova:invest:v1:' .. modeFor(context) .. ':' .. context.key end

local function write(key, account)
    local encoded = json.encode(account)
    SetResourceKvp(key, encoded)
    if GetResourceKvpString(key) ~= encoded then error('Brokerage persistence failed. Refresh before retrying.') end
end

local function read(context)
    local key, mode = keyFor(context), modeFor(context)
    local raw = GetResourceKvpString(key)
    if raw then
        local ok, account = pcall(json.decode, raw)
        if not ok or type(account) ~= 'table' or account.version ~= 1 or account.mode ~= mode
            or not integer(account.cashCents, 0, 9000000000000) or not integer(account.revision, 0, 2147483647)
            or type(account.positions) ~= 'table' or type(account.history) ~= 'table'
            or type(account.receipts) ~= 'table' or type(account.watchlist) ~= 'table' then
            error('Saved brokerage account is unreadable. Restore its KVP backup.')
        end
        return account, key
    end
    local starting = mode == 'paper' and cents(Config.Market.PracticeStartingCash) or 0
    local watchlist = {}
    for i = 1, math.min(4, #Config.Market.Stocks) do watchlist[i] = Config.Market.Stocks[i].symbol end
    local account = { version = 1, mode = mode, revision = 0, cashCents = starting, positions = {},
        watchlist = watchlist, history = {}, receipts = {}, realizedPnlCents = 0, feesPaidCents = 0,
        netDepositsCents = starting, createdAt = os.time() * 1000 }
    write(key, account)
    return account, key
end

local function receipt(account, id)
    for _, item in ipairs(account.receipts) do if item.id == id then return item end end
end

local function remember(account, id, message, ok)
    account.receipts[#account.receipts + 1] = { id = id, message = message, ok = ok ~= false }
    while #account.receipts > 80 do table.remove(account.receipts, 1) end
end

local function record(account, item)
    item.at, item.cashAfterCents = os.time() * 1000, account.cashCents
    table.insert(account.history, 1, item)
    while #account.history > Config.Market.MaxHistory do table.remove(account.history) end
end

local function valuation(account)
    local invested, cost, positions = 0, 0, {}
    for symbol, position in pairs(account.positions) do
        assert(integer(position.quantity, 1, 1000000000) and integer(position.costBasisCents, 0, 9000000000000), 'Invalid saved holding.')
        local stock = Market.Get(symbol)
        if not stock then error('A held stock has no saved price. Restore the market data.') end
        local value = stock.priceCents * position.quantity
        invested, cost = invested + value, cost + position.costBasisCents
        positions[#positions + 1] = { symbol = symbol, quantity = position.quantity, costBasisCents = position.costBasisCents,
            valueCents = value, pnlCents = value - position.costBasisCents,
            averageCents = position.costBasisCents / position.quantity, openedAt = position.openedAt }
    end
    table.sort(positions, function(a, b) return a.valueCents > b.valueCents end)
    return invested, cost, positions
end

function Trading.Snapshot(context)
    if not Config.Market.Enabled then return nil, 'The stock exchange is disabled.' end
    local prices, revision, updatedAt = Market.Quotes()
    local account = read(context)
    local invested, cost, positions = valuation(account)
    local bankBalance
    if account.mode == 'bank' then bankBalance = cents(Bridge.BankBalance(context)) end
    return {
        quotes = prices, marketRevision = revision, updatedAt = updatedAt * 1000, serverTime = os.time() * 1000,
        tickSeconds = Config.Market.TickSeconds,
        account = { mode = account.mode, revision = account.revision, cashCents = account.cashCents,
            positions = positions, history = account.history, watchlist = account.watchlist,
            realizedPnlCents = account.realizedPnlCents, unrealizedPnlCents = invested - cost,
            equityCents = account.cashCents + invested, investedCents = invested,
            feesPaidCents = account.feesPaidCents, netDepositsCents = account.netDepositsCents,
            bankBalanceCents = bankBalance, createdAt = account.createdAt,
            pendingTransfer = account.pendingTransfer },
        rules = { feeBps = Config.Market.FeeBps, spreadBps = Config.Market.SpreadBps,
            minFeeCents = Config.Market.MinFeeCents, maxOrderShares = Config.Market.MaxOrderShares,
            maxOrderValueCents = cents(Config.Market.MaxOrderValue),
            minTransfer = Config.Market.MinTransfer, maxTransfer = Config.Market.MaxTransfer }
    }
end

local function success(context, message, replayed)
    local snapshot, err = Trading.Snapshot(context)
    if not snapshot then return failure(err) end
    return { ok = true, market = snapshot, message = message, replayed = replayed or false }
end

local function locked(context, callback)
    local key = keyFor(context)
    if locks[key] then return failure('A brokerage action is already processing. Please wait.') end
    locks[key] = true
    local ok, result = pcall(callback)
    locks[key] = nil
    if not ok then
        print(('[nova_laptop] Brokerage action failed: %s'):format(result))
        return failure('The action was not confirmed. Refresh your account before retrying; do not assume funds moved.')
    end
    return result
end

local function mutation(context, input, callback)
    return locked(context, function()
        if not validId(input.requestId) or not integer(input.revision, 0, 2147483647) then return failure('Invalid account request.') end
        local account, key = read(context)
        local previous = receipt(account, input.requestId)
        if previous then
            if previous.ok == false then return failure(previous.message) end
            return success(context, previous.message, true)
        end
        if account.pendingTransfer then return failure('A bank transfer needs staff reconciliation. Your brokerage account is temporarily locked.') end
        if account.revision ~= input.revision then return failure('Your account changed. Refresh the account and review the action again.') end
        return callback(account, key)
    end)
end

function Trading.Quote(context, input)
    return locked(context, function()
        local account = read(context)
        if account.pendingTransfer then return failure('A bank transfer needs staff reconciliation before you can trade.') end
        if input.side ~= 'buy' and input.side ~= 'sell' then return failure('Invalid order side.') end
        if not integer(input.quantity, 1, Config.Market.MaxOrderShares) then return failure('Enter a valid whole number of shares.') end
        local stock = Market.Get(input.symbol)
        if not stock or (input.side == 'buy' and not stock.active) then return failure('This stock is unavailable for buying.') end
        local bid, ask = Market.Prices(stock)
        local price = input.side == 'buy' and ask or bid
        local gross = price * input.quantity
        if gross > cents(Config.Market.MaxOrderValue) then return failure('Order exceeds the maximum trade value.') end
        local fee = math.max(Config.Market.MinFeeCents, math.floor(gross * Config.Market.FeeBps / 10000 + 0.5))
        local total = gross + (input.side == 'buy' and fee or -fee)
        if total <= 0 then return failure('Order is too small after fees.') end
        local position = account.positions[input.symbol]
        if input.side == 'buy' and (position and position.quantity or 0) + input.quantity > Config.Market.MaxPositionShares then
            return failure('This order exceeds the maximum shares per company.')
        end
        if input.side == 'sell' and account.cashCents + total > 9000000000000 then return failure('Brokerage cash limit reached.') end
        if input.side == 'buy' and account.cashCents < total then return failure('Insufficient buying power. Add funds or reduce the quantity.') end
        if input.side == 'sell' and (not position or position.quantity < input.quantity) then return failure('You do not own enough shares to sell.') end
        local token = ('quote_%s_%s_%s'):format(os.time(), math.random(100000, 999999), math.random(100000, 999999))
        local quote = { token = token, symbol = stock.symbol, name = stock.name, side = input.side,
            quantity = input.quantity, priceCents = price, grossCents = gross, feeCents = fee,
            totalCents = total, expiresAt = (os.time() + Config.Market.QuoteSeconds) * 1000,
            accountRevision = account.revision, marketRevision = Market.Revision() }
        quotes[keyFor(context)] = quote
        return { ok = true, quote = quote, serverTime = os.time() * 1000 }
    end)
end

function Trading.Execute(context, input)
    return mutation(context, input, function(account, key)
        local quote = quotes[key]
        if not quote or type(input.token) ~= 'string' or quote.token ~= input.token then return failure('Get a new order quote before confirming.') end
        if quote.expiresAt <= os.time() * 1000 or quote.marketRevision ~= Market.Revision() then
            quotes[key] = nil; return failure('The market moved or the quote expired. Review a fresh quote.')
        end
        if quote.accountRevision ~= account.revision then return failure('Your account changed. Review a fresh quote.') end
        local position = account.positions[quote.symbol]
        local realized = 0
        if quote.side == 'buy' then
            if account.cashCents < quote.totalCents then return failure('Insufficient buying power.') end
            position = position or { quantity = 0, costBasisCents = 0, openedAt = os.time() * 1000 }
            position.quantity, position.costBasisCents = position.quantity + quote.quantity, position.costBasisCents + quote.totalCents
            account.positions[quote.symbol] = position
            account.cashCents = account.cashCents - quote.totalCents
        else
            if not position or position.quantity < quote.quantity then return failure('Insufficient shares.') end
            local cost = quote.quantity == position.quantity and position.costBasisCents
                or math.floor(position.costBasisCents * quote.quantity / position.quantity)
            realized = quote.totalCents - cost
            position.quantity, position.costBasisCents = position.quantity - quote.quantity, position.costBasisCents - cost
            if position.quantity == 0 then account.positions[quote.symbol] = nil end
            account.cashCents = account.cashCents + quote.totalCents
            account.realizedPnlCents = account.realizedPnlCents + realized
        end
        account.feesPaidCents = account.feesPaidCents + quote.feeCents
        account.revision = account.revision + 1
        local message = (quote.side == 'buy' and 'Bought ' or 'Sold ') .. quote.quantity .. ' ' .. quote.symbol .. ' shares.'
        record(account, { id = input.requestId, type = quote.side, symbol = quote.symbol, quantity = quote.quantity,
            priceCents = quote.priceCents, feeCents = quote.feeCents, amountCents = quote.totalCents,
            realizedPnlCents = realized })
        remember(account, input.requestId, message)
        write(key, account) -- Cash, shares, cost basis, P/L and receipt commit together.
        quotes[key] = nil
        return success(context, message)
    end)
end

function Trading.Watch(context, input)
    return mutation(context, input, function(account, key)
        if not Market.Get(input.symbol) or type(input.watched) ~= 'boolean' then return failure('Invalid watchlist change.') end
        local found
        for i, symbol in ipairs(account.watchlist) do if symbol == input.symbol then found = i break end end
        if input.watched and not found then account.watchlist[#account.watchlist + 1] = input.symbol
        elseif not input.watched and found then table.remove(account.watchlist, found) end
        account.revision = account.revision + 1
        local message = input.watched and 'Added to your watchlist.' or 'Removed from your watchlist.'
        remember(account, input.requestId, message); write(key, account)
        return success(context, message)
    end)
end

local function finishTransfer(account, transfer)
    local delta = transfer.direction == 'deposit' and transfer.amountCents or -transfer.amountCents
    account.cashCents = account.cashCents + delta
    account.netDepositsCents = account.netDepositsCents + delta
    account.pendingTransfer = nil
    account.revision = account.revision + 1
    local message = transfer.direction == 'deposit' and 'Funds added to your brokerage account.' or 'Funds returned to your in-game bank.'
    record(account, { id = transfer.id, type = transfer.direction, amountCents = transfer.amountCents, feeCents = 0 })
    remember(account, transfer.id, message)
    return message
end

function Trading.Transfer(context, input)
    return mutation(context, input, function(account, key)
        if account.mode ~= 'bank' then return failure('Practice funds cannot be moved into the game economy.') end
        if input.direction ~= 'deposit' and input.direction ~= 'withdraw' then return failure('Invalid transfer direction.') end
        if not integer(input.amount, Config.Market.MinTransfer, Config.Market.MaxTransfer) then return failure('Enter a whole-dollar amount within the transfer limits.') end
        local amount = input.amount * 100
        if input.direction == 'withdraw' and account.cashCents < amount then return failure('Not enough available brokerage cash.') end
        if input.direction == 'deposit' then
            if Bridge.BankBalance(context) < input.amount then return failure('Your in-game bank has insufficient funds.') end
            local invested = valuation(account)
            if account.cashCents + invested + amount > cents(Config.Market.MaxAccountValue) then return failure('This deposit exceeds the brokerage account limit.') end
        end
        local transfer = { id = input.requestId, direction = input.direction, amountCents = amount, at = os.time() * 1000 }
        account.pendingTransfer = transfer
        write(key, account) -- Durable journal BEFORE touching the external bank.
        local result = Bridge.BankTransfer(context, input.direction, input.amount, input.requestId)
        if result == false then
            account.pendingTransfer = nil; account.revision = account.revision + 1
            remember(account, input.requestId, 'Bank declined this transfer. No brokerage funds moved.', false)
            write(key, account)
            return failure('The bank declined this transfer. Refresh the account before retrying.')
        end
        if result ~= true then error('The bank adapter returned an ambiguous transfer outcome.') end
        local message = finishTransfer(account, transfer)
        write(key, account)
        print(('[nova_laptop] Transfer %s completed: %s $%d.'):format(transfer.id, transfer.direction, input.amount))
        return success(context, message)
    end)
end

-- No automatic retries or refunds after an uncertain cross-resource transfer.
-- Console only; staff first inspect the matching reference in bank logs.
function Trading.Resolve(context, id, applied)
    return locked(context, function()
        local account, key = read(context)
        local pending = account.pendingTransfer
        if not pending or pending.id ~= id then return failure('Pending transfer ID does not match.') end
        local message
        if applied then message = finishTransfer(account, pending)
        else
            account.pendingTransfer = nil; account.revision = account.revision + 1
            message = 'Transfer reconciled: bank operation was not applied.'
            remember(account, pending.id, message)
        end
        write(key, account)
        return { ok = true, message = message }
    end)
end

RegisterCommand('novainvest_resolve', function(src, args)
    if src ~= 0 then return end
    local playerSource = tonumber(args[1])
    local resolution = args[3]
    if not playerSource or not args[2] or (resolution ~= 'applied' and resolution ~= 'not_applied') then
        print('Usage: novainvest_resolve <online-player-id> <exact-transfer-id> <applied|not_applied>') return
    end
    local context = Bridge.Context(playerSource)
    if not context then print('[nova_laptop] Character must be online for reconciliation.') return end
    local result = Trading.Resolve(context, args[2], resolution == 'applied')
    print(('[nova_laptop] Reconcile %s: %s'):format(args[2], result.message or result.error))
end, false)

function Trading.Handle(context, name, input)
    if not Config.Market.Enabled then return failure('The stock exchange is disabled.') end
    if name == 'marketSnapshot' then
        local snapshot, err = Trading.Snapshot(context); return { ok = snapshot ~= nil, market = snapshot, error = err }
    elseif name == 'marketChart' then
        local chart, err = Market.Chart(input.symbol, input.period); return { ok = chart ~= nil, chart = chart, error = err }
    elseif name == 'marketQuote' then return Trading.Quote(context, input)
    elseif name == 'marketTrade' then return Trading.Execute(context, input)
    elseif name == 'marketWatch' then return Trading.Watch(context, input)
    elseif name == 'marketTransfer' then return Trading.Transfer(context, input) end
    return failure('Unknown brokerage action.')
end
