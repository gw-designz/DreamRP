if not Config.Modules.MUGGING then
    return
end

while not eventName do
    Wait(0)
end

RegisterServerCallback({
    eventName = eventName .. "server:giveMuggingReward",
    eventCallback = function(playerId, args)
        local player = Framework.fetchPlayer(Framework, playerId)
        local itemName = args.itemName

        if not player then
            return { status = false, message = "NO_CHARACTER" }
        end

        if Main.isJobBlacklisted(Main, playerId, "MUGGING") then
            return { status = false, success = false, message = "BLACKLISTED" }
        end

        -- Find matching loot entry
        for _, lootEntry in pairs(Config.Mugging.LootTables) do
            if lootEntry.name == itemName then
                local count = 1
                if lootEntry.count then
                    count = math.random(lootEntry.count[1], lootEntry.count[2])
                end

                if itemName == "money" then
                    Framework.addMoney(Framework, playerId, count)
                    sendWebhook(playerId, "MUGGED_NPC", "Money x" .. count)
                    return { status = true, message = Translate("GIVE_MONEY", { count }) }
                else
                    local given = Inventory.addPlayerItem(Inventory, playerId, itemName, count)
                    sendWebhook(playerId, "MUGGED_NPC", itemName .. " x" .. count)
                    if not given then
                        return { status = false, message = "ITEM_FAILED_TO_GIVE" }
                    end
                    return { status = true }
                end
            end
        end

        return { status = true }
    end,
})
