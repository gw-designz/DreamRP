---@type table<string, boolean>
local playerAllowlists = {}

--- Checks if the player has a specific allowlist.
--- @param allowlist string The allowlist to check.
--- @return boolean Returns true if the player has the allowlist, false otherwise.
local function isAllowlisted(allowlist)
    return playerAllowlists[allowlist] == true
end

RegisterNetEvent("prp-bridge:client:updateAllowlist", function(allowlists)
    playerAllowlists = allowlists
    lib.print.debug("Loaded player allowlist:", json.encode(allowlists))
end)

CreateThread(function()
    Wait(1000)
    TriggerServerEvent("prp-bridge:server:requestAllowlist")
end)

exports("IsAllowlisted", isAllowlisted)
