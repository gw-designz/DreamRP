if not Config.Modules.PICKPOCKETING then return end

PickPocketing = {
    inAction        = false,
    newElement      = nil,
    minigamePromise = nil,
}

-- Returns a random float in [minVal, maxVal] with 0.01 precision
local function randomFloat(minVal, maxVal)
    local range = (maxVal - minVal) * 100
    return minVal + math.random(0, math.floor(range)) / 100
end

local function cancelMinigame(self)
    SendNUIMessage({ action = "PICKPOCKET_MINIGAME_CANCEL" })
    if self.minigamePromise then
        self.minigamePromise:resolve({ succeeded = {}, failed = true, cancelled = true })
        self.minigamePromise = nil
    end
end

local function maybeSendDispatch(targetPed)
    local roll = math.random(1, 100)
    if roll > Config.PickPocketing.AlertChance then return false end

    Dispatch:Send(BuildDispatchData({
        message = Translate("PICKPOCKET_DISPATCH"),
        coords  = GetEntityCoords(targetPed),
        jobs    = { "police", "lspd", "bcso" },
        blip    = {
            sprite = 458,
            color  = 1,
            scale  = 1.0,
            text   = Translate("PICKPOCKET_DISPATCH_BLIP"),
            flash  = true,
        },
    }, Config.PickPocketing.Dispatch))

    return true
end

-- Fisher-Yates shuffle on a sequential index array
local function shuffledIndices(count)
    local indices = {}
    for i = 1, count do indices[i] = i end
    for i = count, 2, -1 do
        local j = math.random(1, i)
        indices[i], indices[j] = indices[j], indices[i]
    end
    return indices
end

-- Builds the slot list for the minigame: 'count' slots, some randomly unlockable
local function buildMinigameSlots(count)
    local maxUnlockable = math.min(count - 1, 3)
    local numUnlockable = math.random(1, maxUnlockable)

    local shuffled = shuffledIndices(count)
    local unlockableSet = {}
    for i = 1, numUnlockable do
        unlockableSet[shuffled[i]] = true
    end

    local slots = {}
    for i = 1, count do
        local item = SelectRandomItem(Config.PickPocketing.LootTables)
        local count = nil
        if item.count then
            count = math.random(item.count[1], item.count[2])
        end
        table.insert(slots, {
            name       = item.name,
            label      = item.label or item.name,
            count      = count,
            unlockable = unlockableSet[i] == true,
        })
    end
    return slots
end

function PickPocketing:canPickPocket(targetPed)
    if not targetPed or targetPed == 0 then return false end
    if not DoesEntityExist(targetPed) or IsEntityDead(targetPed) then return false end
    if not Framework:canDoAction("PICKPOCKETING") then return false end

    -- Check blacklisted models
    local model = GetEntityModel(targetPed)
    for _, blacklisted in pairs(Config.PickPocketing.BlacklistedModels) do
        if model == blacklisted then return false end
    end

    if IsPedInAnyVehicle(targetPed, false) then return false end
    if not NetworkGetEntityIsNetworked(targetPed) then return false end
    if Entity(targetPed).state.pickPocketed then return false end
    if self.inAction then return false end

    -- Player must be facing the target from behind
    return not IsPedFacingPed(cache.ped, targetPed, 90.0)
end

function PickPocketing:pickPocket(targetPed)
    if not targetPed or not DoesEntityExist(targetPed) then return end
    if not self:canPickPocket(targetPed) then return end

    if Main:getPoliceCount() < Config.PickPocketing.PoliceRequired then
        Framework:Notify(Translate("NOT_ENOUGH_POLICE"))
        return
    end

    Main:playAnimation({ ped = cache.ped, dict = "anim@heists@prison_heiststation@heels", lib = "pickup_bus_schedule", flag = 49 })

    self.inAction = true
    self:onPickPocket(targetPed)

    local slotCount  = Config.PickPocketing.MinigameSlots    or 5
    local speedMin   = Config.PickPocketing.MinigameSpeedMin or 0.28
    local speedMax   = Config.PickPocketing.MinigameSpeedMax or 0.72
    local zoneWidth  = Config.PickPocketing.MinigameZoneWidth or 0.22
    local slots      = buildMinigameSlots(slotCount)
    local speed      = randomFloat(speedMin, speedMax)

    self.minigamePromise = promise.new()

    SendNUIMessage({
        action = "PICKPOCKET_MINIGAME_OPEN",
        data   = {
            items     = slots,
            speed     = speed,
            zoneWidth = zoneWidth,
            labels    = {
                stopHint    = Translate("PICKPOCKET_MINIGAME_STOP_HINT"),
                noticed     = Translate("PICKPOCKET_MINIGAME_NOTICED"),
                gotPrefix   = Translate("PICKPOCKET_MINIGAME_GOT"),
                keyStop     = Translate("PICKPOCKET_MINIGAME_KEY_STOP"),
                keyCancel   = Translate("PICKPOCKET_MINIGAME_KEY_CANCEL"),
                stopLabel   = Translate("PICKPOCKET_MINIGAME_STOP_LABEL"),
                cancelLabel = Translate("PICKPOCKET_MINIGAME_CANCEL_LABEL"),
            },
        }
    })

    -- Input control loop while minigame is active
    Citizen.CreateThread(function()
        while self.minigamePromise do
            DisableControlAction(0, 22, true)
            DisableControlAction(0, 177, true)
            DisableControlAction(0, 199, true)
            DisableControlAction(0, 200, true)

            if IsDisabledControlJustPressed(0, 22) then
                SendNUIMessage({ action = "PICKPOCKET_MINIGAME_STOP" })
            end

            if IsDisabledControlJustPressed(0, 200) then
                cancelMinigame(self)
            end

            Citizen.Wait(0)
        end
    end)

    local result = Citizen.Await(self.minigamePromise)
    self.inAction = false

    if result.cancelled then
        ClearPedTasks(cache.ped)
        Main:setEntityStateBag(targetPed, { pickPocketed = true })
        return
    end

    if result.failed or result.itemIndex == nil then
        self:onFail(targetPed, true)
        return
    end

    local chosenSlot = slots[result.itemIndex + 1]
    if chosenSlot then
        TriggerServerCallback({
            eventName = eventName .. "server:onPickPocketFinish",
            args      = {{
                netId     = NetworkGetNetworkIdFromEntity(targetPed),
                itemName  = chosenSlot.name,
                count     = chosenSlot.count,
                guaranteed = true,
            }},
        })
    end

    Main:setEntityStateBag(targetPed, { pickPocketed = true })
    ClearPedTasks(cache.ped)
    Framework:onFinished("PICKPOCKETING")
end

function PickPocketing:onFail(targetPed, forceDispatch)
    if not self.inAction and not forceDispatch then return end

    self.inAction = false

    if self.minigamePromise then
        cancelMinigame(self)
    end

    ClearPedTasks(cache.ped)

    local wasFacing = IsPedFacingPed(targetPed, cache.ped, 90.0)
    if not wasFacing and not forceDispatch then return end

    local dispatched = maybeSendDispatch(targetPed)

    if not DoesEntityExist(targetPed) or IsEntityDead(targetPed) then return end

    ClearPedTasksImmediately(targetPed)

    if not dispatched then
        Framework:Notify(Translate("PICKPOCKET_FAIL"))
    end

    -- 60% flee, 40% fight back (unless dispatched, always flee)
    if math.random(1, 100) <= 60 or dispatched then
        TaskReactAndFleePed(targetPed, cache.ped)
    else
        TaskCombatPed(targetPed, cache.ped, 0, 16)
    end

    Main:setEntityStateBag(targetPed, { pickPocketed = true })
end

-- Monitors the target ped during an active pickpocket attempt for interruptions
function PickPocketing:onPickPocket(targetPed)
    Citizen.CreateThread(function()
        Citizen.Wait(800)

        while self.inAction do
            if Entity(targetPed).state.pickPocketed then
                self.inAction = false
                break
            end

            local targetPos = GetEntityCoords(targetPed)
            local pedPos    = GetEntityCoords(cache.ped)
            local dist      = #(targetPos - pedPos)

            local targetIsAlerted = IsPedSprinting(targetPed) or IsPedFleeing(targetPed)
                or (dist <= 3.0 and IsPedFacingPed(targetPed, cache.ped, 90.0))

            if targetIsAlerted then
                self:onFail(targetPed)
                self.inAction = false
                break
            end

            if dist > 3.0 then
                if self.minigamePromise then
                    cancelMinigame(self)
                end
                self.inAction = false
                ClearPedTasks(cache.ped)
                Framework:Notify(Translate("PICKPOCKET_TOO_FAR"))
                break
            end

            Citizen.Wait(200)
        end
    end)
end

-- Target setup
Citizen.CreateThread(function()
    WaitForConfigSync()
    Citizen.Wait(1000)

    local element = Target:addGlobalPed({
        label       = Translate("PICKPOCKET_LABEL"),
        icon        = "fas fa-search",
        action      = function(targetPed) PickPocketing:pickPocket(targetPed) end,
        canInteract = function(targetPed) return PickPocketing:canPickPocket(targetPed) end,
    })

    PickPocketing.newElement = element
end)

RegisterNUICallback("pickpocket:minigame:result", function(data, cb)
    cb({})
    if PickPocketing.minigamePromise then
        PickPocketing.minigamePromise:resolve(data)
        PickPocketing.minigamePromise = nil
    end
end)

AddEventHandler("onResourceStop", function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end

    if PickPocketing.newElement then
        Target:removeGlobalPed(PickPocketing.newElement)
    end

    if PickPocketing.minigamePromise then
        PickPocketing.minigamePromise:resolve({ succeeded = {}, failed = true, cancelled = true })
        PickPocketing.minigamePromise = nil
    end
end)

exports("isPickpocketed", function(entity)
    return Entity(entity).state.pickPocketed or false
end)

exports("setPickpocketed", function(entity, value)
    Main:setEntityStateBag(entity, { pickPocketed = value })
end)
