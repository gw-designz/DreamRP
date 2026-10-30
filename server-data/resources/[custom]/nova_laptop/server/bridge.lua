Bridge = {}
local core

local function started(name)
    return GetResourceState(name) == 'started'
end

function Bridge.Framework()
    if Config.Framework ~= 'auto' then return Config.Framework end
    if started('qbx_core') then return 'qbox' end
    if started('qb-core') then return 'qb' end
    if started('es_extended') then return 'esx' end
    return 'standalone'
end

function Bridge.Context(src)
    local mode = Bridge.Framework()
    if mode == 'qb' or mode == 'qbox' then
        local player
        if mode == 'qbox' then
            if not started('qbx_core') then return nil end
            player = exports.qbx_core:GetPlayer(src)
        else
            if not started('qb-core') then return nil end
            core = core or exports['qb-core']:GetCoreObject()
            player = core.Functions.GetPlayer(src)
        end
        if not player or not player.PlayerData or not player.PlayerData.citizenid then return nil end
        local data = player.PlayerData
        local info, job, metadata = data.charinfo or {}, data.job or {}, data.metadata or {}
        local name = ((info.firstname or '') .. ' ' .. (info.lastname or '')):match('^%s*(.-)%s*$')
        return {
            key = 'character:' .. data.citizenid,
            name = name ~= '' and name or GetPlayerName(src),
            framework = mode, player = player,
            job = job.name, grade = type(job.grade) == 'table' and job.grade.level or tonumber(job.grade) or 0,
            dead = metadata.isdead or metadata.inlaststand or false
        }
    elseif mode == 'esx' then
        if not started('es_extended') then return nil end
        core = core or exports.es_extended:getSharedObject()
        local player = core.GetPlayerFromId(src)
        if not player or not player.identifier then return nil end
        local job = player.getJob() or {}
        return { key = 'esx:' .. player.identifier, name = player.getName(), framework = mode,
            player = player, job = job.name, grade = tonumber(job.grade) or 0 }
    end
    local license = GetPlayerIdentifierByType(src, 'license')
    if not license then return nil end
    return { key = 'standalone:' .. license, name = GetPlayerName(src), framework = mode, grade = 0 }
end

function Bridge.HasItem(src, context)
    local inventory = Config.Inventory
    if inventory == 'none' then return false end
    if inventory == 'ox' or (inventory == 'auto' and started('ox_inventory')) then
        if not started('ox_inventory') then return false end
        local count = exports.ox_inventory:Search(src, 'count', Config.ItemName)
        return type(count) == 'number' and count > 0
    end
    if context.framework == 'qb' or context.framework == 'qbox' then
        local functions = context.player.Functions
        if not functions or not functions.GetItemByName then return false end
        local item = functions.GetItemByName(Config.ItemName)
        return item ~= nil and (tonumber(item.amount or item.count) or 0) > 0
    elseif context.framework == 'esx' then
        local item = context.player.getInventoryItem(Config.ItemName)
        return item ~= nil and (tonumber(item.count) or 0) > 0
    end
    return false
end

function Bridge.RegisterItem(callback)
    -- ox_inventory uses install/ox_inventory.lua and the client UseLaptop export.
    if Config.Inventory == 'ox' or (Config.Inventory == 'auto' and started('ox_inventory')) then return end
    if Config.Inventory == 'none' then return end
    local mode = Bridge.Framework()
    if mode == 'qb' then
        core = exports['qb-core']:GetCoreObject()
        core.Functions.CreateUseableItem(Config.ItemName, function(src) callback(src) end)
    elseif mode == 'qbox' then
        exports.qbx_core:CreateUseableItem(Config.ItemName, function(src) callback(src) end)
    elseif mode == 'esx' then
        core = exports.es_extended:getSharedObject()
        core.RegisterUsableItem(Config.ItemName, function(src) callback(src) end)
    end
end


AddEventHandler('onResourceStop', function(name)
    if name == 'qb-core' or name == 'es_extended' then core = nil end
end)
