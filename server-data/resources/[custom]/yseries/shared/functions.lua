if not IsDuplicityVersion() then
    local lastInteraction = 0

    function CanInteract()
        if lastInteraction + 500 > GetGameTimer() then
            return false
        end

        lastInteraction = GetGameTimer()
        return true
    end
end

Config.ExtendedDebugPrintDebugPrint = false

function debugPrint(...)
    if not Config?.DebugPrint then
        return
    end

    local args = { ... }
    local appendStr = ''
    for _, v in ipairs(args) do
        appendStr = appendStr .. ' ' .. tostring(v or 'nil')
    end

    -- If the first argument is a table, print it as a table.
    if type(args[1]) == "table" then
        DebugTable(args[1])
        return
    end

    -- Only get file and line info if extended debug is enabled
    if Config.ExtendedDebugPrint then
        local info = debug.getinfo(2, "Sl")
        local fileName = "unknown"

        if info and info.source then
            fileName = info.source:match("@?([^/\\]-)$") or "unknown"
            fileName = fileName:gsub(".lua", "")
        end

        local lineNumber = info.currentline
        local finalMsg = string.format("^2[%s:%d]^0%s", fileName, lineNumber, appendStr)
        print(finalMsg)
    else
        -- Simple debug print without file and line info
        print(appendStr)
    end
end

--- This will print the table in JSON like format to the console.
---@param tbl any The table to print.
function DebugTable(tbl)
    if not Config.DebugPrint then
        return
    end

    if type(tbl) ~= "table" then
        debugPrint("Invalid input. Expected a table.")
        return
    end

    local function printTableHelper(tbl, indent)
        indent = indent or 0
        local indentStr = string.rep("  ", indent)

        for key, value in pairs(tbl) do
            if type(value) == "table" then
                print(indentStr .. key .. " = {")
                printTableHelper(value, indent + 1)
                print(indentStr .. "}")
            else
                print(indentStr .. key .. " = " .. tostring(value))
            end
        end
    end

    printTableHelper(tbl)
end

--- Coerces MySQL-style numeric flags (`1`/`0`), Lua booleans, or `nil` to a strict boolean.
--- Note: framework helpers such as `IsPlayerAceAllowed` return Lua `true`/`false`, not `1`/`0`.
--- @param value any
--- @return boolean
function IntToBool(value)
    if value == true or value == 1 then
        return true
    end
    return false
end

--- Truncate a string without exceeding the requested max length.
---@param s string The source string to truncate.
---@param maxLength number The maximum allowed length for the returned string.
---@return string
function trimString(s, maxLength)
    if #s <= maxLength then
        return s
    end

    if maxLength <= 3 then
        return s:sub(1, maxLength)
    end

    return s:sub(1, maxLength - 3) .. "..."
end

function Imei(imei)
    if not imei then return nil end

    return string.gsub(imei, ':boomer', '')
end
