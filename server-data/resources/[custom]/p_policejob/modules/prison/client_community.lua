if not (Config and Config.Prison and Config.Prison.Enabled) then return end
if not (Config.Prison.CommunityService and Config.Prison.CommunityService.enabled) then return end

local csCfg = Config.Prison.CommunityService

-- ─── Module State ────────────────────────────────────────────────────────────

local activeSentenceData  = nil    -- current sentenceData while in CS
local currentLocation     = nil    -- selected CS location data table
-- Session counter: incremented on each enter/leave; used by SetTimeout callbacks
-- to detect if they belong to the current session before acting
local sessionId           = 0
local trashPoolCoords     = {}     -- [poolIndex] = vec3
local poolSpawnCounts     = {}     -- [poolIndex] = spawnCount (nil = free)
local activePiles         = {}     -- [spawnCount] = { prop, zoneId, blip, poolIndex, coords }
local globalSpawnCounter  = 0     -- monotonic counter for unique spawn IDs
local dumpsterData        = nil    -- { coords, prop, blip, zoneId }
local locationBlip        = nil
local carriedBag          = nil    -- { bag = entity } when holding a bag
local minigameResolver    = nil    -- promise resolve function for the trash minigame

-- ─── Internal Helpers ────────────────────────────────────────────────────────

-- Returns a random pool index that has no active spawn, or nil if all occupied
local function GetFreePoolIndex()
    local free = {}
    for i = 1, #trashPoolCoords do
        if not poolSpawnCounts[i] then
            free[#free + 1] = i
        end
    end
    if #free == 0 then return nil end
    return free[math.random(#free)]
end

-- Removes a sphere zone (pcall to suppress errors on resource stop)
local function RemoveSphereZone(zone)
    if not zone then return end
    if Bridge.Target and Bridge.Target.removeSphereZone then
        pcall(Bridge.Target.removeSphereZone, zone)
    end
end

-- Deletes an entity if it exists
local function SafeDeleteEntity(entity)
    if entity and DoesEntityExist(entity) then
        DeleteEntity(entity)
    end
end

-- Spawns a frozen prop at ground level at the given coords; returns entity or nil
local function SpawnFrozenPropAtGround(model, coords)
    local modelHash = type(model) == "number" and model or joaat(model)
    lib.requestModel(modelHash, 5000)
    if not HasModelLoaded(modelHash) then return nil end

    local foundGround, groundZ = GetGroundZFor_3dCoord(coords.x, coords.y, coords.z + 1.0, false)
    local spawnZ = (foundGround and groundZ) or coords.z

    local entity = CreateObject(modelHash, coords.x, coords.y, spawnZ, false, false, false)
    PlaceObjectOnGroundProperly(entity)

    if coords.w then SetEntityHeading(entity, coords.w) end
    FreezeEntityPosition(entity, true)
    SetModelAsNoLongerNeeded(modelHash)

    return entity
end

-- Fade-teleport to coords
local function FadeTeleport(coords)
    DoScreenFadeOut(400)
    Wait(400)
    SetEntityCoords(cache.ped, coords.x, coords.y, coords.z, false, false, false, true)
    if coords.w then SetEntityHeading(cache.ped, coords.w) end
    Wait(300)
    DoScreenFadeIn(400)
end

-- Shows the trash-pickup minigame NUI and returns a promise that resolves when done
local function ShowTrashMinigame()
    local p = promise.new()

    minigameResolver = function(success)
        if p then
            local res = p
            p = nil
            res:resolve(success == true)
        end
    end

    SetNuiFocus(true, true)
    SendNUIMessage({
        action = "setVisibleCommunityTrash",
        data   = {
            required = csCfg.requiredPickups or 6,
            time     = csCfg.minigameTime    or 16,
        },
    })

    local result = Citizen.Await(p)

    SetNuiFocus(false, false)
    SendNUIMessage({ action = "setVisibleCommunityTrash", data = false })

    return result
end

RegisterNUICallback("prison/community/trashResult", function(payload, cb)
    cb({})
    local resolver = minigameResolver
    minigameResolver = nil
    if resolver then
        local success = payload and payload.success == true
        resolver(success)
    end
end)

-- ─── Bag Attach / Carry Anim ─────────────────────────────────────────────────

-- Spawns and attaches the trash bag prop to the player's right hand
local function AttachBagToPed()
    local model = csCfg.bagProp or "prop_cs_rub_binbag_01"
    local hash  = joaat(model)
    lib.requestModel(hash, 5000)
    if not HasModelLoaded(hash) then return nil end

    local pedPos = GetEntityCoords(cache.ped)
    local bag    = CreateObject(hash, pedPos.x, pedPos.y, pedPos.z, true, true, false)
    local bone   = GetPedBoneIndex(cache.ped, 57005)

    AttachEntityToEntity(bag, cache.ped, bone,
        0.12, 0.02, -0.02, -130.0, 0.0, 0.0,
        true, true, false, true, 1, true)

    SetModelAsNoLongerNeeded(hash)
    return bag
end

local function StartCarryAnim()
    if not (csCfg.carryAnim and csCfg.carryAnim.dict) then return end
    lib.requestAnimDict(csCfg.carryAnim.dict)
    TaskPlayAnim(cache.ped, csCfg.carryAnim.dict, csCfg.carryAnim.clip,
        4.0, -4.0, -1, 49, 0, false, false, false)
end

local function StopCarryAnim()
    if not (csCfg.carryAnim and csCfg.carryAnim.dict) then return end
    if IsEntityPlayingAnim(cache.ped, csCfg.carryAnim.dict, csCfg.carryAnim.clip, 3) then
        StopAnimTask(cache.ped, csCfg.carryAnim.dict, csCfg.carryAnim.clip, 1.0)
    end
    ClearPedSecondaryTask(cache.ped)
end

-- ─── Dumpster Throw ──────────────────────────────────────────────────────────

-- Throws the carried bag into the dumpster (triggers server task complete)
local function ThrowBagIntoDumpster()
    if not carriedBag then
        return Bridge.Notify.showNotify(locale("cs_need_bag"), "error")
    end

    local capturedSession = sessionId
    StopCarryAnim()

    local animDef = csCfg.throwAnim or { dict = "pickup_object", clip = "putdown_low" }

    lib.progressBar({
        duration     = csCfg.throwDuration or 2500,
        label        = locale("cs_throwing"),
        useWhileDead = false,
        canCancel    = false,
        disable      = { move = true, car = true, combat = true },
        anim         = { dict = animDef.dict, clip = animDef.clip },
    })

    -- Validate session is still active
    if sessionId ~= capturedSession or not carriedBag then return end

    SafeDeleteEntity(carriedBag.bag)
    carriedBag = nil
    ClearPedTasks(cache.ped)

    if not activeSentenceData then return end

    TriggerServerEvent("p_policejob/server/prison/communityTaskComplete")
    Bridge.Notify.showNotify(locale("cs_task_done"), "success")

    -- After a delay, spawn a new pile if session still active
    SetTimeout(csCfg.respawnDelay or 4000, function()
        if sessionId == capturedSession and activeSentenceData then
            local freePool = GetFreePoolIndex()
            if freePool then
                SpawnTrashPile(freePool)
            end
        end
    end)
end

-- ─── Trash Pile Spawning ─────────────────────────────────────────────────────

-- Forward declaration used in ThrowBagIntoDumpster
local SpawnTrashPile

-- Picks up a trash pile: plays minigame → progress bar → attach bag → notify
local function PickUpTrashPile(spawnCount)
    if not activeSentenceData then return end
    if carriedBag then
        return Bridge.Notify.showNotify(locale("cs_carry_to_dumpster"), "error")
    end

    local pile = activePiles[spawnCount]
    if not (pile and pile.prop) then return end

    local capturedSession = sessionId

    -- Minigame
    local passed = ShowTrashMinigame()

    if sessionId ~= capturedSession or not activeSentenceData then return end

    if not passed then
        return Bridge.Notify.showNotify(locale("cs_minigame_fail"), "error")
    end

    -- Pickup progress bar
    local animDef = csCfg.pickupAnim or { dict = "pickup_object", clip = "pickup_low" }
    local completed = lib.progressBar({
        duration     = csCfg.pickupDuration or 4000,
        label        = locale("cs_picking_up"),
        useWhileDead = false,
        canCancel    = true,
        disable      = { move = true, car = true, combat = true },
        anim         = { dict = animDef.dict, clip = animDef.clip },
    })

    if not completed then return end

    -- Re-validate after progress bar
    if sessionId ~= capturedSession or not activeSentenceData then return end
    if not activePiles[spawnCount] then return end

    -- Clean up the pile
    SafeDeleteEntity(pile.prop)
    RemoveSphereZone(pile.zoneId)

    if pile.blip and DoesBlipExist(pile.blip) then
        RemoveBlip(pile.blip)
    end

    poolSpawnCounts[pile.poolIndex] = nil
    activePiles[spawnCount] = nil

    -- Attach bag and start carry anim
    local bag = AttachBagToPed()
    if not bag then return end

    carriedBag = { bag = bag }
    StartCarryAnim()
    Bridge.Notify.showNotify(locale("cs_carry_to_dumpster"), "info")
end

-- Spawns a trash pile at the given pool index
SpawnTrashPile = function(poolIndex)
    -- Skip if pool already occupied or no coords
    if poolSpawnCounts[poolIndex] then return end
    if not trashPoolCoords[poolIndex]  then return end

    -- Scatter position around pool center
    local scatter  = tonumber(csCfg.scatter) or 1.2
    local angle    = math.random() * 2 * math.pi
    local dist     = math.sqrt(math.random()) * scatter
    local center   = trashPoolCoords[poolIndex]

    local spawnPos = vector3(
        center.x + math.cos(angle) * dist,
        center.y + math.sin(angle) * dist,
        center.z
    )

    globalSpawnCounter = globalSpawnCounter + 1
    local spawnCount   = globalSpawnCounter
    poolSpawnCounts[poolIndex] = spawnCount

    -- Prop
    local prop = SpawnFrozenPropAtGround(csCfg.trashProp or "prop_rub_binbag_03", spawnPos)

    -- Target zone
    local zone = Bridge.Target.addSphereZone({
        coords  = spawnPos,
        radius  = 1.4,
        debug   = Bridge.Config and Bridge.Config.Debug,
        options = {
            {
                name     = string.format("p_policejob_prison_cs_pile_%d", spawnCount),
                label    = locale("cs_pickup_trash"),
                icon     = "fa-solid fa-trash",
                distance = 1.8,
                onSelect = function()
                    PickUpTrashPile(spawnCount)
                end,
            },
        },
    })

    -- Blip
    local blip = AddBlipForCoord(spawnPos.x, spawnPos.y, spawnPos.z)
    SetBlipSprite(blip, 318)
    SetBlipColour(blip, 2)
    SetBlipScale(blip, 0.7)
    SetBlipAsShortRange(blip, true)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentSubstringPlayerName(locale("cs_pickup_trash"))
    EndTextCommandSetBlipName(blip)

    activePiles[spawnCount] = {
        poolIndex = poolIndex,
        coords    = spawnPos,
        prop      = prop,
        zoneId    = zone,
        blip      = blip,
    }
end

-- ─── Dumpster Spawning ────────────────────────────────────────────────────────

local function SpawnDumpster()
    local loc = currentLocation
    if not (loc and loc.dumpster) then return end

    dumpsterData = { coords = loc.dumpster }

    dumpsterData.prop = SpawnFrozenPropAtGround(csCfg.dumpsterProp or "prop_dumpster_01a", loc.dumpster)

    local blip = AddBlipForCoord(loc.dumpster.x, loc.dumpster.y, loc.dumpster.z)
    SetBlipSprite(blip, 318)
    SetBlipColour(blip, 1)
    SetBlipScale(blip, 0.8)
    SetBlipAsShortRange(blip, true)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentSubstringPlayerName(locale("cs_dumpster"))
    EndTextCommandSetBlipName(blip)
    dumpsterData.blip = blip

    local zone = Bridge.Target.addSphereZone({
        coords  = vector3(loc.dumpster.x, loc.dumpster.y, loc.dumpster.z + 0.5),
        radius  = 1.6,
        debug   = Bridge.Config and Bridge.Config.Debug,
        options = {
            {
                name     = "p_policejob_prison_cs_dumpster",
                label    = locale("cs_dumpster"),
                icon     = "fa-solid fa-dumpster",
                distance = 2.0,
                onSelect = ThrowBagIntoDumpster,
            },
        },
    })

    dumpsterData.zoneId = zone
end

-- ─── Full Session Cleanup ────────────────────────────────────────────────────

local function CleanupSession()
    for _, pile in pairs(activePiles) do
        SafeDeleteEntity(pile.prop)
        RemoveSphereZone(pile.zoneId)
        if pile.blip and DoesBlipExist(pile.blip) then RemoveBlip(pile.blip) end
    end
    activePiles       = {}
    poolSpawnCounts   = {}

    if dumpsterData then
        SafeDeleteEntity(dumpsterData.prop)
        RemoveSphereZone(dumpsterData.zoneId)
        if dumpsterData.blip and DoesBlipExist(dumpsterData.blip) then
            RemoveBlip(dumpsterData.blip)
        end
        dumpsterData = nil
    end

    if carriedBag then
        SafeDeleteEntity(carriedBag.bag)
        carriedBag = nil
    end

    StopCarryAnim()

    if locationBlip and DoesBlipExist(locationBlip) then
        RemoveBlip(locationBlip)
    end
    locationBlip = nil

    -- Cancel any pending minigame promise
    if minigameResolver then
        local resolver = minigameResolver
        minigameResolver = nil
        resolver(false)
    end

    SetNuiFocus(false, false)
    SendNUIMessage({ action = "setVisibleCommunityTrash", data = false })
end

-- ─── Session Initialisation ───────────────────────────────────────────────────

local function InitSession()
    CleanupSession()

    if not currentLocation then return end

    -- Location blip
    if currentLocation.location then
        locationBlip = AddBlipForCoord(
            currentLocation.location.x,
            currentLocation.location.y,
            currentLocation.location.z
        )
        SetBlipSprite(locationBlip, 280)
        SetBlipColour(locationBlip, 5)
        SetBlipScale(locationBlip, 0.9)
        SetBlipAsShortRange(locationBlip, true)
        BeginTextCommandSetBlipName("STRING")
        AddTextComponentSubstringPlayerName("Community Service")
        EndTextCommandSetBlipName(locationBlip)
    end

    -- Build pool coords
    trashPoolCoords = {}

    if currentLocation.taskLocations and currentLocation.taskLocations.trash_pickup
    and #currentLocation.taskLocations.trash_pickup > 0
    then
        for _, pt in ipairs(currentLocation.taskLocations.trash_pickup) do
            trashPoolCoords[#trashPoolCoords + 1] = vector3(pt.x, pt.y, pt.z)
        end
    elseif currentLocation.location then
        local loc      = currentLocation.location
        local spots    = tonumber(csCfg.generatedSpots)     or 8
        local minR     = tonumber(csCfg.generatedMinRadius) or 8.0
        local maxR     = tonumber(csCfg.generatedRadius)    or 28.0

        for i = 1, spots do
            local angle  = (i / spots) * 2 * math.pi + (math.random() - 0.5) * 0.6
            local dist   = minR + math.random() * (maxR - minR)
            local px     = loc.x + math.cos(angle) * dist
            local py     = loc.y + math.sin(angle) * dist
            local found, gz = GetGroundZFor_3dCoord(px, py, loc.z + 5.0, false)
            trashPoolCoords[#trashPoolCoords + 1] = vector3(px, py, found and gz or loc.z)
        end
    end

    -- Spawn initial piles
    local activePileLimit = math.min(tonumber(csCfg.activePiles) or 3, #trashPoolCoords)
    for _ = 1, activePileLimit do
        local freePool = GetFreePoolIndex()
        if freePool then SpawnTrashPile(freePool) end
    end

    SpawnDumpster()
end

-- ─── Marker Draw Thread ───────────────────────────────────────────────────────

local function StartMarkerThread()
    local capturedSession = sessionId
    local markerCfg       = csCfg.markers or {}

    if markerCfg.enabled == false then return end

    local markerType     = markerCfg.type          or 2
    local markerSize     = markerCfg.size          or 0.35
    local markerHeight   = markerCfg.height        or 1.2
    local dumpsterHeight = markerCfg.dumpsterHeight or 1.9
    local drawDist       = markerCfg.drawDistance  or 80.0
    local pileColor      = markerCfg.pileColor    or { r = 80,  g = 200, b = 80,  a = 200 }
    local dumpColor      = markerCfg.dumpsterColor or { r = 40,  g = 120, b = 255, a = 200 }

    CreateThread(function()
        while activeSentenceData and sessionId == capturedSession do
            local pedPos   = GetEntityCoords(cache.ped)
            local drew     = false

            -- Pile markers (only when not carrying a bag)
            if not carriedBag then
                for _, pile in pairs(activePiles) do
                    if #(pedPos - pile.coords) <= drawDist then
                        DrawMarker(markerType,
                            pile.coords.x, pile.coords.y, pile.coords.z + markerHeight,
                            0, 0, 0, 180, 0, 0,
                            markerSize, markerSize, markerSize,
                            pileColor.r, pileColor.g, pileColor.b, pileColor.a,
                            true, false, 2, true, nil, nil, false)
                        drew = true
                    end
                end
            end

            -- Dumpster marker
            if dumpsterData and dumpsterData.coords then
                local dc = dumpsterData.coords
                if #(pedPos - vector3(dc.x, dc.y, dc.z)) <= drawDist then
                    DrawMarker(markerType,
                        dc.x, dc.y, dc.z + dumpsterHeight,
                        0, 0, 0, 180, 0, 0,
                        markerSize, markerSize, markerSize,
                        dumpColor.r, dumpColor.g, dumpColor.b, dumpColor.a,
                        true, false, 2, true, nil, nil, false)
                    drew = true
                end
            end

            Wait(drew and 0 or 400)
        end
    end)
end

-- ─── CS Entry / Release ──────────────────────────────────────────────────────

local function EnterCommunityService(sentenceData)
    sessionId = sessionId + 1
    activeSentenceData = sentenceData

    -- Wait for map and CS locations (up to 4 seconds)
    local tries = 0
    while not (Prison and Prison.Map and Prison.Map.communityService) and tries < 40 do
        Wait(100)
        tries = tries + 1
    end

    -- Set state bags
    LocalPlayer.state:set("isInPrison",    true, true)
    LocalPlayer.state:set("prisonSentence", (sentenceData and sentenceData.remaining) or 0, true)

    -- Pick a random CS location
    local csMap = Prison.Map and Prison.Map.communityService
    local locations = nil

    if csMap then
        if csMap.locations and #csMap.locations > 0 then
            locations = csMap.locations
        else
            locations = { csMap }
        end
    end

    if locations then
        currentLocation = locations[math.random(#locations)]
    end

    -- Teleport
    if currentLocation and currentLocation.location then
        FadeTeleport(currentLocation.location)
    end

    Bridge.Notify.showNotify(locale("community_service_arrived"), "info")

    InitSession()
    StartMarkerThread()

    -- Sync Prison state
    if Prison and Prison.pushJailHud then
        Prison.isInPrison   = true
        Prison.sentenceData = sentenceData
        Prison.cellId       = sentenceData and sentenceData.cellId
        if Prison.sentenceData then
            Prison.sentenceData.isCommunityService = true
        end
        Prison:pushJailHud()
    end
end

local function ReleaseCommunityService()
    if not activeSentenceData then return end

    sessionId = sessionId + 1
    activeSentenceData = nil
    CleanupSession()

    LocalPlayer.state:set("isInPrison",    false, true)
    LocalPlayer.state:set("prisonSentence", 0,    true)

    -- Find release coords
    local dest = nil
    if currentLocation and currentLocation.release then
        dest = currentLocation.release
    elseif Prison.Map and Prison.Map.communityService then
        local csMap = Prison.Map.communityService
        dest = csMap.release or csMap.location
    end

    currentLocation = nil

    if dest then FadeTeleport(dest) end

    SendNUIMessage({ action = "setVisibleJailHud", data = false })
    Bridge.Notify.showNotify(locale("community_service_released"), "success")

    if Prison then
        Prison.isInPrison   = false
        Prison.sentenceData = nil
        Prison.cellId       = nil
    end
end

-- ─── Net Events ──────────────────────────────────────────────────────────────

RegisterNetEvent("p_policejob/client/prison/communityService/enter",   EnterCommunityService)
RegisterNetEvent("p_policejob/client/prison/communityService/release", ReleaseCommunityService)

-- ─── Cleanup ─────────────────────────────────────────────────────────────────

AddEventHandler("onResourceStop", function(resourceName)
    if resourceName == GetCurrentResourceName() then
        CleanupSession()
    end
end)
