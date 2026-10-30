-- Module guard
if not Config.Modules.MAILBOX_ROBBERY then
    return
end

-- Wait for eventName to be set by s_main.lua
while not eventName do
    Wait(0)
end

-- ─── Cooldown State ───────────────────────────────────────────────────────────
-- Maps coordKey → unix expiry timestamp.

local mailboxCooldowns = {}

-- ─── Cooldown Cleanup Thread ──────────────────────────────────────────────────

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(60000)
        local now = os.time()
        for key, expiresAt in pairs(mailboxCooldowns) do
            if expiresAt and expiresAt < now then
                mailboxCooldowns[key] = nil
            end
        end
    end
end)

-- ─── Editor API ───────────────────────────────────────────────────────────────

function MailboxEditor_GetCooldowns()
    local now    = os.time()
    local result = {}
    for key, expiresAt in pairs(mailboxCooldowns) do
        if expiresAt == -1 or expiresAt > now then
            result[#result + 1] = {
                key       = key,
                expiresAt = expiresAt,
                remaining = expiresAt == -1 and -1 or (expiresAt - now),
            }
        end
    end
    return result
end

function MailboxEditor_ClearCooldown(key)
    mailboxCooldowns[key] = nil
end

function MailboxEditor_ClearAll()
    for key in pairs(mailboxCooldowns) do
        mailboxCooldowns[key] = nil
    end
end

-- ─── Helpers ──────────────────────────────────────────────────────────────────

local function rollItemBreak(source, itemData)
    local cfg = Config.Mailboxes.Item
    if not cfg.Require or not itemData then return end

    if math.random(1, 100) <= cfg.BreakChance then
        local removed = Inventory:removePlayerItem(source, itemData, 1)
        if not removed then
            Trace("Failed to remove item")
            return
        end
        Framework:Notify(source, Translate("LOCKPICK_BROKE"))
    end
end

-- ─── Set Broken ───────────────────────────────────────────────────────────────

RegisterNetEvent(eventName .. "server:setBrokenMailbox")
AddEventHandler(eventName .. "server:setBrokenMailbox", function(data)
    if not Framework:fetchPlayer(source) then return end

    local expiresAt = os.time() + Config.Mailboxes.Cooldown
    mailboxCooldowns[data.coordKey] = expiresAt

    Trace(
        "Mailbox broken at coordKey: " .. data.coordKey ..
        " until: "        .. expiresAt ..
        " current time: " .. os.time()
    )

    rollItemBreak(source, data.itemData)
end)

-- ─── Is Mailbox Broken? ───────────────────────────────────────────────────────

RegisterServerCallback({
    eventName     = eventName .. "server:isMailboxBroken",
    eventCallback = function(source, coordKey)
        if not Framework:fetchPlayer(source) then
            return { status = false, message = "NO_CHARACTER" }
        end

        local now       = os.time()
        local expiresAt = mailboxCooldowns[coordKey]
        local available = expiresAt == nil

        Trace(
            "Checking mailbox coordKey: " .. coordKey ..
            " stored time: "  .. tostring(expiresAt) ..
            " current time: " .. now ..
            " available: "    .. tostring(available)
        )

        if available then
            local itemData = nil
            local itemCfg  = Config.Mailboxes.Item

            if itemCfg.Require then
                local playerItems = Inventory:getPlayerItemsCount(source)
                for _, itemName in pairs(itemCfg.Names) do
                    if playerItems and playerItems[itemName] and playerItems[itemName] > 0 then
                        itemData = itemName
                        break
                    end
                end
            else
                itemData = true
            end

            if not itemData then
                return { status = true, message = Translate("MAILBOX_MISSING_LOCKPICK") }
            end

            return { status = false, message = "Not broken", itemData = itemData }
        else
            -- ⚠️ In debug mode the original sets cooldown to -1 (permanent) instead of nil.
            -- This differs from cashregisters.lua which sets it to nil. Preserved as-is.
            if Config.Debug then
                mailboxCooldowns[coordKey] = -1
                Trace("Mailbox is resetted")
            end
            -- ⚠️ The Trace below fires unconditionally (not just in debug), matching the original.
            Trace("Mailbox is resetted")

            return { status = true, message = Translate("MAILBOX_ALREADY_BROKEN") }
        end
    end,
})

-- ─── Give Mailbox Loot ────────────────────────────────────────────────────────

RegisterServerCallback({
    eventName     = eventName .. "server:giveMailboxLoot",
    eventCallback = function(source, data)
        local itemName = data.itemName
        local itemData = data.itemData  -- the consumed tool item (e.g. lockpick name)

        if not Framework:fetchPlayer(source) then
            return { success = false, message = "NO_CHARACTER" }
        end

        if Main:isJobBlacklisted(source, "MAILBOX_ROBBERY") then
            return { status = false, success = false, message = "BLACKLISTED" }
        end

        -- Letter item: give directly without consuming a tool
        if itemName == "letter" then
            local added = Inventory:addPlayerItem(source, "bletter", 1)
            if not added then
                return { success = false, message = "FAILED_TO_GIVE_LETTER" }
            end
            return { success = true, message = Translate("MAILBOX_FOUND_LETTER") }
        end

        -- All other items require consuming the used tool first
        if not itemData then
            return { success = false, message = "NO_USED_ITEM" }
        end

        local removed = Inventory:removePlayerItem(source, itemData, 1)
        if not removed then
            Trace("Failed to remove letter")
            return { success = false, message = "FAILED_TO_REMOVE_LETTER" }
        end

        -- Search loot table
        local logLabel  = ""
        local result    = nil

        for _, lootEntry in pairs(Config.Mailboxes.LootTables) do
            if lootEntry.name ~= itemName then goto continue end

            local count = 1
            if lootEntry.count then
                count = math.random(lootEntry.count[1], lootEntry.count[2])
            end

            if itemName == "money" then
                Framework:addMoney(source, count)
                logLabel = "Money x" .. count
                result   = { success = true, message = Translate("GIVE_MONEY", { count }) }
                sendWebhook(source, "OPENED_LETTER", logLabel)
                return result
            else
                local added = Inventory:addPlayerItem(source, itemName, count)
                logLabel = itemName .. " x" .. count
                if not added then
                    return { success = false, message = "ITEM_FAILED_TO_GIVE" }
                end
                result = {
                    success = true,
                    message = Translate("ITEM_FOUND", { count, lootEntry.label }),
                }
            end

            ::continue::
        end

        -- ⚠️ Original sends webhook with (source, "OPENED_LETTER", source, logLabel) — the extra
        -- `source` arg looks like a copy-paste bug (third arg should probably be the label only).
        -- Preserved exactly: sendWebhook(source, "OPENED_LETTER", source, logLabel)
        sendWebhook(source, "OPENED_LETTER", source, logLabel)
        return result
    end,
})