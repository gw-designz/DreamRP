-- Trace: debug-only logger. Accepts up to 7 arguments, converts each to string,
-- and prefixes with a timestamp (server-side only) and the resource name.
-- No-ops when Config.DEBUG is false/nil.
function Trace(...)
    if not Config.DEBUG then return end

    local args = { ... }
    local prefix = ""

    -- On the server (duplicity) prepend a human-readable timestamp.
    if IsDuplicityVersion() then
        prefix = os.date("%Y-%m-%d %H:%M:%S", os.time())
    end

    local resourceName = GetCurrentResourceName() or "LOG"
    prefix = prefix .. " [" .. resourceName .. "] "

    for i = 1, #args do
        prefix = prefix .. tostring(args[i]) .. " "
    end

    print(prefix)
end

-- IsResourceStartedOrStarting: return true if the named resource is started or starting.
function IsResourceStartedOrStarting(resourceName)
    local state = GetResourceState(resourceName)
    return state == "started" or state == "starting"
end

-- GenerateAccountNumber: produce a random account number from Config.AccountNumberPrefix.
-- Each 'X' in the pattern is replaced with a random digit 0–9; other characters are kept.
function GenerateAccountNumber()
    local pattern = Config.AccountNumberPrefix or "BXXXXXXXXX"
    local result  = ""
    for i = 1, #pattern do
        local ch = pattern:sub(i, i)
        if ch == "X" then
            result = result .. math.random(0, 9)
        else
            result = result .. ch
        end
    end
    return result
end

-- Translate: look up key in the active locale table.
-- If substitutions is provided (array), each replaces the next %s placeholder in order.
-- Returns the raw key if no locale or translation is found.
function Translate(key, substitutions)
    local locale = Config.Locale
    if not locale then return key end

    local localeTable = Locales and Locales[locale]
    if not localeTable then return key end

    local text = localeTable[key]
    if not text then return key end

    if substitutions then
        for i = 1, #substitutions do
            text = text:gsub("%%s", substitutions[i], 1)
        end
    end

    return text
end

-- TimestampToUnix: normalise a value to a Unix timestamp integer.
--   nil          → os.time() (now)
--   number       → returned as-is
--   string       → parsed as "YYYY-MM-DD HH:MM:SS"; falls back to os.time() on failure
function TimestampToUnix(value)
    if not value then
        return os.time()
    end

    if type(value) == "number" then
        return value
    end

    if type(value) == "string" then
        local yr, mo, dy, hr, mn, sc = value:match("(%d+)-(%d+)-(%d+) (%d+):(%d+):(%d+)")
        if yr then
            return os.time({
                year  = tonumber(yr),
                month = tonumber(mo),
                day   = tonumber(dy),
                hour  = tonumber(hr),
                min   = tonumber(mn),
                sec   = tonumber(sc),
            })
        end
    end

    return os.time()
end

-- Ensure: assert that value is of the expected type.
-- If value is nil and a default is provided, the default is returned.
-- If value is nil with no default, or has the wrong type, an error is raised.
function Ensure(value, expectedType, default)
    if value == nil then
        if default ~= nil then return default end
        error("Expected value of type " .. expectedType .. ", but got nil")
    end
    if type(value) ~= expectedType then
        error("Expected value of type " .. expectedType .. ", but got " .. type(value))
    end
    return value
end

-- SanitiseIdentity: validate an edit-identity payload from the NUI.
-- Returns firstname, lastname, dob ("YYYY-MM-DD") or nil when anything is off.
function SanitiseIdentity(data)
    if type(data) ~= "table" then return nil end
    local function name(v)
        if type(v) ~= "string" then return nil end
        v = v:gsub("^%s+", ""):gsub("%s+$", "")
        if #v < 2 or #v > 32 or v:find('[%c<>"\\`{}%[%]]') or v:find("%d") then return nil end
        return v
    end
    local first, last = name(data.firstName), name(data.lastName)
    local dob = type(data.dob) == "string" and data.dob:match("^%d%d%d%d%-%d%d%-%d%d$") and data.dob or nil
    if not (first and last and dob) then return nil end
    return first, last, dob
end
