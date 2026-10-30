-- Licenses and Garage data for the NoPixel-style apps. Everything is looked up from the calling
-- player's own source; nothing here trusts NUI input beyond a plate / licence key to act on.

local function fw() return Config.Framework end
local function isQbox() return fw() == 'qbox' end
local function isQB() return fw() == 'qb' or fw() == 'oldqb' end
local function isESX() return fw() == 'esx' or fw() == 'oldesx' end

local function qbPlayer(src)
    if isQbox() then return exports.qbx_core:GetPlayer(src) end
    if isQB() and frameworkObject and frameworkObject.Functions then
        return frameworkObject.Functions.GetPlayer(tonumber(src))
    end
    return nil
end

local function esxPlayer(src)
    if isESX() and frameworkObject and frameworkObject.GetPlayerFromId then
        return frameworkObject.GetPlayerFromId(tonumber(src))
    end
    return nil
end

local function prettyLicense(key)
    local k = tostring(key or ''):gsub('_', ' ')
    k = k:gsub('(%a)([%w]*)', function(a, b) return a:upper() .. b end)
    if not k:lower():find('license') then k = k .. ' License' end
    return k
end

local function safeQuery(query, params)
    local ok, rows = pcall(Sql.Query, query, params)
    if ok and type(rows) == 'table' then return rows end
    return nil
end

-- ---------------------------------------------------------------- licenses
local LIC = Config.Licenses or {}

-- Known licences are always listed (inactive ones show "Not issued"), plus anything else the
-- character holds.
local function mergeKnown(owned)
    local list, seen = {}, {}
    for _, k in ipairs(LIC.Known or {}) do
        list[#list + 1] = { id = k.id, label = k.label or prettyLicense(k.id), active = owned[k.id] == true }
        seen[k.id] = true
    end
    for key, active in pairs(owned) do
        if not seen[key] and key ~= 'id' then
            list[#list + 1] = { id = key, label = prettyLicense(key), active = active == true }
        end
    end
    return list
end

local function cardFor(src)
    local p = qbPlayer(src)
    if p and p.PlayerData then
        local pd = p.PlayerData
        local ci = pd.charinfo or {}
        local gender = ci.gender
        if gender == 0 or gender == '0' then gender = 'Male' elseif gender == 1 or gender == '1' then gender = 'Female' end
        return {
            ok = true,
            person = {
                name        = ((ci.firstname or '') .. ' ' .. (ci.lastname or '')):gsub('^%s+', ''):gsub('%s+$', ''),
                citizenid   = pd.citizenid,
                birthdate   = ci.birthdate,
                gender      = gender and tostring(gender) or nil,
                nationality = ci.nationality,
            },
            licenses = mergeKnown((pd.metadata and pd.metadata.licences) or {}),
            applyAt = LIC.ApplyAt or 'City Hall',
        }
    end

    local xp = esxPlayer(src)
    if xp then
        local id = xp.getIdentifier and xp.getIdentifier() or xp.identifier
        local user = (safeQuery('SELECT firstname, lastname, dateofbirth, sex FROM users WHERE identifier = ?', { id }) or {})[1] or {}
        local owned = {}
        for _, row in ipairs(safeQuery('SELECT `type` FROM `user_licenses` WHERE `owner` = ?', { id }) or {}) do
            owned[row.type] = true
        end
        return {
            ok = true,
            person = {
                name      = xp.getName and xp.getName() or ((user.firstname or '') .. ' ' .. (user.lastname or '')),
                citizenid = id,
                birthdate = user.dateofbirth,
                gender    = user.sex == 'm' and 'Male' or (user.sex == 'f' and 'Female' or user.sex),
            },
            licenses = mergeKnown(owned),
            applyAt = LIC.ApplyAt or 'City Hall',
        }
    end
    return nil
end

RegisterCallback('oph3z-phone:server:np:licenses', function(src)
    return cardFor(src) or { ok = false, reason = 'unsupported' }
end)

-- Show a licence (or the ID card, id = 'id') to the nearest player.
RegisterCallback('oph3z-phone:server:np:licenses:show', function(src, data)
    if type(data) ~= 'table' or not NP.rate(src, 'licshow', 2) then return { ok = false, reason = 'failed' } end
    local key = tostring(data.id or '')
    local info = cardFor(src)
    if not info then return { ok = false, reason = 'unsupported' } end
    local label = 'ID Card'
    if key ~= 'id' then
        local found
        for _, l in ipairs(info.licenses) do
            if l.id == key then found = l end
        end
        if not found or not found.active then return { ok = false, reason = 'none' } end
        label = found.label
    end
    local target = NP.nearest(src, tonumber(LIC.ShowDistance) or 3.0)
    if not target then return { ok = false, reason = 'noplayer' } end
    TriggerClientEvent('oph3z-phone:client:np:licenseShown', target, {
        label = label, name = info.person.name, stateId = info.person.citizenid, dob = info.person.birthdate,
    })
    return { ok = true, name = NP.name(target) }
end)

-- ---------------------------------------------------------------- garage
local GAR = Config.Garage or {}
local QB_STATE = { [0] = 'out', [1] = 'garaged', [2] = 'impound' }

local function trimPlate(p)
    local s = tostring(p or ''):gsub('^%s+', '')
    s = s:gsub('%s+$', '')
    return s:upper()
end

RegisterCallback('oph3z-phone:server:np:garage', function(src)
    local p = qbPlayer(src)
    if p and p.PlayerData then
        local rows = safeQuery(
            'SELECT `vehicle`, `hash`, `plate`, `garage`, `state`, `fuel`, `engine`, `body` FROM `player_vehicles` WHERE `citizenid` = ?',
            { p.PlayerData.citizenid }
        )
        if not rows then return { ok = false, reason = 'unsupported' } end
        local out = {}
        for _, r in ipairs(rows) do
            out[#out + 1] = {
                plate  = trimPlate(r.plate),
                model  = r.vehicle,
                hash   = r.hash,
                garage = r.garage or '',
                state  = QB_STATE[tonumber(r.state) or 0] or 'out',
                fuel   = tonumber(r.fuel) or 0,
                engine = (tonumber(r.engine) or 1000) / 10,
                body   = (tonumber(r.body) or 1000) / 10,
            }
        end
        return { ok = true, vehicles = out }
    end

    local xp = esxPlayer(src)
    if xp then
        local id = xp.getIdentifier and xp.getIdentifier() or xp.identifier
        local rows = safeQuery('SELECT `plate`, `vehicle`, `stored` FROM `owned_vehicles` WHERE `owner` = ?', { id })
        if not rows then return { ok = false, reason = 'unsupported' } end
        local out = {}
        for _, r in ipairs(rows) do
            local props = Sql.Decode(r.vehicle, {})
            out[#out + 1] = {
                plate  = trimPlate(r.plate),
                hash   = props.model,
                garage = '',
                state  = Sql.Bool(r.stored) and 'garaged' or 'out',
                fuel   = tonumber(props.fuelLevel) or 0,
                engine = (tonumber(props.engineHealth) or 1000) / 10,
                body   = (tonumber(props.bodyHealth) or 1000) / 10,
            }
        end
        return { ok = true, vehicles = out }
    end
    return { ok = false, reason = 'unsupported' }
end)

-- Only vehicles the caller owns (framework table) can be tracked / shared / taken out.
local function ownsPlate(src, plate)
    local p = qbPlayer(src)
    if p and p.PlayerData then
        for _, row in ipairs(safeQuery('SELECT `plate`, `garage` FROM `player_vehicles` WHERE `citizenid` = ?', { p.PlayerData.citizenid }) or {}) do
            if trimPlate(row.plate) == plate then return true, row end
        end
        return false
    end
    local xp = esxPlayer(src)
    if xp then
        local id = xp.getIdentifier and xp.getIdentifier() or xp.identifier
        for _, row in ipairs(safeQuery('SELECT `plate` FROM `owned_vehicles` WHERE `owner` = ?', { id }) or {}) do
            if trimPlate(row.plate) == plate then return true, row end
        end
    end
    return false
end

local function findVehicle(plate)
    for _, veh in ipairs(GetAllVehicles()) do
        if DoesEntityExist(veh) and trimPlate(GetVehicleNumberPlateText(veh)) == plate then return veh end
    end
    return nil
end

RegisterCallback('oph3z-phone:server:np:garage:track', function(src, data)
    local plate = trimPlate(type(data) == 'table' and data.plate)
    if plate == '' or not ownsPlate(src, plate) then return { ok = false, reason = 'owner' } end
    local veh = findVehicle(plate)
    if not veh then return { ok = false, reason = 'notfound' } end
    local c = GetEntityCoords(veh)
    return { ok = true, x = c.x, y = c.y }
end)

RegisterCallback('oph3z-phone:server:np:garage:keys', function(src, data)
    if GAR.ShareKeys == false then return { ok = false, reason = 'unsupported' } end
    if not NP.rate(src, 'garagekeys', 3) then return { ok = false, reason = 'failed' } end
    local plate = trimPlate(type(data) == 'table' and data.plate)
    if plate == '' or not ownsPlate(src, plate) then return { ok = false, reason = 'owner' } end
    local target = NP.nearest(src, tonumber(GAR.KeysDistance) or 3.0)
    if not target then return { ok = false, reason = 'noplayer' } end
    local ok = false
    if type(GAR.GiveKeys) == 'function' then
        local pOk, res = pcall(GAR.GiveKeys, src, target, plate, findVehicle(plate))
        ok = pOk and res ~= false
        if not pOk then print(('^1[oph3z-phone] Config.Garage.GiveKeys failed: %s^0'):format(tostring(res))) end
    end
    if not ok then return { ok = false, reason = 'failed' } end
    return { ok = true, name = NP.name(target) }
end)

RegisterCallback('oph3z-phone:server:np:garage:takeout', function(src, data)
    if type(GAR.TakeOutEvent) ~= 'string' or GAR.TakeOutEvent == '' then return { ok = false, reason = 'unsupported' } end
    local plate = trimPlate(type(data) == 'table' and data.plate)
    local owns, row = ownsPlate(src, plate)
    if plate == '' or not owns then return { ok = false, reason = 'owner' } end
    TriggerClientEvent(GAR.TakeOutEvent, src, plate, row and row.garage)
    return { ok = true }
end)
