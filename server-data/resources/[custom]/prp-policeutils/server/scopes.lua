Scopes = {}

Scopes.Players = {}

AddEventHandler("playerEnteredScope", function(data)
    local src = tostring(data["for"])
    local target = tostring(data.player)

    if Scopes.Players[src] == nil then Scopes.Players[src] = {} end

    Scopes.Players[src][target] = true
end)

AddEventHandler("playerLeftScope", function(data)
    local src = tostring(data["for"])
    local target = tostring(data.player)

    if Scopes.Players[src] then Scopes.Players[src][target] = nil end
end)

AddEventHandler("playerDropped", function(reason)
    local src = tostring(source)
    Wait(100)
    if Scopes.Players[src] then Scopes.Players[src] = nil end

    for k, v in pairs(Scopes.Players) do
        if v and v[src] then
            Scopes.Players[k][src] = nil
        end
    end
end)

---@param eventName string
---@param src number | string
---@param ... any
Scopes.TriggerScopeEvent = function(eventName, src, ...)
    local players = Scopes.GetClosestPlayers(src) or {}
    local players_ = lib.table.deepclone(players)
    players_[tostring(src)] = true
    local payload = msgpack.pack_args(...)
    for k, v in pairs(players_) do
        TriggerClientEventInternal(eventName, tonumber(k), payload, payload:len())
    end
end

Scopes.GetClosestPlayers = function(src)
    return Scopes.Players[tostring(src)]
end

Scopes.GetPlayersOutsideTargetScope = function(_src)
    local src = tostring(_src)
    local players = {}

    for k, v in pairs(Scopes.Players) do
        if k ~= src and v[src] == nil then
            players[#players+1] = k
        end
    end

    return players
end