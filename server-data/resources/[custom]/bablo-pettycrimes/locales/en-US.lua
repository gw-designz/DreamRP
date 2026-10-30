
if not Locales then
    Locales = {}
end

Locales['en-US'] = {
    -- Smash n grab

    ["NO_LOOT_FOUND"] = "No loot found.",
    ["WINDOW_SMASHED_ALREADY"] = "Windows already smashed.",
    ["TOO_FAR_FROM_VEHICLE"] = "You are too far away get closer to vehicle",
    ["SEARCHING_FOR_LOOT"] = "Looting...",
    ["SMASH_WINDOW"] = "Smash window",
    ["SMASHNGRAB_DISPATCH"] = "A smash and grab has been reported",
    ["SMASHNGRAB_DISPATCH_BLIP"] = "Smash and grab",
    ["SMASHNGRAB_GOT_BAG"] = "You found a bag with something inside.",
    ["SMASHNGRAB_BAG_OPENED"] = "You opened the bag and found something.",
    -- mailbox robbery

    ["MAILBOX_BROKEN"] = "Mailbox is already broken.",
    ["MAILBOX_ROBBERY_SUCCESS"] = "You successfully broke the mailbox.",
    ["MAILBOX_ROBBERY_FAIL"] = "You failed to break the mailbox.",
    ["MAILBOX_FOUND_LETTER"] = "You found a letter.",
    ["MAILBOX_MISSING_LOCKPICK"] = "You need a lockpick to break the mailbox.",
    ["MAILBOX_ALREADY_BROKEN"] = "Mailbox is already broken.",
    ["MAILBOX_LABEL"] = "Break mailbox",
    ["MAILBOX_DISPATCH"] = "A mailbox robbery has been reported",
    ["MAILBOX_DISPATCH_BLIP"] = "Mailbox robbery",
    ["MAILBOX_STUCK"] = "You got your arm stuck in the mailbox!",
    ["MAILBOX_STILL_STUCK"] = "You're still stuck... try again!",
    ["MAILBOX_UNSTUCK"] = "You finally got yourself free.",

    -- parking meter robbery

    ["PARKING_METER_BROKEN"] = "Parking meter is already broken.",
    ["PARKING_METER_ROBBERY_SUCCESS"] = "You successfully broke the parking meter.",
    ["PARKING_METER_ROBBERY_FAIL"] = "You failed to break the parking meter.",
    ["PARKING_METER_MISSING_LOCKPICK"] = "You need a lockpick to break the parking meter.",
    ["PARKING_METER_ALREADY_BROKEN"] = "Parking meter is already broken.",
    ["PARKING_METER_LABEL"] = "Break parking meter",
    ["PARKING_METER_DISPATCH"] = "A parking meter robbery has been reported",
    ["PARKING_METER_DISPATCH_BLIP"] = "Parking meter robbery",

    -- parcels theft
    ["NO_PACKAGE_TOO_STEAL"] = "There is no package to steal.",
    ["DISARMING_BOMB"] = "Disarming bomb...",
    ["BOMB_DISARMED"] = "You disarmed the bomb",
    ["STEAL_PARCEL_LABEL"] = "Steal parcel",
    ["PARCEL_DISPATCH"] = "Someone is stealing my parcel",
    ["PARCEL_DISPATCH_BLIP"] = "Parcel theft",
    ["PARCEL_BOMB_DISPATCH"] = "An explosion has been reported — possible parcel bomb",
    ["PARCEL_BOMB_DISPATCH_BLIP"] = "Parcel Bomb Explosion",


    -- pickpocketing
    ["PICKPOCKET_FAIL"] = "You failed to pickpocket the target",
    ["PICKPOCKET_PROGRESS"] = "Pickpocketing...",
    ["PICKPOCKET_LABEL"] = "Pickpocket",
    ["PICKPOCKET_DISPATCH"] = "A pickpocketing has been reported",
    ["PICKPOCKET_DISPATCH_BLIP"] = "Pickpocketing",
    ["PICKPOCKET_MINIGAME_HINT"] = "Stop the arrow in the zone",
    ["PICKPOCKET_MINIGAME_HIT"] = "Zone hit — keep going",
    ["PICKPOCKET_MINIGAME_MISS"] = "Missed",
    ["PICKPOCKET_MINIGAME_SUCCESS"] = "Pockets emptied",
    ["PICKPOCKET_MINIGAME_CANCEL"] = "Cancelled",
    ["PICKPOCKET_TOO_FAR"] = "The target moved too far away",
    ["PICKPOCKET_MINIGAME_STOP_HINT"]    = "Stop the arrow on the item you want",
    ["PICKPOCKET_MINIGAME_NOTICED"]      = "The victim noticed you",
    ["PICKPOCKET_MINIGAME_GOT"]          = "Got %s",
    ["PICKPOCKET_MINIGAME_KEY_STOP"]     = "SPACE",
    ["PICKPOCKET_MINIGAME_KEY_CANCEL"]   = "ESC",
    ["PICKPOCKET_MINIGAME_STOP_LABEL"]   = "Stop",
    ["PICKPOCKET_MINIGAME_CANCEL_LABEL"] = "Cancel",

    --mugging
    ["MUGGING_DISPATCH_TITLE"] = "Mugging in progress",
    ["MUGGING_DISPATCH_DESC"] = "A mugging has been reported",
    ["MUGGING_DISPATCH_BLIP"] = "Mugging",
    ["MUGGING_IN_PROGRESS"] = "Robbing...",
    ["MUGGING_SCARED_HINT"] = "Use ~INPUT_PUSH_TO_TALK~ to scare the victim",
    ["MUGGING_SCARED_BAR"] = "Fear",
    ["MUGGING_RETALIATION"] = "You’re not getting anything from me.",

    -- match pairs minigame
    ["MATCHPAIRS_WIN"]       = "You found all the pairs!",
    ["MATCHPAIRS_FAIL"]      = "Time's up! Better luck next time.",
    ["MATCHPAIRS_CANCELLED"] = "Minigame cancelled.",
    ["MATCHPAIRS_MEMORIZE"]  = "Memorize",
    ["MATCHPAIRS_COMPLETE"]  = "Complete",
    ["MATCHPAIRS_TIMES_UP"]  = "Time's Up",
    ["MATCHPAIRS_FIND_PAIRS"]= "Find Pairs",

    -- vending machine robbery
    ["VENDING_LABEL"]            = "Break into vending machine",
    ["VENDING_ROBBERY_SUCCESS"]  = "You broke into the vending machine.",
    ["VENDING_ROBBERY_FAIL"]     = "You failed to break in.",
    ["VENDING_MISSING_ITEM"]     = "You need a tool to break in.",
    ["VENDING_ALREADY_BROKEN"]   = "This vending machine was already broken into.",
    ["VENDING_DISPATCH"]         = "A vending machine break-in has been reported",
    ["VENDING_DISPATCH_BLIP"]    = "Vending machine robbery",

    -- tire slashing
    ["TIRE_SLASH_LABEL"]          = "Slash Tire",
    ["TIRE_SLASH_NO_WEAPON"]      = "You need something sharp to do this",
    ["TIRE_SLASH_ALREADY_FLAT"]   = "This tire is already flat",
    ["TIRE_SLASH_CANT_SLASH"]     = "You can't slash this vehicle's tires",
    ["TIRE_SLASH_MAX_REACHED"]    = "You've slashed enough tires on this vehicle",
    ["TIRE_SLASH_VICTIM_ALERT"]   = "Someone slashed your tire!",
    ["TIRE_SLASH_DISPATCH"]       = "Vehicle vandalism reported — tires being slashed",
    ["TIRE_SLASH_DISPATCH_BLIP"]  = "Tire Slashing",

    -- pedal brick
    ["PEDAL_BRICK_LABEL"]          = "Place Brick on Pedal",
    ["PEDAL_BRICK_READY"]          = "Brick ready — approach a vehicle to place it",
    ["PEDAL_BRICK_EXPIRED"]        = "You took too long, the brick is no longer ready",
    ["PEDAL_BRICK_PLACING"]        = "Placing brick on gas pedal...",
    ["PEDAL_BRICK_PLACED"]         = "Brick placed — the vehicle is about to take off",
    ["PEDAL_BRICK_NO_ITEM"]        = "You don't have a brick",
    ["PEDAL_BRICK_CANT_USE"]       = "You can't use a brick on this vehicle",
    ["PEDAL_BRICK_LOCKED"]         = "The vehicle is locked",
    ["PEDAL_BRICK_ALREADY"]        = "There's already a brick on this pedal",
    ["PEDAL_BRICK_OCCUPIED"]       = "Someone is in the driver seat",
    ["PEDAL_BRICK_DISPATCH"]       = "Vehicle tampering reported — brick on gas pedal",
    ["PEDAL_BRICK_DISPATCH_BLIP"]  = "Vehicle Tampering",
    ["PEDAL_BRICK_FIRE_DISPATCH"]      = "A vehicle is on fire after a collision — suspected tampering",
    ["PEDAL_BRICK_FIRE_DISPATCH_BLIP"] = "Vehicle Fire",

    -- ATM robbery
    ["ATM_ROBBERY_ATTACH_LABEL"]     = "Attach Hacking Device",
    ["ATM_ROBBERY_REMOVE_LABEL"]     = "Remove Hacking Device",
    ["ATM_ROBBERY_DRAIN_LABEL"]      = "Drain ATM Cash",
    ["ATM_ROBBERY_NO_ITEM"]          = "You need a hacking device",
    ["ATM_ROBBERY_COOLDOWN"]         = "This ATM was recently robbed",
    ["ATM_ROBBERY_ALREADY_HACKED"]   = "There is already a device on this ATM",
    ["ATM_ROBBERY_ATTACHING"]        = "Attaching hacking device...",
    ["ATM_ROBBERY_DEVICE_ATTACHED"]  = "Device attached to the ATM",
    ["ATM_ROBBERY_DEVICE_REMOVED"]   = "Device removed from the ATM",
    ["ATM_ROBBERY_HACK_LABEL"]       = "[E] Hack Transaction",
    ["ATM_ROBBERY_WAITING_PED"]      = "Waiting for someone to use the ATM...",
    ["ATM_ROBBERY_SUCCESS"]          = "ATM hacked successfully",
    ["ATM_ROBBERY_FAIL"]             = "Hack failed",
    ["ATM_ROBBERY_DRAINING"]         = "Draining cash from the ATM...",
    ["ATM_ROBBERY_DRAINED"]          = "ATM drained — $%s collected",
    ["ATM_ROBBERY_POOL_ADDED"]       = "Skimmed $%s from transaction (Pool: $%s)",
    ["ATM_ROBBERY_POOL_EMPTY"]       = "Nothing to drain yet — hack some transactions first",
    ["ATM_ROBBERY_COLLECT_LABEL"]    = "[E] Pick Up Cash",
    ["ATM_ROBBERY_COLLECTING"]       = "Collecting money...",
    ["ATM_ROBBERY_MAX_PEDS"]         = "ATM is tapped out — drain or remove the device",
    ["ATM_ROBBERY_TOO_FAR"]          = "Too far from the ATM to hack",
    ["ATM_ROBBERY_ITEM_BROKE"]       = "Your hacking device broke",
    ["ATM_ROBBERY_PED_ANGRY"]        = "The person got angry and left",
    ["ATM_ROBBERY_DISPATCH"]         = "An ATM robbery has been reported",
    ["ATM_ROBBERY_DISPATCH_BLIP"]    = "ATM Robbery",

    -- cash register robbery
    ["CASH_REGISTER_LABEL"]            = "Lockpick Register",
    ["CASH_REGISTER_BROKEN"]           = "This register is already broken.",
    ["CASH_REGISTER_SUCCESS"]          = "You cracked the register open.",
    ["CASH_REGISTER_FAIL"]             = "You failed to pick the lock.",
    ["CASH_REGISTER_MISSING_LOCKPICK"] = "You need a lockpick for this.",
    ["CASH_REGISTER_ALREADY_BROKEN"]   = "This cash register was already robbed.",
    ["CASH_REGISTER_DISPATCH"]         = "A cash register robbery has been reported",
    ["CASH_REGISTER_DISPATCH_BLIP"]    = "Cash Register Robbery",

    -- store shelves
    ["STORE_SHELVES_LABEL"]            = "Search Shelves",
    ["STORE_SHELVES_SUCCESS"]          = "You found some items.",
    ["STORE_SHELVES_EMPTY"]            = "These shelves are empty.",
    ["STORE_SHELVES_DISPATCH"]         = "Store Shoplifting",
    ["STORE_SHELVES_DISPATCH_BLIP"]    = "Shoplifting",

    --global
    ["NOT_ENOUGH_POLICE"] = "Not enough police online",
    ["GIVE_MONEY"] = "You got %s$",
    ["NOTHING_FOUND"] = "Nothing found",
    ["ITEM_FOUND"] = "You found %sx %s",
    ["LOCKPICK_BROKE"] = "Your lockpick broke",
    ["LOCKPICK_MINIGAME_CLICK"]  = "CLICK",
    ["LOCKPICK_MINIGAME_KEY"]    = "E",
    ["LOCKPICK_MINIGAME_TO_OPEN"]= "TO OPEN LOCK",
    ["LOCKPICK_MINIGAME_FAILED"] = "LOCKPICK FAILED",
    ["LOCKPICK_MINIGAME_OPENED"] = "LOCK OPENED",
    ["BLEEDING"] = "You hurt yourself",
    ["CANT_DO_ACTION"] = "You can't do this action right now",
}
