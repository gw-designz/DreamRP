-- Guard: only run if module is enabled in config
if not Config.Modules.SMASH_N_GRAB then
    return
end

-- Global state table (shared across files)
SmashnGrab = {
    blips = {},
    vehicles = {},
    vehicleCount = 0,
    isLoaded = false,
}

-- Wait for Framework and its core to be available before proceeding
while true do
    if Framework and Framework.getCore then
        break
    end
    Citizen.Wait(0)
end

-- ─────────────────────────────────────────────
-- Helper: check if a vehicle entity is valid from a netId
-- ─────────────────────────────────────────────
function GetEntityFromNetId(netId)
    if not netId or netId == 0 then return nil end
    if not NetworkDoesNetworkIdExist(netId) then return nil end
    local entity = NetworkGetEntityFromNetworkId(netId)
    if entity and entity ~= 0 and DoesEntityExist(entity) then
        return entity
    end
    return nil
end

-- ─────────────────────────────────────────────
-- Helper: safely delete a loot prop entity
-- ─────────────────────────────────────────────
function DeleteLootObject(vehicleData)
    if vehicleData.object and DoesEntityExist(vehicleData.object) then
        SetEntityAsMissionEntity(vehicleData.object, true, true)
        DeleteEntity(vehicleData.object)
        vehicleData.object = nil
    end
end

-- ─────────────────────────────────────────────
-- Helper: remove the smash context menu from a vehicle entity
-- ─────────────────────────────────────────────
function RemoveVehicleContextMenu(vehicleEntity, vehicleData)
    if vehicleData.contextElement then
        Target.removeTargetEntity(Target, vehicleEntity, vehicleData.contextElement)
        vehicleData.contextElement = nil
    end
end

-- ─────────────────────────────────────────────
-- Helper: remove a debug blip for a vehicle
-- ─────────────────────────────────────────────
function RemoveVehicleBlip(vehicleData)
    if Config.Debug then
        local blip = SmashnGrab.blips[vehicleData.uniqueId]
        if blip then
            RemoveBlip(blip)
            SmashnGrab.blips[vehicleData.uniqueId] = nil
        end
    end
end

-- ─────────────────────────────────────────────
-- Helper: remove a vehicle entry from SmashnGrab state
-- ─────────────────────────────────────────────
function RemoveVehicleEntry(netId)
    SmashnGrab.vehicles[netId] = nil
    SmashnGrab.vehicleCount = SmashnGrab.vehicleCount - 1
end

-- ─────────────────────────────────────────────
-- SmashnGrab.createBlip
-- Creates a debug map blip for a vehicle location
-- Args: self, coords, netId, label, color, uniqueId
-- ─────────────────────────────────────────────
function SmashnGrab.createBlip(self, coords, netId, label, color, uniqueId)
    local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(blip, 225)
    SetBlipDisplay(blip, 4)
    SetBlipColour(blip, color)
    SetBlipScale(blip, 0.8)
    SetBlipAsShortRange(blip, true)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString(label)
    EndTextCommandSetBlipName(blip)
    SmashnGrab.blips[uniqueId] = blip
end

-- ─────────────────────────────────────────────
-- SmashnGrab.startBleeding
-- 10% chance the player takes 10 HP damage when smashing a window.
-- Only applies if the ped is wearing clothing with drawable ID ≤15
-- or specific IDs (112–114) on component slot 3 (torso/upper body).
-- ⚠️ The `elseif L3_2 <= 5` branch in the original is unreachable
--    because the outer check is already `<= 10`, making `<= 5` always
--    true inside it — but it runs the same code (damage + notify),
--    so it's collapsed into the single branch below without behavior change.
-- ─────────────────────────────────────────────
function SmashnGrab.startBleeding(self)
    local torsoDrawable = GetPedDrawableVariation(cache.ped, 3)
    local barehanded = torsoDrawable <= 15 or torsoDrawable == 112 or torsoDrawable == 113 or torsoDrawable == 114

    local roll = math.random(1, 100)
    if roll <= 10 and barehanded then
        local currentHealth = GetEntityHealth(cache.ped)
        SetEntityHealth(cache.ped, currentHealth - 10)
        Framework.Notify(Framework, Translate("BLEEDING"))
    end
end

-- ─────────────────────────────────────────────
-- SmashnGrab.smashWindow
-- Called when the player activates the "Smash Window" target action.
-- Handles: action gating, animation, window smash, loot progress bar.
-- Args: self (SmashnGrab), vehicle entity, vehicleData table
-- ─────────────────────────────────────────────
function SmashnGrab.smashWindow(self, vehicle, vehicleData)
    if not vehicle or not vehicleData or not vehicleData.seat then return end

    if not Framework.canDoAction(Framework, "SMASH_N_GRAB") then
        Framework.Notify(Framework, Translate("CANT_DO_ACTION"))
        return
    end

    Trace(vehicleData.uniqueId)

    local policeCount = Main.getPoliceCount(Main)
    if policeCount < Config.SmashnGrab.PoliceRequired then
        Framework.Notify(Framework, Translate("NOT_ENOUGH_POLICE"))
        return
    end

    local seat = vehicleData.seat
    if not seat.index or not seat.bone then return end

    -- Map seat index to GTA door index (driver=-1→0, passenger0→1, etc.)
    local seatToDoor = { [-1] = 0, [0] = 1, [1] = 2, [2] = 3 }
    local doorIndex = seatToDoor[seat.index]
    if not doorIndex then return end

    local boneIndex = GetEntityBoneIndexByName(vehicle, seat.bone)
    if boneIndex == -1 then return end

    -- Determine smash position: use bone world position if available, else entity coords
    local smashCoords
    local bonePos = GetWorldPositionOfEntityBone(vehicle, boneIndex)
    if bonePos then
        smashCoords = bonePos
    else
        smashCoords = GetEntityCoords(vehicle)
    end

    if seat.offset then
        smashCoords = vector3(smashCoords.x, smashCoords.y, smashCoords.z)
    end

    local distToWindow = #(GetEntityCoords(cache.ped) - smashCoords)
    if distToWindow > 1.3 then
        Framework.Notify(Framework, Translate("TOO_FAR_FROM_VEHICLE"))
        return
    end

    -- Request network control of the vehicle
    if not NetworkHasControlOfEntity(vehicle) then
        NetworkRequestControlOfEntity(vehicle)
        Citizen.Wait(100)
    end
    NetworkRequestControlOfEntity(vehicle)
    SetEntityAsMissionEntity(vehicle, true, true)

    local entityState = Entity(vehicle).state
    if entityState.looting or entityState.looted then
        Framework.Notify(Framework, Translate("WINDOW_SMASHED_ALREADY"))
        return
    end

    Main.setEntityStateBag(Main, vehicle, { looting = true })
    ClearPedTasksImmediately(cache.ped)

    local lockStatus = GetVehicleDoorLockStatus(vehicle)
    if lockStatus == 1 then
        -- Door is unlocked: open it normally
        TaskOpenVehicleDoor(cache.ped, vehicle, -1, doorIndex, 1.0)
    else
        if not IsVehicleWindowIntact(vehicle, doorIndex) then
            -- Window already broken, just wait
            Trace("smashed")
            Wait(500)
        else
            -- Perform break-in animation and smash the window
            TaskTurnPedToFaceEntity(cache.ped, vehicle, 1000)
            Wait(1000)
            Main.playAdvancedAnimation(Main, cache.ped, "veh@break_in@0h@p_m_zero@", "std_force_entry_ds", {
                speed = 1.0,
                speedMultiplier = 1.0,
                duration = 500,
                flag = 16,
            })
            Wait(500)
            SmashVehicleWindow(vehicle, doorIndex)
            TriggerServerEvent(eventName .. "server:smashVehicleWindow", VehToNet(vehicle), doorIndex, vehicleData.uniqueId)
            self.startBleeding(self)
        end
    end

    -- Random dispatch alert
    if math.random(1, 100) <= Config.SmashnGrab.AlertChance then
        local dispatchData = BuildDispatchData({
            message = Translate("SMASHNGRAB_DISPATCH"),
            coords = GetEntityCoords(cache.ped),
            jobs = { "police", "lspd", "bcso" },
            blip = {
                sprite = 458,
                color = 1,
                scale = 1.0,
                text = Translate("SMASHNGRAB_DISPATCH_BLIP"),
                flash = true,
            },
        }, Config.SmashnGrab.Dispatch)
        Dispatch.Send(Dispatch, dispatchData)
    end

    local loot = vehicleData.loot
    Trace(json.encode(loot))

    if not loot then
        Main.setEntityStateBag(Main, vehicle, { looting = false })
        return
    end

    -- Remove debug blip when looting starts
    if Config.Debug then
        local blip = self.blips[vehicleData.uniqueId]
        if blip then RemoveBlip(blip) end
    end

    -- Start looting scenario and progress bar
    TaskStartScenarioInPlace(cache.ped, "PROP_HUMAN_BUM_BIN", 0, true)

    local progressTime = Config.SmashnGrab.ProgressTime or {}
    local minTime = progressTime.min or 5000
    local maxTime = progressTime.max or 10000
    if minTime > maxTime then maxTime = minTime end

    Framework.doProgress(Framework, {
        text = Translate("SEARCHING_FOR_LOOT"),
        time = math.random(minTime, maxTime),
    }, function(completed)
        if completed then
            local result = TriggerServerCallback({
                eventName = eventName .. "server:giveVehicleLoot",
                args = {{ loot = loot, uniqieId = vehicleData.uniqueId, netId = VehToNet(vehicle) }},
            })
            if not result.success then
                Framework.Notify(Framework, Translate("NO_LOOT_FOUND"))
            end
            Main.setEntityStateBag(Main, vehicle, { looted = true })
            ClearPedTasks(cache.ped)
            Framework.onFinished(Framework, "SMASH_N_GRAB")
        else
            Main.setEntityStateBag(Main, vehicle, { looting = false })
        end
    end)
end

-- ─────────────────────────────────────────────
-- Main proximity + loot object management thread
-- Runs every 500ms; spawns/attaches loot props and manages smash context menus
-- ─────────────────────────────────────────────
Citizen.CreateThread(function()
    WaitForConfigSync()
    Citizen.Wait(500)

    if not Config.Modules.SMASH_N_GRAB then
        Trace("SMASH_N_GRAB disabled after config sync, skipping client init")
        return
    end

    if Framework.isCharacterLoaded(Framework) then
        TriggerServerEvent(eventName .. "server:requestPersistentVehicles")
    end

    while not SmashnGrab.isLoaded do
        Citizen.Wait(0)
    end

    while true do
        local tickDelay = 500

        if SmashnGrab.vehicleCount > 0 then
            for netId, vehicleData in pairs(SmashnGrab.vehicles) do
                local coords = vehicleData.coords
                local distToCoords

                if coords then
                    distToCoords = #(GetEntityCoords(cache.ped) - coords)
                end

                -- Within range if close to stored coords OR coords not yet known
                local inRange = distToCoords and distToCoords < 10.0 or distToCoords

                if not vehicleData.netId or vehicleData.netId == 0 then
                    -- No netId yet, skip
                elseif inRange then
                    local vehicle = GetEntityFromNetId(vehicleData.netId)

                    if not vehicle then
                        Trace("Vehicle does not exist", vehicleData.netId, vehicleData.coords)
                    else
                        local distToVehicle = #(GetEntityCoords(cache.ped) - GetEntityCoords(vehicle))
                        local entityState = Entity(vehicle).state

                        if distToVehicle < 20.0 then
                            if not entityState.looted then
                                -- Add smash context menu when close enough
                                if distToVehicle < 5.0 then
                                    if not vehicleData.contextElement then
                                        vehicleData.contextElement = Target.addTargetEntity(Target, vehicle, {
                                            label = Translate("SMASH_WINDOW"),
                                            icon = "fa fa-car-crash",
                                            action = function(entity)
                                                if entity and DoesEntityExist(entity) then
                                                    SmashnGrab.smashWindow(SmashnGrab, entity, vehicleData)
                                                end
                                            end,
                                            canInteract = function(entity)
                                                if SmashnGrab.vehicleCount < 1 then return false end
                                                for _, vd in pairs(SmashnGrab.vehicles) do
                                                    if vd.netId and vd.netId ~= 0 then
                                                        local ve = GetEntityFromNetId(vd.netId)
                                                        if ve and entity == ve then return true end
                                                    end
                                                end
                                                return false
                                            end,
                                        })
                                        Citizen.Wait(350)
                                    end
                                end

                                -- Spawn loot prop if not already present
                                if not vehicleData.object then
                                    local spawnPos = vec3(vehicleData.coords.x, vehicleData.coords.y, vehicleData.coords.z - 5.0)
                                    vehicleData.object = Main.spawnLocalObject(Main, vehicleData.loot.prop, spawnPos, nil)

                                    while not DoesEntityExist(vehicleData.object) do
                                        Citizen.Wait(0)
                                    end

                                    SetEntityAsMissionEntity(vehicleData.object, true, true)
                                    SetEntityCollision(vehicleData.object, false, false)
                                    Citizen.Wait(100)

                                    local boneIndex = GetEntityBoneIndexByName(vehicle, vehicleData.seat.bone)
                                    local rot = vehicleData.loot.rot or vector3(0.0, 0.0, 0.0)
                                    vehicleData.loot.rot = rot

                                    if boneIndex ~= -1 then
                                        AttachEntityToEntity(
                                            vehicleData.object, vehicle, boneIndex,
                                            0.0, 0.0,
                                            vehicleData.seat.offset and vehicleData.seat.offset.z or 0.0,
                                            rot.x or 0.0, rot.y or 0.0, rot.z or 0.0,
                                            false, false, false, true, 1, true
                                        )
                                        FreezeEntityPosition(vehicleData.object, true)
                                    else
                                        Trace("Bone not found on vehicle:", vehicleData.seat.bone)
                                    end
                                end

                            else
                                -- Vehicle already looted: clean up object and context menu
                                DeleteLootObject(vehicleData)
                                if vehicleData.contextElement then
                                    RemoveVehicleContextMenu(vehicle, vehicleData)
                                end
                            end
                        else
                            -- Out of 20m range: remove context menu only (keep object)
                            if vehicleData.contextElement then
                                RemoveVehicleContextMenu(vehicle, vehicleData)
                            end
                        end
                    end
                end
            end
        end

        Citizen.Wait(tickDelay)
    end
end)

-- ─────────────────────────────────────────────
-- Stale vehicle cleanup thread
-- Every 10 seconds, removes vehicles whose network entity no longer exists
-- ─────────────────────────────────────────────
Citizen.CreateThread(function()
    while not SmashnGrab.isLoaded do
        Citizen.Wait(1000)
    end

    while true do
        Citizen.Wait(10000)

        if SmashnGrab.vehicleCount > 0 then
            local staleEntries = {}

            for netId, vehicleData in pairs(SmashnGrab.vehicles) do
                local vehicle = GetEntityFromNetId(netId)
                if not vehicle then
                    staleEntries[#staleEntries + 1] = { netId = netId, data = vehicleData }
                end
            end

            for _, entry in ipairs(staleEntries) do
                local vehicleData = entry.data

                DeleteLootObject(vehicleData)

                if vehicleData.contextElement then
                    local vehicle = GetEntityFromNetId(entry.netId)
                    if vehicle then
                        RemoveVehicleContextMenu(vehicle, vehicleData)
                    end
                end

                RemoveVehicleBlip(vehicleData)

                SmashnGrab.vehicles[entry.netId] = nil
                SmashnGrab.vehicleCount = math.max(0, SmashnGrab.vehicleCount - 1)
            end
        end
    end
end)

-- ─────────────────────────────────────────────
-- Client callback: verifyVehicles
-- Server sends a table of netIds; client validates each and returns
-- a filtered list of eligible vehicles with seat/model info.
-- ─────────────────────────────────────────────
RegisterClientCallback({
    eventName = eventName .. "client:verifyVehicles",
    eventCallback = function(source, candidateNetIds)
        local verified = {}
        local failures = {
            netIdInvalid = 0,
            notExist = 0,
            wrongClass = 0,
            notEmpty = 0,
            badModel = 0,
            blacklisted = 0,
            tooFewSeats = 0,
            boneNotFound = 0,
        }

        local function isInList(value, list)
            local lower = string.lower(value)
            for _, entry in ipairs(list) do
                if entry == lower then return true end
            end
            return false
        end

        if not next(candidateNetIds) then
            return { status = false, message = "No potential vehicles found", failures = failures }
        end

        for _, netId in pairs(candidateNetIds) do
            local vehicle = GetEntityFromNetId(netId)

            if not vehicle then
                if not netId or netId == 0 or not NetworkDoesNetworkIdExist(netId) then
                    failures.netIdInvalid = failures.netIdInvalid + 1
                else
                    failures.notExist = failures.notExist + 1
                    Trace("Vehicle does not exist", netId)
                end
            else
                local vehicleClass = GetVehicleClass(vehicle)
                if not Config.SmashnGrab.AllowedVehicleClasses[vehicleClass] then
                    failures.wrongClass = failures.wrongClass + 1
                elseif not Main.isVehicleEmpty(Main, vehicle) then
                    failures.notEmpty = failures.notEmpty + 1
                else
                    local modelName = Main.getVehicleSpawnName(Main, vehicle)
                    local seatCount = GetVehicleModelNumberOfSeats(GetEntityModel(vehicle))

                    if not modelName or modelName == "UNKNOWN" or modelName == "NULL" then
                        failures.badModel = failures.badModel + 1
                    elseif isInList(modelName, Config.SmashnGrab.BlacklistedModels) then
                        failures.blacklisted = failures.blacklisted + 1
                    elseif seatCount < 2 then
                        failures.tooFewSeats = failures.tooFewSeats + 1
                    else
                        -- Pick a random seat config (or first if only 2 seats)
                        local seat
                        if seatCount ~= 2 then
                            local idx = math.random(1, #Config.SmashnGrab.Seats)
                            seat = Config.SmashnGrab.Seats[idx]
                        end
                        if not seat then
                            seat = Config.SmashnGrab.Seats[1]
                        end

                        local boneIndex = GetEntityBoneIndexByName(vehicle, seat.bone)
                        if boneIndex == -1 then
                            -- Retry with first seat config
                            Trace("Bone not retrying: ", seat.bone, vehicle)
                            seat = Config.SmashnGrab.Seats[1]
                            boneIndex = GetEntityBoneIndexByName(vehicle, seat.bone)
                            if boneIndex == -1 then
                                Trace("Bone not found on vehicle: ", seat.bone, vehicle)
                                failures.boneNotFound = failures.boneNotFound + 1
                            else
                                verified[#verified + 1] = { netId = netId, model = modelName, seats = seatCount, seat = seat }
                            end
                        else
                            verified[#verified + 1] = { netId = netId, model = modelName, seats = seatCount, seat = seat }
                        end
                    end
                end
            end
        end

        if #verified < 1 then
            return { status = false, message = "Unable to verify any vehicles", failures = failures }
        end

        Trace("Verified vehicles:", json.encode(verified, { indent = true }))
        return { status = true, vehicles = verified, failures = failures }
    end,
})

-- ─────────────────────────────────────────────
-- Event: character loaded → request persistent vehicles from server
-- ─────────────────────────────────────────────
RegisterNetEvent(eventName .. "client:characterLoaded")
AddEventHandler(eventName .. "client:characterLoaded", function()
    TriggerServerEvent(eventName .. "server:requestPersistentVehicles")
end)

-- ─────────────────────────────────────────────
-- Event: smash a vehicle window (triggered by another client via server)
-- ─────────────────────────────────────────────
RegisterNetEvent(eventName .. "client:smashVehicleWindow")
AddEventHandler(eventName .. "client:smashVehicleWindow", function(netId, windowIndex)
    local vehicle = GetEntityFromNetId(netId)
    if not vehicle then return end
    Trace("Smashing window")
    SmashVehicleWindow(vehicle, windowIndex)
end)

-- ─────────────────────────────────────────────
-- Event: server sends updated persistent vehicle list
-- Merges new entries if already loaded, replaces table if first load
-- ─────────────────────────────────────────────
RegisterNetEvent(eventName .. "client:updatePersistentVehicles")
AddEventHandler(eventName .. "client:updatePersistentVehicles", function(vehicleList)
    if (SmashnGrab.vehicleCount or 0) > 0 then
        -- Already have vehicles: merge in any new ones
        local added = 0
        for _, vehicleData in pairs(vehicleList) do
            local netId = vehicleData.netId
            if not (SmashnGrab.vehicles or {})[netId] then
                SmashnGrab.vehicles = SmashnGrab.vehicles or {}
                SmashnGrab.vehicles[netId] = vehicleData
                SmashnGrab.vehicleCount = (SmashnGrab.vehicleCount or 0) + 1
                added = added + 1
            end
        end
        if added > 0 then
            Trace("Added", added, "new vehicles")
            Trace("Total vehicles:", SmashnGrab.vehicleCount)
        end
    else
        -- First load: replace entire table and count
        SmashnGrab.vehicles = vehicleList
        local count = 0
        for _ in pairs(vehicleList) do count = count + 1 end
        SmashnGrab.vehicleCount = count
    end

    -- Spawn debug blips for all vehicles if debug mode is on
    if Config.Debug then
        for _, vehicleData in pairs(vehicleList) do
            SmashnGrab.createBlip(SmashnGrab, vehicleData.coords, vehicleData.netId, vehicleData.model, 5, vehicleData.uniqueId)
        end
    end

    if not SmashnGrab.isLoaded then
        SmashnGrab.isLoaded = true
    end
end)

-- ─────────────────────────────────────────────
-- Event: remove one or more persistent vehicles
-- Arg can be a uniqueId string OR a table of uniqueIds
-- ─────────────────────────────────────────────
RegisterNetEvent(eventName .. "client:removePersistentVehicle")
AddEventHandler(eventName .. "client:removePersistentVehicle", function(arg)
    if type(arg) ~= "table" then
        -- Single removal by uniqueId string
        for netId, vehicleData in pairs(SmashnGrab.vehicles) do
            if vehicleData.uniqueId == arg then
                DeleteLootObject(vehicleData)

                if vehicleData.contextElement then
                    local vehicle = GetEntityFromNetId(netId)
                    if vehicle then
                        RemoveVehicleContextMenu(vehicle, vehicleData)
                    end
                end

                RemoveVehicleBlip(vehicleData)
                RemoveVehicleEntry(netId)
                Trace("Removed vehicle:", arg)
                break
            end
        end
    else
        -- Batch removal by table of uniqueIds
        for _, uniqueId in pairs(arg) do
            for netId, vehicleData in pairs(SmashnGrab.vehicles) do
                if vehicleData.uniqueId == uniqueId then
                    DeleteLootObject(vehicleData)

                    if vehicleData.contextElement then
                        local vehicle = GetEntityFromNetId(netId)
                        if vehicle then
                            RemoveVehicleContextMenu(vehicle, vehicleData)
                        end
                    end

                    Trace("Deleting vehicle:", uniqueId)
                    RemoveVehicleBlip(vehicleData)
                    RemoveVehicleEntry(netId)
                    break
                end
            end
        end
    end
end)

-- ─────────────────────────────────────────────
-- Event: player uses a bag item (loot bag from smash & grab)
-- ─────────────────────────────────────────────
RegisterNetEvent(eventName .. "client:useBagItem")
AddEventHandler(eventName .. "client:useBagItem", function(usedItem)
    local result = TriggerServerCallback({
        eventName = eventName .. "server:openBagLoot",
        args = {{ usedItem = usedItem }},
    })

    if result and result.success then
        local message = result.message or Translate("SMASHNGRAB_BAG_OPENED")
        Framework.Notify(Framework, message)
    else
        Framework.Notify(Framework, Translate("NOTHING_FOUND"))
    end
end)

-- ─────────────────────────────────────────────
-- Event: resource stopping — clean up all entities and blips
-- ─────────────────────────────────────────────
AddEventHandler("onResourceStop", function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end

    if Config.Debug and SmashnGrab.blips then
        for _, blip in pairs(SmashnGrab.blips) do
            RemoveBlip(blip)
        end
    end

    for netId, vehicleData in pairs(SmashnGrab.vehicles or {}) do
        DeleteLootObject(vehicleData)

        if vehicleData.contextElement and netId and netId ~= 0 then
            local vehicle = GetEntityFromNetId(netId)
            if vehicle then
                RemoveVehicleContextMenu(vehicle, vehicleData)
            end
        end
    end
end)-- Module guard
if not (Config and Config.Modules and Config.Modules.SMASH_N_GRAB) then
    Trace("SMASH_N_GRAB module disabled, skipping all initialization and event handlers")
    return
end

-- ─── Vehicle Hash Lookup Table ────────────────────────────────────────────────
-- Loaded from vehicleHashes.json for fast O(1) model validation.

local vehicleHashLookup = {}
do
    local raw = LoadResourceFile(GetCurrentResourceName(), "vehicleHashes.json")
    if raw then
        local decoded = json.decode(raw)
        if decoded then
            for _, entry in ipairs(decoded) do
                vehicleHashLookup[entry.hash] = true
            end
            Trace("Loaded " .. #decoded .. " vehicle hashes for performance optimization")
        else
            Trace("Failed to decode vehicleHashes.json")
        end
    else
        Trace("Failed to load vehicleHashes.json")
    end
end

-- ─── Stats Tables ─────────────────────────────────────────────────────────────
-- nullStatsMeta: a metatable that makes any unset stat read as 0 and silently
-- drops writes — used when debug tracking is off to avoid nil errors cheaply.

local nullStatsMeta = {
    __index    = function() return 0 end,
    __newindex = function() end,
}

local function createNullStats()
    return setmetatable({}, nullStatsMeta)
end

local function createFullStats()
    return {
        candidatesReceived      = 0,
        attempted               = 0,
        notYetReady             = 0,
        successfullyRobbed      = 0,
        playerDroppedLosses     = 0,
        failedNotExist          = 0,
        failedPopType           = 0,
        failedHash              = 0,
        failedVehicleType       = 0,
        failedEngineRunning     = 0,
        failedPlayerOwned       = 0,
        failedNoOwner           = 0,
        failedLimit             = 0,
        failedChance            = 0,
        failedPersistent        = 0,
        failedLootedState       = 0,
        failedFrameworkCheck    = 0,
        failedTooClose          = 0,
        clientVerifyAttempted   = 0,
        clientVerifyPassed      = 0,
        failedClientVerify      = 0,
        clientFailedNetIdInvalid = 0,
        clientFailedNotExist    = 0,
        clientFailedWrongClass  = 0,
        clientFailedNotEmpty    = 0,
        clientFailedBadModel    = 0,
        clientFailedBlacklisted = 0,
        clientFailedTooFewSeats = 0,
        clientFailedBoneNotFound = 0,
        lastVehicleAddedAt      = 0,
        lastTickAt              = 0,
        lastTickProcessed       = 0,
        lastTickPassed          = 0,
    }
end

-- ─── SmashnGrab State ────────────────────────────────────────────────────────

SmashnGrab = {
    -- Legacy fields (used by event handlers declared before this block)
    vehicles               = {},
    vehicleCount           = 0,
    blips                  = {},
    isLoaded               = false,
    -- New persistent-vehicle fields
    persistentVehicles     = {},
    persistentVehicleCount = 0,
    vehiclesToRemove       = {},
    vehicleHashes          = vehicleHashLookup,
    candidateVehicles      = {},
    queueBatchSize         = (Config.SmashnGrab and Config.SmashnGrab.QueueBatchSize) or 8,
    debugEnabled           = false,
    stats                  = createNullStats(),
}

-- ─── Player List Cache ────────────────────────────────────────────────────────
-- Refreshes the player list at most every 5 seconds.

local cachedPlayerList    = {}
local playerListCacheTime = 0
local PLAYER_CACHE_TTL    = 5000

local function getCachedPlayers()
    local now = GetGameTimer()
    if now - playerListCacheTime >= PLAYER_CACHE_TTL then
        cachedPlayerList    = GetPlayers()
        playerListCacheTime = now
    end
    return cachedPlayerList
end

-- ─── Wait for eventName ───────────────────────────────────────────────────────

while not eventName do
    Citizen.Wait(0)
end

-- ─── Helpers ──────────────────────────────────────────────────────────────────

local function getEntityStateBag(entity)
    local state = Entity(entity).state
    if state and type(state.get) == "function" then
        return state
    end
    return nil
end

local function isVehicleLooted(stateBag)
    if not stateBag then return false end
    return stateBag:get("looted") or stateBag:get("looting") or false
end

local function isTooCloseToExisting(coords, minDist)
    for _, data in pairs(SmashnGrab.persistentVehicles) do
        if #(coords - data.coords) < minDist then
            return true
        end
    end
    return false
end

local function buildLootEntry(lootItem)
    if not (Config.SmashnGrab.UseBag and lootItem) then
        return lootItem
    end
    return {
        name  = lootItem.name,
        chance = lootItem.chance,
        count = lootItem.count,
        prop  = Config.SmashnGrab.BagProp or "prop_poly_bag_01",
        rot   = lootItem.rot,
    }
end

local function decrPersistentCount()
    SmashnGrab.persistentVehicleCount = math.max(0, SmashnGrab.persistentVehicleCount - 1)
end

-- ─── Entity Created ───────────────────────────────────────────────────────────

AddEventHandler("entityCreated", function(entity)
    if not entity or not DoesEntityExist(entity) then return end
    if GetEntityType(entity) ~= 2 then return end  -- 2 = vehicle

    SmashnGrab.stats.candidatesReceived = SmashnGrab.stats.candidatesReceived + 1

    if not SmashnGrab.candidateVehicles[entity] then
        SmashnGrab.candidateVehicles[entity] = GetGameTimer() + 10000
    end
end)

-- ─── Entity Removed ───────────────────────────────────────────────────────────

AddEventHandler("entityRemoved", function(entity)
    if not entity then return end

    SmashnGrab.candidateVehicles[entity] = nil

    local netId = NetworkGetNetworkIdFromEntity(entity)
    if netId and netId ~= 0 then
        local data = SmashnGrab.persistentVehicles[netId]
        if data then
            local uniqueId = data.uniqueId
            SmashnGrab.persistentVehicles[netId] = nil
            decrPersistentCount()
            TriggerClientEvent(eventName .. "client:removePersistentVehicle", -1, { uniqueId })
        end
    end
end)

-- ─── Candidate Processing Thread ─────────────────────────────────────────────
-- Runs every 20s, filters candidates through server-side checks, then hands
-- passing vehicles to prepareVehicle for client verification.

Citizen.CreateThread(function()
    SmashnGrab.vehiclesToPrepare = {}

    while true do
        Citizen.Wait(20000)

        local candidateCount = 0
        for _ in pairs(SmashnGrab.candidateVehicles) do
            candidateCount = candidateCount + 1
        end

        Trace(
            "SmashnGrab tick | candidates:", candidateCount,
            "| persistent:", SmashnGrab.persistentVehicleCount,
            "/", Config.SmashnGrab.Limit
        )

        local processed = 0
        local passed    = 0
        local now       = GetGameTimer()
        local minDist   = Config.SmashnGrab.MinVehicleDistance

        for entity, readyAt in pairs(SmashnGrab.candidateVehicles) do
            if processed >= SmashnGrab.queueBatchSize then break end

            if readyAt > now then
                SmashnGrab.stats.notYetReady = SmashnGrab.stats.notYetReady + 1
                goto nextCandidate
            end

            SmashnGrab.candidateVehicles[entity] = nil
            processed = processed + 1
            SmashnGrab.stats.attempted = SmashnGrab.stats.attempted + 1

            if not entity or not DoesEntityExist(entity) then
                SmashnGrab.stats.failedNotExist = SmashnGrab.stats.failedNotExist + 1
                goto nextCandidate
            end

            if not SmashnGrab.vehicleHashes[GetEntityModel(entity)] then
                SmashnGrab.stats.failedHash = SmashnGrab.stats.failedHash + 1
                goto nextCandidate
            end

            if GetVehicleType(entity) ~= "automobile" then
                SmashnGrab.stats.failedVehicleType = SmashnGrab.stats.failedVehicleType + 1
                goto nextCandidate
            end

            if GetIsVehicleEngineRunning(entity) then
                SmashnGrab.stats.failedEngineRunning = SmashnGrab.stats.failedEngineRunning + 1
                goto nextCandidate
            end

            if HasVehicleBeenOwnedByPlayer(entity) then
                SmashnGrab.stats.failedPlayerOwned = SmashnGrab.stats.failedPlayerOwned + 1
                goto nextCandidate
            end

            local owner = NetworkGetEntityOwner(entity)
            if not owner or owner <= 0 then
                SmashnGrab.stats.failedNoOwner = SmashnGrab.stats.failedNoOwner + 1
                goto nextCandidate
            end

            if SmashnGrab.persistentVehicleCount >= Config.SmashnGrab.Limit then
                SmashnGrab.stats.failedLimit = SmashnGrab.stats.failedLimit + 1
                goto nextCandidate
            end

            if math.random(1, 100) > Config.SmashnGrab.ChanceToSpawn then
                SmashnGrab.stats.failedChance = SmashnGrab.stats.failedChance + 1
                goto nextCandidate
            end

            do
                local stateBag = getEntityStateBag(entity)
                if stateBag and stateBag:get("persistent") then
                    SmashnGrab.stats.failedPersistent = SmashnGrab.stats.failedPersistent + 1
                    goto nextCandidate
                end

                if isVehicleLooted(stateBag) then
                    SmashnGrab.stats.failedLootedState = SmashnGrab.stats.failedLootedState + 1
                    goto nextCandidate
                end

                local netId = NetworkGetNetworkIdFromEntity(entity)
                if Framework:vehicleChecks(netId, entity) then
                    SmashnGrab.stats.failedFrameworkCheck = SmashnGrab.stats.failedFrameworkCheck + 1
                    goto nextCandidate
                end

                local coords = GetEntityCoords(entity)
                if isTooCloseToExisting(coords, minDist) then
                    SmashnGrab.stats.failedTooClose = SmashnGrab.stats.failedTooClose + 1
                    goto nextCandidate
                end

                SmashnGrab.vehiclesToPrepare[entity] = true
                passed = passed + 1
            end

            ::nextCandidate::
        end

        if processed > 0 then
            Trace("SmashnGrab processed:", processed, "| passed filters:", passed)
        end

        SmashnGrab.stats.lastTickAt        = GetGameTimer()
        SmashnGrab.stats.lastTickProcessed = processed
        SmashnGrab.stats.lastTickPassed    = passed

        SmashnGrab:prepareVehicle(SmashnGrab.vehiclesToPrepare)
        SmashnGrab.vehiclesToPrepare = {}
    end
end)

-- ─── Stale Persistent Vehicle Cleanup Thread ─────────────────────────────────
-- Every 10s, remove persistent vehicle entries whose entity no longer exists,
-- and flush the vehiclesToRemove queue to all clients.

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(10000)

        local toRemove = {}

        for netId, data in pairs(SmashnGrab.persistentVehicles) do
            local entity = NetworkGetEntityFromNetworkId(netId)
            if not entity or entity == 0 or not DoesEntityExist(entity) then
                toRemove[#toRemove + 1] = data.uniqueId
                SmashnGrab.persistentVehicles[netId] = nil
                decrPersistentCount()
            end
        end

        for _, uniqueId in ipairs(SmashnGrab.vehiclesToRemove) do
            toRemove[#toRemove + 1] = uniqueId
        end
        SmashnGrab.vehiclesToRemove = {}

        if #toRemove > 0 then
            TriggerClientEvent(eventName .. "client:removePersistentVehicle", -1, toRemove)
        end
    end
end)

-- ─── Prepare Vehicle (Client Verify Path) ────────────────────────────────────
-- Groups candidates by their network owner, then asks each owner to verify
-- their vehicles via a client callback. Confirmed vehicles are marked persistent.

function SmashnGrab:prepareVehicle(candidates)
    local count = 0
    for _ in pairs(candidates) do count = count + 1 end
    if count == 0 then return end

    -- Build netId map grouped by owner (source string)
    local byOwner = {}
    for entity in pairs(candidates) do
        if entity and DoesEntityExist(entity) then
            local netId = NetworkGetNetworkIdFromEntity(entity)
            if netId and netId ~= 0 then
                local owner = NetworkGetEntityOwner(entity)
                if owner and owner > 0 then
                    local ownerKey = tostring(owner)
                    byOwner[ownerKey] = byOwner[ownerKey] or {}
                    byOwner[ownerKey][netId] = netId
                end
            end
        end
    end

    local minDist     = Config.SmashnGrab.MinVehicleDistance
    local anyAdded    = false
    local slotsLeft   = Config.SmashnGrab.Limit - SmashnGrab.persistentVehicleCount

    for ownerKey, netIds in pairs(byOwner) do
        if SmashnGrab.persistentVehicleCount >= Config.SmashnGrab.Limit then break end

        self.stats.clientVerifyAttempted = self.stats.clientVerifyAttempted + 1

        local ownerSource = tonumber(ownerKey)
        if not GetPlayerName(ownerSource) then
            self.stats.failedClientVerify = self.stats.failedClientVerify + 1
            goto nextOwner
        end

        do
            -- Promise-based client callback with timeout
            local p        = promise.new()
            local resolved = false
            local function resolve(result)
                if resolved then return end
                resolved = true
                p:resolve(result)
            end

            TriggerClientCallback({
                source    = ownerKey,
                eventName = eventName .. "client:verifyVehicles",
                args      = { netIds },
                timeout   = Config.SmashnGrab.VerifyTimeoutSeconds or 5,
                timedout  = function() resolve(nil) end,
                callback  = function(result) resolve(result) end,
            })

            local response = Citizen.Await(p)

            if not response or type(response) ~= "table" then
                self.stats.failedClientVerify = self.stats.failedClientVerify + 1
                goto nextOwner
            end

            -- Accumulate client-side failure counts
            if response.failures then
                local f = response.failures
                self.stats.clientFailedNetIdInvalid  = self.stats.clientFailedNetIdInvalid  + (f.netIdInvalid  or 0)
                self.stats.clientFailedNotExist      = self.stats.clientFailedNotExist      + (f.notExist      or 0)
                self.stats.clientFailedWrongClass    = self.stats.clientFailedWrongClass    + (f.wrongClass    or 0)
                self.stats.clientFailedNotEmpty      = self.stats.clientFailedNotEmpty      + (f.notEmpty      or 0)
                self.stats.clientFailedBadModel      = self.stats.clientFailedBadModel      + (f.badModel      or 0)
                self.stats.clientFailedBlacklisted   = self.stats.clientFailedBlacklisted   + (f.blacklisted   or 0)
                self.stats.clientFailedTooFewSeats   = self.stats.clientFailedTooFewSeats   + (f.tooFewSeats   or 0)
                self.stats.clientFailedBoneNotFound  = self.stats.clientFailedBoneNotFound  + (f.boneNotFound  or 0)
            end

            if not response.status then
                self.stats.failedClientVerify = self.stats.failedClientVerify + 1
                goto nextOwner
            end

            local added = 0
            for _, vehicleData in pairs(response.vehicles) do
                if slotsLeft <= added then break end

                local netId = vehicleData.netId
                if self.persistentVehicles[netId] then goto nextVehicle end

                local entity = NetworkGetEntityFromNetworkId(netId)
                if not entity or not DoesEntityExist(entity) then goto nextVehicle end

                local coords = GetEntityCoords(entity)
                if isTooCloseToExisting(coords, minDist) then
                    self.stats.failedTooClose = self.stats.failedTooClose + 1
                    goto nextVehicle
                end

                do
                    Trace("Adding persistent vehicle: " .. tostring(coords))

                    local uniqueId   = Main:generateUniqueId()
                    local entityState = Entity(entity).state

                    entityState:set("persistent", true, true)
                    entityState:set("uniqueId",   uniqueId, true)

                    if GetVehicleDoorLockStatus(entity) ~= 2 then
                        SetVehicleDoorsLocked(entity, 2)
                    end

                    local loot = buildLootEntry(SelectRandomItem(Config.SmashnGrab.LootTables))

                    self.persistentVehicles[netId] = {
                        model   = vehicleData.model,
                        netId   = netId,
                        coords  = coords,
                        heading = GetEntityHeading(entity),
                        uniqueId = uniqueId,
                        seat    = vehicleData.seat,
                        loot    = loot,
                        owner   = ownerKey,
                    }
                    self.persistentVehicleCount = self.persistentVehicleCount + 1
                    self.stats.clientVerifyPassed = self.stats.clientVerifyPassed + 1
                    self.stats.lastVehicleAddedAt = GetGameTimer()
                    added    = added + 1
                    anyAdded = true
                end

                ::nextVehicle::
            end
        end

        ::nextOwner::
    end

    if anyAdded then
        TriggerLatentClientEvent(eventName .. "client:updatePersistentVehicles", -1, -1, SmashnGrab.persistentVehicles)
    end
end

-- ─── Get Vehicles (Legacy / Fallback Scan) ───────────────────────────────────
-- Scans all server-side vehicles directly (no candidate queue) and registers
-- robbable ones. Used as an alternative or supplemental path.
-- ⚠️ This function has significant code duplication with prepareVehicle's
-- inner loop. The two paths exist because one uses the candidate queue with
-- per-owner client callbacks, while this one picks a single random source
-- to verify all candidates at once.

function SmashnGrab:getVehicles(source)
    local slotsLeft = Config.SmashnGrab.Limit - self.persistentVehicleCount
    if slotsLeft <= 0 then return end

    local minDist    = Config.SmashnGrab.MinVehicleDistance
    local candidates = {}  -- netId → netId, deduped per-vehicle
    local dedupe     = {}  -- netId → bool, prevents double-registering
    local found      = 0

    for _, entity in ipairs(GetAllVehicles()) do
        if slotsLeft <= found then break end
        if not DoesEntityExist(entity) then goto nextVehicle end
        if GetIsVehicleEngineRunning(entity) then goto nextVehicle end

        local stateBag = getEntityStateBag(entity)
        local netId    = NetworkGetNetworkIdFromEntity(entity)

        if self.persistentVehicles[netId] then goto nextVehicle end

        local owner = NetworkGetEntityOwner(entity)
        -- ⚠️ Condition: owner ~= -1 then check HasVehicleBeenOwnedByPlayer.
        -- If owner IS -1, skip that check. Both paths are "valid" for selection.
        if owner ~= -1 then
            if HasVehicleBeenOwnedByPlayer(entity) then goto nextVehicle end
        end

        if stateBag and (stateBag:get("persistent") or isVehicleLooted(stateBag)) then
            goto nextVehicle
        end

        if Framework:vehicleChecks(netId, entity) then goto nextVehicle end

        do
            local coords = GetEntityCoords(entity)
            if isTooCloseToExisting(coords, minDist) then
                Trace("Vehicle too close to another persistent vehicle")
                goto nextVehicle
            end

            -- Also check against candidates already queued this pass
            for _, candidateNetId in pairs(candidates) do
                local candidateEntity = NetworkGetEntityFromNetworkId(candidateNetId)
                if candidateEntity then
                    local candidateCoords = GetEntityCoords(candidateEntity)
                    if #(coords - candidateCoords) < minDist then
                        goto nextVehicle
                    end
                end
            end

            if not dedupe[netId] then
                dedupe[netId]      = true
                candidates[netId]  = netId
                found = found + 1
            end
        end

        ::nextVehicle::
    end

    if Config.Debug then
        Trace("Vehicles found: " .. found)
    end
    if found < 1 then return end

    local randomSource = self:getRandomSource()
    if not randomSource then return end

    local response = TriggerClientCallback({
        source    = randomSource,
        eventName = eventName .. "client:verifyVehicles",
        args      = { candidates },
    })

    if not response or not response.status then
        Trace(response and response.message or "No response from client verify")
        return
    end

    local added   = 0
    for _, vehicleData in pairs(response.vehicles) do
        if slotsLeft <= added then break end

        local netId  = vehicleData.netId
        if self.persistentVehicles[netId] then goto nextResult end

        local entity = NetworkGetEntityFromNetworkId(netId)
        if not entity then goto nextResult end

        local coords = GetEntityCoords(entity)
        if isTooCloseToExisting(coords, minDist) then
            Trace("Skipping vehicle: too close to another persistent vehicle")
            goto nextResult
        end

        do
            Trace("Adding persistent vehicle: " .. tostring(GetEntityCoords(entity)))

            local assignedSource = self:getRandomSource()
            TriggerClientEvent(eventName .. "client:registerNetworkedEntity", assignedSource, netId, true)

            local uniqueId    = Main:generateUniqueId()
            local entityState = Entity(entity).state
            entityState:set("persistent", true, true)
            entityState:set("uniqueId",   uniqueId, true)

            if GetVehicleDoorLockStatus(entity) ~= 2 then
                SetVehicleDoorsLocked(entity, 2)
            end

            local loot = buildLootEntry(SelectRandomItem(Config.SmashnGrab.LootTables))

            self.persistentVehicles[netId] = {
                model    = vehicleData.model,
                coords   = GetEntityCoords(entity),
                heading  = GetEntityHeading(entity),
                uniqueId = uniqueId,
                seat     = vehicleData.seat,
                loot     = loot,
                owner    = assignedSource,
            }
            self.persistentVehicleCount = self.persistentVehicleCount + 1
            added = added + 1
        end

        ::nextResult::
    end

    Trace("persistentVehicles:", json.encode(self.persistentVehicles, { indent = true }))
    TriggerClientEvent(eventName .. "client:updatePersistentVehicles", -1, self.persistentVehicles)
    Trace("DATA SENT")
end

-- ─── Remove Persistent Vehicle ────────────────────────────────────────────────

function SmashnGrab:removePersistentVehicle(netId, uniqueId)
    local entity = NetworkGetEntityFromNetworkId(netId)
    if not entity or not DoesEntityExist(entity) then
        if self.persistentVehicles[netId] then
            self.persistentVehicles[netId] = nil
            decrPersistentCount()
        end
        Trace("Vehicle does not exist")
        return
    end

    table.insert(self.vehiclesToRemove, uniqueId)

    if self.persistentVehicles[netId] then
        self.persistentVehicles[netId] = nil
        decrPersistentCount()
    end
end

