if not Config.Modules.MAILBOX_ROBBERY then return end

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
                Trace("Successfully loaded mailbox model: " .. modelName)
            else
                Trace("Failed to load mailbox model: " .. modelName .. " (hash: " .. hash .. ")")
            end
        else
            Trace("Invalid mailbox model: " .. tostring(modelName))
        end
    end
    return loaded
end

local function maybeSendDispatch()
    local roll = math.random(1, 100)
    if roll > Config.Mailboxes.AlertChance then return end

    Dispatch:Send(BuildDispatchData({
        message = Translate("MAILBOX_DISPATCH"),
        coords  = GetEntityCoords(cache.ped),
        jobs    = { "police", "lspd", "bcso" },
        blip    = {
            sprite = 458,
            color  = 1,
            scale  = 1.0,
            text   = Translate("MAILBOX_DISPATCH_BLIP"),
            flash  = true,
        },
    }, Config.Mailboxes.Dispatch))
end

local function runLockpickRounds()
    local rounds = math.random(
        Config.Mailboxes.LockpickRoundsMin or 1,
        Config.Mailboxes.LockpickRoundsMax or 1
    )
    for _ = 1, rounds do
        local result
        if Config.Debug then
            result = { success = true }
        else
            result = LockPick:start({
                zones    = Config.Mailboxes.LockpickZones    or 4,
                speed    = Config.Mailboxes.LockpickSpeed    or 0.35,
                zoneSize = Config.Mailboxes.LockpickZoneSize or 0.08,
            })
        end
        if not result.success then return false end
    end
    return true
end

-- If the hand gets stuck in the mailbox after success, loop the stuck-escape minigame
-- until the player breaks free. Runs identically for both the "letter found" and
-- "fail with stuck chance" code paths, so extracted here to avoid duplication.
local function runStuckEscapeSequence()
    Framework:Notify(Translate("MAILBOX_ROBBERY_FAIL"))
    FreezeEntityPosition(cache.ped, true)
    Main:playAnimation({ ped = cache.ped, dict = "bablo@mailbox", lib = "clip", flag = 1 })

    local delayRange = Config.Mailboxes.StuckMinigameDelay
    local delayMin = (delayRange and delayRange[1]) or 4000
    local delayMax = (delayRange and delayRange[2]) or 8000
    Citizen.Wait(math.random(delayMin, delayMax))

    local escaped = false
    while not escaped do
        local result = LockPick:start({
            zones    = Config.Mailboxes.StuckLockpickZones    or 3,
            speed    = Config.Mailboxes.StuckLockpickSpeed    or 0.3,
            zoneSize = Config.Mailboxes.StuckLockpickZoneSize or 0.1,
        })
        if result.success then
            escaped = true
        else
            Framework:Notify(Translate("MAILBOX_STILL_STUCK"))
            Citizen.Wait(math.random(2000, 4000))
        end
    end

    FreezeEntityPosition(cache.ped, false)
end

local function onMailboxAction(entity)
    if not entity or not DoesEntityExist(entity) or IsEntityDead(entity) then
        Trace("Invalid entity passed to mailbox action")
        return
    end

    if not Framework:canDoAction("MAILBOX_ROBBERY") then
        Framework:Notify(Translate("CANT_DO_ACTION"))
        return
    end

    if isActionBusy then
        Framework:Notify(Translate("CANT_DO_ACTION"))
        return
    end

    if Main:getPoliceCount() < Config.Mailboxes.PoliceRequired then
        Framework:Notify(Translate("NOT_ENOUGH_POLICE"))
        return
    end

    local entityCoords = GetEntityCoords(entity)
    local key = coordKey(entityCoords)

    local serverResult = TriggerServerCallback({
        eventName = eventName .. "server:isMailboxBroken",
        args      = { key },
    })

    if GetEntityHealth(entity) < 1000 then
        Framework:Notify(Translate("MAILBOX_BROKEN"))
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

    Main:playAnimation({ ped = cache.ped, dict = "bablo@mailbox", lib = "clip", flag = 1 })

    maybeSendDispatch()

    Citizen.Wait(math.random(2000, 5000))

    local success = runLockpickRounds()

    if success then
        Framework:Notify(Translate("MAILBOX_ROBBERY_SUCCESS"))
        TriggerServerEvent(eventName .. "server:setBrokenMailbox", {
            coordKey = key,
            itemData = serverResult.itemData,
        })

        local lootResult = TriggerServerCallback({
            eventName = eventName .. "server:giveMailboxLoot",
            args      = { { itemName = "letter" } },
        })

        if lootResult.status then
            Framework:Notify(Translate("MAILBOX_FOUND_LETTER"))
            Framework:onFinished("MAILBOX_ROBBERY")
        end

        -- Chance that the hand gets stuck after successfully raiding the mailbox
        local stuckChance = tonumber(Config.Mailboxes.StuckChance) or 0
        if stuckChance > 0 and math.random(1, 100) <= stuckChance then
            runStuckEscapeSequence()
        end
    else
        runStuckEscapeSequence()
    end

    ClearPedTasks(cache.ped)
    isActionBusy = false
end

-- Called when the player uses a found letter item; triggers a random loot reward
function GetRewardItem(itemData)
    local itemName = SelectRandomItem(Config.Mailboxes.LootTables).name

    local result = TriggerServerCallback({
        eventName = eventName .. "server:giveMailboxLoot",
        args      = { { itemName = itemName, itemData = itemData } },
    })

    if result.success then
        Framework:Notify(result.message)
    else
        Framework:Notify(Translate("NOTHING_FOUND"))
    end
end

RegisterNetEvent(eventName .. "client:useLetterItem")
AddEventHandler(eventName .. "client:useLetterItem", function(itemData)
    GetRewardItem(itemData)
end)

Citizen.CreateThread(function()
    WaitForConfigSync()
    Citizen.Wait(500)

    if not Config.Modules.MAILBOX_ROBBERY then return end
    if targetSetupDone then return end
    targetSetupDone = true

    local models = Config.Mailboxes and Config.Mailboxes.Models
    if not models or #models == 0 then
        Trace("No mailbox models configured, skipping target setup")
        return
    end

    local validModels = loadValidModels(models)
    if #validModels == 0 then
        Trace("No valid mailbox models found, skipping target setup")
        return
    end

    local ok, err = pcall(function()
        Target:addTargetModel(validModels, {
            label       = Translate("MAILBOX_LABEL"),
            icon        = "fas fa-mail-bulk",
            action      = onMailboxAction,
            canInteract = function(entity)
                if not entity or not DoesEntityExist(entity) or IsEntityDead(entity) then return false end
                return not isActionBusy
            end,
        })
    end)

    if ok then
        Trace("Successfully added mailbox targets for " .. #validModels .. " models")
    else
        Trace("Failed to add mailbox targets: " .. tostring(err))
    end
end)
