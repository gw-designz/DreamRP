-- Locked doors: planting thermite and hacking. The server checks items, distance, the minigame result and
-- how long the charge burnt; this file only plays the animations and effects.

Door = { busy = false }

local ERRORS = {
    in_use = 'Someone else is already working on this.',
    already_open = 'It is already open.',
    too_far = 'Move closer to the door.',
    not_found = 'This door is not available.',
    not_available = 'That will not work on this door.',
    cooldown = 'The system is locked out for a moment. Try again shortly.',
    bad_state = 'That did not work. Try again.',
    too_fast = 'The charge had not finished burning.',
}

local DICT = 'anim@heists@ornate_bank@thermal_charge'

local function say(text, kind)
    lib.notify({ type = kind or 'inform', description = text })
end

local function failText(res)
    if res and res.error == 'no_item' then return ('You need %s for this.'):format(res.item or 'the right item') end
    return ERRORS[res and res.error] or 'You cannot do that right now.'
end

local function entityOf(netId)
    if not netId or not NetworkDoesNetworkIdExist(netId) then return nil end
    local ent = NetworkGetEntityFromNetworkId(netId)
    if ent and ent ~= 0 and DoesEntityExist(ent) then return ent end
end

local function loadDict(dict)
    RequestAnimDict(dict)
    local t = GetGameTimer() + 4000
    while not HasAnimDictLoaded(dict) and GetGameTimer() < t do Wait(10) end
    return HasAnimDictLoaded(dict)
end

local function loadModel(name)
    local model = joaat(name)
    if not IsModelInCdimage(model) then return nil end
    RequestModel(model)
    local t = GetGameTimer() + 3000
    while not HasModelLoaded(model) and GetGameTimer() < t do Wait(10) end
    return HasModelLoaded(model) and model or nil
end

local function faceDoor(ped, door, at)
    if door then
        TaskTurnPedToFaceEntity(ped, door, 900)
    elseif at then
        TaskTurnPedToFaceCoord(ped, at.x, at.y, at.z, 900)
    else
        return
    end
    Wait(900)
end

-- A placed door swings: the server announces it and every game that has the door animates it locally.
RegisterNetEvent('npv_admin:client:doorSwing', function(netId, from, to)
    CreateThread(function()
        local ent
        local untilTime = GetGameTimer() + 2500
        while GetGameTimer() < untilTime do
            if NetworkDoesNetworkIdExist(netId) then
                local e = NetworkGetEntityFromNetworkId(netId)
                if e and e ~= 0 and DoesEntityExist(e) then ent = e break end
            end
            Wait(100)
        end
        if not ent then
            print(('[npv_admin] door swing: netId %s is not streamed in on this client'):format(tostring(netId)))
            return -- not streamed in here; it shows the final heading when it arrives
        end
        -- Whoever owns the door sets what everyone else sees, so take ownership before moving it.
        local untilControl = GetGameTimer() + 1500
        while not NetworkHasControlOfEntity(ent) and GetGameTimer() < untilControl do
            NetworkRequestControlOfEntity(ent)
            Wait(0)
        end
        print(('[npv_admin] door swing: heading %.1f -> %.1f (now %.1f), control=%s'):format(from, to, GetEntityHeading(ent), tostring(NetworkHasControlOfEntity(ent))))
        local steps = 20
        for i = 1, steps do
            if not DoesEntityExist(ent) then return end
            SetEntityHeading(ent, (from + (to - from) * i / steps) % 360.0)
            Wait(50)
        end
        SetEntityHeading(ent, to % 360.0)
        print(('[npv_admin] door swing: finished at heading %.1f'):format(GetEntityHeading(ent)))
    end)
end)

-- Server asks which way to swing a door so its free end moves toward (or away from) this player.
-- Returns 1 / -1 (the sign of the swing), or nil when it makes no difference.
lib.callback.register('npv_admin:client:doorSwing', function(model, c, angle, dir)
    local hash = type(model) == 'number' and model or joaat(model)
    if not IsModelInCdimage(hash) then return nil end
    RequestModel(hash)
    local t = GetGameTimer() + 1500
    while not HasModelLoaded(hash) and GetGameTimer() < t do Wait(10) end
    local mn, mx = GetModelDimensions(hash)
    -- The free end of the door in plan view: the corner of its box farthest from the hinge (the origin).
    local ex, ey, best = 0.0, 0.0, -1.0
    for _, x in ipairs({ mn.x, mx.x }) do
        for _, y in ipairs({ mn.y, mx.y }) do
            if x * x + y * y > best then ex, ey, best = x, y, x * x + y * y end
        end
    end
    local p = GetEntityCoords(PlayerPedId())
    local function distAfter(theta)
        local a = math.rad(c.h + theta)
        local x = c.x + ex * math.cos(a) - ey * math.sin(a)
        local y = c.y + ex * math.sin(a) + ey * math.cos(a)
        return (x - p.x) ^ 2 + (y - p.y) ^ 2
    end
    local plus, minus = distAfter(angle), distAfter(-angle)
    if math.abs(plus - minus) < 0.01 then return nil end
    local toward = plus < minus and 1 or -1
    return dir == 'away' and -toward or toward
end)

---Hack the door's panel. The server runs the minigame on this player and decides the result.
function Door.Hack(it)
    if Door.busy or Nui.open then return end
    local ped = PlayerPedId()
    if IsPedInAnyVehicle(ped, false) or IsEntityDead(ped) then return end
    Door.busy = true
    faceDoor(ped, entityOf(it.netId), it.coords)
    TaskStartScenarioInPlace(ped, 'WORLD_HUMAN_STAND_MOBILE', 0, true)
    local res = lib.callback.await('npv_admin:door', false, 'hack', it.sid, it.oid)
    ClearPedTasks(PlayerPedId())
    if not res or not res.ok then
        say(failText(res), 'error')
    elseif res.passed then
        say('Access granted.', 'success')
    else
        say('Access denied.', 'error')
    end
    Door.busy = false
end

---Plant a thermite charge, light it (minigame), and stand back while it burns through the lock.
function Door.Thermite(it)
    if Door.busy or Nui.open then return end
    local ped = PlayerPedId()
    if IsPedInAnyVehicle(ped, false) or IsEntityDead(ped) then return end
    Door.busy = true

    local begin = lib.callback.await('npv_admin:door', false, 'thermite_begin', it.sid, it.oid)
    if not begin or not begin.ok then
        say(failText(begin), 'error')
        Door.busy = false
        return
    end

    local door = entityOf(it.netId)
    faceDoor(ped, door, it.coords)
    ped = PlayerPedId()
    local havePlant = loadDict(DICT)
    local charge
    local model = loadModel('hei_prop_heist_thermite')
    if model then
        local c = GetEntityCoords(ped)
        charge = CreateObject(model, c.x, c.y, c.z + 0.2, false, false, false)
        SetModelAsNoLongerNeeded(model)
        SetEntityCollision(charge, false, false)
        AttachEntityToEntity(charge, ped, GetPedBoneIndex(ped, 28422), 0.0, 0.0, 0.0, 0.0, 0.0, 200.0, true, true, false, true, 1, true)
    end

    -- Plant it.
    if havePlant then
        TaskPlayAnim(ped, DICT, 'thermal_charge', 8.0, -8.0, -1, 0, 0, false, false, false)
        Wait(math.floor(math.min(GetAnimDuration(DICT, 'thermal_charge'), 5.0) * 800))
    else
        Wait(1500)
    end
    local spot = GetOffsetFromEntityInWorldCoords(ped, 0.0, 0.45, 0.35)
    if charge and DoesEntityExist(charge) then
        DetachEntity(charge, true, true)
        SetEntityCoords(charge, spot.x, spot.y, spot.z, false, false, false, false)
        SetEntityHeading(charge, GetEntityHeading(ped))
        FreezeEntityPosition(charge, true)
    end
    if havePlant then
        local t = GetGameTimer() + 3000
        while IsEntityPlayingAnim(ped, DICT, 'thermal_charge', 3) and GetGameTimer() < t do Wait(50) end
    end

    local function finish(text, kind)
        if charge and DoesEntityExist(charge) then DeleteEntity(charge) end
        ClearPedTasks(PlayerPedId())
        if havePlant then RemoveAnimDict(DICT) end
        if text then say(text, kind) end
        Door.busy = false
    end

    -- Light it: the server runs the minigame on this player.
    local ignite = lib.callback.await('npv_admin:door', false, 'thermite_ignite', it.sid, it.oid)
    if not ignite or not ignite.ok then return finish(failText(ignite), 'error') end
    if not ignite.passed then return finish('The thermite fizzled out.', 'error') end

    -- Burn: sparks on the charge while the player covers their eyes.
    local fx
    RequestNamedPtfxAsset('scr_ornate_heist')
    local t = GetGameTimer() + 2000
    while not HasNamedPtfxAssetLoaded('scr_ornate_heist') and GetGameTimer() < t do Wait(10) end
    if HasNamedPtfxAssetLoaded('scr_ornate_heist') then
        UseParticleFxAsset('scr_ornate_heist')
        fx = StartParticleFxLoopedAtCoord('scr_heist_ornate_thermal_burn', spot.x, spot.y, spot.z, 0.0, 0.0, 0.0, 1.0, false, false, false, false)
    end
    if havePlant then
        ped = PlayerPedId()
        TaskPlayAnim(ped, DICT, 'cover_eyes_intro', 8.0, -8.0, -1, 0, 0, false, false, false)
        Wait(900)
        TaskPlayAnim(ped, DICT, 'cover_eyes_loop', 8.0, -8.0, -1, 1, 0, false, false, false)
    end

    local untilTime = GetGameTimer() + math.floor(ignite.burn * 1000)
    local aborted = false
    while GetGameTimer() < untilTime do
        ped = PlayerPedId()
        if IsEntityDead(ped) then aborted = true break end
        Wait(100)
    end
    if fx then StopParticleFxLooped(fx, false) end

    if aborted then
        lib.callback.await('npv_admin:door', false, 'thermite_abort', it.sid, it.oid)
        return finish(nil)
    end
    local done = lib.callback.await('npv_admin:door', false, 'thermite_done', it.sid, it.oid)
    if not done or not done.ok then return finish(failText(done), 'error') end
    finish('The lock melted away.', 'success')
end

-- Existing map / MLO doors. Like other bank scripts do, the door object itself is held at a heading: frozen at
-- its closed heading while locked, swung to its open heading when unlocked. Map objects are not shared over
-- the network, so every player's game does this for itself; the server only says what state each door is in.
local worldDoors = {} -- ["sid:oid"] = { it = latest interactable entry, anim = true while swinging }

local function headingGap(a, b)
    return math.abs(((a - b + 180.0) % 360.0) - 180.0)
end

local function findWorldObject(it)
    local obj = GetClosestObjectOfType(it.ox, it.oy, it.oz, 1.5, it.hash, false, false, false)
    return obj ~= 0 and obj or nil
end

local function wantedHeading(it)
    if it.locked then return it.ch end
    return it.ah or it.ch
end

---Called with every interactables update: remember the map doors and what state they are in.
function Door.SyncWorld(list)
    local seen = {}
    for _, it in ipairs(list) do
        if it.kind == 'door' and it.world and it.hash then
            local key = it.sid .. ':' .. it.oid
            seen[key] = true
            worldDoors[key] = worldDoors[key] or {}
            worldDoors[key].it = it
        end
    end
    for key, w in pairs(worldDoors) do
        if not seen[key] then
            -- No longer part of a live scenario: put the door back as the map had it.
            local obj = findWorldObject(w.it)
            if obj then
                SetEntityHeading(obj, w.it.ch)
                FreezeEntityPosition(obj, false)
            end
            worldDoors[key] = nil
        end
    end
end

-- The server announces a swing; each game rotates its own copy of the door.
RegisterNetEvent('npv_admin:client:worldDoorSwing', function(key, from, to)
    local w = worldDoors[key]
    if w then w.anim = true end -- set at once so the keep-in-place loop below leaves it alone
    CreateThread(function()
        local it = w and w.it
        if not it then return end
        local obj
        local untilTime = GetGameTimer() + 1500
        while not obj and GetGameTimer() < untilTime do
            obj = findWorldObject(it)
            if not obj then Wait(100) end
        end
        if obj then
            FreezeEntityPosition(obj, false)
            local steps = 20
            for i = 1, steps do
                if not DoesEntityExist(obj) then break end
                SetEntityHeading(obj, (from + (to - from) * i / steps) % 360.0)
                Wait(50)
            end
            if DoesEntityExist(obj) then
                SetEntityHeading(obj, to % 360.0)
                FreezeEntityPosition(obj, true)
            end
        end
        w.anim = false
    end)
end)

-- Keep every map door where the server says it should be (it streams in late, other scripts nudge it, etc.).
CreateThread(function()
    while true do
        for _, w in pairs(worldDoors) do
            if not w.anim and w.it then
                local obj = findWorldObject(w.it)
                if obj then
                    local want = wantedHeading(w.it)
                    if headingGap(GetEntityHeading(obj), want) > 0.8 then SetEntityHeading(obj, want) end
                    FreezeEntityPosition(obj, true)
                end
            end
        end
        Wait(1500)
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for _, w in pairs(worldDoors) do
        local obj = w.it and findWorldObject(w.it)
        if obj then
            SetEntityHeading(obj, w.it.ch)
            FreezeEntityPosition(obj, false)
        end
    end
    if Door.busy then ClearPedTasksImmediately(PlayerPedId()) end
end)
