CachedAuctions = {}

lib.callback.register("prp-boosting:loadMarketYour", function(source)
    local stateId = bridge.fw.getIdentifier(source)
    local results = MySQL.query.await("SELECT bl.*, bc.id as contractId FROM boosting_listings bl LEFT JOIN boosting_contracts bc ON bl.contractId = bc.id WHERE bl.authorStateId = ? AND bl.active = 1", { stateId })
    for k, v in pairs(results) do
        v.contract = LoadBoostingContract(v.contractId)
    end
    return results
end)

lib.callback.register("prp-boosting:loadMarket", function(source, offset, history, query, class)
    class = string.len(class) > 0 and class or nil
    local results = {}
    if class then
        results = MySQL.query.await("SELECT bl.*, bc.id as contractId FROM boosting_listings bl LEFT JOIN boosting_contracts bc ON bl.contractId = bc.id WHERE bl.active = ? AND bl.authorStateId != ? AND bc.vehicleClass = ? AND bc.vehicleModel LIKE ? ORDER BY bl.id DESC LIMIT 10 OFFSET ?", { (not history) and 1 or 0, bridge.fw.getIdentifier(source), class, "%" .. query .. "%", offset })
    else
        results = MySQL.query.await("SELECT bl.*, bc.id as contractId FROM boosting_listings bl LEFT JOIN boosting_contracts bc ON bl.contractId = bc.id WHERE bl.active = ? AND bl.authorStateId != ? AND bc.vehicleModel LIKE ? ORDER BY bl.id DESC LIMIT 10 OFFSET ?", { (not history) and 1 or 0, bridge.fw.getIdentifier(source), "%" .. query .. "%", offset or 0 })
    end
    for k, v in pairs(results) do
        v.contract = LoadBoostingContract(v.contractId)
    end
    return results
end)

lib.callback.register("prp-boosting:loadMarketMetaData", function(source)
    local result = MySQL.query.await("SELECT DISTINCT bc.vehicleClass FROM boosting_listings bl LEFT JOIN boosting_contracts bc ON bl.contractId = bc.id WHERE bl.active = 1 AND bl.authorStateId != ?", { bridge.fw.getIdentifier(source) })
    local classes = {}

    for k, v in pairs(result) do
        classes[#classes+1] = v.vehicleClass
    end

    return {
        listingCount = MySQL.scalar.await("SELECT COUNT(*) FROM boosting_listings bl LEFT JOIN boosting_contracts bc ON bl.contractId = bc.id WHERE bl.active = 1 AND bl.authorStateId != ?", { bridge.fw.getIdentifier(source) }),
        availableClasses = classes
    }
end)

function GetListingById(id, source)
    local result = MySQL.single.await("SELECT bl.*, bc.id as contractId, bu.username as authorName FROM boosting_listings bl LEFT JOIN boosting_contracts bc ON bl.contractId = bc.id LEFT JOIN boosting_users bu ON bl.authorStateId = bu.stateId WHERE bl.id = ?", { id })
    if not result then return nil end
    result.latestBids = MySQL.query.await("SELECT blb.*, bu.username as authorName FROM boosting_listings_bids as blb LEFT JOIN boosting_users as bu ON blb.authorStateId = bu.stateId WHERE listingId = ? ORDER BY blb.id DESC LIMIT 3", { result.id })
    result.currentBid = MySQL.query.await("SELECT blb.*, bu.username as authorName FROM boosting_listings_bids as blb LEFT JOIN boosting_users as bu ON blb.authorStateId = bu.stateId WHERE listingId = ? AND authorStateId = ? ORDER BY blb.id DESC LIMIT 1", { result.id, bridge.fw.getIdentifier(source) })[1]
    result.contract = LoadBoostingContract(result.contractId)
    return result
end

lib.callback.register("prp-boosting:loadListing", function(source, id)
    return GetListingById(id, source)
end)

lib.callback.register("prp-boosting:placeBid", function(source, listingId, amount)
    local stateId = bridge.fw.getIdentifier(source)
    local listing = MySQL.single.await("SELECT * FROM boosting_listings WHERE id = ?", { listingId })
    if not listing then return { success = false, error = locale("LISTING_DOESNT_EXIST") } end
    if tonumber(listing.authorStateId) == tonumber(stateId) then return { success = false, error = locale("CANT_BID_ON_YOUR_LISTING") } end
    local biggestBid = MySQL.scalar.await("SELECT price FROM boosting_listings_bids WHERE listingId = ? ORDER BY id DESC LIMIT 1", { listingId })
    if not biggestBid then biggestBid = 0 end
    if tonumber(biggestBid) >= tonumber(amount) then return { success = false, error = locale("BID_TOO_LOW") } end
    if not RemovePlayerCurrency(stateId, listing.cryptoName, amount) then return { success = false, error = locale("NOT_ENOUGH_CRYPTO") } end
    local id = MySQL.insert.await("INSERT INTO boosting_listings_bids (listingId, authorStateId, price) VALUES (@listingId, @authorStateId, @price)", {
        ["@listingId"] = listingId,
        ["@authorStateId"] = stateId,
        ["@price"] = amount
    })
    MySQL.update.await("UPDATE boosting_listings SET price = @currentBid WHERE id = @id", {
        ["@currentBid"] = amount,
        ["@id"] = listingId
    })
    local returnBids = MySQL.query.await("SELECT * FROM boosting_listings_bids WHERE listingId = ? and returned = 0 and id != ?", { listingId, id })
    for k, v in pairs(returnBids) do
        MySQL.update.await("UPDATE boosting_listings_bids SET returned = 1 WHERE id = ?", { v.id })
        AddPlayerCurrency(v.authorStateId, listing.cryptoName, v.price, "Bid Return", "Bid Return", "boosting_bid_return")
    end
    if id then
        local contract = LoadBoostingContract(listing.contractId)
        if not contract then return { success = false, error = locale("CONTRACT_NOT_FOUND") } end
        LoggerBySid(stateId, "boosting", ("Player bid %s on listing %s"):format(amount, listing.id), {
            boosting_eventType = "market_bid",
            boosting_listingId = listing.id,
            boosting_vehicleModel = contract.vehicleModel,
            boosting_vehicleClass = contract.vehicleClass,
            boosting_bid = amount,
        })
        return { success = true, listing = GetListingById(listingId, source) }
    end
    return { success = false, error = locale("ERROR_OCCURED") }
end)

lib.callback.register("prp-boosting:addMarketContract", function(source, contractId, buyType, price)
    local stateId = bridge.fw.getIdentifier(source)
    local contract = LoadBoostingContract(contractId)
    if not contract then return { success = false, error = locale("CONTRACT_NOT_FOUND") } end
    if contract.ownerStateId ~= stateId then return { success = false, error = "You can't add this contract" } end
    if contract.active then return { success = false, error = locale("CONTRACT_ACTIVE") } end
    local onMarket = MySQL.scalar.await("SELECT COUNT(*) FROM boosting_listings WHERE contractId = ? AND active = 1", { contractId }) > 0
    if onMarket then return { success = false, error = locale("CONTRACT_ON_MARKET") } end
    local id = MySQL.insert.await("INSERT INTO boosting_listings (contractId, authorStateId, `type`, price, endTimestamp) VALUES (@contractId, @authorStateStateId, @buyType, @price, FROM_UNIXTIME(@endTimestamp))", {
        ["@contractId"] = contractId,
        ["@authorStateStateId"] = stateId,
        ["@buyType"] = buyType,
        ["@price"] = price,
        ["@endTimestamp"] = buyType == "auction" and (os.time() + 24 * 60 * 60) or nil
    })
    if buyType == "auction" then
        CachedAuctions[#CachedAuctions+1] = MySQL.single.await("SELECT * FROM boosting_listings WHERE id = ?", { id }) 
    end
    if id then
        LoggerBySid(stateId, "boosting", ("Player added listing %s"):format(id), {
            boosting_eventType = "market_add_listing",
            boosting_listingId = id,
            boosting_vehicleModel = contract.vehicleModel,
            boosting_vehicleClass = contract.vehicleClass,
            boosting_price = price,
            boosting_listingType = buyType
        })
        return { success = true, id = id }
    end
    return { success = false, error = locale("ERROR_OCCURED") }
end)

lib.callback.register("prp-boosting:transferContract", function(source, contractId, username)
    local stateId = bridge.fw.getIdentifier(source)
    local contract = LoadBoostingContract(contractId)
    if not contract then return { success = false, error = locale("CONTRACT_NOT_FOUND") } end
    if contract.ownerStateId ~= stateId then return { success = false, error = locale("CANNOT_TRANSFER_CONTRACT") } end
    local onMarket = MySQL.scalar.await("SELECT COUNT(*) FROM boosting_listings WHERE contractId = ? AND active = 1", { contractId }) > 0
    if onMarket then return { success = false, error = locale("CONTRACT_ON_MARKET") } end
    local targetStateId = MySQL.scalar.await("SELECT stateId FROM boosting_users WHERE LOWER(username) = ?", { string.lower(username) })
    if not targetStateId then return { success = false, error = locale("USER_NOT_FOUND") } end
    local result = MySQL.update.await("UPDATE boosting_contracts SET owner = ? WHERE id = ?", { targetStateId, contractId })
    if result > 0 then
        contract.ownerStateId = targetStateId
        LoggerBySid(stateId, "boosting", ("Player transfered contract %s to %s"):format(contractId, targetStateId), {
            boosting_eventType = "transfer_contract",
            boosting_contractId = contract.id,
            boosting_vehicleModel = contract.vehicleModel,
            boosting_vehicleClass = contract.vehicleClass,
            boosting_oldOwner = stateId,
            boosting_newOwner = targetStateId
        })
        return { success = true }
    end
    return { success = false, error = locale("ERROR_OCCURED") }
end)

lib.callback.register("prp-boosting:deleteListing", function(source, listingId)
    local stateId = bridge.fw.getIdentifier(source)
    local listing = MySQL.single.await("SELECT * FROM boosting_listings WHERE id = ?", { listingId })
    if not listing then return { success = false, error = locale("LISTING_DOESNT_EXIST") } end
    if listing.authorStateId ~= stateId then return { success = false, error = locale("CANT_DELETE_LISTING") } end
    if listing.type == "auction" then return { success = false, error = locale("CANT_DELETE_AUCTION") } end
    local result = MySQL.update.await("DELETE FROM boosting_listings WHERE id = ?", { listingId })
    local contract = LoadBoostingContract(listing.contractId)
    if not contract then return { success = false, error = locale("CONTRACT_NOT_FOUND") } end
    if result > 0 then
        LoggerBySid(stateId, "boosting", ("Player deleted his listing %s"):format(listingId), {
            boosting_eventType = "market_delete",
            boosting_listingId = listingId,
            boosting_vehicleModel = contract.vehicleModel,
            boosting_vehicleClass = contract.vehicleClass,
        })
        return { success = true }
    end
    return { success = false, error = locale("ERROR_OCCURED") }
end)

lib.callback.register("prp-boosting:buyContract", function(source, listingId)
    local stateId = bridge.fw.getIdentifier(source)
    local listing = MySQL.single.await("SELECT * FROM boosting_listings WHERE id = ?", { listingId })
    if not listing or listing.active == 0 then return { success = false, error = locale("LISTING_DOESNT_EXIST") } end
    if listing.authorStateId == stateId then return { success = false, error = locale("CANT_BUY_YOUR_LISTING") } end
    if listing.type == "auction" then return { success = false, error = locale("CANT_BUY_AUCTION") } end
    local ownerStateId = listing.authorStateId
    if not RemovePlayerCurrency(stateId, listing.cryptoName, listing.price) then return { success = false, error = locale("NOT_ENOUGH_CRYPTO") } end
    local contractId = MySQL.scalar.await("SELECT contractId FROM boosting_listings WHERE id = ?", { listingId })
    local contract = LoadBoostingContract(contractId)
    if not contract then return { success = false, error = locale("CONTRACT_NOT_FOUND") } end
    local result = MySQL.update.await("UPDATE boosting_contracts SET owner = ? WHERE id = ?", { stateId, contractId })
    if result > 0 then
        MySQL.update.await("UPDATE boosting_listings SET active = 0 WHERE id = ?", { listingId })
        contract.ownerStateId = stateId
        AddPlayerCurrency(ownerStateId, listing.cryptoName, listing.price, "Market Buy", "Market Buy", "boosting_market_buy")
        LoggerBySid(stateId, "boosting", ("Player bought listing %s"):format(listingId), {
            boosting_eventType = "market_bought",
            boosting_listingId = listingId,
            boosting_vehicleModel = contract.vehicleModel,
            boosting_vehicleClass = contract.vehicleClass,
            boosting_price = listing.price,
            boosting_listingOwner = ownerStateId
        })
        return { success = true }
    end
    return { success = false, error = locale("ERROR_OCCURED") }
end)

function FinishAuction(auction)
    MySQL.update.await("UPDATE boosting_listings SET active = 0 WHERE id = ?", { auction.id })
    local biggestBid = MySQL.single.await("SELECT * FROM boosting_listings_bids WHERE listingId = ? ORDER BY id DESC LIMIT 1", { auction.id })
    if biggestBid then
        local contract = LoadBoostingContract(auction.contractId)
        if not contract then return end
        AddPlayerCurrency(contract.ownerStateId, auction.cryptoName, biggestBid.price, "Market Buy", "Market Buy", "boosting_market_buy")
        MySQL.update.await("UPDATE boosting_contracts SET owner = ? WHERE id = ?", { biggestBid.authorStateId, auction.contractId })
        LoggerBySid(stateId, "boosting", ("Player bought listing %s"):format(listingId), {
            boosting_eventType = "market_bought_auction",
            boosting_listingId = auction.id,
            boosting_vehicleModel = contract.vehicleModel,
            boosting_vehicleClass = contract.vehicleClass,
            boosting_price = biggestBid.price,
            boosting_listingOwner = contract.ownerStateId
        })
        contract.ownerStateId = biggestBid.authorStateId
    end
end

function CheckAuctions()
    local results = MySQL.query.await("SELECT * FROM boosting_listings WHERE active = 1 AND `type` = 'auction' AND endTimestamp < NOW()")
    for k, v in pairs(results) do
        FinishAuction(v)
    end
end

Citizen.CreateThread(function()
    Citizen.Wait(1000)
    CheckAuctions()
    CachedAuctions = MySQL.query.await("SELECT * FROM boosting_listings WHERE active = 1 AND `type` = 'auction'")
    while true do
        if #CachedAuctions > 0 then
            for i=#CachedAuctions, 1, -1 do
                local auction = CachedAuctions[i]
                if (auction.endTimestamp/1000) < os.time() then
                    FinishAuction(auction)
                    table.remove(CachedAuctions, i)
                end
            end
        end
        Citizen.Wait(1000)
    end
end)

-- Citizen.CreateThread(function()
--     Citizen.Wait(1000)
--     while true do
--         local expiredListings = MySQL.query.await("SELECT id FROM boosting_listings WHERE active = 1 AND  `type` <> 'auction' AND createdAt < DATE_SUB(NOW(), INTERVAL 30 DAY)")

--         local ids = {}
--         for k, v in pairs(expiredListings) do
--             ids[#ids+1] = v.id
--         end

--         print("[BOOSTING]: Deleting expired listings: ", #ids)

--         MySQL.update.await("UPDATE boosting_listings SET active = 0 WHERE id IN ?", { ids })
--         Citizen.Wait(30 * 60 * 1000)
--     end
-- end)