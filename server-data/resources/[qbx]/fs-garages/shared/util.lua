--[[
    fs-garages / shared/util.lua

    Small helpers both sides use, and the words in the configured language.
]]

Garage = Garage or {}
Garage.util = Garage.util or {}

local util = Garage.util

function util.debug(...)
    if Config.Debug then print('^5[fs-garages]^7', ...) end
end

function util.error(message)
    print('^1[fs-garages]^7 ' .. tostring(message))
end

--- A plain number that is not NaN or infinite.
function util.number(value)
    return type(value) == 'number' and value == value and value ~= math.huge and value ~= -math.huge
end

function util.clamp(value, low, high)
    if value < low then return low end
    if value > high then return high end
    return value
end

function util.contains(list, wanted)
    for _, value in ipairs(list or {}) do
        if value == wanted then return true end
    end
    return false
end

--[[
    Every garage, as made in the creator (server/garages.lua).

    Reading GlobalState hands back a fresh copy of the whole list each time,
    every garage and every space unpacked again. The parking loop asks many
    times a second, so the list is kept here and only taken again when the
    server changes it.
]]
local kept = nil

function Garage.list()
    if not kept then kept = GlobalState.fsGarages or {} end
    return kept
end

--- The server hands its own new list over here as it shares it.
function Garage.setList(list)
    kept = list
end

AddStateBagChangeHandler('fsGarages', 'global', function(_, _, value)
    kept = value or {}
end)

--- The garage with this id, and where it is in the list.
function util.garage(id)
    for index, garage in ipairs(Garage.list()) do
        if garage.id == id then return garage, index end
    end
end

--- A number plate as it is compared: upper case, no spaces round it.
function util.plate(text)
    return (tostring(text or ''):upper():gsub('^%s+', ''):gsub('%s+$', ''))
end

--- Files a model name under its hash, both ways the game may hand a hash
--- out (as a plain or as a negative number).
function util.nameHash(map, name)
    local hash = GetHashKey(name)
    map[hash] = name
    if hash < 0 then map[hash + 4294967296] = name else map[hash - 4294967296] = name end
end

--- Flat distance between two points with x and y.
function util.flat(a, b)
    return math.sqrt((a.x - b.x) ^ 2 + (a.y - b.y) ^ 2)
end

--- Whole dollars, with thousands marked: 1250 -> "$1,250".
function util.money(amount)
    local text = tostring(math.floor((tonumber(amount) or 0) + 0.5))
    local out = text:reverse():gsub('(%d%d%d)', '%1,'):reverse()
    return '$' .. out:gsub('^,', '')
end

-- ── words ──────────────────────────────────────────────────────────────

function L(key, ...)
    local words = Locales[Config.Locale] or Locales['en'] or {}
    local text = words[key] or (Locales['en'] and Locales['en'][key]) or key
    if select('#', ...) > 0 then
        return text:format(...)
    end
    return text
end
