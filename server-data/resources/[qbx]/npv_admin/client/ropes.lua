-- Rappel ropes: a rope hangs from the anchor point (visual, created locally on each client that is
-- near), and players can rappel down it. The descent is purely local movement with GTA's own rappel
-- animations; nothing here grants rewards, so it needs no server authority.
--   S = down, W = up, Backspace = let go. Landing happens at the ground or the rope's end.

Rappel = { active = false }

local ropeItems = {} -- rope interactables from the server: { sid, oid, coords, length, prompt }
local ropes = {}     -- [sid:oid] = rope handle (only while the player is near)
local VIEW_DISTANCE = 120.0
local MAX_ROPES = 6
-- Heist rappel animations (anim_heist@hs3f@ig1_rappel@male@): start_rappel, rappel_idle, rappel_walk,
-- rope_slide, land. They work on any humanoid ped.
local DICT = 'anim_heist@hs3f@ig1_rappel@male@'
local SPEED = 1.6      -- walking down / up the wall (m/s)
local SLIDE_SPEED = 3.6 -- holding Shift slides down the rope faster

local function key(it) return it.sid .. ':' .. it.oid end

local function deleteRope(handle)
    local ok = pcall(DeleteRope, handle)
    if not ok then pcall(function() DeleteRope(Citizen.PointerValueIntInitialized(handle)) end) end
end

local function createRope(it)
    RopeLoadTextures()
    local waited = 0
    while not RopeAreTexturesLoaded() and waited < 2000 do Wait(50) waited = waited + 50 end
    local c, len = it.coords, (it.length or 20) + 0.0
    local rope = AddRope(c.x + 0.0, c.y + 0.0, c.z + 0.0, 0.0, 0.0, 0.0, len, 4, len, 0.5, 0.0, false, true, false, 5.0, false, 0)
    pcall(ActivatePhysics, rope)
    return rope
end

---Called with the full interactable list whenever it changes.
function Rappel.SetList(list)
    ropeItems = {}
    for _, it in ipairs(list or {}) do
        if it.kind == 'rope' then ropeItems[#ropeItems + 1] = it end
    end
    -- Drop ropes that no longer exist in any live scenario.
    local valid = {}
    for _, it in ipairs(ropeItems) do valid[key(it)] = true end
    for k, handle in pairs(ropes) do
        if not valid[k] then deleteRope(handle) ropes[k] = nil end
    end
end

-- Keep ropes created only for nearby anchors (GTA limits how many ropes can exist at once).
CreateThread(function()
    while true do
        if #ropeItems > 0 then
            local p = GetEntityCoords(PlayerPedId())
            local count = 0
            for _, it in ipairs(ropeItems) do
                local k, c = key(it), it.coords
                local near = #(p - vec3(c.x, c.y, c.z)) < VIEW_DISTANCE
                if near and not ropes[k] and count < MAX_ROPES then
                    ropes[k] = createRope(it)
                elseif not near and ropes[k] then
                    deleteRope(ropes[k])
                    ropes[k] = nil
                end
                if ropes[k] then count = count + 1 end
            end
            Wait(1500)
        else
            Wait(3000)
        end
    end
end)

-- Animation sets, tried in order. The first one whose idle clip really starts playing is used, so a
-- clip that refuses to play on this ped/build falls back instead of leaving the player standing there.
local SETS = {
    { dict = 'anim_heist@hs3f@ig1_rappel@male@', intro = 'start_rappel', idle = 'rappel_idle', walk = 'rappel_walk', slide = 'rope_slide', land = 'land' },
    { dict = 'missrappel', idle = 'rappel_idle', walk = 'rappel_loop', slide = 'rope_slide', land = 'land' },
}

local function loadDict(dict)
    RequestAnimDict(dict)
    local t = GetGameTimer() + 3000
    while not HasAnimDictLoaded(dict) and GetGameTimer() < t do Wait(10) end
    return HasAnimDictLoaded(dict)
end

local function playClip(ped, set, clip, flag)
    TaskPlayAnim(ped, set.dict, clip, 4.0, -4.0, -1, flag, 0.0, false, false, false)
end

local function isPlaying(ped, set, clip)
    return IsEntityPlayingAnim(ped, set.dict, clip, 3)
end

---Returns the first animation set whose idle clip actually plays on this ped (or nil).
local function pickSet(ped)
    for _, set in ipairs(SETS) do
        if loadDict(set.dict) then
            playClip(ped, set, set.idle, 1)
            Wait(350)
            if isPlaying(ped, set, set.idle) then return set end
            print(('^3[npv_admin] rappel: %s / %s did not play, trying the next set^7'):format(set.dict, set.idle))
            ClearPedTasks(ped)
        else
            print(('^3[npv_admin] rappel: could not load animation dictionary %s^7'):format(set.dict))
        end
    end
    return nil
end

local function groundBelow(x, y, z)
    local ok, gz = GetGroundZFor_3dCoord(x, y, z, false)
    return ok and gz or nil
end

local function help(text)
    BeginTextCommandDisplayHelp('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayHelp(0, false, false, -1)
end

local function release(ped)
    SetEntityCollision(ped, true, true)
    SetEntityHasGravity(ped, true)
    SetPedCanRagdoll(ped, true)
    FreezeEntityPosition(ped, false)
end

-- The ped hangs from a hidden local anchor object that we move; the ped is attached to it. A ped
-- held in mid-air by teleporting it every frame is treated as falling and keeps getting its clips
-- interrupted, whereas an attached ped plays its animations normally.
local ANCHOR_MODEL = 'prop_box_wood02a_pu'

local function makeAnchor(x, y, z, heading)
    local hash = joaat(ANCHOR_MODEL)
    if not lib.requestModel(hash, 3000) then return nil end
    local obj = CreateObject(hash, x, y, z, false, false, false)
    SetModelAsNoLongerNeeded(hash)
    if obj == 0 then return nil end
    SetEntityVisible(obj, false, false)
    SetEntityCollision(obj, false, false)
    FreezeEntityPosition(obj, true)
    SetEntityHeading(obj, heading)
    return obj
end

---Start rappelling down the given rope interactable.
function Rappel.Start(it)
    if Rappel.active or Nui.open then return end
    local ped = PlayerPedId()
    if IsPedInAnyVehicle(ped, false) or IsEntityDead(ped) or IsPedRagdoll(ped) then return end

    local c = it.coords
    local heading = (c.h or 0.0) + 0.0
    local rad = math.rad(heading)
    -- Hang slightly out from the wall: "behind" the direction the player faces.
    local x, y = c.x + math.sin(rad) * 0.45, c.y - math.cos(rad) * 0.45
    local top = c.z - 0.9
    local bottom = c.z - (it.length or 20)
    local z = top

    Rappel.active = true
    ClearPedTasksImmediately(ped)
    SetEntityCoordsNoOffset(ped, x, y, z, false, false, false)
    SetEntityHeading(ped, heading)

    local anchor = makeAnchor(x, y, z, heading)
    if not anchor then
        Rappel.active = false
        return lib.notify({ type = 'error', description = 'Could not set up the rappel.' })
    end
    SetEntityCollision(ped, false, false)
    SetPedCanRagdoll(ped, false)
    AttachEntityToEntity(ped, anchor, 0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, false, false, false, true, 2, true)

    local function cleanup(finalCoords)
        local p = PlayerPedId()
        ClearPedTasks(p)
        DetachEntity(p, true, true)
        if finalCoords then SetEntityCoordsNoOffset(p, finalCoords.x, finalCoords.y, finalCoords.z, false, false, false) end
        release(p)
        if DoesEntityExist(anchor) then DeleteEntity(anchor) end
    end

    local set = pickSet(ped)
    if not set then
        cleanup()
        Rappel.active = false
        lib.notify({ type = 'error', description = 'Rappel animations are unavailable. Check the F8 console.' })
        return
    end

    local state = set.idle
    local function play(clip, flag)
        if state == clip then return end
        state = clip
        playClip(PlayerPedId(), set, clip, flag)
    end
    local function holdAt(px, py, pz)
        SetEntityCoordsNoOffset(anchor, px, py, pz, false, false, false)
        SetEntityHeading(anchor, heading)
    end

    -- Optional intro clip: clip into the rope before the player can move.
    if set.intro then
        state = set.intro
        playClip(ped, set, set.intro, 0)
        local len = GetAnimDuration(set.dict, set.intro)
        local untilTime = GetGameTimer() + math.floor(math.min(len > 0 and len or 1.5, 3.0) * 1000)
        while GetGameTimer() < untilTime and Rappel.active do
            DisableAllControlActions(0)
            EnableControlAction(0, 1, true) EnableControlAction(0, 2, true)
            holdAt(x, y, z)
            Wait(0)
        end
        state = nil
        play(set.idle, 1)
    end

    local landed, exitCoords = false, nil
    local frame = 0
    while Rappel.active do
        ped = PlayerPedId()
        if IsEntityDead(ped) or Nui.open then break end
        DisableAllControlActions(0)
        EnableControlAction(0, 1, true) EnableControlAction(0, 2, true) -- look around
        help('~INPUT_MOVE_DOWN_ONLY~ Down   ~INPUT_MOVE_UP_ONLY~ Up   ~INPUT_SPRINT~ Slide   ~INPUT_FRONTEND_RRIGHT~ Let go')

        local dt = GetFrameTime()
        local moved = 0.0
        local sliding = false
        if IsDisabledControlPressed(0, 33) then                                -- S: down
            sliding = IsDisabledControlPressed(0, 21)                          -- Shift: slide
            moved = -(sliding and SLIDE_SPEED or SPEED) * dt
        end
        if IsDisabledControlPressed(0, 32) then moved = SPEED * dt end         -- W: up
        if IsDisabledControlJustPressed(0, 177) then break end                 -- Backspace: let go

        z = z + moved
        if moved == 0.0 then play(set.idle, 1)
        elseif sliding then play(set.slide, 1)
        else play(set.walk, 1) end

        -- Something may cancel the clip (damage, other scripts): put it back.
        frame = frame + 1
        if frame % 30 == 0 and state and not isPlaying(ped, set, state) then
            local clip = state
            state = nil
            play(clip, 1)
        end

        -- Back at the top: climb off onto the ledge.
        if z >= top + 0.3 then
            exitCoords = { x = c.x - math.sin(rad) * 0.7, y = c.y + math.cos(rad) * 0.7, z = c.z + 0.1 }
            break
        end

        -- Land at the ground or the end of the rope, whichever comes first.
        local gz = groundBelow(x, y, z + 0.5)
        local floor = math.max(bottom, gz and gz + 1.0 or bottom)
        if z <= floor then
            z = floor
            landed = true
        end

        holdAt(x, y, z)
        if landed then break end
        Wait(0)
    end

    cleanup(exitCoords)
    local p = PlayerPedId()
    if landed then playClip(p, set, set.land, 0) end
    RemoveAnimDict(set.dict)
    Rappel.active = false
end

-- Staff helper for trying animations on yourself:  /npv_anim <dict> <clip> [flag]   |   /npv_anim stop
-- Prints whether the clip really started, which is how to find clips that work on your ped.
RegisterCommand('npv_anim', function(_, args)
    if lib.callback.await('npv_admin:isStaff', false) ~= true then return end
    local ped = PlayerPedId()
    if not args[1] or args[1] == 'stop' then return ClearPedTasks(ped) end
    local dict, clip, flag = args[1], args[2], tonumber(args[3]) or 1
    if not clip then return print('usage: /npv_anim <dict> <clip> [flag]') end
    if not loadDict(dict) then return lib.notify({ type = 'error', description = 'Dictionary not found: ' .. dict }) end
    TaskPlayAnim(ped, dict, clip, 4.0, -4.0, -1, flag, 0.0, false, false, false)
    Wait(400)
    local ok = IsEntityPlayingAnim(ped, dict, clip, 3)
    print(('[npv_admin] %s / %s flag %d -> %s'):format(dict, clip, flag, ok and 'PLAYING' or 'not playing'))
    lib.notify({ type = ok and 'success' or 'error', description = ('%s: %s'):format(clip, ok and 'playing' or 'not playing') })
end, false)


AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for _, handle in pairs(ropes) do deleteRope(handle) end
    ropes = {}
    if Rappel.active then
        Rappel.active = false
        local ped = PlayerPedId()
        DetachEntity(ped, true, true)
        SetEntityCollision(ped, true, true)
        SetPedCanRagdoll(ped, true)
        FreezeEntityPosition(ped, false)
        ClearPedTasks(ped)
    end
end)
