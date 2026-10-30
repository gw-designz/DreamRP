if not Config.Modules.PARKING_METER_ROBBERY then return end

local isActionBusy = false
local targetSetupDone = false

local function coordKey(coords)
    return string.format("%.1f_%.1f_%.1f", coords.x, coords.y, coords.z)
end

local function loadValidModels(modelList)
    local loaded = {}
    for _, modelName in pairs(modelList) do
        if type(modelName) == "string" and modelName ~= "" then
            local hash = GetHashKey(modelName)
            RequestModel(hash)
            local elapsed = 0
            while not HasModelLoaded(hash) and elapsed < 5000 do
                Citizen.Wait(100)
                elapsed = elapsed + 100
            end
            if HasModelLoaded(hash) then
                table.insert(loaded, modelName)
                Trace("Successfully loaded parking meter model: " .. modelName)
            else
                Trace("Failed to load parking meter model: " .. modelName .. " (hash: " .. hash .. ")")
            end
        else
            Trace("Invalid parking meter model: " .. tostring(modelName))
        end
    end
    return loaded
end

local function maybeSendDispatch(coords)
    local roll = math.random(1, 100)
    if roll > Config.ParkingMeters.AlertChance then return end

    Dispatch:Send(BuildDispatchData({
        message = Translate("PARKING_METER_DISPATCH"),
        coords  = coords,
        jobs    = { "police", "lspd", "bcso" },
        blip    = {
            sprite = 458,
            color  = 1,
            scale  = 1.0,
            text   = Translate("PARKING_METER_DISPATCH_BLIP"),
            flash  = true,
        },
    }, Config.ParkingMeters.Dispatch))
end

local function runLockpickRounds()
    local rounds = math.random(
        Config.ParkingMeters.LockpickRoundsMin or 1,
        Config.ParkingMeters.LockpickRoundsMax or 1
    )
    for _ = 1, rounds do
        local result
        if Config.Debug then
            result = { success = true }
        else
            result = LockPick:start({
                zones    = Config.ParkingMeters.LockpickZones    or 3,
                speed    = Config.ParkingMeters.LockpickSpeed    or 0.3,
                zoneSize = Config.ParkingMeters.LockpickZoneSize or 0.09,
            })
        end
        if not result.success then return false end
    end
    return true
end

local function onParkingMeterAction(entity)
    if not entity or not DoesEntityExist(entity) or IsEntityDead(entity) then
        Trace("Invalid entity passed to parking meter action")
        return
    end

    if not Framework:canDoAction("PARKING_METER_ROBBERY") then
        Framework:Notify(Translate("CANT_DO_ACTION"))
        return
    end

    if isActionBusy then
        Framework:Notify(Translate("CANT_DO_ACTION"))
        return
    end

    if Main:getPoliceCount() < Config.ParkingMeters.PoliceRequired then
        Framework:Notify(Translate("NOT_ENOUGH_POLICE"))
        return
    end

    local entityCoords = GetEntityCoords(entity)
    local key = coordKey(entityCoords)

    local serverResult = TriggerServerCallback({
        eventName = eventName .. "server:isParkingMeterBroken",
        args      = { key },
    })

    if GetEntityHealth(entity) < 1000 then
        Framework:Notify(Translate("PARKING_METER_BROKEN"))
        return
    end

    if serverResult.status then
        Framework:Notify(serverResult.message)
        return
    end

    isActionBusy = true

    local destination = GetOffsetFromEntityInWorldCoords(entity, vector3(0.0, -0.7, 0.0))
    local arrived = Main:gotoPlace(cache.ped, destination, 1.0, 4000, GetEntityHeading(entity), 1.0)
    if not arrived then
        isActionBusy = false
        return
    end

    Main:playAnimation({ ped = cache.ped, dict = "veh@break_in@0h@p_m_one@", lib = "low_force_entry_ds", flag = 49 })

    maybeSendDispatch(GetEntityCoords(cache.ped))

    Citizen.Wait(math.random(2000, 5000))

    local success = runLockpickRounds()

    if success then
        Framework:Notify(Translate("PARKING_METER_ROBBERY_SUCCESS"))
        TriggerServerEvent(eventName .. "server:setBrokenParkingMeter", {
            coordKey = key,
            itemData = serverResult.itemData,
        })

        local lootItem = Main:selectRandomItem(Config.ParkingMeters.LootTables)
        local lootResult = TriggerServerCallback({
            eventName = eventName .. "server:giveParkingMeterLoot",
            args      = { { itemName = lootItem.name } },
        })

        if lootResult.status then
            if lootResult.message then
                Framework:Notify(lootResult.message)
            end
            Framework:onFinished("PARKING_METER_ROBBERY")
        else
            Framework:Notify(Translate("NOTHING_FOUND"))
        end
    else
        Framework:Notify(Translate("PARKING_METER_ROBBERY_FAIL"))
    end

    ClearPedTasks(cache.ped)
    isActionBusy = false
end

Citizen.CreateThread(function()
    WaitForConfigSync()
    Citizen.Wait(500)

    if not Config.Modules.PARKING_METER_ROBBERY then return end
    if targetSetupDone then return end
    targetSetupDone = true

    local models = Config.ParkingMeters and Config.ParkingMeters.Models
    if not models or #models == 0 then
        Trace("No parking meter models configured, skipping target setup")
        return
    end

    local validModels = loadValidModels(models)
    if #validModels == 0 then
        Trace("No valid parking meter models found, skipping target setup")
        return
    end

    local ok, err = pcall(function()
        Target:addTargetModel(validModels, {
            label      = Translate("PARKING_METER_LABEL"),
            icon       = "fas fa-parking",
            action     = onParkingMeterAction,
            canInteract = function(entity)
                if not entity or not DoesEntityExist(entity) or IsEntityDead(entity) then return false end
                return not isActionBusy
            end,
        })
    end)

    if ok then
        Trace("Successfully added parking meter targets for " .. #validModels .. " models")
    else
        Trace("Failed to add parking meter targets: " .. tostring(err))
    end
end)
