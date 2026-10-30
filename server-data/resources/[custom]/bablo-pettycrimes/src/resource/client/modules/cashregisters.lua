if not Config.Modules.CASH_REGISTER_ROBBERY then return end

local isActionBusy = false
local targetSetupDone = false

local ANIM_DICT = "oddjobs@shop_robbery@rob_till"
local ANIM_PHASES = { "enter", "loop", "exit" }

local sceneState = {
    animations = ANIM_PHASES,
    scenes     = {},
}

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
                Trace("Successfully loaded cash register model: " .. modelName)
            else
                Trace("Failed to load cash register model: " .. modelName .. " (hash: " .. hash .. ")")
            end
        end
    end
    return loaded
end

-- Shoots a blank bullet into the register to trigger the open animation
local function shootRegister(entity)
    local pos = GetEntityCoords(entity)
    ShootSingleBulletBetweenCoords(
        pos.x, pos.y, pos.z + 0.3,
        pos.x, pos.y, pos.z - 0.1,
        200, true, GetHashKey("WEAPON_PISTOL"), PlayerPedId(), true, false, 1.0
    )
end

local function loadAnimDict(dict)
    RequestAnimDict(dict)
    local elapsed = 0
    while not HasAnimDictLoaded(dict) and elapsed < 10000 do
        Citizen.Wait(10)
        elapsed = elapsed + 10
    end
    return HasAnimDictLoaded(dict)
end

local function playRegisterScene(entity)
    local ped = PlayerPedId()
    local pedCoords = GetEntityCoords(ped)

    if not loadAnimDict(ANIM_DICT) then
        Trace("Failed to load anim dict: " .. ANIM_DICT)
        return
    end

    local offset = GetOffsetFromEntityInWorldCoords(entity, vector3(-0.02512, -0.712561, -0.089709))
    local rotation = GetEntityRotation(entity)

    for i = 1, #ANIM_PHASES do
        local isLoop = (i == 2)
        local scene = NetworkCreateSynchronisedScene(
            offset.x, offset.y, offset.z,
            rotation.x, rotation.y, rotation.z,
            2, false, isLoop, 1065353216, 0, 0.8
        )
        sceneState.scenes[i] = scene
        NetworkAddPedToSynchronisedScene(ped, scene, ANIM_DICT, ANIM_PHASES[i], 1.5, -4.0, 1, 16, 1148846080, 0)
    end

    local cashBone = GetPedBoneIndex(ped, 18905)
    local cashProp1 = CreateObject(GetHashKey("prop_anim_cash_note"), pedCoords, true, true, false)
    AttachEntityToEntity(cashProp1, ped, cashBone, 0.13, 0.04, -0.02, -44.0, 0.0, 0.0, true, true, false, false, 1, true)

    local leftBone = GetPedBoneIndex(ped, 57005)
    local cashProp2 = CreateObject(GetHashKey("prop_anim_cash_note"), pedCoords, true, true, false)
    AttachEntityToEntity(cashProp2, ped, leftBone, 0.16, 0.04, -0.02, 36.0, 16.0, 27.0, true, true, false, false, 1, true)

    NetworkStartSynchronisedScene(sceneState.scenes[1])
    Citizen.Wait(1000)
    NetworkStartSynchronisedScene(sceneState.scenes[2])
    Citizen.Wait(Config.CashRegisters.GrabTime)
    NetworkStartSynchronisedScene(sceneState.scenes[3])
    Citizen.Wait(1000)

    DetachEntity(cashProp1, false, false)
    DetachEntity(cashProp2, false, false)
    DeleteObject(cashProp1)
    DeleteObject(cashProp2)
    RemoveAnimDict(ANIM_DICT)
end

local function maybeSendDispatch()
    local roll = math.random(1, 100)
    if roll > Config.CashRegisters.AlertChance then return end

    Dispatch:Send(BuildDispatchData({
        message = Translate("CASH_REGISTER_DISPATCH"),
        coords  = GetEntityCoords(cache.ped),
        jobs    = { "police", "lspd", "bcso" },
        blip    = {
            sprite = 431,
            color  = 1,
            scale  = 1.0,
            text   = Translate("CASH_REGISTER_DISPATCH_BLIP"),
            flash  = true,
        },
    }, Config.CashRegisters.Dispatch))
end

local function runLockpickRounds()
    local rounds = math.random(
        Config.CashRegisters.LockpickRoundsMin or 1,
        Config.CashRegisters.LockpickRoundsMax or 1
    )
    for _ = 1, rounds do
        local result
        if Config.Debug then
            result = { success = true }
        else
            result = LockPick:start({
                zones    = Config.CashRegisters.LockpickZones,
                speed    = Config.CashRegisters.LockpickSpeed,
                zoneSize = Config.CashRegisters.LockpickZoneSize,
            })
        end
        if not result.success then return false end
    end
    return true
end

local function onCashRegisterAction(entity)
    if not entity or not DoesEntityExist(entity) or IsEntityDead(entity) then return end

    if not Framework:canDoAction("CASH_REGISTER_ROBBERY") then
        Framework:Notify(Translate("CANT_DO_ACTION"))
        return
    end

    if isActionBusy then
        Framework:Notify(Translate("CANT_DO_ACTION"))
        return
    end

    if Main:getPoliceCount() < Config.CashRegisters.PoliceRequired then
        Framework:Notify(Translate("NOT_ENOUGH_POLICE"))
        return
    end

    local entityCoords = GetEntityCoords(entity)
    local key = coordKey(entityCoords)

    local serverResult = TriggerServerCallback({
        eventName = eventName .. "server:isCashRegisterBroken",
        args      = { key },
    })

    if serverResult.status then
        Framework:Notify(serverResult.message)
        return
    end

    isActionBusy = true

    maybeSendDispatch()

    Main:playAnimation({ ped = cache.ped, dict = "veh@break_in@0h@p_m_one@", lib = "low_force_entry_ds", flag = 1 })
    FreezeEntityPosition(cache.ped, true)

    local success = runLockpickRounds()

    FreezeEntityPosition(cache.ped, false)
    ClearPedTasks(cache.ped)

    if not success then
        Framework:Notify(Translate("CASH_REGISTER_FAIL"))
        TriggerServerEvent(eventName .. "server:cashRegisterItemBreak", { itemData = serverResult.itemData })
        isActionBusy = false
        return
    end

    shootRegister(entity)
    Citizen.Wait(500)
    playRegisterScene(entity)

    Framework:Notify(Translate("CASH_REGISTER_SUCCESS"))
    TriggerServerEvent(eventName .. "server:setBrokenCashRegister", {
        coordKey = key,
        itemData = serverResult.itemData,
    })

    local lootItem = Main:selectRandomItem(Config.CashRegisters.LootTables)
    local lootResult = TriggerServerCallback({
        eventName = eventName .. "server:giveCashRegisterLoot",
        args      = { { itemName = lootItem.name } },
    })

    if lootResult.status then
        if lootResult.message then
            Framework:Notify(lootResult.message)
        end
        Framework:onFinished("CASH_REGISTER_ROBBERY")
    else
        Framework:Notify(Translate("NOTHING_FOUND"))
    end

    ClearPedTasks(cache.ped)
    isActionBusy = false
end

Citizen.CreateThread(function()
    WaitForConfigSync()
    Citizen.Wait(500)

    if not Config.Modules.CASH_REGISTER_ROBBERY then return end
    if targetSetupDone then return end
    targetSetupDone = true

    local models = Config.CashRegisters and Config.CashRegisters.Models
    if not models or #models == 0 then
        Trace("No cash register models configured, skipping target setup")
        return
    end

    local validModels = loadValidModels(models)
    if #validModels == 0 then
        Trace("No valid cash register models found, skipping target setup")
        return
    end

    local ok, err = pcall(function()
        Target:addTargetModel(validModels, {
            label       = Translate("CASH_REGISTER_LABEL"),
            icon        = "fas fa-cash-register",
            action      = onCashRegisterAction,
            canInteract = function(entity)
                if not entity or not DoesEntityExist(entity) or IsEntityDead(entity) then return false end
                return not isActionBusy
            end,
        })
    end)

    if ok then
        Trace("Successfully added cash register targets for " .. #validModels .. " models")
    else
        Trace("Failed to add cash register targets: " .. tostring(err))
    end
end)
