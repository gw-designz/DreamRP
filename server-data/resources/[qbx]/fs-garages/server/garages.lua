--[[
    fs-garages / server/garages.lua

    The garages, made in game with the creator and kept in data/garages.json.
    Nobody types a coordinate: an admin stands there and places the kiosk
    and the parking spaces by looking at the ground.

    The list is shared with every game through GlobalState.fsGarages, so a
    garage saved in the creator is there for everyone at once.

    A garage is:
      id      'garage_3'
      label   the name on the map and the kiosk, e.g. 'Legion Square'
      type    'car', 'boat' or 'air': which vehicles it keeps
      kind    'public' (anyone), 'job' (only `jobs`) or 'depot' (the
              impound lot, where lost and impounded cars are paid out)
      jobs    for a job garage, the job names that may use it
      blip    false to keep it off the map
      kiosk   { x, y, z, w }: w is the way its screen faces
      spots   { { x, y, z, w } }: the parking spaces, w the way a car faces
]]

local util = Garage.util

local RESOURCE = GetCurrentResourceName()
local DATA_FILE = 'data/garages.json'
local MAX_SPOTS = 40
local TYPES = { car = true, boat = true, air = true }
local KINDS = { public = true, job = true, depot = true }

local garages = {}

local function number(value, limit)
    value = tonumber(value)
    if not util.number(value) or math.abs(value) > limit then return nil end
    return value + 0.0
end

local function point(p)
    if type(p) ~= 'table' then return nil end
    local x, y, z = number(p.x, 20000), number(p.y, 20000), number(p.z, 5000)
    if not (x and y and z) then return nil end
    return { x = x, y = y, z = z, w = (number(p.w, 100000) or 0.0) % 360.0 }
end

local function label(text, length)
    text = tostring(text or ''):gsub('[%c]', ''):gsub('^%s+', ''):gsub('%s+$', '')
    return text:sub(1, length or 32)
end

--- A garage as the creator sent it, checked and tidied; nil if it is not
--- a garage at all.
local function clean(def)
    if type(def) ~= 'table' then return nil end
    local name = label(def.label)
    local kiosk = point(def.kiosk)
    if name == '' or not kiosk then return nil end
    local spots = {}
    for _, p in ipairs(type(def.spots) == 'table' and def.spots or {}) do
        local spot = point(p)
        if spot and #spots < MAX_SPOTS then spots[#spots + 1] = spot end
    end
    local jobs = {}
    for _, job in ipairs(type(def.jobs) == 'table' and def.jobs or {}) do
        local jobName = label(job, 40):gsub('[^%w_%-]', '')
        if jobName ~= '' and #jobs < 10 then jobs[#jobs + 1] = jobName end
    end
    local kind = KINDS[def.kind] and def.kind or 'public'
    -- A job garage nobody's job is allowed into would be a dead garage.
    if kind == 'job' and #jobs == 0 then return nil end
    return {
        label = name,
        type = TYPES[def.type] and def.type or 'car',
        kind = kind,
        jobs = jobs,
        blip = def.blip ~= false,
        kiosk = kiosk,
        spots = spots,
    }
end

local function publish()
    GlobalState.fsGarages = garages
    Garage.setList(garages)
end

local function save()
    SaveResourceFile(RESOURCE, DATA_FILE, json.encode(garages, { indent = true }), -1)
end

local function indexOf(id)
    for i, garage in ipairs(garages) do
        if garage.id == id then return i end
    end
end

CreateThread(function()
    local raw = LoadResourceFile(RESOURCE, DATA_FILE)
    local ok, list = pcall(json.decode, raw or '[]')
    if ok and type(list) == 'table' then
        for _, def in ipairs(list) do
            local entry = clean(def)
            local id = type(def) == 'table' and type(def.id) == 'string' and def.id:gsub('[^%w%-_]', ''):sub(1, 32) or ''
            if entry and id ~= '' and not indexOf(id) then
                entry.id = id
                garages[#garages + 1] = entry
            end
        end
    end
    publish()
    if #garages == 0 then
        util.error(('No garages yet. Type /%s in game to make one.'):format(Config.Command))
    end
end)

-- ── the creator ────────────────────────────────────────────────────────

--- Admins only: the command's own permission, or an admin of the
--- framework (Config.AdminGroups).
local function mayCreate(src)
    if src == 0 then return false end
    if IsPlayerAceAllowed(src, 'command.' .. Config.Command) then return true end
    local ok, admin = pcall(function() return Bridge and Bridge.isAdmin(src) end)
    return ok and admin == true
end

--- Opens the creator on the screen of whoever typed it.
RegisterCommand(Config.Command, function(src)
    if src == 0 then return end
    if not mayCreate(src) then
        TriggerClientEvent('fs-garages:client:notify', src, L('err_admin_only'), 'error')
        return
    end
    TriggerClientEvent('fs-garages:creator', src)
end, false)

--- A garage made or changed in the creator. With no id it is a new one.
RegisterNetEvent('fs-garages:creator:save', function(id, def)
    local src = source
    if not mayCreate(src) then return end
    local entry = clean(def)
    if not entry then
        TriggerClientEvent('fs-garages:creator:saved', src, nil, 'ui_c_incomplete')
        return
    end

    local at = type(id) == 'string' and indexOf(id) or nil
    if not at then
        local n = #garages + 1
        repeat
            id = ('garage_%d'):format(n)
            n = n + 1
        until not indexOf(id)
        at = #garages + 1
    end
    entry.id = id
    garages[at] = entry
    save()
    publish()
    TriggerClientEvent('fs-garages:creator:saved', src, id)
end)

RegisterNetEvent('fs-garages:creator:delete', function(id)
    local src = source
    if not mayCreate(src) or type(id) ~= 'string' then return end
    local at = indexOf(id)
    if not at then return end
    table.remove(garages, at)
    save()
    publish()
end)
