Trace(("[Framework/qbox] server.lua LOADED at %s"):format(tostring(GetGameTimer())))
if Config.Framework ~= "qbox" then return end

-- Optional legacy QBCore shared object (only populated when qb-core is the active core).
-- All qbx_core interactions use exports.qbx_core directly.
local QBCore = nil

CreateThread(function()
    while GetResourceState("qbx_core") ~= "started"
      and GetResourceState("qb-core")  ~= "started" do
        Wait(50)
    end

    if GetResourceState("qb-core") == "started" then
        QBCore = exports["qb-core"]:GetCoreObject()
    end

    Trace("[Framework/qbox] Server initialised")
end)

-- ─── Local helpers ────────────────────────────────────────────────────────────

-- Return the primary license identifier for src.
-- qbox prefers license2 (Rockstar), falling back to license (Steam/cfx).
local function getPrimaryLicense(src)
    return GetPlayerIdentifierByType(src, "license2")
        or GetPlayerIdentifierByType(src, "license")
end

-- Return both license identifiers for src: (primary, secondary).
-- primary  = license2 if available, else license
-- secondary = license if available, else license2
-- Both are used in WHERE clauses that accept either.
local function getBothLicenses(src)
    local license  = GetPlayerIdentifierByType(src, "license")
    local license2 = GetPlayerIdentifierByType(src, "license2")
    local primary   = license2 or license
    local secondary = license  or license2
    return primary, secondary
end

-- Safely JSON-decode a string; returns a table or {} on failure / empty input.
local function safeJsonDecode(str)
    if not str or str == "" then return {} end
    local ok, result = pcall(json.decode, str)
    if ok and type(result) == "table" then return result end
    return {}
end

-- Normalise gender from qbox's numeric / string format to "Male" / "Female".
local function normaliseSex(raw)
    if raw == 1 or raw == "f" or raw == "F" then return "Female" end
    return "Male"
end

-- Build the normalised character record sent to the client.
local function buildCharacterRecord(row)
    local charinfo  = safeJsonDecode(row.charinfo)
    local job       = safeJsonDecode(row.job)
    local money     = safeJsonDecode(row.money)
    local position  = safeJsonDecode(row.position)
    local gender    = normaliseSex(charinfo.gender)

    local gradeLabel = ""
    if job.grade then
        gradeLabel = job.grade.name or job.grade.label or ""
    end

    local firstname = charinfo.firstname or ""
    local lastname  = charinfo.lastname  or ""
    local fullName  = (firstname .. " " .. lastname):gsub("^%s+", ""):gsub("%s+$", "")

    local lastLocation
    if position.x then
        lastLocation = { x = position.x, y = position.y, z = position.z }
    end

    return {
        id              = row.citizenid,
        cid             = tonumber(row.cid),
        name            = fullName,
        firstname       = firstname,
        lastname        = lastname,
        gender          = gender,
        dob             = charinfo.birthdate or "",
        cash            = tonumber(money.cash)   or 0,
        bank            = tonumber(money.bank)   or 0,
        playtimeMinutes = tonumber(row.playtime) or 0,
        job             = job.name,
        jobLabel        = job.label,
        jobGrade        = gradeLabel,
        bio             = charinfo.bio or "",
        lastLocation    = lastLocation,
        _skin           = Appearance:FetchSkin(row.citizenid),
        houses          = Housing:GetOwned(row.citizenid),
    }
end

-- ─── In-flight load/create guards ────────────────────────────────────────────
-- Prevent duplicate concurrent LoadCharacter or CreateCharacter calls for the
-- same source. These tables are keyed by src and cleaned up on playerDropped or
-- on success/failure.

-- loadingPlayers[src] = true while LoadCharacter is in flight for src.
local loadingPlayers = {}

-- createCooldowns[src] = expiry timestamp (from GetGameTimer) to rate-limit
-- CreateCharacter submissions per player.
local createCooldowns = {}
local CREATE_COOLDOWN_MS = 5000

AddEventHandler("playerDropped", function()
    loadingPlayers[source]  = nil
    createCooldowns[source] = nil
end)

-- ─── Logout → character selection ────────────────────────────────────────────
-- With useExternalCharacters = true, qbx_core's own /logout (and any other
-- resource calling exports.qbx_core:Logout) expects the external multichar to
-- reopen the selector. qbx_core fires qbx_core:server:playerLoggedOut from
-- inside Logout, so logouts this resource triggers itself (switching or
-- creating a character, /relog) are flagged and skipped here.

local internalLogout = {}

local function logoutInternal(src)
    internalLogout[src] = true
    local ok = pcall(function() exports.qbx_core:Logout(src) end)
    internalLogout[src] = nil
    return ok
end

AddEventHandler("qbx_core:server:playerLoggedOut", function(src)
    src = tonumber(src)
    if not src or internalLogout[src] then return end
    TriggerClientEvent(eventName .. "client:prepareRelog", src)
    SetTimeout(600, function()
        if GetPlayerName(src) then
            TriggerClientEvent(eventName .. "client:openUI", src)
        end
    end)
end)

-- ─── Framework methods ────────────────────────────────────────────────────────

-- FetchCharacters: query both license columns so qbox players are found
-- regardless of which license variant was stored.
function Framework:FetchCharacters(src)
    local primary, secondary = getBothLicenses(src)
    Trace(("[Framework/qbox] FetchCharacters — src=%s license=%s / %s"):format(
        tostring(src), tostring(primary), tostring(secondary)))

    if not primary then return {} end

    local rows = MySQL.query.await(
        "SELECT * FROM `players` WHERE `license` = ? OR `license` = ? ORDER BY `cid` ASC",
        { primary, secondary }
    )
    local count = (rows and #rows) or 0
    Trace(("[Framework/qbox] FetchCharacters — query returned %d row(s)"):format(count))

    if not rows or count == 0 then return {} end

    local chars = {}
    for _, row in ipairs(rows) do
        chars[#chars + 1] = buildCharacterRecord(row)
    end
    return chars
end

-- LoadCharacter: login via qbx_core.Login. Handles the idempotent case where
-- the player is already logged in as the requested character.
function Framework:LoadCharacter(src, citizenid)
    if GetResourceState("qbx_core") ~= "started" then return false end

    -- Idempotency check: if the player is already on this character, return true.
    local existing = exports.qbx_core:GetPlayer(src)
    if existing and existing.PlayerData and existing.PlayerData.citizenid == citizenid then
        Trace(("[Framework/qbox] LoadCharacter — src=%s already logged in as %s (idempotent)"):format(
            tostring(src), tostring(citizenid)))
        return true
    end

    -- Guard against concurrent loads for the same source.
    if loadingPlayers[src] then
        local deadline = GetGameTimer() + 5000
        while loadingPlayers[src] and GetGameTimer() < deadline do
            Wait(50)
        end
    end
    loadingPlayers[src] = true

    -- Fetch the saved position so Login can restore it.
    local posRows = MySQL.query.await(
        "SELECT `position` FROM `players` WHERE `citizenid` = ?",
        { citizenid }
    )
    local savedPosition = posRows and posRows[1] and posRows[1].position or nil

    -- If a different character was loaded, log out first.
    if existing then
        logoutInternal(src)
        Wait(300)
    end

    local loginOk = exports.qbx_core:Login(src, citizenid)
    if not loginOk then
        loadingPlayers[src] = nil
        return false
    end

    -- Wait up to 5 s for qbx_core to register the player object.
    local deadline = GetGameTimer() + 5000
    while not exports.qbx_core:GetPlayer(src) and GetGameTimer() < deadline do
        Wait(10)
    end

    local xPlayer = exports.qbx_core:GetPlayer(src)
    if not xPlayer then
        loadingPlayers[src] = nil
        return false
    end

    -- Optionally overwrite the stored position with Config.SpawnCoords.
    Wait(250)
    if savedPosition then
        MySQL.query.await(
            "UPDATE `players` SET `position` = ? WHERE `citizenid` = ?",
            { savedPosition, citizenid }
        )
    end

    Playtime:EndSession(src)
    Playtime:StartSession(src, citizenid)
    loadingPlayers[src] = nil

    Trace(("[Framework/qbox] LoadCharacter ok — src=%s citizenid=%s"):format(
        tostring(src), tostring(citizenid)))
    return true
end

-- giveStarterItems: give qbox StarterItems (sourced from QBCore.Shared when the
-- legacy shim is present) to a freshly created character.
local function giveStarterItems(src)
    local xPlayer = exports.qbx_core:GetPlayer(src)
    if not xPlayer then return end

    local starterItems = QBCore and QBCore.Shared and QBCore.Shared.StarterItems
    if not starterItems then return end

    for _, entry in pairs(starterItems) do
        local metadata = {}
        local pd = xPlayer.PlayerData

        if entry.item == "id_card" then
            metadata.citizenid   = pd.citizenid
            metadata.firstname   = pd.charinfo.firstname
            metadata.lastname    = pd.charinfo.lastname
            metadata.birthdate   = pd.charinfo.birthdate
            metadata.gender      = pd.charinfo.gender
            metadata.nationality = pd.charinfo.nationality
        elseif entry.item == "driver_license" then
            metadata.firstname = pd.charinfo.firstname
            metadata.lastname  = pd.charinfo.lastname
            metadata.birthdate = pd.charinfo.birthdate
            metadata.type      = "Class C Driver License"
        end

        xPlayer.Functions.AddItem(entry.item, entry.amount, false, metadata)
    end
end

-- CreateCharacter: rate-limited, allocates the next cid, calls qbx_core.Login
-- with new player data, optionally writes SpawnCoords, gives starter items,
-- and starts a playtime session.
-- Returns: success (bool), citizenid (string|nil)
function Framework:CreateCharacter(src, formData)
    if GetResourceState("qbx_core") ~= "started" then return false, nil end

    -- Duplicate-submission cooldown.
    local now = GetGameTimer()
    if createCooldowns[src] and now < createCooldowns[src] then
        Trace(("[Framework/qbox] CreateCharacter — duplicate ignored for src=%s (cooldown active for %dms more)"):format(
            tostring(src), createCooldowns[src] - now))
        return false, nil
    end
    createCooldowns[src] = now + CREATE_COOLDOWN_MS

    local primaryLicense = getPrimaryLicense(src)
    if not primaryLicense then
        createCooldowns[src] = nil
        return false, nil
    end

    local primary, secondary = getBothLicenses(src)

    -- Count existing characters for both license variants to determine the next cid.
    local countRows = MySQL.query.await(
        "SELECT COUNT(*) AS n FROM `players` WHERE `license` = ? OR `license` = ?",
        { primary, secondary }
    )
    local existingCount = (countRows and countRows[1] and tonumber(countRows[1].n)) or 0
    local newCid = existingCount + 1

    -- Normalise first/last name and gender.
    local firstName = formData.firstName or formData.firstname or ""
    local lastName  = formData.lastName  or formData.lastname  or ""
    local gender    = 0
    if formData.gender == "Female" or formData.gender == "female" then
        gender = 1
    end

    local playerData = {
        cid     = newCid,
        license = primaryLicense,
        charinfo = {
            firstname   = firstName,
            lastname    = lastName,
            birthdate   = formData.dob or "",
            gender      = gender,
            height      = tonumber(formData.height) or 180,
            nationality = formData.nationality or "",
        },
    }

    -- Log out the player's current session if one exists, then log in as new character.
    local currentPlayer = exports.qbx_core:GetPlayer(src)
    if currentPlayer then
        logoutInternal(src)
        Wait(100)
    end

    local loginOk = exports.qbx_core:Login(src, false, playerData)
    if not loginOk then
        createCooldowns[src] = nil
        return false, nil
    end

    -- Wait up to 5 s for qbx_core to register the player object.
    local deadline = GetGameTimer() + 5000
    while not exports.qbx_core:GetPlayer(src) and GetGameTimer() < deadline do
        Wait(10)
    end

    local xPlayer = exports.qbx_core:GetPlayer(src)
    if not xPlayer then
        createCooldowns[src] = nil
        return false, nil
    end

    -- Optionally write SpawnCoords to the DB immediately.
    if Config.SpawnCoords and Config.SpawnCoords.coords then
        Wait(250)
        local c = Config.SpawnCoords.coords
        MySQL.query.await(
            "UPDATE `players` SET `position` = ? WHERE `citizenid` = ?",
            { json.encode({ x = c.x + 0.0, y = c.y + 0.0, z = c.z + 0.0 }),
              xPlayer.PlayerData.citizenid }
        )
    end

    giveStarterItems(src)
    Playtime:EndSession(src)
    Playtime:StartSession(src, xPlayer.PlayerData.citizenid)

    -- Refresh the cooldown timestamp so a rapid second call is still blocked.
    createCooldowns[src] = GetGameTimer() + CREATE_COOLDOWN_MS

    Trace(("[Framework/qbox] CreateCharacter ok — citizenid=%s"):format(
        tostring(xPlayer.PlayerData.citizenid)))
    return true, xPlayer.PlayerData.citizenid
end

-- Dependent-cleanup table: DELETE statements to run for associated resources
-- before the core character row is removed. Each entry has:
--   .resource (string|nil) — if set, skip the cleanup when the resource isn't started
--   .sql      (string)     — DELETE query; citizenid is passed as the single param
local dependentCleanups = {
    { resource = "qbx_properties",  sql = "DELETE FROM `properties`     WHERE `owner`      = ?" },
    { resource = "qbx_apartments",  sql = "DELETE FROM `apartments`     WHERE `citizenid`  = ?" },
    { resource = "qb-houses",       sql = "DELETE FROM `player_houses`  WHERE `citizenid`  = ?" },
    { resource = nil,               sql = "DELETE FROM `playerskins`    WHERE `citizenid`  = ?" },
    { resource = nil,               sql = "DELETE FROM `player_vehicles` WHERE `citizenid` = ?" },
}

-- DeleteCharacter: verify ownership, run dependent cleanup queries, then call
-- qbx_core.DeleteCharacter.
function Framework:DeleteCharacter(src, citizenid)
    if Config.AllowCharacterDeletion == false then return false end
    if GetResourceState("qbx_core") ~= "started" then return false end
    if not src or not citizenid then return false end

    local primary, secondary = getBothLicenses(src)
    if not primary then return false end

    -- Verify the citizenid actually belongs to this player.
    local owned = MySQL.single.await(
        "SELECT `citizenid` FROM `players` WHERE `citizenid` = ? AND (`license` = ? OR `license` = ?)",
        { citizenid, primary, secondary }
    )
    if not owned then
        Trace(("[Framework/qbox] DeleteCharacter — citizenid=%s does NOT belong to license=%s, rejected"):format(
            tostring(citizenid), tostring(primary)))
        return false
    end

    -- Run dependent cleanup (skip entries whose resource isn't running).
    for _, entry in ipairs(dependentCleanups) do
        if not entry.resource or GetResourceState(entry.resource) == "started" then
            local ok, err = pcall(function()
                MySQL.query.await(entry.sql, { citizenid })
            end)
            if not ok then
                Trace(("[Framework/qbox] DeleteCharacter — dependent cleanup failed for \"%s\": %s"):format(
                    entry.sql, tostring(err)))
            end
        end
    end

    exports.qbx_core:DeleteCharacter(citizenid)
    Trace(("[Framework/qbox] DeleteCharacter — citizenid=%s deleted"):format(citizenid))
    return true
end

-- GetPlaytime: return stored playtime minutes for citizenid, or 0.
function Framework:GetPlaytime(citizenid)
    if not citizenid then return 0 end
    local rows = MySQL.query.await(
        "SELECT `playtime` FROM `players` WHERE `citizenid` = ?",
        { citizenid }
    )
    return (rows and rows[1] and tonumber(rows[1].playtime)) or 0
end

-- AddPlaytime: increment playtime in the DB by minutes.
function Framework:AddPlaytime(citizenid, minutes)
    if not citizenid or not minutes or minutes <= 0 then return end
    MySQL.query.await(
        "UPDATE `players` SET `playtime` = `playtime` + ? WHERE `citizenid` = ?",
        { minutes, citizenid }
    )
end

-- IsAdmin: check via exports.qbx_core.HasPermission (pcall'd), then ace fallback.
function Framework:IsAdmin(src)
    src = tonumber(src)
    if not src then return false end

    local qbxCore = exports.qbx_core
    if qbxCore and qbxCore.HasPermission then
        local ok, result = pcall(function()
            return qbxCore:HasPermission(src, "admin") or qbxCore:HasPermission(src, "god")
        end)
        if ok and result then return true end
    end

    return IsPlayerAceAllowed(src, "command")
end

-- LogoutCharacter: call exports.qbx_core.Logout (pcall'd to handle not-logged-in cases).
function Framework:LogoutCharacter(src)
    src = tonumber(src)
    if not src then return false end
    -- /relog opens the selector itself, so don't let the logout hook do it too.
    return logoutInternal(src)
end

-- ─── lib.callback registrations ──────────────────────────────────────────────

Framework:RegisterCallback("bablo-multicharacter:fetchCharacters", function(src)
    return Framework:FetchCharacters(src)
end)

Framework:RegisterCallback("bablo-multicharacter:loadCharacter", function(src, citizenid)
    return Framework:LoadCharacter(src, citizenid)
end)

Framework:RegisterCallback("bablo-multicharacter:createCharacter", function(src, formData)
    return Framework:CreateCharacter(src, formData)
end)

Framework:RegisterCallback("bablo-multicharacter:deleteCharacter", function(src, citizenid)
    return Framework:DeleteCharacter(src, citizenid)
end)

-- ─── Export ───────────────────────────────────────────────────────────────────

exports("FetchCharacters", function(src)
    return Framework:FetchCharacters(src)
end)

exports("LoadCharacter", function(src, citizenid)
    return Framework:LoadCharacter(src, citizenid)
end)

exports("CreateCharacter", function(src, formData)
    return Framework:CreateCharacter(src, formData)
end)

exports("DeleteCharacter", function(src, citizenid)
    return Framework:DeleteCharacter(src, citizenid)
end)

exports("LogoutCharacter", function(src)
    return Framework:LogoutCharacter(src)
end)

exports("IsAdmin", function(src)
    return Framework:IsAdmin(src)
end)

exports("GetPlaytime", function(citizenid)
    return Framework:GetPlaytime(citizenid)
end)

exports("AddPlaytime", function(citizenid, minutes)
    return Framework:AddPlaytime(citizenid, minutes)
end)

-- UpdateIdentity: rename / change DOB of one of the caller's own characters.
Framework:RegisterCallback("bablo-multicharacter:updateIdentity", function(src, data)
    local first, last, dob = SanitiseIdentity(data)
    local primary, secondary = getBothLicenses(src)
    if not (first and primary and data.id) then return false end
    local res = MySQL.update.await(
        "UPDATE `players` SET `charinfo` = JSON_SET(`charinfo`, '$.firstname', ?, '$.lastname', ?, '$.birthdate', ?) " ..
        "WHERE `citizenid` = ? AND (`license` = ? OR `license` = ?)",
        { first, last, dob, data.id, primary, secondary })
    return (res or 0) > 0
end)
