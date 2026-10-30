
IsResourceStartedOrStarting = function(resource)
    local state = GetResourceState(resource)
    return state == "started" or state == "starting"
end

if Config.Framework == "auto" then
    if IsResourceStartedOrStarting("es_extended") then
        Config.Framework = "esx"
    elseif IsResourceStartedOrStarting("qbx_core") then
        Config.Framework = "qbox"
    elseif IsResourceStartedOrStarting("qb-core") then
        Config.Framework = "qbcore"
    end

    -- Trace("Detected framework: " .. Config.Framework)
end

if Config.Target == "auto" then
    if IsResourceStartedOrStarting("qb-target") then
        Config.Target = "qb-target"
    elseif IsResourceStartedOrStarting("ox_target") then
        Config.Target = "ox_target"
    else
        Config.Target = "standalone"
    end
end
