if not Config.Band.Enabled then return end

Band = {}
Band.props       = {}
Band.blips       = {}
Band.isTracking  = false

-- ============================================================
--  Exports
-- ============================================================

exports("isBandTracking", function()
    return Band.isTracking
end)

exports("SetPlayerBand", function(targetSource, state)
    TriggerServerEvent("p_policejob/server/band/SetPlayerBand", {
        player = targetSource,
        state  = state,
    })
end)

exports("RemovePlayerBand", function(targetSource)
    TriggerServerEvent("p_policejob/server/band/SetPlayerBand", {
        player = targetSource,
        state  = false,
    })
end)

-- ============================================================
--  Prop management
-- ============================================================

function Band.attachProp(self, identifier, ped)
    -- Delete any existing prop for this identifier first
    if self.props[identifier] and DoesEntityExist(self.props[identifier]) then
        DeleteEntity(self.props[identifier])
    end

    local model  = Config.Band.Prop.model
    local propCfg = Config.Band.Prop

    lib.requestModel(model)

    local spawnCoords = GetEntityCoords(ped)
    local prop        = CreateObject(model, spawnCoords, false, false, false)
    local boneIndex   = GetPedBoneIndex(ped, 14201)

    AttachEntityToEntity(
        prop, ped, boneIndex,
        propCfg.coords, propCfg.rotation,
        true, true, false, true, 1, true
    )

    SetModelAsNoLongerNeeded(model)
    SetEntityCollision(prop, true, false)

    self.props[identifier] = prop

    if identifier == cache.serverId then
        Config.Band.onAttach()
    end
end

function Band.removeProp(self, identifier)
    local prop = self.props[identifier]
    if prop and DoesEntityExist(prop) then
        DeleteEntity(prop)
        self.props[identifier] = nil
    end

    if identifier == cache.serverId then
        Config.Band.onRemove()
    end
end

-- ============================================================
--  Blip management
-- ============================================================

function Band.createBlip(self, identifier, bandData)
    if not bandData.online or not bandData.coords then return end

    self:removeBlip(identifier)

    self.blips[identifier] = {}
    local blipEntry = self.blips[identifier]
    local blipCfg   = Config.Band.Blip
    local coords    = bandData.coords

    -- Primary blip
    local primaryBlip = AddBlipForCoord(coords.x, coords.y, coords.z)
    blipEntry.first   = primaryBlip

    SetBlipScale(primaryBlip,    blipCfg.scale    or 1.1)
    SetBlipSprite(primaryBlip,   blipCfg.sprite   or 1)
    SetBlipCategory(primaryBlip, blipCfg.category or 3)
    SetBlipShrink(primaryBlip,   blipCfg.shrink   ~= nil and blipCfg.shrink or true)
    SetBlipPriority(primaryBlip, blipCfg.priority or 3)
    ShowHeightOnBlip(primaryBlip, blipCfg.height  or false)
    SetBlipColour(primaryBlip,   blipCfg.color    or 76)

    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString(bandData.name or "Unknown")
    EndTextCommandSetBlipName(primaryBlip)

    -- Optional pulse blip
    if blipCfg.pulse then
        local pulseBlip   = AddBlipForCoord(coords.x, coords.y, coords.z)
        blipEntry.second  = pulseBlip
        SetBlipSprite(pulseBlip,  161)
        SetBlipScale(pulseBlip,   1.0)
        SetBlipColour(pulseBlip,  blipCfg.color or 76)
        PulseBlip(pulseBlip)
    end

    -- Optional heading indicator
    if blipCfg.heading and bandData.heading then
        ShowHeadingIndicatorOnBlip(primaryBlip, true)
        SetBlipRotation(primaryBlip, bandData.heading)
    end
end

function Band.removeBlip(self, identifier)
    local blipEntry = self.blips[identifier]
    if not blipEntry then return end

    if blipEntry.first  then RemoveBlip(blipEntry.first)  end
    if blipEntry.second then RemoveBlip(blipEntry.second) end

    self.blips[identifier] = nil
end

function Band.removeAllBlips(self)
    for identifier in pairs(self.blips) do
        self:removeBlip(identifier)
    end
end

-- ============================================================
--  Tracking
-- ============================================================

function Band.updateBlips(self)
    local playersWithBand = GlobalState.playersWithBand
    if not playersWithBand then return end

    for identifier, bandData in pairs(playersWithBand) do
        if bandData.coords and bandData.online then
            self:createBlip(identifier, bandData)
        else
            self:removeBlip(identifier)
        end
    end
end

function Band.startTracking(self)
    if self.isTracking then return end
    self.isTracking = true

    CreateThread(function()
        while self.isTracking do
            self:updateBlips()
            Wait(Config.Band.LoopRate)
        end
    end)

    if Bridge and type(Bridge.Debug) == "function" then
        Bridge.Debug("[Band] Started tracking")
    end
end

function Band.stopTracking(self)
    if not self.isTracking then return end
    self.isTracking = false
    self:removeAllBlips()
    Bridge.Debug("[Band] Stopped tracking")
end

-- ============================================================
--  Job access check
-- ============================================================

function Band.checkJobAccess(self)
    if not Bridge.Framework.isPlayerLoaded() then return false end

    local job = Bridge.Framework.fetchPlayerJob()
    if not job then return false end

    return Config.Jobs[job.name] ~= nil
end

-- ============================================================
--  Tracking loop — polls job access every 2.5 s
-- ============================================================

CreateThread(function()
    while true do
        Wait(2500)
        if Band:checkJobAccess() then
            if not Band.isTracking then
                Band:startTracking()
            end
        else
            if Band.isTracking then
                Band:stopTracking()
            end
        end
    end
end)

-- ============================================================
--  State bag — attach / remove prop when hasTrackingBand changes
-- ============================================================

AddStateBagChangeHandler("hasTrackingBand", nil, function(bagName, _, newValue, _, wasDeleted)
    if wasDeleted then return end

    local playerHandle = GetPlayerFromStateBagName(bagName)
    if playerHandle == 0 then return end

    local ped        = GetPlayerPed(playerHandle)
    local identifier = GetPlayerServerId(playerHandle)

    if not newValue then
        Band:removeProp(identifier)
        return
    end

    Wait(1)
    Band:attachProp(identifier, ped)
end)

-- ============================================================
--  Net events
-- ============================================================

RegisterNetEvent("p_policejob/client/band/SetPlayerBand", function(state)
    LocalPlayer.state:set("hasTrackingBand", state, true)
end)

RegisterNetEvent("p_policejob/client/band/RemoveBandBlip", function(data)
    Band:removeBlip(data.id)
end)
