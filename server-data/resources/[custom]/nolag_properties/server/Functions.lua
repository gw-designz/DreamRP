if Config.DynamicDoors then
    SetConvarReplicated('game_enableDynamicDoorCreation', 'true')
end

local oxLibVersion = GetResourceMetadata('ox_lib', 'version', 0)
local function compareVersions(version1, version2)
    local v1 = {}
    local v2 = {}

    for num in string.gmatch(version1, "%d+") do
        table.insert(v1, tonumber(num))
    end

    for num in string.gmatch(version2, "%d+") do
        table.insert(v2, tonumber(num))
    end

    for i = 1, math.max(#v1, #v2) do
        local n1 = v1[i] or 0
        local n2 = v2[i] or 0

        if n1 < n2 then
            return -1
        elseif n1 > n2 then
            return 1
        end
    end

    return 0
end

if compareVersions(oxLibVersion, '3.30.10') < 0 then
    lib.print.warn(('ox_lib version %s detected. v3.30.10+ is recommended for stability.'):format(oxLibVersion))
    lib.print.warn('Download the latest version: https://github.com/CommunityOx/ox_lib/releases/latest')
end

-- a function to check if every column is in the properties table
local function checkPropertiesTable()
    local columns = MySQL.query.await('SHOW COLUMNS FROM properties')
    local columnsNames = {}
    for _, v in pairs(columns) do
        columnsNames[#columnsNames + 1] = v.Field
    end

    local missingColumns = {}
    local propertiesColumns = {
        'id',
        'address',
        'label',
        'type',
        'keyholders',
        'metadata',
        'buildingid',
        'ownerid',
        'renterid',
        'priceid',
        'rentpriceid',
        'last_entered',
        'electricity_last_payment',
        'water_last_payment',
        'internet_last_payment',
        'forsale',
        'forrent',
        'formortgage'
    }
    for i = 1, #propertiesColumns do
        if not lib.table.contains(columnsNames, propertiesColumns[i]) then
            missingColumns[#missingColumns + 1] = propertiesColumns[i]
        end
    end

    if #missingColumns > 0 then
        lib.print.error('Missing columns in the properties table: ' .. table.concat(missingColumns, ', '))
        lib.print.error('Please drop the properties table and restart the resource')
    end

    return #missingColumns == 0
end

function LoadPropertiesFromDatabase()
    local checkForMissingTables = checkPropertiesTable()
    if not checkForMissingTables then
        return
    end

    local success, properties = pcall(MySQL.query.await, [[
        SELECT
            p.id,
            p.address,
            p.label,
            p.type,
            p.buildingid,
            p.metadata,
            p.keyholders,
            p.electricity_last_payment,
            p.water_last_payment,
            p.internet_last_payment,
            p.forsale,
            p.forrent,
            o.type AS owner_type,
            o.identifier AS owner_identifier,
            o.purchase_price AS purchase_price,
            o.purchase_date AS purchase_date,
            r.id AS renter_id,
            r.type AS renter_type,
            r.identifier AS renter_identifier,
            r.rented_from AS rented_from,
            r.rent_data AS rent_data,
            r.rented_to AS rented_to,
            r.rented_price AS rented_price,
            r.auto_renew AS auto_renew,
            rpr.price AS rentPrice,
            rpr.set_by AS rentPrice_set_by,
            rpr.set_on AS rentPrice_set_on,
            pr.price,
            pr.set_by AS price_set_by,
            pr.set_on AS price_set_on
        FROM
            properties p
        LEFT JOIN properties_owners o ON p.ownerid = o.id
        LEFT JOIN properties_renters r ON p.renterid = r.id
        LEFT JOIN properties_prices pr ON p.priceid = pr.id
        LEFT JOIN properties_rentprices rpr ON p.rentpriceid = rpr.id;
    ]])

    if not success then
        lib.print.error(
            'Failed to load properties from database. If you are migrating from the old version, drop the properties table and restart the resource - https://docs.nolag.dev/paid-scripts/properties/installation#database')
        return
    end

    if properties and properties[1] then
        for _, property in pairs(properties) do
            local metaData = ConvertToVector(json.decode(property.metadata))
            local propertyData = {
                id = property.id,
                ownerType = property.owner_type,
                owner = property.owner_identifier,
                label = property.label,
                address = property.address,
                price = tonumber(property.price),
                rentPrice = tonumber(property.rentPrice) or 0,
                purchasePrice = tonumber(property.purchase_price),
                purchaseDate = property.purchase_date,
                keyHolders = property.keyholders and json.decode(property.keyholders) or {},
                type = property.type,
                doorLocked = Config.LockDoorsByDefault and true or type(metaData.doorLocked) ~= "boolean" and true or metaData.doorLocked,
                buildingId = property.buildingid,
                utilities = {
                    electricity = { lastPayment = property.electricity_last_payment and math.floor(property.electricity_last_payment / 1000) or 0 },
                    water = { lastPayment = property.water_last_payment and math.floor(property.water_last_payment / 1000) or 0 },
                    internet = { lastPayment = property.internet_last_payment and math.floor(property.internet_last_payment / 1000) or 0 }
                },
                forSale = property.forsale == 1,
                forRent = property.forrent == 1,
                metadata = metaData, -- Additional information
                rentData = property.renter_id and {
                    id = property.renter_id,
                    type = property.renter_type,
                    identifier = property.renter_identifier,
                    rentData = property.rent_data and json.decode(property.rent_data) or nil,
                    rentedFrom = property.rented_from and os.date('%Y-%m-%d', property.rented_from / 1000) or nil,
                    rentedTo = property.rented_to and os.date('%Y-%m-%d', property.rented_to / 1000) or nil,
                    rentedPrice = property.rented_price,
                    autoRenew = property.auto_renew
                } or nil,
            }
            LoadedProperties[property.id] = ServerProperty:new(propertyData)
        end
    end
end

function LoadBuildingsFromDatabase()
    local Buildings = MySQL.query.await('SELECT * FROM buildings')
    if Buildings and Buildings[1] then
        for _, v in pairs(Buildings) do
            LoadedBuildingsIds[#LoadedBuildingsIds + 1] = v.id
            LoadedBuildings[v.id] = ServerBuilding:new({
                id = v.id,
                name = v.name,
                label = v.label,
                metadata = json.decode(v.metadata)
            })
        end
    end
end

---@param price number
---@return boolean|nil
function RemoveMoneyFromDefaultSeller(price)
    price = math.floor(price)
    local type = Config.DefaultBuyerType
    local identifier = Config.DefaultBuyerIdentifier
    if type == 'user' then
        local xPlayer = Framework.GetPlayerFromIdentifier(identifier)
        if xPlayer then
            -- if the player is online
            -- removeAccountMoney should check if the player has enough money but we will check it here too
            if xPlayer.getAccount('bank').money >= price then
                xPlayer.removeAccountMoney('bank', price)
                return true
            else
                return false
            end
        else
            -- if the player is offline
            return RemoveOfflinePlayerMoney(identifier, 'bank', price)
        end
    else
        if not RemoveMoneyFromSociety then
            lib.print.error('RemoveMoneyFromSociety function is not found, make sure to configure your banking in Config.Banking')
            return false
        end

        return RemoveMoneyFromSociety(identifier, price, '')
    end
end

---@param type 'user' | 'society' The type of the account
---@param identifier string The identifier of the account
---@param price number The amount of money that will be removed
---@param executor string The identifier of the player that executes the action
---@param reason string The reason of the action
---@return boolean|nil
function RemoveMoney(type, identifier, price, executor, reason)
    price = math.floor(price)
    if type == 'user' then
        local xPlayer = Framework.GetPlayerFromIdentifier(identifier)
        if xPlayer then
            -- if the player is online
            -- removeAccountMoney should check if the player has enough money but we will check it here too
            if xPlayer.getAccount('bank').money >= price then
                xPlayer.removeAccountMoney('bank', price, reason)
                return true
            else
                return false
            end
        else
            -- if the player is offline
            return RemoveOfflinePlayerMoney(identifier, 'bank', price, reason)
        end
    else
        if not RemoveMoneyFromSociety then
            lib.print.error('RemoveMoneyFromSociety function is not found, make sure to configure your banking in Config.Banking')
            return false
        end

        return RemoveMoneyFromSociety(identifier, price, executor)
    end
end

function AddMoney(type, identifier, price, executor, reason)
    price = math.floor(price)
    if type == 'user' then
        local xPlayer = Framework.GetPlayerFromIdentifier(identifier)
        if xPlayer then
            -- if the player is online
            xPlayer.addAccountMoney('bank', price, reason)
            return true
        else
            -- if the player is offline
            return AddOfflinePlayerMoney(identifier, 'bank', price, reason)
        end
    else
        if not AddMoneyToSociety then
            lib.print.error('AddMoneyToSociety function is not found, make sure to configure your banking in Config.Banking')
            return false
        end

        return AddMoneyToSociety(identifier, price, executor)
    end
end

function ConvertToVector(inputTable)
    local newTable = {}

    for key, value in pairs(inputTable) do
        if type(value) == 'table' then
            if value.x and value.y and value.z and value.w then
                newTable[key] = vector4(value.x, value.y, value.z, value.w)
            elseif value.x and value.y and value.z then
                newTable[key] = vector3(value.x, value.y, value.z)
            elseif value.x and value.y then
                newTable[key] = vector2(value.x, value.y)
            else
                newTable[key] = ConvertToVector(value)
            end
        else
            newTable[key] = value
        end
    end

    return newTable
end

function HasKey(identifier, propertyId, lock)
    local property = LoadedProperties[propertyId]
    if not property then return false end
    return property:playerHaveKey(identifier, lock)
end

exports('HasKey', HasKey)

-- ? Idk how this works but it should work as a backward compatibility for qb-houses
AddEventHandler('__cfx_export_qb-houses_hasKey', function(setCB)
    setCB(function(identifier, cid, house)
        return HasKey(cid, house)
    end)
end)

-- Function to check if a column exists in a table
local function columnExists(tableName, columnName)
    local result = MySQL.query.await("SHOW COLUMNS FROM `" .. tableName .. "` LIKE ?", { columnName })
    return result and #result > 0
end

-- Ensure the auto_renew column exists in the properties_renters table
function EnsureAutoRenewColumn()
    if not columnExists('properties_renters', 'auto_renew') then
        local result = MySQL.query.await(
            'ALTER TABLE properties_renters ADD COLUMN auto_renew TINYINT(1) NOT NULL DEFAULT 0'
        )
        if result then
            lib.print.info("Added 'auto_renew' column to 'properties_renters' table.")
        else
            lib.print.error("Failed to add 'auto_renew' column to 'properties_renters' table.")
        end
    end
end

function EnsureFurnitureMetadataColumn()
    if columnExists('properties_furniture', 'metadata') then return end
    local result = MySQL.query.await("ALTER TABLE properties_furniture ADD COLUMN metadata LONGTEXT NULL DEFAULT NULL")
    if result then
        lib.print.info("Added 'metadata' column to 'properties_furniture' table.")
    else
        lib.print.error("Failed to add 'metadata' column to 'properties_furniture' table.")
    end
end

-- Function to migrate furniture data
function MigrateFurnitureData()
    if not columnExists('properties_furniture', 'require_keys') then
        local addResult = MySQL.query.await("ALTER TABLE properties_furniture ADD COLUMN require_keys VARCHAR(1) DEFAULT NULL")
        if addResult then
            lib.print.info("Added 'require_keys' column to 'properties_furniture' table.")
        else
            lib.print.error("Failed to add 'require_keys' column to 'properties_furniture' table.")
            return
        end
    end

    -- Check if 'furniture' column exists
    if not columnExists('properties', 'furniture') then
        lib.print.debug("Furniture column does not exist in 'properties' table. Migration not required.")
        return
    end

    lib.print.info("Starting furniture data migration...")

    -- Fetch all properties with non-NULL furniture data
    local properties = MySQL.query.await("SELECT id, furniture FROM properties WHERE furniture IS NOT NULL")
    if not properties or #properties == 0 then
        lib.print.info("No properties with furniture data found.")
        -- Proceed to drop the furniture column
        local dropResult = MySQL.query.await("ALTER TABLE properties DROP COLUMN furniture")
        if dropResult then
            lib.print.info("Furniture column has been dropped from 'properties' table.")
        else
            lib.print.error("Failed to drop 'furniture' column from 'properties' table.")
        end
        return
    end

    local migrationErrors = false

    for _, prop in ipairs(properties) do
        local propertyId = prop.id
        local furnitureJson = prop.furniture

        -- Parse the JSON data
        local success, furnitureData = pcall(function()
            return json.decode(furnitureJson)
        end)

        if not success or type(furnitureData) ~= "table" then
            lib.print.error(("Error parsing JSON for property ID %d. Skipping."):format(propertyId))
            migrationErrors = true
        else
            local inserts = {}
            local insertCount = 0

            for environment, items in pairs(furnitureData) do
                if environment == 'inside' or environment == 'outside' then
                    for _, item in pairs(items) do
                        -- Extract item attributes with safe defaults
                        local furnitureId = tonumber(item.id) or 0
                        local coords = item.coords or {}
                        local rotation = item.rotation or {}
                        local price = tonumber(item.price) or 0.0
                        local model = item.model or ""
                        local itemType = item.type or ""
                        local label = item.label or ""

                        local coordsX = tonumber(coords.x) or 0.0
                        local coordsY = tonumber(coords.y) or 0.0
                        local coordsZ = tonumber(coords.z) or 0.0
                        local rotationX = tonumber(rotation.x) or 0.0
                        local rotationY = tonumber(rotation.y) or 0.0
                        local rotationZ = tonumber(rotation.z) or 0.0

                        -- Prepare data for batch insertion
                        inserts[#inserts + 1] = {
                            propertyId = propertyId,
                            furnitureId = furnitureId,
                            environment = environment,
                            coordsX = coordsX,
                            coordsY = coordsY,
                            coordsZ = coordsZ,
                            rotationX = rotationX,
                            rotationY = rotationY,
                            rotationZ = rotationZ,
                            price = price,
                            model = model,
                            type = itemType,
                            label = label
                        }

                        insertCount = insertCount + 1
                    end
                else
                    lib.print.error(("Unknown environment '%s' in property ID %d. Skipping."):format(environment, propertyId))
                    migrationErrors = true
                end
            end

            if insertCount > 0 then
                -- Batch insert furniture items for this property
                local sql = [[
                    INSERT INTO properties_furniture (
                        propertyId,
                        furnitureId,
                        environment,
                        coords_x,
                        coords_y,
                        coords_z,
                        rotation_x,
                        rotation_y,
                        rotation_z,
                        price,
                        model,
                        type,
                        label
                    ) VALUES
                ]]

                local values = {}
                local params = {}

                for i, data in ipairs(inserts) do
                    values[#values + 1] = "(?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)"
                    params[#params + 1] = data.propertyId
                    params[#params + 1] = data.furnitureId
                    params[#params + 1] = data.environment
                    params[#params + 1] = data.coordsX
                    params[#params + 1] = data.coordsY
                    params[#params + 1] = data.coordsZ
                    params[#params + 1] = data.rotationX
                    params[#params + 1] = data.rotationY
                    params[#params + 1] = data.rotationZ
                    params[#params + 1] = data.price
                    params[#params + 1] = data.model
                    params[#params + 1] = data.type
                    params[#params + 1] = data.label
                end

                sql = sql .. table.concat(values, ",")

                -- Execute the batch insert synchronously
                local insertResult = MySQL.query.await(sql, params)
                if insertResult then
                    lib.print.info(("Migrated %d furniture items for property ID %d."):format(insertCount, propertyId))
                else
                    lib.print.error(("Failed to migrate furniture items for property ID %d."):format(propertyId))
                    migrationErrors = true
                end
            else
                lib.print.info(("No furniture items to migrate for property ID %d."):format(propertyId))
            end
        end
    end

    -- After all migrations
    if not migrationErrors then
        -- All migrations successful, drop the 'furniture' column
        local dropResult = MySQL.query.await("ALTER TABLE properties DROP COLUMN furniture")
        if dropResult then
            lib.print.info(
            "Furniture data migration completed successfully. 'furniture' column has been dropped from 'properties' table. It is recommended to restart the resource.")
        else
            lib.print.error("Furniture data migration completed, but failed to drop 'furniture' column from 'properties' table.")
        end
    else
        lib.print.error("Furniture data migration completed with errors. 'furniture' column has not been dropped.")
    end
end

---@param address string
---@return string
function GetAddress(address)
    local targetAddress = address -- e.g., "Alta St", without the number
    local maxNumber = 0

    -- Query to select addresses that contain the target address, sorted by the numeric part in descending order
    local result = MySQL.query.await([[
      SELECT address FROM properties WHERE address LIKE ? 
      UNION ALL
      SELECT name as address FROM buildings WHERE name LIKE ?
      ORDER BY address DESC
    ]], { targetAddress .. '%', targetAddress .. '%' })

    -- If there are results, extract the number from the first one (highest number)
    if #result > 0 then
        --- Get the biggest number from the addresses
        for i = 1, #result do
            local number = result[i].address:gsub(targetAddress .. ' ', '') -- Remove the street part from the address
            number = tonumber(number) or 0                                  -- Convert the number to a number, or 0 if it's not a number
            if number > maxNumber then
                maxNumber = number
            end
        end
    end

    -- Return the next highest number
    return targetAddress .. " " .. maxNumber + 1
end

---Get a unique name for a property
---@param name string
---@return string
function GetUniqueName(name)
    local result = MySQL.query.await("SELECT label FROM properties WHERE label LIKE ?", { name .. '%' })
    local maxNumber = 0
    if #result > 0 then
        for i = 1, #result do
            local number = result[i].label:gsub(name .. ' ', '')
            number = tonumber(number) or 0
            if number > maxNumber then
                maxNumber = number
            end
        end
    end
    return name .. " " .. maxNumber + 1
end

---@param playerId number
---@param furnitureName string
---@return boolean, string?
function GiveFurnitureToPlayer(playerId, furnitureName)
    local player = Framework.GetPlayerFromId(playerId)
    if not player then return false, 'Player not found' end
    local furnitureData = GetFurnitureDataFromObject(furnitureName)
    if not furnitureData then return false, 'Furniture not found' end
    local metadata = {
        label = furnitureData.label,
        furnitureName = furnitureName,
        imageurl = 'nui://nolag_properties/web/build/images/props/' .. furnitureName .. '.webp',
        description = 'A piece of furniture from the property',
        weight = furnitureData.weight or Config.DefaultFurnitureWeight,
    }
    local success = exports.ox_inventory:AddItem(player.source, 'furniture', 1, metadata)
    if success then
        return true, nil
    else
        return false, 'Failed to give furniture to player'
    end
end

RegisterNetEvent('txsv:req:spectate:start', function(targetId)
end)

RegisterNetEvent('txsv:req:spectate:cycle', function(currentTargetId, isNextPlayer)
end)

RegisterNetEvent('txsv:req:spectate:end', function()
end)
