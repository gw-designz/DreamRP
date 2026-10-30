while true do
    if Config and Config.Grenades then break end
    Citizen.Wait(500)
end

if not Config.Grenades.Enabled then return end

local FlashbangCfg   = Config.Grenades.Flashbang
local SmokeCfg       = Config.Grenades.SmokeGrenade

Grenades = {}
Grenades.active   = {}   -- [WeaponHash] = true while monitoring shots
Grenades.inFlight = {}   -- [WeaponHash] = true while grenade is in the air
Grenades.flashbang = { affected = false }
Grenades.smoke     = { zones = {}, inside = false, lastCough = 0, loopRunning = false }

-- ============================================================
--  Access check (client-side — server validates too)
-- ============================================================

local function hasJobAccess()
    if not next(Config.Jobs) then return true end  -- no restriction
    local job = Bridge.Framework.fetchPlayerJob()
    if not job or not job.name then return false end
    local minGrade = Config.Jobs[job.name]
    if minGrade == nil then return false end
    return (job.grade or 0) >= minGrade
end

-- ============================================================
--  Flashbang effects
-- ============================================================

-- Blocks look/move inputs while flashbanged
local function blockFlashbangInput()
    DisableControlAction(0, 1,   true)  -- look left/right
    DisableControlAction(0, 2,   true)  -- look up/down
    DisableControlAction(0, 220, true)  -- aim
    DisableControlAction(0, 221, true)  -- attack
end

-- Applies slow-aim drift when partially flashed
local function startSlowAimThread(durationMs, scale)
    CreateThread(function()
        local startTime  = GetGameTimer()
        local camHeading = GetGameplayCamRelativeHeading()
        local camPitch   = GetGameplayCamRelativePitch()

        while Grenades.flashbang.affected do
            local elapsed = GetGameTimer() - startTime
            if elapsed >= durationMs then break end

            local lookX = GetDisabledControlNormal(0, 220)
            local lookY = GetDisabledControlNormal(0, 221)

            camHeading = camHeading - lookX * scale * 10.0
            camPitch   = math.max(-70.0, math.min(42.0, camPitch - lookY * scale * 10.0))

            SetGameplayCamRelativeHeading(camHeading)
            SetGameplayCamRelativePitch(camPitch, 1.0)
            Wait(0)
        end
    end)
end

-- Draws a white flash that fades over WhiteFlashMs
local function startWhiteFlashThread(durationMs)
    CreateThread(function()
        local maxMs    = math.min(durationMs, FlashbangCfg.WhiteFlashMs)
        local startTime = GetGameTimer()

        while true do
            local elapsed = GetGameTimer() - startTime
            if elapsed >= maxMs then break end
            local alpha = math.floor(255 * (1.0 - elapsed / maxMs))
            DrawRect(0.5, 0.5, 1.0, 1.0, 255, 255, 255, alpha)
            Wait(0)
        end
    end)
end

-- Main flashbang effect — intensity 0.0-1.0, durationMs, inStunRadius, facingExplosion
local function applyFlashbangEffect(intensity, durationMs, inStunRadius, facingExplosion)
    if Grenades.flashbang.affected then return end
    Grenades.flashbang.affected = true

    local ped = cache.ped
    AnimpostfxStop("MP_flash")
    AnimpostfxPlay("MP_flash", 0, true)

    local playSound = inStunRadius and facingExplosion
    Sounds:playSound("flashbang", 0.4)

    if playSound then startWhiteFlashThread(durationMs) end

    local drunkMs = math.floor(FlashbangCfg.DrunkMs * intensity)

    -- Face anim
    CreateThread(function()
        local animDict = lib.requestAnimDict(FlashbangCfg.FaceAnimDict, 2000)
        if animDict then
            TaskPlayAnim(ped, FlashbangCfg.FaceAnimDict, FlashbangCfg.FaceAnimName,
                4.0, -4.0, drunkMs, 49, 0, false, false, false)
        end
    end)

    -- Camera shake
    CreateThread(function()
        ShakeGameplayCam("DRUNK_SHAKE", FlashbangCfg.DrunkShakeAmp)
        local startTime = GetGameTimer()
        while true do
            local elapsed = GetGameTimer() - startTime
            if elapsed >= drunkMs then break end
            local t = elapsed / drunkMs
            -- Hold full amplitude for first 75%, then fade out
            local amp = t < 0.75 and 1.0 or (1.0 - (t - 0.75) / 0.25)
            SetGameplayCamShakeAmplitude(FlashbangCfg.DrunkShakeAmp * amp)
            Wait(0)
        end
        StopGameplayCamShaking(true)
        StopAnimTask(ped, FlashbangCfg.FaceAnimDict, FlashbangCfg.FaceAnimName, -4.0)
    end)

    if inStunRadius then
        -- Disarm
        if FlashbangCfg.Disarm then
            SetCurrentPedWeapon(ped, -1569615261, true)  -- WEAPON_UNARMED hash
            if Bridge.Inventory.disarm then
                pcall(Bridge.Inventory.disarm, true)
            end
        end

        -- Ragdoll
        if FlashbangCfg.RagdollEnabled and not IsPedInAnyVehicle(ped, false) then
            SetPedToRagdoll(ped, FlashbangCfg.RagdollMs, FlashbangCfg.RagdollMs, 0, false, false, false)
        end

        -- Slow aim
        if FlashbangCfg.SlowAim then
            startSlowAimThread(durationMs, FlashbangCfg.SlowAimScale)
        end

        -- Block input thread
        CreateThread(function()
            while Grenades.flashbang.affected do
                blockFlashbangInput()
                Wait(0)
            end
        end)
    end

    -- Clear effects after duration
    CreateThread(function()
        Wait(durationMs)
        AnimpostfxStop("MP_flash")
        SetPedMotionBlur(ped, false)
        Grenades.flashbang.affected = false
    end)
end

-- ============================================================
--  Flashbang net event
-- ============================================================

RegisterNetEvent("p_policejob/client/grenades/flashbang", function(data)
    if type(data) ~= "table" or type(data.pos) ~= "vector3" then return end
    if not FlashbangCfg.Enabled then return end

    local ped = cache.ped
    if not DoesEntityExist(ped) or IsEntityDead(ped) then return end

    local myCoords = GetEntityCoords(ped)
    local dist     = #(myCoords - data.pos)
    if dist > FlashbangCfg.Radius then return end

    local inStunRadius = dist <= FlashbangCfg.StunRadius

    -- Line-of-sight check for partial-radius players
    if not inStunRadius and FlashbangCfg.RequireLineOfSight then
        local rayHandle = StartShapeTestRay(
            myCoords.x, myCoords.y, myCoords.z + 0.5,
            data.pos.x, data.pos.y, data.pos.z,
            1, ped, 0)
        local _, hit = GetShapeTestResult(rayHandle)
        if hit == 1 then return end  -- blocked
    end

    -- Calculate intensity (1.0 in stun radius, falls off outside)
    local effectRange = math.max(0.001, FlashbangCfg.Radius - FlashbangCfg.StunRadius)
    local intensity
    if inStunRadius then
        intensity = 1.0
    else
        intensity = math.max(0.0, math.min(1.0, (FlashbangCfg.Radius - dist) / effectRange))
    end

    -- Base duration
    local duration = math.floor(FlashbangCfg.MinDurationMs + (FlashbangCfg.MaxDurationMs - FlashbangCfg.MinDurationMs) * intensity)

    -- Bonus duration for stun radius (scaled by proximity)
    if inStunRadius then
        local proximityBonus = math.max(0.0, 1.0 - dist / FlashbangCfg.StunRadius)
        duration = math.floor(duration * (1.0 + proximityBonus))
    end

    -- Facing check: are we looking toward the explosion?
    local facingExplosion = inStunRadius  -- always "facing" if stunned
    if not inStunRadius then
        local camRot    = GetGameplayCamRot(2)
        local camDir    = vector3(math.sin(math.rad(-camRot.z)), math.cos(math.rad(-camRot.z)), 0.0)
        local toBlast   = data.pos - myCoords
        local toBlast2D = vector3(toBlast.x, toBlast.y, 0.0)
        if #toBlast2D > 0.001 then
            local toBlastNorm = toBlast2D / #toBlast2D
            facingExplosion   = (camDir.x * toBlastNorm.x + camDir.y * toBlastNorm.y) > 0.4
        end
    end

    applyFlashbangEffect(intensity, duration, inStunRadius, facingExplosion)
end)

-- ============================================================
--  Smoke grenade
-- ============================================================

local function startSmokeLoop()
    if Grenades.smoke.loopRunning then return end
    Grenades.smoke.loopRunning = true

    CreateThread(function()
        while next(Grenades.smoke.zones) do
            local now      = GetGameTimer()
            local ped      = cache.ped
            local myCoords = GetEntityCoords(ped)
            local maxDensity = 0.0

            for zoneId, zone in pairs(Grenades.smoke.zones) do
                if now >= zone.expiresAt then
                    Grenades.smoke.zones[zoneId] = nil
                else
                    local dist = #(myCoords - zone.pos)
                    if dist <= zone.radius then
                        local density = math.max(0.0, math.min(1.0, (zone.radius - dist) / zone.radius))
                        if density > maxDensity then maxDensity = density end
                    end
                end
            end

            if maxDensity > 0.0 and not IsEntityDead(ped) then
                if not Grenades.smoke.inside then
                    Grenades.smoke.inside = true
                    SetTimecycleModifier("hud_def_blur_flash")
                end
                SetTimecycleModifierStrength(SmokeCfg.BlurStrength * maxDensity)

                -- Cough anim
                if (now - Grenades.smoke.lastCough) >= SmokeCfg.CoughInterval then
                    if not IsPedInAnyVehicle(ped, false) then
                        Grenades.smoke.lastCough = now
                        CreateThread(function()
                            local animDict = lib.requestAnimDict("random@arrests", 1500)
                            if animDict then
                                TaskPlayAnim(ped, "random@arrests", "generic_radio_chatter",
                                    4.0, -4.0, 1200, 49, 0, false, false, false)
                            end
                        end)
                    end
                end
            else
                if Grenades.smoke.inside then
                    Grenades.smoke.inside = false
                    ClearTimecycleModifier()
                end
            end

            Wait(SmokeCfg.TickMs)
        end

        -- Cleanup when all zones expire
        if Grenades.smoke.inside then
            Grenades.smoke.inside = false
            ClearTimecycleModifier()
        end
        Grenades.smoke.loopRunning = false
    end)
end

RegisterNetEvent("p_policejob/client/grenades/smoke", function(data)
    if type(data) ~= "table" or type(data.pos) ~= "vector3" then return end
    if not SmokeCfg.Enabled then return end

    -- Immune jobs skip smoke effect
    if SmokeCfg.ImmuneAllowedJobs and hasJobAccess() then return end

    local zoneId = ("%d_%d"):format(GetGameTimer(), math.random(1, 1000000))
    Grenades.smoke.zones[zoneId] = {
        pos       = data.pos,
        radius    = SmokeCfg.Radius,
        expiresAt = GetGameTimer() + SmokeCfg.LingerMs,
    }
    startSmokeLoop()
end)

-- ============================================================
--  Grenade tracking — detects throw and fires server event on land
-- ============================================================

-- Tracks a grenade object after throw, fires serverEvent with landing coords.
-- onLand(coords) optional local callback.
local function trackGrenade(grenadeDef, serverEvent, onLand)
    if Grenades.inFlight[grenadeDef.WeaponHash] then return end
    Grenades.inFlight[grenadeDef.WeaponHash] = true

    CreateThread(function()
        local projectileHandle = 0
        local deadline = GetGameTimer() + 250

        -- Wait briefly for the object to appear in world
        while projectileHandle == 0 do
            if GetGameTimer() >= deadline then break end
            projectileHandle = GetClosestObjectOfType(
                GetEntityCoords(cache.ped), 8.0,
                grenadeDef.ProjectileModel, false, false, false)
            if projectileHandle == 0 then Wait(20) end
        end

        -- Track until fuse expires
        local fuseEnd  = GetGameTimer() + grenadeDef.FuseMs
        local lastPos  = projectileHandle ~= 0 and GetEntityCoords(projectileHandle) or GetEntityCoords(cache.ped)

        while GetGameTimer() < fuseEnd do
            if projectileHandle ~= 0 and DoesEntityExist(projectileHandle) then
                lastPos = GetEntityCoords(projectileHandle)
            end
            Wait(50)
        end

        TriggerServerEvent(serverEvent, lastPos)
        if onLand then onLand(lastPos) end

        Grenades.inFlight[grenadeDef.WeaponHash] = false
    end)
end

-- Monitors weapon state; starts tracking when the player shoots the grenade.
local function monitorGrenade(grenadeDef, serverEvent, onLand)
    if Grenades.active[grenadeDef.WeaponHash] then return end
    if not hasJobAccess() then return end

    Grenades.active[grenadeDef.WeaponHash] = true

    CreateThread(function()
        while Grenades.active[grenadeDef.WeaponHash] do
            if IsPedShooting(cache.ped) then
                trackGrenade(grenadeDef, serverEvent, onLand)
            end
            Wait(0)
        end
    end)
end

local function stopMonitoringGrenade(grenadeDef)
    Grenades.active[grenadeDef.WeaponHash] = nil
end

-- ============================================================
--  Weapon cache hook — start/stop monitoring on weapon switch
-- ============================================================

lib.onCache("weapon", function(currentWeapon)
    if FlashbangCfg.Enabled then
        if currentWeapon == FlashbangCfg.WeaponHash then
            monitorGrenade(FlashbangCfg, "p_policejob/server/grenades/flashbangDetonate", function(coords)
                -- Local visual explosion
                AddExplosion(coords.x, coords.y, coords.z, 25, 0.0, true, false, 0.6)
            end)
        else
            stopMonitoringGrenade(FlashbangCfg)
        end
    end

    if SmokeCfg.Enabled then
        if currentWeapon == SmokeCfg.WeaponHash then
            monitorGrenade(SmokeCfg, "p_policejob/server/grenades/smokeDetonate", nil)
        else
            stopMonitoringGrenade(SmokeCfg)
        end
    end
end)

-- ============================================================
--  Cleanup on resource stop
-- ============================================================

AddEventHandler("onResourceStop", function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    AnimpostfxStop("MP_flash")
    ClearTimecycleModifier()
    SetPedMotionBlur(cache.ped, false)
    SetPedIsDrunk(cache.ped, false)
    ResetPedMovementClipset(cache.ped, 0.0)
    StopGameplayCamShaking(true)
end)
