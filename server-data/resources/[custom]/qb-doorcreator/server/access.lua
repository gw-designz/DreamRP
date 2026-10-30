--[[
    server/access.lua

    Everything to do with deciding "can THIS player operate THIS door
    right now" lives here. server/main.lua calls Access.Evaluate() and
    nothing else in the resource re-implements permission logic, so
    there is exactly one place access rules can go wrong.

    THE ACCESS-CHECK FLOW (see spec section 4)
    Access.Evaluate() runs the categories in a fixed priority order:

        1. Permission bypass      - staff/admin override, ALWAYS wins
        2. Owner identifier       - citizenid/license allow-list (house doors)
        3. Job + min grade
        4. Gang + min grade
        5. Key item (keyring)     - generic key item tagged with this door id
        6. Required item          - consumable or not
        7. Password                - needs a client round-trip, see below

    Each door's access.mode decides how these combine:
        "any" (default) - first category that passes wins, short-circuit.
                           This is why the order above matters: permission
                           is checked first because it is a hard bypass,
                           password is checked LAST because unlike every
                           other category it cannot be answered from data
                           we already have. It requires prompting the
                           player, so that cost is only paid if nothing
                           cheaper already granted access.
        "all"  - every category that has at least one rule CONFIGURED
                 on the door must pass. Categories with zero rules are
                 skipped, so an admin who never added a job rule is not
                 accidentally requiring "no job" to be true.

    Password is special in BOTH modes: because checking it requires
    asking the player for input, Access.Evaluate() never blocks on it.
    Instead it reports needsPassword = true when password is the ONLY
    thing standing between the player and access, and the caller
    (server/main.lua) is responsible for requesting the password from
    the client and then calling Access.VerifyPassword() separately.

    A door with a completely empty access object (no rules in ANY
    category, password disabled, no permission set) is treated as a
    PUBLIC door, openable by anyone. That matches how most door-lock
    scripts expect an "unconfigured" door to behave.
]]

Access = {}

-- ----------------------------------------------------------------
-- Pure Lua 5.4 SHA-256
--
-- FXServer's server-side Lua runtime does not expose any crypto
-- natives (those are game natives, not general-purpose crypto), and
-- we do not want a hard dependency on an external bcrypt binary
-- module just to hash a door code. This is a small, self-contained
-- SHA-256 implementation using Lua 5.4's native 64-bit integers and
-- bitwise operators (fx_version cerulean + lua54 "yes" guarantees
-- these are available). It is not used for anything security-critical
-- beyond "do not store door codes in plaintext" - see
-- Config.PasswordHashing if you want to swap in a real bcrypt module.
-- ----------------------------------------------------------------

local SHA256_K = {
    0x428a2f98,0x71374491,0xb5c0fbcf,0xe9b5dba5,0x3956c25b,0x59f111f1,0x923f82a4,0xab1c5ed5,
    0xd807aa98,0x12835b01,0x243185be,0x550c7dc3,0x72be5d74,0x80deb1fe,0x9bdc06a7,0xc19bf174,
    0xe49b69c1,0xefbe4786,0x0fc19dc6,0x240ca1cc,0x2de92c6f,0x4a7484aa,0x5cb0a9dc,0x76f988da,
    0x983e5152,0xa831c66d,0xb00327c8,0xbf597fc7,0xc6e00bf3,0xd5a79147,0x06ca6351,0x14292967,
    0x27b70a85,0x2e1b2138,0x4d2c6dfc,0x53380d13,0x650a7354,0x766a0abb,0x81c2c92e,0x92722c85,
    0xa2bfe8a1,0xa81a664b,0xc24b8b70,0xc76c51a3,0xd192e819,0xd6990624,0xf40e3585,0x106aa070,
    0x19a4c116,0x1e376c08,0x2748774c,0x34b0bcb5,0x391c0cb3,0x4ed8aa4a,0x5b9cca4f,0x682e6ff3,
    0x748f82ee,0x78a5636f,0x84c87814,0x8cc70208,0x90befffa,0xa4506ceb,0xbef9a3f7,0xc67178f2,
}
local MASK32 = 0xFFFFFFFF

local function rrotate(x, n)
    return ((x >> n) | (x << (32 - n))) & MASK32
end

--- Computes the SHA-256 digest of msg and returns it as a 64-char
--- lowercase hex string. Pure function, no external state.
local function sha256(msg)
    local h0,h1,h2,h3,h4,h5,h6,h7 =
        0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a,
        0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19

    -- Padding: 0x80 byte, zero bytes until length % 64 == 56, then the
    -- original bit-length as a big-endian 64-bit integer.
    local bitLen = #msg * 8
    local padded = msg .. '\128'
    while (#padded % 64) ~= 56 do
        padded = padded .. '\0'
    end
    padded = padded .. string.pack('>I8', bitLen)

    for chunkStart = 1, #padded, 64 do
        local w = {}
        for i = 0, 15 do
            w[i] = string.unpack('>I4', padded, chunkStart + i * 4)
        end
        for i = 16, 63 do
            local s0 = rrotate(w[i-15], 7) ~ rrotate(w[i-15], 18) ~ (w[i-15] >> 3)
            local s1 = rrotate(w[i-2], 17) ~ rrotate(w[i-2], 19) ~ (w[i-2] >> 10)
            w[i] = (w[i-16] + s0 + w[i-7] + s1) & MASK32
        end

        local a, b, c, d, e, f, g, h = h0, h1, h2, h3, h4, h5, h6, h7

        for i = 0, 63 do
            local S1 = rrotate(e, 6) ~ rrotate(e, 11) ~ rrotate(e, 25)
            local ch = (e & f) ~ ((~e & MASK32) & g)
            local temp1 = (h + S1 + ch + SHA256_K[i + 1] + w[i]) & MASK32
            local S0 = rrotate(a, 2) ~ rrotate(a, 13) ~ rrotate(a, 22)
            local maj = (a & b) ~ (a & c) ~ (b & c)
            local temp2 = (S0 + maj) & MASK32

            h = g; g = f; f = e; e = (d + temp1) & MASK32
            d = c; c = b; b = a; a = (temp1 + temp2) & MASK32
        end

        h0 = (h0 + a) & MASK32; h1 = (h1 + b) & MASK32
        h2 = (h2 + c) & MASK32; h3 = (h3 + d) & MASK32
        h4 = (h4 + e) & MASK32; h5 = (h5 + f) & MASK32
        h6 = (h6 + g) & MASK32; h7 = (h7 + h) & MASK32
    end

    return string.format('%08x%08x%08x%08x%08x%08x%08x%08x', h0, h1, h2, h3, h4, h5, h6, h7)
end

--- Constant-time-ish string compare so hash comparisons do not leak
--- timing info via early-exit string equality.
local function secureCompare(a, b)
    if type(a) ~= 'string' or type(b) ~= 'string' or #a ~= #b then return false end
    local diff = 0
    for i = 1, #a do
        diff = diff | (string.byte(a, i) ~ string.byte(b, i))
    end
    return diff == 0
end

-- ----------------------------------------------------------------
-- Password hashing entry points (Config.PasswordHashing)
-- ----------------------------------------------------------------

--- Hashes a raw password for storage. Called server-side ONLY, from
--- the NUI save handler when an admin sets or changes a door password.
function Access.HashPassword(rawPassword)
    if Config.PasswordHashing == 'bcrypt' then
        -- No pure-Lua/FXServer-native bcrypt implementation exists.
        -- If your server has a bcrypt-capable resource, wire its
        -- export in here (and in Access.VerifyPassword below), e.g.:
        --   return exports["your-bcrypt-resource"]:HashSync(rawPassword)
        -- Falling back to sha256 keeps doors functional instead of
        -- hard-erroring, but this is loud on purpose so it gets fixed.
        print('^3[qb-doorcreator] Config.PasswordHashing is bcrypt but no bcrypt export is wired up in server/access.lua - falling back to sha256.^0')
    end
    return sha256(rawPassword)
end

--- Compares a raw password entered by a player against a door stored
--- hash. NEVER called with client-supplied booleans - only the raw
--- string the client sent is trusted, and only as input to this
--- function; the actual pass/fail decision is made entirely here.
function Access.VerifyPassword(door, rawPassword)
    local pw = door.access and door.access.password
    if not pw or not pw.enabled or not pw.hash then return false end
    if type(rawPassword) ~= 'string' or rawPassword == '' then return false end
    return secureCompare(sha256(rawPassword), pw.hash)
end

-- ----------------------------------------------------------------
-- Inventory / player-data adapters
--
-- Qbox servers overwhelmingly run ox_inventory, so that is the
-- primary path. A qbx_core PlayerData fallback is included for
-- servers on a legacy-style inventory. If your server uses something
-- else entirely, this is the only place that needs editing.
-- ----------------------------------------------------------------

--- Returns true + count if the player has at least one of itemName.
local function playerHasItem(src, itemName)
    local ok, count = pcall(function()
        return exports.ox_inventory:Search(src, 'count', itemName)
    end)
    if ok and count and count > 0 then return true, count end

    -- Fallback for non-ox_inventory setups exposing a QBCore-style API.
    local okPlayer, Player = pcall(function() return exports.qbx_core:GetPlayer(src) end)
    if okPlayer and Player and Player.Functions and Player.Functions.GetItemByName then
        local item = Player.Functions.GetItemByName(itemName)
        if item and (item.amount or 0) > 0 then return true, item.amount end
    end
    return false, 0
end

--- Removes one itemName from the player. Only ever called AFTER
--- access has already been granted via the item category.
local function removePlayerItem(src, itemName)
    local ok = pcall(function()
        exports.ox_inventory:RemoveItem(src, itemName, 1)
    end)
    if not ok then
        pcall(function()
            local Player = exports.qbx_core:GetPlayer(src)
            if Player and Player.Functions and Player.Functions.RemoveItem then
                Player.Functions.RemoveItem(itemName, 1)
            end
        end)
    end
end

--- Keyring support: looks for Config.KeyItemName in the player
--- inventory with metadata.doorId matching this door's id. Mirrors
--- how ox_inventory-based keyring resources tag vehicle/house keys.
local function playerHasKeyForDoor(src, doorId)
    local ok, slots = pcall(function()
        return exports.ox_inventory:Search(src, 'slots', Config.KeyItemName or 'door_key')
    end)
    if ok and slots then
        for _, slot in pairs(slots) do
            if slot.metadata and (slot.metadata.doorId == doorId or slot.metadata.doorId == tostring(doorId)) then
                return true
            end
        end
    end
    return false
end

-- ----------------------------------------------------------------
-- Category evaluators - each takes (Player, door) and returns a bool,
-- plus for items, the matched rule (so the caller knows what to
-- consume).
-- ----------------------------------------------------------------

local function checkOwner(Player, door)
    local rules = door.access.identifiers
    if not DoorShared.NotEmpty(rules) then return false end
    local citizenid = Player.PlayerData.citizenid
    local license = Player.PlayerData.license
    for _, identifier in ipairs(rules) do
        if identifier == citizenid or identifier == license then
            return true
        end
    end
    return false
end

local function checkJob(Player, door)
    local rules = door.access.jobs
    if not DoorShared.NotEmpty(rules) then return false end
    local job = Player.PlayerData.job
    if not job then return false end
    for _, rule in ipairs(rules) do
        if job.name == rule.job and (job.grade and job.grade.level or 0) >= (rule.grade or 0) then
            return true
        end
    end
    return false
end

local function checkGang(Player, door)
    local rules = door.access.gangs
    if not DoorShared.NotEmpty(rules) then return false end
    local gang = Player.PlayerData.gang
    if not gang then return false end
    for _, rule in ipairs(rules) do
        if gang.name == rule.gang and (gang.grade and gang.grade.level or 0) >= (rule.grade or 0) then
            return true
        end
    end
    return false
end

local function checkKey(src, door)
    if not door.access.keys or not door.access.keys.enabled then return false end
    return playerHasKeyForDoor(src, door.id)
end

--- Returns (passed, matchedRule). matchedRule is nil if no item rules
--- are configured, so the caller can distinguish "no item rules" from
--- "item rules exist but the player has none of them".
local function checkItem(src, door)
    local rules = door.access.items
    if not DoorShared.NotEmpty(rules) then return false, nil end
    for _, rule in ipairs(rules) do
        local has = playerHasItem(src, rule.item)
        if has then return true, rule end
    end
    return false, nil
end

-- ----------------------------------------------------------------
-- Access.Evaluate - the single entry point server/main.lua calls.
--
-- Returns a result table:
--   { allowed = bool, reason = string, needsPassword = bool, consumeItem = string|nil }
--
-- reason is one of: permission | owner | job | gang | key | item | all
--                  | public | password | denied
-- ----------------------------------------------------------------
function Access.Evaluate(src, door)
    local access = door.access or {}
    local mode = access.mode == 'all' and 'all' or 'any' -- default "any"

    -- 1. Permission bypass - checked first and ALWAYS short-circuits,
    --    independent of mode. This is the staff override: someone in
    --    Qbox's e.g. 'admin' permission group can open any door
    --    regardless of how restrictive its other rules are. Uses
    --    exports.qbx_core:HasPermission, same as Config.CreatorPermission -
    --    NOT a FiveM ace permission.
    local hasPermission = false
    if access.permission and access.permission ~= '' then
        local ok, result = pcall(function()
            return exports.qbx_core:HasPermission(src, access.permission)
        end)
        hasPermission = ok and result == true
    end
    if hasPermission then
        return { allowed = true, reason = 'permission' }
    end

    local okPlayer, Player = pcall(function() return exports.qbx_core:GetPlayer(src) end)
    if not okPlayer or not Player then
        return { allowed = false, reason = 'denied' }
    end

    local passwordConfigured = access.password and access.password.enabled and access.password.hash ~= nil

    -- Evaluate every non-password category up front; used by both modes.
    local ownerPass = checkOwner(Player, door)
    local jobPass = checkJob(Player, door)
    local gangPass = checkGang(Player, door)
    local keyPass = checkKey(src, door)
    local itemPass, itemRule = checkItem(src, door)

    local anyCategoryConfigured = DoorShared.NotEmpty(access.identifiers)
        or DoorShared.NotEmpty(access.jobs)
        or DoorShared.NotEmpty(access.gangs)
        or (access.keys and access.keys.enabled)
        or DoorShared.NotEmpty(access.items)
        or passwordConfigured

    -- Fully open door: nothing configured in any category at all.
    if not anyCategoryConfigured then
        return { allowed = true, reason = 'public' }
    end

    if mode == 'any' then
        -- 2-6, in priority order. First pass wins.
        if ownerPass then return { allowed = true, reason = 'owner' } end
        if jobPass then return { allowed = true, reason = 'job' } end
        if gangPass then return { allowed = true, reason = 'gang' } end
        if keyPass then return { allowed = true, reason = 'key' } end
        if itemPass then
            return {
                allowed = true,
                reason = 'item',
                consumeItem = (itemRule.remove and itemRule.item) or nil,
            }
        end
        -- 7. Nothing else matched - if a password is configured, this
        --    is the ONLY remaining path, so ask the caller to prompt.
        if passwordConfigured then
            return { allowed = false, reason = 'password', needsPassword = true }
        end
        return { allowed = false, reason = 'denied' }
    end

    -- mode == "all": every CONFIGURED category must pass. Categories
    -- with zero rules are skipped rather than treated as automatic
    -- failures (an admin who left Gangs empty did not mean "deny
    -- everyone who has no gang").
    if DoorShared.NotEmpty(access.identifiers) and not ownerPass then
        return { allowed = false, reason = 'denied' }
    end
    if DoorShared.NotEmpty(access.jobs) and not jobPass then
        return { allowed = false, reason = 'denied' }
    end
    if DoorShared.NotEmpty(access.gangs) and not gangPass then
        return { allowed = false, reason = 'denied' }
    end
    if access.keys and access.keys.enabled and not keyPass then
        return { allowed = false, reason = 'denied' }
    end
    if DoorShared.NotEmpty(access.items) and not itemPass then
        return { allowed = false, reason = 'denied' }
    end
    -- All configured non-password categories passed (or none were
    -- configured). Password, if configured, is still required.
    if passwordConfigured then
        return { allowed = false, reason = 'password', needsPassword = true }
    end
    return {
        allowed = true,
        reason = 'all', -- mode == 'all': every configured category passed together, not just one
        consumeItem = (itemPass and itemRule.remove and itemRule.item) or nil,
    }
end

--- Removes the item a successful item-based access check flagged for
--- consumption. Split out from Evaluate so evaluation stays a pure
--- read (safe to call speculatively) and the actual inventory mutation
--- only happens once server/main.lua has committed to granting access.
function Access.ConsumeItem(src, itemName)
    if not itemName then return end
    removePlayerItem(src, itemName)
end
