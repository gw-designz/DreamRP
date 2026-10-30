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
    TriggerEvent("qb-clothing:client:loadPlayerClothing", decoded, ped)
end

---@param ped? number
---@return table?
function appearance.getPedAppearance(ped)
    return nil
end

---@param isNew? boolean
function appearance.openCreator(isNew)
    if isNew then
        TriggerEvent("qb-clothes:client:CreateFirstCharacter")
        return
    end
    TriggerEvent("qb-clothing:client:openMenu")
end

return appearance
