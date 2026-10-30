--[[
    client/main.lua

    Boot sequence, the local door cache, native door-system integration,
    and player-facing lock/unlock interaction (§8/§9).

    ── HOW THE NATIVE DOOR SYSTEM IS USED (read this before touching it) ──
    GTA has a built-in "door system" that is separate from any given
    door PROP. A door prop (the .ydr model) just knows how to animate
    itself; the door SYSTEM is what other game systems (peds pathing
    through it, other scripts, MP door sync) actually look at to know
    whether a door is open, closed, locked, or ajar. If you only
    freeze/rotate the prop yourself, the game's own systems (and any
    other resource that touches that same door) never find out - peds
    walk through it, and re-entering the interior can reset your
    "fake" rotation. Registering the door with AddDoorToSystem makes
    OUR lock state the same lock state everything else in the game
    sees, which is why this resource uses it instead of manual
    freeze/rotate for every door that supports it.

    The three calls that matter:
      AddDoorToSystem(doorHash, doorModelHash, x, y, z, p5, p6, p7)
        Registers coords+model under a unique `doorHash` key. Safe to
        call again for a door that is already registered (e.g. after
        an edit) - it just re-registers it, which is how this file
        handles a moved/reconfigured door without a resource restart.
        `doorHash` is NOT the model hash - it is an arbitrary unique
        id WE choose (see server/db.lua: derived from the row's
        primary key so it is stable across restarts). `doorModelHash`
        IS the model hash of the actual door prop.
      DoorSystemSetDoorState(doorHash, state, p2, p3)
        state = 1 means locked, state = 0 means unlocked. The native
        supports more nuanced states in the base game (partially ajar,
        etc.) but every community door-lock script settles on this
        binary convention for a plain lock/unlock, and so does this one.
      RemoveDoorFromSystem(doorHash)
        Unregisters it. Called when a door is deleted via the NUI panel.

    A door flagged `fallback = true` in the DB skips all of the above
    entirely and uses freeze + heading toggling instead - see
    ApplyDoorState() below. That path exists for custom MLO props that
    were never built as real door-system doors (§3).
]]

-- id -> decoded door row, exactly as broadcast by the server. This is
-- a CACHE, not a second source of truth - every write goes to the
-- server first and this table is only ever updated from server events
-- (initDoors/addDoor/updateDoor/removeDoor). See §9.
DoorCache = {}

local InteractionPoints = {} -- doorId -> lib.points object
local AccessHints = {}       -- doorId -> bool, cosmetic-only (see server previewAccess callback)

-- ----------------------------------------------------------------
-- Boot sequence
-- ----------------------------------------------------------------

local function ensureQbxCore()
    if GetResourceState('qbx_core') ~= 'started' then
        print(Lang.T('qbx_core_missing'))
        return false
    end
    return true
end

CreateThread(function()
    if not ensureQbxCore() then
        StopResource(GetCurrentResourceName())
        return
    end
    -- Ask the server for the current door list. We do this from the
    -- client instead of relying on playerJoined server-side so there
    -- is no race between "server decided to send it" and "client is
    -- actually listening yet".
    TriggerServerEvent('qb-doorcreator:server:ready')
end)

-- ----------------------------------------------------------------
-- Native / fallback state application
-- ----------------------------------------------------------------

--- Finds the live entity for a `fallback = true` door. Fallback doors
--- are ordinary map/MLO objects we never spawn ourselves, so this
--- just looks for the closest object of the right model near the
--- stored coords. Returns nil if it is not currently streamed in
--- (fine - fallback doors only need to resolve when a player is
--- actually close enough to interact, which is exactly when the
--- object would be streamed in anyway).
local function GetFallbackEntity(door)
    local c = door.coords
    local entity = GetClosestObjectOfType(c.x, c.y, c.z, 1.5, door.model, false, false, false)
    return entity ~= 0 and entity or nil
end

--- Applies a door's CURRENT locked flag to the game world. Safe to
--- call repeatedly/idempotently - it does not register anything, it
--- only pushes state (see RegisterDoorNative for registration).
local function ApplyDoorState(door)
    if door.fallback then
        local entity = GetFallbackEntity(door)
        if not entity then return end
        FreezeEntityPosition(entity, true)
        -- Crude but effective: swing 90 degrees off the door's
        -- recorded placement heading to fake an "open" pose. This is
        -- intentionally simple - fallback mode trades visual fidelity
        -- for working on props the native door system does not know
        -- about at all.
        SetEntityHeading(entity, door.locked and door.coords.heading or (door.coords.heading + 90.0))
        return
    end

    local hash = tonumber(door.door_hash)
    if not hash then return end

    DoorSystemSetDoorState(hash, door.locked and 1 or 0, false, false)
    if door.locked then
        -- Force fully shut immediately rather than waiting on physics
        -- to swing it closed, so "locked" never looks visibly ajar.
        DoorSystemSetOpenRatio(hash, 0.0, false, false)
    end
end

--- Registers a door with the native door system (or just applies the
--- fallback freeze/heading state). Called once when a door first
--- enters the cache, and again if an edit changes its model/coords.
local function RegisterDoorNative(door)
    if door.fallback then
        ApplyDoorState(door)
        return
    end

    local hash = tonumber(door.door_hash)
    if not hash then
        if Config.Debug then
            print(('[qb-doorcreator] door %d has an invalid door_hash, skipping native registration'):format(door.id))
        end
        return
    end

    local c = door.coords
    AddDoorToSystem(hash, door.model, c.x, c.y, c.z, false, false, false)
    DoorSystemSetAutomaticRate(hash, Config.DoorAutoRate, false, false)
    ApplyDoorState(door)
end

local function UnregisterDoorNative(door)
    if door.fallback then return end -- nothing to unregister, it is just a world object
    local hash = tonumber(door.door_hash)
    if not hash then return end
    RemoveDoorFromSystem(hash)
end

-- ----------------------------------------------------------------
-- Interaction (§8)
-- ----------------------------------------------------------------

local function PlayDoorSound(kind)
    if not Config.Sound.enabled then return end
    local s = Config.Sound[kind]
    if not s then return end
    -- PlaySoundFromCoord wants x/y/z as three separate floats, not a
    -- vector3 - decompose explicitly rather than passing coords whole.
    local c = GetEntityCoords(PlayerPedId())
    PlaySoundFromCoord(-1, s.name, c.x, c.y, c.z, s.set, false, 0, false)
end

--- Lightweight, prop-less "fiddling with the lock" animation. Reuses
--- the arresting/cuffing hand animation purely for the hand motion -
--- there is no lock prop attached, so this works on any door without
--- needing a per-door prop offset configured.
local function PlayLockAnim()
    local ped = PlayerPedId()
    lib.requestAnimDict('anim@mp_arresting')
    TaskPlayAnim(ped, 'anim@mp_arresting', 'a_uncuff', 3.0, 3.0, 1500, 49, 0, false, false, false)
end

--- The single entry point for a player trying to lock/unlock a door,
--- called when the interaction prompt's keybind is pressed in range.
--- Every access decision happens server-side (§4/§8) - this function
--- only ever reacts to what the server callback returns.
function InteractWithDoor(doorId)
    local door = DoorCache[doorId]
    if not door then return end

    local ok, result = pcall(lib.callback.await, 'qb-doorcreator:interact', false, doorId)
    if not ok or not result then return end

    if result.ok then
        PlayLockAnim()
        PlayDoorSound(result.locked and 'lock' or 'unlock')
        lib.notify({ description = Lang.T(result.locked and 'door_locked' or 'door_unlocked'), type = 'success' })
        return
    end

    if result.needsPassword then
        local input = lib.inputDialog(Lang.T('password_prompt_title'), {
            { type = 'input', label = Lang.T('password_prompt_label'), required = true, min = 1, max = 32 },
        })
        if not input or not input[1] or tostring(input[1]) == '' then return end

        -- The raw string the player typed is sent as-is. The server
        -- hashes it and compares against the stored hash - this
        -- client NEVER sees the real password or decides pass/fail.
        local pOk, pResult = pcall(lib.callback.await, 'qb-doorcreator:submitPassword', false, doorId, tostring(input[1]))
        if pOk and pResult and pResult.ok then
            PlayLockAnim()
            PlayDoorSound(pResult.locked and 'lock' or 'unlock')
            lib.notify({ description = Lang.T(pResult.locked and 'door_locked' or 'door_unlocked'), type = 'success' })
        else
            PlayDoorSound('denied')
            lib.notify({ description = Lang.T('access_denied_password'), type = 'error' })
        end
        return
    end

    PlayDoorSound('denied')
    local reasonKey = result.reason == 'dependency' and 'access_denied_dependency' or 'access_denied'
    lib.notify({ description = Lang.T(reasonKey), type = 'error' })
end

-- ----------------------------------------------------------------
-- Interaction prompt (custom NUI, no ox_target)
--
-- lib.points only runs a point's `nearby()` callback for points the
-- player is currently within `distance` of, so this costs nothing for
-- every door the player is not near - satisfying §9's idle-resmon
-- target without a hand-rolled per-frame distance loop. The visible
-- prompt itself is a small custom HTML/CSS element (web/index.html's
-- #prompt, styled in web/style.css) driven purely by SendNUIMessage -
-- it never calls SetNuiFocus, so it never touches mouse/keyboard
-- capture or blocks movement.
-- ----------------------------------------------------------------

local function ShowPrompt(door)
    SendNUIMessage({
        action = 'showPrompt',
        key = Config.InteractKeyLabel,
        label = door.locked and Lang.T('prompt_unlock') or Lang.T('prompt_lock'),
        position = Config.PromptPosition,
    })
end

local function HidePrompt()
    SendNUIMessage({ action = 'hidePrompt' })
end

--- Refreshes a door's cosmetic "does this player even have a path to
--- access it" hint, used only when Config.HideInteractIfNoAccess is
--- on. Async and fire-and-forget - the point's nearby() loop just
--- reads whatever is currently in AccessHints[doorId] each tick.
local function RefreshAccessHint(doorId)
    if not Config.HideInteractIfNoAccess then return end
    CreateThread(function()
        local ok, hasAccess = pcall(lib.callback.await, 'qb-doorcreator:previewAccess', false, doorId)
        AccessHints[doorId] = ok and hasAccess or true
    end)
end

local function RemoveInteractionPoint(doorId)
    local point = InteractionPoints[doorId]
    if point then
        point:remove()
        InteractionPoints[doorId] = nil
    end
end

--- Creates (or recreates, at a possibly-new position) the proximity
--- point for a door. Safe to call again for an already-registered
--- door - e.g. after an edit moves it.
local function CreateInteractionPoint(door)
    RemoveInteractionPoint(door.id)

    local c = door.coords
    local point = lib.points.new({
        coords = vector3(c.x, c.y, c.z),
        distance = Config.InteractDistance,
        doorId = door.id,
        showing = false,
    })

    function point:nearby()
        if Config.HideInteractIfNoAccess and AccessHints[self.doorId] == false then
            if self.showing then
                self.showing = false
                HidePrompt()
            end
            return -- cosmetic-only: server still denies even if this hint is stale
        end

        local dist = #(GetEntityCoords(PlayerPedId()) - self.coords)
        local inRange = dist <= Config.PromptDistance

        if inRange and not self.showing then
            self.showing = true
            local d = DoorCache[self.doorId]
            if d then ShowPrompt(d) end
        elseif not inRange and self.showing then
            self.showing = false
            HidePrompt()
        end

        if inRange and IsControlJustReleased(0, Config.InteractKey) then
            self.showing = false
            HidePrompt()
            InteractWithDoor(self.doorId)
        end
    end

    function point:onExit()
        if self.showing then
            self.showing = false
            HidePrompt()
        end
    end

    InteractionPoints[door.id] = point
end

local function coordsChanged(a, b)
    return a.x ~= b.x or a.y ~= b.y or a.z ~= b.z
end

-- ----------------------------------------------------------------
-- Server -> client sync events (§9: targeted patches, never a full
-- re-broadcast of every door on a single change)
-- ----------------------------------------------------------------

RegisterNetEvent('qb-doorcreator:client:initDoors', function(doors)
    -- Full snapshot, received once (on join / resource start). Every
    -- update after this point is a single-door patch event below.
    for id in pairs(DoorCache) do
        UnregisterDoorNative(DoorCache[id])
        RemoveInteractionPoint(id)
    end
    DoorCache = {}

    for _, door in ipairs(doors) do
        DoorCache[door.id] = door
        RegisterDoorNative(door)
        CreateInteractionPoint(door)
        RefreshAccessHint(door.id)
    end

    if Config.Debug then
        print(('[qb-doorcreator] initialized %d door(s)'):format(#doors))
    end
end)

RegisterNetEvent('qb-doorcreator:client:addDoor', function(door)
    DoorCache[door.id] = door
    RegisterDoorNative(door)
    CreateInteractionPoint(door)
    RefreshAccessHint(door.id)
    if NotifyNuiDoorChange then NotifyNuiDoorChange('doorAdded', door) end
end)

RegisterNetEvent('qb-doorcreator:client:updateDoor', function(door)
    local existing = DoorCache[door.id]
    DoorCache[door.id] = door

    if not existing then
        RegisterDoorNative(door)
        CreateInteractionPoint(door)
        RefreshAccessHint(door.id)
        if NotifyNuiDoorChange then NotifyNuiDoorChange('doorUpdated', door) end
        return
    end

    if existing.model ~= door.model or coordsChanged(existing.coords, door.coords) or existing.fallback ~= door.fallback then
        -- Model/position/mode changed - cheapest correct fix is to
        -- fully re-register rather than trying to diff native state.
        RegisterDoorNative(door)
    else
        ApplyDoorState(door)
    end

    -- The point only needs to physically move if coords changed - it
    -- reads DoorCache live inside nearby() for the lock-state label,
    -- so a label-only change never needs a rebuild. The access hint,
    -- on the other hand, can go stale on ANY access-rule edit, so it
    -- is always refreshed here regardless of what else changed.
    if coordsChanged(existing.coords, door.coords) then
        CreateInteractionPoint(door)
    end
    RefreshAccessHint(door.id)

    if NotifyNuiDoorChange then NotifyNuiDoorChange('doorUpdated', door) end
end)

RegisterNetEvent('qb-doorcreator:client:removeDoor', function(doorId)
    local door = DoorCache[doorId]
    if door then UnregisterDoorNative(door) end
    RemoveInteractionPoint(doorId)
    AccessHints[doorId] = nil
    DoorCache[doorId] = nil
    if NotifyNuiDoorChange then NotifyNuiDoorChange('doorRemoved', doorId) end
end)

RegisterNetEvent('qb-doorcreator:client:notify', function(key, subs, notifyType)
    lib.notify({ description = Lang.T(key, subs), type = notifyType or 'inform' })
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    for id in pairs(InteractionPoints) do RemoveInteractionPoint(id) end
    HidePrompt()
end)
