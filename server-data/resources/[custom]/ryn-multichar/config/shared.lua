Config = {}

-- 'auto' | 'qb' | 'esx' | 'qbox'
Config.Framework = 'qbox'

Config.Debug = false

Config.ESX = {
    -- 'legacy' = full users insert (older ESX + ox_inventory)
    -- 'minimal' = core columns only (modern ESX; inventory via ox_inventory after join)
    mode = 'legacy',
    identifierFormat = 'char%d:%s',
}

Config.SceneTools = {
    enabled = true,
    permission = 'group.admin',
    pedCommand = 'ryn_scene_pos',
    camCommand = 'ryn_scene_cam',
    snapPedsToGround = true,
}

Config.Slots = {
    default = 3,
    max = nil, -- nil = unlimited, enforced per license only
    overrides = {
        -- ['license2:abc123...'] = 5,
    },
    tebex = {
        enabled = true,
        autoApplyOnConnect = true,
        packages = {
            -- [packageId] = slotsToAdd,
            -- ['1234567'] = 2,
        },
    },
}

Config.AdminCommands = {
    enabled = true,
    permission = 'group.admin',
    setSlots = 'setslots',
    addSlots = 'addslots',
    enableChar = 'enablechar', -- legacy alias: grant extra character slot(s)
}

Config.CreationFields = {
    { name = 'firstname',   label = 'First Name',    type = 'text',   required = true },
    { name = 'lastname',    label = 'Last Name',     type = 'text',   required = true },
    { name = 'birthdate',   label = 'Date of Birth', type = 'date',   required = true },
    { name = 'gender',      label = 'Gender',        type = 'select', required = true, options = { 'male', 'female' } },
    { name = 'nationality', label = 'Nationality',   type = 'autocomplete', required = false, options = NationalityOptions },
}

Config.Spawns = {
    ['legion'] = {
        label = 'Legion Square',
        description = 'Downtown Los Santos. Busy streets, easy access to the city center.',
        coords = vector4(195.17, -933.77, 29.7, 144.5),
        icon = 'map-pin',
    },
    ['policedp'] = {
        label = 'Police Department',
        description = 'Mission Row PD. Start near the heart of law enforcement.',
        coords = vector4(428.23, -984.28, 29.76, 3.5),
        icon = 'shield',
        jobs = { 'police', 'leo', 'sheriff' },
    },
    ['paleto'] = {
        label = 'Paleto Bay',
        description = 'Quiet northern town. Fresh air and a slower pace.',
        coords = vector4(80.35, 6424.12, 31.67, 45.5),
        icon = 'map-pin',
    },
}

Config.SpawnOptions = {
    lastLocation = true,
    publicSpawns = true,
    housing = true,
    showFilters = true,
}

Config.NameFilter = {
    enabled = true,
    blockedExact = {
        'admin', 'administrator', 'mod', 'moderator', 'staff', 'owner',
        'system', 'console', 'null', 'undefined',
        'michael', 'franklin', 'trevor',
    },
    blockedPrefixes = {
        'admin', 'mod', 'staff', 'owner', 'sys',
    },
    blockedContains = {},
}

-- Bird's-eye preview while choosing a spawn
Config.SpawnPreview = {
    height = 55.0,
    pullback = 32.0,
    fov = 42.0,
    pitch = -52.0,
    transitionMs = 350,
}

Config.Housing = {
    providers = { 'qb-houses', 'qb-apartments', 'qbx_apartments', 'ps-housing' },
    custom = {
        getOwned = function(_source, _citizenid)
            return {}
        end,
    },
}

Config.StarterItems = {
    enabled = true,
    items = {
        { name = 'phone', amount = 1 },
        { name = 'id_card', amount = 1 },
    },
}

Config.Relog = {
    enabled = true,
    permission = 'user', -- 'user' | 'admin' | 'none'
}

Config.Discord = {
    enabled = false,
    webhooks = {
        create = '',
        delete = '',
        login = '',
    },
}

-- One place for product branding (overrides matching Config.UI fields when set).
Config.Brand = {
    wordmark = 'RYN',
    logo = '', -- URL or nui:// path; empty uses wordmark mark
    accent = '#FF243A', -- drives primary UI accent (drp-hud red)
    tip = 'Select who you are in the city.',
}

Config.UI = {
    locale = 'en', -- 'en' | 'es'
    -- Every slot's ped stands in one shot with its card over its head (see `group` in config/scenes.lua).
    -- false: one ped at a time, the camera moving to each slot.
    cardsOverPeds = true,
    theme = 'drp-red',
    -- Fallback if Config.Brand.wordmark is empty
    serverName = 'RYN',
    -- Matches drp-hud: black / graphite plates, grey type, one neon red accent
    colors = {
        primary = '#FF243A',
        background = '#0A0A0C',
        surface = '#18181C',
        border = 'rgba(200, 202, 210, 0.14)',
        text = '#F2F3F5',
        textMuted = '#8D929B',
        success = '#3DDC84',
        warning = '#FFB020',
        danger = '#FF2A3D',
    },
    logo = '',
    sounds = {
        enabled = true,
        volume = 0.28,
        slotSelect = '',
        transition = '',
        confirm = '',
        error = '',
    },
}
