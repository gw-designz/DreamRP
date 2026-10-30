DB = {}

math.randomseed(os.time())

local cache = {}
local contactCache = {}
local lastTouch = {}
local numberIndex = {}
local mailIndex = {}

local EVICT_AFTER = 600
local SWEEP_EVERY = 120000

local function touch(citizenid)
    lastTouch[citizenid] = os.time()
end

function DB.GetCitizenId(src)
    return GetIdentifier(src)
end

function DB.Digits(s)
    return (tostring(s or ''):gsub('%D', ''))
end

function DB.FormatNumber(digits)
    digits = tostring(digits or '')
    if #digits == 7 then
        return digits:sub(1, 3) .. '-' .. digits:sub(4)
    end
    return digits
end

local function isValidId(citizenid)
    return type(citizenid) == 'string' and #citizenid > 0 and #citizenid <= 64
end

local function defaultSettings()
    return (json.decode(json.encode(Config.DefaultSettings or {})))
end

local function numberTaken(digits)
    return Sql.Scalar('SELECT `citizenid` FROM `oph3z_phone_players` WHERE `number` = ?', { digits }) ~= nil
end

local function allocateNumber()
    local prefix = Config.PhoneNumberPrefix or '555'
    for _ = 1, 50 do
        local digits = prefix .. ('%04d'):format(math.random(0, 9999))
        if not numberTaken(digits) then return digits end
    end
    return prefix .. tostring(os.time()):sub(-4)
end

local function mailSlug(s)
    return (tostring(s or ''):lower():gsub('[^a-z0-9]', ''))
end

local function allocateMail(citizenid, firstname, lastname)
    local domain = Config.MailDomain or 'mail.com'
    local first, last = mailSlug(firstname), mailSlug(lastname)

    local base
    if first ~= '' and last ~= '' then base = first .. '.' .. last
    elseif first ~= '' then base = first
    elseif last ~= '' then base = last
    else base = 'user' .. mailSlug(citizenid):sub(1, 6) end

    local address = base .. '@' .. domain
    local n = 1
    while Sql.Scalar('SELECT `citizenid` FROM `oph3z_phone_players` WHERE `mail` = ?', { address }) ~= nil do
        n = n + 1
        address = base .. tostring(n) .. '@' .. domain
        if n > 200 then
            address = base .. tostring(os.time()) .. '@' .. domain
            break
        end
    end
    return address
end

local function hydrate(row)
    local player = {
        citizenid = row.citizenid,
        numberRaw = row.number or '',
        number    = row.number and DB.FormatNumber(row.number) or nil,
        mail      = row.mail,
        name      = row.name,
        avatar    = row.avatar,
        settings  = Sql.Decode(row.settings, defaultSettings()),
        home      = Sql.Decode(row.home, nil),
    }
    cache[row.citizenid] = player
    touch(row.citizenid)
    if row.number then numberIndex[row.number] = row.citizenid end
    if row.mail then mailIndex[tostring(row.mail):lower()] = row.citizenid end
    return player
end

function DB.Player(citizenid, firstname, lastname, fallbackName)
    if not isValidId(citizenid) then return nil end

    local cached = cache[citizenid]
    if cached then
        touch(citizenid)
        return cached
    end

    Sql.Wait()
    local row = Sql.Single('SELECT * FROM `oph3z_phone_players` WHERE `citizenid` = ?', { citizenid })

    if not row then
        local settings = json.encode(defaultSettings())
        local now = os.time()

        for _ = 1, 5 do
            Sql.Execute(
                'INSERT IGNORE INTO `oph3z_phone_players` (`citizenid`, `number`, `mail`, `name`, `settings`, `created_at`, `updated_at`) ' ..
                'VALUES (?, ?, ?, ?, ?, ?, ?)',
                {
                    citizenid,
                    allocateNumber(),
                    allocateMail(citizenid, firstname, lastname),
                    (fallbackName and fallbackName ~= '') and fallbackName or nil,
                    settings, now, now,
                }
            )
            row = Sql.Single('SELECT * FROM `oph3z_phone_players` WHERE `citizenid` = ?', { citizenid })
            if row then break end
        end

        if not row then
            print(('^1[oph3z-phone] could not create a phone record for %s (no free number?).^0'):format(citizenid))
            return nil
        end
    end

    local player = hydrate(row)

    if (not player.name) and fallbackName and fallbackName ~= '' then
        DB.SetName(citizenid, fallbackName)
    end
    if not player.mail then
        local mail = allocateMail(citizenid, firstname, lastname)
        Sql.Execute('UPDATE `oph3z_phone_players` SET `mail` = ? WHERE `citizenid` = ?', { mail, citizenid })
        player.mail = mail
        mailIndex[mail:lower()] = citizenid
    end
    if player.numberRaw == '' then
        local number = allocateNumber()
        Sql.Execute('UPDATE `oph3z_phone_players` SET `number` = ? WHERE `citizenid` = ?', { number, citizenid })
        player.numberRaw = number
        player.number = DB.FormatNumber(number)
        numberIndex[number] = citizenid
    end

    return player
end

function DB.Forget(citizenid)
    cache[citizenid] = nil
    contactCache[citizenid] = nil
    lastTouch[citizenid] = nil
end

CreateThread(function()
    while true do
        Wait(SWEEP_EVERY)
        local now = os.time()
        for citizenid, ts in pairs(lastTouch) do
            if (now - ts) > EVICT_AFTER and not GetPlayerByCitizenId(citizenid) then
                cache[citizenid] = nil
                contactCache[citizenid] = nil
                lastTouch[citizenid] = nil
            end
        end
    end
end)

function DB.Settings(citizenid)
    local player = DB.Player(citizenid)
    return player and player.settings or {}
end

function DB.SetSettings(citizenid, patch)
    local player = DB.Player(citizenid)
    if not player or type(patch) ~= 'table' then return false end
    for key, value in pairs(patch) do
        player.settings[key] = value
    end
    Sql.Execute(
        'UPDATE `oph3z_phone_players` SET `settings` = ?, `updated_at` = ? WHERE `citizenid` = ?',
        { json.encode(player.settings), os.time(), citizenid }
    )
    return true
end

function DB.ClearSetting(citizenid, key)
    local player = DB.Player(citizenid)
    if not player then return false end
    player.settings[key] = nil
    Sql.Execute(
        'UPDATE `oph3z_phone_players` SET `settings` = ?, `updated_at` = ? WHERE `citizenid` = ?',
        { json.encode(player.settings), os.time(), citizenid }
    )
    return true
end

function DB.SetHome(citizenid, layout)
    local player = DB.Player(citizenid)
    if not player then return false end
    player.home = layout
    Sql.Execute(
        'UPDATE `oph3z_phone_players` SET `home` = ?, `updated_at` = ? WHERE `citizenid` = ?',
        { Sql.Encode(layout), os.time(), citizenid }
    )
    return true
end

function DB.SetName(citizenid, name)
    local player = DB.Player(citizenid)
    if not player then return false end
    player.name = name
    Sql.Execute('UPDATE `oph3z_phone_players` SET `name` = ? WHERE `citizenid` = ?', { name, citizenid })
    return true
end

function DB.SetAvatar(citizenid, url)
    local player = DB.Player(citizenid)
    if not player then return false end
    player.avatar = url
    Sql.Execute('UPDATE `oph3z_phone_players` SET `avatar` = ? WHERE `citizenid` = ?', { url, citizenid })
    return true
end

function DB.GetCitizenIdByNumber(digits)
    digits = DB.Digits(digits)
    if digits == '' then return nil end
    if numberIndex[digits] then return numberIndex[digits] end

    Sql.Wait()
    local cid = Sql.Scalar('SELECT `citizenid` FROM `oph3z_phone_players` WHERE `number` = ?', { digits })
    if cid then numberIndex[digits] = cid end
    return cid
end

function DB.GetCitizenIdByMail(address)
    if type(address) ~= 'string' or address == '' then return nil end
    address = address:lower()
    if mailIndex[address] then return mailIndex[address] end

    Sql.Wait()
    local cid = Sql.Scalar('SELECT `citizenid` FROM `oph3z_phone_players` WHERE `mail` = ?', { address })
    if cid then mailIndex[address] = cid end
    return cid
end

function DB.NumberOf(citizenid)
    local player = DB.Player(citizenid)
    return player and DB.Digits(player.numberRaw) or ''
end

local function loadContacts(citizenid)
    local entry = contactCache[citizenid]
    if entry then
        touch(citizenid)
        return entry
    end

    Sql.Wait()
    local rows = Sql.Query(
        'SELECT `id`, `name`, `number`, `notes`, `img`, `favorite` FROM `oph3z_phone_contacts` WHERE `citizenid` = ? ORDER BY `name` ASC',
        { citizenid }
    )

    entry = { list = rows, byDigits = {} }
    for _, row in ipairs(rows) do
        row.favorite = Sql.Bool(row.favorite)
        entry.byDigits[DB.Digits(row.number)] = row
    end

    contactCache[citizenid] = entry
    touch(citizenid)
    return entry
end

local function dropContacts(citizenid)
    contactCache[citizenid] = nil
end

function DB.GetContacts(citizenid)
    return loadContacts(citizenid).list
end

function DB.AddContact(citizenid, data)
    Sql.Wait()
    local id = Sql.Insert(
        'INSERT INTO `oph3z_phone_contacts` (`citizenid`, `name`, `number`, `notes`, `img`, `favorite`) VALUES (?, ?, ?, ?, ?, 0)',
        { citizenid, data.name, data.number, data.notes, data.img }
    )
    if not id then return nil end
    dropContacts(citizenid)
    return { id = id, name = data.name, number = data.number, notes = data.notes, img = data.img, favorite = false }
end

function DB.UpdateContact(citizenid, id, data)
    Sql.Wait()
    local changed = Sql.Execute(
        'UPDATE `oph3z_phone_contacts` SET `name` = ?, `number` = ?, `notes` = ?, `img` = ? WHERE `id` = ? AND `citizenid` = ?',
        { data.name, data.number, data.notes, data.img, id, citizenid }
    ) > 0
    if changed then dropContacts(citizenid) end
    return changed
end

function DB.DeleteContact(citizenid, id)
    Sql.Wait()
    local changed = Sql.Execute(
        'DELETE FROM `oph3z_phone_contacts` WHERE `id` = ? AND `citizenid` = ?',
        { id, citizenid }
    ) > 0
    if changed then dropContacts(citizenid) end
    return changed
end

function DB.SetContactFavorite(citizenid, id, favorite)
    Sql.Wait()
    local changed = Sql.Execute(
        'UPDATE `oph3z_phone_contacts` SET `favorite` = ? WHERE `id` = ? AND `citizenid` = ?',
        { favorite and 1 or 0, id, citizenid }
    ) > 0
    if changed then dropContacts(citizenid) end
    return changed
end

function DB.ResolveContact(citizenid, numberDigits)
    if not citizenid or not numberDigits or numberDigits == '' then return nil end
    return loadContacts(citizenid).byDigits[numberDigits]
end

function DB.GetRecents(citizenid)
    Sql.Wait()
    local rows = Sql.Query(
        'SELECT `id`, `number`, `name`, `img`, `direction`, `missed`, `video`, `ts` FROM `oph3z_phone_recents` ' ..
        'WHERE `citizenid` = ? ORDER BY `id` DESC LIMIT ?',
        { citizenid, Config.MaxRecents or 50 }
    )
    for _, row in ipairs(rows) do
        row.missed = Sql.Bool(row.missed)
        row.video = Sql.Bool(row.video)
    end
    return rows
end

function DB.LogRecent(citizenid, entry)
    if not citizenid or type(entry) ~= 'table' then return end
    Sql.Wait()
    Sql.Execute(
        'INSERT INTO `oph3z_phone_recents` (`citizenid`, `number`, `name`, `img`, `direction`, `missed`, `video`, `ts`) ' ..
        'VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
        {
            citizenid, entry.number, entry.name, entry.img,
            entry.direction == 'out' and 'out' or 'in',
            entry.missed and 1 or 0, entry.video and 1 or 0,
            entry.ts or os.time(),
        }
    )
    Sql.Execute(
        'DELETE FROM `oph3z_phone_recents` WHERE `citizenid` = ? AND `id` NOT IN ' ..
        '(SELECT `id` FROM (SELECT `id` FROM `oph3z_phone_recents` WHERE `citizenid` = ? ORDER BY `id` DESC LIMIT ?) AS keep)',
        { citizenid, citizenid, Config.MaxRecents or 50 }
    )
end

function DB.DeleteRecent(citizenid, id)
    Sql.Wait()
    return Sql.Execute(
        'DELETE FROM `oph3z_phone_recents` WHERE `id` = ? AND `citizenid` = ?',
        { id, citizenid }
    ) > 0
end

function DB.ClearRecents(citizenid, scope)
    Sql.Wait()
    if scope == 'missed' then
        Sql.Execute('DELETE FROM `oph3z_phone_recents` WHERE `citizenid` = ? AND `missed` = 1', { citizenid })
    else
        Sql.Execute('DELETE FROM `oph3z_phone_recents` WHERE `citizenid` = ?', { citizenid })
    end
    return true
end

function DB.GetBlocked(citizenid)
    Sql.Wait()
    local rows = Sql.Query(
        'SELECT `number`, `label`, `name`, `ts` FROM `oph3z_phone_blocked` WHERE `citizenid` = ?',
        { citizenid }
    )
    local out = {}
    for _, row in ipairs(rows) do
        out[row.number] = { number = row.label or row.number, name = row.name, ts = row.ts }
    end
    return out
end

function DB.IsBlocked(citizenid, numberDigits)
    if not citizenid or not numberDigits or numberDigits == '' then return false end
    Sql.Wait()
    return Sql.Scalar(
        'SELECT `number` FROM `oph3z_phone_blocked` WHERE `citizenid` = ? AND `number` = ?',
        { citizenid, numberDigits }
    ) ~= nil
end

function DB.Block(citizenid, rawNumber)
    local digits = DB.Digits(rawNumber)
    if digits == '' then return DB.GetBlocked(citizenid) end

    Sql.Wait()
    local contact = DB.ResolveContact(citizenid, digits)
    Sql.Execute(
        'INSERT INTO `oph3z_phone_blocked` (`citizenid`, `number`, `label`, `name`, `ts`) VALUES (?, ?, ?, ?, ?) ' ..
        'ON DUPLICATE KEY UPDATE `label` = VALUES(`label`), `name` = VALUES(`name`), `ts` = VALUES(`ts`)',
        { citizenid, digits, tostring(rawNumber), contact and contact.name or nil, os.time() }
    )
    return DB.GetBlocked(citizenid)
end

function DB.Unblock(citizenid, rawNumber)
    Sql.Wait()
    Sql.Execute(
        'DELETE FROM `oph3z_phone_blocked` WHERE `citizenid` = ? AND `number` = ?',
        { citizenid, DB.Digits(rawNumber) }
    )
    return DB.GetBlocked(citizenid)
end

AddEventHandler('playerDropped', function()
    local src = source
    local citizenid = GetIdentifier(src)
    if citizenid then DB.Forget(citizenid) end
end)