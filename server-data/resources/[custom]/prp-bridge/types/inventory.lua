---@meta

--- Source: https://coxdocs.dev/ox_inventory/Functions/Server/Hooks#swapitems

---@alias InvHookAction "move" | "stack" | "swap" | "give"
---@alias InvGiveItemResp "invalid_item" | "invalid_inventory" | "inventory_full"
---@alias InvRemoveItemResp "invalid_item" | "not_enough_items" | "invalid_inventory"

---@class InvHookOptions
---@field print boolean? Print to the console when triggering the event.
---@field itemFilter table<string, boolean>? The event will only trigger for items defined as keys in a set.
---@field inventoryFilter table<string>? The event will only trigger for inventories that match one of the patterns in the array.
---@field typeFilter table<string, boolean>? The event will only trigger for inventories with one of the provided types (e.g. 'player', 'stash')

---@class InvSwapHookPayload
---@field source number The source of the player swapping items.
---@field action InvHookAction
---@field fromInventory table | string | number
---@field toInventory table | string | number
---@field fromType string
---@field toType string
---@field fromSlot number | table | nil
---@field toSlot number | table | nil
---@field count number

---@class InvCreateItemHookPayload
---@field inventoryId string | number
---@field metadata table
---@field item table
---@field count number

--- https://coxdocs.dev/ox_inventory/Functions/Server

---@class InvTempStashProps
---@field label string
---@field slots number
---@field maxWeight number
---@field owner string | number | boolean | nil `string`: Can only access the stash linked to the owner. `true`: Each player has a unique stash but can request other player's stashes. The inventory is always shared if `false` or `nil`.
---@field groups table<string, number>? Table of group names (e.g. jobs) where the numeric value is the minimum grade required. `{['police'] = 0, ['ambulance'] = 2}`
---@field coords vector3?
---@field items table<{ name: string, count: number, metaData: table? }>?

---@class InvStashProps
---@field id string
---@field label string
---@field slots number
---@field maxWeight number
---@field owner string | number | boolean | nil `string`: Can only access the stash linked to the owner. `true`: Each player has a unique stash but can request other player's stashes. The inventory is always shared if `false` or `nil`.
---@field groups table<string, number>? Table of group names (e.g. jobs) where the numeric value is the minimum grade required. `{['police'] = 0, ['ambulance'] = 2}`
---@field coords vector3?
---@field items table<{ name: string, count: number, metaData: table? }>?

---@class InvShopData
---@field name string
---@field items table<{ name: string, price: number }>
---@field locations? table<vector3>
---@field groups table<string, number>?

---@class InvSearchItem
---@field name string
---@field slot number
---@field count number
---@field metadata table

---@alias InvVehStashType "glovebox" | "trunk"
