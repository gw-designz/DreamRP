-- ────────────────────────────────────────────────────────────
-- Constants
-- ────────────────────────────────────────────────────────────
local OVERRIDES_FILE   = "editor-overrides.json"
local OVERRIDES_BACKUP = "editor-overrides.backup.json"
local RESOURCE_NAME    = GetCurrentResourceName()

-- All crime modules, in the order they appear across the editor API
local MODULE_KEYS = {
    "mugging", "mailboxes", "parkingMeters", "parcels",
    "pickPocketing", "smashnGrab", "vendingMachines",
    "tireSlash", "pedalBrick", "cashRegisters", "atmRobbery", "storeShelves",
}

-- ────────────────────────────────────────────────────────────
-- Startup guard: wait until eventName is available
-- ────────────────────────────────────────────────────────────
while not eventName do
    Wait(0)
end

-- ────────────────────────────────────────────────────────────
-- Utility: isSequentialArray(t)
-- Returns true only if t is a table whose keys are consecutive
-- integers 1..N (i.e. a pure array), with at least one element.
-- ────────────────────────────────────────────────────────────
function isSequentialArray(t)
    if type(t) ~= "table" then return false end
    local count = 0
    for _ in pairs(t) do
        count = count + 1
        if t[count] == nil then return false end
    end
    return count > 0
end

-- ────────────────────────────────────────────────────────────
-- Utility: deepMerge(target, source)
-- Recursively merges source into target (in place).
-- Arrays in source replace arrays in target wholesale.
-- Hash-tables in source are merged key-by-key into target.
-- Scalar values always overwrite.
-- ────────────────────────────────────────────────────────────
function deepMerge(target, source)
    for key, srcValue in pairs(source) do
        if type(srcValue) == "table" then
            if type(target[key]) == "table" then
                -- Both sides are tables; decide whether to recurse or skip
                if not isSequentialArray(srcValue) then
                    -- Hash-table: only recurse if source has any keys
                    if next(srcValue) ~= nil then
                        deepMerge(target[key], srcValue)
                    end
                end
                -- Sequential arrays in source are silently ignored here
                -- (they are handled by direct assignment in applyOverrides)
            end
        else
            target[key] = srcValue
        end
    end
    return target
end

-- ────────────────────────────────────────────────────────────
-- Utility: deepCopy(value)
-- Returns a full recursive copy of any value.
-- ────────────────────────────────────────────────────────────
function deepCopy(value)
    if type(value) ~= "table" then return value end
    local copy = {}
    for k, v in pairs(value) do
        copy[k] = deepCopy(v)
    end
    return copy
end

-- ────────────────────────────────────────────────────────────
-- Utility: clampNumber(value, min, max)
-- Returns value clamped to [min, max], or nil if not a number.
-- ────────────────────────────────────────────────────────────
function clampNumber(value, minVal, maxVal)
    if type(value) ~= "number" then return nil end
    if minVal and value < minVal then return minVal end
    if maxVal and maxVal < value then return maxVal end
    return value
end

-- ────────────────────────────────────────────────────────────
-- Utility: uniqueStringArray(t)
-- Returns a new array containing only unique, non-empty strings
-- from the input array (preserves order, drops duplicates).
-- ────────────────────────────────────────────────────────────
function uniqueStringArray(t)
    if type(t) ~= "table" then return {} end
    local seen   = {}
    local result = {}
    for _, v in ipairs(t) do
        if type(v) == "string" and v ~= "" and not seen[v] then
            seen[v]              = true
            result[#result + 1]  = v
        end
    end
    return result
end

-- ────────────────────────────────────────────────────────────
-- Utility: sanitizeLootTable(rawTable)
-- Validates and normalises a loot-table array.
-- Each entry must have a non-empty .name string; chance is
-- clamped 0-100; count, label, prop, and rot are passed through
-- if present and of correct types.
-- ────────────────────────────────────────────────────────────
function sanitizeLootTable(rawTable)
    if type(rawTable) ~= "table" then return {} end
    local result = {}

    for _, entry in ipairs(rawTable) do
        if type(entry) == "table" and type(entry.name) == "string" and entry.name ~= "" then
            local clean = {
                name   = entry.name,
                chance = clampNumber(entry.chance, 0, 100),
            }

            if entry.count then
                if type(entry.count) == "table" then
                    local minCount = clampNumber(entry.count[1], 0, 999999)
                    local maxCount = clampNumber(entry.count[2], 0, 999999)
                    clean.count = { minCount, maxCount }
                end
            end

            if entry.label then clean.label = tostring(entry.label) end
            if entry.prop  then clean.prop  = tostring(entry.prop)  end
            if entry.rot   then clean.rot   = entry.rot             end

            result[#result + 1] = clean
        end
    end

    return result
end

-- ────────────────────────────────────────────────────────────
-- File I/O: loadOverridesFile()
-- Reads and JSON-decodes editor-overrides.json.
-- Returns the decoded table, or nil on missing/invalid file.
-- ────────────────────────────────────────────────────────────
function loadOverridesFile()
    local raw = LoadResourceFile(RESOURCE_NAME, OVERRIDES_FILE)
    if not raw or raw == "" then return nil end

    local ok, decoded = pcall(json.decode, raw)
    if not ok then
        print("[bablo-pettycrimes] WARNING: Failed to parse editor overrides JSON")
        return nil
    end

    return decoded
end

-- ────────────────────────────────────────────────────────────
-- File I/O: saveOverridesFile(data)
-- Backs up the existing file, merges any existing keys into
-- data so nothing is lost, then writes data as pretty JSON.
-- ────────────────────────────────────────────────────────────
function saveOverridesFile(data)
    -- Back up whatever is currently on disk before overwriting
    local existing = LoadResourceFile(RESOURCE_NAME, OVERRIDES_FILE)
    if existing and existing ~= "" then
        SaveResourceFile(RESOURCE_NAME, OVERRIDES_BACKUP, existing, -1)

        -- Merge existing keys into data so we don't lose them
        local ok, existingDecoded = pcall(json.decode, existing)
        if ok and existingDecoded and type(existingDecoded) == "table" then
            for k, v in pairs(data) do
                existingDecoded[k] = v
            end
            data = existingDecoded
        end
    end

    local encoded = json.encode(data, { indent = true })
    if not encoded then
        print("[bablo-pettycrimes] ERROR: json.encode returned nil when saving overrides")
        return
    end

    local saved = SaveResourceFile(RESOURCE_NAME, OVERRIDES_FILE, encoded, -1)
    if not saved then
        print("[bablo-pettycrimes] ERROR: SaveResourceFile failed — ensure the data/ folder exists inside the resource")
    end
end

-- ────────────────────────────────────────────────────────────
-- applyOverrides(overrides)
-- Applies a decoded overrides table onto the live Config by
-- calling deepMerge on each recognised top-level module.
-- ────────────────────────────────────────────────────────────

-- Map of override key → live Config key (all identical here, kept explicit)
local CONFIG_SECTION_MAP = {
    Modules        = "Modules",
    Mugging        = "Mugging",
    Mailboxes      = "Mailboxes",
    ParkingMeters  = "ParkingMeters",
    Parcels        = "Parcels",
    PickPocketing  = "PickPocketing",
    SmashnGrab     = "SmashnGrab",
    AtmRobbery     = "AtmRobbery",
    VendingMachines= "VendingMachines",
    TireSlash      = "TireSlash",
    PedalBrick     = "PedalBrick",
    CashRegisters  = "CashRegisters",
    StoreShelves   = "StoreShelves",
    Minigames      = "Minigames",
}

function applyOverrides(overrides)
    if not overrides then return end

    for overrideKey, configKey in pairs(CONFIG_SECTION_MAP) do
        local overrideSection = overrides[overrideKey]
        if overrideSection and type(overrideSection) == "table" then
            deepMerge(Config[configKey], overrideSection)
        end
    end
end

-- ────────────────────────────────────────────────────────────
-- hasMissingDefaultKeys(existingOverrides, currentDefaults)
-- Returns true if currentDefaults contains any key (recursively)
-- that is absent from existingOverrides.  Used to detect when a
-- resource update added new config keys that need migration.
-- ────────────────────────────────────────────────────────────
function hasMissingDefaultKeys(existing, defaults)
    if not existing then return false end
    local changed = false

    for key, defaultValue in pairs(defaults) do
        if existing[key] == nil then
            existing[key] = deepCopy(defaultValue)
            changed = true
        else
            if type(defaultValue) == "table" and type(existing[key]) == "table" then
                if not isSequentialArray(defaultValue) and not isSequentialArray(existing[key]) then
                    if hasMissingDefaultKeys(existing[key], defaultValue) then
                        changed = true
                    end
                end
            end
        end
    end

    return changed
end

-- ────────────────────────────────────────────────────────────
-- buildCurrentConfigSnapshot()
-- Returns a deep copy of every live Config section the editor
-- cares about, with camelCase keys for the client UI.
-- ────────────────────────────────────────────────────────────
function buildCurrentConfigSnapshot()
    local snap = {
        version  = GetResourceMetadata(RESOURCE_NAME, "version", 0) or "0.0.0",
        modules  = deepCopy(Config.Modules),
        minigames = deepCopy(Config.Minigames),

        mugging = {
            PoliceRequired    = Config.Mugging.PoliceRequired,
            RetaliationChance = Config.Mugging.RetaliationChance,
            AlertChance       = Config.Mugging.AlertChance,
            RetaliationWeapons= deepCopy(Config.Mugging.RetaliationWeapons),
            ProgressTime      = deepCopy(Config.Mugging.ProgressTime),
            BlacklistedWeapons= deepCopy(Config.Mugging.BlacklistedWeapons),
            BlacklistedJobs   = deepCopy(Config.Mugging.BlacklistedJobs or {}),
            LootTables        = deepCopy(Config.Mugging.LootTables),
            Dispatch          = deepCopy(Config.Mugging.Dispatch),
        },

        mailboxes = {
            Models            = deepCopy(Config.Mailboxes.Models),
            PoliceRequired    = Config.Mailboxes.PoliceRequired,
            AlertChance       = Config.Mailboxes.AlertChance,
            Cooldown          = Config.Mailboxes.Cooldown,
            LockpickRoundsMin = Config.Mailboxes.LockpickRoundsMin  or 1,
            LockpickRoundsMax = Config.Mailboxes.LockpickRoundsMax  or 1,
            LockpickZones     = Config.Mailboxes.LockpickZones      or 4,
            LockpickSpeed     = Config.Mailboxes.LockpickSpeed      or 0.35,
            LockpickZoneSize  = Config.Mailboxes.LockpickZoneSize   or 0.08,
            StuckChance       = Config.Mailboxes.StuckChance        or 0,
            BlacklistedJobs   = deepCopy(Config.Mailboxes.BlacklistedJobs or {}),
            Item              = deepCopy(Config.Mailboxes.Item),
            LootTables        = deepCopy(Config.Mailboxes.LootTables),
            Dispatch          = deepCopy(Config.Mailboxes.Dispatch),
        },

        parkingMeters = {
            Models            = deepCopy(Config.ParkingMeters.Models),
            PoliceRequired    = Config.ParkingMeters.PoliceRequired,
            AlertChance       = Config.ParkingMeters.AlertChance,
            Cooldown          = Config.ParkingMeters.Cooldown,
            LockpickRoundsMin = Config.ParkingMeters.LockpickRoundsMin or 1,
            LockpickRoundsMax = Config.ParkingMeters.LockpickRoundsMax or 1,
            LockpickZones     = Config.ParkingMeters.LockpickZones     or 3,
            LockpickSpeed     = Config.ParkingMeters.LockpickSpeed     or 0.3,
            LockpickZoneSize  = Config.ParkingMeters.LockpickZoneSize  or 0.08,
            BlacklistedJobs   = deepCopy(Config.ParkingMeters.BlacklistedJobs or {}),
            Item              = deepCopy(Config.ParkingMeters.Item),
            LootTables        = deepCopy(Config.ParkingMeters.LootTables),
            Dispatch          = deepCopy(Config.ParkingMeters.Dispatch),
        },

        parcels = {
            PoliceRequired       = Config.Parcels.PoliceRequired,
            AlertChance          = Config.Parcels.AlertChance,
            Chance               = Config.Parcels.Chance,
            Cooldown             = Config.Parcels.Cooldown,
            BombEnabled          = Config.Parcels.BombEnabled ~= false,
            ParcelBombProbability= Config.Parcels.ParcelBombProbability,
            BlacklistedJobs      = deepCopy(Config.Parcels.BlacklistedJobs or {}),
            LootTables           = deepCopy(Config.Parcels.LootTables),
            Dispatch             = deepCopy(Config.Parcels.Dispatch),
            BombDispatch         = deepCopy(Config.Parcels.BombDispatch),
        },

        pickPocketing = {
            PoliceRequired      = Config.PickPocketing.PoliceRequired,
            ProgressTime        = Config.PickPocketing.ProgressTime,
            Chance              = Config.PickPocketing.Chance,
            AlertChance         = Config.PickPocketing.AlertChance,
            MinigameSlots       = Config.PickPocketing.MinigameSlots       or 5,
            MinigameSpeedMin    = Config.PickPocketing.MinigameSpeedMin    or 0.28,
            MinigameSpeedMax    = Config.PickPocketing.MinigameSpeedMax    or 0.72,
            MinigameZoneWidth   = Config.PickPocketing.MinigameZoneWidth   or 0.22,
            MinigameUnlockChance= Config.PickPocketing.MinigameUnlockChance or 55,
            BlacklistedJobs     = deepCopy(Config.PickPocketing.BlacklistedJobs or {}),
            LootTables          = deepCopy(Config.PickPocketing.LootTables),
            Dispatch            = deepCopy(Config.PickPocketing.Dispatch),
        },

        smashnGrab = {
            PoliceRequired       = Config.SmashnGrab.PoliceRequired,
            AlertChance          = Config.SmashnGrab.AlertChance,
            ChanceToSpawn        = Config.SmashnGrab.ChanceToSpawn,
            Limit                = Config.SmashnGrab.Limit,
            MinVehicleDistance   = Config.SmashnGrab.MinVehicleDistance,
            QueueBatchSize       = Config.SmashnGrab.QueueBatchSize,
            UseBag               = Config.SmashnGrab.UseBag == true,
            ProgressTime         = deepCopy(Config.SmashnGrab.ProgressTime or { min = 5000, max = 10000 }),
            AllowedVehicleClasses= deepCopy(Config.SmashnGrab.AllowedVehicleClasses),
            BlacklistedModels    = deepCopy(Config.SmashnGrab.BlacklistedModels),
            BlacklistedJobs      = deepCopy(Config.SmashnGrab.BlacklistedJobs or {}),
            LootTables           = deepCopy(Config.SmashnGrab.LootTables),
            Dispatch             = deepCopy(Config.SmashnGrab.Dispatch),
        },

        vendingMachines = {
            Models          = deepCopy(Config.VendingMachines.Models),
            PoliceRequired  = Config.VendingMachines.PoliceRequired,
            AlertChance     = Config.VendingMachines.AlertChance,
            Cooldown        = Config.VendingMachines.Cooldown,
            BlacklistedJobs = deepCopy(Config.VendingMachines.BlacklistedJobs or {}),
            Item            = deepCopy(Config.VendingMachines.Item),
            LootTables      = deepCopy(Config.VendingMachines.LootTables),
            Dispatch        = deepCopy(Config.VendingMachines.Dispatch),
        },

        tireSlash = {
            PoliceRequired          = Config.TireSlash.PoliceRequired,
            AlertChance             = Config.TireSlash.AlertChance,
            AllowedWeapons          = deepCopy(Config.TireSlash.AllowedWeapons),
            BlacklistedVehicleClasses= deepCopy(Config.TireSlash.BlacklistedVehicleClasses),
            BlacklistedJobs         = deepCopy(Config.TireSlash.BlacklistedJobs or {}),
            MaxTiresPerVehicle      = Config.TireSlash.MaxTiresPerVehicle,
            AlertOnSlash            = Config.TireSlash.AlertOnSlash,
            Dispatch                = deepCopy(Config.TireSlash.Dispatch),
        },

        pedalBrick = {
            PoliceRequired          = Config.PedalBrick.PoliceRequired,
            AlertChance             = Config.PedalBrick.AlertChance,
            ItemName                = Config.PedalBrick.ItemName,
            AccelDuration           = Config.PedalBrick.AccelDuration,
            MaxSpeed                = Config.PedalBrick.MaxSpeed,
            AccelRate               = Config.PedalBrick.AccelRate,
            BreakOnCollision        = Config.PedalBrick.BreakOnCollision ~= false,
            BlacklistedVehicleClasses= deepCopy(Config.PedalBrick.BlacklistedVehicleClasses),
            BlacklistedJobs         = deepCopy(Config.PedalBrick.BlacklistedJobs or {}),
            Dispatch                = deepCopy(Config.PedalBrick.Dispatch),
            FireDispatch            = deepCopy(Config.PedalBrick.FireDispatch),
        },

        cashRegisters = {
            Models            = deepCopy(Config.CashRegisters.Models),
            PoliceRequired    = Config.CashRegisters.PoliceRequired,
            AlertChance       = Config.CashRegisters.AlertChance,
            Cooldown          = Config.CashRegisters.Cooldown,
            GrabTime          = Config.CashRegisters.GrabTime,
            LockpickRoundsMin = Config.CashRegisters.LockpickRoundsMin or 1,
            LockpickRoundsMax = Config.CashRegisters.LockpickRoundsMax or 1,
            LockpickZones     = Config.CashRegisters.LockpickZones,
            LockpickSpeed     = Config.CashRegisters.LockpickSpeed,
            LockpickZoneSize  = Config.CashRegisters.LockpickZoneSize,
            BlacklistedJobs   = deepCopy(Config.CashRegisters.BlacklistedJobs or {}),
            Item              = deepCopy(Config.CashRegisters.Item),
            LootTables        = deepCopy(Config.CashRegisters.LootTables),
            Dispatch          = deepCopy(Config.CashRegisters.Dispatch),
        },

        atmRobbery = {
            PoliceRequired          = Config.AtmRobbery.PoliceRequired,
            RequiredItem            = Config.AtmRobbery.RequiredItem,
            ItemBreakChanceOnRemove = Config.AtmRobbery.ItemBreakChanceOnRemove,
            AlertChance             = Config.AtmRobbery.AlertChance,
            GlobalCooldown          = Config.AtmRobbery.GlobalCooldown,
            PoolPerPedMin           = Config.AtmRobbery.PoolPerPedMin,
            PoolPerPedMax           = Config.AtmRobbery.PoolPerPedMax,
            DrainTime               = Config.AtmRobbery.DrainTime,
            MatchPairsPairs         = Config.AtmRobbery.MatchPairsPairs,
            MatchPairsTimeLimit     = Config.AtmRobbery.MatchPairsTimeLimit,
            MatchPairsGridCols      = Config.AtmRobbery.MatchPairsGridCols,
            MatchPairsGridRows      = Config.AtmRobbery.MatchPairsGridRows,
            MatchPairsTilesPerPair  = Config.AtmRobbery.MatchPairsTilesPerPair,
            MaxPeds                 = Config.AtmRobbery.MaxPeds,
            PedDelayMin             = Config.AtmRobbery.PedDelayMin,
            PedDelayMax             = Config.AtmRobbery.PedDelayMax,
            HackMaxDistance         = Config.AtmRobbery.HackMaxDistance,
            InteractDistance        = Config.AtmRobbery.InteractDistance,
            BlacklistedJobs         = deepCopy(Config.AtmRobbery.BlacklistedJobs or {}),
            AtmModels               = deepCopy(Config.AtmRobbery.AtmModels),
            PedModels               = deepCopy(Config.AtmRobbery.PedModels),
            Dispatch                = deepCopy(Config.AtmRobbery.Dispatch),
        },

        storeShelves = {
            Models          = deepCopy(Config.StoreShelves.Models),
            PoliceRequired  = Config.StoreShelves.PoliceRequired,
            AlertChance     = Config.StoreShelves.AlertChance,
            Cooldown        = Config.StoreShelves.Cooldown,
            ProgressTime    = Config.StoreShelves.ProgressTime,
            EmptyChance     = Config.StoreShelves.EmptyChance,
            BlacklistedJobs = deepCopy(Config.StoreShelves.BlacklistedJobs or {}),
            LootTables      = deepCopy(Config.StoreShelves.LootTables),
            Dispatch        = deepCopy(Config.StoreShelves.Dispatch),
        },
    }
    return snap
end

-- ────────────────────────────────────────────────────────────
-- applyIncomingEdits(edits)
-- Takes a validated edits table from the client, merges it into
-- Config, and returns a changelog table (for saving to disk).
-- ────────────────────────────────────────────────────────────
function applyIncomingEdits(edits)
    local changelog = {}

    -- Helper: merge one section and record what changed
    local function applySection(editKey, configKey)
        local section = edits[editKey]
        if not section then return end
        changelog[configKey] = section
        deepMerge(Config[configKey], section)
    end

    -- Modules and Minigames need Config.X.Y-level assignment, not deepMerge,
    -- because deepMerge would touch sub-keys; the editor sends the full table.
    if edits.modules then
        changelog.Modules    = edits.modules
        Config.Modules       = deepMerge(Config.Modules, edits.modules)
    end
    if edits.minigames then
        changelog.Minigames  = edits.minigames
        Config.Minigames     = deepMerge(Config.Minigames, edits.minigames)
    end

    applySection("mugging",         "Mugging")
    applySection("mailboxes",       "Mailboxes")
    applySection("parkingMeters",   "ParkingMeters")
    applySection("parcels",         "Parcels")
    applySection("pickPocketing",   "PickPocketing")
    applySection("smashnGrab",      "SmashnGrab")
    applySection("vendingMachines", "VendingMachines")
    applySection("tireSlash",       "TireSlash")
    applySection("pedalBrick",      "PedalBrick")
    applySection("cashRegisters",   "CashRegisters")
    applySection("atmRobbery",      "AtmRobbery")
    applySection("storeShelves",    "StoreShelves")

    return changelog
end

-- ────────────────────────────────────────────────────────────
-- validateIncomingEdits(edits)
-- Sanitises and clamps all numeric fields in an incoming edit
-- payload.  Returns the sanitised table, or nil on type error.
-- ────────────────────────────────────────────────────────────
function validateIncomingEdits(edits)
    if type(edits) ~= "table" then return nil end

    -- Ensure minigames has a valid Color string
    if edits.minigames and type(edits.minigames) == "table" then
        if type(edits.minigames.Color) ~= "string" then
            edits.minigames.Color = "#7aadff"
        end
    end

    -- Helper to clamp a field on a module table
    local function clamp(mod, field, lo, hi)
        if mod[field] ~= nil then
            mod[field] = clampNumber(mod[field], lo, hi)
        end
    end

    -- Helper to clamp a ProgressTime {min, max} sub-table
    local function clampProgressTime(mod)
        if mod.ProgressTime and type(mod.ProgressTime) == "table" then
            local pt = mod.ProgressTime
            pt.min = clampNumber(pt.min, 0, 600000)
            pt.max = clampNumber(pt.max, 0, 600000)
            -- Ensure max >= min
            if pt.min and pt.max and pt.max < pt.min then
                pt.max = pt.min
            end
        end
    end

    -- Helper to clamp an Item.BreakChance sub-table
    local function clampItemBreakChance(mod)
        if mod.Item and type(mod.Item) == "table" then
            mod.Item.BreakChance = clampNumber(mod.Item.BreakChance, 0, 100)
        end
    end

    if edits.mugging and type(edits.mugging) == "table" then
        local m = edits.mugging
        clamp(m, "PoliceRequired",    0, 100)
        clamp(m, "RetaliationChance", 0, 100)
        clamp(m, "AlertChance",       0, 100)
        clampProgressTime(m)
        if m.LootTables then m.LootTables = sanitizeLootTable(m.LootTables) end
    end

    if edits.mailboxes and type(edits.mailboxes) == "table" then
        local m = edits.mailboxes
        clamp(m, "PoliceRequired", 0, 100)
        clamp(m, "AlertChance",    0, 100)
        clamp(m, "Cooldown",       0, 86400)
        clamp(m, "StuckChance",    0, 100)
        clampItemBreakChance(m)
        if m.LootTables then m.LootTables = sanitizeLootTable(m.LootTables) end
    end

    if edits.parkingMeters and type(edits.parkingMeters) == "table" then
        local m = edits.parkingMeters
        clamp(m, "PoliceRequired", 0, 100)
        clamp(m, "AlertChance",    0, 100)
        clamp(m, "Cooldown",       0, 86400)
        clampItemBreakChance(m)
        if m.LootTables then m.LootTables = sanitizeLootTable(m.LootTables) end
    end

    if edits.parcels and type(edits.parcels) == "table" then
        local m = edits.parcels
        clamp(m, "PoliceRequired",        0, 100)
        clamp(m, "AlertChance",           0, 100)
        clamp(m, "Chance",                0, 100)
        clamp(m, "Cooldown",              0, 86400)
        clamp(m, "ParcelBombProbability", 0, 100)
        if m.BombEnabled ~= nil then
            m.BombEnabled = m.BombEnabled == true
        end
        if m.LootTables then m.LootTables = sanitizeLootTable(m.LootTables) end
    end

    if edits.pickPocketing and type(edits.pickPocketing) == "table" then
        local m = edits.pickPocketing
        clamp(m, "PoliceRequired", 0, 100)
        clamp(m, "Chance",         0, 100)
        clamp(m, "AlertChance",    0, 100)
        clamp(m, "ProgressTime",   0, 600000)
        if m.LootTables then m.LootTables = sanitizeLootTable(m.LootTables) end
    end

    if edits.smashnGrab and type(edits.smashnGrab) == "table" then
        local m = edits.smashnGrab
        clamp(m, "PoliceRequired",     0, 100)
        clamp(m, "AlertChance",        0, 100)
        clamp(m, "ChanceToSpawn",      0, 100)
        clamp(m, "Limit",              1, 500)
        clamp(m, "MinVehicleDistance", 0, 500)
        clamp(m, "QueueBatchSize",     1, 1000)
        if m.UseBag ~= nil then m.UseBag = m.UseBag == true end
        clampProgressTime(m)
        -- Ensure ProgressTime.max >= .min after clamping
        if m.LootTables then m.LootTables = sanitizeLootTable(m.LootTables) end
    end

    if edits.vendingMachines and type(edits.vendingMachines) == "table" then
        local m = edits.vendingMachines
        clamp(m, "PoliceRequired", 0, 100)
        clamp(m, "AlertChance",    0, 100)
        clamp(m, "Cooldown",       0, 86400)
        clampItemBreakChance(m)
        if m.LootTables then m.LootTables = sanitizeLootTable(m.LootTables) end
    end

    if edits.tireSlash and type(edits.tireSlash) == "table" then
        local m = edits.tireSlash
        clamp(m, "PoliceRequired",    0, 100)
        clamp(m, "AlertChance",       0, 100)
        clamp(m, "MaxTiresPerVehicle", 1, 6)
        clamp(m, "AlertOnSlash",       1, 6)
    end

    if edits.pedalBrick and type(edits.pedalBrick) == "table" then
        local m = edits.pedalBrick
        clamp(m, "PoliceRequired",  0, 100)
        clamp(m, "AlertChance",     0, 100)
        clamp(m, "AccelDuration",   1, 120)
        clamp(m, "MaxSpeed",        1, 80)
        clamp(m, "AccelRate",     0.1, 5.0)
        if m.BreakOnCollision ~= nil then
            m.BreakOnCollision = m.BreakOnCollision == true
        end
    end

    if edits.cashRegisters and type(edits.cashRegisters) == "table" then
        local m = edits.cashRegisters
        clamp(m, "PoliceRequired",  0,      100)
        clamp(m, "AlertChance",     0,      100)
        clamp(m, "Cooldown",        0,    86400)
        clamp(m, "GrabTime",     1000,    30000)
        clamp(m, "LockpickZones",   1,       10)
        clamp(m, "LockpickSpeed", 0.001,     1.0)
        clamp(m, "LockpickZoneSize", 0.01,  0.5)
        clampItemBreakChance(m)
        if m.LootTables then m.LootTables = sanitizeLootTable(m.LootTables) end
    end

    if edits.atmRobbery and type(edits.atmRobbery) == "table" then
        local m = edits.atmRobbery
        clamp(m, "PoliceRequired",          0,    100)
        clamp(m, "ItemBreakChanceOnRemove", 0,    100)
        clamp(m, "AlertChance",             0,    100)
        clamp(m, "GlobalCooldown",          0,  86400)
        clamp(m, "PoolPerPedMin",           0, 999999)
        clamp(m, "PoolPerPedMax",           0, 999999)
        clamp(m, "DrainTime",            1000,  60000)
        clamp(m, "MatchPairsPairs",         1,     12)
        clamp(m, "MatchPairsTimeLimit",     5,    300)
        clamp(m, "MatchPairsGridCols",      2,     14)
        clamp(m, "MatchPairsGridRows",      2,     14)
        clamp(m, "MatchPairsTilesPerPair",  2,      8)
        clamp(m, "MaxPeds",                 1,     50)
        clamp(m, "PedDelayMin",          1000, 120000)
        clamp(m, "PedDelayMax",          1000, 120000)
        clamp(m, "InteractDistance",      0.5,   20.0)
        clamp(m, "HackMaxDistance",       1.0,   50.0)
    end

    if edits.storeShelves and type(edits.storeShelves) == "table" then
        local m = edits.storeShelves
        clamp(m, "PoliceRequired", 0,    100)
        clamp(m, "AlertChance",    0,    100)
        clamp(m, "Cooldown",       0,  86400)
        clamp(m, "ProgressTime",   1000, 60000)
        clamp(m, "EmptyChance",    0,    100)
        if m.LootTables then m.LootTables = sanitizeLootTable(m.LootTables) end
    end

    -- Normalise BlacklistedJobs on every module that has one
    for _, key in ipairs(MODULE_KEYS) do
        local section = edits[key]
        if section and type(section) == "table" and section.BlacklistedJobs ~= nil then
            section.BlacklistedJobs = uniqueStringArray(section.BlacklistedJobs)
        end
    end

    return edits
end

-- ────────────────────────────────────────────────────────────
-- getInventoryItems()
-- Safely calls Inventory.getItems and returns the result, or {}
-- on failure / missing method.
-- ────────────────────────────────────────────────────────────
function getInventoryItems()
    if not Inventory or not Inventory.getItems then return {} end
    local ok, items = pcall(Inventory.getItems, Inventory)
    if not ok or not items then return {} end
    return items
end

-- ────────────────────────────────────────────────────────────
-- buildCooldownGetters()
-- Returns a table of { moduleName → function() → cooldownList }
-- for every module.  Optional module editors (AtmRobbery, etc.)
-- fall back to an empty-list stub if their global is missing.
-- ────────────────────────────────────────────────────────────
function buildCooldownGetters()
    local function optionalGetter(globalFn)
        if type(globalFn) == "function" and globalFn then
            return globalFn
        end
        return function() return {} end
    end

    return {
        mailboxes      = MailboxEditor_GetCooldowns,
        parkingMeters  = ParkingMeterEditor_GetCooldowns,
        parcels        = ParcelsEditor_GetCooldowns,

        -- Pickpocketing has no dedicated Editor_ global; cooldown is tracked
        -- via entity statebag on every ped with state.pickPocketed == true.
        pickpocketing  = function()
            local result = {}
            for _, ped in ipairs(GetAllPeds()) do
                if Entity(ped).state.pickPocketed then
                    local netId = NetworkGetNetworkIdFromEntity(ped)
                    if netId and netId > 0 then
                        result[#result + 1] = {
                            key       = tostring(netId),
                            label     = "Ped #" .. netId,
                            remaining = -1,
                        }
                    end
                end
            end
            return result
        end,

        atmRobbery     = optionalGetter(AtmRobberyEditor_GetCooldowns),
        vendingMachines= optionalGetter(VendingEditor_GetCooldowns),
        cashRegisters  = optionalGetter(CashRegisterEditor_GetCooldowns),
        storeShelves   = optionalGetter(StoreShelvesEditor_GetCooldowns),
    }
end

-- ────────────────────────────────────────────────────────────
-- buildCooldownClearers()
-- Returns a table of { moduleName → function(key) } to clear
-- one cooldown entry.  Pickpocketing clears via entity state.
-- ────────────────────────────────────────────────────────────
function buildCooldownClearers()
    local function optionalClearer(globalFn)
        if type(globalFn) == "function" and globalFn then
            return globalFn
        end
        return function() end
    end

    return {
        mailboxes      = MailboxEditor_ClearCooldown,
        parkingMeters  = ParkingMeterEditor_ClearCooldown,
        parcels        = ParcelsEditor_ClearCooldown,

        pickpocketing  = function(key)
            local netId = tonumber(key)
            if not netId then return end
            local ped = NetworkGetEntityFromNetworkId(netId)
            if ped and DoesEntityExist(ped) then
                Entity(ped).state:set("pickPocketed", false, true)
            end
        end,

        atmRobbery     = optionalClearer(AtmRobberyEditor_ClearCooldown),
        vendingMachines= optionalClearer(VendingEditor_ClearCooldown),
        cashRegisters  = optionalClearer(CashRegisterEditor_ClearCooldown),
        storeShelves   = optionalClearer(StoreShelvesEditor_ClearCooldown),
    }
end

-- ────────────────────────────────────────────────────────────
-- buildCooldownClearAllFns()
-- Returns a table of { moduleName → function() } to clear all
-- cooldowns for that module.
-- ────────────────────────────────────────────────────────────
function buildCooldownClearAllFns()
    local function optionalClearAll(globalFn)
        if type(globalFn) == "function" and globalFn then
            return globalFn
        end
        return function() end
    end

    return {
        mailboxes      = MailboxEditor_ClearAll,
        parkingMeters  = ParkingMeterEditor_ClearAll,
        parcels        = ParcelsEditor_ClearAll,

        pickpocketing  = function()
            for _, ped in ipairs(GetAllPeds()) do
                if Entity(ped).state.pickPocketed then
                    Entity(ped).state:set("pickPocketed", false, true)
                end
            end
        end,

        atmRobbery     = optionalClearAll(AtmRobberyEditor_ClearAll),
        vendingMachines= optionalClearAll(VendingEditor_ClearAll),
        cashRegisters  = optionalClearAll(CashRegisterEditor_ClearAll),
        storeShelves   = optionalClearAll(StoreShelvesEditor_ClearAll),
    }
end

-- ────────────────────────────────────────────────────────────
-- Startup thread
-- Waits 3 s, loads overrides, migrates if needed, broadcasts.
-- ────────────────────────────────────────────────────────────
CreateThread(function()
    Wait(3000)

    local snapshot  = buildCurrentConfigSnapshot()
    local overrides = loadOverridesFile()

    if overrides then
        if hasMissingDefaultKeys(overrides, snapshot) then
            saveOverridesFile(overrides)
            Trace("Editor overrides auto-migrated with new default keys")
        end
        applyOverrides(overrides)
        Trace("Editor overrides loaded and applied")
    end

    TriggerLatentClientEvent(eventName .. "editor:configUpdated", -1, 128000, buildCurrentConfigSnapshot())
end)

-- ────────────────────────────────────────────────────────────
-- Event: playerJoining
-- Sends the current config snapshot to the joining player after
-- a 5-second delay (give them time to finish loading).
-- ────────────────────────────────────────────────────────────
AddEventHandler("playerJoining", function()
    local joiningSource = source
    Citizen.SetTimeout(5000, function()
        TriggerLatentClientEvent(eventName .. "editor:configUpdated", joiningSource, 128000, buildCurrentConfigSnapshot())
    end)
end)

-- ────────────────────────────────────────────────────────────
-- Event: server:requestConfigSync
-- Lets a client explicitly request the current config snapshot.
-- ────────────────────────────────────────────────────────────
RegisterNetEvent(eventName .. "server:requestConfigSync")
AddEventHandler(eventName .. "server:requestConfigSync", function()
    TriggerLatentClientEvent(eventName .. "editor:configUpdated", source, 128000, buildCurrentConfigSnapshot())
end)

-- ────────────────────────────────────────────────────────────
-- Callback: editor:getConfig
-- Returns the full config snapshot + inventory item list to an admin.
-- ────────────────────────────────────────────────────────────
RegisterServerCallback({
    eventName = eventName .. "editor:getConfig",
    eventCallback = function(source)
        if not Framework:isAdmin(source) then
            return { status = false, message = "NOT_ADMIN" }
        end

        return {
            status = true,
            config = buildCurrentConfigSnapshot(),
            items  = getInventoryItems(),
        }
    end,
})

-- ────────────────────────────────────────────────────────────
-- Callback: editor:saveConfig
-- Validates, applies, saves, and broadcasts an admin's edits.
-- ────────────────────────────────────────────────────────────
RegisterServerCallback({
    eventName = eventName .. "editor:saveConfig",
    eventCallback = function(source, rawEdits)
        if not Framework:isAdmin(source) then
            return { status = false, message = "NOT_ADMIN" }
        end

        if not rawEdits or type(rawEdits) ~= "table" then
            return { status = false, message = "INVALID_DATA" }
        end

        local validated = validateIncomingEdits(rawEdits)
        if not validated then
            return { status = false, message = "VALIDATION_FAILED" }
        end

        local ok, err = pcall(function()
            local changelog = applyIncomingEdits(validated)
            saveOverridesFile(changelog)
        end)

        if not ok then
            print("[bablo-pettycrimes] ERROR saving config: " .. tostring(err))
            return { status = false, message = "SAVE_ERROR" }
        end

        TriggerLatentClientEvent(eventName .. "editor:configUpdated", -1, 128000, validated)
        Trace("Editor config saved by player " .. source)

        return { status = true }
    end,
})

-- ────────────────────────────────────────────────────────────
-- Callback: editor:getActiveVehicles
-- Returns a paginated list of active SmashnGrab persistent
-- vehicles.  Stale entries (entity gone) are cleaned up.
-- ────────────────────────────────────────────────────────────
RegisterServerCallback({
    eventName = eventName .. "editor:getActiveVehicles",
    eventCallback = function(source, params)
        if not Framework:isAdmin(source) then
            return { status = false, message = "NOT_ADMIN" }
        end

        local page     = (params and params.page)     or 1
        local pageSize = (params and params.pageSize)  or 20

        local activeVehicles = {}
        local staleVehicles  = {}

        if SmashnGrab and SmashnGrab.persistentVehicles then
            for netId, vehicleData in pairs(SmashnGrab.persistentVehicles) do
                local entity = NetworkGetEntityFromNetworkId(netId)
                if entity and DoesEntityExist(entity) then
                    -- Vehicle is alive, add it to the active list
                    local coords = vehicleData.coords
                    local coordsCopy = coords and { x = coords.x, y = coords.y, z = coords.z }
                                                or { x = 0, y = 0, z = 0 }
                    table.insert(activeVehicles, {
                        netId    = netId,
                        model    = vehicleData.model   or "unknown",
                        heading  = vehicleData.heading  or 0.0,
                        uniqueId = vehicleData.uniqueId or tostring(netId),
                        loot     = vehicleData.loot     or nil,
                        coords   = coordsCopy,
                    })
                else
                    -- Entity no longer exists — mark for cleanup
                    table.insert(staleVehicles, { netId = netId, uniqueId = vehicleData.uniqueId })
                end
            end

            -- Clean up stale entries
            if #staleVehicles > 0 then
                local removedIds = {}
                for _, stale in ipairs(staleVehicles) do
                    SmashnGrab.persistentVehicles[stale.netId] = nil
                    SmashnGrab.persistentVehicleCount = math.max(0, SmashnGrab.persistentVehicleCount - 1)
                    removedIds[#removedIds + 1] = stale.uniqueId
                end
                TriggerClientEvent(eventName .. "client:removePersistentVehicle", -1, removedIds)
                Trace("Editor cleanup: removed " .. #staleVehicles .. " stale vehicles")
            end
        end

        -- Paginate
        local total     = #activeVehicles
        local startIdx  = (page - 1) * pageSize + 1
        local endIdx    = math.min(startIdx + pageSize - 1, total)
        local pageItems = {}
        for i = startIdx, endIdx do
            pageItems[#pageItems + 1] = activeVehicles[i]
        end

        return {
            status   = true,
            vehicles = pageItems,
            total    = total,
            page     = page,
            pageSize = pageSize,
        }
    end,
})

-- ────────────────────────────────────────────────────────────
-- Callback: editor:getCooldowns
-- Returns the cooldown list for one module.
-- ────────────────────────────────────────────────────────────
RegisterServerCallback({
    eventName = eventName .. "editor:getCooldowns",
    eventCallback = function(source, params)
        if not Framework:isAdmin(source) then
            return { status = false, message = "NOT_ADMIN" }
        end

        local moduleName = params and params.module
        if not moduleName then
            return { status = false, message = "NO_MODULE" }
        end

        local getters = buildCooldownGetters()
        local getter  = getters[moduleName]
        if not getter then
            return { status = false, message = "UNKNOWN_MODULE" }
        end

        local ok, cooldowns = pcall(getter)
        if not ok then
            return { status = false, message = tostring(cooldowns) }
        end

        return { status = true, cooldowns = cooldowns }
    end,
})

-- ────────────────────────────────────────────────────────────
-- Callback: editor:clearCooldown
-- Clears one cooldown entry for a specific module.
-- ────────────────────────────────────────────────────────────
RegisterServerCallback({
    eventName = eventName .. "editor:clearCooldown",
    eventCallback = function(source, params)
        if not Framework:isAdmin(source) then
            return { status = false, message = "NOT_ADMIN" }
        end

        local moduleName = params and params.module
        local cooldownKey = params and params.key
        if not moduleName or not cooldownKey then
            return { status = false, message = "INVALID_DATA" }
        end

        local clearers = buildCooldownClearers()
        local clearer  = clearers[moduleName]
        if not clearer then
            return { status = false, message = "UNKNOWN_MODULE" }
        end

        local ok, err = pcall(clearer, cooldownKey)
        if not ok then
            return { status = false, message = tostring(err) }
        end

        Trace("Admin " .. source .. " cleared cooldown key=" .. cooldownKey .. " module=" .. moduleName)
        return { status = true }
    end,
})

-- ────────────────────────────────────────────────────────────
-- Callback: editor:clearAllCooldowns
-- Clears every cooldown for a specific module.
-- ────────────────────────────────────────────────────────────
RegisterServerCallback({
    eventName = eventName .. "editor:clearAllCooldowns",
    eventCallback = function(source, params)
        if not Framework:isAdmin(source) then
            return { status = false, message = "NOT_ADMIN" }
        end

        local moduleName = params and params.module
        if not moduleName then
            return { status = false, message = "NO_MODULE" }
        end

        local clearAllFns = buildCooldownClearAllFns()
        local clearAll    = clearAllFns[moduleName]
        if not clearAll then
            return { status = false, message = "UNKNOWN_MODULE" }
        end

        local ok, err = pcall(clearAll)
        if not ok then
            return { status = false, message = tostring(err) }
        end

        Trace("Admin " .. source .. " cleared all cooldowns for module=" .. moduleName)
        return { status = true }
    end,
})

-- ────────────────────────────────────────────────────────────
-- Callback: editor:removeVehicle
-- Admin removes one persistent SmashnGrab vehicle by netId.
-- ────────────────────────────────────────────────────────────
RegisterServerCallback({
    eventName = eventName .. "editor:removeVehicle",
    eventCallback = function(source, params)
        if not Framework:isAdmin(source) then
            return { status = false, message = "NOT_ADMIN" }
        end

        if not params or not params.netId then
            return { status = false, message = "INVALID_DATA" }
        end

        local netId = params.netId

        if not SmashnGrab or not SmashnGrab.persistentVehicles then
            return { status = false, message = "VEHICLE_NOT_FOUND" }
        end

        local vehicleData = SmashnGrab.persistentVehicles[netId]
        if not vehicleData then
            return { status = false, message = "VEHICLE_NOT_FOUND" }
        end

        -- Mark entity as no longer persistent so the client cleans it up
        local entity = NetworkGetEntityFromNetworkId(netId)
        if entity and DoesEntityExist(entity) then
            Entity(entity).state:set("persistent", false, true)
            Entity(entity).state:set("looted",     true,  true)
        end

        table.insert(SmashnGrab.vehiclesToRemove, vehicleData.uniqueId)
        SmashnGrab.persistentVehicles[netId]  = nil
        SmashnGrab.persistentVehicleCount     = math.max(0, SmashnGrab.persistentVehicleCount - 1)

        TriggerClientEvent(eventName .. "client:removePersistentVehicle", -1, { vehicleData.uniqueId })
        Trace("Admin " .. source .. " removed persistent vehicle netId=" .. netId)

        return { status = true }
    end,
})

-- ────────────────────────────────────────────────────────────
-- Callback: editor:checkRequirements
-- Returns a list of inventory-item issues (missing required
-- items for any module that needs them).
-- ────────────────────────────────────────────────────────────
RegisterServerCallback({
    eventName = eventName .. "editor:checkRequirements",
    eventCallback = function(source)
        if not Framework:isAdmin(source) then
            return { status = false, message = "NOT_ADMIN" }
        end

        -- Build a set of all known inventory item names
        local knownItems = {}
        for key, entry in pairs(getInventoryItems()) do
            if type(key) == "string" then
                knownItems[key] = true
            elseif type(entry) == "table" then
                if type(entry.name) == "string" then
                    knownItems[entry.name] = true
                end
            elseif type(entry) == "string" then
                knownItems[entry] = true
            end
        end

        -- Check usable items registered by Main
        local issues         = {}
        local usableItemsSeen = {}

        for _, usable in ipairs(Main.usableItems) do
            if usable.name then
                if not knownItems[usable.name] then
                    issues[#issues + 1] = {
                        module   = "Core",
                        item     = usable.name,
                        type     = "required_item",
                        severity = "error",
                        message  = 'Usable item "' .. usable.name .. '" not found in inventory',
                    }
                end
                usableItemsSeen[usable.name] = true
            end
        end

        -- Collect required items per module
        local moduleRequiredItems = {}

        if Config and Config.AtmRobbery and type(Config.AtmRobbery.RequiredItem) == "string" then
            moduleRequiredItems[#moduleRequiredItems + 1] = {
                module = "ATM Robbery",
                name   = Config.AtmRobbery.RequiredItem,
            }
        end

        if Config and Config.PedalBrick and type(Config.PedalBrick.ItemName) == "string" then
            moduleRequiredItems[#moduleRequiredItems + 1] = {
                module = "Pedal Brick",
                name   = Config.PedalBrick.ItemName,
            }
        end

        if Config and Config.CashRegisters and Config.CashRegisters.Item and Config.CashRegisters.Item.Names then
            for _, itemName in ipairs(Config.CashRegisters.Item.Names) do
                moduleRequiredItems[#moduleRequiredItems + 1] = {
                    module = "Cash Register Robbery",
                    name   = itemName,
                }
            end
        end

        -- Report any module-required items not found in inventory and not already in usableItems
        for _, required in ipairs(moduleRequiredItems) do
            if not usableItemsSeen[required.name] and not knownItems[required.name] then
                issues[#issues + 1] = {
                    module   = required.module,
                    item     = required.name,
                    type     = "required_item",
                    severity = "error",
                    message  = 'Required item "' .. required.name .. '" not found in inventory',
                }
            end
        end

        return { status = true, issues = issues }
    end,
})

-- ────────────────────────────────────────────────────────────
-- Callback: editor:testDispatch
-- Fires a fake dispatch notification on the requesting player's
-- client so admins can preview each crime's dispatch message.
-- ────────────────────────────────────────────────────────────
local DISPATCH_PRESETS = {
    mugging        = { message = "Mugging In Progress",          description = "A civilian is being mugged"              },
    mailboxes      = { message = "Mailbox Robbery",              description = "Someone is breaking into a mailbox"      },
    parkingMeters  = { message = "Parking Meter Robbery",        description = "Someone is breaking into a parking meter" },
    parcels        = { message = "Parcel Theft",                 description = "Someone is stealing a parcel"            },
    pickPocketing  = { message = "Pickpocketing",                description = "A civilian is being pickpocketed"        },
    smashnGrab     = { message = "Vehicle Break-in",             description = "Someone is breaking into a vehicle"      },
    vendingMachines= { message = "Vending Machine Break-in",     description = "Someone is breaking into a vending machine" },
    atmRobbery     = { message = "ATM Robbery",                  description = "Someone is robbing an ATM"               },
    tireSlash      = { message = "Tire Slashing",                description = "Someone is slashing vehicle tires"       },
    pedalBrick     = { message = "Vehicle Tampering",            description = "Someone placed a brick on a gas pedal"   },
    cashRegisters  = { message = "Cash Register Robbery",        description = "Someone is robbing a cash register"      },
    storeShelves   = { message = "Store Shoplifting",            description = "Someone is stealing from store shelves"  },
}

RegisterServerCallback({
    eventName = eventName .. "editor:testDispatch",
    eventCallback = function(source, crimeKey)
        if not Framework:isAdmin(source) then
            return { status = false, message = "NOT_ADMIN" }
        end

        if not crimeKey or type(crimeKey) ~= "string" then
            return { status = false, message = "INVALID_CRIME" }
        end

        local preset = DISPATCH_PRESETS[crimeKey]
        if not preset then
            return { status = false, message = "UNKNOWN_CRIME" }
        end

        local ped    = GetPlayerPed(source)
        local coords = GetEntityCoords(ped)

        TriggerClientEvent(eventName .. "editor:triggerTestDispatch", source, {
            coords      = { x = coords.x, y = coords.y, z = coords.z },
            message     = preset.message,
            description = preset.description,
        })

        return { status = true }
    end,
})