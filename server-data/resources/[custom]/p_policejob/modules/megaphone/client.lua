if not Config.Megaphone.enabled then return end

-- Global Megaphone object shared across the resource
Megaphone = {
    isActive = false,
    props    = {},
    filter   = nil,
}

-- ─── Audio submix filter parameters ─────────────────────────────────────────
-- ⚠️ These are raw audio engine hash keys used by SetAudioSubmixEffectParamInt.
--    The values are intentional and must not be renamed without knowing their
--    engine meaning. Preserved verbatim from the original.
local SUBMIX_PARAMS = {
    [-455129387]  = 1,
    [-773893275]  = 300.0,
    [2006643436]  = 5000.0,
    [-688973352]  = 0.0,
    [-1383405282] = 0.2,
    [1634608902]  = 0.0,
    [1556538169]  = 550.0,
    [-1555401541] = 0.0,
}

-- ─── Exports ─────────────────────────────────────────────────────────────────

exports("isMegaphoneActive", function()
    return Megaphone.isActive
end)

exports("useMegaphone", function()
    Megaphone:use()
end)

-- ─── Submix Init Thread ───────────────────────────────────────────────────────

-- Creates and configures the audio submix filter for the megaphone effect
CreateThread(function()
    if not Config.Megaphone.enableSubmix then return end

    local filter = CreateAudioSubmix("Megaphone")
    Megaphone.filter = filter

    SetAudioSubmixEffectRadioFx(filter, 0)

    for paramHash, _ in pairs(SUBMIX_PARAMS) do
        SetAudioSubmixEffectParamInt(filter, 0, paramHash, 1)
    end

    AddAudioSubmixOutput(filter, 0)
end)

-- ─── Megaphone Methods ────────────────────────────────────────────────────────

-- Plays the megaphone hold animation on the local ped
function Megaphone:playAnim()
    local dict = lib.requestAnimDict("molly@megaphone")
    TaskPlayAnim(cache.ped, dict, "megaphone_clip", -8.0, 8.0, -1, 49, 1)
    RemoveAnimDict(dict)
end

-- Spawns the megaphone prop and attaches it to the given ped's right hand bone
function Megaphone:attachProp(pedEntity, propKey)
    local modelHash  = lib.requestModel("prop_megaphone_01")
    local propEntity = CreateObject(modelHash, GetEntityCoords(pedEntity), false, false, false)
    local boneIndex  = GetPedBoneIndex(pedEntity, 57005)

    AttachEntityToEntity(
        propEntity, pedEntity, boneIndex,
        0.1, 0.05, 0.0,
        -75.62, -19.44, -30.24,
        true, false, false, false, 0, true
    )

    SetModelAsNoLongerNeeded(modelHash)
    self.props[propKey] = propEntity
end

-- Deletes the megaphone prop for the given key if it exists
function Megaphone:removeProp(propKey)
    local entity = self.props[propKey]
    if entity and DoesEntityExist(entity) then
        DeleteEntity(entity)
        self.props[propKey] = nil
    end
end

-- Expands the player's voice proximity range via pma-voice or yaca-voice
function Megaphone:enableVoice()
    if GetResourceState("pma-voice") == "started" then
        exports["pma-voice"]:overrideProximityRange(Config.Megaphone.forceRange or 30.0, true)
    elseif GetResourceState("yaca-voice") == "started" then
        exports["yaca-voice"]:setCanUseMegaphone(true)
        exports["yaca-voice"]:useMegaphone(true)
    end
end

-- Restores the player's default voice proximity range
function Megaphone:disableVoice()
    if GetResourceState("pma-voice") == "started" then
        exports["pma-voice"]:clearProximityOverride()
    elseif GetResourceState("yaca-voice") == "started" then
        exports["yaca-voice"]:useMegaphone(false)
    end
end

-- Plays the animation, fires onStart, starts anim-keepalive and radius-marker threads
function Megaphone:startLocalLoop()
    self:playAnim()
    Config.Megaphone.onStart()

    -- Keepalive: re-plays the animation if it stops while active
    CreateThread(function()
        while self.isActive do
            Wait(1000)
            if self.isActive then
                if not IsEntityPlayingAnim(cache.ped, "molly@megaphone", "megaphone_clip", 3) then
                    self:playAnim()
                end
            end
        end
    end)

    -- Visual: shows a range sphere while G (control 47) is held
    local rangeRadius = Config.Megaphone.forceRange * 2.25
    CreateThread(function()
        while self.isActive do
            Wait(1)
            if IsControlPressed(0, 47) then
                local pos = GetEntityCoords(cache.ped)
                DrawMarker(
                    28,
                    pos.x, pos.y, pos.z,
                    0.0, 0.0, 0.0,
                    0.0, 0.0, 0.0,
                    rangeRadius, rangeRadius, rangeRadius,
                    255, 42, 24, 100,
                    false, false, 0, true, false, false, false
                )
            end
        end
        lib.hideTextUI()
    end)

    lib.showTextUI(locale("megaphone_radius"))
end

-- Toggles the megaphone on or off.
-- Checks job access when turning on; broadcasts state via player state bag.
function Megaphone:use()
    if not self.isActive then
        local job = Bridge.Framework.fetchPlayerJob()
        if not (Config.Jobs[job.name]) then
            return Bridge.Notify.showNotify(locale("extras_no_access"), "error")
        end
    end

    self.isActive = not self.isActive
    LocalPlayer.state:set("usingMegaphone", self.isActive, true)
end

-- ─── State Bag Handler ────────────────────────────────────────────────────────

-- Fires for any player whose "usingMegaphone" state bag changes.
-- A4_2 (isReserved) being true means it's a server-side bag — skip those.
AddStateBagChangeHandler("usingMegaphone", nil, function(bagName, _, newValue, _, isReserved)
    if isReserved then return end

    local playerHandle = GetPlayerFromStateBagName(bagName)
    if playerHandle == 0 then return end

    local playerPed      = GetPlayerPed(playerHandle)
    local playerServerId = GetPlayerServerId(playerHandle)
    local isLocalPlayer  = playerServerId == cache.serverId

    if not newValue then
        -- Megaphone turned OFF
        if isLocalPlayer then
            ClearPedTasks(playerPed)
            Megaphone:disableVoice()
            Config.Megaphone.onStop()
        end

        MumbleSetSubmixForServerId(playerServerId, -1)
        MumbleSetVolumeOverrideByServerId(playerServerId, -1.0)
        MumbleClearVoiceTargetPlayers(playerServerId)
        Megaphone:removeProp(playerServerId)
        return
    end

    -- Megaphone turned ON
    Wait(1)
    Megaphone:attachProp(playerPed, playerServerId)
    MumbleSetVolumeOverrideByServerId(playerServerId, 0.99)

    if Megaphone.filter then
        MumbleSetSubmixForServerId(playerServerId, Megaphone.filter)
    end

    if isLocalPlayer then
        Megaphone:enableVoice()
        Megaphone:startLocalLoop()
    end
end)

-- ─── Net Event ───────────────────────────────────────────────────────────────

RegisterNetEvent("p_policejob/client/megaphone/use", function()
    Megaphone:use()
end)
