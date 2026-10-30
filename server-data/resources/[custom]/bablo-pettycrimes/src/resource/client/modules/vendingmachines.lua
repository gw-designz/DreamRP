if not Config.Modules.VENDING_MACHINE then return end

local isActionBusy = false
local targetSetupDone = false
local lastActionTime = 0
local notifyCooldowns = {}

local function coordKey(coords)
    return string.format("%.1f_%.1f_%.1f", coords.x, coords.y, coords.z)
end

local function throttledNotify(notifyKey, message, notifyType, cooldownMs)
    local now = GetGameTimer()
    local cd = cooldownMs or 1500
    if now < (notifyCooldowns[notifyKey] or 0) then return end
    notifyCooldowns[notifyKey] = now + cd
    Framework:Notify(message, notifyType)
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
                Trace("Successfully loaded vending machine model: " .. modelName)
            else
                Trace("Failed to load vending machine model: " .. modelName .. " (hash: " .. hash .. ")")
            end
        end
    end
    return loaded
end

local function maybeSendDispatch()
    local roll = math.random(1, 100)
    if roll > Config.VendingMachines.AlertChance then return end

    Dispatch:Send(BuildDispatchData({
        message = Translate("VENDING_DISPATCH"),
        coords  = GetEntityCoords(cache.ped),
        jobs    = { "police", "lspd", "bcso" },
        blip    = {
            sprite = 52,
            color  = 1,
            scale  = 1.0,
            text   = Translate("VENDING_DISPATCH_BLIP"),
            flash  = true,
        },
    }, Config.VendingMachines.Dispatch))
end

local function onVendingMachineAction(entity)
    local now = GetGameTimer()
    if now < lastActionTime then return end
    lastActionTime = now + 350

    if not entity or not DoesEntityExist(entity) then return end

    if not Framework:canDoAction("VENDING_MACHINE") then
        throttledNotify("cant_do_action", Translate("CANT_DO_ACTION"))
        return
    end

    if isActionBusy then
        throttledNotify("vending_busy", Translate("CANT_DO_ACTION"))
        return
    end

    if Main:getPoliceCount() < Config.VendingMachines.PoliceRequired then
        throttledNotify("not_enough_police", Translate("NOT_ENOUGH_POLICE"))
        return
    end

    isActionBusy = true

    local entityCoords = GetEntityCoords(entity)
    local key = coordKey(entityCoords)

    local serverResult = TriggerServerCallback({
        eventName = eventName .. "server:isVendingBroken",
        args      = { key },
    })

    if serverResult.status then
        isActionBusy = false
        throttledNotify("vending_unavailable", serverResult.message, "error", 1800)
        return
    end

    local destination = GetOffsetFromEntityInWorldCoords(entity, vector3(0.0, -0.8, 0.0))
    local arrived = Main:gotoPlace(cache.ped, destination, 1.0, 4000, GetEntityHeading(entity), 1.0)
    if not arrived then
        isActionBusy = false
        return
    end

    Main:playAnimation({ ped = cache.ped, dict = "veh@break_in@0h@p_m_one@", lib = "low_force_entry_ds", flag = 49 })

    maybeSendDispatch()

    Citizen.Wait(math.random(2000, 5000))

    local skillPassed
    if Config.Debug then
        skillPassed = true
    else
        skillPassed = Framework:skillCheck()
    end

    if skillPassed then
        throttledNotify("vending_success", Translate("VENDING_ROBBERY_SUCCESS"), "success", 1000)

        local lootResult = TriggerServerCallback({
            eventName = eventName .. "server:vendingRobbed",
            args      = { { coordKey = key, itemData = serverResult.itemData } },
        })

        if lootResult.status then
            Framework:onFinished("VENDING_MACHINE")
        end
    else
        throttledNotify("vending_fail", Translate("VENDING_ROBBERY_FAIL"), "error", 1000)
    end

    ClearPedTasks(cache.ped)
    isActionBusy = false
end

Citizen.CreateThread(function()
    WaitForConfigSync()
    Citizen.Wait(500)

    if not Config.Modules.VENDING_MACHINE then return end
    if targetSetupDone then return end
    targetSetupDone = true

    local models = Config.VendingMachines and Config.VendingMachines.Models
    if not models or #models == 0 then
        Trace("No vending machine models configured, skipping target setup")
        return
    end

    local validModels = loadValidModels(models)
    if #validModels == 0 then
        Trace("No valid vending machine models found, skipping target setup")
        return
    end

    local ok, err = pcall(function()
        Target:addTargetModel(validModels, {
            label       = Translate("VENDING_LABEL"),
            icon        = "fas fa-wine-bottle",
            action      = onVendingMachineAction,
            canInteract = function(entity)
                if not entity or not DoesEntityExist(entity) then return false end
                return not isActionBusy
            end,
        })
    end)

    if ok then
        Trace("Successfully added vending machine targets for " .. #validModels .. " models")
    else
        Trace("Failed to add vending machine targets: " .. tostring(err))
    end
end)
