Hud = {
    settings = {},
    scriptHidden = false,
    visible = false,
    mapVisible = false,
    mapDrawn = false,       -- the 3D minimap (client/map3d.lua) is standing in for the radar
    forceMap = false,
    devMode = false,
    inVehicle = false,
    vehicle = 0,
    belted = false,
    speedMph = 0,
}

local cache = {}

-- Sends only the keys of `data` whose value changed since the last push for `group`.
function Hud.push(group, data)
    local c = cache[group]
    if not c then
        c = {}
        cache[group] = c
    end
    local changed
    for k, v in pairs(data) do
        if c[k] ~= v then
            c[k] = v
            changed = changed or {}
            changed[k] = v
        end
    end
    if changed then
        SendNUIMessage({ action = 'update', group = group, data = changed })
    end
end

-- Forget what was sent so the next push resends everything (after a NUI reload).
function Hud.resetCache()
    cache = {}
end

function Hud.send(action, payload)
    payload = payload or {}
    payload.action = action
    SendNUIMessage(payload)
end

-- Config.Tick[name] scaled by the player's performance mode (Settings > Home).
local TICK_SCALE = { performance = 1.6, balanced = 1.0, quality = 0.6 }
function Hud.tick(name)
    return math.floor(Config.Tick[name] * (TICK_SCALE[Hud.settings.performance] or 1.0))
end

function Hud.round(v)
    return math.floor(v + 0.5)
end

function Hud.clamp(v, lo, hi)
    if v < lo then return lo elseif v > hi then return hi end
    return v
end

-- Screen metrics shared by the NUI layout and the game minimap placement.
-- Everything is in pixels of the active resolution.
function Hud.metrics()
    local resX, resY = GetActiveScreenResolution()
    local margin = (1.0 - GetSafeZoneSize()) * 0.5
    local inset = 0
    if not Hud.settings.ultrawide and resX / resY > 16 / 9 + 0.01 then
        inset = (resX - resY * 16 / 9) * 0.5
    end
    return {
        resX = resX,
        resY = resY,
        safeX = margin * resX,          -- where the game's 'R' alignment measures from
        marginX = margin * resX + inset, -- where the HUD is anchored
        marginY = margin * resY,
        k = resY / 1080 * (Hud.settings.scale or 1.0),
    }
end
