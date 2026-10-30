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
    if ped ~= PlayerPedId() then return end
    TriggerEvent("skinchanger:loadSkin", decoded)
end

---@param ped? number
---@return table?
function appearance.getPedAppearance(ped)
    local skin
    TriggerEvent("skinchanger:getSkin", function(result)
        skin = result
    end)
    return skin
end

---@param isNew? boolean
function appearance.openCreator(isNew)
    TriggerEvent("esx_skin:openSaveableMenu", function()
    end, function()
    end)
end

return appearance
