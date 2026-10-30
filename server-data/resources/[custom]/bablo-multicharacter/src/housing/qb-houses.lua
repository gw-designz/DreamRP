

local RESOURCE   = 'qb-houses'
local CONFIG_KEY = 'qb-houses'

local function activate()
    if Config.Housing == CONFIG_KEY then return true end
    if Config.Housing ~= 'auto' and Config.Housing ~= nil then return false end
    if not IsResourceStartedOrStarting(RESOURCE) then return false end
    Config.Housing = CONFIG_KEY
    return true
end

local function decode(raw)
    if not raw or raw == '' then return nil end
    local ok, parsed = pcall(json.decode, raw)
    if not ok or type(parsed) ~= 'table' then return nil end
    return parsed
end

local function extractEnter(coords)
    if type(coords) ~= 'table' then return nil end

    local candidates = {
        coords.enter,
        coords.entrance,
        coords.door,
        coords.coords and coords.coords.enter,
        coords,
    }

    for _, c in ipairs(candidates) do
        if type(c) == 'table' and c.x ~= nil and c.y ~= nil and c.z ~= nil then
            return c
        end
    end
    return nil
end

local function register()
    if IsDuplicityVersion() then
        Trace('[Housing/qb-houses] registering SERVER methods')

        function Housing:GetOwned(citizenid)
            if not citizenid then return nil end
            if GetResourceState('qb-houses') ~= 'started' then return nil end

            local rows = MySQL.query.await([[
                SELECT ph.`house`   AS name,
                       hl.`label`   AS label,
                       hl.`coords`  AS coords
                FROM   `player_houses` ph
                LEFT JOIN `houselocations` hl
                       ON ph.`house` = hl.`name`
                WHERE  ph.`citizenid` = ?
            ]], { citizenid })

            if not rows or #rows == 0 then return nil end

            local out = {}
            for _, row in ipairs(rows) do
                local coords = decode(row.coords)
                local enter  = extractEnter(coords)

                if enter then
                    out[#out + 1] = {
                        name   = row.name,
                        label  = row.label or row.name,
                        coords = {
                            x = enter.x + 0.0,
                            y = enter.y + 0.0,
                            z = enter.z + 0.0,
                        },
                        kind   = 'house',
                    }
                else
                    Trace(('[Housing/qb-houses] house=%s SKIPPED — no usable enter coords. raw=%s'):format(
                        tostring(row.name), tostring(row.coords)
                    ))
                end
            end

            return (#out > 0) and out or nil
        end

        return
    end

    Trace('[Housing/qb-houses] registering CLIENT methods')

    function Housing:EnterInterior(entry)
        if not entry or not entry.name then return end
        TriggerEvent('qb-houses:client:enterOwnedHouse', entry.name)
    end
end

if activate() then
    register()
    return
end

if Config.Housing ~= 'auto' and Config.Housing ~= nil then
    return
end

CreateThread(function()
    local deadline = GetGameTimer() + 10000
    while GetGameTimer() < deadline do
        Wait(100)
        if activate() then
            register()
            return
        end
        if Config.Housing ~= 'auto' and Config.Housing ~= nil
            and Config.Housing ~= CONFIG_KEY then
            return
        end
    end
    Trace('[Housing/qb-houses] resource not started after 10s — giving up')
end)

