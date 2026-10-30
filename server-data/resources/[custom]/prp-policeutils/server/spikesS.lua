local ActiveSpikes = {}

local function hasJob(source)
    for _, job in pairs(Spikes.RequiredJobs) do
        if bridge.fw.hasJob(source, job, nil, true) then
            return true
        end
    end

    return false
end

bridge.fw.registerItemUse(Spikes.Items.box, function(source, data)
    local item = bridge.inv.getSlot(source, data.slot)
    if not item then return false end

    if Spikes.RequiredJobs and #Spikes.RequiredJobs > 0 and not hasJob(source) then
        bridge.fw.notify(source, 'error', locale("NO_JOB"))
        return false
    end

    local status, coords = lib.callback.await("prp-policeutils:placeSpikeStrip", source)
    if not status then return false end
    if not coords then return false, locale("SOMETHING_WENT_WRONG") end

    local removed = bridge.inv.removeItem(source, Spikes.Items.box, 1, nil, data.slot)
    if not removed then return false, locale("SOMETHING_WENT_WRONG") end

    local uuid = GenerateUUID()
    local success = bridge.inv.giveItem(source, Spikes.Items.pilot, 1, { spikeUUID = uuid })
    if success then
        ActiveSpikes[uuid] = {
            coords = coords,
            uuid = uuid,
            active = false,
            owner = bridge.fw.getIdentifier(source)
        }
        TriggerClientEvent("prp-policeutils:client:placeSpikeStrip", -1, uuid,
            ActiveSpikes[uuid])
    end

    return true
end)

bridge.fw.registerItemUse(Spikes.Items.pilot, function(source, data)
    local item = bridge.inv.getSlot(source, data.slot)
    if not item then return false end

    if not item.metadata or not item.metadata?.spikeUUID then
        bridge.inv.removeItem(source, Spikes.Items.pilot, 1, data.metaData)
        return false, locale("SPIKE_STRIP_NOT_FOUND")
    end

    local spikeData = ActiveSpikes[item.metadata.spikeUUID]
    if not spikeData then
        bridge.inv.removeItem(source, Spikes.Items.pilot, 1, item.metadata)
        return false, locale("SPIKE_STRIP_NOT_FOUND")
    end

    TriggerClientEvent("prp-policeutils:client:toggleSpikeStripAnim", source);
    Citizen.Wait(500)
    TriggerClientEvent(
        "prp-bridge:sound:playSpatial",
        -1,
        "unmute.ogg",
        0.2,
        GetEntityCoords(GetPlayerPed(source)),
        20.0
    )

    local distance = #(GetEntityCoords(GetPlayerPed(source)) - spikeData.coords.xyz)
    if distance > Spikes.Range.pilotControl then
        return false, locale("TOO_FAR_FROM_SPIKE_STRIP")
    end
    if spikeData.active then
        spikeData.active = false
    else
        spikeData.active = true
    end
    TriggerClientEvent("prp-policeutils:client:toggleSpikeStrip", -1, item.metadata.spikeUUID, spikeData.active)
    return true
end)

RegisterNetEvent("prp-policeutils:server:pickupSpikeStrip", function(uuid)
    local source = source
    if not hasJob(source) then return end

    if ActiveSpikes[uuid] then
        ActiveSpikes[uuid] = nil
        local status, coords = lib.callback.await("prp-policeutils:placeSpikeStrip", source, true)
        if not status then return false end

        bridge.inv.removeItem(source, Spikes.Items.pilot, 1, { spikeUUID = uuid })
        bridge.inv.giveItem(source, Spikes.Items.box, 1)
        TriggerClientEvent("prp-policeutils:client:removeSpikeStrip", -1, uuid)
    end
end)

RegisterNetEvent("prp-policeutils:server:breakSpikeStrip", function(uuid)
    if ActiveSpikes[uuid] then
        ActiveSpikes[uuid] = nil
        TriggerClientEvent("prp-policeutils:client:removeSpikeStrip", -1, uuid)
    end
end)

lib.callback.register("prp-policeutils:getSpikes", function(src)
    return ActiveSpikes
end)
