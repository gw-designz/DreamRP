--[[
    fs-garages / config/config.lua

    Parking garages all over the city.

    Every garage has a kiosk and its parking spaces. Drive into a space and
    press E to park: the car is kept just as it was (paint, parts, damage
    and fuel). To drive it again, walk up to that garage's kiosk, press E
    and use its screen. A car is kept at the garage it was parked in; any
    other garage shows where it is and can bring it over for a fee.

    Garages are made in game by an admin (see Config.Command below); there
    are no coordinates to copy into this file.

    Restart the resource after changing anything here.
]]

Config = {}

--- Which framework the server runs. 'auto' finds it by itself; or name it:
--- 'esx', 'qbcore' or 'qbox'.
Config.Framework = 'auto'

--- If your framework's resource has been renamed, put its name here.
Config.FrameworkResources = {
    esx = 'es_extended',
    qbcore = 'qb-core',
    qbox = 'qbx_core',
}

--- The words on the kiosk and in the messages. Must match a file in locales/.
Config.Locale = 'en'

--- The key that uses a kiosk and parks a car (38 = E).
Config.Key = 38

--[[
    How players use a kiosk and park:
      'auto'       picks the first one your server has, in this order
      'fantasy'    the [E] prompts of Fantasy Scripts' ox_lib
      'target'     look at the kiosk with ox_target or qb-target, whichever
                   your server runs ('ox_target' or 'qb-target' to name one)
      '3dtext'     a floating [E] text, needs nothing else
    Parking is done from the driver's seat, and the target scripts do not
    work from a vehicle, so with 'target' parking is a floating [E] text.
]]
Config.Interaction = 'fantasy'

--[[
    The garages are made in game: type this command, and a window opens
    where you name a garage and place its kiosk and parking spaces by
    looking at the ground. Only admins can open it: anyone allowed the
    command in server.cfg (add_ace group.admin command.garagecreator allow),
    or an admin of your framework in one of these groups.
]]
Config.Command = 'garagecreator'
Config.AdminGroups = { 'admin', 'superadmin', 'god' }

--- How close you must be to a kiosk to use it, in metres.
Config.PromptDistance = 1.6

--- Extra lines in the server console. Leave off unless you are looking
--- into a problem.
Config.Debug = false

-- ════════════════════════════════════════════════════════════════════════
--  Parking
-- ════════════════════════════════════════════════════════════════════════

Config.Parking = {
    --- How far (metres) the middle of the car may be from the middle of a
    --- parking space to park in it.
    reach = 2.5,

    --- The car must be this slow (km/h) to park.
    maxSpeed = 3,

    --- A car brought over from another garage costs this much.
    transferFee = 250,

    --- Draw the outline of every free space while driving near a garage.
    showSpaces = true,
}

-- ════════════════════════════════════════════════════════════════════════
--  The impound
-- ════════════════════════════════════════════════════════════════════════

--[[
    A car left out in the city that is no longer there (it was blown up,
    sank, was cleared away, or the server restarted) shows as "Lost" at
    every garage, and is got back at an impound for a fee. Impounds are
    made in the creator like any garage (type: Impound), with spaces where
    the cars come out.
]]
Config.Impound = {
    --- What getting a lost or impounded car back costs. 0 is free.
    fee = 500,

    --- QBCore and Qbox: a car the police impounded with a price of its own
    --- costs that price instead.
    useImpoundPrice = true,

    --- Also let players get back a car that still stands somewhere in the
    --- city with nobody in it (stuck, or they forgot where they left it).
    --- It is removed from where it stands and comes out at the impound.
    takeFromCity = true,

    --- Paid from 'bank' or 'cash'.
    account = 'bank',
}

-- ════════════════════════════════════════════════════════════════════════
--  Map icons
-- ════════════════════════════════════════════════════════════════════════

--[[
    Every garage shows on the map with the name it was given in the
    creator. `sprite` and `colour` are GTA's own blip numbers:
    https://docs.fivem.net/docs/game-references/blips/
]]
Config.Blips = {
    enabled = true,
    car = { sprite = 357, colour = 3, scale = 0.7 },
    boat = { sprite = 356, colour = 3, scale = 0.7 },
    air = { sprite = 359, colour = 3, scale = 0.7 },
    depot = { sprite = 68, colour = 47, scale = 0.7 },
}

-- ════════════════════════════════════════════════════════════════════════
--  The kiosk screen
-- ════════════════════════════════════════════════════════════════════════

--[[
    Car pictures on the kiosk. By default each car's picture is fetched
    from FiveM's own vehicle pictures, by the car's model name. Put your
    own folder or website here to use your own pictures; {model} becomes
    the model name, e.g. 'nui://my-pictures/cars/{model}.png'.
]]
Config.CarPictures = 'https://docs.fivem.net/vehicles/{model}.webp'
