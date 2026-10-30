--[[
    client/creator.lua

    The admin placement workflow behind /createdoor (§6), plus the
    single-entity "link another door" pick used by the NUI edit
    panel's Link Another Door button (§5/§6 double doors, after the
    fact). This file only ever produces a "draft" (model hash + coords
    + heading) and hands it off - to OpenCreatorPanel() (client/nui.lua)
    for a normal new door / linked pair, or to FinalizeLinkedDoor() for
    an after-the-fact link. Nothing in here writes to the database
    directly.

    creatorMode is nil (idle) | 'create' (/createdoor flow, supports
    multi-select) | 'link' (single-pick, joins an EXISTING door's
    group). Both modes share the same raycast/outline loop below; only
    what happens on confirm differs.

    ── HOW THE RAYCAST WORKS ──
    Every tick while placement mode is active, we cast a ray from the
    gameplay camera's position along the direction it is facing
    (RotationToDirection below - a standard rotation-to-vector
    conversion, since the game does not expose a native for it) out to
    Config.Creator.maxDistance, and ask the game what it hit
    (StartShapeTestRay / GetShapeTestResult). If the hit entity is an
    OBJECT (GetEntityType == 3 - doors are always objects, never peds
    or vehicles), we outline it with SetEntityDrawOutline so the admin
    can see exactly what they are about to capture before committing.
]]

local creatorMode = nil -- nil | 'create' | 'link'
local linkTargetDoorId = nil -- 'link' mode only: which existing door we are joining
local hoveredEntity = nil
local promptShown = false
local selectionBuffer = {} -- up to 2 drafts while multi-selecting a linked pair ('create' mode only)

-- ----------------------------------------------------------------
-- Raycast helpers
-- ----------------------------------------------------------------

--- Converts a camera rotation (pitch/roll/yaw in degrees) into a unit
--- direction vector. The game does not expose this as a native, so
--- every FiveM raycast script implements the same trig by hand.
local function RotationToDirection(rotation)
    local z = math.rad(rotation.z)
    local x = math.rad(rotation.x)
    local num = math.abs(math.cos(x))
    return vector3(
        -math.sin(z) * num,
        math.cos(z) * num,
        math.sin(x)
    )
end

--- Casts a ray from the gameplay camera and returns whether it hit
--- something, the hit coords, and the entity handle (0 if none/world).
--- Flag -1 hits everything; we only ever act on the result if it is
--- an OBJECT, so there is no need to fine-tune the intersect flags.
local function RaycastCamera(maxDistance)
    local camCoords = GetGameplayCamCoord()
    local direction = RotationToDirection(GetGameplayCamRot(2))
    local destination = camCoords + direction * maxDistance

    local rayHandle = StartShapeTestRay(
        camCoords.x, camCoords.y, camCoords.z,
        destination.x, destination.y, destination.z,
        -1, PlayerPedId(), 0
    )
    local _, hit, endCoords, _, entityHit = GetShapeTestResult(rayHandle)
    -- `hit` comes back as a genuine Lua boolean from this native (not
    -- 0/1), but is normalized defensively in case that ever changes.
    local hitBool = hit == true or hit == 1
    return hitBool, endCoords, entityHit
end

-- ----------------------------------------------------------------
-- Outline / prompt housekeeping
-- ----------------------------------------------------------------

local function ClearHoverOutline()
    if hoveredEntity then
        SetEntityDrawOutline(hoveredEntity, false)
        hoveredEntity = nil
    end
end

local function HidePrompt()
    if promptShown then
        promptShown = false
        lib.hideTextUI()
    end
end

local function ResetCreatorState()
    creatorMode = nil
    linkTargetDoorId = nil
    ClearHoverOutline()
    HidePrompt()
    selectionBuffer = {}
end

-- ----------------------------------------------------------------
-- Draft building + finalization
-- ----------------------------------------------------------------

local function BuildDraft(entity)
    local model = GetEntityModel(entity)
    local coords = GetEntityCoords(entity)
    local heading = GetEntityHeading(entity)
    return {
        model = model,
        coords = { x = coords.x, y = coords.y, z = coords.z, heading = heading },
    }
end

local function FinalizeSingle(draft)
    ResetCreatorState()
    OpenCreatorPanel(draft, nil)
end

--- Two entities have been captured via modifier+confirm. Ask once
--- whether to link them as a door group (§5/§6) before ever touching
--- the NUI or the server.
local function FinalizeGroupChoice(draftA, draftB)
    ResetCreatorState()

    local choice = lib.alertDialog({
        header = Lang.T('creator_confirmed_multi', { count = 2 }),
        content = ('%s (%s)  <->  %s (%s)'):format(
            tostring(draftA.model), 'A',
            tostring(draftB.model), 'B'
        ),
        centered = true,
        cancel = true,
        labels = {
            confirm = Lang.T('creator_link_group_yes'),
            cancel = Lang.T('creator_link_group_no'),
        },
    })

    if choice == 'confirm' then
        -- Shared group id, generated once here. The NUI save flow for
        -- draftA carries draftB along and auto-creates it right after
        -- draftA is saved, both stamped with this same group_id.
        local groupId = ('grp_%d_%d'):format(math.floor(GetGameTimer() / 1000), math.random(1000, 9999))
        draftA.group_id = groupId
        draftB.group_id = groupId
    end

    -- One call either way - client/nui.lua tells linked vs independent
    -- apart by whether group_id matches on both drafts. Linked drafts
    -- auto-create draftB the instant draftA is saved; independent
    -- drafts just open draftB's form next once draftA's panel closes
    -- (saved or cancelled), so the admin is never shown two panels at
    -- once.
    OpenCreatorPanel(draftA, draftB)
end

local function HandleConfirmSelect(entity)
    local modifierHeld = IsControlPressed(0, Config.Creator.modifierKey)
    local draft = BuildDraft(entity)

    if not modifierHeld then
        if #selectionBuffer > 0 then
            -- A multi-select was already in progress; a plain confirm
            -- finishes it as the second entity.
            selectionBuffer[#selectionBuffer + 1] = draft
            if #selectionBuffer >= 2 then
                FinalizeGroupChoice(selectionBuffer[1], selectionBuffer[2])
            else
                FinalizeSingle(draft)
            end
        else
            FinalizeSingle(draft)
        end
        return
    end

    selectionBuffer[#selectionBuffer + 1] = draft
    lib.notify({
        description = Lang.T('creator_selected', { model = tostring(draft.model), key = 'E' }),
        type = 'inform',
    })

    if #selectionBuffer >= 2 then
        FinalizeGroupChoice(selectionBuffer[1], selectionBuffer[2])
    end
end

--- 'link' mode confirm: a single pick, no multi-select branching -
--- hands straight off to FinalizeLinkedDoor() (client/nui.lua), which
--- talks to the server's dedicated qb-doorcreator:linkDoor callback.
--- Unlike normal creation, this never opens the NUI form - it clones
--- the EXISTING door's access rules directly server-side and creates
--- the new door immediately (§5/§6: quick after-the-fact double doors).
local function HandleLinkConfirm(entity)
    local draft = BuildDraft(entity)
    local targetDoorId = linkTargetDoorId
    ResetCreatorState()
    FinalizeLinkedDoor(targetDoorId, draft)
end

-- ----------------------------------------------------------------
-- Main placement loop - only runs at all while creatorMode is set;
-- otherwise this thread sleeps at 500ms and costs nothing (§9).
-- ----------------------------------------------------------------

CreateThread(function()
    while true do
        local sleep = 500

        if creatorMode then
            sleep = 0

            local hit, _, entityHit = RaycastCamera(Config.Creator.maxDistance)
            local validHit = hit and entityHit ~= 0 and GetEntityType(entityHit) == 3

            if hoveredEntity and hoveredEntity ~= entityHit then
                ClearHoverOutline()
            end

            if validHit then
                hoveredEntity = entityHit
                local color = Config.Creator.outlineColor
                for _, sel in ipairs(selectionBuffer) do
                    -- BuildDraft does not keep the entity handle, so we
                    -- compare by current coords instead - close enough
                    -- since selected entities are not expected to move.
                    local c = GetEntityCoords(entityHit)
                    if math.abs(c.x - sel.coords.x) < 0.05 and math.abs(c.y - sel.coords.y) < 0.05 then
                        color = Config.Creator.multiSelectColor
                        break
                    end
                end
                SetEntityDrawOutline(entityHit, true)
                SetEntityDrawOutlineColor(color.r, color.g, color.b, color.a)

                if not promptShown then
                    promptShown = true
                    lib.showTextUI(('[E] Select    [Backspace] Cancel'), { position = 'right-center', icon = 'crosshairs' })
                end

                if IsControlJustReleased(0, Config.Creator.confirmKey) then
                    if creatorMode == 'link' then
                        HandleLinkConfirm(entityHit)
                    else
                        HandleConfirmSelect(entityHit)
                    end
                end
            else
                HidePrompt()
                if IsControlJustReleased(0, Config.Creator.confirmKey) then
                    lib.notify({ description = Lang.T('creator_no_entity'), type = 'error' })
                end
            end

            if IsControlJustReleased(0, Config.Creator.cancelKey) then
                ResetCreatorState()
                lib.notify({ description = Lang.T('creator_cancelled'), type = 'inform' })
            end
        end

        Wait(sleep)
    end
end)

-- ----------------------------------------------------------------
-- Entry point
-- ----------------------------------------------------------------

local function StartCreatorMode()
    if creatorMode then return end
    creatorMode = 'create'
    selectionBuffer = {}
    lib.notify({
        description = Lang.T('creator_start', { key = 'E', mod = 'LShift', cancel = 'Backspace' }),
        type = 'inform',
        duration = 8000,
    })
end

RegisterCommand('createdoor', function()
    lib.callback('qb-doorcreator:checkAdmin', false, function(allowed)
        if not allowed then
            lib.notify({ description = Lang.T('no_permission'), type = 'error' })
            return
        end
        StartCreatorMode()
    end)
end, false)

--- Single-pick raycast mode for the "Link Another Door" button in the
--- NUI edit panel (§5/§6): joins `doorId`'s group without redoing the
--- whole create-a-door flow. No client-side checkAdmin round trip
--- here - reaching this button already required the panel to be open,
--- which only happens after a permission check, and the actual write
--- (qb-doorcreator:linkDoor) re-checks isAdmin() server-side anyway,
--- same as every other mutation in this resource.
local function StartLinkMode(doorId)
    if creatorMode then return end
    creatorMode = 'link'
    linkTargetDoorId = doorId
    selectionBuffer = {}
    lib.notify({
        description = Lang.T('creator_start_link', { key = 'E', cancel = 'Backspace' }),
        type = 'inform',
        duration = 8000,
    })
end

-- Exposed so client/nui.lua's buttons can trigger these flows.
StartDoorCreator = StartCreatorMode
StartDoorLinkMode = StartLinkMode
