local pma = exports["pma-voice"]
local mumble = exports["mumble-voip"]
local toko = exports["tokovoip_script"]

local function exportHandler(resource, name, cb)
    AddEventHandler(('__cfx_export_%s_%s'):format(resource, name), function(setCB)
        setCB(cb)
    end)
end

function AddPlayerToCall(callId)
    debugPrint("Add player to call with call id: ", callId)

    if Config.Voice.System == "pma" then
        pma:addPlayerToCall(callId)
    elseif Config.Voice.System == "mumble" then
        mumble:addPlayerToCall(callId)
    elseif Config.Voice.System == "salty" then
        TriggerServerEvent("voice:add-to-call", callId)
    elseif Config.Voice.System == "toko" then
        toko:addPlayerToRadio(callId)
    end
end

exports("AddPlayerToCall", AddPlayerToCall)
exportHandler('yseries', 'AddPlayerToCall', AddPlayerToCall)

function RemovePlayerFromCall(callId)
    debugPrint("Remove player from call with call id: ", callId)

    if Config.Voice.System == "pma" then
        pma:removePlayerFromCall()
    elseif Config.Voice.System == "mumble" then
        mumble:removePlayerFromCall()
    elseif Config.Voice.System == "salty" then
        TriggerServerEvent("voice:remove-from-call", callId)
    elseif Config.Voice.System == "toko" then
        toko:removePlayerFromRadio(callId)
    end
end

exports("RemovePlayerFromCall", RemovePlayerFromCall)
exportHandler('yseries', 'RemovePlayerFromCall', RemovePlayerFromCall)

function SetCallVolume(volumePercent)
    debugPrint("Set call volume: ", volumePercent)

    if Config.Voice.System == "pma" then
        pma:setCallVolume(volumePercent)
        return true
    elseif Config.Voice.System == "mumble" then
        -- Mumble call volume control not supported by default
        return true
    elseif Config.Voice.System == "salty" then
        -- SaltyChat call volume control not supported by default
        return true
    elseif Config.Voice.System == "toko" then
        -- TokoVoip call volume control not supported by default
        return true
    end
    return false
end

exports("SetCallVolume", SetCallVolume)
exportHandler('yseries', 'SetCallVolume', SetCallVolume)
