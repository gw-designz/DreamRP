Players = {}

local function qb(src)
    local ok, p = pcall(function() return exports.qbx_core:GetPlayer(src) end)
    return ok and p or nil
end

function Players.CitizenId(src)
    local p = qb(src)
    return p and p.PlayerData and p.PlayerData.citizenid or nil
end

local function summary(src)
    local p = qb(src)
    local pd = p and p.PlayerData
    local ped = GetPlayerPed(src)
    local info = pd and pd.charinfo
    return {
        id = src,
        name = GetPlayerName(src),
        character = info and (('%s %s'):format(info.firstname or '', info.lastname or '')) or nil,
        citizenid = pd and pd.citizenid or nil,
        ping = GetPlayerPing(src),
        job = pd and pd.job and pd.job.label or nil,
        jobGrade = pd and pd.job and pd.job.grade and pd.job.grade.level or nil,
        bucket = GetPlayerRoutingBucket(src),
        staff = Perms.GetRank(src) and Perms.GetRank(src).label or nil,
        dead = ped ~= 0 and GetEntityHealth(ped) <= 101 or false,
    }
end

function Players.List()
    local out = {}
    for _, id in ipairs(GetPlayers()) do
        out[#out + 1] = summary(tonumber(id))
    end
    table.sort(out, function(a, b) return a.id < b.id end)
    return out
end

---Detailed card. Sensitive fields depend on the caller's permissions.
function Players.Details(caller, target)
    if not GetPlayerName(target) then return nil end
    local base = summary(target)
    local p = qb(target)
    local pd = p and p.PlayerData
    local ped = GetPlayerPed(target)
    if ped ~= 0 then
        local c = GetEntityCoords(ped)
        base.coords = { x = c.x, y = c.y, z = c.z, h = GetEntityHeading(ped) }
        base.health = GetEntityHealth(ped)
        base.armor = GetPedArmour(ped)
        local veh = GetVehiclePedIsIn(ped, false)
        if veh ~= 0 then
            base.vehicle = { model = GetEntityModel(veh), plate = GetVehicleNumberPlateText(veh) }
        end
    end
    if pd and (Perms.Has(caller, 'economy') or Perms.Has(caller, 'players.ban')) then
        base.money = pd.money
    end
    if Perms.Has(caller, Config.IdentifierPerm) then
        local ids = {}
        for _, v in ipairs(GetPlayerIdentifiers(target)) do ids[#ids + 1] = v end
        base.identifiers = ids
    end
    if base.citizenid then
        base.notes = MySQL.query.await('SELECT id, created_at, kind, staff_name, text FROM npv_admin_notes WHERE citizenid = ? ORDER BY id DESC LIMIT 30', { base.citizenid })
    end
    return base
end

---Online player resolved from an NUI-provided id. Returns nil if offline.
function Players.Resolve(id)
    id = Utils.Num(id, 1, 65535)
    if not id then return nil end
    id = math.floor(id)
    if not GetPlayerName(id) then return nil end
    return id
end
