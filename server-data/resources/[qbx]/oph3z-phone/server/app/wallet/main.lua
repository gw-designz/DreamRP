local MAX_TX = 100

local function cidOf(src)
    return GetIdentifier(src)
end

local function listTx(citizenid)
    Sql.Wait()
    return Sql.Query(
        'SELECT `id`, `kind`, `amount`, `party`, `number`, `note`, `ts` FROM `oph3z_phone_transactions` ' ..
        'WHERE `citizenid` = ? ORDER BY `id` DESC LIMIT ?',
        { citizenid, MAX_TX }
    )
end

local function bankOf(src)
    return Bank.Get(cidOf(src))
end

local function comma(n)
    local s = tostring(math.floor(tonumber(n) or 0))
    return (s:reverse():gsub('(%d%d%d)', '%1,'):reverse():gsub('^,', ''))
end

local function logTx(citizenid, tx)
    tx.ts = tx.ts or os.time()

    Sql.Wait()
    tx.id = Sql.Insert(
        'INSERT INTO `oph3z_phone_transactions` (`citizenid`, `kind`, `amount`, `party`, `number`, `note`, `ts`) ' ..
        'VALUES (?, ?, ?, ?, ?, ?, ?)',
        { citizenid, tx.kind, math.floor(tonumber(tx.amount) or 0), tx.party, tx.number, tx.note, tx.ts }
    )
    Sql.Execute(
        'DELETE FROM `oph3z_phone_transactions` WHERE `citizenid` = ? AND `id` NOT IN ' ..
        '(SELECT `id` FROM (SELECT `id` FROM `oph3z_phone_transactions` WHERE `citizenid` = ? ORDER BY `id` DESC LIMIT ?) AS keep)',
        { citizenid, citizenid, MAX_TX }
    )
    return tx
end

-- Other phone apps (Crypto, Guber, Property, ...) record bank movements through this so they
-- show up in the Bank app's transaction list.
Wallet = Wallet or {}
function Wallet.Log(citizenid, tx)
    if not citizenid or type(tx) ~= 'table' then return nil end
    local logged = logTx(citizenid, tx)
    local src = GetSourceById(citizenid)
    if src then
        TriggerClientEvent('oph3z-phone:client:wallet:incoming', src, { balance = Bank.Get(citizenid), tx = logged })
    end
    return logged
end

RegisterCallback('oph3z-phone:server:wallet:get', function(src)
    local cid = cidOf(src)
    if not cid then return {} end
    return {
        balance      = bankOf(src),
        transactions = listTx(cid),
        bills        = (BillsProvider.Get and BillsProvider.Get(cid, src)) or {},
        serverId     = src,
        accountId    = cid, -- shown as "Account ID" in the Bank app; transfers accept it
    }
end)

RegisterCallback('oph3z-phone:server:wallet:send', function(src, data)
    local cid = cidOf(src)
    if not cid or type(data) ~= 'table' then return { ok = false, reason = 'bad' } end

    local amount = math.floor(tonumber(data.amount) or 0)
    if amount <= 0 then return { ok = false, reason = 'amount' } end

    local recipCid
    if data.toId ~= nil and tostring(data.toId) ~= '' then
        local tid = tonumber(data.toId)
        recipCid = tid and cidOf(tid) or nil
    else
        -- "Account ID or phone number": an Account ID is a citizenid that has a phone record.
        local raw = tostring(data.to or ''):gsub('%s', '')
        if raw ~= '' and raw:find('%a') then
            Sql.Wait()
            recipCid = Sql.Scalar('SELECT `citizenid` FROM `oph3z_phone_players` WHERE `citizenid` = ?', { raw })
                or Sql.Scalar('SELECT `citizenid` FROM `oph3z_phone_players` WHERE `citizenid` = ?', { raw:upper() })
        else
            local digits = DB.Digits(raw)
            if digits == '' then return { ok = false, reason = 'bad' } end
            recipCid = DB.GetCitizenIdByNumber(digits)
        end
    end
    if not recipCid then return { ok = false, reason = 'notfound' } end
    if recipCid == cid then return { ok = false, reason = 'self' } end

    local recipPlayer = DB.Player(recipCid)
    if not recipPlayer then return { ok = false, reason = 'notfound' } end
    local recipDigits = DB.Digits(recipPlayer.numberRaw)

    local note = tostring(data.note or ''):sub(1, 80)

    if bankOf(src) < amount then return { ok = false, reason = 'funds' } end
    if not Bank.Remove(cid, amount, 'phone-transfer') then
        return { ok = false, reason = 'funds' }
    end
    if not Bank.Add(recipCid, amount, 'phone-transfer') then
        Bank.Add(cid, amount, 'phone-transfer-refund')
        return { ok = false, reason = 'failed' }
    end

    local myNumber = DB.NumberOf(cid)
    local myContactForRecip = DB.ResolveContact(cid, recipDigits)
    local recipName = (myContactForRecip and myContactForRecip.name) or DB.FormatNumber(recipDigits)

    local theirContactForMe = DB.ResolveContact(recipCid, myNumber)
    local senderName = (theirContactForMe and theirContactForMe.name) or DB.FormatNumber(myNumber)

    local myTx = logTx(cid, { kind = 'sent', amount = amount, party = recipName, number = recipDigits, note = note })
    logTx(recipCid, { kind = 'received', amount = amount, party = senderName, number = myNumber, note = note })

    if Notif then
        Notif.Push(recipCid, {
            app = 'wallet',
            title = senderName,
            bodyKey = 'notify.received',
            bodyArgs = { comma(amount) },
            route = { app = 'wallet' },
        })
    end
    local recipSrc = GetSourceById(recipCid)
    if recipSrc then
        TriggerClientEvent('oph3z-phone:client:wallet:incoming', recipSrc, {
            balance = Bank.Get(recipCid),
            tx = { kind = 'received', amount = amount, party = senderName, number = myNumber, note = note, ts = os.time() },
        })
    end

    return { ok = true, balance = bankOf(src), tx = myTx }
end)

RegisterCallback('oph3z-phone:server:wallet:bills', function(src)
    local cid = cidOf(src)
    if not cid then return {} end
    return (BillsProvider.Get and BillsProvider.Get(cid, src)) or {}
end)

RegisterCallback('oph3z-phone:server:wallet:pay', function(src, billId)
    local cid = cidOf(src)
    if not cid then return { ok = false } end

    local res = BillsProvider.Pay and BillsProvider.Pay(cid, src, billId) or { ok = false, reason = 'gone' }
    if not res or not res.ok then return res or { ok = false } end

    local tx = logTx(cid, { kind = 'bill', amount = res.amount, party = res.issuer, note = res.label })
    return { ok = true, balance = bankOf(src), tx = tx, bills = (BillsProvider.Get and BillsProvider.Get(cid, src)) or {} }
end)