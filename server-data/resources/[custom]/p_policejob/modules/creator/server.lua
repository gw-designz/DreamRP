while true do
    if Config and Config.Creator then break end
    Citizen.Wait(500)
end

if not Config.Creator.enabled then return end

-- Map type → directory path relative to resource root
local MAP_DIRS = {
    departments = "maps/departments",
    prisons     = "maps/prisons",
}

-- ============================================================
--  Access checks
-- ============================================================

-- Returns true if the player's job grants creator access
local function checkJobAccess(playerSource)
    local job = Bridge.Framework.getPlayerJob(playerSource)
    if not job or not job.name then return false end

    local accessLevel = Config.Creator.access[job.name]
    if accessLevel == nil then return false end

    -- If access is a number, treat it as a minimum grade requirement
    if type(accessLevel) == "number" then
        local grade = job.grade or 0
        if accessLevel > grade then return false end
    end

    return true
end

-- Returns true if the player is an admin (ace) OR has job access
local function canAccess(playerSource)
    if Config.Creator.allowAdmins and Config.Creator.adminPermission then
        if IsPlayerAceAllowed(playerSource, Config.Creator.adminPermission) then
            return true
        end
    end
    return checkJobAccess(playerSource)
end

lib.callback.register("p_policejob/server/creator/canAccess", canAccess)

-- ============================================================
--  File listing
-- ============================================================

-- Returns a sorted list of .lua filenames inside a map directory.
-- Tries Windows (dir) then Unix (ls) shell commands.
local function listMapFiles(mapType)
    local relDir = MAP_DIRS[mapType]
    if not relDir then return {} end

    local resourcePath = GetResourcePath(GetCurrentResourceName())
    local fullDir      = ("%s/%s/"):format(resourcePath, relDir)

    local files   = {}
    local winCmd  = ('dir "%s" /b 2>nul'):format(fullDir:gsub("/", "\\"))
    local unixCmd = ('ls -1 "%s" 2>/dev/null'):format(fullDir)

    for _, cmd in ipairs({ winCmd, unixCmd }) do
        local handle = io.popen(cmd)
        if handle then
            for line in handle:lines() do
                if line:match("%.lua$") then
                    files[#files + 1] = line
                end
            end
            handle:close()
        end
        if #files > 0 then break end
    end

    table.sort(files)
    return files
end

-- ============================================================
--  Safe data sanitiser (max depth 12, strips non-primitive keys)
-- ============================================================

local function sanitiseData(value, depth)
    depth = depth or 0
    if depth > 12 then return nil end

    local t = type(value)
    if t == "string" or t == "number" or t == "boolean" then return value end
    if t ~= "table" then return nil end

    local out = {}
    for k, v in pairs(value) do
        local kt = type(k)
        if kt == "string" or kt == "number" then
            local sanitised = sanitiseData(v, depth + 1)
            if sanitised ~= nil then
                out[k] = sanitised
            end
        end
    end
    return out
end

-- ============================================================
--  Net events
-- ============================================================

RegisterNetEvent("p_policejob/server/creator/getFiles", function(mapType)
    local playerSource = source
    if not canAccess(playerSource) then return end
    if not MAP_DIRS[mapType] then return end

    local fileList = listMapFiles(mapType)
    TriggerClientEvent("p_policejob/client/creator/fileList", playerSource, mapType, fileList)
end)

-- ============================================================
--  Save a map file (write Lua code to disk)
-- ============================================================

RegisterNetEvent("p_policejob/server/creator/saveFile", function(mapType, fileName, luaContent)
    local playerSource = source
    if not canAccess(playerSource) then return end
    if not MAP_DIRS[mapType] then return end
    if type(fileName) ~= "string" or type(luaContent) ~= "string" then return end

    -- Sanitise filename (same rules as loadFile)
    fileName = fileName:gsub("[/\\]+", ""):gsub("%.%.", "")
    if not fileName:match("^[%w_%-%.]+%.lua$") then return end

    -- Enforce a reasonable size limit (512 KB)
    if #luaContent > 524288 then
        return Bridge.Notify.showNotify(playerSource, "File too large to save", "error")
    end

    local resourcePath = GetResourcePath(GetCurrentResourceName())
    local filePath     = ("%s/%s/%s"):format(resourcePath, MAP_DIRS[mapType], fileName)

    local file = io.open(filePath, "w")
    if not file then
        lib.print.error(("[Creator] Failed to open %s for writing"):format(filePath))
        return Bridge.Notify.showNotify(playerSource, locale("creator_map_load_failed"), "error")
    end

    file:write(luaContent)
    file:close()

    Bridge.Notify.showNotify(playerSource,
        ("Map file saved: %s"):format(fileName), "success")
    Bridge.Debug(("[Creator] Player %s saved map file: %s/%s"):format(
        playerSource, mapType, fileName))
end)

RegisterNetEvent("p_policejob/server/creator/loadFile", function(mapType, fileName)
    local playerSource = source
    if not canAccess(playerSource) then return end
    if not MAP_DIRS[mapType] then return end
    if type(fileName) ~= "string" then return end

    -- Sanitise filename: strip path separators and traversal attempts
    fileName = fileName:gsub("[/\\]+", ""):gsub("%.%.", "")

    -- Must be a simple alphanumeric .lua filename
    if not fileName:match("^[%w_%-%.]+%.lua$") then return end

    local resourcePath = GetResourcePath(GetCurrentResourceName())
    local filePath     = ("%s/%s/%s"):format(resourcePath, MAP_DIRS[mapType], fileName)

    local file = io.open(filePath, "r")
    if not file then
        return Bridge.Notify.showNotify(playerSource, locale("creator_map_load_failed"), "error")
    end

    local source = file:read("*a")
    file:close()

    -- Sandbox: stub out constructors that return plain tables
    local function vecStub(...) return { (...) } end
    local sandbox = setmetatable({
        vec2     = vecStub, vec3     = vecStub, vec4     = vecStub,
        vector2  = vecStub, vector3  = vecStub, vector4  = vecStub,
        locale     = tostring,
        joaat      = function(v) return v end,
        GetHashKey = function(v) return v end,
    }, { __index = function() return function() return "" end end })

    local chunk, parseErr = load(source, fileName, "t", sandbox)
    if not chunk then
        lib.print.error(("[Creator] Failed to parse %s: %s"):format(fileName, parseErr))
        return Bridge.Notify.showNotify(playerSource, locale("creator_map_load_failed"), "error")
    end

    local ok, mapData = pcall(chunk)
    if not ok or type(mapData) ~= "table" then
        lib.print.error(("[Creator] Failed to execute %s: %s"):format(fileName, tostring(mapData)))
        return Bridge.Notify.showNotify(playerSource, locale("creator_map_load_failed"), "error")
    end

    TriggerClientEvent("p_policejob/client/creator/loadedMap", playerSource, mapType, fileName, sanitiseData(mapData))
end)
