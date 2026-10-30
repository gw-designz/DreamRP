if not Config.Trunks.enabled then return end

Trunks = {}
Trunks.isActive = false
Trunks.entity   = nil
Trunks.cam      = nil
Trunks.angle    = 0   -- used by dynamic camera mode

-- ============================================================
--  Exports
-- ============================================================

exports("inTrunk",    function() return Trunks.isActive end)
exports("enterTrunk", function(entity) Trunks:enter(entity) end)
exports("exitTrunk",  function() Trunks:exit() end)
exports("TrunkEditor",function() Trunks:openEditor() end)

-- ============================================================
--  Idle animation (played while inside trunk)
-- ============================================================

local function playTrunkIdle()
    local animDict = lib.requestAnimDict("fin_ext_p1-7")
    TaskPlayAnim(cache.ped, animDict, "cs_devin_dual-7",
        -8.0, 8.0, -1, 0, 0, 0, 0, 0)
    RemoveAnimDict(animDict)
end

-- ============================================================
--  Camera: create / destroy
-- ============================================================

function Trunks.createCamera(self)
    self.cam = CreateCam("DEFAULT_SCRIPTED_CAMERA", true)
    SetCamActive(self.cam, true)
    RenderScriptCams(true, true, 500, true, false)
    SetCamFov(self.cam, 60.0)
    ClearPedTasks(cache.ped)

    if Config.Trunks.cameraType == "dynamic" then
        self:dynamicCameraLoop()
    elseif Config.Trunks.cameraType == "static" then
        self:staticCameraLoop()
    end
end

function Trunks.destroyCamera(self)
    if not self.cam or not DoesCamExist(self.cam) then return end
    DestroyCam(self.cam, false)
    RenderScriptCams(false, true, 500, true, false)
    self.cam = nil
end

-- ============================================================
--  Camera loops
-- ============================================================

-- Dynamic: orbits around the trunk; mouse X-axis rotates the view.
function Trunks.dynamicCameraLoop(self)
    CreateThread(function()
        while true do
            if not self.isActive then break end

            if not self.entity or not DoesEntityExist(self.entity) then
                self:destroyCamera()
                break
            end

            DisableAllControlActions(0)

            if not IsEntityPlayingAnim(cache.ped, "fin_ext_p1-7", "cs_devin_dual-7", 3) then
                playTrunkIdle()
            end

            -- Backspace (73) exits trunk
            if IsDisabledControlJustReleased(0, 73) then
                self:exit()
                break
            end

            -- Rotate camera with mouse X (control 1)
            self.angle = self.angle + GetDisabledControlNormal(0, 1) * 2.5

            local entityCoords = GetEntityCoords(self.entity)
            local dist    = 4.0
            local camX    = entityCoords.x + math.cos(math.rad(self.angle)) * dist
            local camY    = entityCoords.y + math.sin(math.rad(self.angle)) * dist
            local camZ    = entityCoords.z + 1.25

            SetCamCoord(self.cam, camX, camY, camZ)
            PointCamAtCoord(self.cam,
                entityCoords.x, entityCoords.y, entityCoords.z + 0.5)

            Wait(0)
        end
    end)
end

-- Static: fixed offset behind the vehicle.
function Trunks.staticCameraLoop(self)
    CreateThread(function()
        while true do
            if not self.isActive then break end

            if not self.entity or not DoesEntityExist(self.entity) then
                self:destroyCamera()
                break
            end

            DisableAllControlActions(0)

            if not IsEntityPlayingAnim(cache.ped, "fin_ext_p1-7", "cs_devin_dual-7", 3) then
                playTrunkIdle()
            end

            -- Backspace (73) exits trunk
            if IsDisabledControlJustReleased(0, 73) then
                self:exit()
                break
            end

            local entityCoords = GetEntityCoords(self.entity)
            local camOffset    = GetOffsetFromEntityInWorldCoords(self.entity, 0.0, -4.5, 1.25)

            SetCamCoord(self.cam, camOffset)
            PointCamAtCoord(self.cam,
                entityCoords.x, entityCoords.y, entityCoords.z + 0.5)

            Wait(0)
        end
    end)
end

-- ============================================================
--  canInteract
--  A2_2 = true  → "can the player GET IN?" (checks occupancy + locks)
--  A2_2 = false → "can the player GET OUT?" (checks currently inside this vehicle)
-- ============================================================

function Trunks.canInteract(self, entity, wantToEnter)
    if cache.vehicle then return false end
    if not NetworkGetEntityIsNetworked(entity) then return false end

    if not wantToEnter then
        -- Exit check: is this the vehicle we're currently in?
        return self.isActive and self.entity == entity
    end

    -- Entry checks
    if self.isActive then return false end

    local netId = NetworkGetNetworkIdFromEntity(entity)
    local occupiedTrunks = GlobalState["p_policejob:occupiedTrunks"]
    if occupiedTrunks and occupiedTrunks[netId] then return false end

    if Config.Trunks.checkVehicleLocks then
        if GetVehicleDoorLockStatus(entity) >= 2 then return false end
    end

    if Config.Trunks.checkTrunkState then
        if GetVehicleDoorAngleRatio(entity, 5) < 0.1 then return false end
    end

    return true
end

-- ============================================================
--  enter
-- ============================================================

function Trunks.enter(self, entity)
    if self.isActive then return end

    if not entity then
        entity = lib.getClosestVehicle(GetEntityCoords(cache.ped), 3.5, true)
    end
    if not entity or entity == 0 then return end

    -- Mark trunk as occupied on server
    local netId = NetworkGetNetworkIdFromEntity(entity)
    TriggerServerEvent("p_policejob/server/trunks/setOccupied", netId, true)

    self.isActive = true
    self.entity   = entity

    -- Resolve vehicle model name for offset lookup
    local modelName  = string.lower(GetDisplayNameFromVehicleModel(GetEntityModel(entity)))
    local offsetCfg  = Config.Trunks.offsets[modelName] or Config.Trunks.defaultOffset
    local min, max   = GetModelDimensions(GetEntityModel(entity))

    AttachEntityToEntity(
        cache.ped, entity, 0,
        offsetCfg.coords.x,
        min.y + offsetCfg.coords.y,
        max.z + offsetCfg.coords.z,
        offsetCfg.rotation.x, offsetCfg.rotation.y, offsetCfg.rotation.z,
        1, 1, 1, 1, 1, 1)

    playTrunkIdle()
    Config.Trunks.onEnter()

    if Config.Trunks.cameraType ~= "game" then
        self:createCamera()
    end

    SendNUIMessage({ action = "setVisibleTrunk", data = true })
end

-- ============================================================
--  exit
-- ============================================================

function Trunks.exit(self)
    if not self.entity then return end

    local netId    = NetworkGetNetworkIdFromEntity(self.entity)
    local exitPos  = GetOffsetFromEntityInWorldCoords(self.entity, 0.0, -3.25, 0.0)

    TriggerServerEvent("p_policejob/server/trunks/setOccupied", netId, false)
    self:destroyCamera()
    DetachEntity(cache.ped)
    ClearPedTasks(cache.ped)
    SetEntityCoords(cache.ped, exitPos)

    self.isActive = false
    self.entity   = nil

    Config.Trunks.onExit()
    SendNUIMessage({ action = "setVisibleTrunk", data = false })
end

-- ============================================================
--  Net events
-- ============================================================

RegisterNetEvent("p_policejob/client/trunks/enter", function(entity)
    Trunks:enter(entity)
end)

RegisterNetEvent("p_policejob/client/trunks/exit", function()
    Trunks:exit()
end)

-- Push updated offsets from server (after editor save)
RegisterNetEvent("p_policejob/client/trunks/refreshOffsets", function(newOffsets)
    for modelName, offsetData in pairs(newOffsets) do
        Config.Trunks.offsets[modelName] = offsetData
    end
end)

-- ============================================================
--  Load saved offsets from trunks.json (client-side copy)
-- ============================================================

CreateThread(function()
    Wait(1000)
    local raw = LoadResourceFile(GetCurrentResourceName(), "trunks.json")
    if not raw then return end
    local decoded = json.decode(raw)
    if not decoded then return end
    for modelName, offsetData in pairs(decoded) do
        Config.Trunks.offsets[modelName] = offsetData
    end
end)

-- ============================================================
--  Target options
-- ============================================================

CreateThread(function()
    Bridge.Target.addVehicle({
        -- Get in trunk
        {
            name     = "p_policejob/trunks/enter",
            label    = locale("get_in_trunk"),
            icon     = "fa-solid fa-car",
            distance = 2,
            onSelect = function(arg)
                local entity = type(arg) == "number" and arg or arg.entity
                Trunks:enter(entity)
            end,
            canInteract = function(arg)
                return Trunks:canInteract(arg, true)
            end,
        },
        -- Get out of trunk
        {
            name     = "p_policejob/trunks/exit",
            label    = locale("get_out_trunk"),
            icon     = "fa-solid fa-car",
            distance = 2,
            onSelect = function()
                Trunks:exit()
            end,
            canInteract = function(arg)
                return Trunks:canInteract(arg, false)
            end,
        },
        -- Take player out of trunk (officer action)
        {
            name     = "p_policejob/trunks/takeOut",
            label    = locale("take_player_out_trunk"),
            icon     = "fa-solid fa-car",
            distance = 2,
            onSelect = function(arg)
                local entity = type(arg) == "number" and arg or arg.entity
                if not NetworkGetEntityIsNetworked(entity) then return end
                local netId = NetworkGetNetworkIdFromEntity(entity)
                TriggerServerEvent("p_policejob/server/trunks/takeOut", netId)
            end,
            canInteract = function(arg)
                if not NetworkGetEntityIsNetworked(arg) then return false end
                local netId          = NetworkGetNetworkIdFromEntity(arg)
                local occupiedTrunks = GlobalState["p_policejob:occupiedTrunks"]
                if not occupiedTrunks then return false end
                local occupant = occupiedTrunks[netId]
                -- Show only if someone else is in this trunk
                return occupant ~= nil and occupant ~= cache.serverId
            end,
        },
    })
end)

-- ============================================================
--  Trunk editor
-- ============================================================

function Trunks.openEditor(self)
    local pedCoords     = GetEntityCoords(cache.ped)
    local vehicle       = lib.getClosestVehicle(pedCoords, 10.0, true)
    if not vehicle or vehicle == 0 then
        return Bridge.Notify.showNotify(locale("no_closest_vehicle"), "error")
    end

    local min, max      = GetModelDimensions(GetEntityModel(vehicle))
    local vehicleCoords = GetEntityCoords(vehicle)
    local def           = Config.Trunks.offsets[string.lower(GetDisplayNameFromVehicleModel(GetEntityModel(vehicle)))] or Config.Trunks.defaultOffset
    local offsetCoords  = vector3(def.coords.x, def.coords.y, def.coords.z)
    local offsetRot     = vector3(def.rotation.x, def.rotation.y, def.rotation.z)
    local isEditing     = true

    -- Editor scripted camera (static, looking into trunk)
    local editorCam = CreateCam("DEFAULT_SCRIPTED_CAMERA", true)
    SetCamActive(editorCam, true)
    RenderScriptCams(true, true, 500, true, false)
    SetCamFov(editorCam, 60.0)

    local camOffset = GetOffsetFromEntityInWorldCoords(vehicle, 0.0, -4.5, 1.25)
    SetCamCoord(editorCam, camOffset)
    PointCamAtCoord(editorCam,
        vehicleCoords.x, vehicleCoords.y, vehicleCoords.z + 0.5)

    -- Attach ped to vehicle with current offset
    local function reattach()
        AttachEntityToEntity(
            cache.ped, vehicle, 0,
            offsetCoords.x,
            min.y + offsetCoords.y,
            max.z + offsetCoords.z,
            offsetRot.x, offsetRot.y, offsetRot.z,
            1, 1, 1, 1, 1, 1)
    end

    reattach()

    SendNUIMessage({ action = "setVisibleTrunkEditor", data = true })

    -- Close editor: detach ped, teleport slightly below camera, destroy cam
    local function closeEditor()
        isEditing = false
        Wait(10)
        DetachEntity(cache.ped)
        SetEntityCoords(cache.ped, camOffset.x, camOffset.y, camOffset.z - 1.0)
        ClearPedTasks(cache.ped)
        RenderScriptCams(false, true, 500, true, false)
        DestroyCam(editorCam)
        SendNUIMessage({ action = "setVisibleTrunkEditor", data = false })
    end

    -- Key bindings for coord/rotation adjustments
    -- Format: { key = controlId, action = function() }
    local keyBindings = {
        { key = 34,  action = function() offsetCoords = vector3(offsetCoords.x - 0.1, offsetCoords.y, offsetCoords.z) end },  -- Left  → X-
        { key = 35,  action = function() offsetCoords = vector3(offsetCoords.x + 0.1, offsetCoords.y, offsetCoords.z) end },  -- Right → X+
        { key = 244, action = function() offsetCoords = vector3(offsetCoords.x, offsetCoords.y - 0.1, offsetCoords.z) end },  -- Num4  → Y-
        { key = 249, action = function() offsetCoords = vector3(offsetCoords.x, offsetCoords.y + 0.1, offsetCoords.z) end },  -- Num6  → Y+
        { key = 32,  action = function() offsetCoords = vector3(offsetCoords.x, offsetCoords.y, offsetCoords.z + 0.1) end },  -- Up   → Z+
        { key = 33,  action = function() offsetCoords = vector3(offsetCoords.x, offsetCoords.y, offsetCoords.z - 0.1) end },  -- Down → Z-
        { key = 44,  action = function() offsetRot = vector3(offsetRot.x - 10.0, offsetRot.y, offsetRot.z) end },             -- Q → Rx-
        { key = 45,  action = function() offsetRot = vector3(offsetRot.x + 10.0, offsetRot.y, offsetRot.z) end },             -- E → Rx+
        { key = 23,  action = function() offsetRot = vector3(offsetRot.x, offsetRot.y - 10.0, offsetRot.z) end },             -- Enter → Ry-
        { key = 47,  action = function() offsetRot = vector3(offsetRot.x, offsetRot.y + 10.0, offsetRot.z) end },             -- G  → Ry+
        { key = 26,  action = function() offsetRot = vector3(offsetRot.x, offsetRot.y, offsetRot.z - 10.0) end },             -- K  → Rz-
        { key = 236, action = function() offsetRot = vector3(offsetRot.x, offsetRot.y, offsetRot.z + 10.0) end },             -- Ins → Rz+
    }

    CreateThread(function()
        while isEditing do
            DisableAllControlActions(0)

            if not IsEntityPlayingAnim(cache.ped, "fin_ext_p1-7", "cs_devin_dual-7", 3) then
                playTrunkIdle()
            end

            -- Backspace (73) = cancel
            if IsDisabledControlJustReleased(0, 73) then
                closeEditor()
                break
            end

            -- E / control 38 = confirm + save
            if IsDisabledControlJustReleased(0, 38) then
                local modelName = string.lower(GetDisplayNameFromVehicleModel(GetEntityModel(vehicle)))
                TriggerServerEvent("p_policejob/server/trunks/save", {
                    coords   = offsetCoords,
                    rotation = offsetRot,
                    model    = modelName,
                })
                Wait(1000)
                closeEditor()
                break
            end

            -- Adjustment keys
            for _, binding in ipairs(keyBindings) do
                if IsDisabledControlJustReleased(0, binding.key) then
                    binding.action()
                    reattach()
                end
            end

            Wait(0)
        end
    end)
end

-- ============================================================
--  Commands
-- ============================================================

RegisterCommand("trunk_editor", function() Trunks:openEditor() end)

RegisterCommand("entertrunk", function()
    local vehicle = lib.getClosestVehicle(GetEntityCoords(cache.ped), 5.0, true)
    if not vehicle or vehicle == 0 then return end
    if not Trunks:canInteract(vehicle, true) then return end
    Trunks:enter(vehicle)
end)

RegisterCommand("exittrunk", function()
    if not Trunks.isActive then return end
    Trunks:exit()
end)
