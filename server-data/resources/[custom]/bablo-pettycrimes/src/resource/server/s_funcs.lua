-- ─── Main Table ───────────────────────────────────────────────────────────────

Main = {}
Main.activeSounds = {}

-- ─── Usable Items ─────────────────────────────────────────────────────────────

Main.usableItems = {
    {
        name = "bletter",
        use  = function(source, itemData)
            TriggerClientEvent(eventName .. "client:useLetterItem", source, itemData)
        end,
    },
    {
        name = "bpackage",
        use  = function(source, itemData)
            TriggerClientEvent(eventName .. "client:useParcelItem", source, itemData)
        end,
    },
    {
        name = "batm_hacker",
        use  = function(source, itemData)
            -- No client event; hacker item usage is handled client-side
        end,
    },
    {
        name = "bbrick",
        use  = function(source, itemData)
            TriggerClientEvent(eventName .. "client:useBrickItem", source)
        end,
    },
    {
        name = "bbag",
        use  = function(source, itemData)
            TriggerClientEvent(eventName .. "client:useBagItem", source, itemData)
        end,
    },
}

-- ─── Module → Config Key Map ──────────────────────────────────────────────────

local moduleConfigKeys = {
    MUGGING               = "Mugging",
    MAILBOX_ROBBERY       = "Mailboxes",
    PARKING_METER_ROBBERY = "ParkingMeters",
    PARCEL_THEFT          = "Parcels",
    PICKPOCKETING         = "PickPocketing",
    SMASH_N_GRAB          = "SmashnGrab",
    VENDING_MACHINE       = "VendingMachines",
    ATM_ROBBERY           = "AtmRobbery",
    TIRE_SLASH            = "TireSlash",
    PEDAL_BRICK           = "PedalBrick",
    CASH_REGISTER_ROBBERY = "CashRegisters",
    STORE_SHELVES         = "StoreShelves",
}

-- ─── Internal Helpers ─────────────────────────────────────────────────────────

local function normalizeJobName(value)
    if type(value) ~= "string" then return nil end
    local trimmed = value:match("^%s*(.-)%s*$")
    if not trimmed or trimmed == "" then return nil end
    return trimmed:lower()
end

-- ─── Job Blacklist Check ──────────────────────────────────────────────────────

function Main:isJobBlacklisted(source, moduleKey)
    local configKey = moduleConfigKeys[moduleKey]
    if not configKey then return false end

    local moduleConfig = Config[configKey]
    if not moduleConfig then return false end

    local blacklist = moduleConfig.BlacklistedJobs
    if not blacklist or #blacklist == 0 then return false end

    if not Framework or type(Framework.getPlayerJob) ~= "function" then return false end

    local ok, playerJob = pcall(function()
        return Framework:getPlayerJob(source)
    end)
    if not ok then return false end

    local normalizedJob = normalizeJobName(playerJob)
    if not normalizedJob then return false end

    for _, entry in ipairs(blacklist) do
        if normalizeJobName(entry) == normalizedJob then
            return true
        end
    end

    return false
end

-- ─── Initialization ───────────────────────────────────────────────────────────

function Main:Init()
    while not (Framework and Framework.getCore) do
        Citizen.Wait(100)
    end
    Inventory:Init()
end

-- ─── UUID Generator ───────────────────────────────────────────────────────────

function Main:generateUniqueId()
    return ("xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx"):gsub("[xy]", function(char)
        local value = char == "x"
            and math.random(0, 15)
            or  math.random(8, 11)
        return string.format("%x", value)
    end)
end
