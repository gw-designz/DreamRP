--[[
    fs-garages / bridge/init.lua

    Picks one framework adapter and makes it the global `Bridge`. Loads
    after the three adapters. The rest of the resource only ever calls
    Bridge.*.
]]

Garage = Garage or {}

--- Qbox is looked for first: a Qbox server may also run a qb-core
--- stand-in, and finding that first would pick the wrong one.
local DETECT_ORDER = { 'qbox', 'qbcore', 'esx' }

--- Checked at start, so a missing function shows up here and not halfway
--- through somebody parking a car.
local REQUIRED = {
    server = {
        'getPlayer', 'getIdentifier', 'getMoney', 'removeMoney', 'addMoney', 'isAdmin', 'getName', 'getJob', 'sourceOf',
        'install', 'vehicles', 'vehicle', 'park', 'claim', 'move', 'release', 'modelNames',
    },
    client = { 'isLoggedIn', 'notify' },
}

Bridge = nil

local side = IsDuplicityVersion() and 'server' or 'client'

local function pick()
    local wanted = Config.Framework
    if wanted and wanted ~= 'auto' then
        local adapter = Garage.Adapters[wanted]
        if not adapter then
            Garage.util.error(('Config.Framework is "%s", which is not one of: auto, esx, qbcore, qbox.'):format(tostring(wanted)))
            return nil
        end
        return adapter.detect() and adapter or nil
    end
    for _, name in ipairs(DETECT_ORDER) do
        local adapter = Garage.Adapters[name]
        if adapter and adapter.detect() then return adapter end
    end
end

CreateThread(function()
    local adapter, waited = nil, 0

    -- No clock that gives up: a framework that starts late must still be
    -- found, or the kiosks would be dead for the whole session.
    while true do
        adapter = pick()
        if adapter then break end
        Wait(500)
        waited = waited + 500
        if waited % 15000 == 0 then
            Garage.util.error(('No framework found yet (looking for %s, %s or %s). '
                .. 'Set Config.Framework or Config.FrameworkResources if yours is named differently.')
                :format(Config.FrameworkResources.esx, Config.FrameworkResources.qbcore, Config.FrameworkResources.qbox))
        end
    end

    local missing = {}
    for _, method in ipairs(REQUIRED[side]) do
        if type(adapter[side] and adapter[side][method]) ~= 'function' then missing[#missing + 1] = method end
    end
    if #missing > 0 then
        Garage.util.error(('The %s adapter is missing: %s'):format(adapter.name, table.concat(missing, ', ')))
        return
    end

    waited = 0
    while not adapter.getCore() do
        Wait(250)
        waited = waited + 250
        if waited == 10000 then
            Garage.util.error(('%s is running but has not handed itself over yet; still waiting.'):format(adapter.label))
        end
    end

    Bridge = setmetatable({ Name = adapter.name, Label = adapter.label }, { __index = adapter[side] })
    Garage.util.debug(('framework: %s (%s side)'):format(adapter.label, side))
    TriggerEvent('fs-garages:bridgeReady', adapter.name)
end)

--- Waits for the bridge, for as long as it takes.
function Garage.waitForBridge()
    while not Bridge do Wait(100) end
    return true
end
