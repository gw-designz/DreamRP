--[[
    Within this section, you'll discover the setup details for the chosen garage.
    If your system isn't listed here, feel free to reach out to the garage creator
    and request the inclusion of its exports in any of these files. Alternatively,
    you can utilize these files to generate your own configuration, which would greatly
    benefit our community.
]]

if Config.Garage ~= "jg-advancedgarages" then
    return
end


Config.Functions["OpenGarageMenu"] = {
    type = "outside", -- inside or outside
    zone = true, -- If the interaction is a zone or ox_target
    maxPerProperty = 1, -- The maximum amount of garage menu's per property
    radius = 2.0, -- The radius of the interaction
    requireKeys = true, -- If the player needs to have keys to interact with the interaction
    label = "Garage Menu",
    icon = "fas fa-car",
    onSelect = function(property, data)
        if property.metadata?.lockdown and Config.PoliceLockdown.DisableGarage then
            Framework.Notify({
                description = locale("property_under_police_lockdown"),
                type = "error"
            })
            return
        end
        if GetResourceState("jg-advancedgarages") == "started" and tonumber(string.sub(GetResourceMetadata("jg-advancedgarages", "version", 0), 2, 2)) >= 3 then
            if cache.vehicle then
                TriggerEvent("jg-advancedgarages:client:store-vehicle", "House " .. property.id, "car")
            else
                local spawnCoords = vector4(data.coords.x, data.coords.y, data.coords.z, data.coords.w)
                TriggerEvent("jg-advancedgarages:client:open-garage", "House " .. property.id, "car", spawnCoords)
            end
        else
            if cache.vehicle then
                TriggerEvent('jg-advancedgarages:client:InsertVehicle', "House " .. property.id, true)
            else
                TriggerEvent('jg-advancedgarages:client:ShowHouseGarage:qs-housing', "House " .. property.id)
            end
        end
    end,
}
