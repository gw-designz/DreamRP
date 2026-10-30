Config = {}

-- QBX, ND, ESX, OX, STANDALONE
Config.Framework = 'QBX'
Config.Debug = false
Config.EnableTestCommand = false
Config.Inventory = 'ox_inventory'

Config.DamageMultiplier = 1.0
Config.MinDamage = 3
Config.CheckInterval = 250

Config.Effects = {
    limp = true,
    limpThreshold = 40,
    bleed = true,
    bleedTickInterval = 5000,
    bleedDamagePerTick = 2,
    bleedMinHealth = 20,
}

Config.BleedChance = 50

Config.BodyParts = {
    ['head']       = { label = 'Head' },
    ['torso']      = { label = 'Torso' },
    ['pelvis']     = { label = 'Pelvis',     limp = true },
    ['left-arm']   = { label = 'Left Arm',   arm = true },
    ['right-arm']  = { label = 'Right Arm',  arm = true },
    ['left-hand']  = { label = 'Left Hand',  arm = true },
    ['right-hand'] = { label = 'Right Hand', arm = true },
    ['left-leg']   = { label = 'Left Leg',   limp = true },
    ['right-leg']  = { label = 'Right Leg',  limp = true },
    ['left-foot']  = { label = 'Left Foot',  limp = true },
    ['right-foot'] = { label = 'Right Foot', limp = true },
}

Config.Items = {
    ['bandage'] = {
        health = 15,
        bones = 20,
        stopBleed = 1,
        notify = 'items.bandage',
    },

    ['firstaid'] = {
        health = 40,
        bones = 50,
        stopBleed = 2,
        notify = 'items.firstaid',
    },

    ['medkit'] = {
        setHealth = 200,
        bones = 'all',
        stopBleed = 'all',
        notify = 'items.medkit',
    },

    ['painkillers'] = {
        health = 10,
        bones = 10,
        notify = 'items.painkillers',
    },
}

Config.Bones = {
    [0]     = 'NONE',
    [31085] = 'head',
    [31086] = 'head',
    [39317] = 'head',
    [57597] = 'torso',
    [23553] = 'torso',
    [24816] = 'torso',
    [24817] = 'torso',
    [24818] = 'torso',
    [10706] = 'torso',
    [64729] = 'torso',
    [11816] = 'pelvis',
    [45509] = 'left-arm',
    [61163] = 'left-arm',
    [18905] = 'left-hand',
    [4089]  = 'left-hand',
    [4090]  = 'left-hand',
    [4137]  = 'left-hand',
    [4138]  = 'left-hand',
    [4153]  = 'left-hand',
    [4154]  = 'left-hand',
    [4169]  = 'left-hand',
    [4170]  = 'left-hand',
    [4185]  = 'left-hand',
    [4186]  = 'left-hand',
    [26610] = 'left-hand',
    [26611] = 'left-hand',
    [26612] = 'left-hand',
    [26613] = 'left-hand',
    [26614] = 'left-hand',
    [40269] = 'right-arm',
    [28252] = 'right-arm',
    [57005] = 'right-hand',
    [58866] = 'right-hand',
    [58867] = 'right-hand',
    [58868] = 'right-hand',
    [58869] = 'right-hand',
    [58870] = 'right-hand',
    [64016] = 'right-hand',
    [64017] = 'right-hand',
    [64064] = 'right-hand',
    [64065] = 'right-hand',
    [64080] = 'right-hand',
    [64081] = 'right-hand',
    [64096] = 'right-hand',
    [64097] = 'right-hand',
    [64112] = 'right-hand',
    [64113] = 'right-hand',
    [58271] = 'left-leg',
    [63931] = 'left-leg',
    [2108]  = 'left-foot',
    [14201] = 'left-foot',
    [36864] = 'right-leg',
    [51826] = 'right-leg',
    [20781] = 'right-foot',
    [52301] = 'right-foot',
}
