-- Module guard
if not Config.Modules.CASH_REGISTER_ROBBERY then
    return
end

-- Wait for eventName to be set by s_main.lua
while not eventName do
    Wait(0)
end

-- ─── Cooldown State ───────────────────────────────────────────────────────────
-- Maps coordKey → unix expiry timestamp, or -1 for permanent cooldown.

local registerCooldowns = {}

-- ─── Cooldown Cleanup Thread ──────────────────────────────────────────────────

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(60000)
        local now = os.time()
        for key, expiresAt in pairs(registerCooldowns) do
            if expiresAt ~= -1 and expiresAt < now then
                registerCooldowns[key] = nil
            end
        end
    end
end)

-- ─── Editor API (exposed globals for external tooling) ────────────────────────

function CashRegisterEditor_GetCooldowns()
    local now    = os.time()
    local result = {}
    for key, expiresAt in pairs(registerCooldowns) do
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

function CashRegisterEditor_ClearCooldown(key)
    registerCooldowns[key] = nil
end

function CashRegisterEditor_ClearAll()
    for key in pairs(registerCooldowns) do
        registerCooldowns[key] = nil
    end
end

-- ─── Helpers ──────────────────────────────────────────────────────────────────

local function rollItemBreak(source, itemData)
    local cfg = Config.CashRegisters.Item
    if not cfg.Require or not itemData then return end

    local roll = math.random(1, 100)
    if roll <= cfg.BreakChance then
        local removed = Inventory:removePlayerItem(source, itemData, 1)
        if not removed then
            Trace("Failed to remove item")
            return
        end
        Framework:Notify(source, Translate("LOCKPICK_BROKE"))
    end
end

-- ─── Set Broken (Register robbed) ─────────────────────────────────────────────

RegisterNetEvent(eventName .. "server:setBrokenCashRegister")
AddEventHandler(eventName .. "server:setBrokenCashRegister", function(data)
    if not Framework:fetchPlayer(source) then return end

    local expiresAt = os.time() + Config.CashRegisters.Cooldown
    registerCooldowns[data.coordKey] = expiresAt

    Trace(
        "Cash register broken at coordKey: " .. data.coordKey ..
        " until: "        .. expiresAt ..
        " current time: " .. os.time()
    )

    rollItemBreak(source, data.itemData)
end)

-- ─── Item Break During Use ────────────────────────────────────────────────────

RegisterNetEvent(eventName .. "server:cashRegisterItemBreak")
AddEventHandler(eventName .. "server:cashRegisterItemBreak", function(data)
    if not Framework:fetchPlayer(source) then return end
    rollItemBreak(source, data.itemData)
end)

-- ─── Is Register Broken? ──────────────────────────────────────────────────────

RegisterServerCallback({
    eventName     = eventName .. "server:isCashRegisterBroken",
    eventCallback = function(source, coordKey)
        if not Framework:fetchPlayer(source) then
            return { status = false, message = "NO_CHARACTER" }
        end

        local now       = os.time()
        local expiresAt = registerCooldowns[coordKey]
        local available = expiresAt == nil

        Trace(
            "Checking cash register coordKey: " .. coordKey ..
            " stored time: "  .. tostring(expiresAt) ..
            " current time: " .. now ..
            " available: "    .. tostring(available)
        )

        if available then
            -- Register is available — check if player has a required item
            local itemData = nil
            local itemCfg  = Config.CashRegisters.Item

            if itemCfg.Require then
                local itemNames  = itemCfg.Names
                local playerItems = Inventory:getPlayerItemsCount(source)
                for _, itemName in pairs(itemNames) do
                    if playerItems and playerItems[itemName] and playerItems[itemName] > 0 then
                        itemData = itemName
                        break
                    end
                end
            else
                itemData = true
            end

            if not itemData then
                return {
                    status  = true,
                    message = Translate("CASH_REGISTER_MISSING_LOCKPICK"),
                }
            end

            return { status = false, message = "Not broken", itemData = itemData }
        else
            -- Register is on cooldown
            if Config.Debug then
                registerCooldowns[coordKey] = nil
                Trace("Cash register cooldown reset (debug mode)")
            end

            return {
                status  = true,
                message = Translate("CASH_REGISTER_ALREADY_BROKEN"),
            }
        end
    end,
})

-- ─── Give Loot ────────────────────────────────────────────────────────────────

RegisterServerCallback({
    eventName     = eventName .. "server:giveCashRegisterLoot",
    eventCallback = function(source, data)
        local itemName = data.itemName

        if not Framework:fetchPlayer(source) then
            return { status = false, message = "NO_CHARACTER" }
        end

        if Main:isJobBlacklisted(source, "CASH_REGISTER_ROBBERY") then
            return { status = false, success = false, message = "BLACKLISTED" }
        end

        for _, lootEntry in pairs(Config.CashRegisters.LootTables) do
            if lootEntry.name ~= itemName then goto continue end

            local count = 1
            if lootEntry.count then
                count = math.random(lootEntry.count[1], lootEntry.count[2])
            end

            if itemName == "money" then
                Framework:addMoney(source, count)
                local logLabel = "Money x" .. count
                sendWebhook(source, "CASH_REGISTER_ROBBERY", logLabel)
                return {
                    status  = true,
                    message = Translate("GIVE_MONEY", { count }),
                }
            else
                local added = Inventory:addPlayerItem(source, itemName, count)
                local logLabel = itemName .. " x" .. count
                if not added then
                    return { status = false, message = "ITEM_FAILED_TO_GIVE" }
                end
                sendWebhook(source, "CASH_REGISTER_ROBBERY", logLabel)
                return {
                    status  = true,
                    message = Translate("ITEM_FOUND", { count, lootEntry.label or "Item" }),
                }
            end

            ::continue::
        end

        return { status = false, message = "INVALID_LOOT_ITEM" }
    end,
})