local groups = {}
local playerGroup = {}
local invites = {}

local function displayName(src)
    local group = groups[playerGroup[src]] or nil

    if group then
        for _, member in ipairs(group.members) do
            if member.id == src then
                return member.nickname or member.name
            end
        end
    end

    return ('Player %d'):format(src)
end

--- Server id of the group's leader.
---@param groupID string
---@return number?
local function GetGroupLeader(groupID)
    local group = groups[groupID] or nil
    if not group then return nil end
    return group.leaderId
end

--- Number of players in the group.
---@param groupID string
---@return number
local function GetGroupSize(groupID)
    local group = groups[groupID] or nil
    if not group then return 0 end
    return #group.members
end

--- Server ids of the group's members, as a copy so callers cannot mutate our state.
---@param groupID string
---@return number[]
local function GetGroupMembers(groupID)
    local group = groups[groupID] or nil
    if not group then return {} end

    local members = {}
    for i, member in ipairs(group.members) do members[i] = member.id end
    return members
end

--- The group a player belongs to, if any.
---@param playerID number
---@return string?
local function FindGroupByMember(playerID)
    return playerGroup[tonumber(playerID)] or nil
end

--- Fire a client event on every member of a group. Also exported at the bottom.
---@param groupID string
---@param eventname string
---@return boolean fired
local function GroupEvent(groupID, eventname, ...)
    local group = groups[groupID] or nil
    if not group or type(eventname) ~= 'string' then return false end

    for _, member in ipairs(group.members) do
        TriggerClientEvent(eventname, member.id, ...)
    end

    return true
end

local function disband(group, reason)
    for _, member in ipairs(group.members) do
        playerGroup[member.id] = nil
        TriggerClientEvent('royal-groups:client:sync', member.id, false)
        if reason then
            TriggerClientEvent('ox_lib:notify', member.id, { description = reason, type = 'inform' })
        end
    end

    groups[group.id] = nil
end

local function removeMember(src, silent)
    local group = groups[playerGroup[src]] or nil
    if not group then return end

    playerGroup[src] = nil

    local name = displayName(src)
    for i = 1, #group.members do
        if group.members[i].id == src then
            name = group.members[i].nickname or name
            table.remove(group.members, i)
            break
        end
    end

    TriggerClientEvent('royal-groups:client:sync', src, false)

    if #group.members == 0 then
        groups[group.id] = nil
        return
    end

    if group.leaderId == src then
        group.leaderId = group.members[1].id
        TriggerClientEvent('ox_lib:notify', group.leaderId, {
            description = 'You are now the group leader.',
            type = 'inform',
        })
    end

    if not silent then
        for _, member in ipairs(group.members) do
            TriggerClientEvent('ox_lib:notify', member.id, {
                description = ('%s left the group.'):format(name),
                type = 'inform',
            })
        end
    end

    GroupEvent(group.id, 'royal-groups:client:sync', group)
end

lib.callback.register('royal-groups:server:getGroup', function(source)
    return groups[playerGroup[source]] or false
end)

lib.callback.register('royal-groups:server:createGroup', function(source)
    if playerGroup[source] then
        return { success = false, message = 'You are already in a group.' }
    end

    local nickname = Player(source).state.groupNickname
    if type(nickname) ~= 'string' then nickname = '' end
    nickname = nickname:gsub('^%s+', ''):gsub('%s+$', ''):sub(1, Config.NicknameLength)

    local group = {
        id = ("RYL-%010d"):format(math.random(0, 9999999999)),
        leaderId = source,
        members = { { id = source, name = displayName(source), nickname = nickname ~= '' and nickname or nil } },
    }

    groups[group.id] = group
    playerGroup[source] = group.id
    GroupEvent(group.id, 'royal-groups:client:sync', group)

    return { success = true }
end)

lib.callback.register('royal-groups:server:invitePlayer', function(source, data)
    local group = groups[playerGroup[source]] or nil
    if not group then return { success = false, message = 'You are not in a group.' } end
    if group.leaderId ~= source then return { success = false, message = 'Only the leader can invite.' } end

    local target = tonumber(data and data.id)
    if not target or target == source then return { success = false } end
    if not GetPlayerName(target) then return { success = false, message = 'That player is no longer online.' } end
    if playerGroup[target] then return { success = false, message = 'That player is already in a group.' } end

    invites[target] = {
        groupId = group.id,
        from = source,
        expires = os.time() + Config.InviteTimeout,
    }

    TriggerClientEvent('royal-groups:client:invited', target, group.id, displayName(source))
    GroupEvent(group.id, 'royal-groups:client:sync', group)

    return { success = true, message = ('Invite sent to %s.'):format(displayName(target)) }
end)

lib.callback.register('royal-groups:server:kickMember', function(source, data)
    local group = groups[playerGroup[source]] or nil
    if not group then return { success = false } end
    if group.leaderId ~= source then return { success = false, message = 'Only the leader can kick.' } end

    local target = tonumber(data and data.id)
    if not target or target == source then return { success = false } end
    if playerGroup[target] ~= group.id then return { success = false } end

    local name = displayName(target)

    TriggerClientEvent('ox_lib:notify', target, {
        description = 'You were removed from the group.',
        type = 'error',
    })

    removeMember(target, true)

    for _, member in ipairs(group.members) do
        TriggerClientEvent('ox_lib:notify', member.id, {
            description = ('%s was removed from the group.'):format(name),
            type = 'inform',
        })
    end

    return { success = true }
end)

lib.callback.register('royal-groups:server:promoteMember', function(source, data)
    local group = groups[playerGroup[source]] or nil
    if not group then return { success = false } end
    if group.leaderId ~= source then return { success = false, message = 'Only the leader can promote.' } end

    local target = tonumber(data and data.id)
    if not target or playerGroup[target] ~= group.id then return { success = false } end

    group.leaderId = target
    GroupEvent(group.id, 'royal-groups:client:sync', group)

    local name = displayName(target)
    for _, member in ipairs(group.members) do
        TriggerClientEvent('ox_lib:notify', member.id, {
            description = ('%s is now the group leader.'):format(name),
            type = 'inform',
        })
    end

    return { success = true }
end)

lib.callback.register('royal-groups:server:leaveGroup', function(source)
    if not playerGroup[source] then return { success = false } end

    removeMember(source)
    return { success = true }
end)

lib.callback.register('royal-groups:server:disbandGroup', function(source)
    local group = groups[playerGroup[source]] or nil
    if not group then return { success = false } end
    if group.leaderId ~= source then return { success = false, message = 'Only the leader can disband.' } end

    disband(group, 'The group was disbanded.')
    return { success = true }
end)

lib.callback.register('royal-groups:server:setNickname', function(source, data)
    local group = groups[playerGroup[source]] or nil
    if not group then return { success = false } end

    local nickname = data and data.nickname
    if type(nickname) ~= 'string' then nickname = '' end
    nickname = nickname:gsub('^%s+', ''):gsub('%s+$', ''):sub(1, Config.NicknameLength)

    for _, member in ipairs(group.members) do
        if member.id == source then
            member.nickname = nickname ~= '' and nickname or nil
            break
        end
    end

    GroupEvent(group.id, 'royal-groups:client:sync', group)
    return { success = true }
end)

RegisterNetEvent('royal-groups:server:acceptInvite', function(groupId)
    local src = source
    local invite = invites[src]
    invites[src] = nil

    if not invite or invite.groupId ~= groupId then return end

    if os.time() > invite.expires then
        return TriggerClientEvent('ox_lib:notify', src, { description = 'That invite expired.', type = 'error' })
    end

    if playerGroup[src] then
        return TriggerClientEvent('ox_lib:notify', src, { description = 'You are already in a group.', type = 'error' })
    end

    local group = groups[groupId]

    if not group then
        return TriggerClientEvent('ox_lib:notify', src, { description = 'That group no longer exists.', type = 'error' })
    end

    local nickname = Player(src).state.groupNickname
    if type(nickname) ~= 'string' then nickname = '' end
    nickname = nickname:gsub('^%s+', ''):gsub('%s+$', ''):sub(1, Config.NicknameLength)

    group.members[#group.members + 1] = {
        id = src,
        name = displayName(src),
        nickname = nickname ~= '' and nickname or nil,
    }

    playerGroup[src] = group.id
    GroupEvent(group.id, 'royal-groups:client:sync', group)

    local name = displayName(src)
    for _, member in ipairs(group.members) do
        if member.id ~= src then
            TriggerClientEvent('ox_lib:notify', member.id, {
                description = ('%s joined the group.'):format(name),
                type = 'success',
            })
        end
    end
end)

RegisterNetEvent('royal-groups:server:declineInvite', function()
    local src = source
    local invite = invites[src]
    invites[src] = nil

    if invite then
        TriggerClientEvent('ox_lib:notify', invite.from, {
            description = ('%s declined your invite.'):format(displayName(src)),
            type = 'error',
        })
    end
end)

exports('GetGroupLeader', GetGroupLeader)
exports('GetGroupSize', GetGroupSize)
exports('GetGroupMembers', GetGroupMembers)
exports('FindGroupByMember', FindGroupByMember)
exports('GroupEvent', GroupEvent)

AddEventHandler('playerDropped', function()
    local src = source
    invites[src] = nil
    removeMember(src)
end)