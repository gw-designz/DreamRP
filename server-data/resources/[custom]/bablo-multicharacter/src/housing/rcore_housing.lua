

local RESOURCE   = 'rcore_housing'
local CONFIG_KEY = 'rcore_housing'

local function activate()
    if Config.Housing == CONFIG_KEY then return true end
    if Config.Housing ~= 'auto' and Config.Housing ~= nil then return false end
    if not IsResourceStartedOrStarting(RESOURCE) then return false end
    Config.Housing = CONFIG_KEY
    return true
end

local function propId(p)
    return p.id or p.propertyId or p.property_id or p.uid or p.identifier
end

local function propLabel(p)
    return p.label or p.name or p.address or p.title or p.house_name
end

local function coordsXYZ(c)
    local t = type(c)
    if (t == 'table' or t == 'vector3' or t == 'vector4') and c.x ~= nil and c.y ~= nil and c.z ~= nil then
        return { x = c.x + 0.0, y = c.y + 0.0, z = c.z + 0.0 }
    end
    return nil
end

local function register()
    if IsDuplicityVersion() then
        Trace('[Housing/rcore_housing] registering SERVER methods')

        function Housing:GetOwned(identifier)
            if not identifier then return nil end
            if GetResourceState(RESOURCE) ~= 'started' then return nil end

            local props
            local ok, err = pcall(function()
                props = exports[RESOURCE]:GetPlayerProperties(identifier)
            end)
            if not ok then
                Trace(('[Housing/rcore_housing] GetPlayerProperties error: %s'):format(tostring(err)))
                return nil
            end
            if type(props) ~= 'table' then return nil end

            local out = {}
            for _, p in ipairs(props) do
                local id     = propId(p)
                local coords = coordsXYZ(p.coords)
                if id ~= nil and coords then
                    out[#out + 1] = {
                        name   = tostring(id),
                        label  = propLabel(p) or ('Property ' .. tostring(id)),
                        coords = coords,
                        kind   = 'house',
                        type   = 'rcore',
                    }
                else
                    Trace(('[Housing/rcore_housing] skipped a property — id=%s coords=%s (report this)'):format(
                        tostring(id), tostring(p.coords)
                    ))
                end
            end

            return (#out > 0) and out or nil
        end

        RegisterNetEvent('bablo-multicharacter:server:rcoreEnterProperty', function(propertyId)
            local src = source
            propertyId = tonumber(propertyId)
            if not propertyId then return end
            if GetResourceState(RESOURCE) ~= 'started' then return end
            pcall(function()
                exports[RESOURCE]:EnterProperty(src, propertyId)
            end)
        end)
        return
    end

    Trace('[Housing/rcore_housing] registering CLIENT methods')

    function Housing:EnterInterior(entry)
        if not entry or not entry.name then return end
        local propertyId = tonumber(entry.name)
        if not propertyId then
            Trace(('[Housing/rcore_housing] EnterInterior — non-numeric property id "%s"'):format(tostring(entry.name)))
            return
        end

        local ped = PlayerPedId()
        SetEntityVisible(ped, true)
        NetworkSetEntityInvisibleToNetwork(ped, false)
        SetEntityAlpha(ped, 255)
        SetEntityCollision(ped, true, true)
        FreezeEntityPosition(ped, false)

        TriggerServerEvent('bablo-multicharacter:server:rcoreEnterProperty', propertyId)
    end
end

if activate() then
    register()
    return
end

if Config.Housing ~= 'auto' and Config.Housing ~= nil then
    return
end

CreateThread(function()
    local deadline = GetGameTimer() + 10000
    while GetGameTimer() < deadline do
        Wait(100)
        if activate() then
            register()
            return
        end
        if Config.Housing ~= 'auto' and Config.Housing ~= nil
            and Config.Housing ~= CONFIG_KEY then
            return
        end
    end
    Trace('[Housing/rcore_housing] resource not started after 10s — giving up')
end)

