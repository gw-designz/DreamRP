-- Stress gain from shooting and speeding, batched to the server, plus the high-stress shake.
-- The authoritative value lives in LocalPlayer.state.stress (set by the server).

local cfg = Config.Stress
local pending = 0
local ignored = {}
for _, hash in ipairs(cfg.shooting.ignoredWeapons) do ignored[hash] = true end

local function exempt()
    return not cfg.enabled or (Bridge.job and cfg.whitelistedJobs[Bridge.job])
end

local function gain(min, max)
    if exempt() then return end
    pending = pending + math.random(min, max)
end

-- Shots are counted from ammo drops so a 100ms poll never misses one.
if cfg.enabled and cfg.shooting.enabled then
    CreateThread(function()
        local lastWeapon, lastAmmo = 0, 0
        while true do
            local ped = PlayerPedId()
            if IsPedArmed(ped, 4) then
                local weapon = GetSelectedPedWeapon(ped)
                local ammo = GetAmmoInPedWeapon(ped, weapon)
                if weapon == lastWeapon and ammo < lastAmmo and not ignored[weapon] then
                    for _ = 1, math.min(lastAmmo - ammo, 10) do
                        if math.random() < cfg.shooting.chance then gain(cfg.shooting.min, cfg.shooting.max) end
                    end
                end
                lastWeapon, lastAmmo = weapon, ammo
                Wait(100)
            else
                lastWeapon, lastAmmo = 0, 0
                Wait(1000)
            end
        end
    end)
end

if cfg.enabled and cfg.speeding.enabled then
    CreateThread(function()
        while true do
            if Hud.inVehicle and GetPedInVehicleSeat(Hud.vehicle, -1) == PlayerPedId() then
                local limit = Hud.belted and cfg.speeding.buckled or cfg.speeding.unbuckled
                if Hud.speedMph > limit then gain(cfg.speeding.min, cfg.speeding.max) end
                Wait(cfg.speeding.interval)
            else
                Wait(2000)
            end
        end
    end)
end

if cfg.enabled then
    CreateThread(function()
        while true do
            Wait(cfg.syncInterval)
            if pending > 0 then
                local amount = math.min(pending, cfg.maxPerEvent)
                TriggerServerEvent('my-hud:server:gainStress', amount)
                pending = pending - amount
            end
        end
    end)

    CreateThread(function()
        while true do
            local stress = LocalPlayer.state.stress or 0
            local tier
            for _, t in ipairs(cfg.shake) do
                if stress >= t.min then
                    tier = t
                    break
                end
            end
            if tier and Hud.settings.stressShake and Hud.visible then
                ShakeGameplayCam('SMALL_EXPLOSION_SHAKE', tier.intensity)
                Wait(tier.interval)
            else
                Wait(5000)
            end
        end
    end)
end

Bridge.onLoaded(function()
    TriggerServerEvent('my-hud:server:requestStress')
end)

exports('AddStress', function(amount)
    amount = tonumber(amount) or 0
    if amount > 0 and not exempt() then pending = pending + amount end
end)

exports('RelieveStress', function(amount)
    TriggerServerEvent('hud:server:RelieveStress', tonumber(amount) or 0)
end)
