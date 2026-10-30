---@meta
---This file was based on ox_lib init.lua file.
---ox_lib <https://github.com/overextended/ox_lib>
---Copyright (C) 2021 Linden <https://github.com/thelindat>
---LGPL-3.0-or-later <https://www.gnu.org/licenses/lgpl-3.0.en.html>

local resourceName = GetCurrentResourceName()
local prpBridge = "prp-bridge"

if resourceName == prpBridge then
    exports("GetConfig", function()
        return BridgeConfig
    end)
else
    BridgeConfig = exports[prpBridge]:GetConfig()
end

if GetResourceState(prpBridge) ~= "started" and resourceName ~= prpBridge then
    error("^1prp-bridge must be started before this resource.^0", 0)
end

if not lib then
    error("^1prp-bridge requires ox_lib to be started.^0", 0)
end

local LoadResourceFile = LoadResourceFile
local context = IsDuplicityVersion() and "server" or "client"

local function noop() end

local disabledModule = setmetatable({}, {
    __index = function()
        return noop
    end,
})

local moduleToDependency = {
    fw = BridgeConfig.FrameWork,
    inv = BridgeConfig.Inventory,
    phone = BridgeConfig.Phone,
    target = BridgeConfig.Target,
    dispatch = BridgeConfig.Dispatch,
    medical = BridgeConfig.Medical,
    minigames = BridgeConfig.Minigames,
    vkeys = BridgeConfig.VehicleKeys,
    vfuel = BridgeConfig.VehicleFuel,
    appearance = BridgeConfig.Appearance,
    voice = BridgeConfig.Voice,
}

local function loadModule(self, module)
    local dir = ("modules/%s"):format(module)
    local targetDependency = moduleToDependency[module]

    if targetDependency == false then
        lib.print.debug("Skipping disabled module", module)
        self[module] = disabledModule
        return self[module]
    end

    local chunk, shared = nil, nil

    if not targetDependency then
        chunk = LoadResourceFile(prpBridge, ("%s/%s.lua"):format(dir, context))
        shared = LoadResourceFile(prpBridge, ("%s/shared.lua"):format(dir))
    else
        chunk = LoadResourceFile(prpBridge, ("%s/%s/%s.lua"):format(dir, targetDependency, context))
        shared = LoadResourceFile(prpBridge, ("%s/%s/shared.lua"):format(dir, targetDependency))
    end

    lib.print.debug("Loading module", module, dir, targetDependency, context)

    if shared then
        chunk = (chunk and ("%s\n%s"):format(shared, chunk)) or shared
    end

    if chunk then
        local fn, err = load(chunk, ("@@prp-bridge/modules/%s/%s.lua"):format(module, context))

        if not fn or err then
            return error(("\n^1Error importing module (%s): %s^0"):format(dir, err), 3)
        end

        local result = fn()

        if module == "fw" and context == "client" and type(result) == "table" then
            local pedStatusChunk = LoadResourceFile(prpBridge, "modules/fw/shared/pedStatus.lua")

            if pedStatusChunk then
                local pedFn, pedErr = load(pedStatusChunk, "@@prp-bridge/modules/fw/shared/pedStatus.lua")

                if pedFn then
                    local pedGetters = pedFn()

                    if pedGetters then
                        for key, getter in pairs(pedGetters) do
                            if result[key] == nil then
                                result[key] = getter
                            end
                        end
                    end
                elseif pedErr then
                    lib.print.error("Failed to load fw pedStatus:", pedErr)
                end
            end
        end

        self[module] = result or noop
        return self[module]
    end
end

local function call(self, index, ...)
    local module = rawget(self, index)

    if not module then
        self[index] = noop
        module = loadModule(self, index)
    end

    return module
end

local bridge = setmetatable({
    context = context,
    name = prpBridge,
    currentResource = resourceName,
    usedInv = BridgeConfig.Inventory,
    usedFw = BridgeConfig.FrameWork,
}, {
    __index = call,
    __call = call,
})

---@type Bridge
_ENV.bridge = bridge

Citizen.CreateThreadNow(function()
    for module, _ in pairs(moduleToDependency) do
        loadModule(bridge, module)
    end
end)

if resourceName == prpBridge or context == "client" then return end

if BridgeConfig.VersionCheck == true then
    CreateThread(function()
        Wait(1000)
        local version = GetResourceMetadata(resourceName, 'version', 0)
        if version and version ~= "" then
            exports[prpBridge]:CheckVersion(resourceName)
        end
    end)
end
