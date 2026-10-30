--[[
    fs-garages / integrations/init.lua

    How the garages find the other scripts they work with. Each kind of
    integration (keys, fuel) has a few scripts the garages know; each of
    those adds itself here with Integrations.add. Config.Integrations
    (config/integrations.lua) says which one to use, and Integrations.get
    hands it out. 'custom' hands out the table of the same name in
    integrations/custom.lua instead.
]]

Garage = Garage or {}

local Integrations = { known = {} }
Garage.Integrations = Integrations

--- Makes a script known. `impl.running`, when given, says whether it can be
--- used right now; the order they are added in is the order 'auto' tries.
function Integrations.add(kind, name, impl)
    local list = Integrations.known[kind] or {}
    Integrations.known[kind] = list
    impl.name = name
    list[#list + 1] = impl
end

local warned = {}
local function warnOnce(key, message)
    if warned[key] then return end
    warned[key] = true
    print('^3[fs-garages]^7 ' .. message)
end

function Integrations.get(kind)
    local wanted = (Config.Integrations or {})[kind] or 'auto'
    if wanted == 'none' then return nil end
    if wanted == 'custom' then
        local impl = Custom and Custom[kind]
        if type(impl) ~= 'table' then
            warnOnce(kind .. ':custom', ('Config.Integrations.%s is "custom", but integrations/custom.lua has no Custom.%s.'):format(kind, kind))
            return nil
        end
        impl.name = 'custom'
        return impl
    end
    local known = Integrations.known[kind] or {}
    for _, impl in ipairs(known) do
        if wanted == 'auto' or impl.name == wanted then
            if not impl.running or impl.running() then return impl end
            if wanted ~= 'auto' then
                warnOnce(kind .. ':' .. wanted, ('Config.Integrations.%s is "%s", but %s is not running.'):format(kind, wanted, wanted))
                return nil
            end
        end
    end
    if wanted ~= 'auto' then
        local names = {}
        for _, impl in ipairs(known) do names[#names + 1] = impl.name end
        warnOnce(kind .. ':unknown', ('Config.Integrations.%s is "%s", which the garages do not know. Known: %s, or "custom".')
            :format(kind, wanted, table.concat(names, ', ')))
    end
    return nil
end

--- A function of the chosen script, called so that a mistake inside it is
--- written to the console instead of breaking the garage.
function Integrations.call(kind, fn, ...)
    local impl = Integrations.get(kind)
    local f = impl and impl[fn]
    if type(f) ~= 'function' then return nil end
    local result = table.pack(pcall(f, ...))
    if not result[1] then
        print(('^1[fs-garages]^7 the %s integration (%s) failed in %s: %s'):format(kind, impl.name, fn, tostring(result[2])))
        return nil
    end
    return table.unpack(result, 2, result.n)
end
