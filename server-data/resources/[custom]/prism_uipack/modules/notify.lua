---@diagnostic disable: duplicate-doc-alias
---@diagnostic disable: duplicate-doc-field

---@alias NotificationPosition 'top' | 'top-left' | 'top-center' | 'top-right' | 'bottom' | 'bottom-left' | 'bottom-center' | 'bottom-right'
---@alias NotificationType 'info' | 'warning' | 'success' | 'error'
---@alias IconAnimationType 'spin' | 'spinPulse' | 'spinReverse' | 'pulse' | 'beat' | 'fade' | 'beatFade' | 'bounce' | 'shake'

---@class NotifyProps
---@field id? string
---@field title? string
---@field description? string
---@field duration? number
---@field showDuration? boolean
---@field position? NotificationPosition
---@field type? NotificationType
---@field icon? string | { [1]: IconProp, [2]: string }
---@field iconAnimation? IconAnimationType
---@field sound? { bank?: string, set: string, name: string } | string
---@field volume? number

local function LoadNotificationSettings()
    local function safeGetKvp(fn, key, default)
        local ok, result = pcall(fn, key)
        if not ok then return DeleteResourceKvp(key) end
        return result or default
    end

    return {
        notification_audio = safeGetKvp(GetResourceKvpInt, 'notification_audio', 1) == 1
    }
end

local settings = LoadNotificationSettings()

function PlayNotificationSound(sound)
    local bankExists = sound.bank ~= nil

    if bankExists then Utils.requestAudioBank(sound.bank) end

    local soundId = GetSoundId()
    PlaySoundFrontend(soundId, sound.name, sound.set, true)
    ReleaseSoundId(soundId)

    if bankExists then ReleaseNamedScriptAudioBank(sound.bank) end
end

---@param data NotifyProps
function Notify(data)
    if data and data.type == 'inform' then data.type = 'info' end

    local sound = settings.notification_audio and data.sound
    data.sound = nil

    SendNUIMessage({ action = 'notification', data = data })

    if sound and type(sound) ~= 'string' then
        PlayNotificationSound(sound)
    end
end
