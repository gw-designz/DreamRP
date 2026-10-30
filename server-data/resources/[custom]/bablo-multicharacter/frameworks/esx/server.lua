Trace(("[Framework/ESX] server.lua loading — Config.Framework=%s"):format(tostring(Config.Framework)))
if Config.Framework ~= "esx" then return end

-- ESX shared object; populated asynchronously once es_extended is started.
local ESX = nil

-- Job label cache: jobLabels[jobName] = displayLabel (e.g. "Police Officer")
-- Job grade cache: jobGrades[jobName][gradeNumber] = gradeLabel (e.g. "Lieutenant")
local jobLabels = {}
local jobGrades = {}

-- ─── ESX initialisation ───────────────────────────────────────────────────────

CreateThread(function()
    while GetResourceState("es_extended") ~= "started" do
        Wait(50)
    end

    local ok, obj = pcall(function() return exports.es_extended:getSharedObject() end)
    ESX = (ok and obj) or _G.ESX

    Trace(("[Framework/ESX] Server initialised — ESX=%s"):format(ESX and "OK" or "NIL"))
end)

-- ─── Job / grade label cache ──────────────────────────────────────────────────

MySQL.ready(function()
    -- Load job display labels.
    local ok, rows = pcall(function()
        return MySQL.query.await("SELECT `name`, `label` FROM `jobs`")
    end)
    if ok and rows then
        for _, row in ipairs(rows) do
            jobLabels[row.name] = row.label
        end
    end

    -- Load grade labels per job.
    ok, rows = pcall(function()
        return MySQL.query.await("SELECT `job_name`, `grade`, `label` FROM `job_grades`")
    end)
    if ok and rows then
        for _, row in ipairs(rows) do
            local jobName = row.job_name
            if not jobGrades[jobName] then jobGrades[jobName] = {} end
            jobGrades[jobName][tonumber(row.grade)] = row.label
        end
    end

    -- Count entries for the log.
    local jobCount, gradeSetCount = 0, 0
    for _ in pairs(jobLabels) do jobCount      = jobCount      + 1 end
    for _ in pairs(jobGrades) do gradeSetCount = gradeSetCount + 1 end
    Trace(("[Framework/ESX] Job label cache ready — %d job(s), %d grade-set(s)"):format(
        jobCount, gradeSetCount))
end)

-- ─── Local helpers ────────────────────────────────────────────────────────────

-- Return the bare license hash for src (strips the "license:" prefix if present).
local function getLicense(src)
    local raw = GetPlayerIdentifierByType(src, "license")
    if not raw then return nil end
    local colonPos = string.find(raw, ":")
    return colonPos and string.sub(raw, colonPos + 1) or raw
end

-- Safely JSON-decode a string; returns a table or {} on failure.
local function safeJsonDecode(str)
    if not str or str == "" then return {} end
    local ok, result = pcall(json.decode, str)
    if ok and type(result) == "table" then return result end
    return {}
end

-- Extract the numeric character slot from an ESX identifier like "char3:license123".
-- Returns nil if the format doesn't match.
local function extractSlot(identifier)
    return tonumber(identifier:match("^char(%d+):"))
end

-- Normalise a raw `sex` value from the DB ("f", "F", 1) to "Female" / "Male".
local function normaliseSex(raw)
    if raw == "f" or raw == "F" or raw == 1 then return "Female" end
    return "Male"
end

-- Build the normalised character record sent to the client.
local function buildCharacterRecord(row)
    local accounts  = safeJsonDecode(row.accounts)
    local position  = safeJsonDecode(row.position)
    local gender    = normaliseSex(row.sex)

    local jobName   = row.job or "unemployed"
    local jobGrade  = tonumber(row.job_grade) or 0
    local jobLabel  = jobLabels[jobName] or jobName

    local gradeLabel
    if jobGrades[jobName] then
        gradeLabel = jobGrades[jobName][jobGrade]
    end
    if not gradeLabel then gradeLabel = tostring(jobGrade) end

    local firstname = row.firstname or ""
    local lastname  = row.lastname  or ""
    local fullName  = (firstname .. " " .. lastname):gsub("^%s+", ""):gsub("%s+$", "")

    local lastLocation
    if position.x then
        lastLocation = { x = position.x, y = position.y, z = position.z }
    end

    return {
        id              = row.identifier,
        cid             = extractSlot(row.identifier) or 0,
        name            = fullName,
        firstname       = firstname,
        lastname        = lastname,
        gender          = gender,
        dob             = row.dateofbirth or "",
        cash            = tonumber(accounts.money) or 0,
        bank            = tonumber(accounts.bank)  or 0,
        playtimeMinutes = tonumber(row.playtime)   or 0,
        job             = jobName,
        jobLabel        = jobLabel,
        jobGrade        = gradeLabel,
        bio             = "",
        lastLocation    = lastLocation,
        _skin           = Appearance:FetchSkin(row.identifier),
        houses          = nil,
    }
end

-- ─── Framework methods ────────────────────────────────────────────────────────

-- FetchCharacters: return all character rows for src as normalised records.
function Framework:FetchCharacters(src)
    local license = getLicense(src)
    Trace(("[Framework/ESX] FetchCharacters — src=%s license=%s"):format(
        tostring(src), tostring(license)))

    if not license then return {} end

    local rows = MySQL.query.await(
        "SELECT * FROM `users` WHERE `identifier` LIKE ? ORDER BY `identifier` ASC",
        { "char%:" .. license }
    )
    local count = (rows and #rows) or 0
    Trace(("[Framework/ESX] FetchCharacters — query returned %d row(s)"):format(count))

    if not rows or count == 0 then return {} end

    local chars = {}
    for _, row in ipairs(rows) do
        chars[#chars + 1] = buildCharacterRecord(row)
    end
    return chars
end

-- LoadCharacter: trigger esx:onPlayerJoined, wait for xPlayer to settle,
-- store the active character identifier in player state, and start a playtime session.
function Framework:LoadCharacter(src, identifier)
    if not src or not identifier then return false end

    local slot = extractSlot(identifier)
    if not slot then
        Trace(("[Framework/ESX] LoadCharacter — could not extract slot from %s"):format(tostring(identifier)))
        return false
    end

    local exists = MySQL.scalar.await(
        "SELECT `identifier` FROM `users` WHERE `identifier` = ?",
        { identifier }
    )
    if not exists then
        Trace(("[Framework/ESX] LoadCharacter — row %s does not exist"):format(identifier))
        return false
    end

    -- Determine what to pass as the identifier to ESX: full identifier or short "charN" form.
    local esxIdentifier
    if Config.ESXPassFullIdentifier and identifier then
        esxIdentifier = identifier
    else
        esxIdentifier = "char" .. slot
    end

    TriggerEvent("esx:onPlayerJoined", src, esxIdentifier)

    -- Wait up to 5 s for ESX to register the player.
    local deadline = GetGameTimer() + 5000
    while ESX and ESX.GetPlayerFromId and ESX.GetPlayerFromId(src) == nil and GetGameTimer() < deadline do
        Wait(0)
    end

    if not ESX or not ESX.GetPlayerFromId or not ESX.GetPlayerFromId(src) then
        Trace("[Framework/ESX] LoadCharacter — xPlayer never settled after esx:onPlayerJoined")
        return false
    end

    Player(src).state:set("bablo_active_char", identifier, true)
    Playtime:EndSession(src)
    Playtime:StartSession(src, identifier)

    Trace(("[Framework/ESX] LoadCharacter ok — identifier=%s"):format(identifier))
    return true
end

-- CreateCharacter: allocate the next free slot, INSERT via esx:onPlayerJoined,
-- optionally write SpawnCoords to the DB, start a playtime session.
-- Returns: success (bool), newIdentifier (string|nil)
function Framework:CreateCharacter(src, formData)
    local license = getLicense(src)
    if not license then return false, nil end

    -- Find the highest existing slot number for this license.
    local rows = MySQL.query.await(
        "SELECT `identifier` FROM `users` WHERE `identifier` LIKE ?",
        { "char%:" .. license }
    )
    local maxSlot = 0
    for _, row in ipairs(rows or {}) do
        local s = extractSlot(row.identifier)
        if s and s > maxSlot then maxSlot = s end
    end

    local newSlot       = maxSlot + 1
    local newIdentifier = "char" .. newSlot .. ":" .. license

    -- Trim and normalise nationality.
    local nationality = formData.nationality
    if nationality then
        nationality = nationality:gsub("^%s+", ""):gsub("%s+$", "")
        if nationality == "" then nationality = nil end
    end

    -- Determine what to pass as the ESX identifier.
    local esxIdentifier
    if Config.ESXPassFullIdentifier and newIdentifier then
        esxIdentifier = newIdentifier
    else
        esxIdentifier = "char" .. newSlot
    end

    -- Normalise first/last name (accept both cases).
    local firstName = (formData.firstName or formData.firstname or "")
    local lastName  = (formData.lastName  or formData.lastname  or "")

    -- Normalise gender to ESX's single-character format.
    local sex = "m"
    if formData.gender == "Female" or formData.gender == "female" then
        sex = "f"
    end

    local charInfo = {
        firstname   = firstName,
        lastname    = lastName,
        sex         = sex,
        height      = tonumber(formData.height) or 180,
        dateofbirth = formData.dob or "",
        nationality = nationality,
    }

    TriggerEvent("esx:onPlayerJoined", src, esxIdentifier, charInfo)

    -- Wait up to 5 s for ESX to register the player.
    local deadline = GetGameTimer() + 5000
    while ESX and ESX.GetPlayerFromId and ESX.GetPlayerFromId(src) == nil and GetGameTimer() < deadline do
        Wait(0)
    end

    if not ESX or not ESX.GetPlayerFromId or not ESX.GetPlayerFromId(src) then
        Trace("[Framework/ESX] CreateCharacter — xPlayer never settled")
        return false, nil
    end

    -- Optionally write the spawn position to the DB immediately so the character
    -- starts at the right location even before the client-side spawn runs.
    local spawnCfg = Config.SpawnCoords
    if spawnCfg and spawnCfg.coords then
        local c = spawnCfg.coords
        MySQL.query.await(
            "UPDATE `users` SET `position` = ? WHERE `identifier` = ?",
            { json.encode({ x = c.x + 0.0, y = c.y + 0.0, z = c.z + 0.0 }), newIdentifier }
        )
    end

    Player(src).state:set("bablo_active_char", newIdentifier, true)
    Playtime:EndSession(src)
    Playtime:StartSession(src, newIdentifier)

    Trace(("[Framework/ESX] CreateCharacter ok — identifier=%s slot=%d"):format(newIdentifier, newSlot))
    return true, newIdentifier
end

-- DeleteCharacter: verify ownership then DELETE the row.
function Framework:DeleteCharacter(src, identifier)
    if Config.AllowCharacterDeletion == false then return false end
    if not src or not identifier then return false end

    local license = getLicense(src)
    if not license then return false end

    -- Ensure the identifier actually ends with this player's license.
    if not identifier:find(":" .. license .. "$") then
        Trace(("[Framework/ESX] DeleteCharacter — id=%s does not belong to license %s"):format(
            identifier, license))
        return false
    end

    local result = MySQL.query.await(
        "DELETE FROM `users` WHERE `identifier` = ?",
        { identifier }
    )
    local affected = (result and result.affectedRows) or 0
    if affected > 0 then
        Trace(("[Framework/ESX] DeleteCharacter — identifier=%s deleted"):format(identifier))
        return true
    end
    return false
end

-- GetPlaytime: return stored playtime minutes for citizenid, or 0.
function Framework:GetPlaytime(citizenid)
    if not citizenid then return 0 end
    local rows = MySQL.query.await(
        "SELECT `playtime` FROM `users` WHERE `identifier` = ?",
        { citizenid }
    )
    return (rows and rows[1] and tonumber(rows[1].playtime)) or 0
end

-- AddPlaytime: increment playtime in the DB by minutes.
function Framework:AddPlaytime(citizenid, minutes)
    if not citizenid or not minutes or minutes <= 0 then return end
    MySQL.query.await(
        "UPDATE `users` SET `playtime` = `playtime` + ? WHERE `identifier` = ?",
        { minutes, citizenid }
    )
end

-- IsAdmin: return true if src has an ESX admin/superadmin/god group or the
-- "command" ace permission.
function Framework:IsAdmin(src)
    src = tonumber(src)
    if not src then return false end

    if ESX and ESX.GetPlayerFromId then
        local xPlayer = ESX.GetPlayerFromId(src)
        if xPlayer and xPlayer.getGroup then
            local group = xPlayer.getGroup()
            if group == "admin" or group == "superadmin" or group == "god" then
                return true
            end
        end
    end

    return IsPlayerAceAllowed(src, "command")
end

-- LogoutCharacter: trigger esx:playerLogout for the given src.
function Framework:LogoutCharacter(src)
    src = tonumber(src)
    if not src then return false end
    TriggerEvent("esx:playerLogout", src, function() end)
    return true
end

-- ─── Position save on disconnect ─────────────────────────────────────────────

-- Save the last known position for a player when they drop.
local function saveLastPosition(src)
    if not ESX then return end
    local xPlayer = ESX.GetPlayerFromId and ESX.GetPlayerFromId(src)
    if not xPlayer then return end

    local identifier = xPlayer.identifier
    if not identifier then return end

    local coords = xPlayer.getCoords and xPlayer.getCoords(true)
    if not coords or not coords.x then return end

    MySQL.query(
        "UPDATE `users` SET `position` = ? WHERE `identifier` = ?",
        { json.encode({ x = coords.x + 0.0, y = coords.y + 0.0, z = coords.z + 0.0 }), identifier }
    )
    Trace(("[Framework/ESX] saved last position for identifier=%s @ (%.2f, %.2f, %.2f)"):format(
        identifier, coords.x, coords.y, coords.z))
end

AddEventHandler("playerDropped", function()
    saveLastPosition(source)
end)

AddEventHandler("onResourceStop", function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    if not ESX then return end
    for _, src in ipairs(GetPlayers()) do
        saveLastPosition(tonumber(src))
    end
end)

-- ─── lib.callback registrations ──────────────────────────────────────────────

Framework:RegisterCallback("bablo-multicharacter:fetchCharacters", function(src)
    return Framework:FetchCharacters(src)
end)

Framework:RegisterCallback("bablo-multicharacter:loadCharacter", function(src, identifier)
    return Framework:LoadCharacter(src, identifier)
end)

Framework:RegisterCallback("bablo-multicharacter:createCharacter", function(src, formData)
    return Framework:CreateCharacter(src, formData)
end)

Framework:RegisterCallback("bablo-multicharacter:deleteCharacter", function(src, identifier)
    return Framework:DeleteCharacter(src, identifier)
end)

-- fetchActiveSkin: used by the client for skinchanger/codem-appearance to get the
-- skin data of the player's currently loaded character.
Framework:RegisterCallback("bablo-multicharacter:fetchActiveSkin", function(src)
    local state = Player(src).state
    local activeChar = state and state.bablo_active_char
    if not activeChar then
        Trace(("[Framework/ESX] fetchActiveSkin — no bablo_active_char for src=%s"):format(tostring(src)))
        return nil
    end
    return Appearance:FetchSkin(activeChar)
end)

-- ─── Exports ──────────────────────────────────────────────────────────────────

exports("FetchCharacters", function(src)
    return Framework:FetchCharacters(src)
end)

exports("LoadCharacter", function(src, identifier)
    return Framework:LoadCharacter(src, identifier)
end)

exports("CreateCharacter", function(src, formData)
    return Framework:CreateCharacter(src, formData)
end)

exports("DeleteCharacter", function(src, identifier)
    return Framework:DeleteCharacter(src, identifier)
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

Trace("[Framework/ESX] server.lua done — lib.callback.register completed for fetchCharacters/loadCharacter/createCharacter/deleteCharacter")

-- UpdateIdentity: rename / change DOB of one of the caller's own characters.
Framework:RegisterCallback("bablo-multicharacter:updateIdentity", function(src, data)
    local first, last, dob = SanitiseIdentity(data)
    local license = getLicense(src)
    if not (first and license and type(data.id) == "string") then return false end
    if not data.id:find(":" .. license .. "$", 1, false) then return false end
    local res = MySQL.update.await(
        "UPDATE `users` SET `firstname` = ?, `lastname` = ?, `dateofbirth` = ? WHERE `identifier` = ?",
        { first, last, dob, data.id })
    return (res or 0) > 0
end)
