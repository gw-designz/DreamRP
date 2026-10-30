local appearance = {}

local function decodeAppearance(data)
    if type(data) == "string" then
        return json.decode(data)
    end
    return data
end

---@param ped number
---@param data table|string
function appearance.setPedAppearance(ped, data)
    local decoded = decodeAppearance(data)
    if not decoded then return end
    if ped == PlayerPedId() and decoded.model then
        exports["illenium-appearance"]:setPlayerAppearance(decoded)
        return
    end
    exports["illenium-appearance"]:setPedAppearance(ped, decoded)
end

---@param ped? number
---@return table?
function appearance.getPedAppearance(ped)
    ped = ped or PlayerPedId()
    return exports["illenium-appearance"]:getPedAppearance(ped)
end

---@param isNew? boolean
function appearance.openCreator(isNew)
    if isNew then
        TriggerEvent("qb-clothes:client:CreateFirstCharacter")
        return
    end
    TriggerEvent("illenium-appearance:client:openClothingShop", true)
end

return appearance
