Inventory = {}

function Inventory.normalizeInventoryMode(value)
	local normalized =
		tostring(value or "auto"):gsub("^%s+", ""):gsub("%s+$", ""):lower()
	normalized = normalized:gsub("%s+", "")

	if normalized == "" or normalized == "auto" then
		return "auto"
	end

	if normalized == "ox_inventory" or normalized == "ox-inventory" then
		return "ox_inventory"
	end
	if normalized == "qb-inventory" or normalized == "qbinventory" or normalized == "qb_inventory" then
		return "qb-inventory"
	end
	if normalized == "esx_inventory" or normalized == "esx-inventory" or normalized == "esxinventory" then
		return "esx_inventory"
	end
	if normalized == "qs-inventory" or normalized == "qsinventory" or normalized == "qs_inventory" then
		return "qs-inventory"
	end
	if normalized == "core-inventory" or normalized == "core_inventory" or normalized == "coreinventory" then
		return "core-inventory"
	end

	return normalized
end

function Inventory.getSelectedInventory(context)
	local selected =
		context and context.runtime and context.runtime.inventory or Config.Runtime.Inventory
	selected = Inventory.normalizeInventoryMode(selected)

	if selected ~= "auto" then
		return selected
	end

	if GetResourceState("ox_inventory") == "started" then
		return "ox_inventory"
	end
	if GetResourceState("qb-inventory") == "started" or GetResourceState(
		"qb-core"
	) == "started" then
		return "qb-inventory"
	end
	if GetResourceState("es_extended") == "started" then
		return "esx_inventory"
	end
	if GetResourceState("qs-inventory") == "started" then
		return "qs-inventory"
	end
	if GetResourceState("core_inventory") == "started" then
		return "core-inventory"
	end

	return "auto"
end

function Inventory.getSelectedShopSystem(context)
	local override =
		context and context.runtime and context.runtime.shop or Config.Runtime.Shop
	override = tostring(override or "")
	if override ~= "" and override ~= "auto" then
		return override
	end

	local inventory = Inventory.getSelectedInventory(context)
	if inventory == "ox_inventory" then
		return "ox_inventory"
	end

	if GetResourceState("qb-shops") == "started" then
		return "qb-shops"
	end

	if inventory == "qb-inventory" then
		return "qb-shops"
	end

	return "custom"
end

function Inventory.getSelectedTarget(context)
	local selected =
		context and context.runtime and context.runtime.target or Config.Runtime.Target
	selected = tostring(selected or "auto")

	if selected ~= "auto" then
		return selected
	end

	if GetResourceState("ox_target") == "started" then
		return "ox_target"
	end
	if GetResourceState("qb-target") == "started" then
		return "qb-target"
	end

	return "auto"
end

function Inventory.addItem(context, itemName, count)
	local inventoryMode = Inventory.getSelectedInventory(context)

	if inventoryMode == "ox_inventory" and GetResourceState(
		"ox_inventory"
	) == "started" then
		return exports.ox_inventory:AddItem(context.playerId, itemName, count)
	end

	if inventoryMode == "qb-inventory" then
		local qbxPlayer = DTreeFw.getQBXPlayer(context.playerId)
		if qbxPlayer and qbxPlayer.Functions and qbxPlayer.Functions.AddItem then
			return qbxPlayer.Functions.AddItem(itemName, count)
		end

		local qbPlayer = DTreeFw.getQBPlayer(context.playerId)
		if qbPlayer and qbPlayer.Functions and qbPlayer.Functions.AddItem then
			return qbPlayer.Functions.AddItem(itemName, count)
		end
	end

	if inventoryMode == "esx_inventory" then
		local esxPlayer = DTreeFw.getESXPlayer(context.playerId)
		if esxPlayer and esxPlayer.addInventoryItem then
			esxPlayer.addInventoryItem(itemName, count)
			return true
		end
	end

	if inventoryMode == "qs-inventory" and GetResourceState(
		"qs-inventory"
	) == "started" then
		return exports["qs-inventory"]:AddItem(
			context.playerId,
			itemName,
			count
		)
	end

	if inventoryMode == "core-inventory" and GetResourceState(
		"core_inventory"
	) == "started" then
		return exports["core_inventory"]:addItem(
			context.playerId,
			itemName,
			count
		)
	end

	return false
end

function Inventory.removeItem(context, itemName, count)
	local inventoryMode = Inventory.getSelectedInventory(context)

	if inventoryMode == "ox_inventory" and GetResourceState(
		"ox_inventory"
	) == "started" then
		return exports.ox_inventory:RemoveItem(
			context.playerId,
			itemName,
			count
		)
	end

	if inventoryMode == "qb-inventory" then
		local qbxPlayer = DTreeFw.getQBXPlayer(context.playerId)
		if qbxPlayer and qbxPlayer.Functions and qbxPlayer.Functions.RemoveItem then
			return qbxPlayer.Functions.RemoveItem(itemName, count)
		end

		local qbPlayer = DTreeFw.getQBPlayer(context.playerId)
		if qbPlayer and qbPlayer.Functions and qbPlayer.Functions.RemoveItem then
			return qbPlayer.Functions.RemoveItem(itemName, count)
		end
	end

	if inventoryMode == "esx_inventory" then
		local esxPlayer = DTreeFw.getESXPlayer(context.playerId)
		if esxPlayer and esxPlayer.removeInventoryItem then
			esxPlayer.removeInventoryItem(itemName, count)
			return true
		end
	end

	if inventoryMode == "qs-inventory" and GetResourceState(
		"qs-inventory"
	) == "started" then
		return exports["qs-inventory"]:RemoveItem(
			context.playerId,
			itemName,
			count
		)
	end

	if inventoryMode == "core-inventory" and GetResourceState(
		"core_inventory"
	) == "started" then
		return exports["core_inventory"]:removeItem(
			context.playerId,
			itemName,
			count
		)
	end

	return false
end

function Inventory.getItemCount(context, itemName)
	local inventoryMode = Inventory.getSelectedInventory(context)

	if inventoryMode == "ox_inventory" and GetResourceState(
		"ox_inventory"
	) == "started" then
		return exports.ox_inventory:Search(
			context.playerId,
			"count",
			itemName
		) or 0
	end

	if inventoryMode == "qb-inventory" then
		local qbxPlayer = DTreeFw.getQBXPlayer(context.playerId)
		if qbxPlayer and qbxPlayer.Functions and qbxPlayer.Functions.GetItemByName then
			local item = qbxPlayer.Functions.GetItemByName(itemName)
			return item and item.amount or 0
		end

		local qbPlayer = DTreeFw.getQBPlayer(context.playerId)
		if qbPlayer and qbPlayer.Functions and qbPlayer.Functions.GetItemByName then
			local item = qbPlayer.Functions.GetItemByName(itemName)
			return item and item.amount or 0
		end
	end

	if inventoryMode == "esx_inventory" then
		local esxPlayer = DTreeFw.getESXPlayer(context.playerId)
		if esxPlayer and esxPlayer.getInventoryItem then
			local item = esxPlayer.getInventoryItem(itemName)
			return item and item.count or 0
		end
	end

	if inventoryMode == "qs-inventory" and GetResourceState(
		"qs-inventory"
	) == "started" then
		local ok, count = pcall(function()
			return exports["qs-inventory"]:GetItemTotalAmount(
				context.playerId,
				itemName
			)
		end)
		if ok then
			return count or 0
		end
	end

	if inventoryMode == "core-inventory" and GetResourceState(
		"core_inventory"
	) == "started" then
		local ok, count = pcall(function()
			return exports["core_inventory"]:getItemCount(
				context.playerId,
				itemName
			)
		end)
		if ok then
			return count or 0
		end
	end

	return nil
end

function Inventory.parseShopItems(params)
	local decoded = DTreeUtil.decodeJsonValue(params and params.itemsJson)
	if type(decoded) == "table" then
		local normalized = {}
		local defaultAmount =
			tonumber(params and params.defaultAmount or 50) or 50

		for index, entry in ipairs(decoded) do
			if type(entry) == "table" then
				local itemName = tostring(entry.name or entry.item or "")
				if itemName ~= "" then
					normalized[#normalized + 1] = {
						name = itemName,
						amount = tonumber(
							entry.amount or defaultAmount
						) or defaultAmount,
						price = tonumber(entry.price or entry.cost or 0) or 0,
						slot = tonumber(entry.slot or index) or index,
					}
				end
			end
		end

		return normalized
	end

	local items = {}
	local itemNames = DTreeUtil.splitCsv(params and params.items)
	local defaultPrice = tonumber(params and params.defaultPrice or 0) or 0
	local defaultAmount = tonumber(params and params.defaultAmount or 50) or 50

	for _, itemName in ipairs(itemNames) do
		items[#items + 1] = {
			name = itemName,
			amount = defaultAmount,
			price = defaultPrice,
			slot = #items + 1,
		}
	end

	return items
end

DTreeInv = Inventory
