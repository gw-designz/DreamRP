local voice = {}

local VOICE_MODE_COUNT = 3

local FALLBACK_HUD_DATA = {
    connected = false,
    isTalking = false,
    radioTalking = false,
    volume = 1,
    volumeCount = VOICE_MODE_COUNT,
    indicator = "",
}

local radioTalking = false

local function getIndicator()
    local radioChannel = LocalPlayer.state.radioChannel or 0
    local callChannel = LocalPlayer.state.callChannel or 0

    if radioChannel > 0 then
        return "radio"
    end

    if callChannel > 0 then
        return "phone"
    end

    return ""
end

local function getProximityVolume()
    local proximity = LocalPlayer.state.proximity

    if type(proximity) == "table" then
        if proximity.index then
            return proximity.index
        end

        if proximity.mode then
            return proximity.mode
        end
    end

    return 1
end

function voice.getProvider()
    return "pma-voice"
end

---@return VoiceHudData
function voice.getHudData()
    return {
        connected = MumbleIsConnected() == 1,
        isTalking = MumbleIsPlayerTalking(PlayerId()) == 1,
        radioTalking = radioTalking,
        volume = getProximityVolume(),
        volumeCount = VOICE_MODE_COUNT,
        indicator = getIndicator(),
    }
end

local function emitVoiceHudChanged()
    TriggerEvent("prp-bridge:client:voiceHudChanged", voice.getHudData())
end

if bridge.name == bridge.currentResource then
    AddEventHandler("pma-voice:radioActive", function(state)
        radioTalking = state == true
        emitVoiceHudChanged()
    end)

    AddEventHandler("pma-voice:setTalkingMode", function()
        emitVoiceHudChanged()
    end)

    AddStateBagChangeHandler("radioChannel", ("player:%s"):format(cache.serverId), function()
        emitVoiceHudChanged()
    end)

    AddStateBagChangeHandler("callChannel", ("player:%s"):format(cache.serverId), function()
        emitVoiceHudChanged()
    end)

    AddStateBagChangeHandler("proximity", ("player:%s"):format(cache.serverId), function()
        emitVoiceHudChanged()
    end)

    CreateThread(function()
        local lastPayload = nil

        while true do
            Wait(200)

            local payload = voice.getHudData()
            local encoded = json.encode(payload)

            if encoded ~= lastPayload then
                lastPayload = encoded
                TriggerEvent("prp-bridge:client:voiceHudChanged", payload)
            end

            ::continue::
        end
    end)
end

return voice
