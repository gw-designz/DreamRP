Config = Config or {}


--[[
╔══════════════════════════════════════════════════════════════════╗
║                     SIM CONFIGURATION                            ║
╠══════════════════════════════════════════════════════════════════╣
║  For detailed documentation and setup instructions, visit:       ║
║  https://docs.teamsgg.dev/paid-scripts/phone/configure/sim-cards ║
╚══════════════════════════════════════════════════════════════════╝
--]]


Config.Sim = {}
-------------------------------------
--- IMPORTANT: READ FULLY -----------
----------- IMPORTANT: READ FULLY ---
-------------------------------------
-------------------------------------
-------------------------------------
--- To use the SIM Cards functionality you need to have one of the supported inventories(with metadata) installed. Do not contact us to add support for unsupported inventories.
--- Also you need to have the SIM card item in your inventory. You can find the item in the file that is provided when you download the script or in our documentation.
--- DOCS: https://docs.teamsgg.dev/
-------------------------------------
-------------------------------------
-------------------------------------
--- IMPORTANT: READ FULLY -----------
----------- IMPORTANT: READ FULLY ---
-------------------------------------

-- You can use the command `/createSimCard` to create a SIM card item. Learn more about it in the documentation. - https://docs.teamsgg.dev/paid-scripts/phone/configure/sim-cards

-- Whether to enable the SIM switch functionality.
-- *manual: When a phone is initialized the phone won't have a SIM card. You need to have a SIM card item in your inventory. You can assign the SIM card to the phone via the Settings app -> SIM Manager.
-- *auto_generate: When a phone is initialized, it will automatically generate a SIM card and add it to the phone.
Config.Sim.Mode = 'auto_generate' -- options: 'manual', 'auto_generate'

-- Whether to enable the SIM switch functionality from the Settings app(Settings -> SIM Manager).
Config.Sim.EnableSimSwitch = true

-- The name of the SIM card item.
Config.Sim.ItemName = "ys_sim_card"

-- This config will generate number in the format of -- 088 XXXX (default)
-- Refer to `server/custom/functions/misc.lua` if you want to customize the phone number generation.
Config.Sim.NumberPrefix = { "088", "087", "089" } -- Prefix for phone numbers (default - 088)
Config.Sim.NumberLength = 4                       -- Length of phone numbers (excluding prefix, default - 4)

Config.Calls = {}

-- The time in ms that a player has to await for a call to be answered
-- Multiplied by Config.PhoneCalls.CallRepeats - 2000 x 10 = 20 seconds(default)
Config.Calls.RepeatTimeout = 2000
Config.Calls.CallRepeats = 10
Config.Calls.AllowAnonymous = true -- Allow anonymous calls to be made to players.

Config.DefaultContacts = {
    {
        name = "Police",
        number = "911",
        favorite = false
    },
}
