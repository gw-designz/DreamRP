-- ============================================================
-- Crouch state bag handler + keybind
-- ============================================================

AddStateBagChangeHandler("crouch", ("player:%s"):format(cache.serverId), function(bagName, key, value, reserved, replicated)
    -- Debug: log current stealth state
    print(GetPedStealthMovement(PlayerPedId()))

    -- Exit stealth mode if active
    if GetPedStealthMovement(PlayerPedId()) then
        SetPedStealthMovement(PlayerPedId(), 0)
    end

    Wait(200)

    -- replicated == true means this fired on the sender's side; skip applying clipset
    if replicated then return end

    lib.requestAnimSet("move_Ped_crouched")

    if not value then
        -- Crouching disabled — restore default movement
        ResetPedMovementClipset(cache.ped, 1.0)
        ResetPedWeaponMovementClipset(cache.ped)
        ResetPedStrafeClipset(cache.ped)
        SetPedStealthMovement(cache.ped, false, "DEFAULT_ACTION")
    else
        -- Crouching enabled — apply crouch clipsets
        SetPedMovementClipset(cache.ped, "move_Ped_crouched", 1.0)
        SetPedStrafeClipset(cache.ped, "move_Ped_crouched_strafing")
    end

    RemoveAnimSet("move_Ped_crouched")
end)


-- Register crouch keybind if enabled in config
if Config.Crouch.enabled then
    lib.addKeybind({
        name        = "crouch",
        description = "Crouch",
        defaultKey  = Config.Crouch.keybind,
        onReleased  = function(self)
            -- Cannot crouch while in a vehicle
            if cache.vehicle then return end

            LocalPlayer.state:set("crouch", not LocalPlayer.state.crouch, false)
        end,
    })
end