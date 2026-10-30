-- Wait for Config to be available
while true do
    if Config and Config.Clamp then break end
    Citizen.Wait(500)
end

if not Config.Clamp.enabled then return end

Clamp = {}

-- ============================================================
--  Wheel clamp — apply or remove
-- ============================================================

RegisterNetEvent("p_policejob/server/clamp/setWheelClamp", function(data)
    local playerSource = source

    -- Validate incoming data
    if type(data) ~= "table" or not data.netId then return end

    local vehicle = NetworkGetEntityFromNetworkId(data.netId)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then return end

    -- Job access check
    local playerJob = Bridge.Framework.getPlayerJob(playerSource)
    if not Config.Jobs[playerJob.name] then
        return Bridge.Notify.showNotify(playerSource, locale("no_access"), "error")
    end

    local entityState = Entity(vehicle).state

    if data.state then
        -- Apply clamp
        if entityState.wheelClamp then return end  -- already clamped

        local clampCount = Bridge.Inventory.getItemCount(playerSource, "wheel_clamp")
        if clampCount < 1 then
            return Bridge.Notify.showNotify(playerSource, locale("no_wheel_clamp_item"), "error")
        end

        Bridge.Inventory.removeItem(playerSource, "wheel_clamp", 1)
        Bridge.Notify.showNotify(playerSource, locale("wheel_clamped"), "success")
    else
        -- Remove clamp
        if not entityState.wheelClamp then return end  -- not clamped

        Bridge.Inventory.addItem(playerSource, "wheel_clamp", 1)
        Bridge.Notify.showNotify(playerSource, locale("wheel_clamp_removed"), "success")
    end

    -- Sync state to all clients via state bag
    Entity(vehicle).state:set("wheelClamp", data.state, true)

    local action = data.state and "applied" or "removed"
    Bridge.Debug(("[Clamp] Player %s %s wheel clamp on netId %s"):format(playerSource, action, data.netId))

    if Config.Webhooks and Config.Webhooks.clamp then
        local playerName  = Bridge.Framework.getPlayerName(playerSource)
        local logAction   = data.state and "Applied" or "Removed"
        Bridge.Logs.Send(
            playerSource,
            "Clamp",
            ("%s wheel clamp on vehicle"):format(logAction),
            Config.Webhooks.clamp
        )
    end
end)
