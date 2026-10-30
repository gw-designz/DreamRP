--[[
    Within this section, you'll discover the setup details for the chosen garage.
    If your system isn't listed here, feel free to reach out to the garage creator
    and request the inclusion of its exports in any of these files. Alternatively,
    you can utilize these files to generate your own configuration, which would greatly
    benefit our community.
]]

if Config.Garage ~= "qbx_garages" then
    return
end

if IsDuplicityVersion() then
    RegisterNetEvent("nolag_properties:server:property:addHouseGarage", function(propertyId, coords, interactablePoint)
        local property = LoadedProperties[propertyId]
        if not property then return end

        exports.qbx_garages:RegisterGarage('property_' .. property.id, {
            label = property.label,
            vehicleType = "car",
            shared = true,
            canAccess = function(source)
                local intPoint = property.propertyData.metadata.points[interactablePoint]
                local requireKeys = intPoint.requireKeys
                if not requireKeys then return true end

                local hasKey = property:playerHaveKey(source, 'interactable_point_' .. intPoint.id)
                return hasKey
            end,
            accessPoints = {
                {
                    coords = coords,
                    spawn = coords,
                }
            }
        })
    end)

    RegisterNetEvent("nolag_properties:server:property:removeHouseGarage", function(propertyId)
        local property = LoadedProperties[propertyId]
        if not property then return end

        exports.qbx_garages:DeleteGarage('property_' .. property.id)
    end)
end

Config.Functions["OpenGarageMenu"] = {
    type = "outside",   -- inside or outside
    zone = true,
    maxPerProperty = 1, -- The maximum amount of garage menu's per property
    radius = 2.0,       -- The radius of the interaction
    requireKeys = true, -- If the player needs to have keys to interact with the interaction
    label = "Garage Menu",
    icon = "fas fa-car",
    hideTextUI = true,
    onCreate = function(property, coords, interactablePoint)
        TriggerServerEvent("nolag_properties:server:property:addHouseGarage", property.id, coords, interactablePoint?.id)
    end,
    onRemove = function(property)
        TriggerServerEvent("nolag_properties:server:property:removeHouseGarage", property.id)
    end
}