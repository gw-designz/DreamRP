while true do
    if Config and Config.Tackle then break end
    Citizen.Wait(500)
end

if not Config.Tackle.Enabled then return end

local TackleCfg  = Config.Tackle
local isTackling = false
local nextAllowed = 0

-- ============================================================
--  Export
-- ============================================================

exports("isTackling", function() return isTackling end)

-- ============================================================
--  Can-tackle check (called on the officer's side before triggering)
-- ============================================================

local function canTackle()
    if isTackling then return false end
    if IsPedRagdoll(cache.ped) then return false end
    if cache.vehicle and cache.vehicle ~= 0 then return false end
    if not IsPedSprinting(cache.ped) then return false end

    -- Optional job restriction
    if Config.Jobs then
        local job = Bridge.Framework.fetchPlayerJob()
        if not job or not job.name then return false end
        local minGrade = Config.Jobs[job.name]
        if minGrade == nil then return false end
        if (job.grade or 0) < minGrade then return false end
    end

    return true
end

-- ============================================================
--  Keybind — tackle nearest player while sprinting + Shift held
-- ============================================================

lib.addKeybind({
    name          = "tackle",
    description   = "Tackle nearest player",
    defaultKey    = TackleCfg.Keybind,
    defaultMapper = "keyboard",
    onPressed     = function()
        -- Shift (control 21) must be held
        if not IsControlPressed(0, 21) then return end
        if GetGameTimer() < nextAllowed then return end
        if not canTackle() then return end

        local closestPlayer, closestPed = lib.getClosestPlayer(
            GetEntityCoords(cache.ped), TackleCfg.Distance, false)

        if not closestPlayer or not closestPed or closestPed == 0 then return end
        if closestPed == cache.ped then return end

        nextAllowed = GetGameTimer() + TackleCfg.Timeout
        TriggerServerEvent("p_policejob/server/tackle/tacklePlayer",
            GetPlayerServerId(closestPlayer))
    end,
})

-- ============================================================
--  Net event — play tackle on both sides
-- ============================================================

RegisterNetEvent("p_policejob/client/tackle/tacklePlayer", function(data)
    if isTackling then return end
    isTackling = true

    if TackleCfg.Type == "animation" then
        local animDict = lib.requestAnimDict("missmic2ig_11")

        if data.isTackler then
            -- Officer: play tackle animation
            TaskPlayAnim(cache.ped, animDict, "mic_2_ig_11_intro_goon",
                8.0, -8.0, 4500, 0, 0)
            SetTimeout(4500, function() isTackling = false end)
        else
            -- Target: attach to tackler and play victim animation
            local tacklerPed = GetPlayerPed(GetPlayerFromServerId(data.targetId))
            AttachEntityToEntity(
                cache.ped, tacklerPed, 11816,
                0.25, 0.5, 0.0, 0.5, 0.5, 180.0,
                false, false, false, false, 2, false)
            TaskPlayAnim(cache.ped, animDict, "mic_2_ig_11_intro_p_one",
                8.0, -8.0, 4000, 0, 0)

            SetTimeout(4000, function()
                DetachEntity(cache.ped, true, true)

                -- Ragdoll thread while still tackling
                CreateThread(function()
                    while isTackling do
                        SetPedToRagdoll(cache.ped, 1000, 1000, 0, 0, 0, 0)
                        Wait(1)
                    end
                end)

                Wait(4000)
                isTackling = false
            end)
        end
    else
        -- Ragdoll mode: tackler gets 2.5s, target gets 4s
        local duration = data.isTackler and 2500 or 4000
        SetPedToRagdoll(cache.ped, duration, duration, 0, 0, 0, 0)
        Wait(4000)
        isTackling = false
    end
end)
