-- pma-voice integration: proximity range (1 whisper, 2 normal, 3 shout), talking, radio
-- transmit and the joined radio channel (drives the purple radio circle).

local voice = { range = 2, talking = false, radio = false, channel = 0 }

local function setRange(index)
    voice.range = Hud.clamp(tonumber(index) or 2, 1, 3)
end

AddEventHandler('pma-voice:setTalkingMode', setRange)

AddEventHandler('pma-voice:radioActive', function(active)
    voice.radio = active == true
end)

CreateThread(function()
    local proximity = LocalPlayer.state.proximity
    if proximity and proximity.index then setRange(proximity.index) end

    local playerId = PlayerId()
    while true do
        if Hud.visible then
            voice.talking = NetworkIsPlayerTalking(playerId) or voice.radio
            voice.channel = tonumber(LocalPlayer.state.radioChannel) or 0
            Hud.push('voice', voice)
            Wait(Hud.tick('voice'))
        else
            Wait(500)
        end
    end
end)
