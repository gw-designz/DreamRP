if not Config.Modules.PICKPOCKETING then
    return
end

while not eventName do
    Wait(0)
end

RegisterServerCallback({
    eventName = eventName .. "server:onPickPocketFinish",
    eventCallback = function(playerId, args)
        local player = Framework.fetchPlayer(Framework, playerId)
        local itemName = args.itemName

        if not player then
            return { status = false, message = "NO_CHARACTER" }
        end

        if Main.isJobBlacklisted(Main, playerId, "PICKPOCKETING") then
            return { status = false, success = false, message = "BLACKLISTED" }
        end

        -- Determine success: either guaranteed by the client or by random chance
        local succeeded = args.guaranteed
        if not succeeded then
            succeeded = math.random(1, 100) <= Config.PickPocketing.Chance
        end

        if not succeeded then
            -- 30% chance the NPC notices the failed attempt
            local noticed = math.random(1, 100) >= 70
            return { status = false, noticed = noticed }
        end

        -- Find the matching loot entry and give reward
        for _, lootEntry in pairs(Config.PickPocketing.LootTables) do
            if lootEntry.name == itemName then
                -- Count: prefer args.count, then range from config, then 1
                local count = 1
                if args.count then
                    count = args.count
                elseif lootEntry.count then
                    count = math.random(lootEntry.count[1], lootEntry.count[2])
                end

                if itemName == "money" then
                    Framework.addMoney(Framework, playerId, count)
                    sendWebhook(playerId, "PICKPOCKETED_NPC", "Money x" .. count)
                    return { status = true, message = Translate("GIVE_MONEY", { count }) }
                else
                    local given = Inventory.addPlayerItem(Inventory, playerId, itemName, count)
                    sendWebhook(playerId, "PICKPOCKETED_NPC", itemName .. " x" .. count)
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
