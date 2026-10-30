if not (Config and Config.Interactions and Config.Interactions.MouthTape) then return end

MouthTape = {}
MouthTape.props    = {}
MouthTape.isActive = false

-- ============================================================
--  Voice muting helpers
-- ============================================================

local function muteVoice()
    if GetResourceState("pma-voice") == "started" then
        exports["pma-voice"]:overrideProximityCheck(function() return false end)
    elseif GetResourceState("yaca-voice") == "started" then
        exports["yaca-voice"]:setMaxVoiceRange(0.0)
    end
end

local function unmuteVoice()
    Wait(1000)
    if GetResourceState("pma-voice") == "started" then
        exports["pma-voice"]:resetProximityCheck()
    elseif GetResourceState("yaca-voice") == "started" then
        exports["yaca-voice"]:setMaxVoiceRange(-1)
    end
end

-- Starts a thread that mutes the local player every second while taped
local function startMuteThread()
    if MouthTape.isActive then return end
    MouthTape.isActive = true

    CreateThread(function()
        while MouthTape.isActive do
            Wait(1000)
            muteVoice()
        end
        unmuteVoice()
    end)
end

-- ============================================================
--  Prop management
-- ============================================================

function MouthTape.attachProp(self, identifier, ped)
    -- Remove existing prop if any
    if self.props[identifier] and DoesEntityExist(self.props[identifier]) then
        DeleteEntity(self.props[identifier])
    end

    local tapeCfg = Config.Interactions.MouthTape
    local model   = lib.requestModel(tapeCfg.model)
    local prop    = CreateObject(model, GetEntityCoords(ped), false, false, false)

    local boneIndex = GetPedBoneIndex(ped, tapeCfg.bone)
    AttachEntityToEntity(
        prop, ped, boneIndex,
        tapeCfg.coords, tapeCfg.rotation,
        true, true, false, true, 1, true)

    SetEntityAsMissionEntity(prop, true, true)
    SetModelAsNoLongerNeeded(model)
    SetEntityCollision(prop, true, false)

    self.props[identifier] = prop
end

function MouthTape.removeProp(self, identifier)
    local prop = self.props[identifier]
    if not prop then return end
    if DoesEntityExist(prop) then DeleteEntity(prop) end
    self.props[identifier] = nil
end

-- ============================================================
--  State bag — sync prop when mouthTaped changes
-- ============================================================

AddStateBagChangeHandler("mouthTaped", nil, function(bagName, _, newValue, _, wasDeleted)
    if wasDeleted then return end

    local playerHandle = GetPlayerFromStateBagName(bagName)
    if playerHandle == 0 then return end

    local ped        = GetPlayerPed(playerHandle)
    local identifier = GetPlayerServerId(playerHandle)

    if not newValue then
        MouthTape:removeProp(identifier)
        if cache.serverId == identifier then
            MouthTape.isActive = false
        end
        return
    end

    Wait(1)
    MouthTape:attachProp(identifier, ped)

    if cache.serverId == identifier then
        startMuteThread()
    end
end)

-- ============================================================
--  Exports
-- ============================================================

exports("isMouthTaped", function()
    return LocalPlayer.state.mouthTaped == true
end)

exports("setPlayerMouthTape", function(targetSource, state)
    TriggerServerEvent("p_policejob:mouthtape:toggleTape", {
        player = targetSource,
        state  = state,
    })
end)
