--[[
     Meteo Studios FiveM Server
     Copyright (c) 2026 Meteo Studios. All rights reserved.

     Documentation : https://docs.meteofivem.net/servers/meteo-fivem-server
     Discord       : https://discord.gg/P4B4hYUujN
     Website       : https://meteofivem.net

     Need help? Join Meteo Discord server for setup assistance.
     Our team will guide you through configuring the meteo server
     to match your exact needs.

     NOTICE: Unauthorized redistribution or resale of this
     resource is strictly prohibited.
--]]

--[[ 
    WARNING: Do not modify this config unless you fully
    understand what each thing does. Incorrect changes may
    break your server. If you're unsure, please contact our
    support on Meteo Discord before making any changes. 
--]]

Config = {}

Config.target = 'auto' -- 'qb-target' or 'ox_target'
Config.inventory = 'auto' -- 'qb-inventory' or 'ox_inventory'

Config.defaultFurnitureLimit = 150

-- Per-model placement limits (model_name = max_count)
Config.modelLimits = {
    ['apa_mp_h_yacht_side_table_02'] = 1,
}
Config.paymentMethod = 'both'  -- 'bank', 'cash', 'both'

-- Currency
Config.currencySymbol = '$'

-- Item images CDN (leave empty to use local images from web/images/)
-- Example: 'https://assets.meteofivem.net/furnishing/'
-- Image URL will be: CDN + model + '.webp' (e.g., https://assets.meteofivem.net/furnishing/prop_couch_01.webp)
Config.imagesCDN = ''

-- Wardrobe/Clothing menu configuration
Config.wardrobe = {
    enabled = true,
    event = 'illenium-appearance:client:openOutfitMenu',  -- 'qb-clothing:client:openMenu'
}

-- Default storage configuration (can override per-item with slots/maxWeight)
Config.storage = {
    slots = 20,         -- Number of inventory slots
    maxWeight = 50000  -- Maximum weight
}

-- Storage lockpick configuration
Config.storageLockpick = {
    enabled = true,
    requireOwnerOnline = true,  -- Owner must be online to lockpick storage
    items = {
        ['lockpick'] = {
            label = 'Lockpick',
            -- ox_lib skillcheck difficulty
            difficulty = { 'medium', 'easy', 'medium' },
            breakChance = 15,           -- 15% break chance on fail
            breakChanceSuccess = 2      -- 2% break even on success
        },
        ['advancedlockpick'] = {
            label = 'Advanced Lockpick',
            -- ox_lib skillcheck difficulty
            difficulty = { 'easy', 'easy' },
            breakChance = 5,            -- 5% break chance on fail
            breakChanceSuccess = 0      -- Never breaks on success
        }
    },
    cooldown = 30000,  -- 30 seconds cooldown after failed attempt
    unlockDuration = 300000  -- 5 minutes - how long storage stays unlocked after successful lockpick
}

-- DUI holographic display for special furniture models
Config.dui = {
    enabled = true,
    models = {
        ['apa_mp_h_yacht_side_table_02'] = { -- (only for meteo-organizations)
            type = 'org_hq',
            width = 1200,
            height = 800,
            panelWidth = 3.2,
            zOffset = 1.3,
            renderDistance = 8.0,
        },
    },
}

-- Furniture catalog - you can add new items below as you want
Config.categories = {
    {
        id = 'essential',  -- Has target support in shared/targets.lua (opens apartment radial menu)
        label = 'Essential',
        icon = 'star',
        items = {
            { label = 'Tablet', model = 'hei_prop_dlc_tablet', price = 0 },
        }
    },
    {
        id = 'sofas',
        label = 'Sofas & Couches',
        icon = 'couch',
        items = {
            { label = 'Corner Sofa (L-Shaped, Cream)', model = 'apa_mp_h_stn_sofacorn_01', price = 4950 },
            { label = 'Corner Sofa (Beige, Cushioned)', model = 'apa_mp_h_stn_sofacorn_08', price = 4400 },
            { label = 'Corner Sofa (Dark, Modern)', model = 'apa_mp_h_stn_sofacorn_09', price = 5500 },
            { label = 'Executive Sofa (Charcoal)', model = 'ex_mp_h_off_sofa_003', price = 3200 },
            { label = 'Executive Sofa (Gray)', model = 'ex_mp_h_off_sofa_02', price = 3200 },
            { label = 'Yacht Sofa (White & Brown)', model = 'h4_mp_h_yacht_sofa_01', price = 7500 },
            { label = 'Corner Sofa (Dark Blue)', model = 'hei_heist_stn_sofacorn_05', price = 3900 },
            { label = 'Corner Sofa (Green Cushions)', model = 'hei_heist_stn_sofacorn_06', price = 3700 },
            { label = 'Two-Seat Sofa (Pillows)', model = 'prop_couch_01', price = 1500 },
            { label = 'Rustic Couch (Beige Cushions)', model = 'prop_couch_03', price = 1300 },
            { label = 'Modern Couch (Wood Trim)', model = 'prop_couch_lg_02', price = 2500 },
            { label = 'Fabric Couch (Gray/Brown)', model = 'prop_couch_lg_05', price = 2700 },
            { label = 'Vintage Couch (Red/Brown)', model = 'prop_couch_lg_06', price = 1700 },
            { label = 'Couch with Pillows (Gray/Orange)', model = 'prop_couch_lg_07', price = 2900 },
            { label = 'Modern Couch (Brown/Gray)', model = 'prop_couch_lg_08', price = 4100 },
            { label = 'L-Shaped Sofa (Left Side)', model = 'prop_couch_sm1_07', price = 490 },
            { label = 'L-Shaped Sofa (Right Side)', model = 'prop_couch_sm2_07', price = 490 },
            { label = 'Compact Couch (Brown Fabric)', model = 'prop_couch_sm_02', price = 720 },
            { label = 'Compact Couch (Beige Fabric)', model = 'prop_couch_sm_05', price = 900 },
            { label = 'Compact Sofa (Gray)', model = 'prop_couch_sm_06', price = 700 },
            { label = 'Vintage Leather Sofa', model = 'prop_couch_sm_07', price = 2000 },
            { label = 'Yacht Sofa (2-Seat, Black)', model = 'prop_yaught_sofa_01', price = 1900 },
            { label = 'L-Shaped Sofa (Modern)', model = 'v_ilev_m_sofa', price = 4500 },
        }
    },
    {
        id = 'chairs',
        label = 'Chairs & Seating',
        icon = 'chair',
        items = {
            { label = 'Modern Armchair (Mustard)', model = 'apa_mp_h_stn_chairarm_01', price = 2000 },
            { label = 'Armchair (Red Fabric)', model = 'apa_mp_h_stn_chairstrip_03', price = 2000 },
            { label = 'Armchair (Cyan Fabric)', model = 'apa_mp_h_stn_chairstrip_08', price = 2000 },
            { label = 'Leather Club Armchair (Brown)', model = 'bkr_prop_biker_chairstrip_01', price = 650 },
            { label = 'Yacht Lounge Chair (White)', model = 'h4_mp_h_yacht_strip_chair_01', price = 1400 },
            { label = 'Dining Chair (Red Plastic)', model = 'hei_heist_din_chair_02', price = 350 },
            { label = 'Rattan Lounger (Dark Frame)', model = 'hei_prop_yah_lounger', price = 600 },
            { label = 'Rattan Chair (Single, Narrow)', model = 'hei_prop_yah_seat_01', price = 650 },
            { label = 'Rattan Chair (Wide Seat)', model = 'hei_prop_yah_seat_02', price = 800 },
            { label = 'Rattan Chair (Armrests)', model = 'hei_prop_yah_seat_03', price = 950 },
            { label = 'Upholstered Armchair (Brown Fabric)', model = 'prop_armchair_01', price = 650 },
            { label = 'Metal Chair (Blue Frame)', model = 'prop_chair_01a', price = 250 },
            { label = 'Plastic Chair (Worn Red)', model = 'prop_chair_01b', price = 280 },
            { label = 'Wicker Chair (Dark)', model = 'prop_chair_02', price = 380 },
            { label = 'Antique Dining Chair (Round Back)', model = 'prop_chair_03', price = 220 },
            { label = 'Modern Chair (Striped Back)', model = 'prop_chair_04a', price = 740 },
            { label = 'Modern Chair (Flat Back)', model = 'prop_chair_04b', price = 700 },
            { label = 'Classic Wicker Chair', model = 'prop_chair_05', price = 470 },
            { label = 'Dining Chair (Dark Red)', model = 'prop_chair_06', price = 290 },
            { label = 'Vintage Wooden Chair', model = 'prop_chair_07', price = 220 },
            { label = 'Plastic Chair (White Legs)', model = 'prop_chair_08', price = 200 },
            { label = 'Rattan Chair (Green Weave)', model = 'prop_chair_09', price = 300 },
            { label = 'Ornate Armchair (Vintage)', model = 'prop_chair_10', price = 300 },
            { label = 'Antique Chateau Armchair', model = 'prop_chateau_chair_01', price = 290 },
            { label = 'Circus-Style Wooden Chair', model = 'prop_clown_chair', price = 190 },
            { label = 'Basic Chair (Plastic Seat)', model = 'prop_gc_chair02', price = 195 },
            { label = 'Office Chair (High Back)', model = 'prop_off_chair_01', price = 650 },
            { label = 'Office Chair (Padded, Gray)', model = 'prop_off_chair_03', price = 300 },
            { label = 'Office Chair (Worn Fabric)', model = 'prop_off_chair_04', price = 300 },
            { label = 'Office Chair (Low Back, Gray)', model = 'prop_off_chair_04b', price = 350 },
            { label = 'Office Chair (Mesh Armrests)', model = 'prop_off_chair_05', price = 450 },
            { label = 'Folding Lounge Chair (Blue)', model = 'prop_old_deck_chair', price = 160 },
            { label = 'Wooden Armchair (Gray, Aged)', model = 'prop_old_wood_chair', price = 160 },
            { label = 'Old Wooden Chair (LOD)', model = 'prop_old_wood_chair_lod', price = 180 },
            { label = 'Patio Lounger (Beige Cushion)', model = 'prop_patio_lounger1', price = 900 },
            { label = 'Patio Lounger (No Cushion)', model = 'prop_patio_lounger1b', price = 800 },
            { label = 'Green Patio Lounger (Foldable)', model = 'prop_patio_lounger_2', price = 800 },
            { label = 'Patio Lounger (White)', model = 'prop_patio_lounger_3', price = 500 },
            { label = 'Camping Chair (Dark Green)', model = 'prop_skid_chair_01', price = 430 },
            { label = 'Camping Chair (Blue Fabric)', model = 'prop_skid_chair_02', price = 430 },
            { label = 'Camping Chair (Plaid)', model = 'prop_skid_chair_03', price = 430 },
            { label = 'Classic Armchair (Leather, Worn)', model = 'prop_sol_chair', price = 1650 },
            { label = 'Bar Stool (Metal)', model = 'prop_stool_01', price = 280 },
            { label = 'Wooden Chair (With Armrests)', model = 'prop_table_01_chr_a', price = 350 },
            { label = 'Wooden Chair (No Armrests)', model = 'prop_table_01_chr_b', price = 320 },
            { label = 'Wooden Chair (Dark Wood)', model = 'prop_table_02_chr', price = 300 },
            { label = 'Plastic Chair (Wide Back, White)', model = 'prop_table_03b_chr', price = 220 },
            { label = 'Plastic Chair (Armrest, White)', model = 'prop_table_03_chr', price = 220 },
            { label = 'Dining Chair (Metal Frame)', model = 'prop_table_04_chr', price = 380 },
            { label = 'Wicker Chair (Dining)', model = 'prop_table_05_chr', price = 330 },
            { label = 'Chair (Thin Metal Frame)', model = 'prop_table_06_chr', price = 650 },
            { label = 'Waiting Seat (Brown Leather)', model = 'prop_waiting_seat_01', price = 500 },
            { label = 'Yacht Chair (Single, Black)', model = 'prop_yaught_chair_01', price = 850 },
            { label = 'Ornate Wooden Chair (Carved)', model = 'p_dinechair_01_s', price = 400 },
            { label = 'Yacht Armchair (White)', model = 'sf_mp_h_yacht_armchair_03', price = 1100 },
            { label = 'Office Chair (Boss Style)', model = 'v_club_officechair', price = 950 },
            { label = 'Desk Chair (Gray, No Arms)', model = 'v_corp_bk_chair3', price = 200 },
            { label = 'Desk Chair (Red)', model = 'v_corp_cd_chair', price = 240 },
            { label = 'Office Chair (Slim Back)', model = 'v_corp_offchair', price = 800 },
            { label = 'Office Chair (Black Leather)', model = 'v_ret_gc_chair03', price = 800 },
            { label = 'Office Chair (Wood Frame)', model = 'xm_lab_chairarm_03', price = 550 },
        }
    },
    {
        id = 'storage',  -- Has target support in shared/targets.lua (opens inventory stash)
        label = 'Storage',
        icon = 'archive',
        items = {
            { label = 'Locker', model = 'p_cs_locker_01_s', price = 100, slots = 40, maxWeight = 200000 },
            { label = 'Safe', model = 'prop_ld_int_safe_01', price = 1100 },
            { label = 'Crafting Bench', model = 'prop_toolchest_05', price = 5000 },
            { label = 'Modern Chest of Drawers (Dark)', model = 'apa_mp_h_bed_chestdrawer_02', price = 7800, slots = 10, maxWeight = 10000 },
            { label = 'Floor Standing Shelf (Wood & Black)', model = 'apa_mp_h_str_shelffloorm_02', price = 8000, slots = 10, maxWeight = 10000 },
            { label = 'Low Sideboard (Dark Wood)', model = 'apa_mp_h_str_sideboardl_11', price = 10000, slots = 10, maxWeight = 10000 },
            { label = 'Low Sideboard (White & Gray)', model = 'apa_mp_h_str_sideboardl_13', price = 12000, slots = 10, maxWeight = 10000 },
            { label = 'Low Sideboard (White & Wood)', model = 'apa_mp_h_str_sideboardl_14', price = 11500, slots = 10, maxWeight = 10000 },
            { label = 'Gun Locker Cabinet', model = 'bkr_prop_gunlocker_01a', price = 9200, slots = 10, maxWeight = 10000 },
            { label = 'Green Crate', model = 'gr_prop_gr_rsply_crate04a', price = 7200, slots = 8, maxWeight = 15000 },
            { label = 'Weapon Wooden Crate', model = 'm23_2_prop_m32_weaponcrate_01a', price = 6800, slots = 7, maxWeight = 8000 },
            { label = 'White Cabinet (Tall, Drawers)', model = 'prop_cabinet_01', price = 7000, slots = 10, maxWeight = 10000 },
            { label = 'Filing Cabinet (3 Drawers, Beige)', model = 'prop_cabinet_02b', price = 6000, slots = 10, maxWeight = 10000 },
            { label = 'Warehouse Shelving Unit (Metal)', model = 'prop_ff_shelves_01', price = 10000, slots = 10, maxWeight = 10000 },
            { label = 'Wooden Shelf (Open, Aged)', model = 'prop_rub_cabinet02', price = 6100, slots = 10, maxWeight = 10000 },
            { label = 'Suitcase (Black)', model = 'prop_suitcase_01', price = 5500, slots = 5, maxWeight = 10000 },
            { label = 'Suitcase (Brown)', model = 'prop_suitcase_01b', price = 5500, slots = 5, maxWeight = 10000 },
            { label = 'Suitcase (Red)', model = 'prop_suitcase_01c', price = 5500, slots = 5, maxWeight = 10000 },
            { label = 'Suitcase (Dark Gray)', model = 'prop_suitcase_01d', price = 5500, slots = 5, maxWeight = 10000 },
            { label = 'Double Suitcase (Stacked)', model = 'prop_suitcase_02', price = 3500, slots = 5, maxWeight = 10000 },
            { label = 'Double Suitcase (Red + Black)', model = 'prop_suitcase_03', price = 3500, slots = 3, maxWeight = 10000 },
            { label = 'Double Suitcase (Black)', model = 'prop_suitcase_03b', price = 3500, slots = 3, maxWeight = 10000 },
            { label = 'TV Cabinet (Open Shelves)', model = 'prop_tv_cabinet_03', price = 6900, slots = 10, maxWeight = 10000 },
            { label = 'TV Cabinet (Bookshelf Style)', model = 'prop_tv_cabinet_04', price = 6400, slots = 10, maxWeight = 10000 },
            { label = 'TV Cabinet (Curved Front)', model = 'prop_tv_cabinet_05', price = 6200, slots = 10, maxWeight = 10000 },
            { label = 'Store Counter', model = 'p_new_j_counter_03', price = 9000, slots = 10, maxWeight = 10000 },
            { label = 'Vault Safe (Industrial)', model = 'p_v_43_safe_s', price = 40000, slots = 12, maxWeight = 30000 },
        }
    },
    {
        id = 'wardrobe',  -- Has target support in shared/targets.lua (opens clothing menu)
        label = 'Wardrobe',
        icon = 'shirt',
        items = {
            { label = 'Open Biker Locker', model = 'bkr_prop_biker_garage_locker_01', price = 4200 },
        }
    },
    {
        id = 'electronics',
        label = 'Electronics',
        icon = 'tv',
        items = {
            { label = 'Guitar Amplifier', model = 'prop_amp_01', price = 1200 },
            { label = 'CCTV Camera (Ceiling Dome)', model = 'prop_cctv_cam_04c', price = 12000 },
            { label = 'CCTV Camera (Ceiling Tube)', model = 'prop_cctv_cam_05a', price = 13000 },
            { label = 'CCTV Camera (Wall Box)', model = 'prop_cctv_cam_06a', price = 14000 },
            { label = 'Office Copier (Open Tray)', model = 'prop_copier_01', price = 700 },
            { label = 'Keyboard (Black)', model = 'prop_cs_keyboard_01', price = 480 },
            { label = 'TV Stand with Screen', model = 'prop_cs_tv_stand', price = 2000 },
            { label = 'Desktop Computer (Tower)', model = 'prop_dyn_pc', price = 2000 },
            { label = 'Oscillating Fan (Floor)', model = 'prop_fan_01', price = 400 },
            { label = 'Office Fax Machine', model = 'prop_fax_01', price = 400 },
            { label = 'Boombox Radio (Retro)', model = 'prop_ghettoblast_01', price = 1500 },
            { label = 'Keyboard (White)', model = 'prop_keyboard_01a', price = 480 },
            { label = 'Laptop (Open, Green Wallpaper)', model = 'prop_laptop_01a', price = 3200 },
            { label = 'Microwave (Basic, White)', model = 'prop_micro_01', price = 850 },
            { label = 'Microwave (Digital, White)', model = 'prop_micro_02', price = 950 },
            { label = 'Microwave (Wooden Casing)', model = 'prop_micro_04', price = 800 },
            { label = 'Monitor (Windows XP Style)', model = 'prop_monitor_01c', price = 2000 },
            { label = 'Monitor (Gameshow Display)', model = 'prop_monitor_01d', price = 2200 },
            { label = 'Monitor (Lifeinvader UI)', model = 'prop_monitor_li', price = 2200 },
            { label = 'Wide Office Monitor', model = 'prop_monitor_w_large', price = 3100 },
            { label = 'Mouse (Standard, Right)', model = 'prop_mouse_02', price = 90 },
            { label = 'Office Telephone (TNT Model)', model = 'prop_office_phone_tnt', price = 200 },
            { label = 'Old PC Tower (Beige)', model = 'prop_pc_02a', price = 1600 },
            { label = 'Portable Hi-Fi (Boombox)', model = 'prop_portable_hifi_01', price = 330 },
            { label = 'Office Printer (Closed Lid)', model = 'prop_printer_01', price = 450 },
            { label = 'Speaker Panel (Vertical, LED)', model = 'prop_speaker_01', price = 1450 },
            { label = 'Tall Wooden Speaker (Hi-Fi)', model = 'prop_speaker_02', price = 1200 },
            { label = 'Large Black Speaker', model = 'prop_speaker_06', price = 2000 },
            { label = 'Party Speaker (Dual)', model = 'prop_speaker_07', price = 550 },
            { label = 'CRT TV (Wooden Frame)', model = 'prop_trev_tv_01', price = 140 },
            { label = 'TV (Black Screen)', model = 'prop_tv_01', price = 680 },
            { label = 'TV', model = 'prop_tv_02', price = 550 },
            { label = 'CRT TV (Dark Gray)', model = 'prop_tv_03', price = 150 },
            { label = 'CRT TV (Retro, Gray)', model = 'prop_tv_04', price = 120 },
            { label = 'Vintage TV (Antenna)', model = 'prop_tv_05', price = 700 },
            { label = 'CRT TV (Angled Edges)', model = 'prop_tv_06', price = 200 },
            { label = 'CRT TV (Beveled Frame)', model = 'prop_tv_07', price = 180 },
            { label = 'Flat TV (Modern, On Stand)', model = 'prop_tv_flat_01', price = 3700 },
            { label = 'Flat TV (Modern, Wide)', model = 'prop_tv_flat_02', price = 3000 },
            { label = 'Flat TV (Wide, Black Frame)', model = 'prop_tv_flat_02b', price = 1300 },
            { label = 'Flat TV (Modern Stand)', model = 'prop_tv_flat_03', price = 1500 },
            { label = 'Flat TV (Stand, No Logo)', model = 'prop_tv_flat_03b', price = 4000 },
            { label = 'Flat TV (Michael\'s Room)', model = 'prop_tv_flat_michael', price = 3800 },
            { label = 'TV Stand (Trust Poster)', model = 'prop_tv_stand_01', price = 2200 },
            { label = 'Test TV (Boxy, Placeholder)', model = 'prop_tv_test', price = 900 },
            { label = 'Washing Machine (Modern)', model = 'prop_washer_02', price = 2400 },
            { label = 'Washing Machine (Vintage)', model = 'prop_washer_03', price = 2000 },
            { label = 'Club Speaker (Wall Mount 1)', model = 'v_club_roc_eq1', price = 300 },
            { label = 'Club Speaker (Wall Mount 2)', model = 'v_club_roc_eq2', price = 450 },
            { label = 'Monitor (Square)', model = 'v_res_monitorsquare', price = 2000 },
            { label = 'Monitor (Wide)', model = 'v_res_monitorwidelarge', price = 3000 },
            { label = 'Mouse with Mat', model = 'v_res_mousemat', price = 110 },
            { label = 'PC Headset (Lying)', model = 'v_res_pcheadset', price = 190 },
            { label = 'Tower Speaker (Standing)', model = 'v_res_pcspeaker', price = 300 },
            { label = 'PC Tower (Black)', model = 'v_res_pctower', price = 2000 },
            { label = 'Printer (Multifunction)', model = 'v_res_printer', price = 550 },
            { label = 'Vacuum Cleaner (Upright)', model = 'v_res_vacuum', price = 1250 },
            { label = 'Shredder (Office)', model = 'v_ret_gc_shred', price = 480 },
        }
    },
    {
        id = 'beds',
        label = 'Beds',
        icon = 'bed',
        items = {
            { label = 'Double Bed (Black Upholstered)', model = 'apa_mp_h_bed_double_09', price = 3800 },
            { label = 'Wide Bed (Red Frame)', model = 'apa_mp_h_bed_wide_05', price = 2800 },
            { label = 'Double Bed with Built-in Table', model = 'apa_mp_h_bed_with_table_02', price = 4500 },
            { label = 'Executive Bed (Beige Upholstery)', model = 'ex_prop_exec_bed_01', price = 1100 },
            { label = 'Modern Double Bed (Dark Gray)', model = 'hei_heist_bed_double_08', price = 3700 },
            { label = 'Mattress (Old, Dirty)', model = 'prop_rub_matress_01', price = 750 },
            { label = 'Double Bed (White Frame)', model = 'prop_t_sofa_02', price = 2100 },
            { label = 'Worn Wooden Bed (Blanket)', model = 'p_lestersbed_s', price = 1500 },
            { label = 'Yacht Bed (Single, Brown)', model = 'sum_mp_h_yacht_bed_01', price = 3600 },
            { label = 'Yacht Bed (Double, Gray)', model = 'sum_mp_h_yacht_bed_02', price = 4000 },
        }
    },
    {
        id = 'lighting',
        label = 'Lighting',
        icon = 'lightbulb',
        items = {
            { label = 'Ceiling Light (Glass Dome)', model = 'prop_wall_light_06a', price = 500 },
        }
    },
    {
        id = 'tables',
        label = 'Tables & Desks',
        icon = 'table',
        items = {
            -- { label = 'HQ table', model = 'apa_mp_h_yacht_side_table_02', price = 0, requiredItem = 'meteo_hqtable' },
            -- { label = 'Weed Table', model = 'bkr_prop_weed_table_01a', price = 0, requiredItem = 'meteo_weedtable' },
            -- { label = 'Coke Mixer', model = 'bkr_prop_coke_mixer_01', price = 0, requiredItem = 'meteo_cokemixer' },
            -- { label = 'Coke Table', model = 'bkr_prop_coke_table01a', price = 0, requiredItem = 'meteo_coke_table' },
            -- { label = 'Meth Lab Kit', model = 'prop_meth_setup_01', price = 0, requiredItem = 'meteo_meth_lab' },
            { label = 'Glass Dining Table', model = 'apa_mp_h_din_table_01', price = 7000 },
            { label = 'Modern Curved Chaise Lounger', model = 'apa_mp_h_tab_sidelrg_02', price = 3500 },
            { label = 'Yacht Dining Table (Wooden)', model = 'hei_prop_yah_table_01', price = 500 },
            { label = 'Yacht Table (With Cloth)', model = 'hei_prop_yah_table_02', price = 550 },
            { label = 'Yacht Table (Blue Legs)', model = 'hei_prop_yah_table_03', price = 1000 },
            { label = 'Modern Coffee Table (White Frame)', model = 'prop_fbi3_coffee_table', price = 1200 },
            { label = 'Low Farmhouse Table (Dark Wood)', model = 'prop_ld_farm_table01', price = 1500 },
            { label = 'Low Farm Table (Dark Wood)', model = 'prop_ld_farm_table02', price = 1400 },
            { label = 'Office Desk (Drawers, Gray)', model = 'prop_office_desk_01', price = 1850 },
            { label = 'Patio Table (Wooden)', model = 'prop_patio_lounger1_table', price = 900 },
            { label = 'Wooden Picnic Table (Standard)', model = 'prop_picnictable_01', price = 680 },
            { label = 'Wooden Picnic Table (LOD)', model = 'prop_picnictable_01_lod', price = 500 },
            { label = 'Wooden Picnic Table (Red Accents)', model = 'prop_picnictable_02', price = 900 },
            { label = 'Wooden Round Table (Chateau Style)', model = 'prop_proxy_chateau_table', price = 800 },
            { label = 'Old Wooden Table (Worn)', model = 'prop_rub_table_01', price = 350 },
            { label = 'Rustic Wooden Table (Damaged)', model = 'prop_rub_table_02', price = 310 },
            { label = 'Low Wooden Table (Small)', model = 'prop_tablesmall_01', price = 2000 },
            { label = 'Coffee Table (Wooden)', model = 'prop_table_01', price = 3400 },
            { label = 'Round Table (Wood + Iron Base)', model = 'prop_table_02', price = 1200 },
            { label = 'Plastic Table (White)', model = 'prop_table_03', price = 950 },
            { label = 'Plastic Table (Square, White)', model = 'prop_table_03b', price = 600 },
            { label = 'Plastic Table (Square, White)', model = 'prop_table_03b_cs', price = 600 },
            { label = 'Dining Bench (Dark Frame)', model = 'prop_table_04', price = 3000 },
            { label = 'Round Dining Table (Wicker)', model = 'prop_table_05', price = 720 },
            { label = 'Modern Dining Table (Metal Legs)', model = 'prop_table_06', price = 1400 },
            { label = 'Round Table with Pole', model = 'prop_table_07', price = 620 },
            { label = 'Old Wooden Table with Cover', model = 'prop_table_08', price = 500 },
            { label = 'Parasol Table (Wood, Red Canopy)', model = 'prop_table_para_comb_01', price = 1200 },
            { label = 'Parasol Table (Blue Canopy)', model = 'prop_table_para_comb_03', price = 1200 },
            { label = 'Parasol Table (Gray Fabric)', model = 'prop_table_para_comb_04', price = 1300 },
            { label = 'Table Tennis Table (Foldable)', model = 'prop_table_tennis', price = 2100 },
            { label = 'Market Table (Foldable)', model = 'prop_ven_market_table1', price = 1300 },
            { label = 'Yacht Table (Dark Wicker)', model = 'prop_yacht_table_01', price = 640 },
            { label = 'Yacht Table (Gray Wicker)', model = 'prop_yacht_table_02', price = 550 },
            { label = 'Yacht Table (Black Wicker)', model = 'prop_yacht_table_03', price = 1000 },
            { label = 'Coffee Table (Modern, Black)', model = 'v_ilev_liconftable_sml', price = 8000 },
            { label = 'Wooden Coffee Table (Low)', model = 'v_ind_rc_lowtable', price = 800 },
            { label = 'Modern Desk (Black&Wooden)', model = 'xm_prop_lab_desk_02', price = 3600 },
        }
    },
    {
        id = 'bathroom',
        label = 'Bathroom',
        icon = 'bath',
        items = {
            { label = 'Shower Rack (3 Shelves)', model = 'prop_shower_rack_01', price = 80 },
            { label = 'Metal Sink (Wall Mounted)', model = 'prop_sink_02', price = 300 },
            { label = 'Bathroom Sink (Rounded)', model = 'prop_sink_05', price = 280 },
            { label = 'Bathroom Sink (Tall Pedestal)', model = 'prop_sink_06', price = 250 },
            { label = 'Wall Soap Dispenser', model = 'prop_soap_disp_01', price = 220 },
            { label = 'Toilet (Standard)', model = 'prop_toilet_01', price = 350 },
            { label = 'Toilet (Modern)', model = 'prop_toilet_02', price = 500 },
            { label = 'Toilet Brush (Holder)', model = 'prop_toilet_brush_01', price = 25 },
            { label = 'Toilet Soap (With Dish)', model = 'prop_toilet_soap_02', price = 30 },
            { label = 'Soap Dispenser (Pink)', model = 'prop_toilet_soap_04', price = 50 },
            { label = 'Toothpaste Tube', model = 'prop_toothpaste_01', price = 20 },
            { label = 'Towel Stack (White)', model = 'prop_towel_01', price = 40 },
            { label = 'Public Sink (Stainless, Wide)', model = 'prop_w_fountain_01', price = 180 },
            { label = 'Bathtub (Modern Oval)', model = 'v_res_mbath', price = 600 },
            { label = 'Bathroom Sink (Wall Mount)', model = 'v_res_mbsink', price = 400 },
        }
    },
    {
        id = 'kitchen',
        label = 'Kitchen',
        icon = 'utensils',
        items = {
            { label = 'Blender / Food Processor', model = 'prop_foodprocess_01', price = 170 },
            { label = 'Tall Fridge (Closed)', model = 'prop_fridge_03', price = 8500, slots = 8, maxWeight = 8000 },
            { label = 'Electric Kettle (Silver)', model = 'prop_kettle', price = 140 },
            { label = 'Electric Juicer', model = 'prop_kitch_juicer', price = 200 },
            { label = 'Frying Pan (Shallow)', model = 'prop_kitch_pot_fry', price = 60 },
            { label = 'Cooking Pot (Large)', model = 'prop_kitch_pot_lrg2', price = 80 },
            { label = 'Kitchen Knife (Used)', model = 'prop_knife', price = 50 },
            { label = 'Jar of Lime', model = 'prop_lime_jar', price = 35 },
            { label = 'Cooking Pot (Medium Size)', model = 'prop_pot_03', price = 60 },
            { label = 'Toaster (Stainless)', model = 'prop_toaster_01', price = 400 },
            { label = 'Toaster (White)', model = 'prop_toaster_02', price = 330 },
            { label = 'Water Cooler (Plastic Jug)', model = 'prop_watercooler', price = 1100 },
            { label = 'Decorative Cake Dome (Glass)', model = 'v_res_cakedome', price = 75 },
            { label = 'Food Jar (Chilli)', model = 'v_res_foodjara', price = 45 },
            { label = 'Food Jar (Rice)', model = 'v_res_foodjarb', price = 40 },
            { label = 'Fridge (Double Door, Water Dispenser)', model = 'v_res_fridgemodsml', price = 9900, slots = 8, maxWeight = 8000 },
            { label = 'Knife Block (Wood)', model = 'v_res_mknifeblock', price = 110 },
            { label = 'Mug (Stoneware)', model = 'v_res_mmug', price = 20 },
            { label = 'Dinner Plate (Blue Border)', model = 'v_res_mplatesml', price = 20 },
            { label = 'Mortar and Pestle (Stone)', model = 'v_res_pestle', price = 50 },
            { label = 'Fridge (Retro)', model = 'v_res_tre_fridge', price = 7800, slots = 8, maxWeight = 8000 },
            { label = 'Stack of Plates', model = 'v_res_tt_bowlpile02', price = 40 },
        }
    },
    {
        id = 'plants',
        label = 'Plants & Nature',
        icon = 'leaf',
        items = {
            { label = 'Palm Tree (Tall, Full)', model = 'prop_palm_med_01a', price = 3250 },
            { label = 'Palm Tree (Tall, Curved)', model = 'prop_palm_med_01b', price = 3100 },
            { label = 'Palm Tree (Medium Height, Wide)', model = 'prop_palm_med_01c', price = 3000 },
            { label = 'Palm Tree (Leaning Right)', model = 'prop_palm_med_01d', price = 2300 },
            { label = 'Palm Tree (Small Decorative)', model = 'prop_palm_sm_01a', price = 3000 },
            { label = 'Palm Tree (Small, Dense)', model = 'prop_palm_sm_01d', price = 2400 },
            { label = 'Palm Tree (Small, Thin)', model = 'prop_palm_sm_01e', price = 3000 },
            { label = 'Palm Tree (Small, Thick)', model = 'prop_palm_sm_01f', price = 2800 },
            { label = 'Rectangular Interior Planter', model = 'prop_plant_interior_05a', price = 600 },
            { label = 'Indoor Plant (Short, Round Pot)', model = 'prop_plant_int_01a', price = 360 },
            { label = 'Indoor Plant (Tall, Brown Pot)', model = 'prop_plant_int_01b', price = 340 },
            { label = 'Topiary Ball (Square Pot)', model = 'prop_plant_int_02a', price = 420 },
            { label = 'Topiary Ball (Round Pot)', model = 'prop_plant_int_02b', price = 460 },
            { label = 'Indoor Fern (Stone Pot)', model = 'prop_plant_int_03a', price = 330 },
            { label = 'Indoor Plant (Tall, White Pot)', model = 'prop_plant_int_03b', price = 285 },
            { label = 'Indoor Plant (Pointed, Tall)', model = 'prop_plant_int_03c', price = 250 },
            { label = 'Wide Indoor Plant (Low Pot)', model = 'prop_plant_int_04a', price = 310 },
            { label = 'Indoor Bush (Flat Base)', model = 'prop_plant_int_04b', price = 340 },
            { label = 'Leafy Plant (Round Pot)', model = 'prop_plant_int_04c', price = 120 },
            { label = 'Wicker Planter with Flowers', model = 'prop_plant_int_05a', price = 590 },
            { label = 'Basket Plant (Rectangular)', model = 'prop_plant_int_05b', price = 400 },
            { label = 'Rectangular Planter (Tall Grass)', model = 'prop_plant_int_06a', price = 550 },
            { label = 'Planter with Dense Shrub', model = 'prop_plant_int_06b', price = 700 },
            { label = 'Boxwood Hedge Planter', model = 'prop_plant_int_06c', price = 500 },
            { label = 'Indoor Plant (White Pot, Small)', model = 'prop_pot_plant_01a', price = 200 },
            { label = 'Indoor Plant (Dark Pot, Spiked Leaves)', model = 'prop_pot_plant_01b', price = 280 },
            { label = 'Indoor Plant (Tall, Curved Leaves)', model = 'prop_pot_plant_01c', price = 290 },
            { label = 'Fan Palm (Short, Black Pot)', model = 'prop_pot_plant_01d', price = 340 },
            { label = 'Fan Palm (Small, Gray Pot)', model = 'prop_pot_plant_01e', price = 300 },
            { label = 'Round Pot with Shrub (Stone)', model = 'prop_pot_plant_02a', price = 390 },
            { label = 'Planter with Flowers (Round, Tall)', model = 'prop_pot_plant_02b', price = 450 },
            { label = 'Planter with Pink Flowers (Round)', model = 'prop_pot_plant_02c', price = 450 },
            { label = 'Small Shrub in Round Pot', model = 'prop_pot_plant_02d', price = 350 },
            { label = 'Cone Topiary (White Pot)', model = 'prop_pot_plant_03a', price = 550 },
            { label = 'Shrub in Terracotta Pot', model = 'prop_pot_plant_03b', price = 480 },
            { label = 'Topiary (Pedestal Pot)', model = 'prop_pot_plant_03c', price = 430 },
            { label = 'Window Box Planter (Shrubs)', model = 'prop_pot_plant_04a', price = 365 },
            { label = 'Ornamental Plant (Yellow Pot)', model = 'prop_pot_plant_04b', price = 620 },
            { label = 'Ornamental Palm (Wide Pot)', model = 'prop_pot_plant_04c', price = 500 },
            { label = 'Long Thin Plant (White Base)', model = 'prop_pot_plant_05a', price = 220 },
            { label = 'Tall Cone Topiary (Gray Pot)', model = 'prop_pot_plant_05b', price = 530 },
            { label = 'Rectangular Marble Planter', model = 'prop_pot_plant_05c', price = 850 },
            { label = 'Round Stone Planter (Decorative)', model = 'prop_pot_plant_05d', price = 800 },
            { label = 'Stone Planter with Flowers', model = 'prop_pot_plant_05d_l1', price = 900 },
            { label = 'Hanging Fern Basket', model = 'prop_pot_plant_6a', price = 600 },
            { label = 'Small Bush in Ceramic Pot', model = 'prop_pot_plant_bh1', price = 330 },
            { label = 'Indoor Tall Plant (Minimalist)', model = 'prop_pot_plant_inter_03a', price = 360 },
            { label = 'Bushy Olive Shrub', model = 'prop_rus_olive', price = 430 },
            { label = 'Olive Tree (Large)', model = 'prop_rus_olive_l2', price = 800 },
            { label = 'Winter Olive Tree', model = 'prop_rus_olive_wint', price = 2200 },
            { label = 'Young Sapling Tree (Thin)', model = 'prop_sapling_break_01', price = 2100 },
            { label = 'Tall Sapling (Pointed)', model = 'prop_sapling_break_02', price = 2400 },
            { label = 'Flowers in Vase (Yellow)', model = 'v_ret_ps_flowers_01', price = 550 },
            { label = 'Flowers in Vase (Pink)', model = 'v_ret_ps_flowers_02', price = 500 },
        }
    },
    {
        id = 'decorations',
        label = 'Decorations & Details',
        icon = 'star',
        items = {
            { label = 'Wool Rug', model = 'apa_mp_h_acc_rugwooll_03', price = 450 },
            { label = 'Glass Display Pedestal', model = 'h4_prop_h4_glass_disp_01a', price = 1000 },
            { label = 'Dog Sign', model = 'prop_beware_dog_sign', price = 130 },
            { label = 'FIB Ashtray (Wall-Mounted)', model = 'prop_fib_ashtray_01', price = 25 },
            { label = 'Magazine Holder (Black)', model = 'prop_folder_02', price = 40 },
            { label = 'Wall Clock (White Face)', model = 'prop_game_clock_01', price = 100 },
            { label = 'Wall Clock (Black Face)', model = 'prop_game_clock_02', price = 120 },
            { label = 'Gravestone Statue (Angel Wings)', model = 'prop_gravestones_10a', price = 6000 },
            { label = 'Wall Cabinet (White, Small)', model = 'prop_handdry_01', price = 60 },
            { label = 'Stacked Document Trays (3x)', model = 'prop_inout_tray_02', price = 80 },
            { label = 'Black Garbage Bag (Full)', model = 'prop_rub_binbag_01', price = 10 },
            { label = 'Cleaning Sponge (Yellow)', model = 'prop_sponge_01', price = 20 },
            { label = 'Wall Clock (Sport Design)', model = 'prop_sports_clock_01', price = 130 },
            { label = 'Dog Bed (Grey)', model = 'sf_prop_sf_bed_dog_01a', price = 340 },
            { label = 'Dog Bed (Brown)', model = 'sf_prop_sf_bed_dog_01b', price = 330 },
            { label = 'Stack of Folders', model = 'v_res_paperfolders', price = 45 },
            { label = 'Perfume Bottle (Green)', model = 'v_res_r_perfume', price = 300 },
            { label = 'Wall Mirror (Gold Frame)', model = 'v_ret_mirror', price = 300 },
            { label = 'Toilet Paper Roll (Dark Texture)', model = 'v_ret_ta_paproll', price = 15 },
        }
    },
    {
        id = 'outdoor',
        label = 'Outdoor',
        icon = 'tree',
        items = {
            { label = 'BBQ', model = 'prop_bbq_1', price = 4800 },
            { label = 'Brick BBQ', model = 'prop_bbq_3', price = 5500 },
            { label = 'BBQ', model = 'prop_bbq_4', price = 900 },
            { label = 'BBQ', model = 'prop_bbq_5', price = 4500 },
            { label = 'Beach Campfire', model = 'prop_beach_fire', price = 300 },
            { label = 'Inflatable Pool Mattress', model = 'prop_beach_lilo_02', price = 240 },
            { label = 'Beach Parasol (Striped)', model = 'prop_beach_parasol_05', price = 400 },
            { label = 'Inflatable Swim Ring', model = 'prop_beach_ring_01', price = 200 },
            { label = 'Sandcastle', model = 'prop_beach_sandcas_04', price = 100 },
            { label = 'Metal Bench (Classic)', model = 'prop_bench_01a', price = 440 },
            { label = 'Metal Bench (Classic Blue)', model = 'prop_bench_01b', price = 460 },
            { label = 'Metal Bench (Green)', model = 'prop_bench_01c', price = 420 },
            { label = 'Metal Park Bench', model = 'prop_bench_02', price = 400 },
            { label = 'Industrial Metal Bench', model = 'prop_bench_03', price = 550 },
            { label = 'Wooden Bench', model = 'prop_bench_04', price = 850 },
            { label = 'Garden Bench (Slatted)', model = 'prop_bench_06', price = 600 },
            { label = 'Minimalist Park Bench', model = 'prop_bench_07', price = 500 },
            { label = 'Wooden Bench (Concrete legs)', model = 'prop_bench_08', price = 950 },
            { label = 'Bus Stop Bench', model = 'prop_bench_10', price = 400 },
            { label = 'Heavy Duty Bench', model = 'prop_bench_11', price = 500 },
            { label = 'Standard Trash Can', model = 'prop_bin_01a', price = 180 },
            { label = 'Trash Can (Blue)', model = 'prop_bin_02a', price = 120 },
            { label = 'Black Garbage Bin', model = 'prop_bin_03a', price = 10 },
            { label = 'Commercial Trash Bin (Closed)', model = 'prop_bin_04a', price = 300 },
            { label = 'Dumpster Bin (Blue)', model = 'prop_bin_05a', price = 280 },
            { label = 'Industrial Garbage Bin', model = 'prop_bin_06a', price = 180 },
            { label = 'Metal Trash Can (Empty)', model = 'prop_bin_07a', price = 300 },
            { label = 'Metal Trash Can (Closed)', model = 'prop_bin_07b', price = 300 },
            { label = 'Trash Can (Half-closed)', model = 'prop_bin_07c', price = 300 },
            { label = 'Graffiti Trash Can', model = 'prop_bin_07d', price = 200 },
            { label = 'Tall Public Bin', model = 'prop_bin_08a', price = 300 },
            { label = 'Tall Public Bin (Open)', model = 'prop_bin_08open', price = 300 },
            { label = 'Tall Trash Can (With Lid)', model = 'prop_bin_09a', price = 80 },
            { label = 'Bin (Dark Blue)', model = 'prop_bin_10a', price = 200 },
            { label = 'Bin (Red)', model = 'prop_bin_10b', price = 200 },
            { label = 'Street Bin (Yellow)', model = 'prop_bin_11a', price = 160 },
            { label = 'Street Bin (Green)', model = 'prop_bin_11b', price = 160 },
            { label = 'City Trash Can (Metal Base)', model = 'prop_bin_12a', price = 400 },
            { label = 'Del Perro Promenade Trash Bin', model = 'prop_bin_delpiero', price = 500 },
            { label = 'Del Perro Trash Bin (Decorative)', model = 'prop_bin_delpiero_b', price = 400 },
            { label = 'Wooden Doghouse', model = 'prop_doghouse_01', price = 750 },
            { label = 'Pink Flamingo (Lawn Ornament)', model = 'prop_flamingo', price = 400 },
            { label = 'Stone Fountain (Round)', model = 'prop_fountain2', price = 8500 },
            { label = 'Gazebo Tent (Open Sides)', model = 'prop_gazebo_01', price = 3800 },
            { label = 'Gazebo Tent (Side Walls)', model = 'prop_gazebo_02', price = 3800 },
            { label = 'Gazebo Tent (No Walls)', model = 'prop_gazebo_03', price = 3800 },
            { label = 'Garden Gnome (Smiling)', model = 'prop_gnome1', price = 300 },
            { label = 'Garden Gnome (Lantern)', model = 'prop_gnome2', price = 300 },
            { label = 'Garden Gnome (Digging)', model = 'prop_gnome3', price = 300 },
            { label = 'Wooden Hot Tub (Lid Closed)', model = 'prop_hottub2', price = 9000 },
            { label = 'Inflatable Kayak (Yellow)', model = 'prop_kayak_01b', price = 400 },
            { label = 'Parasol (Light Gray Fabric)', model = 'prop_parasol_01', price = 800 },
            { label = 'Parasol (Dark Base, Lod Style)', model = 'prop_parasol_01b_lod', price = 800 },
            { label = 'Parasol (Dark Blue Fabric)', model = 'prop_parasol_01_b', price = 800 },
            { label = 'Parasol (Brown, Weathered)', model = 'prop_parasol_01_c', price = 600 },
            { label = 'Parasol (Light Gray, Lod Style)', model = 'prop_parasol_01_lod', price = 850 },
            { label = 'Parasol (White, Tilted)', model = 'prop_parasol_02', price = 800 },
            { label = 'Parasol (Green Fabric)', model = 'prop_parasol_02_b', price = 800 },
            { label = 'Parasol (Dark Blue Fabric)', model = 'prop_parasol_02_c', price = 800 },
            { label = 'Parasol (Blue, Wide)', model = 'prop_parasol_03', price = 600 },
            { label = 'Parasol (Yellow with Branding)', model = 'prop_parasol_03_b', price = 600 },
            { label = 'Parasol (Green with Branding)', model = 'prop_parasol_03_c', price = 600 },
            { label = 'Parasol (Red/White Sprunk Branding)', model = 'prop_parasol_04c', price = 600 },
            { label = 'Parasol (Green/White Sprunk Branding)', model = 'prop_parasol_04d', price = 600 },
            { label = 'Recycle Bin (Blue)', model = 'prop_recyclebin_01a', price = 300 },
            { label = 'Recycle Bin (Red - Mixed Plastic)', model = 'prop_recyclebin_02a', price = 300 },
            { label = 'Recycle Bin (Yellow - Cans Only)', model = 'prop_recyclebin_02b', price = 300 },
            { label = 'Classic Bin', model = 'prop_recyclebin_03_a', price = 200 },
            { label = 'Garden Rake (Green)', model = 'prop_shrub_rake', price = 90 },
            { label = 'Camping Tent (Folded)', model = 'prop_skid_tent_01', price = 800 },
            { label = 'Butterfly Decoration (Purple)', model = 'prop_stickbfly', price = 90 },
            { label = 'Bird Decoration (Small, Brown)', model = 'prop_stickhbird', price = 90 },
            { label = 'Mushroom Decoration (Purple Glow)', model = 'prop_stoneshroom1', price = 120 },
            { label = 'Mushroom Decoration (Blue Glow)', model = 'prop_stoneshroom2', price = 120 },
            { label = 'Classic Bin (Mesh)', model = 'zprop_bin_01a_old', price = 280 },
        }
    },
    {
        id = 'recreation',
        label = 'Recreation',
        icon = 'gamepad',
        items = {
            { label = 'Air Hockey Table', model = 'prop_airhockey_01', price = 0 },
            { label = 'Dumbbell 30kg', model = 'prop_barbell_01', price = 180 },
            { label = 'Barbell 110kg', model = 'prop_barbell_02', price = 770 },
            { label = 'Barbell 100kg', model = 'prop_barbell_100kg', price = 700 },
            { label = 'Barbell 10kg', model = 'prop_barbell_10kg', price = 200 },
            { label = 'Barbell 20kg', model = 'prop_barbell_20kg', price = 260 },
            { label = 'Barbell 30kg', model = 'prop_barbell_30kg', price = 330 },
            { label = 'Barbell 40kg', model = 'prop_barbell_40kg', price = 390 },
            { label = 'Barbell 50kg', model = 'prop_barbell_50kg', price = 440 },
            { label = 'Barbell 60kg', model = 'prop_barbell_60kg', price = 510 },
            { label = 'Barbell 80kg', model = 'prop_barbell_80kg', price = 600 },
            { label = 'Basketball Hoop', model = 'prop_basketball_net', price = 1850 },
            { label = 'Dartboard (Wood Backing)', model = 'prop_dart_bd_01', price = 400 },
            { label = 'Dartboard with Cabinet', model = 'prop_dart_bd_cab_01', price = 550 },
            { label = 'Exercise Bike (Stationary)', model = 'prop_exer_bike_01', price = 1600 },
            { label = 'Workout Bench (Flat)', model = 'prop_muscle_bench_01', price = 600 },
            { label = 'Workout Bench (Inclined)', model = 'prop_muscle_bench_03', price = 1200 },
            { label = 'Workout Machine (Arms & Pull)', model = 'prop_muscle_bench_05', price = 1500 },
            { label = 'Modern Pool Table (Gray Trim)', model = 'prop_pooltable_02', price = 3300 },
            { label = 'Pool Table (Purple)', model = 'prop_pooltable_3b', price = 3600 },
            { label = 'Punching Bag (Hanging)', model = 'prop_punch_bag_l', price = 1800 },
            { label = 'Speedball Lamp (Modern)', model = 'prop_speedball_01', price = 1400 },
            { label = 'Weight Bench (Barbell)', model = 'prop_weight_bench_02', price = 1900 },
            { label = 'Weight Rack (Dumbbells)', model = 'prop_weight_rack_02', price = 2400 },
            { label = 'Squat Rack (Weights)', model = 'prop_weight_squat', price = 1100 },
            { label = 'Mop', model = 'm23_2_prop_m32_bucket_mop_01b', price = 200 },
            { label = 'Lawn Mower', model = 'prop_lawnmower_01', price = 600 },
        }
    },
}
