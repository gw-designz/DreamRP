if not GetResourceState('qbx_core'):find('start') then return end

local QBX = exports.qbx_core

-- Returns nil when the player has no character loaded, so isAuthorised fails cleanly instead of erroring in qbx_core
function GetPlayer(playerId)
    return QBX:GetPlayer(playerId)
end

local function getSource(player)
    return player.source or player.PlayerData.source
end

function GetCharacterId(player)
	return QBX:GetPlayer(getSource(player)).PlayerData.citizenid
end

function IsPlayerInGroup(player, filter)
    return QBX:HasGroup(getSource(player), filter)
end
