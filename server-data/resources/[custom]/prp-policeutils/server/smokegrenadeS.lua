local lastTriggerTime = {} ---@type table<string, number>
local triggerTimeThreshold <const> = 2000
local distanceTreshold <const> = 50.0
local vehicleDistanceThreshold <const> = 150.0

RegisterNetEvent("prp-policeutils:client:smokeExp", function(grenadeCoords, weaponName)
    local src = source
    local srcStr = tostring(src)
    lastTriggerTime[srcStr] = lastTriggerTime[srcStr] or 0
    local currentTime = GetGameTimer()
    local identifiers = GetPlayerIdentifiers(src)

    if currentTime - lastTriggerTime[srcStr] < triggerTimeThreshold then
        bridge.log.send(GrenadeLogWebhook, "Smoke Grenade Exploit Attempt", ("Player with serverId: %s attempted to trigger smoke grenade effects too rapidly.\nIdentifiers: %s"):format(srcStr, json.encode(identifiers, {indent = true})))
        return
    end
    lastTriggerTime[srcStr] = currentTime

    local playerPed = GetPlayerPed(src)
    if not DoesEntityExist(playerPed) then return end

    local playerCoords = GetEntityCoords(playerPed)
    local playerVehicle = GetVehiclePedIsIn(playerPed, false)
    local isInVehicle = DoesEntityExist(playerVehicle)
    local distance = #(playerCoords - grenadeCoords)

    if isInVehicle then
        if distance > vehicleDistanceThreshold then return end
    else
        if distance > distanceTreshold then return end
    end

    bridge.log.send(GrenadeLogWebhook, "Smoke Grenade Detonated", ("Player with serverId: %s triggered smoke grenade effects.\nWeapon: %s\nDistance from explosion: %.2f\nIdentifiers: %s"):format(srcStr, weaponName, distance, json.encode(identifiers, {indent = true})))

    Scopes.TriggerScopeEvent("prp-policeutils:client:smokeExplode", src, grenadeCoords, weaponName)
end)

AddEventHandler("playerDropped", function()
    local src = source
    local srcStr = tostring(src)
    lastTriggerTime[srcStr] = nil
end)