if not Config.Modules.STORE_SHELVES then return end

while not eventName do Wait(0) end

local isActionBusy = false
local targetSetupDone = false

local function coordKey(coords)
    return string.format("%.1f_%.1f_%.1f", coords.x, coords.y, coords.z)
end

local function maybeSendDispatch(coords)
    local roll = math.random(1, 100)
    if roll > Config.StoreShelves.AlertChance then return end

    local dispatchMsg = Translate("STORE_SHELVES_DISPATCH")
    Dispatch:Send(BuildDispatchData({
        coords      = coords,
        jobs        = { "police", "lspd", "bcso" },
        message     = dispatchMsg,
        description = dispatchMsg,
        blip        = {
            sprite = 59,
            scale  = 1.0,
            colour = 1,
            text   = Translate("STORE_SHELVES_DISPATCH_BLIP"),
            time   = 30,
        },
    }, Config.StoreShelves.Dispatch))
end

local function onShelfAction(entity)
    if isActionBusy then return end

    local ped = PlayerPedId()
    local entityCoords = GetEntityCoords(entity)
    local key = coordKey(entityCoords)

    if not Framework:canDoAction("STORE_SHELVES") then
        Framework:Notify(Translate("CANT_DO_ACTION"))
        return
    end

    if Main:getPoliceCount() < Config.StoreShelves.PoliceRequired then
        Framework:Notify(Translate("NOT_ENOUGH_POLICE"), "error")
        return
    end

    local isBroken = TriggerServerCallback({
        eventName = eventName .. "server:isShelfBroken",
        args      = { key },
    })

    if isBroken then
        Framework:Notify(Translate("STORE_SHELVES_EMPTY"), "error")
        return
    end

    isActionBusy = true

    maybeSendDispatch(entityCoords)

    TaskTurnPedToFaceEntity(ped, entity, 1000)
    Wait(1000)

    local finished = lib.progressBar({
        duration     = Config.StoreShelves.ProgressTime,
        label        = Translate("STORE_SHELVES_LABEL"),
        useWhileDead = false,
        canCancel    = true,
        disable      = { car = true, move = true, combat = true },
        anim         = { dict = "amb@prop_human_bum_bin@base", clip = "base" },
    })

    if finished then
        TriggerServerEvent(eventName .. "server:setShelfBroken", key)

        local emptyChance = Config.StoreShelves.EmptyChance or 0
        if math.random(1, 100) <= emptyChance then
            Framework:Notify(Translate("STORE_SHELVES_EMPTY"), "error")
        else
            TriggerServerEvent(eventName .. "server:giveShelfLoot")
            Framework:Notify(Translate("STORE_SHELVES_SUCCESS"), "success")
        end
    end

    ClearPedTasks(ped)
    isActionBusy = false
end

CreateThread(function()
    WaitForConfigSync()
    Wait(500)

    if not Config.Modules.STORE_SHELVES then return end
    if targetSetupDone then return end
    targetSetupDone = true

    local models = Config.StoreShelves and Config.StoreShelves.Models
    if not models or #models == 0 then return end

    local validModels = {}
    for _, modelName in pairs(models) do
        if type(modelName) == "string" and modelName ~= "" then
            table.insert(validModels, modelName)
        end
    end

    if #validModels == 0 then return end

    local ok, err = pcall(function()
        Target:addTargetModel(validModels, {
            icon        = "fas fa-search",
            label       = Translate("STORE_SHELVES_LABEL"),
            action      = onShelfAction,
            canInteract = function(entity)
                return not isActionBusy and DoesEntityExist(entity)
            end,
        })
    end)

    if not ok then
        Trace("Failed to add store shelves targets: " .. tostring(err))
    end
end)
