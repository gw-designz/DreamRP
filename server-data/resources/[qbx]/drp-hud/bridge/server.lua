-- Server side of the framework bridge: stress persistence and job lookups.

local QBCore, ESX

if Bridge.name == 'qb' then
    QBCore = exports['qb-core']:GetCoreObject()
elseif Bridge.name == 'esx' then
    ESX = exports.es_extended:getSharedObject()
end

local function getPlayer(src)
    if Bridge.name == 'qbox' then return exports.qbx_core:GetPlayer(src) end
    if Bridge.name == 'qb' then return QBCore.Functions.GetPlayer(src) end
    if Bridge.name == 'esx' then return ESX.GetPlayerFromId(src) end
end

local function license(src)
    for _, id in ipairs(GetPlayerIdentifiers(src)) do
        if id:sub(1, 8) == 'license:' then return id end
    end
end

function Bridge.getStress(src)
    local player = getPlayer(src)
    if Bridge.name == 'qb' or Bridge.name == 'qbox' then
        return player and player.PlayerData.metadata.stress or 0
    elseif Bridge.name == 'esx' then
        return player and player.getMeta and player.getMeta('stress') or 0
    end
    local lic = license(src)
    return lic and GetResourceKvpInt(('stress:%s'):format(lic)) or 0
end

function Bridge.setStress(src, value)
    local player = getPlayer(src)
    if Bridge.name == 'qb' or Bridge.name == 'qbox' then
        if player then player.Functions.SetMetaData('stress', value) end
    elseif Bridge.name == 'esx' then
        if player and player.setMeta then player.setMeta('stress', value) end
    else
        local lic = license(src)
        if lic then SetResourceKvpInt(('stress:%s'):format(lic), value) end
    end
end

function Bridge.getJob(src)
    local player = getPlayer(src)
    if not player then return nil end
    if Bridge.name == 'qb' or Bridge.name == 'qbox' then
        local job = player.PlayerData.job
        return job and job.name, job and job.onduty
    elseif Bridge.name == 'esx' then
        return player.job and player.job.name, true
    end
end

-- Hunger / thirst (0-100) written to the framework, then pushed to the client's HUD.
function Bridge.setNeeds(src, hunger, thirst)
    local player = getPlayer(src)
    if Bridge.name == 'qb' or Bridge.name == 'qbox' then
        if player then
            player.Functions.SetMetaData('hunger', hunger)
            player.Functions.SetMetaData('thirst', thirst)
        end
    elseif Bridge.name == 'esx' then
        -- esx_status stores 0 - 1,000,000
        TriggerClientEvent('esx_status:set', src, 'hunger', hunger * 10000)
        TriggerClientEvent('esx_status:set', src, 'thirst', thirst * 10000)
    end
    TriggerClientEvent('hud:client:UpdateNeeds', src, hunger, thirst)
end

function Bridge.getGroup(src)
    if Bridge.name ~= 'esx' then return nil end
    local player = getPlayer(src)
    return player and player.getGroup and player.getGroup() or nil
end

-- Calls cb(src) whenever a character finishes loading.
function Bridge.onPlayerLoaded(cb)
    if Bridge.name == 'qb' or Bridge.name == 'qbox' then
        AddEventHandler('QBCore:Server:PlayerLoaded', function(player)
            cb(player.PlayerData.source)
        end)
    elseif Bridge.name == 'esx' then
        AddEventHandler('esx:playerLoaded', function(src) cb(src) end)
    end
end
