while true do
    if Config and Config.Rappel then break end
    Citizen.Wait(50)
end

if not Config.Rappel.enabled then return end

local RappelCfg = Config.Rappel

Rappel = {}
Rappel.busy   = false
Rappel.active = false
Rappel.rope   = nil

-- ============================================================
--  Access check
-- ============================================================

local function hasJobAccess()
    if not RappelCfg.requireJob then return true end
    local job = Bridge.Framework.fetchPlayerJob()
    if not job then return false end
    return Config.Jobs[job.name] ~= nil
end

-- ============================================================
--  Heli / seat validation
--  Returns: heli entity (success) OR nil, localeKey (failure)
-- ============================================================

local function validateHeliSetup()
    local ped     = cache.ped
    local vehicle = GetVehiclePedIsIn(ped, false)

    if vehicle == 0 or not IsThisModelAHeli(GetEntityModel(vehicle)) then
        return nil, "rappel_no_point"
    end

    -- Pilot cannot rappel (must be in passenger seat)
    if GetPedInVehicleSeat(vehicle, -1) == ped then
        return nil, "rappel_pilot"
    end

    if not DoesVehicleAllowRappel(vehicle) then
        return nil, "rappel_heli_unsupported"
    end

    if GetEntityHeightAboveGround(vehicle) < RappelCfg.heli.minHeight then
        return nil, "rappel_heli_too_low"
    end

    -- If ped is in front-right seat (seat 0), move them to a rear seat
    if GetPedInVehicleSeat(vehicle, 0) == ped then
        local totalSeats = GetVehicleModelNumberOfSeats(GetEntityModel(vehicle)) - 2
        local moved = false
        for seat = 1, totalSeats do
            if IsVehicleSeatFree(vehicle, seat) then
                SetPedIntoVehicle(ped, vehicle, seat)
                moved = true
                break
            end
        end
        if not moved then return nil, "rappel_no_rear_seat" end
    end

    return vehicle
end

-- ============================================================
--  Begin rappel (called after server authorisation)
-- ============================================================

local function beginRappel(heli)
    TaskRappelFromHeli(cache.ped, false)
    Rappel.active = true

    CreateThread(function()
        -- Wait up to 3 s for rappelling to start
        local deadline = GetGameTimer() + 3000
        while GetGameTimer() < deadline do
            if IsAnyPedRappellingFromHeli(heli) then break end
            Wait(100)
        end

        if not IsAnyPedRappellingFromHeli(heli) then
            -- Rappel failed to initiate; refund item
            Rappel.active = false
            TriggerServerEvent("p_policejob/server/rappel/refund")
            Bridge.Notify.showNotify(locale("rappel_failed"), "error")
            return
        end

        Bridge.Notify.showNotify(locale("rappel_heli_started"), "inform")

        while IsAnyPedRappellingFromHeli(heli) do
            Wait(250)
        end

        Rappel.active = false
    end)
end

-- ============================================================
--  Main attempt entry point
-- ============================================================

function Rappel.attempt(self)
    if self.busy or self.active then return end

    if not hasJobAccess() then
        return Bridge.Notify.showNotify(locale("no_access"), "error")
    end

    local heli, errorKey = validateHeliSetup()
    if not heli then
        return Bridge.Notify.showNotify(locale(errorKey), "error")
    end

    if Bridge.Inventory.getItemCount(RappelCfg.item) < 1 then
        return Bridge.Notify.showNotify(locale("rappel_no_kit"), "error")
    end

    self.busy = true
    local authorised = lib.callback.await("p_policejob/server/rappel/authorize", false)
    self.busy = false

    if not authorised then return end
    beginRappel(heli)
end

-- ============================================================
--  Net events + exports
-- ============================================================

RegisterNetEvent("p_policejob/client/rappel/use", function()
    CreateThread(function() Rappel:attempt() end)
end)

exports("startRappel", function()
    CreateThread(function() Rappel:attempt() end)
end)

exports("isRappelling", function()
    return Rappel.active
end)
