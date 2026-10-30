if Config.Framework ~= "qbcore" then return end

-- QBCore shared object; populated once qb-core is started.
local QBCore = nil

CreateThread(function()
    while GetResourceState("qb-core") ~= "started" do
        Wait(50)
    end
    QBCore = exports["qb-core"]:GetCoreObject()
    Trace("[Framework/QBCore] Server initialised")
end)

-- ─── Local helpers ────────────────────────────────────────────────────────────

-- Return the license identifier for src, preferring QBCore's own getter when available.
local function getLicense(src)
    if QBCore and QBCore.Functions and QBCore.Functions.GetIdentifier then
        return QBCore.Functions.GetIdentifier(src, "license")
    end
    return GetPlayerIdentifierByType(src, "license")
end

-- Safely JSON-decode a string; returns a table or {} on failure / empty input.
local function safeJsonDecode(str)
    if not str or str == "" then return {} end
    local ok, result = pcall(json.decode, str)
    if ok and type(result) == "table" then return result end
    return {}
end

-- Normalise gender from QBCore's numeric / string format to "Male" / "Female".
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

    -- Grade label: prefer .name then .label, fall back to "".
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
        cash            = tonumber(money.cash)  or 0,
        bank            = tonumber(money.bank)  or 0,
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

-- ─── Framework methods ────────────────────────────────────────────────────────

-- FetchCharacters: return all character rows for src as normalised records.
function Framework:FetchCharacters(src)
    local license = getLicense(src)
    Trace(("[Framework/QBCore] FetchCharacters — src=%s license=%s"):format(
        tostring(src), tostring(license)))

    if not license then
        Trace(("[Framework/QBCore] FetchCharacters — no license for source=%s"):format(src))
        return {}
    end

    local rows = MySQL.query.await(
        "SELECT * FROM `players` WHERE `license` = ? ORDER BY `cid` ASC",
        { license }
    )
    local count = (rows and #rows) or 0
    Trace(("[Framework/QBCore] FetchCharacters — query returned %d row(s)"):format(count))

    if not rows or count == 0 then
        -- Debug aid: log all identifiers for the source so the operator can see
        -- whether the license in the DB matches the one being queried.
        Trace("[Framework/QBCore] FetchCharacters — no rows. Player identifiers:")
        for _, id in ipairs(GetPlayerIdentifiers(src)) do
            Trace(("[Framework/QBCore]   - %s"):format(id))
        end
        return {}
    end

    local chars = {}
    for _, row in ipairs(rows) do
        chars[#chars + 1] = buildCharacterRecord(row)
    end
    return chars
end

-- LoadCharacter: call QBCore.Player.Login, write spawn position if configured,
-- end any existing playtime session and start a new one.
function Framework:LoadCharacter(src, citizenid)
    if not QBCore then return false end

    -- Fetch saved position from DB (may be nil, which is fine for Login).
    local posRows = MySQL.query.await(
        "SELECT `position` FROM `players` WHERE `citizenid` = ?",
        { citizenid }
    )
    local savedPosition = (posRows and posRows[1] and posRows[1].position) or nil

    -- QBCore.Player.Login(src, citizenid, position)
    local loginOk = QBCore.Player.Login(src, citizenid, savedPosition)
    if not loginOk then return false end

    -- Wait up to 5 s for QBCore to register the player object.
    local deadline = GetGameTimer() + 5000
    while not QBCore.Functions.GetPlayer(src) and GetGameTimer() < deadline do
        Wait(10)
    end

    local xPlayer = QBCore.Functions.GetPlayer(src)
    if not xPlayer then return false end

    -- Optionally overwrite the DB position with Config.SpawnCoords so the
    -- character always starts at the same place on first load.
    Wait(250)
    if savedPosition and Config.SpawnCoords and Config.SpawnCoords.coords then
        local c = Config.SpawnCoords.coords
        MySQL.query.await(
            "UPDATE `players` SET `position` = ? WHERE `citizenid` = ?",
            { json.encode({ x = c.x + 0.0, y = c.y + 0.0, z = c.z + 0.0 }), citizenid }
        )
    end

    Playtime:EndSession(src)
    Playtime:StartSession(src, citizenid)
    return true
end

-- giveStarterItems: give QBCore StarterItems to a freshly created character.
-- Called internally after CreateCharacter succeeds.
local function giveStarterItems(src)
    if not QBCore then return end
    local xPlayer = QBCore.Functions.GetPlayer(src)
    if not xPlayer then return end

    local starterItems = QBCore.Shared and QBCore.Shared.StarterItems
    if not starterItems then return end

    for _, entry in pairs(starterItems) do
        local metadata = {}
        local pd = xPlayer.PlayerData

        if entry.item == "id_card" then
            metadata.citizenid  = pd.citizenid
            metadata.firstname  = pd.charinfo.firstname
            metadata.lastname   = pd.charinfo.lastname
            metadata.birthdate  = pd.charinfo.birthdate
            metadata.gender     = pd.charinfo.gender
            metadata.nationality = pd.charinfo.nationality
        elseif entry.item == "driver_license" then
            metadata.firstname  = pd.charinfo.firstname
            metadata.lastname   = pd.charinfo.lastname
            metadata.birthdate  = pd.charinfo.birthdate
            metadata.type       = "Class C Driver License"
        end

        xPlayer.Functions.AddItem(entry.item, entry.amount, false, metadata)
    end
end

-- CreateCharacter: allocate a new cid, call QBCore.Player.Login, optionally
-- write SpawnCoords to the DB, give starter items, start a playtime session.
-- Returns: success (bool), citizenid (string|nil)
function Framework:CreateCharacter(src, formData)
    if not QBCore then return false, nil end

    local license = getLicense(src)
    if not license then return false, nil end

    -- Find the next free cid for this license.
    local countRows = MySQL.query.await(
        "SELECT COUNT(*) AS n FROM `players` WHERE `license` = ?",
        { license }
    )
    local existingCount = (countRows and countRows[1] and tonumber(countRows[1].n)) or 0
    local newCid = existingCount + 1

    -- Generate a unique citizenid and build the charinfo payload.
    local citizenid = QBCore.Player.CreateCitizenId()

    local firstName = formData.firstName or formData.firstname or ""
    local lastName  = formData.lastName  or formData.lastname  or ""
    local gender    = 0
    if formData.gender == "Female" or formData.gender == "female" then
        gender = 1
    end

    local charinfo = {
        firstname   = firstName,
        lastname    = lastName,
        birthdate   = formData.dob or "",
        gender      = gender,
        height      = tonumber(formData.height) or 180,
        nationality = formData.nationality or "",
        phone       = QBCore.Functions.CreatePhoneNumber and QBCore.Functions.CreatePhoneNumber() or nil,
        account     = QBCore.Functions.CreateAccountNumber and QBCore.Functions.CreateAccountNumber() or nil,
    }

    local playerData = {
        cid       = newCid,
        citizenid = citizenid,
        license   = license,
        charinfo  = charinfo,
    }

    local loginOk = QBCore.Player.Login(src, false, playerData)
    if not loginOk then
        Trace("[Framework/QBCore] CreateCharacter — QBCore.Player.Login returned false")
        return false, nil
    end

    -- Wait up to 5 s for QBCore to register the player object.
    local deadline = GetGameTimer() + 5000
    while not QBCore.Functions.GetPlayer(src) and GetGameTimer() < deadline do
        Wait(10)
    end

    local xPlayer = QBCore.Functions.GetPlayer(src)
    if not xPlayer then
        Trace("[Framework/QBCore] CreateCharacter — player never settled after Login")
        return false, nil
    end

    -- Optionally write SpawnCoords to the DB.
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

    Trace(("[Framework/QBCore] CreateCharacter ok — citizenid=%s cid=%d"):format(
        tostring(xPlayer.PlayerData.citizenid), newCid))
    return true, xPlayer.PlayerData.citizenid
end

-- DeleteCharacter: verify the citizenid exists then delegate to QBCore.
function Framework:DeleteCharacter(src, citizenid)
    if Config.AllowCharacterDeletion == false then return false end

    if not QBCore then
        Trace("[Framework/QBCore] DeleteCharacter — QBCore not loaded yet")
        return false
    end

    if not src or not citizenid then return false end

    local exists = MySQL.scalar.await(
        "SELECT `citizenid` FROM `players` WHERE `citizenid` = ?",
        { citizenid }
    )
    if not exists then
        Trace(("[Framework/QBCore] DeleteCharacter — citizenid=%s not found"):format(citizenid))
        return false
    end

    QBCore.Player.DeleteCharacter(src, citizenid)
    Trace(("[Framework/QBCore] DeleteCharacter — citizenid=%s deleted"):format(citizenid))
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

-- IsAdmin: return true if src has QBCore's admin/god permission or the "command" ace.
function Framework:IsAdmin(src)
    src = tonumber(src)
    if not src then return false end

    if QBCore and QBCore.Functions and QBCore.Functions.HasPermission then
        if QBCore.Functions.HasPermission(src, "admin") or
           QBCore.Functions.HasPermission(src, "god") then
            return true
        end
    end

    return IsPlayerAceAllowed(src, "command")
end

-- LogoutCharacter: call QBCore.Player.Logout for src.
function Framework:LogoutCharacter(src)
    src = tonumber(src)
    if not src then return false end
    if not (QBCore and QBCore.Player and QBCore.Player.Logout) then return false end
    QBCore.Player.Logout(src)
    return true
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
    local license = getLicense(src)
    if not (first and license and data.id) then return false end
    local res = MySQL.update.await(
        "UPDATE `players` SET `charinfo` = JSON_SET(`charinfo`, '$.firstname', ?, '$.lastname', ?, '$.birthdate', ?) " ..
        "WHERE `citizenid` = ? AND `license` = ?",
        { first, last, dob, data.id, license })
    return (res or 0) > 0
end)
