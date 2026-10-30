
if not IsFrameworkValid() or Config.Framework:lower() ~= 'qbox' then
    return
end

local QBX = exports.qbx_core
local m = {}

m.Notify = function(message, type)
    if not message or type == nil then
        Debug:error("Invalid parameters for notify")
        return
    end

    exports.qbx_core:Notify(message, type)
end

m.GetPlayerData = function()
    return QBX:GetPlayerData()
end

Framework = m
