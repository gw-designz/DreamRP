-- Wait for Config to be available
while true do
    if Config and Config.Clamp then break end
    Citizen.Wait(500)
end

if not Config.Clamp.enabled then return end

Clamp = {}
Clamp.wheelClamps = {}  -- [netId] = propEntity

-- Excluded vehicle classes: Cycles(13), Boats(14), Helicopters(15), Planes(16), Bikes(21)
local EXCLUDED_VEHICLE_CLASSES = { 13, 14, 15, 16, 21 }

local PROGRESS_BAR_ANIM = {
    dict = "anim@amb@clubhouse@tutorial@bkr_tut_ig3@",
    clip = "machinic_loop_mechandplayer",
    flag = 1,
}

-- ============================================================
--  Checks
-- ============================================================

function Clamp.canApplyClamp(self, vehicle)
    if not DoesEntityExist(vehicle) then return false end

    local vehicleClass = GetVehicleClass(vehicle)
    if lib.table.contains(EXCLUDED_VEHICLE_CLASSES, vehicleClass) then return false end

    local clampCount = Bridge.Inventory.getItemCount("wheel_clamp") or 0
    if clampCount < 1 then return false end

    return not Entity(vehicle).state.wheelClamp
end

function Clamp.canRemoveClamp(self, vehicle)
    if not DoesEntityExist(vehicle) then return false end
    return Entity(vehicle).state.wheelClamp
end

-- ============================================================
--  Apply / Remove (with progress bar)
-- ============================================================

function Clamp.applyClamp(self, vehicle)
    if not self:canApplyClamp(vehicle) then return end

    local completed = lib.progressBar({
        duration     = 5000,
        label        = locale("clamping_wheel"),
        useWhileDead = false,
        canCancel    = true,
        disable      = { car = true, move = true, combat = true },
        anim         = PROGRESS_BAR_ANIM,
    })

    if not completed then
        Bridge.Notify.showNotify(locale("clamp_cancelled"), "error")
        return
    end

    if not DoesEntityExist(vehicle) then return end

    local netId = NetworkGetNetworkIdFromEntity(vehicle)
    if not netId or netId == 0 then return end

    TriggerServerEvent("p_policejob/server/clamp/setWheelClamp", { netId = netId, state = true })
end

function Clamp.removeClamp(self, vehicle)
    if not self:canRemoveClamp(vehicle) then return end

    local completed = lib.progressBar({
        duration     = 5000,
        label        = locale("removing_wheel_clamp"),
        useWhileDead = false,
        canCancel    = true,
        disable      = { car = true, move = true, combat = true },
        anim         = PROGRESS_BAR_ANIM,
    })

    if not completed then
        Bridge.Notify.showNotify(locale("clamp_cancelled"), "error")
        return
    end

    if not DoesEntityExist(vehicle) then return end

    local netId = NetworkGetNetworkIdFromEntity(vehicle)
    if not netId or netId == 0 then return end

    TriggerServerEvent("p_policejob/server/clamp/setWheelClamp", { netId = netId, state = false })
end

-- ============================================================
--  Prop management
-- ============================================================

function Clamp.attachProp(self, vehicle)
    if not DoesEntityExist(vehicle) then return end

    local netId = NetworkGetNetworkIdFromEntity(vehicle)
    if not netId or netId == 0 then return end

    -- Prop already exists and is valid
    if self.wheelClamps[netId] and DoesEntityExist(self.wheelClamps[netId]) then return end

    local propCfg     = Config.Clamp.Prop
    local ok, model   = pcall(lib.requestModel, propCfg.model)
    if not ok or not model then
        print(("[^1ERROR^7] [Clamp] Could not load clamp prop model '%s' - make sure the model is streamed (see modules/clamp/config.lua)."):format(tostring(propCfg.model)))
        return
    end

    local vehicleCoords = GetEntityCoords(vehicle)
    local prop = CreateObject(
        model,
        vehicleCoords.x, vehicleCoords.y, vehicleCoords.z - 3.0,
        false, false, false
    )

    local boneIndex = GetEntityBoneIndexByName(vehicle, propCfg.boneIndex)
    AttachEntityToEntity(
        prop, vehicle, boneIndex,
        propCfg.offset, propCfg.rotation,
        true, true, false, false, 2, true
    )

    SetEntityAsMissionEntity(prop, true, true)
    FreezeEntityPosition(prop, true, true)
    SetModelAsNoLongerNeeded(model)

    SetVehicleHandbrake(vehicle, true)
    SetVehicleDoorsLockedForAllPlayers(vehicle, true)

    self.wheelClamps[netId] = prop
    Config.Clamp.onWheelClamped(vehicle)
end

function Clamp.removeProp(self, vehicle)
    if not DoesEntityExist(vehicle) then return end

    local netId = NetworkGetNetworkIdFromEntity(vehicle)
    if not netId or netId == 0 then return end

    local prop = self.wheelClamps[netId]
    if not prop or not DoesEntityExist(prop) then return end

    SetVehicleHandbrake(vehicle, false)
    SetVehicleDoorsLockedForAllPlayers(vehicle, false)
    DeleteEntity(prop)

    self.wheelClamps[netId] = nil
    Config.Clamp.onWheelUnclamped(vehicle)
end

-- ============================================================
--  State bag — sync clamp prop when wheelClamp state changes
-- ============================================================

AddStateBagChangeHandler("wheelClamp", nil, function(bagName, _, newValue, _, wasDeleted)
    if wasDeleted then return end

    local vehicle = GetEntityFromStateBagName(bagName)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then return end

    if newValue then
        Clamp:attachProp(vehicle)
    else
        Clamp:removeProp(vehicle)
    end
end)

-- ============================================================
--  Cleanup loop — remove orphaned clamp props every 10 s
-- ============================================================

CreateThread(function()
    while true do
        Citizen.Wait(10000)
        for netId, prop in pairs(Clamp.wheelClamps) do
            local vehicle = NetworkGetEntityFromNetworkId(netId)
            if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then
                -- Vehicle is gone; clean up the prop
                if DoesEntityExist(prop) then
                    DeleteEntity(prop)
                end
                Clamp.wheelClamps[netId] = nil
            end
        end
    end
end)

-- ============================================================
--  Target options
-- ============================================================

CreateThread(function()
    -- ⚠️ Bridge.Target.addVehicle receives a raw entity OR a table with .entity
    -- depending on the target system. The original resolves this with a type check.
    local function resolveVehicleArg(arg)
        if type(arg) == "number" then return arg end
        return arg.entity
    end

    Bridge.Target.addVehicle({
        {
            name       = "p_policejob/clamp/apply",
            label      = locale("use_wheel_clamp"),
            icon       = "fa-solid fa-lock",
            distance   = 2.5,
            onSelect   = function(arg) Clamp:applyClamp(resolveVehicleArg(arg)) end,
            canInteract = function(arg) return Clamp:canApplyClamp(arg) end,
        },
        {
            name       = "p_policejob/clamp/remove",
            label      = locale("remove_wheel_clamp"),
            icon       = "fa-solid fa-unlock",
            distance   = 2.5,
            onSelect   = function(arg) Clamp:removeClamp(resolveVehicleArg(arg)) end,
            canInteract = function(arg) return Clamp:canRemoveClamp(arg) end,
        },
    })
end)

-- ============================================================
--  Exports
-- ============================================================

exports("applyWheelClamp", function(vehicle)
    if Clamp:canApplyClamp(vehicle) then
        Clamp:applyClamp(vehicle)
    end
end)

exports("removeWheelClamp", function(vehicle)
    if Clamp:canRemoveClamp(vehicle) then
        Clamp:removeClamp(vehicle)
    end
end)
