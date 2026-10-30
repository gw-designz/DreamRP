if not Config.Modules.PEDAL_BRICK then
    return
end

while not eventName do
    Wait(0)
end

local function getBrickItemName()
    return Config.PedalBrick.ItemName or "bbrick"
end

-- Validate player and consume the brick item before placing.
RegisterServerCallback({
    eventName = eventName .. "server:pedalBrickUse",
    eventCallback = function(playerId)
        local player = Framework.fetchPlayer(Framework, playerId)
        if not player then
            return { status = false, message = "NO_CHARACTER" }
        end

        if Main.isJobBlacklisted(Main, playerId, "PEDAL_BRICK") then
            return { status = false, success = false, message = "BLACKLISTED" }
        end

        local itemName = getBrickItemName()
        local playerItems = Inventory.getPlayerItemsCount(Inventory, playerId)
        local itemCount = playerItems[itemName]

        if not itemCount or itemCount < 1 then
            return { status = false, message = "PEDAL_BRICK_NO_ITEM" }
        end

        local removed = Inventory.removePlayerItem(Inventory, playerId, itemName, 1)
        if not removed then
            return { status = false, message = "PEDAL_BRICK_NO_ITEM" }
        end

        return { status = true }
    end,
})

-- Refund the brick if the player cancelled before it was placed.
RegisterServerEvent(eventName .. "server:pedalBrickRefund")
AddEventHandler(eventName .. "server:pedalBrickRefund", function()
    Inventory.addPlayerItem(Inventory, source, getBrickItemName(), 1)
end)

-- Log when the brick is successfully placed.
RegisterServerEvent(eventName .. "server:pedalBrickDone")
AddEventHandler(eventName .. "server:pedalBrickDone", function()
    sendWebhook(source, "PEDAL_BRICK", "Placed a brick on a gas pedal")
end)
