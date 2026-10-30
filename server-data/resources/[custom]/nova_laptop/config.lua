Config = {}

Config.Framework = 'auto' -- auto, qb, qbox, esx, standalone
Config.Inventory = 'auto' -- auto, ox, framework, none
Config.ItemName = 'laptop'
Config.Command = {
    Enabled = true,
    Name = 'laptop',
    RequireItem = false -- true: /laptop also requires the inventory item
}
Config.Keybind = '' -- e.g. 'F6'; empty means no default keybind
Config.ServerName = 'Los Santos'
Config.DeviceName = 'NOVA BOOK'
Config.AllowInVehicle = false
Config.BlockWhenDead = true
Config.OpenCooldownMs = 1000

--[[
    The laptop is set down before it is used: /laptop (or the item) brings
    up a laptop to place with the gizmo (object_gizmo), then Enter puts it
    down. Everyone sees it; only its owner can use it or pick it up, by
    standing at it (interact's E prompt, or E / G without interact).
]]
Config.Placement = {
    Prop = 'prop_laptop_01a',
    UseDistance = 1.8, -- how close you must stand to use it (/laptop near it opens it)
    MaxDistance = 5.0  -- how far from you it may be put down
}

--[[
    How the laptop is shown.
      'world'   the desktop is painted onto the laptop prop's own screen and the
                camera moves in to it; the mouse and keyboard work on it there.
                You set the laptop down first (Config.Placement).
      'screen'  no laptop to set down: the desktop fills the player's screen as an overlay.
]]
Config.Display = {
    Mode = 'world',
    -- The page's size in pixels. Keep 1280 x 800: the desktop is laid out for it.
    Resolution = { w = 1280, h = 800 },
    -- Where the desktop sits on each laptop model's glass, in the model's own
    -- coordinates with its front facing -Y: centre (x, y, z), size in metres,
    -- and how far the top leans back, in degrees. A model left out is fitted
    -- from its size. Staff line it up in game with /laptopscreen at a placed
    -- laptop (object_gizmo); that is saved to screens.json, sent to everyone
    -- and takes the place of these.
    Screens = {
        prop_laptop_01a = { x = -0.0013, y = 0.0654, z = 0.1375, width = 0.3362, height = 0.2012, tilt = 14.85 },
    },
    -- Who may line screens up: the framework's permission ACEs (Qbox: god, admin).
    EditGroups = { 'god', 'admin' },
    -- How close placed laptops are painted from.
    PaintDistance = 25.0,
    -- How much of the view's height the screen fills (lower shows more of the
    -- laptop and desk around it; try /laptopzoom in F8), and the camera's field of view.
    Fill = 0.72,
    Fov = 40.0
}

--[[
    Weazel News: the business the laptop's apps run.
    Staff are the players with the qbx job below; its boss grade (isboss) is
    the page's owner, who can do everything. Everyone else gets what their
    portal group allows.

    Photos upload to Fivemanage: its API key goes in server_config.lua,
    never here (this file is sent to every player).
]]
Config.News = {
    Job = 'reporter',
    -- The page's owners by citizen ID: every permission, shown in the Owner
    -- group on LifeInvader. They count as staff even without the job above;
    -- the job's boss grade (isboss) is an owner too.
    Owners = {
        'KLH82788',
    },
    PageName = 'News',             -- the business page's name on LifeInvader
    Account = 'reporter',          -- the Renewed-Banking account that pays staff
    PhoneResource = 'oph3z-phone', -- whose gallery the Phone gallery tab reads
    MemoryCard = 60,               -- photos each character's memory card holds
    MaxAttachments = 20,
    MaxPayment = 25000,
    Printing = {
        Item = 'magazine',         -- what a printed copy is (ox_inventory item)
        Paper = 'paper',           -- used up per copy; false prints for free
        MaxCopies = 10,
        SecondsPerCopy = 3,
        -- Staff can set a printer down anywhere (Newsstand, Print copies, Place
        -- printer), one each, with object_gizmo; copies print beside any of them.
        Prop = 'prop_printer_01',
        Command = 'printer',       -- /printer sets one down too; false turns the command off
        -- Fixed office printers as well, if any.
        Printers = {
            vec3(0.891, 6513.155, 31.878)
        },
        Range = 4.0
    },
    -- Ready-made columns editors can drop into an issue and edit in the
    -- magazine editor. Only used to fill an empty database the first time.
    Columns = {
        { title = 'Recent Jailings', body = 'Who the city put behind bars this week, and why.' },
        { title = 'Current Tax Rates', body = 'Sales tax, income tax and property tax, as set by City Hall.' },
        { title = 'Upcoming Elections', body = 'Who is running, for what, and when the polls open.' },
        { title = 'Recent Election Results', body = 'The winners, the losers and the turnout.' },
        { title = 'Weather Forecast', body = 'Sun over Vespucci, fog over Paleto. Bring a jacket.' },
        { title = 'Classifieds', body = 'For sale, wanted, and lost and found. Call the newsroom to place an ad.' }
    }
}

-- GTA's own frontend sounds for the laptop's and the printer menu's buttons:
-- { sound name, sound set } for the pointer moving onto one, a click, and
-- closing. Players can turn them off in the laptop (Settings, Interface Sounds).
Config.Sounds = {
    Enabled = true,
    Hover = { 'NAV_UP_DOWN', 'HUD_FRONTEND_DEFAULT_SOUNDSET' },
    Select = { 'SELECT', 'HUD_FRONTEND_DEFAULT_SOUNDSET' },
    Back = { 'BACK', 'HUD_FRONTEND_DEFAULT_SOUNDSET' }
}

Config.DefaultSettings = {
    theme = 'light', wallpaper = 'bloom', accent = 'red', sounds = true -- accent: red, blue, violet, mint
}

