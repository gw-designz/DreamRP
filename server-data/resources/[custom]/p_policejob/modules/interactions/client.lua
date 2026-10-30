if not (Config and Config.Interactions and Config.Interactions.Enabled) then return end

Interactions = {}
Interactions.isInCuffProcess = false
Interactions.cuffProp        = nil
Interactions.cuffSide        = "rear"
Interactions.isHard          = false
Interactions.isCuffed        = false
Interactions.ropeTimer       = nil
Interactions.dragStatus      = { draggedBy = nil, draggingPlayer = nil }
Interactions.carryData       = { isActive = false, playerId = nil, playerPed = nil, role = "" }
Interactions.headBagData     = { object = nil, state = false }
Interactions.mouthTapes      = {}

-- Seat labels for the police menu PutInVehicle options
local SEAT_LABELS = {
    ["-1"] = locale("driver_seat"),
    ["0"]  = locale("passenger_seat"),
    ["1"]  = locale("back_left_passenger"),
    ["2"]  = locale("back_right_passenger"),
}

-- ============================================================
--  Compat export shim — broadcasts this export to legacy police resource names
-- ============================================================

local function registerCompatExport(exportName, handler)
    for _, resourceName in ipairs({ "qb-policejob", "qbx_police", "wasabi_police" }) do
        AddEventHandler(("__cfx_export_%s_%s"):format(resourceName, exportName), function(setCb)
            setCb(handler)
        end)
    end
    exports(exportName, handler)
end

registerCompatExport("IsHandcuffed", function()
    return LocalPlayer.state.isCuffed
end)

-- ============================================================
--  Exports
-- ============================================================

exports("isInCuffProcess", function()
    return Interactions.isInCuffProcess
end)

registerCompatExport("searchPlayer", function(targetSource)
    if not targetSource then return end
    Bridge.Inventory.openInventory("player", tonumber(targetSource))
end)

registerCompatExport("escortPlayer", function(targetSource)
    if not targetSource then return end
    Interactions:quickEscort(tonumber(targetSource))
end)

-- ============================================================
--  Shared utility methods
-- ============================================================

function Interactions.canAct(self)
    return Editable.canAct()
end

function Interactions.isInFront(self, targetPed)
    return Editable:isInFront(targetPed)
end

function Interactions.isPlayerDead(self, targetSource)
    return Editable:isPlayerDead(targetSource)
end

-- Waits until an entity is networked (up to 100×10ms), then returns its netId
function Interactions.getNetIdFromEntity(self, entity)
    local attempts = 0
    while not NetworkGetEntityIsNetworked(entity) do
        Wait(10)
        attempts = attempts + 1
        if attempts > 100 then return 0 end
    end
    return NetworkGetNetworkIdFromEntity(entity)
end

-- ============================================================
--  Per-frame cache for player state lookups
-- ============================================================

local _frameCache = { frame = -1 }

-- Called every time we need info about a nearby ped. Cached per frame to avoid
-- repeated native calls when the same ped is queried multiple times in one tick.
local function resolvePlayerCache(ped)
    local currentFrame = GetFrameCount()
    if _frameCache.frame == currentFrame and _frameCache.entity == ped then
        return _frameCache
    end

    local playerIndex = NetworkGetPlayerIndexFromPed(ped)
    local serverId    = (playerIndex ~= 0) and GetPlayerServerId(playerIndex) or 0
    local playerState = {
        isCuffed        = false,
        draggedBy       = nil,
        carriedBy       = nil,
        isDead          = false,
        dead            = false,
        cuffType        = "none",
        mouthTaped      = false,
        hasHeadBag      = false,
        hasTrackingBand = false,
    }

    if serverId and serverId ~= 0 then
        local ok, ps = pcall(function() return Player(serverId).state end)
        if ok and ps then
            playerState.isCuffed        = ps.isCuffed        or false
            playerState.draggedBy       = ps.draggedBy
            playerState.carriedBy       = ps.carriedBy
            playerState.isDead          = ps.isDead          or false
            playerState.dead            = ps.dead            or false
            playerState.cuffType        = ps.cuffType        or "none"
            playerState.mouthTaped      = ps.mouthTaped      or false
            playerState.hasHeadBag      = ps.hasHeadBag      or false
            playerState.hasTrackingBand = ps.hasTrackingBand or false
        end
    end

    -- canAct = not currently dragging OR carrying someone
    local localState = LocalPlayer.state
    local canAct     = not localState.draggingPlayer and not localState.carryingPlayer

    _frameCache = {
        frame  = currentFrame,
        entity = ped,
        id     = serverId or 0,
        s      = playerState,
        canAct = canAct,
    }
    return _frameCache
end

Interactions.resolve = resolvePlayerCache

-- ============================================================
--  Job cache (TTL: 5 s) and item cache (TTL: 30 s)
-- ============================================================

local JOB_CACHE_TTL  = 5000
local ITEM_CACHE_TTL = 30000

local _jobCache  = { value = nil, expires = 0 }
local _itemCache = {}

local function getCachedJob()
    local now = GetGameTimer()
    if _jobCache.value and now < _jobCache.expires then
        return _jobCache.value
    end
    local job = Bridge.Framework.fetchPlayerJob()
    _jobCache.value   = job
    _jobCache.expires = now + JOB_CACHE_TTL
    return job
end

local function invalidateJobCache()
    _jobCache.value   = nil
    _jobCache.expires = 0
end

local function getCachedItemCount(itemName, targetSource)
    -- Safety: if itemName is not a string (e.g. a resolved-player table was passed
    -- in the wrong argument position), return 0 instead of crashing on concatenation.
    if type(itemName) ~= "string" then return 0 end
    local now = GetGameTimer()
    local key = targetSource and (itemName .. "\0" .. tostring(targetSource)) or itemName
    local cached = _itemCache[key]
    if cached and now < cached.expires then return cached.value end

    local count = Bridge.Inventory.getItemCount(itemName, targetSource) or 0
    if _itemCache[key] then
        _itemCache[key].value   = count
        _itemCache[key].expires = now + ITEM_CACHE_TTL
    else
        _itemCache[key] = { value = count, expires = now + ITEM_CACHE_TTL }
    end
    return count
end

local function invalidateItemCache()
    _itemCache = {}
end

Interactions.getJob          = getCachedJob
Interactions.getItemCount    = function(_, itemName, targetSource) return getCachedItemCount(itemName, targetSource) end
Interactions.invalidateJobCache  = invalidateJobCache
Interactions.invalidateItemCache = invalidateItemCache

-- Job/inventory cache invalidation events
for _, eventName in ipairs({
    "esx:setJob", "esx:setJob2",
    "QBCore:Client:OnJobUpdate", "QBCore:Client:SetDuty",
    "qbx_core:client:onJobUpdate",
}) do
    RegisterNetEvent(eventName, invalidateJobCache)
end

for _, eventName in ipairs({
    "QBCore:Client:OnPlayerLoaded", "esx:playerLoaded"
}) do
    RegisterNetEvent(eventName, function()
        invalidateJobCache()
        invalidateItemCache()
    end)
end

for _, eventName in ipairs({
    "esx:addInventoryItem", "esx:removeInventoryItem"
}) do
    RegisterNetEvent(eventName, invalidateItemCache)
end

AddEventHandler("ox_inventory:updateInventory", invalidateItemCache)

-- ============================================================
--  Hands-up check (cached 250ms per entity)
-- ============================================================

local _handsUpCache = { entity = 0, expires = 0, value = false }

local function isHandsUp(resolved)
    if not resolved or not resolved.entity then return false end
    local now = GetGameTimer()
    if _handsUpCache.entity == resolved.entity and now < _handsUpCache.expires then
        return _handsUpCache.value
    end
    local result = IsEntityPlayingAnim(resolved.entity, "random@mugging3", "handsup_standing_base", 3)
    _handsUpCache = { entity = resolved.entity, expires = now + 250, value = result }
    return result
end

Interactions.isHandsUp   = function(resolved) return isHandsUp(resolved) end
Interactions.isTargetDead = function(ped) return ped and Editable.isDead(ped) or false end

-- ============================================================
--  Animation helper
-- ============================================================

local function playAnim(ped, dict, clip, blendIn, blendOut, duration, flag, playbackRate)
    if not dict then return end
    lib.requestAnimDict(dict)
    TaskPlayAnim(ped, dict, clip,
        blendIn    or 8.0,
        blendOut   or -8.0,
        duration   or -1,
        flag       or 49,
        playbackRate or 0,
        false, false, false)
    RemoveAnimDict(dict)
end

-- ============================================================
--  Attach entity to bone helper
-- ============================================================

local function attachToBone(prop, targetPed, attachDef)
    if not attachDef then return end
    AttachEntityToEntity(
        prop, targetPed,
        attachDef.bone or 11816,
        attachDef.offset, attachDef.rotation,
        false, false, false, false,
        attachDef.type or 2,
        attachDef.fixedRot ~= false)
end

-- ============================================================
--  Target setup
-- ============================================================

CreateThread(function()
    LocalPlayer.state:set("cuffType", "none", true)

    local globalOptions  = {}   -- for Bridge.Target.addPlayer
    local vehicleOptions = {}   -- for Bridge.Target.addVehicle

    for targetName, targetDef in pairs(Config.Interactions.Targets) do
        local canInteract = targetDef.canInteract

        local baseOption = {
            name        = targetName,
            label       = targetDef.label,
            icon        = targetDef.icon,
            distance    = targetDef.distance or 2,
            groups      = targetDef.groups or nil,
            items       = targetDef.items or nil,
            canInteract = canInteract,
            onSelect    = function(arg) targetDef.onSelect(arg) end,
        }

        if targetName == "OutFromVehicle" then
            vehicleOptions[#vehicleOptions + 1] = baseOption

        elseif targetName == "StopDragPlayer" then
            -- ox_target uses a global option; other targets use player targeting
            if GetResourceState("ox_target") == "started" then
                -- Remove before adding to prevent "Replacing existing target option" warning
                exports.ox_target:removeGlobalOption("StopDragPlayer")
                local oxOption = {
                    name     = targetName,
                    label    = targetDef.label,
                    icon     = targetDef.icon,
                    distance = targetDef.distance or 2,
                    groups   = targetDef.groups or nil,
                    onSelect = function()
                        local draggingId = LocalPlayer.state.draggingPlayer
                        if draggingId then
                            local ped = GetPlayerPed(GetPlayerFromServerId(draggingId))
                            targetDef.onSelect(ped)
                        end
                    end,
                }
                if canInteract then
                    oxOption.canInteract = function()
                        local draggingId = LocalPlayer.state.draggingPlayer
                        if not draggingId then return false end
                        local ped = GetPlayerPed(GetPlayerFromServerId(draggingId))
                        return canInteract(ped)
                    end
                end
                exports.ox_target:addGlobalOption({ oxOption })
            else
                globalOptions[#globalOptions + 1] = baseOption
            end

        else
            globalOptions[#globalOptions + 1] = baseOption
        end
    end

    Bridge.Target.addPlayer(globalOptions)
    Bridge.Target.addVehicle(vehicleOptions)
end)

-- ============================================================
--  Cuff prop
-- ============================================================

function Interactions.createCuffProp(self, cuffType, isFront)
    local modelCfg = Config.Interactions.Cuffs.Models[cuffType]
    if not modelCfg then return end

    -- Delete existing prop first
    if self.cuffProp and DoesEntityExist(self.cuffProp) then
        DeleteObject(self.cuffProp)
    end

    local spawnCoords = GetEntityCoords(cache.ped)
    local model       = lib.requestModel(modelCfg.model)
    local prop        = CreateObject(model, spawnCoords, true, true, true)

    local netId = self:getNetIdFromEntity(prop)
    SetNetworkIdExistsOnAllMachines(netId, true)
    SetNetworkIdCanMigrate(netId, false)
    NetworkSetNetworkIdDynamic(netId, true)

    local side      = isFront and "front" or "rear"
    local coords    = modelCfg.coords[side]
    local rotation  = modelCfg.rotation[side]
    local boneIndex = GetPedBoneIndex(cache.ped, 60309)  -- SKEL_L_Hand

    AttachEntityToEntity(
        prop, cache.ped, boneIndex,
        coords, rotation,
        true, true, false, true, 1, true)

    SetModelAsNoLongerNeeded(model)
    self.cuffProp = prop
end

function Interactions.destroyCuffProp(self)
    if self.cuffProp and DoesEntityExist(self.cuffProp) then
        DeleteObject(self.cuffProp)
    end
    self.cuffProp = nil
end

-- ============================================================
--  Cuff threads (idle anim + input blocking)
-- ============================================================

function Interactions.startCuffThread(self)
    local idleAnims    = Config.Interactions.Cuffs.Animations.idle
    local hardKeys     = Config.Interactions.DisableKeys.hardcuff
    local softKeys     = Config.Interactions.DisableKeys.cuff

    -- Idle animation maintenance
    CreateThread(function()
        while self.isCuffed do
            Wait(500)
            if not self.isCuffed then break end

            local animCfg = idleAnims[self.cuffSide]
            if animCfg then
                local playing = IsEntityPlayingAnim(cache.ped, animCfg.dict, animCfg.clip, 3)
                if playing ~= 1 then
                    playAnim(cache.ped, animCfg.dict, animCfg.clip,
                        8.0, -8.0, -1, animCfg.flag or 49, 1)
                end
            end
        end
    end)

    -- Input control thread
    CreateThread(function()
        while self.isCuffed do
            Wait(1)
            if self.isHard then
                DisableAllControlActions(0)
                for _, controlId in pairs(hardKeys) do
                    EnableControlAction(0, controlId, true)
                    EnableControlAction(1, controlId, true)
                end
            else
                for _, controlId in pairs(softKeys) do
                    DisableControlAction(0, controlId, true)
                    DisableControlAction(1, controlId, true)
                end
            end
        end
    end)
end

-- ============================================================
--  Rope timer (cable ties auto-escape)
-- ============================================================

function Interactions.clearRopeTimer(self)
    if self.ropeTimer then
        self.ropeTimer:forceEnd(false)
        self.ropeTimer = nil
    end
end

function Interactions.startRopeTimer(self, timerData)
    self:clearRopeTimer()

    CreateThread(function()
        local timer = lib.timer(timerData.time, function()
            self.ropeTimer = nil
            Bridge.Notify.showNotify(locale("cable_ties_came_loose"), "error")

            self.isCuffed = false
            LocalPlayer.state:set("isCuffed",  false,  true)
            LocalPlayer.state:set("cuffType",  "none", true)
            Config.Interactions.OnPlayerUnCuff()
            DetachEntity(cache.ped, true, true)
            self:destroyCuffProp()
            self.isInCuffProcess = false
            Wait(100)
            ClearPedTasks(cache.ped)
        end)
        self.ropeTimer = timer
    end)
end

-- ============================================================
--  Cuff animation handlers (called on the arrested player)
-- ============================================================

function Interactions.handleArrestedCuff(self, data, officerPed, isFront)
    self.isInCuffProcess = true
    local animCfg = Config.Interactions.Cuffs.Animations.cuff.arrested
    local isDead  = self:isPlayerDead(cache.serverId)

    LocalPlayer.state:set("isCuffed", true, true)
    Sounds:playSound("cuff", 0.5)

    local cuffKeys = Config.Interactions.DisableKeys.cuff

    -- Block controls during cuff process
    CreateThread(function()
        while self.isInCuffProcess do
            Wait(1)
            for _, controlId in pairs(cuffKeys) do
                DisableControlAction(0, controlId, true)
                DisableControlAction(1, controlId, true)
            end
        end
    end)

    -- Cable ties rope timer
    if data.type == "cable_ties" and data.timer and data.time then
        self:startRopeTimer({ time = data.time })
    end

    -- Detach if attached
    if IsEntityAttached(cache.ped) then DetachEntity(cache.ped); Wait(10) end
    if IsEntityAttached(officerPed) then DetachEntity(officerPed); Wait(10) end

    -- Choose animation
    local animKey
    if isFront then
        animKey = Config.Interactions.Cuffs.cuffAnimation == "basic" and "frontBasic" or "frontAdvanced"
    elseif isDead then
        animKey = animCfg.rearDead or "rearDead"
    else
        animKey = "rearAlive"
    end
    local anim = animCfg[animKey]

    if isDead then ClearPedTasks(cache.ped) end
    attachToBone(cache.ped, officerPed, anim and anim.attach)

    if anim and anim.dict then
        playAnim(cache.ped, anim.dict, anim.clip,
            8.0, -8.0, anim.duration or 5000, anim.flag or 33, 0)
    end

    FreezeEntityPosition(cache.ped, true)

    -- Run cuffGame check if alive
    if not isDead then
        local minigameResult = Config.Interactions.Cuffs.cuffGame(data.isHard, data.type)
        if minigameResult then
            LocalPlayer.state:set("isCuffed", false, true)
            DetachEntity(cache.ped)
            ClearPedTasksImmediately(cache.ped)
            FreezeEntityPosition(cache.ped, false)
            self.isInCuffProcess = false
            return
        end
    end

    -- After 950ms: finalise cuff state
    SetTimeout(950, function()
        self.cuffSide = isFront and "front" or "rear"
        DetachEntity(cache.ped)
        FreezeEntityPosition(cache.ped, false)
        LocalPlayer.state:set("isCuffed",  true,      true)
        LocalPlayer.state:set("cuffType",  data.type, true)
        self.isCuffed = true

        -- Wait for anim to finish before spawning prop
        local waitTime = isDead and 4500 or (isFront and 1000 or 3000)
        Wait(waitTime)

        self:createCuffProp(data.type, isFront)
        Config.Interactions.OnPlayerCuff()
        self:startCuffThread()
        self.isInCuffProcess = false
    end)
end

function Interactions.handleArrestedUncuff(self, data, officerPed, isFront)
    self.isInCuffProcess = true
    local animCfg = Config.Interactions.Cuffs.Animations.uncuff.arrested
    local isDead  = self:isPlayerDead(cache.serverId)

    self:clearRopeTimer()
    self.isCuffed = false
    Wait(100)

    if isDead then
        local delay = (animCfg.deadDuration or 3000)
        SetTimeout(delay, function()
            DetachEntity(cache.ped)
            LocalPlayer.state:set("isCuffed", false, true)
            Config.Interactions.OnPlayerUnCuff()
            self:destroyCuffProp()
            self.isInCuffProcess = false
            Wait(500)
            ClearPedTasks(cache.ped)
        end)
        return
    end

    local animSide = isFront and animCfg.front or animCfg.rear
    attachToBone(cache.ped, officerPed, animSide and animSide.attach)
    Sounds:playSound("uncuff", 0.5)

    if animSide and animSide.dict then
        playAnim(cache.ped, animSide.dict, animSide.clip,
            8.0, -8.0, animSide.duration or 6000, animSide.flag or 33, 0)
    end

    local delay = (animSide and animSide.duration or 4500)
    SetTimeout(delay, function()
        DetachEntity(cache.ped)
        LocalPlayer.state:set("isCuffed", false, true)
        Config.Interactions.OnPlayerUnCuff()
        self:destroyCuffProp()
        self.isInCuffProcess = false
        Wait(1500)
        ClearPedTasks(cache.ped)
    end)
end

-- ============================================================
--  Cuff animation handlers (called on the officer)
-- ============================================================

function Interactions.handleOfficerCuff(self, data, targetPed, isFront)
    self.isInCuffProcess = true
    local animCfg = Config.Interactions.Cuffs.Animations.cuff.officer
    local isDead  = self:isPlayerDead(data.player)

    if IsEntityAttached(cache.ped) then DetachEntity(cache.ped); Wait(10) end
    if IsEntityAttached(targetPed) then DetachEntity(targetPed); Wait(10) end
    Wait(400)

    local anim
    if isDead then
        anim = animCfg.rearDead
    elseif isFront then
        anim = animCfg.frontAlive
    else
        anim = animCfg.rearAlive
    end

    Sounds:playSound("cuff", 0.5)

    if anim and anim.dict then
        playAnim(cache.ped, anim.dict, anim.clip,
            8.0, -8.0, anim.duration or 4500, anim.flag or 33, 0)
    end

    local delay = ((anim and anim.duration) or 4500) + 100
    SetTimeout(delay, function()
        self.isInCuffProcess = false
    end)
end

function Interactions.handleOfficerUncuff(self, data, targetPed)
    self.isInCuffProcess = true
    local animCfg = Config.Interactions.Cuffs.Animations.uncuff.officer
    local isDead  = self:isPlayerDead(data.player)

    local anim = isDead and animCfg.dead or animCfg.alive
    Wait(150)
    Sounds:playSound("uncuff", 0.5)

    if anim and anim.dict then
        playAnim(cache.ped, anim.dict, anim.clip,
            8.0, -8.0, anim.duration or 6000, anim.flag or 33, 0)
    end

    local delay = ((anim and anim.duration) or 6000) + 100
    SetTimeout(delay, function()
        self.isInCuffProcess = false
    end)
end

-- ============================================================
--  HandCuffsAnimation net event (dispatches to correct handler)
-- ============================================================

RegisterNetEvent("p_policejob/client/interactions/HandCuffsAnimation", function(data)
    if type(data) ~= "table" or not data.player or data.player < 1 then return end

    if data.isArrested then
        RemoveAllPedWeapons(cache.ped, true)
    end

    Wait(1)
    Interactions.isHard = data.isHard

    local officerPed = GetPlayerPed(GetPlayerFromServerId(data.player))
    if not officerPed or officerPed == 0 or officerPed == cache.ped then return end

    -- Determine if front-cuffed (explicit flag OR already playing front idle anim)
    local idleAnims = Config.Interactions.Cuffs.Animations.idle
    local isFront   = data.front
    if not isFront then
        local checkPed = data.isArrested and cache.ped or officerPed
        isFront = IsEntityPlayingAnim(checkPed, idleAnims.front.dict, idleAnims.front.clip, 3)
    end

    -- For officers, "basic" cuff mode always treats as front
    if data.isCuff and not data.isArrested then
        if Config.Interactions.Cuffs.cuffAnimation == "basic" then
            isFront = true
        end
    end

    if data.isArrested then
        if data.isCuff then
            Interactions:handleArrestedCuff(data, officerPed, isFront)
        else
            Interactions:handleArrestedUncuff(data, officerPed, isFront)
        end
    else
        if data.isCuff then
            Interactions:handleOfficerCuff(data, officerPed, isFront)
        else
            Interactions:handleOfficerUncuff(data, officerPed)
        end
    end
end)

-- ============================================================
--  Force cuff / uncuff net events
-- ============================================================

RegisterNetEvent("p_policejob/client/interactions/ForceUncuff", function()
    Wait(100)
    if LocalPlayer.state.isCuffed then return end  -- server already cleared it

    Interactions.isCuffed = false
    Interactions:clearRopeTimer()
    Config.Interactions.OnPlayerUnCuff()
    DetachEntity(cache.ped, true, true)
    Interactions:destroyCuffProp()
    Interactions.isInCuffProcess = false
    Wait(100)
    ClearPedTasks(cache.ped)
end)

RegisterNetEvent("p_policejob/client/interactions/ForceCuff", function()
    Interactions.cuffSide = "rear"
    DetachEntity(cache.ped)
    FreezeEntityPosition(cache.ped, false)
    Interactions.isCuffed = true
    Interactions:createCuffProp("cuffs", false)
    Config.Interactions.OnPlayerCuff()
    Interactions:startCuffThread()
    Interactions.isInCuffProcess = false
end)

-- ============================================================
--  Ragdoll prevention while cuffed (damage event)
-- ============================================================

AddEventHandler("gameEventTriggered", function(eventName, args)
    if eventName ~= "CEventNetworkEntityDamage" then return end

    local damagedPed = args[1]
    if not IsPedAPlayer(damagedPed) then return end
    if NetworkGetPlayerIndexFromPed(damagedPed) ~= cache.playerId then return end
    if not LocalPlayer.state.isCuffed then return end

    ClearPedTasks(cache.ped)
    Wait(100)
    while IsPedRagdoll(cache.ped) do
        Wait(250)
    end
    ClearPedTasks(cache.ped)
end)

-- ============================================================
--  Drag / Escort
-- ============================================================

RegisterNetEvent("p_policejob/client/interactions/StartDrag", function(data)
    if not data.state then
        Interactions.dragStatus.draggingPlayer = nil
        Interactions.dragStatus.draggedBy      = nil
        Wait(100)
        ClearPedTasks(cache.ped)
        return
    end

    if data.isDragging then
        -- This player is the one doing the dragging
        Interactions.dragStatus.draggingPlayer = data.player
        local dragAnimCfg = Config.Interactions.Drag.animation

        -- Maintain drag animation
        CreateThread(function()
            while Interactions.dragStatus.draggingPlayer do
                Wait(1000)
                if not Interactions.dragStatus.draggingPlayer then break end

                local playing = IsEntityPlayingAnim(cache.ped, dragAnimCfg.dict, dragAnimCfg.clip, 3)
                if playing ~= 1 then
                    playAnim(cache.ped, dragAnimCfg.dict, dragAnimCfg.clip,
                        -8.0, -8.0, -1, dragAnimCfg.flag or 49, 0)
                end

                -- Check if target is still valid
                local draggedPed = GetPlayerPed(GetPlayerFromServerId(Interactions.dragStatus.draggingPlayer))
                if not DoesEntityExist(draggedPed) or draggedPed == cache.ped then
                    ClearPedTasks(cache.ped)
                    LocalPlayer.state:set("draggingPlayer", false, true)
                    Interactions.dragStatus.draggingPlayer = nil
                    DetachEntity(cache.ped, true, true)
                    Config.Interactions.OnStopPlayerDrag()
                end
            end
        end)

        -- Input control + TextUI + cancel key listener
        CreateThread(function()
            Wait(1500)
            local usingOxTarget = GetResourceState("ox_target") == "started"
            if not usingOxTarget then
                lib.showTextUI(locale("stop_drag_textui"))
            end

            while LocalPlayer.state.draggingPlayer do
                Wait(1)
                SetPlayerMayNotEnterAnyVehicle(cache.playerId)
                for _, controlId in pairs(Config.Interactions.DisableKeys.drag) do
                    DisableControlAction(0, controlId, true)
                end

                if not usingOxTarget then
                    local cancelKey = Config.Interactions.Drag.cancelKey
                    if IsControlJustReleased(0, cancelKey) or IsDisabledControlJustReleased(0, cancelKey) then
                        TriggerServerEvent("p_policejob/server/interactions/DragPlayer", {
                            state  = false,
                            player = LocalPlayer.state.draggingPlayer,
                        })
                        break
                    end
                end
            end

            if not usingOxTarget then lib.hideTextUI() end
        end)

    else
        -- This player is being dragged
        Interactions.dragStatus.draggedBy = data.player
        Config.Interactions.OnStartPlayerDrag()
        Interactions:startDragThread()
    end
end)

function Interactions.startDragThread(self)
    local isAttached = false

    -- Attachment maintenance thread
    CreateThread(function()
        while true do
            local draggedBy = self.dragStatus.draggedBy
            if not draggedBy then
                if isAttached then
                    DetachEntity(cache.ped, true, true)
                    isAttached = false
                    self.dragStatus.draggedBy = nil
                    Config.Interactions.OnStopPlayerDrag()
                end
                break
            end

            local draggerPed = GetPlayerPed(GetPlayerFromServerId(draggedBy))
            local waitMs     = 1000

            -- Stop dragging if not cuffed and not dead (and not applicable condition)
            local isCuffedOrDead = self.isCuffed or self:isPlayerDead(cache.serverId)
            if not isCuffedOrDead then
                if isAttached then
                    DetachEntity(cache.ped, true, true)
                    isAttached = false
                    self.dragStatus.draggedBy = nil
                    Config.Interactions.OnStopPlayerDrag()
                end
                break
            end

            if DoesEntityExist(draggerPed) then
                if not isAttached then
                    AttachEntityToEntity(
                        cache.ped, draggerPed, 1816,
                        0.15, 0.42, 0.0, 0.0, 0.0, 0.0,
                        false, false, false, false, 2, true)
                    isAttached = true
                else
                    waitMs = 750
                end
            else
                if isAttached then
                    DetachEntity(cache.ped, true, true)
                    isAttached = false
                end
                self.dragStatus.draggedBy = nil
                Config.Interactions.OnStopPlayerDrag()
                break
            end

            Wait(waitMs)
        end
    end)

    -- Walking animation when dragger is moving
    CreateThread(function()
        local draggerPed = GetPlayerPed(GetPlayerFromServerId(self.dragStatus.draggedBy))
        while self.dragStatus.draggedBy do
            Wait(100)
            if not DoesEntityExist(draggerPed) then
                self.dragStatus.draggedBy = nil
                break
            end

            if GetEntitySpeed(draggerPed) > 1 and not self:isPlayerDead(cache.serverId) then
                local walkDict = "move_m@generic_variations@walk"
                if IsEntityPlayingAnim(cache.ped, walkDict, "walk_b", 3) ~= 1 then
                    playAnim(cache.ped, walkDict, "walk_b", 8.0, -8.0, -1, 0, 1)
                end
            end
        end
    end)
end

function Interactions.quickEscort(self, targetSource)
    if cache.vehicle and cache.vehicle ~= 0 then
        Bridge.Notify.showNotify(locale("you_cant_do_it"), "error")
        return
    end

    -- Stop current drag if we are dragging
    local dragging = LocalPlayer.state.draggingPlayer
    if dragging then
        TriggerServerEvent("p_policejob/server/interactions/DragPlayer", {
            state = false, player = dragging
        })
        return
    end

    -- Use provided target or find closest
    if not targetSource then
        local closestPlayer = lib.getClosestPlayer(GetEntityCoords(cache.ped), 5.0, false)
        if not closestPlayer or closestPlayer == 0 then return end
        targetSource = GetPlayerServerId(closestPlayer)
    end

    TriggerServerEvent("p_policejob/server/interactions/DragPlayer", {
        state = true, player = targetSource
    })
end

RegisterCommand("escort", function()
    Interactions:quickEscort()
end, false)

-- ============================================================
--  Vehicle interactions
-- ============================================================

RegisterNetEvent("p_policejob/client/interactions/TakeOutVehicle", function()
    if not IsPedSittingInAnyVehicle(cache.ped) then return end
    local vehicle = GetVehiclePedIsIn(cache.ped, false)
    TaskLeaveVehicle(cache.ped, vehicle, 16)
    Wait(1000)
    ClearPedTasksImmediately(cache.ped)
end)

RegisterNetEvent("p_policejob/client/interactions/PutInVehicle", function(data)
    if IsPedSittingInAnyVehicle(cache.ped) then return end

    local vehicle = lib.getClosestVehicle(GetEntityCoords(cache.ped), 5.0, false)
    if not vehicle or not IsVehicleSeatFree(vehicle, data.seat) then return end

    if Interactions:isPlayerDead(cache.serverId) then
        SetPedIntoVehicle(cache.ped, vehicle, data.seat)
    else
        TaskWarpPedIntoVehicle(cache.ped, vehicle, data.seat)
    end

    Interactions.dragStatus.draggedBy = nil
    LocalPlayer.state:set("draggedBy", false, true)
    Player(data.player).state:set("draggingPlayer", false, true)
end)

-- ============================================================
--  Search player
-- ============================================================

function Interactions.searchPlayer(self, targetPed, targetSource)
    local searchCfg = Config.Interactions.Search

    local completed = Bridge.Progress.Start({
        duration     = searchCfg.duration,
        label        = locale("searching_player"),
        useWhileDead = false,
        canCancel    = true,
        disable      = { car = true, move = true, combat = true },
        anim         = { dict = searchCfg.animation.dict, clip = searchCfg.animation.clip },
    })

    if not completed then return end

    -- Verify target is still searchable
    local targetState    = Player(targetSource).state
    local isSearchable   = targetState.isCuffed
        or IsEntityPlayingAnim(targetPed, "random@mugging3", "handsup_standing_base", 3)
        or self:isPlayerDead(targetSource)

    if isSearchable then
        Bridge.Inventory.openInventory("player", targetSource)
    end
end

-- ============================================================
--  Lockpick cuffs (client callback)
-- ============================================================

lib.callback.register("p_policejob/client/interactions/attemptOpenCuffs", function()
    local lockpickCfg = Config.Interactions.LockpickCuffs
    if lockpickCfg.animation.enabled then
        playAnim(cache.ped,
            lockpickCfg.animation.dict, lockpickCfg.animation.clip,
            -8.0, 8.0, -1, lockpickCfg.animation.flag or 49, 1)
    end
    local success = lockpickCfg.miniGame()
    ClearPedTasks(cache.ped)
    return success
end)

-- ============================================================
--  Gunpowder tracking
-- ============================================================

local lastShotTime = 0

AddEventHandler("CEventGunShot", function()
    local ped = cache.ped or PlayerPedId()
    if IsPedShooting(ped) then
        lastShotTime = GetGameTimer()
    end
end)

-- Clear shot record if player enters water (washes off powder)
Citizen.CreateThread(function()
    while true do
        Wait(2500)
        if lastShotTime ~= 0 then
            if IsPedSwimming(cache.ped) or IsEntityInWater(cache.ped) then
                lastShotTime = 0
            end
        end
    end
end)

lib.callback.register("p_policejob/client/evidence/checkGunPowder", function()
    if lastShotTime == 0 then return false end
    local windowMs = (Config.Interactions.GunPowder and Config.Interactions.GunPowder.WindowMs) or 300000
    return GetGameTimer() - lastShotTime <= windowMs
end)

-- ============================================================
--  Head bag
-- ============================================================

function Interactions.createHeadBag(self)
    local bagCfg  = Config.Interactions.HeadBag
    local model   = lib.requestModel(bagCfg.model)
    local coords  = GetEntityCoords(cache.ped)
    local prop    = CreateObject(model, coords, true, true, true)

    local boneIndex = GetPedBoneIndex(cache.ped, bagCfg.bone)
    AttachEntityToEntity(prop, cache.ped, boneIndex,
        bagCfg.coords, bagCfg.rotation,
        true, true, false, true, 1, true)

    SetEntityCompletelyDisableCollision(prop, false, true)
    SetModelAsNoLongerNeeded(model)
    self.headBagData.object = prop
end

RegisterNetEvent("p_policejob/client/interactions/ToggleHeadBag", function(state)
    Interactions.headBagData.state = state
    Wait(10)

    local obj = Interactions.headBagData.object
    if obj and DoesEntityExist(obj) then DeleteEntity(obj) end

    SendNUIMessage({ action = "setVisibleHeadBag", data = state })

    if state then Interactions:createHeadBag() end
end)

-- Periodic head bag prop repair (respawns it if deleted while state is active)
CreateThread(function()
    while true do
        Wait(3000)
        if Interactions.headBagData.state then
            local obj = Interactions.headBagData.object
            if obj and not DoesEntityExist(obj) then
                Interactions:createHeadBag()
            end
        end
    end
end)

-- ============================================================
--  Mouth tape (mouthTaped state bag — handled here for prop + voice)
--  Note: The dedicated mouthtape_client.lua handles this too.
--  This duplicate handler in interactions/client.lua exists in the original
--  and is preserved to avoid breaking the load order.
-- ============================================================

AddStateBagChangeHandler("mouthTaped", nil, function(bagName, _, newValue, _, wasDeleted)
    if wasDeleted then return end

    local playerHandle = GetPlayerFromStateBagName(bagName)
    if playerHandle == 0 then return end

    local ped        = GetPlayerPed(playerHandle)
    local identifier = GetPlayerServerId(playerHandle)

    if not newValue then
        local prop = Interactions.mouthTapes[identifier]
        if prop and DoesEntityExist(prop) then
            DeleteEntity(prop)
            Interactions.mouthTapes[identifier] = nil
        end
        if cache.serverId == identifier then
            Interactions._mouthTapeActive = false
        end
        return
    end

    Wait(1)
    local tapeCfg = Config.Interactions.MouthTape
    local model   = lib.requestModel(tapeCfg.model)
    local prop    = CreateObject(model, GetEntityCoords(ped), false, false, false)

    local boneIndex = GetPedBoneIndex(ped, tapeCfg.bone)
    AttachEntityToEntity(prop, ped, boneIndex,
        tapeCfg.coords, tapeCfg.rotation,
        true, true, false, true, 1, true)

    SetEntityAsMissionEntity(prop, true, true)
    SetModelAsNoLongerNeeded(model)
    SetEntityCollision(prop, true, false)
    Interactions.mouthTapes[identifier] = prop

    if cache.serverId == identifier and not Interactions._mouthTapeActive then
        Interactions._mouthTapeActive = true
        CreateThread(function()
            while Interactions._mouthTapeActive do
                Wait(1000)
                if GetResourceState("pma-voice") == "started" then
                    exports["pma-voice"]:overrideProximityCheck(function() return false end)
                elseif GetResourceState("yaca-voice") == "started" then
                    exports["yaca-voice"]:setMaxVoiceRange(0.0)
                end
            end
            Wait(1000)
            if GetResourceState("pma-voice") == "started" then
                exports["pma-voice"]:resetProximityCheck()
            elseif GetResourceState("yaca-voice") == "started" then
                exports["yaca-voice"]:setMaxVoiceRange(-1)
            end
        end)
    end
end)

-- ============================================================
--  Carry
-- ============================================================

local function playCarryAnim()
    local role    = Interactions.carryData.role
    local animCfg = Config.Interactions.Carry.animation[role]
    if animCfg then
        playAnim(cache.ped, animCfg.dict, animCfg.clip, 8.0, -8.0, -1, animCfg.flag, 0)
    end
end

local function stopCarry()
    local carryData = Interactions.carryData
    if not carryData.isActive then return end
    carryData.isActive  = false
    carryData.playerId  = nil
    carryData.playerPed = nil
    Wait(1)
    ClearPedSecondaryTask(cache.ped)
    DetachEntity(cache.ped, true, false)
end

RegisterNetEvent("p_policejob/client/interactions/StopCarryPlayer", stopCarry)

RegisterNetEvent("p_policejob/client/interactions/StartCarryPlayer", function(data)
    local carryData = Interactions.carryData
    if carryData.isActive then return end

    carryData.isActive  = true
    carryData.playerId  = data.playerId
    carryData.playerPed = GetPlayerPed(GetPlayerFromServerId(data.playerId))

    if data.isCarrying then
        carryData.role = "carrying"
        Wait(1)
        playCarryAnim()
    else
        carryData.role = "carried"
        Wait(1)
        playCarryAnim()

        local carriedAnimCfg = Config.Interactions.Carry.animation.carried
        AttachEntityToEntity(
            cache.ped, carryData.playerPed, 0,
            carriedAnimCfg.offset.coords, carriedAnimCfg.offset.rotation,
            false, false, false, false, 2, false)
    end

    -- Monitor loop: re-plays anim and stops if partner disconnects
    CreateThread(function()
        while carryData.isActive do
            Wait(100)
            if not carryData.isActive then break end

            local animCfg = Config.Interactions.Carry.animation[carryData.role]
            if animCfg then
                if not IsEntityPlayingAnim(cache.ped, animCfg.dict, animCfg.clip, 3) then
                    playCarryAnim()
                end
            end

            local partnerPed = GetPlayerPed(GetPlayerFromServerId(carryData.playerId))
            if not (partnerPed and partnerPed ~= 0 and DoesEntityExist(partnerPed) and partnerPed ~= cache.ped) then
                stopCarry()
            end
        end
    end)
end)

-- Stop carry keybind
CreateThread(function()
    local stopKey = Config.Interactions.Carry.stopCarryKey
    if not stopKey then return end

    lib.addKeybind({
        name        = "policejob:stopcarry",
        description = locale("stop_carry_player_bind"),
        defaultKey  = stopKey,
        onPressed   = function()
            local carryData = Interactions.carryData
            if carryData.isActive and carryData.role == "carrying" then
                TriggerServerEvent("p_policejob/server/interactions/StopCarryPlayer", carryData.playerId)
            end
        end,
    })
end)

-- Carry consent callback
lib.callback.register("p_policejob/client/interactions/RequestCarryPlayer", function(officerSource)
    local carryData = Interactions.carryData
    if carryData.isActive then return false end
    return Config.Interactions.Carry.onRequest(officerSource)
end)

-- ============================================================
--  Item-use: handcuffs
-- ============================================================

exports("handcuffs", function(_, itemData)
    if not Config.Interactions.Cuffs.usableItem then return end
    if cache.vehicle and cache.vehicle ~= 0 then return end

    local closestPlayer, closestPed = lib.getClosestPlayer(GetEntityCoords(cache.ped), 3.0, false)
    if not closestPlayer or closestPlayer == 0 then return end
    if IsPedSittingInAnyVehicle(closestPed) then return end

    local targetServerId = GetPlayerServerId(closestPlayer)
    local action = Config.Interactions.Cuffs.cuffItemCheck(closestPed, targetServerId)
    if not action then return end

    if action == "cuff" then
        local isFront = Interactions:isInFront(closestPed)
        TriggerServerEvent("p_policejob/server/interactions/HandCuffs", {
            type   = "cuffs",
            state  = true,
            player = targetServerId,
            front  = isFront,
        })
    else
        TriggerServerEvent("p_policejob/server/interactions/HandCuffs", {
            type   = "cuffs",
            state  = false,
            player = targetServerId,
        })
    end
end)

RegisterNetEvent("p_policejob/useHandcuffs", function()
    exports.p_policejob:handcuffs()
end)

-- ============================================================
--  Cuff shortcut net events (hard, soft, cable-ties)
-- ============================================================

local function getClosestForCuff(range)
    if cache.vehicle and cache.vehicle ~= 0 then return nil, nil end
    local closestPlayer, closestPed = lib.getClosestPlayer(GetEntityCoords(cache.ped), range or 3.0, false)
    if not closestPlayer or closestPlayer == 0 then return nil, nil end
    return GetPlayerServerId(closestPlayer), closestPed
end

RegisterNetEvent("p_policejob/hardCuff", function()
    local targetId, targetPed = getClosestForCuff(3.0)
    if not targetId then return end
    local isFront = Interactions:isInFront(targetPed)
    TriggerServerEvent("p_policejob/server/interactions/HandCuffs", {
        type   = "cuffs",
        state  = not Player(targetId).state.isCuffed,
        player = targetId,
        front  = isFront,
        isHard = true,
    })
end)

RegisterNetEvent("p_policejob/softCuff", function()
    local targetId, targetPed = getClosestForCuff(3.0)
    if not targetId then return end
    if LocalPlayer.state.draggingPlayer or LocalPlayer.state.carryingPlayer then return end
    local isFront = Interactions:isInFront(targetPed)
    TriggerServerEvent("p_policejob/server/interactions/HandCuffs", {
        type   = "cuffs",
        state  = not Player(targetId).state.isCuffed,
        player = targetId,
        front  = isFront,
        isHard = false,
    })
end)

RegisterNetEvent("p_policejob/tiePlayer", function()
    local targetId, targetPed = getClosestForCuff(3.0)
    if not targetId then return end
    local isFront = Interactions:isInFront(targetPed)
    TriggerServerEvent("p_policejob/server/interactions/HandCuffs", {
        type   = "cable_ties",
        state  = not Player(targetId).state.isCuffed,
        player = targetId,
        timer  = true,
        time   = Config.Interactions.Cuffs.cableTieTimer,
        front  = isFront,
    })
end)

RegisterNetEvent("p_policejob/searchPlayer", function()
    if cache.vehicle and cache.vehicle ~= 0 then return end
    local closestPlayer, closestPed = lib.getClosestPlayer(GetEntityCoords(cache.ped), 5.0, false)
    if not closestPlayer or closestPlayer == 0 then return end
    local targetId = GetPlayerServerId(closestPlayer)
    Interactions:searchPlayer(closestPed, targetId)
end)

RegisterNetEvent("p_policejob/escortPlayer", function()
    if cache.vehicle and cache.vehicle ~= 0 then return end

    local dragging = LocalPlayer.state.draggingPlayer
    if dragging and type(dragging) == "number" then
        TriggerServerEvent("p_policejob/server/interactions/DragPlayer", {
            state = false, player = dragging
        })
        return
    end

    local closestPlayer = lib.getClosestPlayer(GetEntityCoords(cache.ped), 3.0, false)
    if not closestPlayer or closestPlayer == 0 then return end
    TriggerServerEvent("p_policejob/server/interactions/DragPlayer", {
        state = true, player = GetPlayerServerId(closestPlayer)
    })
end)

-- ============================================================
--  Legacy compat shims
-- ============================================================

for _, eventName in ipairs({ "esx_policejob:handcuff", "police:client:CuffPlayer" }) do
    RegisterNetEvent(eventName, function() TriggerEvent("p_policejob/softCuff") end)
end

for _, eventName in ipairs({ "esx_policejob:search", "police:client:SearchPlayer", "police:client:RobPlayer" }) do
    RegisterNetEvent(eventName, function() TriggerEvent("p_policejob/searchPlayer") end)
end

for _, eventName in ipairs({ "esx_policejob:drag", "esx_policejob:escort", "police:client:EscortPlayer" }) do
    RegisterNetEvent(eventName, function() TriggerEvent("p_policejob/escortPlayer") end)
end

for _, eventName in ipairs({ "esx_policejob:putInVehicle", "police:client:PutInVehicle" }) do
    RegisterNetEvent(eventName, function()
        if cache.vehicle and cache.vehicle ~= 0 then return end
        local closestPlayer = lib.getClosestPlayer(GetEntityCoords(cache.ped), 3.0, false)
        if not closestPlayer or closestPlayer == 0 then return end
        local targetId = GetPlayerServerId(closestPlayer)
        TriggerServerEvent("p_policejob/server/interactions/PutInVehicle", {
            seat = -1, player = targetId
        })
    end)
end

RegisterNetEvent("police:client:GetCuffed", function()
    TriggerServerEvent("p_policejob/server/interactions/compatSelfCuff", {
        state = not LocalPlayer.state.isCuffed
    })
end)

RegisterNetEvent("esx_policejob:unrestrain", function()
    if not LocalPlayer.state.isCuffed then return end
    TriggerServerEvent("p_policejob/server/interactions/compatSelfCuff", { state = false })
end)

RegisterNetEvent("police:client:GetEscorted", function(officerSource)
    officerSource = tonumber(officerSource)
    if not officerSource then return end
    TriggerServerEvent("p_policejob/server/interactions/compatEscortRequest", officerSource)
end)

for _, eventName in ipairs({ "esx_policejob:OutVehicle", "police:client:SetOutVehicle" }) do
    RegisterNetEvent(eventName, function()
        if cache.vehicle and cache.vehicle ~= 0 then return end
        local vehicle = lib.getClosestVehicle(GetEntityCoords(cache.ped), 5.0, false)
        if not vehicle or vehicle == 0 then return end

        for seat = -1, 6 do
            local seatPed = GetPedInVehicleSeat(vehicle, seat)
            if seatPed and seatPed ~= 0 then
                local seatPlayerId = NetworkGetPlayerIndexFromPed(seatPed)
                local seatServerId = GetPlayerServerId(seatPlayerId)
                if seatServerId ~= 0 then
                    TriggerServerEvent("p_policejob/server/interactions/OutVehicle", {
                        seat = seat, player = seatServerId
                    })
                    return
                end
            end
        end
    end)
end

-- ============================================================
--  Police action menu (optional — enabled via Config)
-- ============================================================

if Config.Interactions.PoliceMenu.enabled then
    local function openPoliceMenu()
        local job = Bridge.Framework.fetchPlayerJob()
        if not job or not Config.Jobs[job.name] then return end

        local myCoords      = GetEntityCoords(cache.ped)
        local closestPlayer, closestPed = lib.getClosestPlayer(myCoords, 4.0, false)
        local closestVehicle = lib.getClosestVehicle(myCoords, 5.0, false)
        local menuOptions    = {}

        for targetName, targetDef in pairs(Config.Interactions.Targets) do
            if targetName == "PutInVehicle" then
                if closestVehicle and closestVehicle ~= 0 then
                    for seat = -1, 6 do
                        if IsVehicleSeatFree(closestVehicle, seat) then
                            local seatLabel = SEAT_LABELS[tostring(seat)] or locale("addon_seat")
                            menuOptions[#menuOptions + 1] = {
                                label = targetDef.label:format(seatLabel),
                                args  = { name = targetName, seat = seat },
                                close = false,
                            }
                        end
                    end
                end

            elseif targetName == "OutFromVehicle" then
                if closestVehicle and closestVehicle ~= 0 then
                    local canUse = not targetDef.canInteract or targetDef.canInteract(closestVehicle)
                    if canUse then
                        menuOptions[#menuOptions + 1] = {
                            label = targetDef.label,
                            args  = { name = targetName },
                            close = true,
                        }
                    end
                end

            else
                menuOptions[#menuOptions + 1] = {
                    label = targetDef.label,
                    args  = { name = targetName },
                    close = false,
                }
            end
        end

        lib.registerMenu({
            id      = "police_menu",
            title   = locale("police_menu"),
            options = menuOptions,
        }, function(_, _, selected)
            if Interactions.isInCuffProcess then return end

            local targetDef = Config.Interactions.Targets[selected.name]
            if not targetDef then return end

            local targetArg
            if selected.name == "OutFromVehicle" then
                targetArg = lib.getClosestVehicle(GetEntityCoords(cache.ped), 4.0, false)
                if not targetArg or targetArg == 0 then
                    Bridge.Notify.showNotify(locale("you_cant_do_it"), "error")
                    return
                end
            else
                _, targetArg = lib.getClosestPlayer(GetEntityCoords(cache.ped), 4.0, false)
                if not targetArg or targetArg == 0 then
                    Bridge.Notify.showNotify(locale("no_players_nearby"), "error")
                    return
                end
            end

            if targetDef.canInteract then
                if not targetDef.canInteract(targetArg, selected.seat or nil) then
                    Bridge.Notify.showNotify(locale("you_cant_do_it"), "error")
                    return
                end
            end

            targetDef.onSelect(targetArg, selected.seat or nil)
        end)

        lib.showMenu("police_menu")
    end

    RegisterCommand(Config.Interactions.PoliceMenu.command, openPoliceMenu)
    RegisterKeyMapping(
        Config.Interactions.PoliceMenu.command,
        locale("police_menu"),
        "keyboard",
        Config.Interactions.PoliceMenu.key)
end
