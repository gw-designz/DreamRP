--[[
    Provided below is the log configuration, allowing you to make adjustments or create your own.
    If your log sources are not included, you have the option to request the creator to generate
    a file based on this example and include it.
]]

if Config.Logs ~= "ox_lib" then return end

Logs = {
    CreateProperty = function(playerId, propertyId, propertyType, propertyLabel, propertyPrice)
        lib.logger(playerId, "CreateProperty", locale("logs_created_property", playerId, propertyId, propertyType, propertyLabel, propertyPrice))
    end,
    DeleteProperty = function(playerId, propertyId, propertyType, propertyLabel)
        lib.logger(playerId, "DeleteProperty", locale("logs_deleted_property", playerId, propertyId, propertyType, propertyLabel))
    end,
    CreateBuilding = function(playerId, buildingId, buildingLabel)
        lib.logger(playerId, "CreateBuilding", locale("logs_created_building", playerId, buildingId, buildingLabel))
    end,
    DeleteBuilding = function(playerId, buildingId, buildingLabel)
        lib.logger(playerId, "DeleteBuilding", locale("logs_deleted_building", playerId, buildingId, buildingLabel))
    end,
    BuyProperty = function(playerId, propertyId, propertyPrice, propertyLabel)
        lib.logger(playerId, "BuyProperty", locale("logs_bought_property", playerId, propertyId, propertyPrice, propertyLabel))
    end,
    RentProperty = function(playerId, propertyId, propertyPrice, propertyLabel, rentTill)
        lib.logger(playerId, "RentProperty", locale("logs_rented_property", playerId, propertyId, propertyPrice, propertyLabel, rentTill))
    end,
    ExtendRentProperty = function(playerId, propertyId, propertyPrice, propertyLabel, rentFrom, rentTill, rentAs)
        lib.logger(playerId, "ExtendRentProperty", locale("logs_extendrent_property", playerId, propertyId, propertyPrice, propertyLabel, rentFrom, rentTill, rentAs))
    end,
    CancelRentProperty = function(playerId, propertyId, propertyLabel, canceledFrom, rentedFrom, rentedTo, rentedPrice)
        lib.logger(playerId, "CancelRentProperty", locale("logs_cancelrent_property", playerId, propertyId, propertyLabel, canceledFrom, rentedFrom, rentedTo, rentedPrice))
    end,
    SellProperty = function(playerId, propertyId)
        lib.logger(playerId, "SellProperty", locale("logs_sold_property", playerId, propertyId))
    end,
    SetPropertyForSale = function(propertyId)
        lib.logger(propertyId, "SetPropertyForSale", locale("logs_set_property_for_sale", propertyId))
    end,
    AddKeyHolder = function(playerId, propertyId, targetId)
        lib.logger(playerId, "AddKeyHolder", locale("logs_added_keyholder", playerId, propertyId, targetId))
    end,
    RemoveKeyHolder = function(playerId, propertyId, targetId)
        lib.logger(playerId, "RemoveKeyHolder", locale("logs_removed_keyholder", playerId, propertyId, targetId))
    end,
    RemoveAllKeyHolder = function(playerId, propertyId)
        lib.logger(playerId, "RemoveAllKeyHolder", locale("logs_removed_all_keyholder", playerId, propertyId))
    end,
    AddDoor = function(playerId, propertyId, doorId)
        lib.logger(playerId, "AddDoor", locale("logs_added_door", playerId, propertyId, doorId))
    end,
    RemoveDoor = function(playerId, propertyId, doorId)
        lib.logger(playerId, "RemoveDoor", locale("logs_removed_door", playerId, propertyId, doorId))
    end,
    RaidProperty = function(playerId, propertyId, propertyLabel)
        lib.logger(playerId, "RaidProperty", locale("logs_raided_property", playerId, propertyId, propertyLabel))
    end,
    RekeyLock = function(playerId, propertyId, lockType, lockId)
        lib.logger(playerId, "RekeyLock", locale("logs_rekey_lock", playerId, propertyId, lockType, tostring(lockId)))
    end,
    IssuePhysicalKey = function(playerId, propertyId, lockType, lockId, targetId)
        lib.logger(playerId, "IssuePhysicalKey", locale("logs_issued_physical_key", playerId, propertyId, lockType, tostring(lockId), targetId))
    end,
}

-- Set the metatable for the functions list
setmetatable(Logs, LogsMetaTable)
