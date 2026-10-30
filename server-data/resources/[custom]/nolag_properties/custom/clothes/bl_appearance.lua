--[[ 
    Presented here is the wardrobe configuration, providing you the flexibility to make
    modifications or even design your own from scratch. If your wardrobe is not listed, simply
    reach out to the creator and request the addition of a file following this example.
]]

if Config.Clothes ~= "bl_appearance" then
    return
end

Config.Functions["ClothingMenu"] = {
    type = "inside", -- inside or outside
    maxPerProperty = 1, -- The maximum amount of wardrobe menu's per property
    radius = 1.0, -- The radius of the interaction
    label = "Clothing Menu",
    icon = "fas fa-tshirt",
    onSelect = function(property)
        exports.bl_appearance:OpenMenu('outfits')
    end,
}