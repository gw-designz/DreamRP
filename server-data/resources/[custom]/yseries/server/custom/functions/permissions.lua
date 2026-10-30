function CanCreateNewsArticles(source)
    local xPlayer = Framework.GetPlayerFromId(source)

    if not xPlayer then return false end

    if IsPlayerAceAllowed(source, 'admin') then return true end

    if lib.table.contains(Config.News.Jobs, xPlayer.getJob().name) then
        return true
    end

    return false
end

lib.callback.register('permissions:server:admin:check', function(source)
    local player = Framework.GetPlayerFromId(source)
    if not player then return false end

    return IntToBool(Framework.IsPlayerAdmin(source))
end)
