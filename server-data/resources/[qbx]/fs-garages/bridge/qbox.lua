--[[
    fs-garages / bridge/qbox.lua

    Qbox. It grew out of QBCore but hands its players out through exports
    on qbx_core rather than a core object. Registers itself into
    Garage.Adapters; bridge/init.lua decides whether it is the one used.
]]

Garage = Garage or {}
Garage.Adapters = Garage.Adapters or {}

local adapter = { name = 'qbox', label = 'Qbox' }

local QBX = Config.FrameworkResources.qbox or 'qbx_core'

function adapter.detect()
    return GetResourceState(QBX) == 'started'
end

--- Nothing to fetch: Qbox works through exports.
function adapter.getCore()
    return true
end

--- Qbox keeps cars in the same player_vehicles table as QBCore.
local Cars = Garage.Adapters.qbcore.cars

if IsDuplicityVersion() then
    local S = {}
    adapter.server = S

    local function call(name, ...)
        local ok, result = pcall(function(...) return exports[QBX][name](exports[QBX], ...) end, ...)
        return ok and result or nil
    end

    function S.getName(src)
        local player = S.getPlayer(src)
        local info = player and player.PlayerData.charinfo
        if info and info.firstname then return ('%s %s'):format(info.firstname, info.lastname or '') end
        return GetPlayerName(src)
    end

    function S.getJob(src)
        local player = S.getPlayer(src)
        local job = player and player.PlayerData.job
        return job and { name = job.name, grade = tonumber(type(job.grade) == 'table' and job.grade.level or job.grade) or 0 } or nil
    end

    function S.sourceOf(identifier)
        local player = call('GetPlayerByCitizenId', identifier)
        return player and player.PlayerData.source or nil
    end

    S.install, S.vehicles, S.vehicle, S.park, S.claim, S.move = Cars.install, Cars.vehicles, Cars.vehicle, Cars.park, Cars.claim, Cars.move
    S.release = Cars.release

    function S.modelNames()
        return Cars.modelNames(call('GetVehiclesByName'))
    end

    function S.getPlayer(src)
        local ok, player = pcall(function() return exports[QBX]:GetPlayer(src) end)
        return ok and player or nil
    end

    function S.getIdentifier(src)
        local player = S.getPlayer(src)
        return player and player.PlayerData.citizenid or nil
    end

    function S.getMoney(src, account)
        local player = S.getPlayer(src)
        if not player then return 0 end
        return player.PlayerData.money[account] or 0
    end

    function S.removeMoney(src, account, amount)
        local player = S.getPlayer(src)
        if not player then return false end
        -- The framework lets some accounts go below zero (the bank, out of
        -- the box), so it is asked first rather than trusted to refuse.
        if (player.PlayerData.money[account] or 0) < amount then return false end
        return player.Functions.RemoveMoney(account, amount, 'fs-garages') and true or false
    end

    function S.addMoney(src, account, amount)
        local player = S.getPlayer(src)
        if not player then return false end
        return player.Functions.AddMoney(account, amount, 'fs-garages') and true or false
    end

    --- Qbox keeps its admin groups as permissions of the server itself.
    function S.isAdmin(src)
        for _, group in ipairs(Config.AdminGroups or {}) do
            if IsPlayerAceAllowed(src, 'group.' .. group) then return true end
        end
        return false
    end
else
    local C = {}
    adapter.client = C

    function C.isLoggedIn()
        return LocalPlayer.state.isLoggedIn == true
    end

    function C.notify(message, kind)
        if GetResourceState('ox_lib') == 'started' then
            exports.ox_lib:notify({ description = message, type = kind or 'inform' })
        end
    end
end

Garage.Adapters.qbox = adapter
