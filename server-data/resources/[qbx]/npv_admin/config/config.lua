Config = {}

-- Command and keybind that open the admin menu.
Config.Command = 'admin'
Config.OpenKey = 'F10' -- RegisterKeyMapping default; players can rebind in GTA settings.

-- Keybind that toggles the DM tool (staff only).
Config.DmKey = 'L'
Config.DmKeyLabel = 'L'

-- Discord webhook for audit logs. Server-only, never sent to the NUI. Leave empty to disable.
Config.Webhook = ''

-- Delete audit rows older than this many days on startup (0 = keep forever).
Config.AuditRetentionDays = 90

-- Hard limits protecting the server.
Config.Limits = {
    ObjectsPerScenario = 600,
    PeoplePerScenario = 60,
    WorldRenderLoad = 2200, -- total entities drawn by all live scenarios
    ScenariosPerOwner = 25,
    ScriptBlocksPerScript = 200,
    ScriptDepth = 6,
    MaxWaitMs = 60000,
    MaxNotifyChars = 200,
    MaxCoord = 8000.0,
    ActionsPerMinute = 90, -- rate limit per staff member for run/rpc calls
}

-- Kick "kidnap" style: a guard drags the player into a van before they are dropped.
-- The server drops them after this many ms even if the scene never reports back.
Config.KickSceneTimeout = 20000 -- includes the few seconds spent finding an outdoor spot
Config.KickSceneGuard = 's_m_m_armoured_02'
Config.KickSceneVan = 'burrito'

-- Reach of "revive in range" and DM actions defaults, in metres.
Config.ReviveRange = 10.0
Config.DefaultActionRange = 30.0

-- Distance (m) a player has to be within for server-validated triggers/dialogue to count.
Config.TriggerTolerance = 6.0
Config.TalkDistance = 2.5

-- Event fired on a target client to revive them. Adjust to match your ambulance resource.
-- The client falls back to a plain native resurrect when the event does nothing.
Config.ReviveEvent = 'qbx_medical:client:playerRevived'

-- Inventory resource used by give/take item blocks ('ox_inventory' or '' to disable).
Config.Inventory = 'ox_inventory'

-- Police alert dispatch. Return nothing; adapt to your dispatch resource.
-- Called server-side with (coords, message).
Config.PoliceAlert = function(coords, message)
    -- Example for ps-dispatch:
    -- exports['ps-dispatch']:CustomAlert({ coords = coords, message = message, dispatchCode = '10-90', description = message, radius = 0, sprite = 161, color = 1, scale = 1.0, length = 3 })
    TriggerEvent('npv_admin:policeAlert', coords, message)
end

-- Models that may be placed as NPC/people. Catalogue entries; hash is validated server-side too.
Config.NpcCatalog = {
    { id = 'mp_m_shopkeep_01', label = 'Shop Clerk', group = 'Civilians' },
    { id = 'a_m_y_business_01', label = 'Business Man', group = 'Civilians' },
    { id = 'a_f_y_business_01', label = 'Business Woman', group = 'Civilians' },
    { id = 'mp_m_freemode_01', label = 'MP Male', group = 'Freemode' },
    { id = 'mp_f_freemode_01', label = 'MP Female', group = 'Freemode' },
    { id = 'a_f_m_fatwhite_01', label = 'Casual Woman', group = 'Civilians' },
    { id = 's_m_y_cop_01', label = 'Cop', group = 'Law' },
    { id = 's_m_y_sheriff_01', label = 'Sheriff', group = 'Law' },
    { id = 's_m_y_swat_01', label = 'SWAT', group = 'Law' },
    { id = 'g_m_y_ballaeast_01', label = 'Ballas', group = 'Gangs' },
    { id = 'g_m_y_famca_01', label = 'Families', group = 'Gangs' },
    { id = 'g_m_y_mexgoon_01', label = 'Vagos', group = 'Gangs' },
    { id = 'g_m_y_korean_01', label = 'Korean Gang', group = 'Gangs' },
    { id = 'g_m_m_armboss_01', label = 'Armenian Boss', group = 'Gangs' },
    { id = 'g_m_m_armgoon_01', label = 'Armenian Goon', group = 'Gangs' },
    { id = 'g_m_y_salvagoon_01', label = 'Salvadoran', group = 'Gangs' },
    { id = 'g_m_m_chigoon_01', label = 'Triad', group = 'Gangs' },
    { id = 'g_m_m_mexboss_01', label = 'Cartel Boss', group = 'Gangs' },
    { id = 'g_m_y_mexgoon_02', label = 'Cartel', group = 'Gangs' },
    { id = 'a_c_shepherd', label = 'Shepherd Dog', group = 'Animals', animal = true },
    { id = 'a_c_rottweiler', label = 'Rottweiler', group = 'Animals', animal = true },
    { id = 'a_c_husky', label = 'Husky', group = 'Animals', animal = true },
    { id = 'a_c_cow', label = 'Cow', group = 'Animals', animal = true },
    { id = 'a_c_pig', label = 'Pig', group = 'Animals', animal = true },
}

-- Props offered in the catalogue. Any valid prop model can also be typed in manually.
Config.ObjectCatalog = {
    { id = 'prop_ld_int_safe_01', label = 'Floor Safe', group = 'Safes' },
    { id = 'prop_idol_case_01', label = 'Idol Case', group = 'Safes' },
    { id = 'prop_ld_crate_01', label = 'Closed Crate', group = 'Crates' },
    { id = 'prop_mil_crate_01', label = 'Military Crate', group = 'Crates' },
    { id = 'prop_box_wood02a_pu', label = 'Wooden Crate', group = 'Crates' },
    { id = 'prop_boxpile_01a', label = 'Box Pile', group = 'Crates' },
    { id = 'prop_box_guncase_01a', label = 'Gun Case', group = 'Cases' },
    { id = 'prop_cash_case_01', label = 'Cash Case', group = 'Cases' },
    { id = 'prop_ld_case_01', label = 'Briefcase', group = 'Cases' },
    { id = 'prop_ld_suitcase_01', label = 'Suitcase', group = 'Cases' },
    { id = 'prop_tool_box_01', label = 'Tool Box', group = 'Tools' },
    { id = 'prop_tool_box_04', label = 'Tool Chest', group = 'Tools' },
    { id = 'prop_generator_03b', label = 'Generator', group = 'Tools' },
    { id = 'prop_fridge_03', label = 'Fridge', group = 'Furniture' },
    { id = 'prop_table_03', label = 'Table', group = 'Furniture' },
    { id = 'prop_chair_01a', label = 'Chair', group = 'Furniture' },
    { id = 'prop_barrier_work06a', label = 'Roadwork Barrier', group = 'Street' },
    { id = 'prop_barrel_01a', label = 'Barrel', group = 'Street' },
    { id = 'prop_bin_01a', label = 'Bin', group = 'Street' },
    { id = 'prop_laptop_01a', label = 'Laptop', group = 'Electronics' },
    { id = 'prop_money_bag_01', label = 'Money Bag', group = 'Loot' },
    { id = 'prop_drug_package', label = 'Drug Package', group = 'Loot' },
    { id = 'prop_weed_pallet', label = 'Weed Pallet', group = 'Loot' },
    { id = 'prop_coke_block_01', label = 'Coke Block', group = 'Loot' },
    { id = 'prop_ld_bomb_01', label = 'Bomb', group = 'Loot' },
}

-- Animations offered in the NPC animation panel (dictionary/name pairs are validated client side).
-- `scenario` entries use TaskStartScenarioInPlace.
Config.NpcAnimations = {
    { group = 'Idle', id = 'impatient', label = 'Impatient', scenario = 'WORLD_HUMAN_STAND_IMPATIENT' },
    { group = 'Idle', id = 'phone', label = 'On Phone', scenario = 'WORLD_HUMAN_STAND_MOBILE' },
    { group = 'Idle', id = 'hangout', label = 'Hang Out', scenario = 'WORLD_HUMAN_HANG_OUT_STREET' },
    { group = 'Idle', id = 'map', label = 'Reading Map', scenario = 'WORLD_HUMAN_TOURIST_MAP' },
    { group = 'Idle', id = 'binoculars', label = 'Binoculars', scenario = 'WORLD_HUMAN_BINOCULARS' },
    { group = 'Idle', id = 'leaning', label = 'Leaning', scenario = 'WORLD_HUMAN_LEANING' },
    { group = 'Idle', id = 'armscrossed', label = 'Arms Crossed', scenario = 'WORLD_HUMAN_GUARD_STAND' },
    { group = 'Leisure', id = 'smoking', label = 'Smoking', scenario = 'WORLD_HUMAN_SMOKING' },
    { group = 'Leisure', id = 'joint', label = 'Smoking (Joint)', scenario = 'WORLD_HUMAN_SMOKING_POT' },
    { group = 'Leisure', id = 'drinking', label = 'Drinking', scenario = 'WORLD_HUMAN_DRINKING' },
    { group = 'Leisure', id = 'coffee', label = 'Coffee', scenario = 'WORLD_HUMAN_AA_COFFEE' },
    { group = 'Leisure', id = 'partying', label = 'Partying', scenario = 'WORLD_HUMAN_PARTYING' },
    { group = 'Leisure', id = 'cheering', label = 'Cheering', scenario = 'WORLD_HUMAN_CHEERING' },
    { group = 'Leisure', id = 'muscle', label = 'Muscle Flex', scenario = 'WORLD_HUMAN_MUSCLE_FLEX' },
    { group = 'Leisure', id = 'fishing', label = 'Fishing', scenario = 'WORLD_HUMAN_STAND_FISHING' },
    { group = 'Leisure', id = 'sitting', label = 'Sitting', scenario = 'PROP_HUMAN_SEAT_BENCH' },
    { group = 'Work', id = 'clipboard', label = 'Clipboard', scenario = 'WORLD_HUMAN_CLIPBOARD' },
    { group = 'Work', id = 'hammering', label = 'Hammering', scenario = 'WORLD_HUMAN_HAMMERING' },
    { group = 'Work', id = 'welding', label = 'Welding', scenario = 'WORLD_HUMAN_WELDING' },
    { group = 'Work', id = 'sweeping', label = 'Sweeping', scenario = 'WORLD_HUMAN_JANITOR' },
    { group = 'Work', id = 'cleaning', label = 'Cleaning', scenario = 'WORLD_HUMAN_MAID_CLEAN' },
    { group = 'Guard', id = 'guard', label = 'Guard (Arms Crossed)', scenario = 'WORLD_HUMAN_GUARD_STAND' },
    { group = 'Guard', id = 'copidle', label = 'Cop Idle', scenario = 'WORLD_HUMAN_COP_IDLES' },
}

-- "Who sees this reply" options in the dialogue editor. `jobs` are QBox job names; an empty
-- reply role list means everyone sees the reply.
Config.DialogueRoles = {
    { id = 'civilian', label = 'Civilians', jobs = { 'unemployed' } },
    { id = 'police', label = 'Police', jobs = { 'police', 'sheriff' } },
    { id = 'ems', label = 'EMS', jobs = { 'ambulance' } },
    { id = 'mechanic', label = 'Mechanic', jobs = { 'mechanic' } },
    { id = 'judge', label = 'Judge', jobs = { 'judge' } },
}

-- Dialogue / interaction prompt key (control id 38 = E).
Config.InteractControl = 38
Config.InteractKeyLabel = 'E'

-- Use the `interact` resource for "use" prompts and NPC "talk" prompts when it is running.
-- Falls back to a built-in help-text prompt (Config.InteractControl) when it is not.
Config.UseInteractResource = true
Config.InteractDistance = 8.0   -- how far away the prompt dot is shown
Config.InteractUseDistance = 1.5 -- how close the player must be to use it
Config.InteractTalkDistance = 2.0 -- same, for talking to an NPC (the prompt sits on the ped's body)

-- UI sounds (GTA frontend sounds played through PlaySoundFrontend).
-- Each entry is { soundName, soundSet }. Set enabled = false to silence the menus.
Config.Sounds = {
    enabled = true,
    hover = { 'NAV_UP_DOWN', 'HUD_FRONTEND_DEFAULT_SOUNDSET' },
    click = { 'SELECT', 'HUD_FRONTEND_DEFAULT_SOUNDSET' },
    enter = { 'CONTINUE', 'HUD_FRONTEND_DEFAULT_SOUNDSET' },
    back  = { 'BACK', 'HUD_FRONTEND_DEFAULT_SOUNDSET' },
}

-- Blur the game behind the menus with GTA's own screen blur (CSS backdrop blur renders black in NUI).
Config.ScreenBlur = true

-- Radial menu integration. The "DM Tool" command in the admin menu adds/removes a button in this
-- radial menu; pressing that button opens the DM tool. Uses exports[resource]:AddOption/RemoveOption.
Config.Radial = {
    resource = 'codera-radialmenu',
    title = 'DM Tool',
    icon = 'boxes', -- Font Awesome 5 name used by the radial menu
    -- If the radial menu resource is not running, open the DM tool directly instead.
    fallbackOpenDirectly = true,
}

-- Weather / time sync. The admin menu's "Set Weather" and "Set Time" write through these two
-- functions (server side). The defaults match Renewed-Weathersync (also fine for anything that
-- provides qb-weathersync's GlobalState format). Replace them if you run a different resource.
local SNOWY = { SNOW = true, SNOWLIGHT = true, BLIZZARD = true, XMAS = true }
Config.WeatherSync = {
    setWeather = function(weather)
        GlobalState.weather = {
            weather = weather,
            time = 9999999999, -- hold this weather until changed again
            hasSnow = SNOWY[weather] or nil,
        }
    end,
    setTime = function(hour, minute)
        GlobalState.currentTime = { hour = hour, minute = minute }
    end,
}

-- Teleport locations offered by the "Teleport To Location" command.
Config.Locations = {
    { label = 'Pillbox Hospital', coords = vec4(308.7, -595.0, 43.2, 205.9) },
    { label = 'Legion Square',    coords = vec4(195.8, -933.6, 30.7, 358.0) },
    { label = 'Sandy Shores',     coords = vec4(1961.7, 3740.5, 32.3, 305.0) },
    { label = 'Paleto Bay PD',    coords = vec4(-448.6, 6012.0, 31.7, 225.0) },
    { label = 'Airport',          coords = vec4(-1034.6, -2733.6, 20.2, 240.0) },
}

-- Account types the money commands may touch, and the largest single amount.
Config.MoneyTypes = { 'cash', 'bank', 'crypto' }
Config.MaxMoneyPerCommand = 10000000

-- Event triggered on a target to toggle cuffs (set to '' to disable the command).
Config.CuffEvent = 'police:client:GetCuffed'

-- Resources that "Resource Control" refuses to stop/restart (starting/ensuring is still fine).
Config.ProtectedResources = { 'npv_admin', 'oxmysql', 'ox_lib', 'qbx_core', 'monitor', 'ox_inventory' }

-- Stash used by "Open Stash".
Config.StashSlots = 500
Config.StashMaxWeight = 4000000

-- Sounds the DM actions panel can play at a spot: key = { soundName, soundSet }.
Config.DmSounds = {
    alarm = { "Burglar_Bell", "Generic_Alarms" },
    beep = { "Beep_Red", "DLC_HEIST_HACKING_SNAKE_SOUNDS" },
    ding = { "CHECKPOINT_PERFECT", "HUD_MINI_GAME_SOUNDSET" },
    wasted = { "Bed", "WastedSounds" },
}

-- Minigames offered by the Hack script block (the dropdown). `skill` is the built-in ox_lib skill check.
-- The others are games from the cortex-minigames resource (ids from its shared/catalog.json); they are
-- started as server-issued attempts, so the server decides the result. If cortex-minigames is not
-- running, a hack that picked one of them falls back to the skill check.
Config.HackGames = {
    { id = 'skill', label = 'Skill check (ox_lib)' },
    { id = 'timing', label = 'Timing Check' },
    { id = 'sequence', label = 'Sequence Recall' },
    { id = 'pressure', label = 'Pressure Control' },
    { id = 'signal_lock', label = 'Signal Lock' },
    { id = 'circuit_route', label = 'Circuit Routing' },
    { id = 'pin_tension', label = 'Pin & Tension (lockpick)' },
    { id = 'wave_match', label = 'Wave Match' },
    { id = 'trace_path', label = 'Trace Path' },
    { id = 'pattern_rebuild', label = 'Pattern Rebuild' },
    { id = 'pulse_sync', label = 'Pulse Sync' },
    { id = 'mash', label = 'Mash' },
    { id = 'trace', label = 'Trace Sweep' },
}
Config.HackProvider = 'cortex-minigames'
Config.HackTimeoutMs = 120000 -- safety net if the provider never reports back

-- ---------------------------------------------------------------------------------------------------------
-- Trolleys: heist trolleys players can grab from (cash, gold, diamonds, cocaine...).
-- Every trolley object in the DM tool starts from one of these presets and can be changed per object
-- (full/empty model, stacks, seconds per grab and the reward) in its properties panel.
--
--   stacks    how many times it can be grabbed from before it is empty
--   seconds   how long one grab takes
--   reward    mode = 'money' pays reward.account (one of Config.MoneyTypes);
--             mode = 'item' gives reward.item through ox_inventory.
--             Each grab pays a random whole number between min and max (items: how many).
--   model     the full trolley; emptyModel replaces it when it runs out (nil = it just disappears)
--   anim      key into Config.TrolleyAnims
-- ---------------------------------------------------------------------------------------------------------
Config.Trolleys = {
    {
        id = 'cash', label = 'Cash trolley', prompt = 'Grab the cash',
        model = 'hei_prop_hei_cash_trolly_01', emptyModel = 'hei_prop_hei_cash_trolly_03',
        stacks = 8, seconds = 6.0, anim = 'cash',
        reward = { mode = 'money', account = 'cash', item = '', min = 1500, max = 3500 },
    },
    {
        id = 'gold', label = 'Gold trolley', prompt = 'Grab the gold',
        model = 'ch_prop_gold_trolly_01a', emptyModel = 'ch_prop_gold_trolly_01c',
        stacks = 6, seconds = 7.0, anim = 'gold',
        reward = { mode = 'item', account = 'cash', item = 'goldbar', min = 1, max = 3 },
    },
    {
        id = 'diamonds', label = 'Diamond trolley', prompt = 'Grab the diamonds',
        model = 'ch_prop_diamond_trolly_01a', emptyModel = 'ch_prop_diamond_trolly_01c',
        stacks = 6, seconds = 7.0, anim = 'gold',
        reward = { mode = 'item', account = 'cash', item = 'diamond', min = 1, max = 4 },
    },
    {
        id = 'cocaine', label = 'Cocaine trolley', prompt = 'Grab the cocaine',
        model = 'imp_prop_impexp_coke_trolly', emptyModel = nil,
        stacks = 5, seconds = 7.0, anim = 'gold',
        reward = { mode = 'item', account = 'cash', item = 'coke_brick', min = 1, max = 2 },
    },
}

-- Grab animations. enter -> grab (repeats once per stack) -> exit, played as a synchronised scene whose
-- origin is the trolley, so the player is positioned by the animation itself. `prop` is an optional clip
-- played on the trolley during the grab (the cash stacks disappearing).
Config.TrolleyAnims = {
    -- bag = clips for the duffel bag that plays along with the player (nil = hold a bag in the hand instead)
    cash = { dict = 'anim@heists@ornate_bank@grab_cash', enter = 'intro', grab = 'grab', exit = 'exit', prop = 'cart_cash_dissapear',
             bag = { enter = 'bag_intro', grab = 'bag_grab', exit = 'bag_exit' } },
    gold = { dict = 'anim@scripted@heist@ig1_table_grab@gold@male@', enter = 'enter', grab = 'grab', exit = 'exit', prop = nil, bag = nil },
}

-- The bag players carry while grabbing. `model` plays inside the animation; `handModel` is held in the right
-- hand when an animation has no bag clips (bone/offset/rotation are tweakable if it sits wrong).
Config.TrolleyBag = {
    enabled = true,
    model = 'hei_p_m_bag_var22_arm_s',
    handModel = 'prop_cs_heist_bag_02',
    bone = 57005, offset = vec3(0.12, 0.0, -0.02), rotation = vec3(0.0, 270.0, 0.0),
}

Config.TrolleyMaxDistance = 3.5     -- how close a player must stay to the trolley while grabbing (server checked)
Config.TrolleyTimeoutMs = 45000     -- a grab with no progress for this long frees the trolley for others

-- ---------------------------------------------------------------------------------------------------------
-- Locked doors (DM tool -> Place as -> Door). A door is a prop that stays shut until it is unlocked by
-- thermite, a hack, a script, or staff. Each placed door has its own copy of these settings.
--   thermite  item (consumed when planted; '' = none needed), burn = seconds it burns, game + difficulty = the
--             minigame to light it ('none' = no minigame)
--   hack      item (needed, not consumed; '' = none needed), game + difficulty (ids from Config.HackGames)
-- ---------------------------------------------------------------------------------------------------------
Config.Doors = {
    MaxDistance = 6.0,           -- how close a player must be (server checked)
    TimeoutMs = 90000,           -- an unfinished attempt frees the door for others after this long
    FailCooldownMs = 8000,       -- wait after a failed hack
    Thermite = { item = 'thermite', burn = 10, game = 'skill', difficulty = 3 },
    Hack = { item = '', game = 'skill', difficulty = 3 },
    -- Starting points in the catalogue. openAngle: how far the door swings (degrees). Each door also has a swing direction:
    -- toward the player who unlocked it (default), away from them, or fixed (the sign of openAngle).
    Presets = {
        { id = 'fleeca', label = 'Fleeca vault door', model = 'v_ilev_gb_vauldr', openAngle = -90 },
        { id = 'heistsec', label = 'Heist security door', model = 'hei_prop_heist_sec_door', openAngle = 90 },
        { id = 'pacific', label = 'Pacific vault door', model = 'v_ilev_bk_vaultdoor', openAngle = -90 },
        { id = 'vaultgate', label = 'Vault gate', model = 'v_ilev_cbankvaulgate01', openAngle = 90 },
        { id = 'prison', label = 'Prison gate', model = 'prop_gate_prison_01', openAngle = 90 },
        { id = 'cell', label = 'Cell gate', model = 'v_ilev_ph_cellgate', openAngle = 90 },
        { id = 'police', label = 'Police door', model = 'v_ilev_ph_gendoor002', openAngle = 90 },
    },
}
