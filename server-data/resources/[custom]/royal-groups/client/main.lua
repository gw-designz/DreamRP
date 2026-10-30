local currentGroup = nil
local nickname = GetResourceKvpString('royal-groups:nickname')
LocalPlayer.state:set('groupNickname', nickname, true)

local function getNearbyPlayers()
    local coords = GetEntityCoords(cache.ped)
    local inGroup = {}

    if currentGroup then
        for _, member in ipairs(currentGroup.members) do inGroup[member.id] = true end
    end

    local players = {}
    for _, player in ipairs(lib.getNearbyPlayers(coords, Config.NearbyRadius)) do
        local serverId = GetPlayerServerId(player.id)

        if not inGroup[serverId] then
            local name = Player(serverId).state.groupNickname or ('Player %d'):format(serverId)

            players[#players + 1] = {
                id = serverId,
                name = name,
                distance = math.floor(#(coords - player.coords) + 0.5),
            }
        end
    end

    return players
end

local function updateUI()
    SendNUIMessage({
        type = 'update',
        group = currentGroup or false,
        nearby = getNearbyPlayers(),
    })
end

local function closeUI()
    SetNuiFocus(false, false)
    SendNUIMessage({ type = 'close' })
end

local function openUI()
    local group = lib.callback.await('royal-groups:server:getGroup', false)
    currentGroup = group or nil

    SetNuiFocus(true, true)
    SendNUIMessage({
        type = 'open',
        me = { id = GetPlayerServerId(PlayerId()), name = GetPlayerName(PlayerId()) },
        group = currentGroup or false,
        nearby = getNearbyPlayers(),
    })
end

RegisterNetEvent('royal-groups:client:sync', function(group)
    currentGroup = group or nil
    updateUI()
end)

RegisterNetEvent('royal-groups:client:invited', function(groupId, from)
    local accepted = lib.alertDialog({
        header = 'Group Invite',
        content = ('**%s** invited you to their group.'):format(from),
        centered = true,
        cancel = true,
        labels = { confirm = 'Accept', cancel = 'Decline' },
    })

    if accepted == 'confirm' then
        TriggerServerEvent('royal-groups:server:acceptInvite', groupId)
    else
        TriggerServerEvent('royal-groups:server:declineInvite')
    end
end)

RegisterNUICallback('close', function(_, cb)
    closeUI()
    cb({ success = true })
end)

RegisterNUICallback('createGroup', function(_, cb)
    local res = lib.callback.await('royal-groups:server:createGroup', false) or { success = false }

    if res.message then
        lib.notify({ description = res.message, type = res.success })
    end

    cb(res)
end)

RegisterNUICallback('invitePrompt', function(_, cb)
    cb({ success = true })

    SetNuiFocus(false, false)

    local input = lib.inputDialog('Invite Player', {
        {
            type = 'number',
            label = 'Player ID',
            description = 'Server id of the player you want in your group',
            required = true,
            min = 1,
        },
    })

    SetNuiFocus(true, true)

    if not input or not input[1] then return end

    local res = lib.callback.await('royal-groups:server:invitePlayer', false, { id = input[1] }) or { success = false }

    if res.message then
        lib.notify({ description = res.message, type = res.success })
    end
end)

RegisterNUICallback('invitePlayer', function(data, cb)
    local res = lib.callback.await('royal-groups:server:invitePlayer', false, { id = data.id }) or { success = false }

    if res.message then
        lib.notify({ description = res.message, type = res.success })
    end

    cb(res)
end)

RegisterNUICallback('kickMember', function(data, cb)
    local res = lib.callback.await('royal-groups:server:kickMember', false, { id = data.id }) or { success = false }

    if res.message then
        lib.notify({ description = res.message, type = res.success })
    end

    cb(res)
end)

RegisterNUICallback('promoteMember', function(data, cb)
    local res = lib.callback.await('royal-groups:server:promoteMember', false, { id = data.id }) or { success = false }

    if res.message then
        lib.notify({ description = res.message, type = res.success })
    end

    cb(res)
end)

RegisterNUICallback('leaveGroup', function(_, cb)
    local res = lib.callback.await('royal-groups:server:leaveGroup', false) or { success = false }

    if res.message then
        lib.notify({ description = res.message, type = res.success })
    end

    cb(res)
end)

RegisterNUICallback('disbandGroup', function(_, cb)
    local res = lib.callback.await('royal-groups:server:disbandGroup', false) or { success = false }

    if res.message then
        lib.notify({ description = res.message, type = res.success })
    end

    cb(res)
end)

RegisterNUICallback('setNickname', function(data, cb)
    local res = lib.callback.await('royal-groups:server:setNickname', false, { nickname = data.nickname }) or { success = false }

    if res.success then
        ---@diagnostic disable-next-line: cast-local-type
        nickname = data.nickname ~= '' and data.nickname or nil

        LocalPlayer.state:set('groupNickname', nickname, true)

        if nickname then
            SetResourceKvp('royal-groups:nickname', nickname)
        else
            DeleteResourceKvp('royal-groups:nickname')
        end
    end

    if res.message then
        lib.notify({ description = res.message, type = res.success })
    end

    cb(res)
end)

local function GetGroupID()
    return currentGroup and currentGroup.id or nil
end

local function IsGroupLeader()
    return currentGroup ~= nil and currentGroup.leaderId == GetPlayerServerId(PlayerId())
end

exports('GetGroupID', GetGroupID)
exports('IsGroupLeader', IsGroupLeader)

---@diagnostic disable-next-line: missing-parameter
RegisterCommand(Config.Command, function()
    openUI()
end)