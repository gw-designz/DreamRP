Utils = {}

function Utils.IsFiniteNumber(v)
    return type(v) == 'number' and v == v and v ~= math.huge and v ~= -math.huge
end

---Clamp-and-validate a number, returns nil when it is not a finite number.
function Utils.Num(v, min, max)
    v = tonumber(v)
    if not Utils.IsFiniteNumber(v) then return nil end
    if min and v < min then return nil end
    if max and v > max then return nil end
    return v
end

---Trim a string and cap its length. Returns nil if not a string.
function Utils.Str(v, max)
    if type(v) ~= 'string' then return nil end
    v = v:gsub('^%s+', ''):gsub('%s+$', '')
    if max and #v > max then v = v:sub(1, max) end
    return v
end

---Strip control characters (keeps normal unicode).
function Utils.Clean(v, max)
    v = Utils.Str(v, max)
    if not v then return nil end
    return (v:gsub('[%c]', ''))
end

local MAX = Config.Limits.MaxCoord
function Utils.ValidCoords(c)
    if type(c) ~= 'table' then return nil end
    local x, y, z = Utils.Num(c.x, -MAX, MAX), Utils.Num(c.y, -MAX, MAX), Utils.Num(c.z, -1000.0, 3000.0)
    if not (x and y and z) then return nil end
    local h = Utils.Num(c.h or 0.0, -720.0, 720.0) or 0.0
    return { x = x + 0.0, y = y + 0.0, z = z + 0.0, h = h + 0.0 }
end

function Utils.Dist(a, b)
    local dx, dy, dz = a.x - b.x, a.y - b.y, a.z - b.z
    return math.sqrt(dx * dx + dy * dy + dz * dz)
end

---ID safe for use as a database key and in statebags.
function Utils.ValidId(id)
    return type(id) == 'string' and #id >= 1 and #id <= 50 and id:match('^[%w_%-]+$') ~= nil
end

function Utils.CommandById(id)
    for i = 1, #Config.Commands do
        if Config.Commands[i].id == id then return Config.Commands[i] end
    end
end
