LockPick = {}

local lockpickPromise = nil
local isLockpickActive = false

function LockPick:start(options)
    if isLockpickActive then
        return { success = false, cancelled = false }
    end

    if not options then options = {} end

    isLockpickActive = true
    lockpickPromise = promise.new()

    SendNUIMessage({
        action = "LOCKPICK_OPEN",
        data = {
            zones    = options.zones    or 4,
            speed    = options.speed    or 0.35,
            zoneSize = options.zoneSize or 0.08,
            labels   = {
                click  = Translate("LOCKPICK_MINIGAME_CLICK"),
                key    = Translate("LOCKPICK_MINIGAME_KEY"),
                toOpen = Translate("LOCKPICK_MINIGAME_TO_OPEN"),
                failed = Translate("LOCKPICK_MINIGAME_FAILED"),
                opened = Translate("LOCKPICK_MINIGAME_OPENED"),
            }
        }
    })

    Citizen.CreateThread(function()
        while isLockpickActive do
            DisableControlAction(0, 38, true)
            DisableControlAction(0, 177, true)
            DisableControlAction(0, 199, true)
            DisableControlAction(0, 200, true)

            if IsDisabledControlJustPressed(0, 38) then
                SendNUIMessage({ action = "LOCKPICK_HIT" })
            end

            if IsDisabledControlJustPressed(0, 200) or IsDisabledControlJustPressed(0, 177) then
                SendNUIMessage({ action = "LOCKPICK_CANCEL" })
            end

            Citizen.Wait(0)
        end
    end)

    local result = Citizen.Await(lockpickPromise)
    isLockpickActive = false
    lockpickPromise = nil
    return result
end

RegisterNUICallback("lockpick:result", function(data, cb)
    cb({})
    if lockpickPromise then
        lockpickPromise:resolve(data)
    end
end)

exports("startLockPick", function(options, callback)
    Citizen.CreateThread(function()
        local result = LockPick:start(options)
        if callback then
            callback(result)
        end
    end)
end)
