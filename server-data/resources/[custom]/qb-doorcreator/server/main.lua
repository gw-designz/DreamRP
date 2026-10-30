--[[
    server/main.lua

    Boot sequence, in-memory door cache, and every server event / ox_lib
    callback the client talks to. This file is the ONLY place door
    state is allowed to change - client/main.lua only ever reflects
    what it is told here (see §9: server is the single source of truth).

    Request/response traffic (admin CRUD, player interact) goes through
    ox_lib's lib.callback so the client can `await` a real answer
    instead of us hand-rolling a request-id correlation system.
    Fire-and-forget state patches (a door being added/edited/removed/
    toggled, by anyone, for any reason) go out as plain
    TriggerClientEvent broadcasts so every connected client's cache
    stays in sync without a full re-broadcast of the whole door list.
]]

-- Doors[id] = decoded door row (see server/db.lua rowToDoor). This is
-- the authoritative in-memory mirror of the doorlocks table - every
-- read in this file goes through this table, never straight to MySQL,
-- so a burst of interactions doesn't hammer the database.
local Doors = {}

-- Minimal in-memory store for the "switch" half of the dependency
-- system (§5). Doors only ever reference a switch by id; nothing in
-- this resource places lever props itself. Other resources (or a
-- future addon) can flip a switch via the exports at the bottom of
-- this file, e.g. exports['qb-doorcreator']:SetSwitchState('lever_01', 'on').
local SwitchStates = {}

-- Generation counters for auto-relock timers, keyed by door id. See
-- ScheduleRelock() - this stops a stale timer from an earlier unlock
-- re-locking a door after a NEWER unlock already reset the clock.
local relockGen = {}

--- Checks Qbox's own permission-group system (the same one behind
--- qbx_core's /addpermission and its admin menu), NOT a FiveM ace
--- permission. Config.CreatorPermission is whatever group name (or
--- table of group names, if your qbx_core build's HasPermission
--- accepts a list) counts as "admin" for this resource - 'admin' and
--- 'god' are the common Qbox defaults.
---
--- pcall-wrapped like every other qbx_core export call in this
--- resource: if HasPermission does not exist or errors for any reason
--- (wrong qbx_core version, etc.), this fails CLOSED (denies) rather
--- than crashing or accidentally granting access.
local function isAdmin(source)
    local ok, hasPermission = pcall(function()
        return exports.qbx_core:HasPermission(source, Config.CreatorPermission)
    end)
    return ok and hasPermission == true
end

--- Lightweight permission check used purely to gate CLIENT-SIDE UX
--- (entering creator placement mode, opening the management panel)
--- with a clean denial notification instead of a silent no-op. This
--- is NOT the security boundary - every mutation callback below calls
--- isAdmin() again independently regardless of what this returns.
lib.callback.register('qb-doorcreator:checkAdmin', function(source)
    return isAdmin(source)
end)

--- Sends a localized notification to one client. Kept as a thin event
--- wrapper (rather than calling ox_lib here) because notification
--- rendering is inherently a client concern; the server only decides
--- WHAT to say.
local function Notify(source, key, subs, type)
    TriggerClientEvent('qb-doorcreator:client:notify', source, key, subs, type)
end

-- ----------------------------------------------------------------
-- Boot sequence
-- ----------------------------------------------------------------

--- Confirms qbx_core is actually running before this resource does
--- anything else. A missing qbx_core is a hard stop (this resource is
--- Qbox-only by design); a qbx_core that exists but hasn't finished
--- starting yet (server.cfg ordering hiccup) gets a short grace
--- window instead of an infinite wait.
local function ensureQbxCore()
    local state = GetResourceState('qbx_core')
    if state == 'missing' then
        print(Lang.T('qbx_core_missing'))
        StopResource(GetCurrentResourceName())
        return false
    end

    local attempts = 0
    while GetResourceState('qbx_core') ~= 'started' and attempts < 50 do
        Wait(100)
        attempts = attempts + 1
    end

    if GetResourceState('qbx_core') ~= 'started' then
        print(Lang.T('qbx_core_missing'))
        StopResource(GetCurrentResourceName())
        return false
    end

    return true
end

CreateThread(function()
    if not ensureQbxCore() then return end

    DoorDB.Init()

    local rows = DoorDB.GetAll()
    for _, door in ipairs(rows) do
        Doors[door.id] = door
    end

    print(('^2[qb-doorcreator]^0 Loaded %d door(s) from the database.'):format(#rows))
end)

-- Re-sends the full snapshot to a client once ITS OWN client scripts
-- confirm they are ready to receive it. Using a client-initiated
-- "ready" ping instead of playerJoined avoids the race where the
-- player join fires before qb-doorcreator's client-side listeners
-- exist yet.
RegisterNetEvent('qb-doorcreator:server:ready', function()
    local source = source
    local list = {}
    for _, d in pairs(Doors) do list[#list + 1] = d end
    TriggerClientEvent('qb-doorcreator:client:initDoors', source, list)
end)

-- ----------------------------------------------------------------
-- Core state mutation - the ONLY function allowed to change a door's
-- locked flag. Handles group propagation (§5: doors sharing group_id
-- toggle together) and keeps DB + memory + every client in sync.
-- ----------------------------------------------------------------

local function applyLockedState(door, locked)
    door.locked = locked
    DoorDB.SetLocked(door.id, locked)
    TriggerClientEvent('qb-doorcreator:client:updateDoor', -1, door)
end

--- Sets a door's locked state and mirrors it to every other door in
--- the same group_id, if any. `cause` is 'interact' | 'admin' | 'system'
--- purely for logging/telemetry - it does not change behavior beyond
--- auto-relock only ever being scheduled by the interact path (see
--- the callback below).
local function SetDoorLocked(doorId, locked, cause)
    local door = Doors[doorId]
    if not door then return end

    applyLockedState(door, locked)

    if door.group_id and door.group_id ~= '' then
        local members = DoorShared.GetGroupMembers(Doors, door.group_id)
        for _, member in ipairs(members) do
            if member.id ~= door.id and member.locked ~= locked then
                applyLockedState(member, locked)
            end
        end
    end

    if Config.Debug then
        print(('[qb-doorcreator] door %d -> %s (cause: %s)'):format(doorId, locked and 'locked' or 'unlocked', cause))
    end
end

--- Schedules an auto re-lock after `seconds`. See the module comment
--- on relockGen for why the generation check exists: without it, two
--- unlocks in quick succession would race and could re-lock the door
--- earlier than the SECOND unlock's own timer intended.
local function ScheduleRelock(doorId, seconds)
    relockGen[doorId] = (relockGen[doorId] or 0) + 1
    local myGen = relockGen[doorId]

    SetTimeout(seconds * 1000, function()
        if relockGen[doorId] ~= myGen then return end -- superseded by a newer unlock
        local door = Doors[doorId]
        if not door or door.locked then return end -- already locked by someone/something else
        SetDoorLocked(doorId, true, 'system')
    end)
end

-- ----------------------------------------------------------------
-- Player-facing interaction (§8)
-- ----------------------------------------------------------------

--- Runs the full §4 access pipeline for a lock/unlock attempt. Never
--- trusts anything from the client except "which door" - every other
--- fact (job, gang, items, permission, owner) is re-derived server-side.
lib.callback.register('qb-doorcreator:interact', function(source, doorId)
    local door = Doors[doorId]
    if not door then return { ok = false, reason = 'denied' } end

    -- Dependency gate (§5): vault-style multi-step unlocks. Nobody -
    -- regardless of access rules - can toggle this door until every
    -- dependency's required state is currently true.
    local satisfied = DoorShared.CheckDependencies(door.dependencies, Doors, SwitchStates)
    if not satisfied then
        return { ok = false, reason = 'dependency' }
    end

    local result = Access.Evaluate(source, door)

    if result.needsPassword then
        -- Nothing else granted access and this door has a password
        -- configured. Tell the client to prompt for it; the actual
        -- comparison happens in the submitPassword callback below,
        -- never here and never on the client.
        return { ok = false, reason = 'password', needsPassword = true }
    end

    if not result.allowed then
        return { ok = false, reason = result.reason or 'denied' }
    end

    if result.consumeItem then
        Access.ConsumeItem(source, result.consumeItem)
    end

    local newLocked = not door.locked
    SetDoorLocked(doorId, newLocked, 'interact')

    if not newLocked and door.auto_close and door.auto_close > 0 then
        ScheduleRelock(doorId, door.auto_close)
        Notify(source, 'auto_relock_notice', { seconds = door.auto_close }, 'inform')
    end

    return { ok = true, reason = result.reason, locked = newLocked }
end)

--- Cosmetic-only hint used by client/main.lua to decide whether to
--- show the interaction prompt at all (Config.HideInteractIfNoAccess).
--- Reuses the real Access.Evaluate so the hint can never drift out of
--- sync with actual enforcement, but it is still just a hint: the
--- interact/submitPassword callbacks above are what actually decide
--- access, and they run this same check again regardless of what the
--- client was shown.
lib.callback.register('qb-doorcreator:previewAccess', function(source, doorId)
    local door = Doors[doorId]
    if not door then return false end

    local satisfied = DoorShared.CheckDependencies(door.dependencies, Doors, SwitchStates)
    if not satisfied then return false end

    local result = Access.Evaluate(source, door)
    return result.allowed or result.needsPassword == true
end)

--- Second step of the password flow. The client only ever sends the
--- raw string the player typed; Access.VerifyPassword() does the
--- actual hash comparison server-side.
lib.callback.register('qb-doorcreator:submitPassword', function(source, doorId, rawPassword)
    local door = Doors[doorId]
    if not door then return { ok = false, reason = 'denied' } end

    local satisfied = DoorShared.CheckDependencies(door.dependencies, Doors, SwitchStates)
    if not satisfied then
        return { ok = false, reason = 'dependency' }
    end

    if type(rawPassword) ~= 'string' or #rawPassword > 64 then
        return { ok = false, reason = 'password' }
    end

    if not Access.VerifyPassword(door, rawPassword) then
        return { ok = false, reason = 'password' }
    end

    local newLocked = not door.locked
    SetDoorLocked(doorId, newLocked, 'interact')

    if not newLocked and door.auto_close and door.auto_close > 0 then
        ScheduleRelock(doorId, door.auto_close)
        Notify(source, 'auto_relock_notice', { seconds = door.auto_close }, 'inform')
    end

    return { ok = true, reason = 'password', locked = newLocked }
end)

-- ----------------------------------------------------------------
-- Admin NUI CRUD (§6/§7) - every single one re-checks the Qbox
-- permission server-side. The client also hides/blocks these actions
-- in the UI, but that is a UX nicety, not the security boundary.
-- ----------------------------------------------------------------

--- Deep-validates and normalizes an access object coming from the
--- NUI before it ever touches the database. Nothing here trusts
--- types, lengths, or shapes from the client. `existingAccess` (when
--- editing) supplies the previous password hash so leaving the
--- password field untouched in the form doesn't wipe it.
local function sanitizeAccess(input, existingAccess)
    input = type(input) == 'table' and input or {}

    local access = {
        mode = input.mode == 'all' and 'all' or 'any',
        jobs = {},
        gangs = {},
        identifiers = {},
        items = {},
        permission = nil,
        keys = { enabled = false },
        password = { enabled = false, hash = nil, algo = Config.PasswordHashing },
    }

    if type(input.jobs) == 'table' then
        for _, rule in ipairs(input.jobs) do
            if type(rule) == 'table' and type(rule.job) == 'string' and rule.job ~= '' then
                access.jobs[#access.jobs + 1] = { job = rule.job, grade = tonumber(rule.grade) or 0 }
            end
        end
    end

    if type(input.gangs) == 'table' then
        for _, rule in ipairs(input.gangs) do
            if type(rule) == 'table' and type(rule.gang) == 'string' and rule.gang ~= '' then
                access.gangs[#access.gangs + 1] = { gang = rule.gang, grade = tonumber(rule.grade) or 0 }
            end
        end
    end

    if type(input.identifiers) == 'table' then
        for _, id in ipairs(input.identifiers) do
            if type(id) == 'string' and id ~= '' and #id <= 100 then
                access.identifiers[#access.identifiers + 1] = id
            end
        end
    end

    if type(input.items) == 'table' then
        for _, rule in ipairs(input.items) do
            if type(rule) == 'table' and type(rule.item) == 'string' and rule.item ~= '' then
                access.items[#access.items + 1] = { item = rule.item, remove = rule.remove == true }
            end
        end
    end

    -- Qbox permission group (e.g. 'admin', 'god') for this specific
    -- door - staff bypass, checked the same way as Config.CreatorPermission
    -- via exports.qbx_core:HasPermission. NOT a FiveM ace permission.
    if type(input.permission) == 'string' and input.permission ~= '' and #input.permission <= 100 then
        access.permission = input.permission
    end

    if type(input.keys) == 'table' then
        access.keys.enabled = input.keys.enabled == true
    end

    if type(input.password) == 'table' and input.password.enabled == true then
        access.password.enabled = true
        if type(input.password.raw) == 'string' and input.password.raw ~= '' then
            if #input.password.raw > 32 then
                input.password.raw = input.password.raw:sub(1, 32)
            end
            access.password.hash = Access.HashPassword(input.password.raw)
        elseif existingAccess and existingAccess.password and existingAccess.password.hash then
            -- Editing a door without retyping the code: keep the old hash.
            access.password.hash = existingAccess.password.hash
        end
    end

    return access
end

--- Validates dependency entries. Unknown/malformed entries are
--- silently dropped rather than rejecting the whole save, so a bad
--- row in the dependency builder never blocks the rest of the form.
local function sanitizeDependencies(input)
    local out = {}
    if type(input) ~= 'table' then return out end
    for _, dep in ipairs(input) do
        if type(dep) == 'table' and (dep.type == 'door' or dep.type == 'switch') and dep.id ~= nil and type(dep.requiredState) == 'string' then
            out[#out + 1] = { type = dep.type, id = dep.id, requiredState = dep.requiredState }
            if #out >= 10 then break end -- sane upper bound, vault chains don't need more
        end
    end
    return out
end

--- Shared coords/model/label validation used by both create and edit.
--- Returns normalized fields, or nil + an error key if the payload is
--- unusable.
local function sanitizeCore(data)
    if type(data) ~= 'table' then return nil, 'invalid_input' end

    local label = type(data.label) == 'string' and DoorShared.Trim(data.label) or ''
    if label == '' then label = 'Unnamed Door' end
    if #label > 100 then label = label:sub(1, 100) end

    local model = tonumber(data.model)
    if not model then return nil, 'invalid_input' end

    local coords = data.coords
    if type(coords) ~= 'table' or not tonumber(coords.x) or not tonumber(coords.y) or not tonumber(coords.z) then
        return nil, 'invalid_input'
    end

    local groupId = type(data.group_id) == 'string' and DoorShared.Trim(data.group_id) or ''
    if #groupId > 64 then groupId = groupId:sub(1, 64) end

    local autoClose = tonumber(data.auto_close) or 0
    if autoClose < 0 then autoClose = 0 end
    if autoClose > 86400 then autoClose = 86400 end -- 24h ceiling, sanity cap

    return {
        label = label,
        model = model,
        coords = {
            x = tonumber(coords.x),
            y = tonumber(coords.y),
            z = tonumber(coords.z),
            heading = tonumber(coords.heading) or 0.0,
        },
        group_id = groupId,
        auto_close = autoClose,
        fallback = data.fallback == true,
    }, nil
end

lib.callback.register('qb-doorcreator:createDoor', function(source, data)
    if not isAdmin(source) then return { ok = false, error = 'no_permission' } end

    local core, err = sanitizeCore(data)
    if not core then return { ok = false, error = err } end

    if core.group_id ~= '' then
        local existingCount = #DoorShared.GetGroupMembers(Doors, core.group_id)
        if existingCount >= Config.MaxDoorsPerGroup then
            return { ok = false, error = 'creator_max_group' }
        end
    end

    core.access = sanitizeAccess(data.access, nil)
    if core.access.password.enabled and not core.access.password.hash then
        -- Password checkbox was ticked but no code was ever typed (and
        -- there is no existing door to inherit a hash from, since this
        -- is a create). Reject rather than silently saving a door that
        -- LOOKS password-protected in the panel but enforces nothing.
        return { ok = false, error = 'invalid_input' }
    end
    core.dependencies = sanitizeDependencies(data.dependencies)

    local okPlayer, Player = pcall(function() return exports.qbx_core:GetPlayer(source) end)
    core.created_by = (okPlayer and Player and Player.PlayerData.citizenid) or ('src:' .. source)

    local door = DoorDB.Insert(core)
    if not door then return { ok = false, error = 'generic_error' } end

    Doors[door.id] = door
    TriggerClientEvent('qb-doorcreator:client:addDoor', -1, door)

    return { ok = true, door = door }
end)

lib.callback.register('qb-doorcreator:updateDoor', function(source, doorId, data)
    if not isAdmin(source) then return { ok = false, error = 'no_permission' } end

    local existing = Doors[doorId]
    if not existing then return { ok = false, error = 'generic_error' } end

    local core, err = sanitizeCore(data)
    if not core then return { ok = false, error = err } end

    if core.group_id ~= '' and core.group_id ~= existing.group_id then
        local existingCount = #DoorShared.GetGroupMembers(Doors, core.group_id)
        if existingCount >= Config.MaxDoorsPerGroup then
            return { ok = false, error = 'creator_max_group' }
        end
    end

    core.access = sanitizeAccess(data.access, existing.access)
    if core.access.password.enabled and not core.access.password.hash then
        -- Same guard as createDoor - password was just enabled on this
        -- edit but no code was typed, and there was no prior hash to
        -- carry forward either.
        return { ok = false, error = 'invalid_input' }
    end
    core.dependencies = sanitizeDependencies(data.dependencies)

    local door = DoorDB.Update(doorId, core)
    if not door then return { ok = false, error = 'generic_error' } end

    Doors[doorId] = door
    TriggerClientEvent('qb-doorcreator:client:updateDoor', -1, door)

    return { ok = true, door = door }
end)

--- Creates a brand new door from a freshly raycast-picked entity and
--- joins it to an EXISTING door's group (§5/§6: "Link Another Door"
--- in the NUI edit panel - double doors after the fact, no need to
--- redo the whole /createdoor multi-select flow).
---
--- Deliberately does NOT go through sanitizeAccess/data.access like
--- createDoor/updateDoor do. It clones `existing.access` - the
--- SERVER's own already-validated copy, hash included - directly.
--- Re-running it through sanitizeAccess would require a raw password
--- to re-derive the hash from, but this client was never sent one (it
--- only ever sees a redacted access object with a hash, never a
--- plaintext code), so that path would just reproduce the "password
--- enabled with no hash" bug this resource already guards against
--- elsewhere. Cloning the trusted server-side value sidesteps that
--- entirely.
lib.callback.register('qb-doorcreator:linkDoor', function(source, existingDoorId, draft)
    if not isAdmin(source) then return { ok = false, error = 'no_permission' } end

    local existing = Doors[existingDoorId]
    if not existing then return { ok = false, error = 'generic_error' } end

    if type(draft) ~= 'table' or type(draft.coords) ~= 'table' or not tonumber(draft.model) then
        return { ok = false, error = 'invalid_input' }
    end

    local groupId = existing.group_id

    if groupId and groupId ~= '' then
        -- Already grouped - just guard the size cap before adding a
        -- third (or later) member.
        local existingCount = #DoorShared.GetGroupMembers(Doors, groupId)
        if existingCount >= Config.MaxDoorsPerGroup then
            return { ok = false, error = 'creator_max_group' }
        end
    else
        -- First time this door has ever been linked - mint a group id
        -- and retroactively assign it to the existing door too, so
        -- both ends up sharing it.
        groupId = ('grp_%d_%d'):format(os.time(), math.random(1000, 9999))
        local updated = DoorDB.Update(existingDoorId, {
            label = existing.label,
            model = existing.model,
            coords = existing.coords,
            group_id = groupId,
            access = existing.access,
            dependencies = existing.dependencies,
            auto_close = existing.auto_close,
            fallback = existing.fallback,
        })
        if not updated then return { ok = false, error = 'generic_error' } end
        Doors[existingDoorId] = updated
        TriggerClientEvent('qb-doorcreator:client:updateDoor', -1, updated)
    end

    local okPlayer, Player = pcall(function() return exports.qbx_core:GetPlayer(source) end)
    local createdBy = (okPlayer and Player and Player.PlayerData.citizenid) or ('src:' .. source)

    local newDoor = DoorDB.Insert({
        label = (existing.label or 'Door') .. ' (2)',
        model = tonumber(draft.model),
        coords = {
            x = tonumber(draft.coords.x) or 0.0,
            y = tonumber(draft.coords.y) or 0.0,
            z = tonumber(draft.coords.z) or 0.0,
            heading = tonumber(draft.coords.heading) or 0.0,
        },
        group_id = groupId,
        access = existing.access,
        dependencies = {},
        auto_close = existing.auto_close,
        fallback = existing.fallback,
        created_by = createdBy,
    })

    if not newDoor then return { ok = false, error = 'generic_error' } end

    Doors[newDoor.id] = newDoor
    TriggerClientEvent('qb-doorcreator:client:addDoor', -1, newDoor)

    return { ok = true, door = newDoor }
end)

lib.callback.register('qb-doorcreator:deleteDoor', function(source, doorId)
    if not isAdmin(source) then return { ok = false, error = 'no_permission' } end

    local door = Doors[doorId]
    if not door then return { ok = false, error = 'generic_error' } end

    DoorDB.Delete(doorId)
    Doors[doorId] = nil
    relockGen[doorId] = nil

    TriggerClientEvent('qb-doorcreator:client:removeDoor', -1, doorId)

    return { ok = true, label = door.label }
end)

--- Quick lock/unlock override straight from the management list view.
--- This bypasses §4 access rules entirely (it is gated on the admin
--- permission instead) - it is an admin override tool, not a simulated
--- player interaction, so it deliberately does NOT run Access.Evaluate
--- and does NOT schedule an auto-relock timer.
lib.callback.register('qb-doorcreator:toggleLock', function(source, doorId, locked)
    if not isAdmin(source) then return { ok = false, error = 'no_permission' } end

    local door = Doors[doorId]
    if not door then return { ok = false, error = 'generic_error' } end

    SetDoorLocked(doorId, locked and true or false, 'admin')

    return { ok = true, door = Doors[doorId] }
end)

--- Full refresh for the NUI panel on open. Infrequent, admin-only, so
--- refetching straight from the in-memory cache (not the DB) is both
--- cheap and guaranteed consistent with what interact/toggle just did.
lib.callback.register('qb-doorcreator:getAllDoors', function(source)
    if not isAdmin(source) then return { ok = false, error = 'no_permission' } end

    local list = {}
    for _, d in pairs(Doors) do list[#list + 1] = d end
    table.sort(list, function(a, b) return a.id < b.id end)

    return { ok = true, doors = list }
end)

-- ----------------------------------------------------------------
-- Exports - lets other resources integrate with the dependency
-- system's "switch" trigger type, or read door state read-only.
-- ----------------------------------------------------------------

exports('SetSwitchState', function(switchId, state)
    SwitchStates[switchId] = state
end)

exports('GetSwitchState', function(switchId)
    return SwitchStates[switchId]
end)

exports('GetDoor', function(doorId)
    local door = Doors[doorId]
    if not door then return nil end
    -- Return a shallow copy so external resources cannot mutate our
    -- source-of-truth table by reference.
    local copy = {}
    for k, v in pairs(door) do copy[k] = v end
    return copy
end)

exports('GetAllDoors', function()
    local list = {}
    for _, d in pairs(Doors) do list[#list + 1] = d end
    return list
end)
