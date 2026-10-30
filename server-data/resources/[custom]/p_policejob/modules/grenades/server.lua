while true do
    if Config and Config.Grenades then break end
    Wait(50)
end

if not Config.Grenades.Enabled then return end

local GrenadeCfg   = Config.Grenades
local FlashbangCfg = GrenadeCfg.Flashbang
local SmokeCfg     = GrenadeCfg.SmokeGrenade

Grenades = {}
Grenades.lastThrow = {}  -- [playerSource] = lastThrowTimestamp

-- ============================================================
--  Access check
-- ============================================================

local function hasJobAccess(playerSource)
    if not next(Config.Jobs) then return true end
    local job = Bridge.Framework.getPlayerJob(playerSource)
    if not job or not job.name then return false end
    local minGrade = Config.Jobs[job.name]
    if minGrade == nil then return false end
    return (job.grade or 0) >= minGrade
end

-- ============================================================
--  Detonation handler (shared by flashbang and smoke)
-- ============================================================

local function handleDetonate(playerSource, detonationPos, radius, clientEvent, grenadeName)
    if type(detonationPos) ~= "vector3" then return end

    if not hasJobAccess(playerSource) then
        Bridge.Debug(("[Grenades] Player %s denied detonation (no access)"):format(playerSource))
        return
    end

    -- Cooldown check
    local now      = GetGameTimer()
    local lastTime = Grenades.lastThrow[playerSource] or 0
    if (now - lastTime) < GrenadeCfg.CooldownMs then return end
    Grenades.lastThrow[playerSource] = now

    -- Distance anti-cheat
    local ped       = GetPlayerPed(playerSource)
    if not ped or ped == 0 then return end
    local pedCoords = GetEntityCoords(ped)
    local dist      = #(pedCoords - detonationPos)

    if dist > GrenadeCfg.MaxThrowDistance then
        Bridge.Debug(("[Grenades] Player %s detonation rejected (out of range)"):format(playerSource))
        return
    end

    Bridge.Debug(("[Grenades] Player %s detonated %s at %.1f,%.1f,%.1f")
        :format(playerSource, grenadeName, detonationPos.x, detonationPos.y, detonationPos.z))

    local payload = { pos = detonationPos }

    for _, rawId in ipairs(GetPlayers()) do
        local targetSource = tonumber(rawId)
        if targetSource then
            local targetPed = GetPlayerPed(targetSource)
            if targetPed and targetPed ~= 0 then
                local targetDist = #(GetEntityCoords(targetPed) - detonationPos)
                if targetDist <= radius then
                    TriggerClientEvent(clientEvent, targetSource, payload)
                end
            end
        end
    end
end

-- ============================================================
--  Net events
-- ============================================================

RegisterNetEvent("p_policejob/server/grenades/flashbangDetonate", function(detonationPos)
    if not FlashbangCfg.Enabled then return end
    handleDetonate(source, detonationPos, FlashbangCfg.Radius,
        "p_policejob/client/grenades/flashbang", "flashbang")
end)

RegisterNetEvent("p_policejob/server/grenades/smokeDetonate", function(detonationPos)
    if not SmokeCfg.Enabled then return end
    handleDetonate(source, detonationPos, SmokeCfg.Radius,
        "p_policejob/client/grenades/smoke", "smoke")
end)

AddEventHandler("playerDropped", function()
    Grenades.lastThrow[source] = nil
end)
