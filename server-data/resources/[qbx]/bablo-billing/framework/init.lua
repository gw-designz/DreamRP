
local FRAMEWORK_CONFIG = {
    esx = {
        resource = 'es_extended',
        name = 'ESX'
    },
    qbcore = {
        resource = 'qb-core',
        name = 'QB-Core'
    },
    qbox = {
        resource = 'qbx_core',
        name = 'Qbox'
    }
}

local function getContext()
    return IsDuplicityVersion() and 'server' or 'client'
end

local function validateFramework(frameworkKey)
    if not frameworkKey then
        return false, "No framework specified in config"
    end

    local frameworkInfo = FRAMEWORK_CONFIG[frameworkKey:lower()]
    if not frameworkInfo then
        return false, string.format("Unknown framework: %s", frameworkKey)
    end

    local resourceState = GetResourceState(frameworkInfo.resource)
    if resourceState ~= "started" then
        return false, string.format("%s resource (%s) is not started. State: %s",
            frameworkInfo.name, frameworkInfo.resource, resourceState)
    end

    return true, frameworkInfo
end

local function shouldInitialize()
    local frameworkKey = Config.Framework
    local context = getContext()

    if Config.DEBUG then
        print(string.format("^3[bablo-billing]^7 Checking %s context with framework: %s",
            context, frameworkKey or "none"))
    end

    local isValid, frameworkInfoOrError = validateFramework(frameworkKey)
    if not isValid then
        if Config.DEBUG then
            print(string.format("^1[bablo-billing]^7 Framework validation failed: %s", frameworkInfoOrError))
        end
        return false
    end

    if Config.DEBUG then
        print(string.format("^2[bablo-billing]^7 Framework %s is available on %s",
            frameworkInfoOrError.name, context))
    end

    return true
end

function IsFrameworkValid()
    return shouldInitialize()
end

function GetFrameworkInfo()
    local frameworkKey = Config.Framework
    local isValid, frameworkInfo = validateFramework(frameworkKey)

    if isValid then
        return {
            key = frameworkKey:lower(),
            name = frameworkInfo.name,
            resource = frameworkInfo.resource,
            isAvailable = true,
            context = getContext()
        }
    else
        return {
            key = frameworkKey,
            isAvailable = false,
            error = frameworkInfo,
            context = getContext()
        }
    end
end
