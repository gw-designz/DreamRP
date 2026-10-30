RegisterNuiCallback('getLocale', function(data, cb)
    cb({
        lang = lib.getLocaleKey()
    })
end)

RegisterNetEvent("prp-bridge:notify", bridge.fw.notify)
lib.callback.register("prp-bridge:progress", bridge.fw.progressBar)
lib.callback.register("prp-bridge:minigame", bridge.minigames.play)
lib.callback.register('prp-bridge:confirmDialog', bridge.fw.confirmDialog)
lib.callback.register('prp-bridge:inputDialog', bridge.fw.inputDialog)

local sounds = {} ---@type table<string, { position: vector3, muffled: boolean }> --- key: soundId
local muffleSounds = {} ---@type table<string, boolean> --- key: soundId
local soundsThread = false
local muffleSoundsThread = false

local MAX_SOUND_DISTANCE <const> = 500.0 -- Above this distance, the sound won't be processed at all
local MUFFLED_RADIUS <const> = 1.0 -- Distance on raycast check to consider sound as not muffled
local MUFFLE_THREAD_INTERVAL <const> = 250 -- ms
local SOUNDS_THREAD_INTERVAL <const> = 100 -- ms

local GetGameplayCamRot = GetGameplayCamRot
local GetEntityCoords = GetEntityCoords
local math_abs = math.abs
local math_cos = math.cos
local math_sin = math.sin
local next = next

---@return string, any
local function generateUUID()
    local template = "xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx"
    return template:gsub("[xy]", function(c)
        local v = (c == "x") and math.random(0, 15) or math.random(8, 11)
        return string.format("%x", v)
    end)
end

---@return { x: number, y: number, z: number }
local function getCameraDirection()
    local rot = GetGameplayCamRot(0)
    local tZ = rot.z * 0.0174532924
    local tX = rot.x * 0.0174532924
    local num = math_abs(math_cos(tX))

    return {
        x = -math_sin(tZ) * num,
        y = math_cos(tZ) * num,
        z = math_sin(tX)
    }
end

---@param soundId string
local function removeMuffleSoundEntry(soundId)
    muffleSounds[soundId] = nil
end

---@param sourceCoords vector3
---@return boolean
local function isSourceBehindWall(sourceCoords)
    local camCoords = GetEntityCoords(cache.ped)
    local rayHandle = StartShapeTestLosProbe(camCoords.x, camCoords.y, camCoords.z, sourceCoords.x, sourceCoords.y, sourceCoords.z, 17, 0, 0)
    local retval, hit, endCoords, _, _ = GetShapeTestResult(rayHandle)
    while retval == 1 do
        Wait(0)
        retval, hit, endCoords, _, _ = GetShapeTestResult(rayHandle)
    end

    if hit == 1 then
        return false
    else
        local dist = #(camCoords - endCoords)
        if dist <= MUFFLED_RADIUS then
            return false
        end

        return true
    end
end

local function startSoundsThread()
    if soundsThread then return end
    soundsThread = true

    local function _soundsLoop()
        local camPos = GetEntityCoords(cache.ped)

        SendNUIMessage({
            event = "sendAppEvent",
            app = "sound",
            action = "updateListener",
            payload = {
                position = {
                    x = camPos.x,
                    y = camPos.y,
                    z = camPos.z
                },
                forward = getCameraDirection()
            }
        })
    end

    Citizen.CreateThreadNow(function()
        while next(sounds) do
            local success, e = pcall(_soundsLoop)
            if not success then
                print("Error in sounds loop:", e)
            end
            Wait(SOUNDS_THREAD_INTERVAL)
        end

        soundsThread = false
    end)
end

local function startMuffleSoundsThread()
    if muffleSoundsThread then return end
    muffleSoundsThread = true

    local function _muffleLoop()
        for soundId, _ in pairs(muffleSounds) do
            local soundData = sounds[soundId]
            if not soundData then
                removeMuffleSoundEntry(soundId)
            else
                local muffled = not isSourceBehindWall(soundData.position)

                if soundData.muffled ~= muffled then
                    soundData.muffled = muffled
                    SendNUIMessage({
                        event = "sendAppEvent",
                        app = "sound",
                        action = "setMuffle",
                        payload = { id = soundId, muffled = muffled }
                    })
                end
            end
        end
    end

    Citizen.CreateThreadNow(function()
        while next(muffleSounds) do
            local success, e = pcall(_muffleLoop)
            if not success then
                print("Error in muffle loop:", e)
            end
            Wait(MUFFLE_THREAD_INTERVAL)
        end

        muffleSoundsThread = false
    end)
end

RegisterNUICallback("soundEnded", function(data, cb)
    local soundId = data.id
    sounds[soundId] = nil
    removeMuffleSoundEntry(soundId)
    cb({})
end)

---@param fileName string
---@param volume number
---@param noAutoPath boolean? This lets you decide, if you want prp-bridge to search for sounds in `sounds` folder of resource.
---@param resourceName string? Internal use only. Mainly for calls from server-side.
---@return string soundId
local function playSound(fileName, volume, noAutoPath, resourceName)
    local resourceName = resourceName or (GetInvokingResource() or GetCurrentResourceName())
    local path = ("https://cfx-nui-%s/sounds/%s"):format(resourceName, fileName)
    if noAutoPath then
        path = fileName
    end

    local soundId = generateUUID()

    SendNUIMessage({
        event = "sendAppEvent",
        app = "sound",
        action = "play",
        payload = {
            id = soundId,
            file = path,
            volume = volume or 1.0,
        }
    })

    return soundId
end

---@param fileName string
---@param volume number
---@param coords vector3
---@param distance number Max distance where the sound can be heard.
---@param shouldMuffle boolean? Whether the sound should be muffled when behind walls.
---@param noAutoPath boolean? This lets you decide, if you want prp-bridge to search for sounds in `sounds` folder of resource.
---@param resourceName string? Internal use only. Mainly for calls from server-side.
---@return string? soundId
local function playSpatialSound(fileName, volume, coords, distance, shouldMuffle, noAutoPath, resourceName)
    local resourceName = resourceName or (GetInvokingResource() or GetCurrentResourceName())
    local path = ("https://cfx-nui-%s/sounds/%s"):format(resourceName, fileName)
    if noAutoPath then
        path = fileName
    end

    local playerCoords = GetEntityCoords(cache.ped)
    local dist = #(playerCoords - vec3(coords.x, coords.y, coords.z))
    if dist > MAX_SOUND_DISTANCE then return nil end

    local soundId = generateUUID()

    sounds[soundId] = {
        muffled = false,
        position = coords
    }

    startSoundsThread()

    if shouldMuffle then
        muffleSounds[soundId] = true
        startMuffleSoundsThread()
    end

    SendNUIMessage({
        event = "sendAppEvent",
        app = "sound",
        action = "playSpatial",
        payload = {
            id = soundId,
            file = path,
            distance = distance or 100,
            volume = volume or 1.0,
            position = {
                x = coords.x,
                y = coords.y,
                z = coords.z
            },
        }
    })

    return soundId
end

exports("PlaySound", playSound)
exports("PlaySpatialSound", playSpatialSound)

RegisterNetEvent("prp-bridge:sound:play", playSound)
RegisterNetEvent("prp-bridge:sound:playSpatial", playSpatialSound)

-- HeistTimer exports
---@param visible boolean
local function heistTimerSetVisible(visible)
    SendNUIMessage({
        event = "sendAppEvent",
        app = "heistTimer",
        action = "setVisible",
        payload = visible
    })
end

---@param timestamp number Target timestamp in milliseconds
---@param delta number Time delta to show (positive or negative seconds)
local function heistTimerUpdateTimestamp(timestamp, delta)
    SendNUIMessage({
        event = "sendAppEvent",
        app = "heistTimer",
        action = "updateTimestamp",
        payload = { timestamp = timestamp, delta = delta or 0 }
    })
end

---@param theme string Theme name (e.g., "traphouse")
local function heistTimerSetTheme(theme)
    SendNUIMessage({
        event = "sendAppEvent",
        app = "heistTimer",
        action = "setTheme",
        payload = theme or ""
    })
end

---@param label string Label text (e.g., "TIME LEFT", "Looting phase")
local function heistTimerSetLabel(label)
    SendNUIMessage({
        event = "sendAppEvent",
        app = "heistTimer",
        action = "setLabel",
        payload = label or ""
    })
end

exports("HeistTimerSetVisible", heistTimerSetVisible)
exports("HeistTimerUpdateTimestamp", heistTimerUpdateTimestamp)
exports("HeistTimerSetTheme", heistTimerSetTheme)
exports("HeistTimerSetLabel", heistTimerSetLabel)
