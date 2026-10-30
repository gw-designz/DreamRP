--[[
    client/nui.lua

    Owns the NUI panel's lifecycle and every callback the web/ page can
    call. Nothing here decides access or persists anything - every
    callback that mutates a door forwards straight to the matching
    ox_lib server callback (registered in server/main.lua), which
    re-checks the admin permission itself. This file's job is purely UI glue:
    open/close the panel, keep it fed with data, and relay results.

    The door list shown in the panel is never fetched fresh from the
    server. client/main.lua already keeps DoorCache perfectly in sync
    via targeted broadcast events (§9), so reusing it here means the
    panel opens instantly with zero network wait, and DoorsArray()
    below is always exactly what the server would have returned anyway.
]]

local nuiOpen = false
local panelMode = nil       -- 'create' | 'manage'
local activeDraft = nil     -- the draft currently being created (create mode only)
local queuedSibling = nil   -- a second draft to open/auto-create once activeDraft's panel session ends

-- ----------------------------------------------------------------
-- Panel plumbing
-- ----------------------------------------------------------------

local function DoorsArray()
    local list = {}
    for _, d in pairs(DoorCache) do list[#list + 1] = d end
    table.sort(list, function(a, b) return a.id < b.id end)
    return list
end

local function OpenNui(mode, payload)
    nuiOpen = true
    panelMode = mode
    payload = payload or {}
    payload.action = 'open'
    payload.mode = mode
    -- Server-owner-customizable short tags for the list view's Access
    -- column (Config.AccessTypeLabels) - sent on every open so the
    -- panel never has to ask for it separately.
    payload.accessLabels = Config.AccessTypeLabels
    SetNuiFocus(true, true)
    SendNUIMessage(payload)
end

local function CloseNui()
    nuiOpen = false
    panelMode = nil
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

--- Shows an error notification for a server error key. A couple of
--- error keys (currently just 'creator_max_group') carry a %{...}
--- placeholder in their locale template, so this is the one place
--- that knows which keys need substitutions filled in - every call
--- site can just pass the bare key without caring.
local function NotifyError(errKey)
    local subs = nil
    if errKey == 'creator_max_group' then
        subs = { max = Config.MaxDoorsPerGroup }
    end
    lib.notify({ description = Lang.T(errKey, subs), type = 'error' })
end

--- Called by client/main.lua whenever a door broadcast lands, so an
--- already-open panel's list view (or dependency/group pickers) stays
--- live without the admin needing to close and reopen it.
function NotifyNuiDoorChange(action, doorOrId)
    if not nuiOpen then return end
    SendNUIMessage({ action = action, door = doorOrId })
end

-- ----------------------------------------------------------------
-- Entry points (§6/§7)
-- ----------------------------------------------------------------

--- Called from client/creator.lua once a raycast selection (or linked
--- pair) is finalized. `sibling` is nil for a normal single door, or a
--- second draft for a multi-selected pair - see the module comment in
--- creator.lua for how linked vs independent siblings are told apart.
function OpenCreatorPanel(draft, sibling)
    activeDraft = draft
    queuedSibling = sibling
    OpenNui('create', {
        draft = draft,
        doors = DoorsArray(),
        -- Config-driven defaults for a BRAND NEW door's form (§10:
        -- Config.DefaultAutoClose). An edit form seeds these fields
        -- from the existing door instead - see app.js openFormFor().
        defaults = {
            autoClose = Config.DefaultAutoClose or 0,
            fallback = Config.NativeDoorsDefault == false,
        },
    })
end

local function OpenManagePanel()
    OpenNui('manage', { doors = DoorsArray() })
end

RegisterCommand('doormanager', function()
    lib.callback('qb-doorcreator:checkAdmin', false, function(allowed)
        if not allowed then
            lib.notify({ description = Lang.T('no_permission'), type = 'error' })
            return
        end
        OpenManagePanel()
    end)
end, false)

-- ox_lib context menu entry point (§7: "/doormanager or an ox_lib
-- context menu entry, permission-gated"). Registered once at resource
-- start; both options re-check the Qbox permission server-side before
-- doing anything.
CreateThread(function()
    lib.registerContext({
        id = 'qb_doorcreator_menu',
        title = Lang.T('menu_title'),
        options = {
            {
                title = Lang.T('menu_create'),
                icon = 'door-open',
                onSelect = function()
                    lib.callback('qb-doorcreator:checkAdmin', false, function(allowed)
                        if allowed then
                            StartDoorCreator()
                        else
                            lib.notify({ description = Lang.T('no_permission'), type = 'error' })
                        end
                    end)
                end,
            },
            {
                title = Lang.T('menu_manage'),
                icon = 'list',
                onSelect = function()
                    lib.callback('qb-doorcreator:checkAdmin', false, function(allowed)
                        if allowed then
                            OpenManagePanel()
                        else
                            lib.notify({ description = Lang.T('no_permission'), type = 'error' })
                        end
                    end)
                end,
            },
        },
    })
end)

exports('OpenDoorContextMenu', function()
    lib.showContext('qb_doorcreator_menu')
end)

-- ----------------------------------------------------------------
-- Linked / independent sibling continuation (§6)
--
-- justSavedDoor is the full door row returned by the server after a
-- successful create, or nil if the create-mode panel was cancelled.
-- submittedAccess is the RAW access object the form sent (as opposed
-- to justSavedDoor.access, which is the server's SANITIZED echo). This
-- distinction matters for passwords specifically: the server never
-- sends a plaintext password back, only its hash, so if the linked
-- sibling copied justSavedDoor.access it would inherit
-- password.enabled = true with no usable hash. Reusing the original
-- submitted access (which still has access.password.raw, the string
-- the admin actually typed) lets the sibling get its OWN correctly
-- hashed copy of the same code.
-- ----------------------------------------------------------------

local function ContinueAfterCreatePanel(justSavedDoor, submittedAccess)
    local sibling = queuedSibling
    local draft = activeDraft
    queuedSibling = nil
    activeDraft = nil

    if not sibling then return end

    local linked = draft and draft.group_id and sibling.group_id == draft.group_id

    if linked then
        if not justSavedDoor then
            -- The first door of the pair was never actually saved, so
            -- there is nothing to link the second one to. Drop it
            -- rather than creating an orphaned group member.
            return
        end

        -- Auto-create the linked sibling immediately, inheriting the
        -- door we just saved's access rules/auto-close/group so a
        -- double door only costs the admin ONE trip through the form.
        CreateThread(function()
            local payload = {
                label = (justSavedDoor.label or 'Door') .. ' (2)',
                model = sibling.model,
                coords = sibling.coords,
                group_id = justSavedDoor.group_id,
                auto_close = justSavedDoor.auto_close,
                -- Prefer the raw submitted access (has password.raw);
                -- fall back to the server's echo only if that is
                -- somehow unavailable (the sibling then just ends up
                -- with no usable password, same as before this fix,
                -- rather than throwing).
                access = submittedAccess or justSavedDoor.access,
                dependencies = {},
                fallback = justSavedDoor.fallback,
            }
            local ok, result = pcall(lib.callback.await, 'qb-doorcreator:createDoor', false, payload)
            if ok and result and result.ok then
                lib.notify({ description = Lang.T('door_created', { label = payload.label }), type = 'success' })
            else
                lib.notify({ description = Lang.T('generic_error'), type = 'error' })
            end
        end)
    else
        -- Independent pair: open a fresh create panel for the second
        -- door now that the first one's panel has fully closed, so the
        -- admin is never looking at two forms at once.
        Wait(50)
        OpenCreatorPanel(sibling, nil)
    end
end

-- ----------------------------------------------------------------
-- NUI callbacks
-- ----------------------------------------------------------------

RegisterNUICallback('close', function(_, cb)
    local wasCreateMode = panelMode == 'create'
    CloseNui()
    cb({ ok = true })
    if wasCreateMode then
        ContinueAfterCreatePanel(nil)
    end
end)

RegisterNUICallback('startCreator', function(_, cb)
    CloseNui()
    cb({ ok = true })
    StartDoorCreator()
end)

--- "Link Another Door" button in the edit panel (§5/§6 double doors).
--- Closes the panel and hands off to creator.lua's single-pick raycast
--- mode - StartDoorLinkMode() calls FinalizeLinkedDoor() below once an
--- entity is confirmed.
RegisterNUICallback('linkAnotherDoor', function(data, cb)
    CloseNui()
    cb({ ok = true })
    StartDoorLinkMode(data.id)
end)

--- Called by client/creator.lua once the second door of a link has
--- been raycast-picked. All the actual work (minting/assigning a
--- group id, cloning access rules, inserting the new door) happens
--- server-side in qb-doorcreator:linkDoor - this just relays the pick
--- and reports the outcome.
function FinalizeLinkedDoor(existingDoorId, draft)
    CreateThread(function()
        local ok, result = pcall(lib.callback.await, 'qb-doorcreator:linkDoor', false, existingDoorId, draft)
        if ok and result and result.ok then
            lib.notify({ description = Lang.T('door_created', { label = result.door.label }), type = 'success' })
        else
            local errKey = (result and result.error) or 'generic_error'
            NotifyError(errKey)
        end
    end)
end

RegisterNUICallback('createDoor', function(data, cb)
    local ok, result = pcall(lib.callback.await, 'qb-doorcreator:createDoor', false, data)

    if ok and result and result.ok then
        lib.notify({ description = Lang.T('door_created', { label = result.door.label }), type = 'success' })
        CloseNui()
        cb({ ok = true, door = result.door })
        ContinueAfterCreatePanel(result.door, data.access)
    else
        local errKey = (result and result.error) or 'generic_error'
        cb({ ok = false, error = errKey })
        NotifyError(errKey)
    end
end)

RegisterNUICallback('updateDoor', function(data, cb)
    local ok, result = pcall(lib.callback.await, 'qb-doorcreator:updateDoor', false, data.id, data)

    if ok and result and result.ok then
        lib.notify({ description = Lang.T('door_updated', { label = result.door.label }), type = 'success' })
        cb({ ok = true, door = result.door })
    else
        local errKey = (result and result.error) or 'generic_error'
        cb({ ok = false, error = errKey })
        NotifyError(errKey)
    end
end)

RegisterNUICallback('deleteDoor', function(data, cb)
    local ok, result = pcall(lib.callback.await, 'qb-doorcreator:deleteDoor', false, data.id)

    if ok and result and result.ok then
        lib.notify({ description = Lang.T('door_deleted', { label = result.label }), type = 'success' })
        cb({ ok = true })
    else
        cb({ ok = false })
        lib.notify({ description = Lang.T('generic_error'), type = 'error' })
    end
end)

RegisterNUICallback('toggleLock', function(data, cb)
    local ok, result = pcall(lib.callback.await, 'qb-doorcreator:toggleLock', false, data.id, data.locked)

    if ok and result and result.ok then
        cb({ ok = true, door = result.door })
    else
        cb({ ok = false })
        lib.notify({ description = Lang.T('generic_error'), type = 'error' })
    end
end)

RegisterNUICallback('locateDoor', function(data, cb)
    local door = DoorCache[data.id]
    if not door then cb({ ok = false }) return end

    local c = door.coords
    SetNewWaypoint(c.x, c.y)

    local blip = AddBlipForCoord(c.x, c.y, c.z)
    SetBlipSprite(blip, 1)
    SetBlipColour(blip, 3)
    SetBlipScale(blip, 0.9)
    SetBlipAsShortRange(blip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(door.label)
    EndTextCommandSetBlipName(blip)

    -- Temporary marker only - clears itself so repeated "Locate"
    -- clicks over a session do not leave a trail of stale blips.
    SetTimeout(120000, function()
        if DoesBlipExist(blip) then RemoveBlip(blip) end
    end)

    lib.notify({ description = Lang.T('located_door', { label = door.label }), type = 'success' })
    cb({ ok = true })
end)

RegisterNUICallback('teleportToDoor', function(data, cb)
    local door = DoorCache[data.id]
    if not door then cb({ ok = false }) return end

    local c = door.coords
    -- Offset a couple of units to the side of the door's heading
    -- rather than dropping the admin exactly inside the door mesh.
    local offsetX = c.x + 1.5 * math.cos(math.rad(c.heading + 90.0))
    local offsetY = c.y + 1.5 * math.sin(math.rad(c.heading + 90.0))

    RequestCollisionAtCoord(offsetX, offsetY, c.z)
    SetEntityCoords(PlayerPedId(), offsetX, offsetY, c.z, false, false, false, false)

    lib.notify({ description = Lang.T('teleported_door', { label = door.label }), type = 'success' })
    cb({ ok = true })
end)

-- ----------------------------------------------------------------
-- Keep the pause menu from popping up behind the panel while it is
-- focused. The JS side owns Escape-to-close (calls the 'close'
-- callback above); this thread only ever runs while nuiOpen is true.
-- ----------------------------------------------------------------

CreateThread(function()
    while true do
        local sleep = 500
        if nuiOpen then
            sleep = 0
            DisableControlAction(0, 200, true) -- INPUT_FRONTEND_PAUSE
        end
        Wait(sleep)
    end
end)
