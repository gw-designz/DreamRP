---@type CaseData[]
local ALL_CASES <const> = {
    -- FISHING_CASE = {
    --     items = { -- Chances needs to add up to 100%
    --         {
    --             name = "ironbar",
    --             chance = 20,
    --         },
    --         {
    --             name = "sport_fishing_rod",
    --             chance = 10,
    --         },
    --         {
    --             name = "professional_fishing_rod",
    --             chance = 10,
    --         },
    --         {
    --             name = "farm_water_can",
    --             chance = 20,
    --         },
    --         {
    --             name = "aluminium_bar",
    --             chance = 10,
    --         },
    --         {
    --             name = "chess_table",
    --             chance = 20,
    --         },
    --         {
    --             name = "weapon_scanner",
    --             chance = 10,
    --         }
    --     }
    -- },
    RACING_CASE = {
        items = { -- Chances now add up to 100%
            {
                name = "racing_tablet",
                chance = 6,
            },
            {
                name = "boosting_vinscratch_b",
                chance = 1,
            },
            {
                name = "boosting_vinscratch_a",
                chance = 1,
            },
            {
                name = "boosting_hack_a",
                chance = 1,
            },
            {
                name = "boosting_hack_s",
                chance = 1,
            },
            {
                name = "boosting_hack_b",
                chance = 4,
            },
            {
                name = "boosting_contract_b",
                chance = 6,
            },
            {
                name = "boosting_contract_a",
                chance = 3,
            },
            {
                name = "fake_id",
                chance = 3,
            },
            {
                name = "lockpick",
                chance = 13,
            },
            {
                name = "money",
                chance = 44,
                min = 500,
                max = 1500
            },
            {
                name = "repairkit",
                chance = 5,
            },
            {
                name = "pdm_blowtorch",
                chance = 12,
            },
        }
    },
    -- BOOSTING_CASE = {
    --     items = {                         -- Chances needs to add up to 100%
    --         {
    --             name = "boosting_hack_b", -- Blue Pendrive
    --             chance = 2,
    --         },
    --         {
    --             name = "boosting_hack_a", -- Green Pendrive
    --             chance = 1,
    --         },
    --         {
    --             name = "boosting_hack_s", -- Purple Pendrive
    --             chance = 1,
    --         },
    --         {
    --             name = "crypto_usb_script", -- Script USB Key
    --             chance = 10,
    --         },
    --         {
    --             name = "crypto_usb_trj", -- Crypto USB Key
    --             chance = 10,
    --         },
    --         {
    --             name = "boosting_contract_d",
    --             chance = 5,
    --         },
    --         {
    --             name = "boosting_contract_c",
    --             chance = 5,
    --         },
    --         {
    --             name = "moneyroll",
    --             chance = 10,
    --             min = 10,
    --             max = 30,
    --         },
    --         {
    --             name = "pdm_blowtorch",
    --             chance = 5,
    --         },
    --         {
    --             name = "improved_lockpick",
    --             chance = 12,
    --         },
    --         {
    --             name = "expert_lockpick",
    --             chance = 10,
    --         },
    --         {
    --             name = "pdm_gps_hack",
    --             chance = 5,
    --         },
    --         {
    --             name = "pliers",
    --             chance = 8,
    --             max = 2,
    --         },
    --         {
    --             name = "racing_crappy",
    --             chance = 5,
    --         },
    --         {
    --             name = "moneyband",
    --             chance = 1,
    --             max = 4,
    --         },
    --         {
    --             name = "repairkitexp",
    --             chance = 10,
    --             max = 2,
    --         },
    --     }
    -- },
    -- BOOSTING_CASE_C = {
    --     items = { -- Chances needs to add up to 100%
    --         {
    --             name = "boosting_hack_b",
    --             chance = 10,
    --         },
    --         {
    --             name = "pdm_gps_hack",
    --             chance = 5,
    --         },
    --         {
    --             name = "boosting_hack_a",
    --             chance = 5,
    --         },
    --         {
    --             name = "crypto_usb_script",
    --             chance = 10,
    --         },
    --         {
    --             name = "crypto_usb_trj",
    --             chance = 10,
    --         },
    --         {
    --             name = "crypto_usb_5race",
    --             chance = 3,
    --             max = 3,
    --         },
    --         {
    --             name = "boosting_hack_a",
    --             chance = 1,
    --         },
    --         {
    --             name = "boosting_hack_s",
    --             chance = 1,
    --         },
    --         {
    --             name = "moneyroll",
    --             chance = 15,
    --             min = 15,
    --             max = 35,
    --         },
    --         {
    --             name = "empty_fake_id",
    --             chance = 15,
    --         },
    --         {
    --             name = "pdm_blowtorch",
    --             chance = 5,
    --         },
    --         {
    --             name = "expert_lockpick",
    --             chance = 5,
    --         },
    --         {
    --             name = "boosting_contract_c",
    --             chance = 5,
    --         },
    --         {
    --             name = "boosting_contract_b",
    --             chance = 5,
    --         },
    --         {
    --             name = "boosting_contract_a",
    --             chance = 2,
    --         },
    --         {
    --             name = "boosting_vinscratch_c",
    --             chance = 1,
    --         },
    --         {
    --             name = "boosting_vinscratch_b",
    --             chance = 1,
    --         },
    --         {
    --             name = "boosting_vinscratch_a",
    --             chance = 1,
    --         }
    --     }
    -- },
    -- BOOSTING_CASE_B = {
    --     items = { -- Chances needs to add up to 100%
    --         {
    --             name = "boosting_hack_b",
    --             chance = 8,
    --         },
    --         {
    --             name = "boosting_hack_s",
    --             chance = 2,
    --         },
    --         {
    --             name = "pdm_gps_hack",
    --             chance = 5,
    --         },
    --         {
    --             name = "boosting_hack_a",
    --             chance = 5,
    --         },
    --         {
    --             name = "crypto_usb_script",
    --             chance = 10,
    --         },
    --         {
    --             name = "crypto_usb_trj",
    --             chance = 10,
    --         },
    --         {
    --             name = "crypto_usb_5race",
    --             chance = 5,
    --             max = 3,
    --         },
    --         {
    --             name = "boosting_obd_b",
    --             chance = 4,
    --         },
    --         {
    --             name = "boosting_obd_a",
    --             chance = 3,
    --         },
    --         {
    --             name = "moneyroll",
    --             chance = 25,
    --             min = 25,
    --             max = 45,
    --         },
    --         {
    --             name = "empty_fake_id",
    --             chance = 5,
    --         },
    --         {
    --             name = "veh_racing_hardnesses",
    --             chance = 1,
    --         },
    --         {
    --             name = "expert_lockpick",
    --             chance = 5,
    --         },
    --         {
    --             name = "boosting_contract_b",
    --             chance = 5,
    --         },
    --         {
    --             name = "boosting_contract_a",
    --             chance = 1,
    --         },
    --         {
    --             name = "boosting_obd_s",
    --             chance = 1,
    --         },
    --         {
    --             name = "boosting_vinscratch_a",
    --             chance = 1,
    --         }
    --     }
    -- },
    -- BOOSTING_CASE_A = {
    --     items = { -- Chances needs to add up to 100%
    --         {
    --             name = "boosting_hack_a",
    --             chance = 10,
    --         },
    --         {
    --             name = "pdm_gps_hack",
    --             chance = 5,
    --         },
    --         {
    --             name = "crypto_usb_script",
    --             chance = 10,
    --         },
    --         {
    --             name = "boosting_hack_s",
    --             chance = 5,
    --         },
    --         {
    --             name = "crypto_usb_trj",
    --             chance = 5,
    --         },
    --         {
    --             name = "boosting_obd_s",
    --             chance = 5,
    --             max = 2,
    --         },
    --         {
    --             name = "boosting_obd_a",
    --             chance = 3,
    --         },
    --         {
    --             name = "moneyroll",
    --             chance = 25,
    --             min = 35,
    --             max = 75,
    --         },
    --         {
    --             name = "moneyband",
    --             chance = 15,
    --             min = 3,
    --             max = 8,
    --         },
    --         {
    --             name = "veh_racing_hardnesses",
    --             chance = 1,
    --         },
    --         {
    --             name = "expert_lockpick",
    --             chance = 5,
    --         },
    --         {
    --             name = "repairkitexp",
    --             chance = 4,
    --             max = 2,
    --         },
    --         {
    --             name = "boosting_contract_a",
    --             chance = 5,
    --         },
    --         {
    --             name = "boosting_vinscratch_b",
    --             chance = 1,
    --         },
    --         {
    --             name = "boosting_vinscratch_a",
    --             chance = 1,
    --         }
    --     }
    -- },
    -- BOOSTING_CASE_S = {
    --     items = { -- Chances needs to add up to 100%
    --         {
    --             name = "boosting_hack_a",
    --             chance = 10,
    --         },
    --         {
    --             name = "pdm_gps_hack",
    --             chance = 5,
    --         },
    --         {
    --             name = "crypto_usb_script",
    --             chance = 10,
    --         },
    --         {
    --             name = "boosting_hack_s",
    --             chance = 5,
    --         },
    --         {
    --             name = "crypto_usb_trj",
    --             chance = 5,
    --         },
    --         {
    --             name = "crypto_usb_5race",
    --             chance = 5,
    --             max = 5,
    --         },
    --         {
    --             name = "boosting_obd_a",
    --             chance = 3,
    --         },
    --         {
    --             name = "moneyroll",
    --             chance = 25,
    --             min = 35,
    --             max = 75,
    --         },
    --         {
    --             name = "moneyband",
    --             chance = 15,
    --             min = 3,
    --             max = 8,
    --         },
    --         {
    --             name = "veh_racing_hardnesses",
    --             chance = 1,
    --         },
    --         {
    --             name = "expert_lockpick",
    --             chance = 5,
    --         },
    --         {
    --             name = "repairkitexp",
    --             chance = 4,
    --             max = 2,
    --         },
    --         {
    --             name = "boosting_contract_a",
    --             chance = 5,
    --         },
    --         {
    --             name = "boosting_vinscratch_b",
    --             chance = 1,
    --         },
    --         {
    --             name = "boosting_vinscratch_a",
    --             chance = 1,
    --         }
    --     }
    -- }
}

local cachedWinnings = {} ---@type CaseWinning[]
local caseDrops = {}

---@param caseData CaseData
---@return boolean
---@return string?
local function assertCaseData(caseData)
    if not caseData then
        return false, "Case data is missing."
    end

    if not caseData.items then
        return false, "Case data is missing items."
    end

    local totalChance = 0

    for _, item in ipairs(caseData.items) do
        if not item.name then
            return false, "Item is missing a name."
        end

        if not item.chance then
            return false, "Item is missing a chance."
        end

        totalChance = totalChance + item.chance
    end

    if math.floor(totalChance) ~= 100 then
        lib.print.error("Total chance of items: " .. tostring(totalChance), caseData.items)
        return false, "Total chance of items does not add up to 100."
    end

    return true
end

---@param caseId string
---@param caseData CaseData
---@return boolean
local function createCase(caseId, caseData)
    local success, errorMsg = assertCaseData(caseData)

    if not success then
        error("Failed to create case: " .. errorMsg)
    end

    ALL_CASES[caseId] = caseData

    return true
end

---@param pool table
---@return table | nil
local function getRandomWeightedItem(pool)
    local poolsize = 0
    for _, item in pairs(pool) do
        poolsize = poolsize + item.chance
    end

    local selection = math.random(1, poolsize)
    for _, item in pairs(pool) do
        selection = selection - item.chance
        if (selection <= 0) then
            return item
        end
    end

    return nil
end

---@param itemSet table
---@return table | boolean
local function customWeightedSetWithCount(itemSet)
    local randomItem = getRandomWeightedItem(itemSet)

    if not randomItem or not randomItem.name or not randomItem.max then
        return false
    end
    
    return {
        name = randomItem.name,
        count = math.random(randomItem.min or 1, randomItem.max)
    }
end

---@param caseId string
---@return table | boolean
---@return number | string
local function generateWinningItemAndCount(caseId)
    local case = ALL_CASES[caseId]

    if not case then
        return false, "Case not found."
    end

    local set = {}
    local totalChance = 0

    for _, item in ipairs(case.items) do
        table.insert(set, {
            chance = item.chance,
            name = item.name,
            min = item.min or 1,
            max = item.max or 1
        })
        totalChance = totalChance + item.chance
    end

    if totalChance < 100.0 and totalChance > 100.0 then
        return false, locale("TOTAL_CHANCE_OF_ITEMS_DOES_NOT_ADD_UP_TO_100_ERROR")
    end

    local randomItem = customWeightedSetWithCount(set)
    if not randomItem then
        return false, locale("NO_WINNING_ITEM_WAS_FOUND_ERROR")
    end

    for itemIndex, item in ipairs(case.items) do
        if item.name == randomItem.name then
            randomItem.metadata = item.metadata

            return randomItem, itemIndex
        end
    end

    return false, locale("WINNING_ITEM_NOT_FOUND_IN_CASE_ERROR")
end

exports("CreateCase", createCase)
exports("GetCase", function(caseId)
    return ALL_CASES[caseId]
end)

exports("GetAllCases", function()
    return ALL_CASES
end)

lib.callback.register("prp-bridge:case:getCaseInfo", function(pSource, caseId)
    local case = ALL_CASES[caseId]
    if not case then
        return false, locale("CASE_NOT_FOUND_ERROR")
    end

    local uiCase = {
        caseId = caseId,
        type = "default",
        itemChances = {},
        availableItems = {}
    }

    for _, item in ipairs(case.items) do
        local itemData = bridge.inv.getItemData(item.name)
        if not itemData then
            lib.print.error("Item not found: " .. item.name)

            uiCase.availableItems[#uiCase.availableItems+1] = {
                name = "water",
                label = "not found:" .. item.name,
                count = 1,
                slot = -1,
            }

            uiCase.itemChances[#uiCase.itemChances+1] = item.chance / 100.0

            goto skip
        end
        
        uiCase.availableItems[#uiCase.availableItems+1] = {
            name = item.name,
            label = itemData.label,
            count = 1,
            slot = -1,
            imageUrl = bridge.inv.getItemImageUrl(item.image or item.name)
        }

        uiCase.itemChances[#uiCase.itemChances+1] = item.chance / 100.0

        :: skip ::
    end

    return uiCase
end)

lib.callback.register("prp-bridge:case:canOpenCase", function(pSource, caseId)
    local characterId = bridge.fw.getIdentifier(pSource)
    if not characterId then
        return false, locale("PLAYER_CHARACTER_NOT_FOUND")
    end

    local caseData = ALL_CASES[caseId]
    if not caseData then
        return false, locale("CASE_NOT_FOUND_ERROR")
    end

    local allCases = bridge.inv.searchInventory(pSource, "case")
    if not allCases or #allCases == 0 then
        return false, locale("PLAYER_HAS_NO_CASES")
    end

    local hasCase = nil ---@type InvSearchItem
    for _, case in pairs(allCases) do
        if case.metadata.caseId and case.metadata.caseId == caseId then
            hasCase = case
            break
        end
    end

    if not hasCase then
        return false, locale("PLAYER_DOESNT_HAVE_CASE")
    end

    local removedCase = bridge.inv.removeItem(pSource, hasCase.name, 1, hasCase.metadata, hasCase.slot)
    if not removedCase then
        return false, locale("FAILED_TO_REMOVE_CASE_FROM_INVENTORY_ERROR")
    end

    local winningItem, winningItemIndex = generateWinningItemAndCount(caseId)
    if not winningItem then
        return false, winningItemIndex
    end

    if caseDrops[characterId] then
        local caseDrop = caseDrops[characterId][caseId]

        if caseDrop then
            winningItem = {
                name = caseDrop.itemName,
                count = caseDrop.itemCount or 1,
                metaData = {}
            }

            for index, caseItem in ipairs(caseData.items) do
                if caseItem.name == winningItem.name then
                    winningItemIndex = index
                    break
                end
            end

            caseDrops[characterId][caseId] = nil
        end
    end

    cachedWinnings[pSource] = {
        caseId = caseId,
        winningItem = winningItem --[[ @as table ]],
        winningItemIndex = winningItemIndex --[[@as number ]]
    }

    return true, winningItemIndex - 1, winningItem.count
end)

lib.callback.register("prp-bridge:case:caseOpened", function(pSource)
    local cachedWinningsData = cachedWinnings[pSource]

    if not cachedWinningsData then
        return false, locale("NO_CACHED_WINNINGS_FOUND_ERROR")
    end

    local case = ALL_CASES[cachedWinningsData.caseId]

    if not case then
        return false, locale("CASE_NOT_FOUND_ERROR")
    end

    local winningItem = cachedWinningsData.winningItem

    if not winningItem then
        return false, locale("NO_WINNING_ITEM_WAS_FOUND_ERROR")
    end

    local addedItem, errorMsg = bridge.inv.giveItem(pSource, winningItem.name, winningItem.count, winningItem.metadata)
    cachedWinnings[pSource] = nil
    return addedItem, errorMsg
end)

CreateThread(function()
    for _, caseData in pairs(ALL_CASES) do
        assertCaseData(caseData)
    end

    bridge.fw.registerItemUse("case", function(pSource, itemData)
        local caseId = itemData.metaData.caseId

        if not caseId then
            return
        end

        TriggerClientEvent("prp-bridge:client:openCase", pSource, caseId)
    end)
end)