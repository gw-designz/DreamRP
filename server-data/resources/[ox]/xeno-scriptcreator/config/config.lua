Config = {}

Config.Debug = false -- Enables debug prints in the server console (Useful for development)
Config.EditorEnabled = true -- Enables access to the UI script editor (Tree Editor)
Config.EditorAce = "dtree.editor" -- The ace permission required to open the UI editor
Config.AllowJsonFallback = false -- Allows loading older JSON graphs if compiled lua is missing
Config.RuntimeUsePublishedOnly = true -- If true, scripts will only execute their published (Compiled) version
Config.MaxNodeStepsPerExecution = 256 -- Maximum steps a tree can execute to prevent infinite loops (DO NOT TOUCH)
Config.DefaultExecutionTimeoutMs = 60000 -- Maximum execution time in ms before a tree timeouts (DO NOT TOUCH)
Config.EnableCustomCodeAction = true -- Allows the use of custom lua code nodes in the editor

Config.AI = {
	Enabled = true,
	Provider = "anthropic",
	Endpoint = "https://api.anthropic.com/v1/messages",
	Model = "claude-3-5-sonnet-20240620",
	ApiKeyConvar = "dtree_ai_api_key",
	SystemPrompt = "You are a Lua coding assistant for FiveM decision trees. Return only executable Lua code, no markdown fences, no prose.",
}

Config.WebhookAllowedDomains = { -- Allowed domains for webhook requests
	"discord.com",
	"discordapp.com"
}

Config.Runtime = {
	Framework = "auto", -- Core Framework (ESX / QBCore / qbx_core / auto)
	Inventory = "auto", -- Inventory System (ox_inventory / qb-inventory / auto)
	Shop = "auto", -- Shop System
	Target = "ox_target", -- Target System (ox_target / qb-target / auto)
	Notify = "ox_lib", -- Notification System (ox_lib / qb-core / auto)
}

-- Client Events triggered by the system (Change only if using custom systems)
Config.NotifyClientEvent = "dtree:notify" -- (DO NOT TOUCH unless necessary)
Config.OpenDoorClientEvent = "dtree:openDoor" -- (DO NOT TOUCH unless necessary)
Config.SpawnVehicleClientEvent = "dtree:spawnVehicle" -- (DO NOT TOUCH unless necessary)
Config.SpawnPedClientEvent = "dtree:spawnPed" -- (DO NOT TOUCH unless necessary)
Config.SpawnTargetPedClientEvent = "dtree:spawnTargetPed" -- (DO NOT TOUCH unless necessary)
Config.CreateTargetZoneClientEvent = "dtree:createTargetZone" -- (DO NOT TOUCH unless necessary)
Config.RemoveTargetEntityClientEvent = "dtree:removeTargetEntity" -- (DO NOT TOUCH unless necessary)
Config.TriggerClientEventAction = "dtree:action:clientEvent" -- (DO NOT TOUCH unless necessary)
Config.OpenShopClientEvent = "dtree:openShop" -- (DO NOT TOUCH unless necessary)

Config.WorkSystems = {
	DefaultCooldownMs = 0, -- Default cooldown time (ms) between work tasks
	DefaultPayIntervalMs = 3600000, -- Default interval for salary payouts in ms (1 hour)
	MaxHourlySalary = 50000, -- Maximum allowed hourly salary limit
	ResetStepsOnResume = true, -- Resets tree progression steps when player resumes work
}

Config.Skills = {
	Command = "skills", -- Command used to open the skills menu
	Keybind = "k", -- Keybind to open the skills menu
	TreeId = "default_skill_tree", -- ID of the skill tree graph to load (DO NOT TOUCH)
	XPPerSkillPoint = 1000, -- Amount of XP required to earn 1 Skill Point
}

Config.AllowedSkillActions = { -- Allowed actions for skill trees (Security)
	events = {}, -- Allowed server events
	clientEvents = {}, -- Allowed client events
	exports = {}, -- Allowed exports
}

Config.Progression = {
	Enabled = true, -- Enables the XP / Level progression system
	Formula = function(level) -- Formula to calculate required XP for the next level
		return (level * 250) + 100
	end,
	MaxLevel = 100, -- Maximum level a player can reach
}

--- DONT TOUCH THIS ---
local _original_print = print
print = function(...)
	if Config.Debug then
		_original_print(...)
	end
end
