Utils = {}

local Inventory = {}

function Inventory.Add(source, item, amount)
    if GetResourceState('ox_inventory') == 'started' then
        return exports['ox_inventory']:AddItem(source, item, amount)
    elseif GetResourceState('qb-inventory') == 'started' then
        return exports['qb-inventory']:AddItem(source, item, amount)
    elseif GetResourceState('tgiann-inventory') == 'started' then
        return exports['tgiann-inventory']:AddItem(source, item, amount)
    elseif GetResourceState('jaksam_inventory') == 'started' then
        return exports['jaksam_inventory']:addItem(source, item, amount)
    end

    local player = Utils.GetFrameworkPlayer(source)
    if not player then return end

    if FRAMEWORK == ENUM_DEFINED_FRAMEWORKS.ESX then
        if player.canCarryItem and not player.canCarryItem(item, amount) then return false end
        player.addInventoryItem(item, amount)
        return true
    elseif FRAMEWORK == ENUM_DEFINED_FRAMEWORKS.QBCORE or FRAMEWORK == ENUM_DEFINED_FRAMEWORKS.QBOX then
        return player.Functions.AddItem(item, amount)
    end
end

function Inventory.Remove(source, item, amount)
    if GetResourceState('ox_inventory') == 'started' then
        return exports['ox_inventory']:RemoveItem(source, item, amount)
    elseif GetResourceState('qb-inventory') == 'started' then
        return exports['qb-inventory']:RemoveItem(source, item, amount)
    elseif GetResourceState('tgiann-inventory') == 'started' then
        return exports['tgiann-inventory']:RemoveItem(source, item, amount)
    elseif GetResourceState('jaksam_inventory') == 'started' then
        return exports['jaksam_inventory']:removeItem(source, item, amount)
    end

    local player = Utils.GetFrameworkPlayer(source)
    if not player then return end

    if FRAMEWORK == ENUM_DEFINED_FRAMEWORKS.ESX then
        return player.removeInventoryItem(item, amount)
    elseif FRAMEWORK == ENUM_DEFINED_FRAMEWORKS.QBCORE or FRAMEWORK == ENUM_DEFINED_FRAMEWORKS.QBOX then
        return player.Functions.RemoveItem(item, amount)
    end
end

function Inventory.Count(source, item)
    if GetResourceState('ox_inventory') == 'started' then
        return exports['ox_inventory']:GetItemCount(source, item)
    elseif GetResourceState('qb-inventory') == 'started' then
        return exports['qb-inventory']:GetItemCount(source, item)
    elseif GetResourceState('tgiann-inventory') == 'started' then
        return exports['tgiann-inventory']:GetItemCount(source, item)
    elseif GetResourceState('jaksam_inventory') == 'started' then
        local count = exports['jaksam_inventory']:getTotalItemAmount(source, item)
        return count
    end

    local player = Utils.GetFrameworkPlayer(source)
    if not player then return 0 end

    if FRAMEWORK == ENUM_DEFINED_FRAMEWORKS.ESX then
        return player.getInventoryItem(item).count or 0
    elseif FRAMEWORK == ENUM_DEFINED_FRAMEWORKS.QBCORE or FRAMEWORK == ENUM_DEFINED_FRAMEWORKS.QBOX then
        return player.Functions.GetItemByName(item)?.amount or 0
    end

    return 0
end

function Utils.GetFrameworkPlayer(source)
    if FRAMEWORK == ENUM_DEFINED_FRAMEWORKS.ESX then
        return FRAMEWORK_DATA.GetPlayerFromId(source)
    elseif FRAMEWORK == ENUM_DEFINED_FRAMEWORKS.QBCORE then
        return FRAMEWORK_DATA.Functions.GetPlayer(source)
    elseif FRAMEWORK == ENUM_DEFINED_FRAMEWORKS.QBOX then
        return exports['qbx_core']:GetPlayer(source)
    end
    return nil
end

function Utils.RegisterUsableItem(item, cb)
    if FRAMEWORK == ENUM_DEFINED_FRAMEWORKS.ESX and FRAMEWORK_DATA.RegisterUsableItem then
        FRAMEWORK_DATA.RegisterUsableItem(item, function(source) cb(source) end)
    elseif FRAMEWORK == ENUM_DEFINED_FRAMEWORKS.QBCORE and FRAMEWORK_DATA.Functions then
        FRAMEWORK_DATA.Functions.CreateUseableItem(item, function(source) cb(source) end)
    elseif FRAMEWORK == ENUM_DEFINED_FRAMEWORKS.QBOX then
        exports['qbx_core']:CreateUseableItem(item, function(source) cb(source) end)
    end

    exports('useBench', function(event, _, inventory)
        if event ~= 'usingItem' then return end
        if inventory and inventory.id then cb(inventory.id) end
        return false
    end)
end

function Utils.GetIdentifier(source)
    local player = Utils.GetFrameworkPlayer(source)

    if player then
        if FRAMEWORK == ENUM_DEFINED_FRAMEWORKS.ESX then
            if player.identifier then return player.identifier end
        elseif FRAMEWORK == ENUM_DEFINED_FRAMEWORKS.QBCORE or FRAMEWORK == ENUM_DEFINED_FRAMEWORKS.QBOX then
            local data = player.PlayerData
            if data and data.citizenid then return data.citizenid end
        end
    end

    return GetPlayerIdentifierByType(source, 'license')
end

function Utils.GetPlayerName(source)
    local player = Utils.GetFrameworkPlayer(source)

    if player then
        if FRAMEWORK == ENUM_DEFINED_FRAMEWORKS.ESX then
            if player.getName then
                local name = player.getName()
                if type(name) == 'string' and name ~= '' then return name:sub(1, 60) end
            end
        elseif FRAMEWORK == ENUM_DEFINED_FRAMEWORKS.QBCORE or FRAMEWORK == ENUM_DEFINED_FRAMEWORKS.QBOX then
            local info = player.PlayerData and player.PlayerData.charinfo
            if info then
                local name = ('%s %s'):format(info.firstname or '', info.lastname or '')
                name = name:match('^%s*(.-)%s*$')
                if name ~= '' then return name:sub(1, 60) end
            end
        end
    end

    return (GetPlayerName(source) or 'Unknown'):sub(1, 60)
end

function Utils.GetJob(source)
    local player = Utils.GetFrameworkPlayer(source)
    if not player then return nil, 0 end

    if FRAMEWORK == ENUM_DEFINED_FRAMEWORKS.ESX then
        local job = player.getJob and player.getJob()
        if job then return job.name, tonumber(job.grade) or 0 end
    elseif FRAMEWORK == ENUM_DEFINED_FRAMEWORKS.QBCORE or FRAMEWORK == ENUM_DEFINED_FRAMEWORKS.QBOX then
        local job = player.PlayerData and player.PlayerData.job
        if job then return job.name, tonumber(job.grade and job.grade.level) or 0 end
    end

    return nil, 0
end

function Utils.HasJob(source, name, minGrade)
    if not name or name == '' then return true end
    local job, grade = Utils.GetJob(source)
    if job ~= name then return false end
    return grade >= (tonumber(minGrade) or 0)
end

function Utils.AddInventoryItem(source, item, amount)
    return Inventory.Add(source, item, amount)
end

function Utils.RemoveInventoryItem(source, item, amount)
    return Inventory.Remove(source, item, amount)
end

function Utils.GetInventoryItemCount(source, item)
    return Inventory.Count(source, item)
end

local itemListCache = nil

function Utils.GetItemList()
    if itemListCache then return itemListCache end

    local list = {}

    if GetResourceState('ox_inventory') == 'started' then
        local items = exports['ox_inventory']:Items() or {}
        for name, data in pairs(items) do
            list[#list + 1] = { name = name, label = (type(data) == 'table' and data.label) or name }
        end
    elseif FRAMEWORK == ENUM_DEFINED_FRAMEWORKS.QBCORE then
        for name, data in pairs(FRAMEWORK_DATA.Shared.Items or {}) do
            list[#list + 1] = { name = name, label = (type(data) == 'table' and data.label) or name }
        end
    elseif FRAMEWORK == ENUM_DEFINED_FRAMEWORKS.ESX then
        local rows = MySQL.query.await('SELECT `name`, `label` FROM `items`')
        for _, row in ipairs(rows or {}) do
            list[#list + 1] = { name = row.name, label = row.label or row.name }
        end
    end

    table.sort(list, function(a, b) return a.name < b.name end)
    if #list > 0 then itemListCache = list end
    return list
end

local itemLabelCache = nil

function Utils.GetItemLabel(name)
    if not name or name == '' then return name end

    if not itemLabelCache then
        local list = Utils.GetItemList()
        if #list == 0 then return name end

        itemLabelCache = {}
        for _, entry in ipairs(list) do
            itemLabelCache[entry.name] = entry.label
        end
    end

    return itemLabelCache[name] or name
end

function Utils.IsAdmin(source)
    if IsPlayerAceAllowed(source, 'command') then return true end

    if FRAMEWORK == ENUM_DEFINED_FRAMEWORKS.ESX then
        local player = Utils.GetFrameworkPlayer(source)
        if not player then return false end
        local group = player.getGroup()
        for _, allowed in ipairs(Config.AdminGroups) do
            if group == allowed then return true end
        end
    elseif FRAMEWORK == ENUM_DEFINED_FRAMEWORKS.QBCORE then
        for _, allowed in ipairs(Config.AdminGroups) do
            if FRAMEWORK_DATA.Functions.HasPermission(source, allowed) then return true end
        end
    elseif FRAMEWORK == ENUM_DEFINED_FRAMEWORKS.QBOX then
        for _, allowed in ipairs(Config.AdminGroups) do
            if IsPlayerAceAllowed(source, 'group.' .. allowed) then return true end
        end
    end

    return false
end

function Utils.Notify(source, title, description, type)
    if GetResourceState('ox_lib') == 'started' then
        TriggerClientEvent('ox_lib:notify', source, {
            title = title,
            description = description,
            type = type
        })
    elseif GetResourceState('vms_notifyv2') == 'started' then
        TriggerClientEvent('vms_notifyv2:Notification', source, {
            title = title,
            description = description,
            time = 5000
        })
    end
end
