-- Global event-name prefix used by all client/server events in this resource.
eventName = "bablo-multicharacter:"

-- Locale table populated by locale files that run after this one.
Locales = Locales or {}

-- ─── Auto-detection helpers ───────────────────────────────────────────────────

-- Detect which framework is running. Returns "esx", "qbox", "qbcore", or nil.
local function detectFramework()
    if IsResourceStartedOrStarting("es_extended") then return "esx"    end
    if IsResourceStartedOrStarting("qbx_core")    then return "qbox"   end
    if IsResourceStartedOrStarting("qb-core")     then return "qbcore" end
    return nil
end

-- Detect which appearance resource is running, or nil if none is found.
local function detectAppearance()
    local candidates = {
        "illenium-appearance",
        "fivem-appearance",
        "bl_appearance",
        "crm-appearance",
        "rcore_clothing",
        "tgiann-clothing",
        "qb-clothing",
        "skinchanger",
    }
    for _, name in ipairs(candidates) do
        if IsResourceStartedOrStarting(name) then return name end
    end
    return nil
end

-- Detect which housing resource is running. Returns "qbx-apartments", "qb-houses", or nil.
local function detectHousing()
    if IsResourceStartedOrStarting("qbx_apartments") then return "qbx-apartments" end
    if IsResourceStartedOrStarting("qb-houses")      then return "qb-houses"      end
    return nil
end

-- Poll detect-fn every 100 ms until it returns a value or timeoutMs elapses.
-- Writes the result into Config[key]. This handles the edge case where a framework
-- or appearance resource hasn't started yet when this file first runs.
local function autoDetectWithPoll(key, detectFn, timeoutMs)
    Config[key] = detectFn()
    if Config[key] then return end

    local deadline = GetGameTimer() + (timeoutMs or 5000)
    while not Config[key] and GetGameTimer() < deadline do
        Wait(100)
        Config[key] = detectFn()
    end
end

-- ─── Framework auto-detection ─────────────────────────────────────────────────

if Config.Framework == "auto" then
    Trace("Detecting framework")
    autoDetectWithPoll("Framework", detectFramework)

    if not Config.Framework then
        Trace("No supported framework detected (qbcore / qbox / esx). bablo-multicharacter will not function.")
    else
        Trace("Detected framework: " .. Config.Framework)
    end
end

-- ─── Appearance auto-detection ────────────────────────────────────────────────

if Config.Appearance == "auto" then
    Trace("Detecting appearance")
    autoDetectWithPoll("Appearance", detectAppearance)
    Trace("Detected appearance: " .. tostring(Config.Appearance))
end

-- ─── Housing auto-detection ───────────────────────────────────────────────────

if Config.Housing == "auto" then
    Trace("Detecting housing")
    autoDetectWithPoll("Housing", detectHousing)

    if not Config.Housing then
        Config.Housing = "none"
    end
    Trace("Detected housing: " .. Config.Housing)
end

-- ─── Exports ──────────────────────────────────────────────────────────────────

exports("GetConfig",    function() return Config end)
exports("GetFramework", function() return Config.Framework end)

-- Client-only exports (registered on client, ignored on server)
if IsDuplicityVersion and not IsDuplicityVersion() then
    -- Open the multicharacter selection screen. No-op if already open.
    exports("openUI", function()
        if Main and not Main.isOpen then
            Main:Init()
        end
    end)

    -- Close the multicharacter selection screen. No-op if not open.
    exports("closeUI", function()
        if Main and Main.isOpen then
            Main:Destroy()
        end
    end)

    -- Returns true if the multicharacter UI is currently open.
    exports("isOpen", function()
        return Main ~= nil and Main.isOpen == true
    end)
end
