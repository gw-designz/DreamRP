if not Config.RadioList.Enabled then return end

-- [channel] = array of { player, name, badge, talking, isDead }
local channels = {}

-- ============================================================
--  Helpers
-- ============================================================

-- Broadcasts the current user list for a channel to all members.
local function broadcastChannel(channel)
    local members = channels[channel] or {}
    for _, member in ipairs(members) do
        TriggerClientEvent("p_policejob/client_radio/refreshRadioChannels",
            member.player, channel, members)
    end
end

-- Removes a player from a channel and optionally broadcasts the update.
local function removeFromChannel(playerSource, channel, shouldBroadcast)
    local members = channels[channel]
    if not members then return end

    for i, member in ipairs(members) do
        if member.player == playerSource then
            table.remove(members, i)
            Player(playerSource).state.lastRadioChannel = 0
            if shouldBroadcast then broadcastChannel(channel) end
            break
        end
    end
end

-- ============================================================
--  pma-voice: player radio channel change
-- ============================================================

RegisterNetEvent("pma-voice:setPlayerRadio", function(rawChannel)
    local playerSource  = source
    local playerState   = Player(playerSource).state
    local newChannel    = tonumber(rawChannel)

    -- Notify client of its new channel
    TriggerClientEvent("p_policejob/client_radio/connectedChannel", playerSource, newChannel)

    -- Leave previous channel if different
    local prevChannel = tonumber(playerState.lastRadioChannel)
    if prevChannel and prevChannel ~= 0 and prevChannel ~= newChannel then
        removeFromChannel(playerSource, prevChannel, true)
    end

    -- Join new channel if valid
    if newChannel and newChannel ~= 0 then
        if not channels[newChannel] then channels[newChannel] = {} end

        -- Check if already registered (e.g. duplicate event)
        local alreadyIn = false
        for _, member in ipairs(channels[newChannel]) do
            if member.player == playerSource then alreadyIn = true; break end
        end

        if not alreadyIn then
            local identifier = Bridge.Framework.getUniqueId(playerSource)
            local name       = Bridge.Framework.getPlayerName(playerSource)
            local badge      = Config.RadioList.GetBadge(playerSource, identifier)

            channels[newChannel][#channels[newChannel] + 1] = {
                name    = name,
                badge   = badge,
                talking = Player(playerSource).state.radioTalking and true or false,
                isDead  = Editable:isPlayerDead(playerSource),
                player  = playerSource,
            }

            playerState.lastRadioChannel = newChannel
            broadcastChannel(newChannel)
        end
    end
end)

-- ============================================================
--  radioTalking state bag — update talking flag in channel list
-- ============================================================

AddStateBagChangeHandler("radioTalking", nil, function(bagName, _, newValue)
    local playerSource = GetPlayerFromStateBagName(bagName)
    if playerSource == 0 then return end

    local channel = tonumber(Player(playerSource).state.lastRadioChannel)
    if not channel or not channels[channel] then return end

    for _, member in ipairs(channels[channel]) do
        if member.player == playerSource then
            member.talking = newValue and true or false
            break
        end
    end
end)

-- ============================================================
--  isDead state bag — notify channel members
-- ============================================================

local function notifyChannelOfDeath(playerSource, isDead)
    local channel = tonumber(Player(playerSource).state.lastRadioChannel)
    if not channel or not channels[channel] then return end

    for _, member in ipairs(channels[channel]) do
        if member.player == playerSource then
            member.isDead = isDead
            for _, other in ipairs(channels[channel]) do
                TriggerClientEvent("p_policejob/client_radio/playerDead",
                    other.player, channel, playerSource, isDead)
            end
            break
        end
    end
end

playerRadioDeath = notifyChannelOfDeath  -- global used by other modules

AddStateBagChangeHandler("isDead", nil, function(bagName, _, newValue)
    local playerSource = GetPlayerFromStateBagName(bagName)
    if playerSource == 0 then return end
    notifyChannelOfDeath(playerSource, newValue and true or false)
end)

-- ============================================================
--  Cleanup on disconnect
-- ============================================================

AddEventHandler("playerDropped", function()
    local playerSource = source
    local playerState  = Player(playerSource).state
    local channel      = tonumber(playerState and playerState.lastRadioChannel)
    if channel and channel ~= 0 then
        removeFromChannel(playerSource, channel, true)
    end
end)
