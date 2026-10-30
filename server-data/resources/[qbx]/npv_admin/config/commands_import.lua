-- Extra commands, ported from codera-adminmenu and re-implemented with this resource's server-side
-- permission, rank and argument checks (see server/commands_import.lua and client/commands.lua).
-- Loaded after config/commands.lua; edit or delete entries freely.

-- Group existing commands into the new Vehicles / Teleport categories.
local recategorise = {
    spawn_vehicle = 'vehicles', clean_vehicle = 'vehicles', fix_vehicle = 'vehicles', delete_vehicle = 'vehicles',
    bring = 'teleport', ['return'] = 'teleport', ['goto'] = 'teleport', tp_waypoint = 'teleport', tp_coords = 'teleport',
}
for _, cmd in ipairs(Config.Commands) do
    if recategorise[cmd.id] then cmd.category = recategorise[cmd.id] end
end

local locationLabels = {}
for _, l in ipairs(Config.Locations) do locationLabels[#locationLabels + 1] = l.label end

local amount = { name = 'amount', type = 'number', label = 'Amount', min = 1, max = Config.MaxMoneyPerCommand, default = 1000 }
local account = { name = 'type', type = 'select', label = 'Account', options = Config.MoneyTypes, default = Config.MoneyTypes[1] }
local target = { name = 'target', type = 'player' }

local extra = {
    -- Economy ------------------------------------------------------------------------------------
    { id = 'give_money', label = 'Give Money', desc = 'Give money to a player', category = 'economy', perm = 'economy', exec = 'server',
      args = { target, amount, account } },
    { id = 'remove_money', label = 'Remove Money', desc = 'Take money from a player', category = 'economy', perm = 'economy', exec = 'server', confirm = true,
      args = { target, amount, account } },
    { id = 'give_money_all', label = 'Give Money To All', desc = 'Give money to every player on the server', category = 'economy', perm = 'economy', exec = 'server', confirm = true,
      args = { amount, account } },
    { id = 'give_item', label = 'Give Item', desc = 'Give an item to a player', category = 'economy', perm = 'items', exec = 'server',
      args = { target, { name = 'item', type = 'name', label = 'Item name', max = 60 }, { name = 'amount', type = 'number', label = 'Amount', min = 1, max = 1000, default = 1 } } },
    { id = 'give_item_all', label = 'Give Item To All', desc = 'Give an item to every player on the server', category = 'economy', perm = 'items', exec = 'server', confirm = true,
      args = { { name = 'item', type = 'name', label = 'Item name', max = 60 }, { name = 'amount', type = 'number', label = 'Amount', min = 1, max = 1000, default = 1 } } },
    { id = 'set_job', label = 'Set Job', desc = 'Set the job of a player', category = 'economy', perm = 'jobs', exec = 'server',
      args = { target, { name = 'job', type = 'name', label = 'Job name', max = 50 }, { name = 'grade', type = 'number', label = 'Grade', min = 0, max = 50, default = 0 } } },
    { id = 'set_gang', label = 'Set Gang', desc = 'Set the gang of a player', category = 'economy', perm = 'jobs', exec = 'server',
      args = { target, { name = 'gang', type = 'name', label = 'Gang name', max = 50 }, { name = 'grade', type = 'number', label = 'Grade', min = 0, max = 50, default = 0 } } },
    { id = 'toggle_duty', label = 'Toggle Duty', desc = 'Toggle your own job duty', category = 'economy', perm = 'jobs', exec = 'server' },
    { id = 'open_inventory', label = 'Open Inventory', desc = "Open a player's inventory", category = 'economy', perm = 'items', exec = 'server',
      args = { target } },
    { id = 'clear_inventory', label = 'Clear Inventory', desc = "Clear a player's inventory", category = 'economy', perm = 'items', exec = 'server', confirm = true,
      args = { target } },
    { id = 'open_stash', label = 'Open Stash', desc = 'Open a stash by its ID', category = 'economy', perm = 'items', exec = 'server',
      args = { { name = 'stash', type = 'name', label = 'Stash ID', max = 50, default = '1' } } },
    { id = 'open_trunk', label = 'Open Trunk', desc = 'Open the trunk inventory of a plate', category = 'economy', perm = 'items', exec = 'server',
      args = { { name = 'plate', type = 'text', label = 'Plate', max = 8 } } },

    -- Players ------------------------------------------------------------------------------------
    { id = 'revive_all', label = 'Revive All', desc = 'Revive every player on the server', category = 'players', perm = 'players.heal', exec = 'server', confirm = true },
    { id = 'make_drunk', label = 'Make Player Drunk', desc = 'Apply a temporary drunk effect to a player', category = 'players', perm = 'players.moderate', exec = 'server',
      args = { target } },
    { id = 'mute_player', label = 'Mute Player', desc = 'Toggle voice mute on a player (pma-voice)', category = 'players', perm = 'players.moderate', exec = 'server',
      args = { target } },
    { id = 'toggle_cuffs', label = 'Toggle Cuffs', desc = 'Cuff or uncuff a player', category = 'players', perm = 'players.moderate', exec = 'server',
      args = { target } },
    { id = 'clothing_menu', label = 'Give Clothing Menu', desc = 'Open the clothing menu for a player', category = 'players', perm = 'players.moderate', exec = 'server',
      args = { target } },
    { id = 'remove_stress', label = 'Remove Stress', desc = 'Remove stress from a player (empty = yourself)', category = 'players', perm = 'players.heal', exec = 'server',
      args = { { name = 'target', type = 'player', optional = true } } },
    { id = 'get_bucket', label = 'Get Routing Bucket', desc = 'Show the routing bucket of a player', category = 'players', perm = 'players.view', exec = 'server',
      args = { target } },

    -- Teleport -----------------------------------------------------------------------------------
    { id = 'teleport_location', label = 'Teleport To Location', desc = 'Teleport to a saved location', category = 'teleport', perm = 'players.teleport', exec = 'client',
      args = { { name = 'location', type = 'select', label = 'Location', options = locationLabels, default = locationLabels[1] } } },
    { id = 'teleport_back', label = 'Teleport Back', desc = 'Return to your previous position', category = 'teleport', perm = 'players.teleport', exec = 'client' },

    -- Vehicles -----------------------------------------------------------------------------------
    { id = 'fix_vehicle_for', label = 'Fix Vehicle For Player', desc = 'Repair the vehicle a player is in', category = 'vehicles', perm = 'vehicles', exec = 'server',
      args = { target } },
    { id = 'refuel_vehicle', label = 'Refuel Vehicle', desc = 'Fill the fuel tank of your vehicle', category = 'vehicles', perm = 'vehicles', exec = 'client' },
    { id = 'max_mods', label = 'Max Vehicle Mods', desc = 'Max out all mods of your vehicle', category = 'vehicles', perm = 'vehicles', exec = 'client' },
    { id = 'change_plate', label = 'Change Plate', desc = 'Change the plate of your vehicle', category = 'vehicles', perm = 'vehicles', exec = 'client',
      args = { { name = 'plate', type = 'text', label = 'Plate', max = 8 } } },
    { id = 'admin_car', label = 'Admin Car', desc = 'Add the vehicle you are in to your garage', category = 'vehicles', perm = 'vehicles', exec = 'client' },

    -- User / overlays ----------------------------------------------------------------------------
    { id = 'infinite_ammo', label = 'Infinite Ammo', desc = 'Toggle infinite ammo', category = 'user', perm = 'self', exec = 'client', toggle = true },
    { id = 'set_ammo', label = 'Set Ammo', desc = 'Set the ammo of the weapon in your hand', category = 'user', perm = 'self', exec = 'client',
      args = { { name = 'amount', type = 'number', label = 'Ammo', min = 0, max = 9999, default = 250 } } },
    { id = 'toggle_coords', label = 'Toggle Coords', desc = 'Show your coordinates on screen', category = 'utility', perm = 'self', exec = 'client', toggle = true },
    { id = 'toggle_names', label = 'Toggle Names', desc = 'Show player IDs and names above heads', category = 'utility', perm = 'players.view', exec = 'client', toggle = true },
    { id = 'toggle_blips', label = 'Toggle Blips', desc = 'Show all players on the map', category = 'utility', perm = 'players.view', exec = 'client', toggle = true },

    -- Server -------------------------------------------------------------------------------------
    { id = 'resource_control', label = 'Resource Control', desc = 'Start, stop or restart a resource', category = 'utility', perm = 'resources', exec = 'server', confirm = true,
      args = { { name = 'resource', type = 'name', label = 'Resource name', max = 60 }, { name = 'action', type = 'select', label = 'Action', options = { 'restart', 'start', 'stop', 'ensure' }, default = 'restart' } } },
}

for _, cmd in ipairs(extra) do Config.Commands[#Config.Commands + 1] = cmd end
