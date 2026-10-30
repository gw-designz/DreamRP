



local RESOURCE   = 'qbx_apartments'
local CONFIG_KEY = 'qbx-apartments'

local function activate()
    if Config.Housing == CONFIG_KEY then return true end
    if Config.Housing ~= 'auto' and Config.Housing ~= nil then return false end
    if not IsResourceStartedOrStarting(RESOURCE) then return false end
    Config.Housing = CONFIG_KEY
    return true
end

local FALLBACK_COORDS = {
    apartment1 = { x = -667.02,   y = -1105.24, z = 14.63, label = 'South Rockford Drive' },
    apartment2 = { x = -1288.52,  y = -430.51,  z = 35.15, label = 'Morningwood Blvd' },
    apartment3 = { x =  269.73,   y = -640.75,  z = 42.02, label = 'Integrity Way' },
    apartment4 = { x = -619.29,   y =  37.69,   z = 43.59, label = 'Tinsel Towers' },
    apartment5 = { x =  291.517,  y = -1078.674,z = 29.405,label = 'Fantastic Plaza' },
}

local function resolveCoords(apartmentType)
    local liveCoords
    pcall(function()
        local res = exports['qbx_apartments']
        if res then
            local getters = {
                'GetApartmentCoords',
                'GetEnterCoords',
                'GetLocations',
                'GetSharedConfig',
            }
            for _, fn in ipairs(getters) do
                if type(res[fn]) == 'function' then
                    local data = res[fn](res, apartmentType)
                    if type(data) == 'table' then
                        if data.x ~= nil and data.y ~= nil and data.z ~= nil then
                            liveCoords = data
                            return
                        end
                        local nested = (data.locations and data.locations[apartmentType])
                                    or data[apartmentType]
                        if type(nested) == 'table' then
                            local enter = nested.enter or nested.coords or nested
                            if type(enter) == 'table' and enter.x ~= nil then
                                liveCoords = enter
                                return
                            end
                        end
                    end
                end
            end
        end
    end)

    if liveCoords then
        return {
            x = liveCoords.x + 0.0,
            y = liveCoords.y + 0.0,
            z = liveCoords.z + 0.0,
        }
    end

    local fallback = FALLBACK_COORDS[apartmentType]
    if fallback then
        return { x = fallback.x, y = fallback.y, z = fallback.z }
    end

    return nil
end

local function register()
    if IsDuplicityVersion() then
        Trace('[Housing/qbx-apartments] registering SERVER methods')

        function Housing:GetOwned(citizenid)
            if not citizenid then return nil end
            if GetResourceState('qbx_apartments') ~= 'started' then return nil end

            local rows = MySQL.query.await(
                'SELECT `name`, `type`, `label` FROM `apartments` WHERE `citizenid` = ? LIMIT 1',
                { citizenid }
            )

            if not rows or #rows == 0 then return nil end

            local row = rows[1]
            local coords = resolveCoords(row.type)
            if not coords then
                Trace(('[Housing/qbx-apartments] apartment=%s type=%s SKIPPED — no coords resolved'):format(
                    tostring(row.name), tostring(row.type)
                ))
                return nil
            end

            local label = row.label
            if not label or label == '' then
                local fb = FALLBACK_COORDS[row.type]
                label = (fb and fb.label) or row.type or row.name
            end

            return {
                {
                    name   = row.name,
                    label  = label,
                    coords = coords,
                    kind   = 'apartment',
                    type   = row.type,
                },
            }
        end
        return
    end

    Trace('[Housing/qbx-apartments] registering CLIENT methods')

    function Housing:EnterInterior(entry)
        if not entry or not entry.name then return end
        if not entry.type then
            Trace(('[Housing/qbx-apartments] EnterInterior — missing type for name=%s'):format(tostring(entry.name)))
            return
        end
        TriggerEvent('apartments:client:SpawnInApartment', entry.name, entry.type)
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
    Trace('[Housing/qbx-apartments] resource not started after 10s — giving up')
end)

