CreateThread(function()
    if Config.Housing ~= 'RxHousing' then return end

    debugPrint("Using RxHousing")

    lib.callback.register('yseries:server:home:get', function(source)
        local propertiesResult = {}
        local playerIdentifier = Framework.GetPlayerFromId(source)?.identifier

        if not playerIdentifier then
            debugPrint('Home: Could not get player id')
            return false
        end

        local properties = exports['RxHousing']:GetOwnedProperties(playerIdentifier)

        if not properties then return propertiesResult end

        for _, v in pairs(properties) do
            local keyholders = exports['RxHousing']:GetPropertyKeyholders(v.propertyId or v.id)
            if not keyholders then keyholders = {} end

            propertiesResult[#propertiesResult + 1] = {
                id = v.propertyId or v.id,
                citizenid = v.citizenid or playerIdentifier,
                coords = v.coords and json.encode(v.coords) or "{}",
                house = v.propertyId or v.id,
                identifier = playerIdentifier,
                keyholders = keyholders,
                label = v.label or v.name or "Property",
                name = v.label or v.name or "Property",
                owned = true,
                price = v.price or 0,
                tier = v.tier or 1,
            }
        end

        return propertiesResult
    end)

    local function getCharacterInfo(playerIdentifier)
        if Config.Framework == 'esx' then
            local result = MySQL.query.await('SELECT firstname, lastname FROM users WHERE identifier = ?', { playerIdentifier })
            if result and result[1] then
                return {
                    firstname = result[1].firstname,
                    lastname = result[1].lastname
                }
            end
        elseif Config.Framework == 'qb' or Config.Framework == 'qbox' then
            local query = MySQL.query.await('SELECT charinfo FROM players WHERE citizenid = ?', { playerIdentifier })
            if query and query[1] and query[1].charinfo then
                local charInfo = json.decode(query[1].charinfo)
                return {
                    firstname = charInfo.firstname,
                    lastname = charInfo.lastname
                }
            end
        end

        return nil
    end

    lib.callback.register('yseries:server:home:get-key-holders-details', function(_, keyHolders)
        local charinfoData = {}

        -- RxHousing likely returns an array of identifiers
        for _, val in pairs(keyHolders) do
            local identifier = val
            -- Handle potential table structure just in case RxHousing returns object instead of plain ID string
            if type(identifier) == "table" then
                identifier = val.identifier or val.citizenid
            end

            if identifier then
                local charInfo = getCharacterInfo(identifier)

                if charInfo then
                    charinfoData[#charinfoData + 1] = {
                        citizenid = identifier,
                        name = charInfo.firstname .. ' ' .. charInfo.lastname,
                    }
                end
            end
        end

        return charinfoData
    end)

    lib.callback.register('yseries:server:home:remove-key-holder', function(source, data)
        -- Removing keyholder using RxHousing export
        local success = exports['RxHousing']:RemoveKeyholder(data.house, data.removedKeyHolder)

        return {
            success = success,
        }
    end)

    lib.callback.register('yseries:server:home:add-key-holder', function(source, data)
        local targetId = tonumber(data.targetSource)
        local player = Framework.GetPlayerFromId(targetId)
        local playerId = player?.identifier

        if not playerId then
            debugPrint('Home: Could not get player id')
            return {
                success = false,
            }
        end

        -- Check if the player already exists in the array
        for _, id in ipairs(data.currentKeyholders) do
            local identifier = id
            if type(id) == 'table' then
                identifier = id.identifier or id.citizenid
            end
            if identifier == playerId then
                return {
                    success = false,
                }
            end
        end

        -- Adding keyholder using RxHousing export
        local success = exports['RxHousing']:AddKeyholder(data.house, playerId)

        if success then
            local keyholders = data.currentKeyholders
            keyholders[#keyholders + 1] = playerId
            return {
                success = true,
                newKeyholders = keyholders,
            }
        else
            return {
                success = false,
            }
        end
    end)
end)
