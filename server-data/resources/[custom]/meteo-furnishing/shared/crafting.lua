Config.Crafting = { -- NOTE THIS IS ONLY SUPPORTS FOR meteo-cratingtablets
    id = 'crafting',
    label = 'Crafting Tables',
    icon = 'hammer',
    items = {
        -- {
        --     label = 'General Workbench',
        --     model = 'gr_prop_gr_bench_04b',
        --     price = 5000,
        --     recipes = { 'advancedlockpick', 'bandage', 'firstaid', 'gauze', 'tourniquet', 'splint', 'ifaks', 'burnkit', 'marking_spray', 'paint_remover', 'painkillers', 'repairkit', 'tirerepairkit', 'armor_plate', 'heavyarmor', 'tactical_backpack', 'firework4', 'headbag', 'meteo_usb', 'electronickit', 'meteo_atm_reader', 'trojan_usb', 'remote_spikes', 'meteo_hqtable', 'drill', 'meteo_pseudoephedrine', 'meteo_acetone', 'meteo_lithium', 'meteo_hqtable', 'meteo_weedtable', 'meteo_cokemixer', 'meteo_coke_table', 'meteo_meth_lab' },
        -- },
        -- {
        --     label = 'Weapon Attachments Bench',
        --     model = 'gr_prop_gr_bench_04a',
        --     price = 10000,
        --     recipes = { 'flashlight_attachment', 'grip_attachment', 'suppressor_attachment', 'clip_attachment', 'smallscope_attachment' },
        -- },
        -- {
        --     label = 'Weapons Bench',
        --     model = 'gr_prop_gr_bench_02a',
        --     price = 25000,
        --     recipes = { 'weapon_pistol_mk2', 'weapon_microsmg', 'weapon_smg', 'weapon_assaultsmg', 'weapon_pumpshotgun', 'weapon_assaultrifle', 'weapon_carbinerifle', 'weapon_snspistol_mk2', 'weapon_smg_mk2', 'weapon_pumpshotgun_mk2', 'weapon_assaultrifle_mk2', 'weapon_carbinerifle_mk2', 'pistol_ammo', 'smg_ammo', 'rifle_ammo' },
        -- },
    }
}

Config.categories[#Config.categories + 1] = Config.Crafting