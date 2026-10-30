if not (Config and Config.Prison and Config.Prison.Enabled) then return end
if not Config.Prison.PrisonLife.enabled then return end

-- ─── Module State ────────────────────────────────────────────────────────────

-- [npcIndex] = ped entity handle (spawned NPCs)
local spawnedNpcPeds = {}
-- [npcIndex] = base64 mugshot string cache
local npcAvatarCache = {}
-- Currently open dialog's NPC index
local activeNpcIndex = nil
-- Scripted camera for NPC portrait
local npcPortraitCam = nil

-- ─── NPC Portrait Camera ─────────────────────────────────────────────────────

-- Creates a scripted camera focused on the NPC's head bone
local function ShowNpcPortraitCam(pedEntity)
    if npcPortraitCam then
        RenderScriptCams(false, false, 0, true, true)
        DestroyCam(npcPortraitCam, false)
        npcPortraitCam = nil
    end

    local heading  = GetEntityHeading(pedEntity)
    local headPos  = GetPedBoneCoords(pedEntity, 31086, 0.0, 0.0, 0.0)
    local offset   = 0.8
    local radH     = math.rad(heading)

    local camPos   = vector3(
        headPos.x - math.sin(radH) * offset,
        headPos.y + math.cos(radH) * offset,
        headPos.z
    )

    local cam = CreateCam("DEFAULT_SCRIPTED_CAMERA", true)
    npcPortraitCam = cam

    SetCamCoord(cam, camPos.x, camPos.y, camPos.z)
    PointCamAtPedBone(cam, pedEntity, 31086, 0.0, 0.0, 0.0, true)
    SetCamFov(cam, 50.0)
    RenderScriptCams(true, true, 500, true, true)
end

local function HideNpcPortraitCam()
    if not npcPortraitCam then return end
    RenderScriptCams(false, true, 500, true, true)
    DestroyCam(npcPortraitCam, false)
    npcPortraitCam = nil
end

-- ─── Mugshot Helper ───────────────────────────────────────────────────────────

-- Returns a base64 mugshot for npcIndex (from cache or via MugShotBase64 export)
-- Also accepts a ped entity handle to generate a fresh one if not cached
local function GetNpcMugshot(npcIndex, pedEntity)
    if npcAvatarCache[npcIndex] then return npcAvatarCache[npcIndex] end

    if not (pedEntity and DoesEntityExist(pedEntity)) then return nil end

    if GetResourceState("MugShotBase64") ~= "started" then return nil end

    local ok, result = pcall(function()
        return exports.MugShotBase64:GetMugShotBase64(pedEntity, true)
    end)

    if ok and result and result ~= "" then
        npcAvatarCache[npcIndex] = result
        return result
    end

    return nil
end

-- ─── Open NPC Dialog ─────────────────────────────────────────────────────────

function openNpcDialog(npcIndex)
    if not (Prison.isInPrison and Prison.Map and Prison.Map.npcs) then return end

    local npcData = Prison.Map.npcs[npcIndex]
    if not npcData then return end

    local pedEntity = spawnedNpcPeds[npcIndex]
    if pedEntity and DoesEntityExist(pedEntity) then
        ShowNpcPortraitCam(pedEntity)
    end

    SendNUIMessage({ action = "setVisiblePrisonDialog", data = true })
    SendNUIMessage({
        action = "setPrisonDialogData",
        data   = {
            npcLabel  = npcData.label,
            npcModel  = npcData.model,
            dialogue  = npcData.dialogue,
            npcAvatar = npcAvatarCache[npcIndex],
        },
    })

    SetNuiFocus(true, true)
    activeNpcIndex = npcIndex

    -- Generate mugshot asynchronously if not yet cached
    if not npcAvatarCache[npcIndex] then
        CreateThread(function()
            local avatar = GetNpcMugshot(npcIndex, pedEntity)
            if avatar and activeNpcIndex == npcIndex then
                SendNUIMessage({ action = "setPrisonDialogAvatar", data = avatar })
            end
        end)
    end
end

-- ─── NUI Callbacks ───────────────────────────────────────────────────────────

RegisterNUICallback("prison/dialog/select", function(payload, cb)
    SetNuiFocus(false, false)
    cb({})
    HideNpcPortraitCam()

    if not (payload and payload.action) then return end

    local action = payload.action

    if action == "close" then
        return

    elseif action == "trade" then
        openTradeMenu(activeNpcIndex)

    elseif action == "illegal_shop" then
        openShopNui("illegal")

    elseif action == "prison_jobs" then
        TriggerEvent("p_policejob/client/prison/openJobs")

    elseif action == "check_sentence" then
        local remaining = lib.callback.await("p_policejob/server/prison/getRemainingTime", false)
        if remaining then
            lib.alertDialog({
                header   = "Sentence Info",
                content  = string.format("You have **%d minutes** remaining on your sentence.",
                    math.ceil(remaining / 60)),
                centered = true,
                cancel   = false,
            })
        end

    elseif action == "info" then
        Bridge.Notify.showNotify(locale("prison_guard_inspect_hint"), "info")
    end
end)

RegisterNUICallback("prison/dialog/close", function(_, cb)
    SetNuiFocus(false, false)
    HideNpcPortraitCam()
    cb({})
end)

-- ─── Trade Menu ───────────────────────────────────────────────────────────────

function openTradeMenu(npcIndex)
    if not Prison.isInPrison then return end

    -- NPC trade if this index has tradeItems
    if npcIndex and Prison.Map and Prison.Map.npcs then
        local npcData = Prison.Map.npcs[npcIndex]
        if npcData and npcData.tradeItems and #npcData.tradeItems > 0 then
            -- Enrich NPC item list with inventory labels / images
            local npcItems = {}
            for i, tradeItem in ipairs(npcData.tradeItems) do
                local itemData = Bridge.Inventory.getItemData(tradeItem.name)
                npcItems[i] = {
                    name        = tradeItem.name,
                    label       = (itemData and itemData.label) or tradeItem.label,
                    price       = tradeItem.price,
                    description = (itemData and itemData.description) or tradeItem.description or "",
                    image       = itemData and itemData.image or nil,
                }
            end

            -- Fetch player inventory items available for trade
            local playerItems = lib.callback.await("p_policejob/server/prison/getTradeItems", false) or {}
            for _, item in ipairs(playerItems) do
                local itemData = Bridge.Inventory.getItemData(item.name)
                item.label = (itemData and itemData.label) or item.label or item.name
                item.image = itemData and itemData.image or nil
                item.value = item.value or 5
            end

            SendNUIMessage({ action = "setVisiblePrisonTrade", data = true })
            SendNUIMessage({
                action = "setNpcTradeData",
                data   = {
                    npcName    = npcData.label,
                    npcIndex   = npcIndex,
                    playerItems = playerItems,
                    npcItems   = npcItems,
                },
            })
            SetNuiFocus(true, true)
            return
        end
    end

    -- Player-to-player trade: find nearby prisoners
    local nearbyPlayers = {}
    local pedPos        = GetEntityCoords(cache.ped)
    local tradeDist     = Config.Prison.PrisonLife.trading.distance

    for _, playerId in ipairs(GetActivePlayers()) do
        if playerId ~= cache.playerId then
            local otherPed = GetPlayerPed(playerId)
            if otherPed and DoesEntityExist(otherPed) then
                local dist = #(pedPos - GetEntityCoords(otherPed))
                if dist < tradeDist then
                    nearbyPlayers[#nearbyPlayers + 1] = {
                        id   = GetPlayerServerId(playerId),
                        name = GetPlayerName(playerId),
                    }
                end
            end
        end
    end

    if #nearbyPlayers == 0 then
        return Bridge.Notify.showNotify(locale("prison_trade_no_target"), "error")
    end

    local targetId, targetName

    if #nearbyPlayers == 1 then
        targetId   = nearbyPlayers[1].id
        targetName = nearbyPlayers[1].name
    else
        -- Multiple nearby: prompt to choose
        local options = {}
        for _, p in ipairs(nearbyPlayers) do
            options[#options + 1] = {
                value = tostring(p.id),
                label = string.format("%s (ID: %s)", p.name, p.id),
            }
        end

        local input = lib.inputDialog(locale("prison_trade_select_player"), {
            { type = "select", label = "Player", options = options, required = true },
        })
        if not input then return end

        targetId = tonumber(input[1])
        for _, p in ipairs(nearbyPlayers) do
            if p.id == targetId then
                targetName = p.name
                break
            end
        end
    end

    if not targetId then return end

    local myItems = lib.callback.await("p_policejob/server/prison/getTradeItems", false) or {}
    if #myItems == 0 then
        return Bridge.Notify.showNotify(locale("prison_trade_no_items"), "error")
    end

    SendNUIMessage({ action = "setVisiblePrisonTrade", data = true })
    SendNUIMessage({
        action = "setPrisonTradeData",
        data   = {
            targetName = targetName or ("Player " .. targetId),
            targetId   = targetId,
            myItems    = myItems,
        },
    })
    SetNuiFocus(true, true)
end

-- ─── Shop NUI (commissary / illegal) ─────────────────────────────────────────

function openShopNui(shopType)
    if not Prison.isInPrison then return end

    local shopCfg, title
    if shopType == "commissary" then
        shopCfg = Config.Prison.Commissary
        title   = "Commissary"
    elseif shopType == "illegal" then
        shopCfg = Config.Prison.IllegalShop
        title   = "Black Market"
    else
        return
    end

    -- Enrich item list with inventory data
    local items = {}
    for i, item in ipairs(shopCfg.items) do
        local itemData = Bridge.Inventory.getItemData(item.name)
        items[i] = {
            name        = item.name,
            label       = (itemData and itemData.label)       or item.name,
            price       = item.price,
            description = (itemData and itemData.description) or item.description or "",
            image       = itemData and itemData.image or nil,
        }
    end

    SendNUIMessage({ action = "setVisiblePrisonShop", data = true })
    SendNUIMessage({
        action = "setPrisonShopData",
        data   = {
            shopType = shopType,
            title    = title,
            items    = items,
        },
    })
    SetNuiFocus(true, true)
end

-- ─── Trade NUI Callbacks ─────────────────────────────────────────────────────

RegisterNUICallback("prison/trade/send", function(payload, cb)
    SetNuiFocus(false, false)
    cb({})
    if not (payload and payload.targetId and payload.items) then return end
    TriggerServerEvent("p_policejob/server/prison/trade/send", {
        targetId = payload.targetId,
        items    = payload.items,
    })
end)

RegisterNUICallback("prison/trade/close", function(_, cb)
    SendNUIMessage({ action = "setVisiblePrisonTrade", data = false })
    SetNuiFocus(false, false)
    cb({})
end)

RegisterNUICallback("prison/npc_trade/execute", function(payload, cb)
    SetNuiFocus(false, false)
    cb({})
    if not (payload and payload.npcIndex and payload.offeredItems and payload.requestedItem) then return end
    TriggerServerEvent("p_policejob/server/prison/npc_trade/execute", {
        npcIndex      = payload.npcIndex,
        offeredItems  = payload.offeredItems,
        requestedItem = payload.requestedItem,
    })
end)

RegisterNUICallback("prison/npc_trade/close", function(_, cb)
    SendNUIMessage({ action = "setVisiblePrisonTrade", data = false })
    SetNuiFocus(false, false)
    cb({})
end)

-- ─── Shop NUI Callbacks ───────────────────────────────────────────────────────

RegisterNUICallback("prison/shop/checkout", function(payload, cb)
    SetNuiFocus(false, false)
    cb({})
    if not (payload and payload.shopType and payload.items) then return end

    for _, item in ipairs(payload.items) do
        if payload.shopType == "commissary" then
            TriggerServerEvent("p_policejob/server/prison/commissary/buy", {
                item     = item.name,
                quantity = item.quantity,
                price    = item.price,
            })
        elseif payload.shopType == "illegal" then
            TriggerServerEvent("p_policejob/server/prison/illegalshop/buy", {
                item     = item.name,
                quantity = item.quantity,
                price    = item.price,
            })
        elseif payload.shopType == "npc_trade" then
            TriggerServerEvent("p_policejob/server/prison/npc_trade/buy", {
                item     = item.name,
                quantity = item.quantity,
                price    = item.price,
                npcIndex = payload.npcIndex,
            })
        end
    end
end)

RegisterNUICallback("prison/shop/close", function(_, cb)
    SendNUIMessage({ action = "setVisiblePrisonShop", data = false })
    SetNuiFocus(false, false)
    cb({})
end)

-- ─── NPC Spawn Thread ────────────────────────────────────────────────────────

CreateThread(function()
    while not Config.Prison do Wait(100) end
    while not Prison.Map    do Wait(100) end

    if not Prison.Map.npcs then return end

    for npcIndex, npcData in ipairs(Prison.Map.npcs) do
        local modelHash = joaat(npcData.model)
        lib.requestModel(npcData.model)

        if HasModelLoaded(modelHash) then
            local coords = npcData.coords
            local ped    = CreatePed(4, modelHash,
                coords.x, coords.y, coords.z - 1.0,
                coords.w, false, true
            )

            SetEntityHeading(ped, coords.w)
            FreezeEntityPosition(ped, true)
            SetEntityInvincible(ped, true)
            SetBlockingOfNonTemporaryEvents(ped, true)
            SetPedFleeAttributes(ped, 0, false)
            SetPedCombatAttributes(ped, 46, true)
            SetPedCanRagdollFromPlayerImpact(ped, false)

            if npcData.scenario then
                TaskStartScenarioInPlace(ped, npcData.scenario, 0, true)
            end

            spawnedNpcPeds[npcIndex] = ped
            SetModelAsNoLongerNeeded(modelHash)

            local idx = npcIndex
            Bridge.Target.addLocalEntity(ped, {
                {
                    label    = "Talk to " .. npcData.label,
                    icon     = "fa-solid fa-comments",
                    canInteract = function()
                        return Prison.isInPrison
                    end,
                    onSelect = function()
                        openNpcDialog(idx)
                    end,
                },
            })
        end
    end
end)

-- ─── Cleanup ─────────────────────────────────────────────────────────────────

AddEventHandler("onResourceStop", function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end

    for _, ped in pairs(spawnedNpcPeds) do
        if DoesEntityExist(ped) then
            Bridge.Target.removeLocalEntity(ped)
            DeleteEntity(ped)
        end
    end
end)
