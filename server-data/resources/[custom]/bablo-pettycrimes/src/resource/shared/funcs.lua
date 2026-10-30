
Trace = function(...)
    if not Config.Debug then
        return
    end

    local logLine = ""
    local logString = { ... }

    if IsDuplicityVersion() then
        logLine = os.date('%Y-%m-%d %H:%M:%S', os.time())
    end

    logLine = logLine .. " [" .. (GetCurrentResourceName() or "LOG") .. "] "

    for i = 1, #logString do
        logLine = logLine .. tostring(logString[i]) .. " "
    end

    print(logLine)
end

function SelectRandomItem(lootTable)
    local totalChance = 0
    for _, item in pairs(lootTable) do
        totalChance = totalChance + item.chance
    end

    local randomChance = math.random(1, totalChance)

    local cumulativeChance = 0
    for _, item in pairs(lootTable) do
        cumulativeChance = cumulativeChance + item.chance
        if randomChance <= cumulativeChance then
            return item
        end
    end
end

Translate = function(key, args)
    if not Config.Locale then
        return key
    end

    local translation = Locales[Config.Locale] and Locales[Config.Locale][key]

    if not translation then
        return key
    else
        if args then
            local i = 1
            translation = translation:gsub("%%s", function()
                local arg = args[i]
                i = i + 1
                return tostring(arg)
            end)
        end
    end

    return translation
end

IsResourceStartedOrStarting = function(resource)
    local state = GetResourceState(resource)
    return state == "started" or state == "starting"
end

if Config.Framework == "auto" then
    Trace("Detecting framework")

    if IsResourceStartedOrStarting("es_extended") then
        Config.Framework = "esx"
    elseif IsResourceStartedOrStarting("qbx_core") then
        Config.Framework = "qbox"
    elseif IsResourceStartedOrStarting("qb-core") then
        Config.Framework = "qbcore"
    else
        Config.Framework = "standalone"
    end
    Trace("Detected framework: " .. Config.Framework)
end

if Config.Inventory == "auto" then
    Trace("Detecting inventory")

    if IsResourceStartedOrStarting("tgiann-inventory") then
        Config.Inventory = "tgiann-inventory"
    elseif IsResourceStartedOrStarting("qb-inventory") then
        Config.Inventory = "qb-inventory"
    elseif IsResourceStartedOrStarting("qs-inventory") then
        Config.Inventory = "qs-inventory"
    elseif IsResourceStartedOrStarting("ps-inventory") then
        Config.Inventory = "ps-inventory"
    elseif IsResourceStartedOrStarting("ox_inventory") then
        Config.Inventory = "ox_inventory"
    elseif IsResourceStartedOrStarting("origen_inventory") then
        Config.Inventory = "origen_inventory"
    elseif IsResourceStartedOrStarting("core_inventory") then
        Config.Inventory = "core_inventory"
    elseif IsResourceStartedOrStarting("codem-inventory") then
        Config.Inventory = "codem-inventory"
    end

    Trace("Detected inventory: " .. Config.Inventory)
end

if Config.Target == "auto" then
    Trace("Detecting target")

    if IsResourceStartedOrStarting("qb-target") then
        Config.Target = "qb-target"
    elseif IsResourceStartedOrStarting("ox_target") then
        Config.Target = "ox_target"
    else
        Config.Target = "standalone"
    end

    Trace("Detected target: " .. Config.Target)
end

if Config.Dispatch == "auto" then
    Trace("Detecting dispatch")

    if IsResourceStartedOrStarting("qs-dispatch") then
        Config.Dispatch = "qs-dispatch"
    elseif IsResourceStartedOrStarting("ps-dispatch") then
        Config.Dispatch = "ps-dispatch"
    elseif IsResourceStartedOrStarting("rcore_dispatch") then
        Config.Dispatch = "rcore_dispatch"
    elseif IsResourceStartedOrStarting("cd_dispatch") then
        Config.Dispatch = "cd_dispatch"
    elseif IsResourceStartedOrStarting("tk_dispatch") then
        Config.Dispatch = "tk_dispatch"
    elseif IsResourceStartedOrStarting("lb-tablet") then
        Config.Dispatch = "lb-tablet"
    else
        Config.Dispatch = "standalone"
    end

    Trace("Detected dispatch: " .. Config.Dispatch)
end

-- Safety fallback: if no dispatch wrapper defined Dispatch:Send by the time
-- something tries to call it, log a warning once and no-op instead of hard-
-- crashing the NUI callback / ox_target action. Common causes: typo in
-- Config.Dispatch, unsupported dispatch resource, or a wrapper file error.
-- Only runs on the client — dispatch wrappers live in client_scripts and are
-- never loaded on the server, so this check is meaningless server-side.
Dispatch = Dispatch or {}
if not IsDuplicityVersion() then
    CreateThread(function()
        Wait(5000)
        if type(Dispatch.Send) ~= 'function' then
            print(('[bablo-pettycrimes] WARNING: Dispatch:Send is not defined. Config.Dispatch = %q has no matching wrapper in src/dispatches/. Alerts will be silently dropped.'):format(tostring(Config.Dispatch)))
            function Dispatch:Send(_) end
        end
    end)
end



TableLength = function(table)
    local count = 0
    for _ in pairs(table) do count = count + 1 end
    return count
end

--- Attach editor-defined custom dispatch fields to the base payload.
--- Stores them in base._customData so each Dispatch:Send implementation
--- can merge them into its own dispatchData table after construction.
---@param base table       The hardcoded dispatch data (message, coords, jobs, blip, etc.)
---@param dispatchCfg table|nil  Config.<Module>.Dispatch from editor overrides
---@return table
function BuildDispatchData(base, dispatchCfg)
    if not dispatchCfg then return base end

    local extra = {}

    if dispatchCfg.code and dispatchCfg.code ~= '' then
        extra.code = dispatchCfg.code
    end

    if dispatchCfg.customFields and type(dispatchCfg.customFields) == 'table' then
        for _, field in ipairs(dispatchCfg.customFields) do
            if field.key and field.key ~= '' then
                extra[field.key] = field.value
            end
        end
    end

    if next(extra) then
        base._customData = extra
    end

    return base
end
