Config = {}

Config.Debug = false -- prints extra info to console

Config.Framework = 'qbox' -- esx, oldesx, qb, oldqb, qbox
-- Required. The phone stores everything in MySQL and creates its own oph3z_phone_* tables on first start.
Config.MySQL = 'oxmysql' -- oxmysql, ghmattimysql, mysql-async
Config.Inventory = 'ox_inventory' -- ox_inventory, qb-inventory, qs-inventory, codem-inventory

Config.Keybind   = 'F1' -- default key (player can rebind in GTA settings)
Config.WalkKey   = 'F7' -- while the phone is open, tap to toggle "walk mode" (move + use phone). LMENU = Left Alt
Config.ItemName  = 'phone'-- ox_inventory item that opens the phone
Config.RequireItem = false -- If true, the phone can ONLY be opened while the player owns Config.ItemName

Config.XVerifyCommand = 'xverify' -- admin command to grant an X verified badge: /xverify <@username> [gold|blue]

Config.PhoneNumberPrefix = '555' -- 555 + 4 digits -> displayed as "555-0142".
Config.DefaultLocale = 'en' -- en, tr
Config.MailDomain = 'mail.com'

-- Billing
-- A MySQL resource (Config.MySQL) is required.
Config.BillingScript = 'qbox' -- 'esx_billing' | 'qb' | 'codem-billing' | 'qbox'
Config.BillingTax = 0 -- informational tax % shown on a bill when the biller doesn't send one
-- 'qb' (phone_invoices) ONLY: how the billed society/job account gets paid.
-- ('qbox' reads phone_invoices too but pays the society via Renewed-Banking.)
Config.QBBanking = true -- true = qb-banking (new management), false = qb-management (legacy)
Config.QBCreateJobAccount = false -- qb-banking: auto-create the society account if it is missing

Config.Sharedrop = {
    Range = 8.0, -- metres: who counts as "nearby" when sharing
    MaxPhotos = 20, -- max photos/videos in a single ShareDrop
    RequirePhone = false, -- true = receiver must have their phone open to be discoverable
}

-- The Clock app's alarms + timers.
Config.Clock = {
    Range = 12.0, -- metres: how far the alarm / timer sound carries (nearby players)
    Volume = 0.5, -- xsound volume for the alarm / timer sound (0.0-1.0)
    RingSeconds = 30, -- auto-stop a ringing alarm / finished timer after this many seconds
}

-- Default phone settings written on first use for a citizen.
Config.DefaultSettings = {
    wallpaper = 'duoAurora', -- preset key (file name in web/src/assets/wallpapers: duoAurora, ember, graphite, blackTitanium, ...) or a custom URL
    brightness = 100, -- screen brightness (Control Center, 20-100)
    volume = 70, -- media volume (Control Center / Music app)
    sharedrop = false, -- ShareDrop receiving toggle (Control Center)
    airplane = false, -- airplane mode (unreachable + can't call)
    scale = 100, -- phone size on screen (75-100; Display & Brightness)
    notifSound = true, -- play a sound on new notifications
    notifMaster = true, -- master switch: off = silence ALL notifications
    language = 'en', -- selected UI language (see locales/, Settings > Language)
}

-- Look & controls of the NoPixel-style interface.
Config.UI = {
    HomeStyle   = 'duo',     -- 'duo' (iPhone Duo foldable: titanium frame, Dynamic Island, iOS home + iOS apps),
                             -- 'nopixel' (NoPixel app grid) or 'ios' (the original draggable home screen with folders)
    Finish      = 'natural', -- iPhone Duo frame colour: 'natural', 'black', 'white' or 'desert' titanium
    LockScreen  = false,     -- true = show the lock screen before the home screen on every open
    Foldable    = true,      -- allow folding / unfolding (narrow phone <-> wide tablet)
    StartFolded = true,      -- state on a player's first open; after that their last choice is remembered
    Legend      = true,      -- key prompts (T UNFOLD / Y HOME / SELECT / BACK / ESC CLOSE) beside the phone
    PhoneSetup  = true,      -- first open shows "Phone Setup": pick a bank (Fleeca green / Pacific blue / Paleto red) that themes the Bank app
    TimeSource  = 'real',    -- 'real' = player's local clock, 'game' = GTA world time
    Clock24h    = false,     -- false = 4:34 PM, true = 16:34
    ShowLocation = true,     -- zone name under the home clock (e.g. GREAT CHAPARRAL)
    -- GTA frontend sounds for every button and app (PlaySoundFrontend): { soundName, soundSet }.
    -- Set one to false to mute just that event. Players can switch them off under Settings › Sounds.
    Sounds = {
        Enabled = true,
        Hover = { 'NAV_UP_DOWN', 'HUD_FRONTEND_DEFAULT_SOUNDSET' }, -- pointer or arrow-key focus moves onto a button
        Click = { 'SELECT', 'HUD_FRONTEND_DEFAULT_SOUNDSET' },      -- mouse click on a button
        Enter = { 'Menu_Accept', 'Phone_SoundSet_Default' },        -- Enter on the focused item, or submitting a text field
        Back  = { 'BACK', 'HUD_FRONTEND_DEFAULT_SOUNDSET' },        -- Backspace and back buttons
        Open  = { 'Menu_Accept', 'Phone_SoundSet_Default' },        -- launching an app
        Home  = { 'Menu_Back', 'Phone_SoundSet_Default' },          -- Home key / home bar
    },
    -- Keys used while the phone has focus (letters only). Backspace / Enter / Esc / arrows are fixed.
    Keys = { Fold = 'T', Home = 'Y', TabLeft = 'Q', TabRight = 'E' },
}

-- Socials (NoPixel-style front end for the built-in Twexa backend)
Config.Socials = {
    AutoAccount = false, -- false = players pick a username on the "Join" screen; true = create one automatically
    MaxLength   = 280,  -- max characters per post / reply
    PostCooldown = 3,   -- seconds between posts per player (anti-spam)
    AnnounceNewPosts = true, -- tell open feeds "New posts" when someone posts (players tap to refresh)
}

-- Licenses app
Config.Licenses = {
    ApplyAt = 'City Hall',  -- shown on licences you don't have
    ShowDistance = 3.0,     -- metres: "Show" goes to the nearest player within this range
    -- always listed (qb/qbox: PlayerData.metadata.licences keys, ESX: user_licenses types)
    Known = {
        { id = 'driver',   label = 'Driver License' },
        { id = 'weapon',   label = 'Weapon License' },
        { id = 'hunting',  label = 'Hunting License' },
        { id = 'fishing',  label = 'Fishing License' },
        { id = 'pilot',    label = 'Pilot License' },
        { id = 'business', label = 'Business License' },
    },
}

-- Garage app
Config.Garage = {
    -- Client event fired for "Take Out" with (plate, garage). nil = button disabled
    -- (players retrieve vehicles at a garage as usual). Example: 'my-garages:client:takeOut'
    TakeOutEvent = nil,
    ShareKeys = true,     -- "Keys" gives the nearest player keys to the vehicle
    KeysDistance = 3.0,
    -- Runs on the server. Return false if it failed. vehicle = entity if the car is out, else nil.
    GiveKeys = function(src, target, plate, vehicle)
        if GetResourceState('qbx_vehiclekeys') == 'started' then
            if not vehicle then return false end -- qbx_vehiclekeys needs the car to be out
            exports.qbx_vehiclekeys:GiveKeys(target, vehicle)
            return true
        end
        if GetResourceState('qb-vehiclekeys') == 'started' then
            TriggerClientEvent('vehiclekeys:client:SetOwner', target, plate)
            return true
        end
        return false
    end,
}

-- Business app (player-created businesses)
Config.Business = {
    MaxOwned = 3,      -- businesses one character can own
    MaxMembers = 50,   -- members per business
    CreateCost = 0,    -- bank charge to register a business (0 = free)
}

-- Crypto app (LCN exchange). Prices drift every TickMinutes within [min, max].
Config.Crypto = {
    TickMinutes = 10,
    FeePercent = 1,      -- exchange fee on buys and withdrawals
    MinPurchase = 10,    -- dollars
    MaxPurchase = 250000,
    Coins = {
        -- icon: cookie, seedling, burger, gas, car, wifi
        { id = 'sbn',  label = 'SnackBits', symbol = 'SBN',  icon = 'cookie',   price = 123.46, min = 20,  max = 600,  volatility = 0.04 },
        { id = 'bean', label = 'BeanToken', symbol = 'BEAN', icon = 'seedling', price = 257.68, min = 40,  max = 900,  volatility = 0.035 },
        { id = 'grl',  label = 'GrillCoin', symbol = 'GRL',  icon = 'burger',   price = 334.09, min = 60,  max = 1200, volatility = 0.03 },
        { id = 'octn', label = 'Octane',    symbol = 'OCTN', icon = 'gas',      price = 500,    min = 100, max = 2000, volatility = 0.05 },
        { id = 'driv', label = 'DrivCoin',  symbol = 'DRIV', icon = 'car',      price = 449.33, min = 80,  max = 1600, volatility = 0.04 },
        { id = 'wzn',  label = 'WizNet',    symbol = 'WZN',  icon = 'wifi',     price = 99.33,  min = 10,  max = 400,  volatility = 0.06 },
    },
}

-- Calendar app
Config.Calendar = {
    MaxEvents = 200,    -- per character
    AllowShared = true, -- players may share an event with everyone
}

-- Government app. Editors publish notices / open ballots: list of job names or { job = minGrade }.
Config.Government = {
    Editors = { 'government', 'mayor', 'judge', 'doj' },
    AdminsCanEdit = true,
    Regions = {
        { id = 'ls',     label = 'Los Santos' },
        { id = 'blaine', label = 'Blaine County' },
    },
}

-- Weazel News app
Config.News = {
    Jobs = { 'weazel', 'reporter', 'news' }, -- who can publish
    EditorJobs = nil,          -- who can delete anyone's article (nil = same as Jobs)
    AnyoneCanPublish = false,
    AdminsCanPublish = true,
    Categories = {
        { id = 'crime',    label = 'Crime' },
        { id = 'city',     label = 'City' },
        { id = 'business', label = 'Business' },
        { id = 'sports',   label = 'Sports' },
        { id = 'weather',  label = 'Weather' },
    },
}

-- Events app
Config.Events = {
    HostJobs = { 'government', 'mayor' }, -- these jobs (and admins) schedule events directly
    AnyoneCanPropose = true,  -- everyone else proposes; the city votes
    VotesToSchedule = 5,
    MaxOpenPerPlayer = 3,
    MaxParticipants = 0,      -- 0 = unlimited
    MaxDaysAhead = 7,
    KeepEndedMinutes = 120,   -- how long finished events stay on the list
}

-- Property + Real Estate apps. Ownership is tracked by the phone; use the hooks to hand the real
-- interior / keys to your housing resource. coords = where the GPS waypoint points.
Config.Property = {
    MaxOwned = 3,
    MaxKeyholders = 5,
    SellBackPercent = 60, -- 0 = selling back disabled
    -- OnPurchase = function(src, citizenid, listing) end,
    -- OnSell = function(src, citizenid, listing) end,
    -- OnKeyChange = function(src, ownerCitizenid, listing, targetCitizenid, given) end,
    Listings = {
        -- type: residential | apartment | storage | commercial ; listing: open | auction
        { id = 'lamesa_storage', label = 'La Mesa Storage', description = 'A deep freeze storage.', type = 'storage', zone = 'La Mesa', street = 'Popular St, La Mesa', coords = vector3(818.6, -1029.8, 26.3), price = 45000, garage = 0, size = 60 },
        { id = 'forum_11', label = '11 Forum Dr', description = 'A cozy family home.', type = 'residential', zone = 'Chamberlain Hills', street = '11 Forum Dr, Chamberlain Hills', coords = vector3(-151.4, -1622.0, 33.6), price = 296000, garage = 2, size = 110 },
        { id = 'grove_4', label = '4 Grove St', description = 'A classic on Grove Street.', type = 'residential', zone = 'Davis', street = '4 Grove St, Davis', coords = vector3(-50.4, -1783.6, 28.3), price = 342000, garage = 2, size = 138 },
        { id = 'eclipse_31', label = 'Eclipse Towers Apt 31', description = 'A luxurious apartment.', type = 'apartment', zone = 'Rockford Hills', street = 'Eclipse Towers Apt 31, Rockford Hills', coords = vector3(-773.9, 312.0, 85.7), price = 8056000, garage = 8, size = 480, listing = 'auction' },
    },
}

-- Guber app (ride hailing between players)
Config.Guber = {
    DriverJobs = nil,        -- nil / {} = anyone can drive; or e.g. { 'taxi' }
    BaseFare = 25,
    PerMile = 35,
    MinFare = 25,
    CommissionPercent = 0,   -- % of each fare kept by the city
    RequestTimeout = 30,     -- seconds a request waits for a driver
    PickupDistance = 12.0,   -- metres driver <-> customer to confirm pickup
    CompleteDistance = 80.0, -- metres from the drop-off to complete the ride
    AllowWaypoint = true,    -- customers can ride to their own GPS waypoint
    Destinations = {
        { label = 'Mission Row Police Department', coords = vector3(441.0, -982.0, 30.7) },
        { label = 'Pillbox Hill Medical Center', coords = vector3(298.0, -584.0, 43.3) },
        { label = 'Legion Square', coords = vector3(195.0, -934.0, 30.7) },
        { label = 'Los Santos International Airport', coords = vector3(-1037.0, -2737.0, 20.2) },
        { label = 'Vespucci Beach', coords = vector3(-1388.0, -1489.0, 4.4) },
        { label = 'Sandy Shores', coords = vector3(1853.0, 3686.0, 34.3) },
    },
}

-- Roach (dark-web browser). Sites are plain text; [[address]] or [[address|label]] become links.
Config.Roach = {
    RequiredItem = nil,  -- e.g. 'laptop' or 'vpn' to require an item
    HomePage = 'roach.onion',
    -- "View Page Source" on unknown addresses shows a decoy page full of fake leads to other dead
    -- addresses (same decoy every time for the same address). Change DecoySeed to reshuffle them.
    DecoySource = true,
    DecoySeed = 'roach',
    -- Players publish their own pages from the browser (⋮ › Host a Site). The first page on a name
    -- (e.g. kitchen.onion) claims it; only the owner can add sub-pages (kitchen.onion/menu).
    -- Admins (group.admin, the 'command' ace or AdminAce) can publish anywhere, including the
    -- HomePage address, and edit or delete any hosted page. Addresses in Sites below can't be claimed.
    Hosting = {
        Enabled = true,
        PlayersCanHost = true,   -- false = only admins can publish
        MaxSitesPerPlayer = 3,   -- addresses per character (sub-pages don't count), 0 = unlimited
        MaxPagesPerSite = 10,    -- pages per address, 0 = unlimited
        Cost = 0,                -- bank charge to claim a new address (0 = free)
        MaxBodyLength = 4000,
        AdminAce = 'oph3z-phone.roach', -- extra ace that can manage every hosted page
    },
    Sites = {
        -- body: plain text, [[address]] or [[address|label]] become links.
        -- hints: strings added as HTML comments to the page source (for puzzles).
        -- source: full custom page source (overrides the generated one).
        -- ['market.onion'] = {
        --     title = 'Market', body = 'Nothing for sale today.\n\nBack to [[roach.onion|home]].',
        --     hints = { 'the vendor moved to qlahcd.onion' }, item = nil, jobs = nil,
        -- },
        -- Sub-pages use a path: ['market.onion/about'] = { ... }. Any address not listed here shows a
        -- 404 with its own decoy source. Players type "name" or "name.onion" in the address bar.
        -- Other resources can add pages at runtime: exports['oph3z-phone']:RegisterRoachSite('name.onion', { title, body, hints, source })

        -- examples (delete or replace them)
        ['board.onion'] = {
            title = 'the board',
            body = 'anonymous notes. nothing here is signed.\n\n> meet where the pier lights die. bring nothing.\n> whoever keeps leaving flowers at the observatory: we see you.\n> the old address is gone. ask around.\n\n[[board.onion/rules|rules]] · [[mirror.onion|mirror]]',
            hints = { 'mods read this page at night' },
        },
        ['board.onion/rules'] = {
            title = 'rules',
            body = '1. no names.\n2. no faces.\n3. if you know, you know.\n\n[[board.onion|back to the board]]',
        },
        ['mirror.onion'] = {
            title = 'mirror',
            body = 'this is a mirror of a mirror.\n\nthe original is gone. so is the copy before this one.\n\n[[board.onion|board]]',
        },
    },
}

-- Scoot-E (scooter rental)
Config.ScootE = {
    Model = 'faggio',    -- vehicle spawned for the rental
    Price = 50,
    Minutes = 30,
    WarpIn = true,       -- put the player on the scooter
    KeysEvent = 'vehiclekeys:client:SetOwner', -- client event given the plate (nil to skip)
}

-- Lemon List (classified ads; uses the built-in marketplace tables)
Config.LemonList = {
    MaxAdsPerPlayer = 5, -- 0 = unlimited
    Categories = {
        { id = 'mechanic',   label = 'Mechanic' },
        { id = 'services',   label = 'Services' },
        { id = 'food',       label = 'Food' },
        { id = 'taxi',       label = 'Taxi' },
        { id = 'government', label = 'Government' },
        { id = 'realty',     label = 'Real Estate' },
        { id = 'selling',    label = 'Selling' },
        { id = 'buying',     label = 'Buying' },
        { id = 'jobs',       label = 'Jobs' },
    },
}

-- Apps
-- place = 'grid' (home screen, in this order) | 'dock' (bottom bar, in this order) | 'hidden'
-- store = true  -> only on the home screen once installed from the Store
-- enabled = false -> remove an app entirely
-- clientEvent / command -> hand the tap off to another resource instead of an in-phone screen:
--     { id = 'guber', label = 'Guber', place = 'grid', clientEvent = 'my-taxi:client:openUI' },
--     { id = 'crypto', label = 'Crypto', place = 'grid', command = 'crypto' },
--   (the phone closes first unless keepOpen = true). A third-party app registered with
--   exports['oph3z-phone']:RegisterApp({ id = 'crypto', ... }) also replaces the built-in screen.
Config.Apps = {
    -- home grid (4 per row, in this order)
    { id = 'wallet',      label = 'Bank',        place = 'grid' },
    { id = 'business',    label = 'Business',    place = 'grid' },
    { id = 'calendar',    label = 'Calendar',    place = 'grid' },
    { id = 'greybook',    label = 'Grey Book',   place = 'grid' },
    { id = 'crypto',      label = 'Crypto',      place = 'grid' },
    { id = 'garage',      label = 'Garage',      place = 'grid' },
    { id = 'government',  label = 'Government',  place = 'grid' },
    { id = 'guber',       label = 'Guber',       place = 'grid' },
    { id = 'marketplace', label = 'Lemon List',  place = 'grid' },
    { id = 'licenses',    label = 'Licenses',    place = 'grid' },
    { id = 'news',        label = 'Weazel',      place = 'grid' },
    { id = 'photos',      label = 'Gallery',     place = 'grid' },
    { id = 'property',    label = 'Property',    place = 'grid' },
    { id = 'realestate',  label = 'Real Estate', place = 'grid' },
    { id = 'scoote',      label = 'Scoot-E',     place = 'grid' },
    { id = 'settings',    label = 'Settings',    place = 'grid' },
    { id = 'twexa',       label = 'Socials',     place = 'grid' },
    { id = 'roach',       label = 'Roach',       place = 'grid' },
    { id = 'calculator',  label = 'Calculator',  place = 'grid' },
    { id = 'events',      label = 'Events',      place = 'grid' },
    -- the phone's other built-in apps; they sit on a 6th row that scrolls up from behind the dock.
    -- set enabled = false to remove any of them
    { id = 'maps',        label = 'Maps',        place = 'grid' },
    { id = 'clock',       label = 'Clock',       place = 'grid' },
    { id = 'mail',        label = 'Mail',        place = 'grid' },

    -- dock
    { id = 'call',        label = 'Phone',       place = 'dock' },
    { id = 'message',     label = 'Messages',    place = 'dock' },
    { id = 'contacts',    label = 'Contacts',    place = 'dock' }, -- opens Phone > Contacts
    { id = 'appstore',    label = 'Store',       place = 'dock' },
    { id = 'camera',      label = 'Camera',      place = 'dock' },
}

Config.AppStore = {
    downloadSeconds = 5, -- how long the download takes (seconds)
}

-- Phone prop
Config.UseProp = true -- attach a phone prop + play hand animation
Config.PropModel = 'prop_amb_phone' -- prop model to put in the player's hand

-- Calls
Config.RingTimeout = 30 -- seconds before an unanswered call is "missed"
Config.MaxRecents  = 50 -- how many recent-call entries to keep
Config.CallSpeakerRange = 6.0 -- metres: how far nearby players can hear a call put on speaker
-- Fallback ringtone (used when a player hasn't picked one in Settings > Ringtones).
-- Played in 3D via xsound so the callee + nearby players hear it.
Config.RingtoneUrl = 'https://cfx-nui-xsound/html/sounds/ringtone.mp3'

-- Ringtones
Config.Ringtones = {
    { id = 'default', name = 'Default', file = 'ringtone.mp3' },
}