---@type table<string, table<string, boolean>>
local allowlists = {}

--- Retrieves the allowlists for a given character ID.
--- @param stateId string|number The character ID to get.
--- @return table<string, boolean> -- The allowlists for the specified character ID.
local function getAllowlist(stateId)
    return allowlists[stateId] or {}
end

--- Checks if a character ID is allowlisted.
--- @param stateId string|number The character ID to check.
--- @param allowlist string The allowlist containing the allowed character IDs.
--- @return boolean -- Returns true if the character ID is allowlisted, false otherwise.
local function hasAllowlist(stateId, allowlist)
    return allowlists[stateId] and allowlists[stateId][allowlist]
end

--- Adds a allowlist to the specified character ID.
--- @param src number The player ID to add.
--- @param stateId string|number The character ID of the player to add.
--- @param allowlist string The allowlist to add.
--- @return boolean -- Returns true if the allowlist was added successfully, false otherwise.
local function addAllowlist(src, stateId, allowlist)
    local insertSQL = [[
        insert into criminal_allowlists (stateId, allowlist)
        values (?, ?)
    ]]

    local affectedRows = MySQL.update.await(insertSQL, {
        stateId, allowlist
    })

    if affectedRows > 0 then
        if not allowlists[stateId] then
            allowlists[stateId] = {}
        end

        allowlists[stateId][allowlist] = true

        if src then
            TriggerClientEvent("prp-bridge:client:updateAllowlist", src, allowlists[stateId])
        end
    end

    return affectedRows > 0
end

--- Removes a player from the allowlist for a specific state.
--- @param src number The player ID to remove.
--- @param stateId string|number The character ID of the player to remove.
--- @param allowlist string The allowlist to remove.
--- @return boolean -- Returns true if the allowlist was removed successfully, false otherwise.
local function removeAllowlist(src, stateId, allowlist)
    local deleteSQL = [[
        delete
        from criminal_allowlists
        where stateId = ? and allowlist = ?
    ]]

    local affectedRows = MySQL.update.await(deleteSQL, {
        stateId, allowlist
    })

    if affectedRows > 0 then
        if allowlists[stateId] then
            allowlists[stateId][allowlist] = nil
        end

        if src then
            TriggerClientEvent("prp-bridge:client:updateAllowlist", src, allowlists[stateId])
        end
    end

    return affectedRows > 0
end

CreateThread(function()
    local sqls = {
        [[
            create table if not exists criminal_allowlists
            (
                stateId  varchar(255)   null,
                allowlist varchar(100)   null
            );
        ]],
        [[
            create index if not exists criminal_allowlists_stateId_index
                on criminal_allowlists (stateId);
        ]]
    }

    for i = 1, #sqls do
        MySQL.query.await(sqls[i])
    end

    local selectSQL = [[
        select
            stateId,
            allowlist
        from criminal_allowlists
    ]]

    local response = MySQL.query.await(selectSQL)
    for i = 1, #response do
        local stateId = response[i].stateId
        local allowlist = response[i].allowlist

        if not allowlists[stateId] then
            allowlists[stateId] = {}
        end

        allowlists[stateId][allowlist] = true
    end

    bridge.fw.registerCommand("add_allowlist", locale("COMMAND_ADD_ALLOWLIST_DESC"), {
        {
            name = "player",
            type = "playerId",
            help = locale("COMMAND_ADD_ALLOWLIST_PLAYER_HELP")
        },
        {
            name = "type",
            type = "string",
            help = locale("COMMAND_ADD_ALLOWLIST_TYPE_HELP")
        }
    }, "group.admin", function(source, args)
        local stateId = bridge.fw.getIdentifier(args.player)
        if not stateId then
            bridge.fw.notify(source, "error", locale("COMMAND_ADD_ALLOWLIST_NO_PLAYER_FOUND", args.type), nil, 5000)
            return
        end

        if hasAllowlist(stateId, args.type) then
            bridge.fw.notify(source, "error", locale("COMMAND_ADD_ALLOWLIST_ALREADY_FOUND", args.player, GetPlayerName(args.player), args.type), nil, 5000)
            return
        end

        local success = addAllowlist(args.player, stateId, args.type)
        if not success then
            bridge.fw.notify(source, "error", locale("COMMAND_ADD_ALLOWLIST_FAILED", args.type, args.player, GetPlayerName(args.player)), nil, 5000)
            return
        end

        bridge.fw.notify(source, "success", locale("COMMAND_ADD_ALLOWLIST_SUCCESS", args.type, args.player, GetPlayerName(args.player)), nil, 5000)
    end)

    bridge.fw.registerCommand("remove_allowlist", locale("COMMAND_REMOVE_ALLOWLIST_DESC"), {
        {
            name = "player",
            type = "playerId",
            help = locale("COMMAND_REMOVE_ALLOWLIST_PLAYER_HELP")
        },
        {
            name = "type",
            type = "string",
            help = locale("COMMAND_REMOVE_ALLOWLIST_TYPE_HELP")
        }
    }, "group.admin", function(source, args)
        local stateId = bridge.fw.getIdentifier(args.player)
        if not stateId then
            bridge.fw.notify(source, "error", locale("COMMAND_REMOVE_ALLOWLIST_NO_PLAYER_FOUND", args.type), nil, 5000)
            return
        end

        if not hasAllowlist(stateId, args.type) then
            bridge.fw.notify(source, "error", locale("COMMAND_REMOVE_ALLOWLIST_NOT_FOUND", args.player, GetPlayerName(args.player), args.type), nil, 5000)
            return
        end

        local success = removeAllowlist(args.player, stateId, args.type)
        if not success then
            bridge.fw.notify(source, "error", locale("COMMAND_REMOVE_ALLOWLIST_FAILED", args.type, args.player, GetPlayerName(args.player)), nil, 5000)
            return
        end

        bridge.fw.notify(source, "success", locale("COMMAND_REMOVE_ALLOWLIST_SUCCESS", args.type, args.player, GetPlayerName(args.player)), nil, 5000)
    end)
end)

RegisterNetEvent("prp-bridge:server:requestAllowlist", function()
    local src = source
    local stateId = bridge.fw.getIdentifier(src)
    if not stateId then return end
    TriggerClientEvent('prp-bridge:client:updateAllowlist', src, getAllowlist(stateId))
end)

AddEventHandler("prp-bridge:server:playerLoad", function(src)
    local stateId = bridge.fw.getIdentifier(src)
    if not stateId then return end
    TriggerClientEvent('prp-bridge:client:updateAllowlist', src, getAllowlist(stateId))
end)

AddEventHandler("prp-bridge:server:playerUnload", function(src)
    TriggerClientEvent('prp-bridge:client:updateAllowlist', src, {})
end)

exports("GetAllowlist", getAllowlist)
exports("HasAllowlist", hasAllowlist)
exports("AddAllowlist", addAllowlist)
exports("RemoveAllowlist", removeAllowlist)
