--[[
    Within this section, you'll discover the setup details for the chosen garage.
    If your system isn't listed here, feel free to reach out to the garage creator
    and request the inclusion of its exports in any of these files. Alternatively,
    you can utilize these files to generate your own configuration, which would greatly
    benefit our community.
]]

if Config.Garage ~= "zerio-garage" then
    return
end

if IsDuplicityVersion() then
    function HasHouseAccess(src, houseId)
        local data = exports[GetCurrentResourceName()]:GetPropertyData(houseId)

        -- todo: use real framework function for getting player identifier from source
        local identifier = Framework.GetPlayerFromId(src)

        if data.owner == identifier then
            return true
        end

        if data.keyHolders[identifier] then
            return true
        end

        return false
    end

    RegisterNetEvent('nolag_properties:client:OpenHousingGarage', function(houseId)
        local src = source

        -- Your own access check
        if not HasHouseAccess(src, houseId) then return end

        local house = exports[GetCurrentResourceName()]:GetPropertyData(houseId)

        local spawnpoint

        if house.metadata.points then
            for _, v in pairs(house.metadata.points) do
                if v.name == "OpenGarageMenu" then
                    spawnpoint = vector4(v.coords.x, v.coords.y, v.coords.z, v.coords.w)
                    break
                end
            end
        end

        if not spawnpoint then
            warn("Couldnt find spawnpoint for house " .. houseId)
            return
        end

        -- Use houseId as the garage ID and house.label as the display name
        exports['zerio-garage']:OpenHousingGarage(src, "nolag_house_" .. houseId, house.label, spawnpoint)
    end)

    -- When the player wants to store their vehicle
    RegisterNetEvent('nolag_properties:client:PutBackHouseVehicle', function(houseId)
        local src = source

        if not HasHouseAccess(src, houseId) then return end

        local house = exports[GetCurrentResourceName()]:GetPropertyData(houseId)

        exports['zerio-garage']:StoreHousingVehicle(src, "nolag_house_" .. houseId, house.label)
    end)
end

Config.Functions["OpenGarageMenu"] = {
    type = "outside",   -- inside or outside
    zone = true,        -- If the interaction is a zone or ox_target
    maxPerProperty = 1, -- The maximum amount of garage menu's per property
    radius = 2.0,       -- The radius of the interaction
    requireKeys = true, -- If the player needs to have keys to interact with the interaction
    label = "Garage Menu",
    icon = "fas fa-car",
    onSelect = function(property)
        if property.metadata?.lockdown and Config.PoliceLockdown.DisableGarage then
            Framework.Notify({
                description = locale("property_under_police_lockdown"),
                type = "error"
            })
            return
        end
        if cache.vehicle then
            TriggerServerEvent("nolag_properties:client:PutBackHouseVehicle", property.id)
        else
            TriggerServerEvent("nolag_properties:client:OpenHousingGarage", property.id)
        end
    end,
}