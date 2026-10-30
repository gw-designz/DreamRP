-- Grabbing from heist trolleys. The server decides what is paid and when; this file plays the animation
-- (a synchronised scene positioned on the trolley, so the animation itself places the player) and asks the
-- server for one payout per stack. The player clicks Left Mouse to grab one stack at a time; Backspace stops.

Trolley = { active = false, empty = {} } -- empty["sid:oid"] = true once everything was taken (cleared when the server lists it again)

local ERRORS = {
    in_use = 'Someone else is already grabbing from this.',
    empty = 'There is nothing left to grab.',
    too_far = 'Move closer to the trolley.',
    not_found = 'This trolley is not available.',
    not_grabbing = 'You are not grabbing from this trolley.',
    too_fast = 'Slow down.',
    could_not_pay = 'Nothing could be given to you. Tell staff.',
}

local CONTROL_ATTACK, CONTROL_BACK = 24, 177 -- left mouse, backspace

local function say(text, kind)
    lib.notify({ type = kind or 'inform', description = text })
end

local function loadDict(dict)
    RequestAnimDict(dict)
    local t = GetGameTimer() + 4000
    while not HasAnimDictLoaded(dict) and GetGameTimer() < t do Wait(10) end
    return HasAnimDictLoaded(dict)
end

local function entityOf(netId)
    if not netId or not NetworkDoesNetworkIdExist(netId) then return nil end
    local ent = NetworkGetEntityFromNetworkId(netId)
    if ent and ent ~= 0 and DoesEntityExist(ent) then return ent end
end

local function takeControl(ent)
    local untilTime = GetGameTimer() + 1500
    while not NetworkHasControlOfEntity(ent) and GetGameTimer() < untilTime do
        NetworkRequestControlOfEntity(ent)
        Wait(0)
    end
end

-- Bottom-right key hints (drawn by the NUI). Sent only when they change.
local lastHint
local function hint(busy)
    local key = busy and 'busy' or (busy == nil and 'off' or 'ready')
    if key == lastHint then return end
    lastHint = key
    if key == 'off' then return Nui.Send('keyhint', nil) end
    Nui.Send('keyhint', { items = {
        { key = 'LMB', label = 'Grab', dim = busy },
        { key = 'BACKSPACE', label = 'Stop' },
    } })
end

---One synchronised scene whose origin is the trolley. `parts` = { { ent, dict, clip, ped = true? } }.
---opts: hold (stay on the last frame), loop, from / to (clip phase 0..1), rate.
local function playScene(origin, parts, opts)
    opts = opts or {}
    local id = NetworkCreateSynchronisedScene(origin.x, origin.y, origin.z, origin.rx, origin.ry, origin.rz, 2,
        opts.hold == true, opts.loop == true, opts.to or 1065353216, opts.from or 0.0, opts.rate or 1.0)
    for _, p in ipairs(parts) do
        if p.ped then
            NetworkAddPedToSynchronisedScene(p.ent, id, p.dict, p.clip, 1.5, -4.0, 1, 16, 1148846080, 0)
        else
            NetworkAddEntityToSynchronisedScene(p.ent, id, p.dict, p.clip, 4.0, -8.0, 1)
        end
    end
    NetworkStartSynchronisedScene(id)
    return id
end

local function lockControls()
    DisableAllControlActions(0)
    EnableControlAction(0, 1, true) EnableControlAction(0, 2, true) -- look around
end

local function makeObject(modelName, near)
    local model = joaat(modelName)
    if not IsModelInCdimage(model) then return nil end
    RequestModel(model)
    local t = GetGameTimer() + 3000
    while not HasModelLoaded(model) and GetGameTimer() < t do Wait(10) end
    if not HasModelLoaded(model) then return nil end
    local c = GetEntityCoords(near)
    local obj = CreateObject(model, c.x, c.y, c.z - 1.0, true, false, false)
    SetModelAsNoLongerNeeded(model)
    if not obj or obj == 0 then return nil end
    SetEntityCollision(obj, false, false)
    return obj
end

local function dropObject(obj)
    if obj and DoesEntityExist(obj) then
        DetachEntity(obj, true, true)
        DeleteEntity(obj)
    end
end

---Hold a bag in the right hand (for animations that have no bag clips, or when the bag clips do not play).
local function handBag(ped)
    local b = Config.TrolleyBag
    local obj = makeObject(b.handModel, ped)
    if not obj then return nil end
    AttachEntityToEntity(obj, ped, GetPedBoneIndex(ped, b.bone), b.offset.x, b.offset.y, b.offset.z,
        b.rotation.x, b.rotation.y, b.rotation.z, true, true, false, true, 1, true)
    return obj
end

local bagObject -- kept at file level so a resource stop can clean it up

---Start grabbing from a trolley interactable ({ sid, oid, netId, prompt }).
function Trolley.Start(it)
    if Trolley.active or Nui.open then return end
    local key = it.sid .. ':' .. it.oid
    if Trolley.empty[key] then return say(ERRORS.empty, 'error') end
    local ped = PlayerPedId()
    if IsPedInAnyVehicle(ped, false) or IsEntityDead(ped) or IsPedRagdoll(ped) then return end

    local trolley = entityOf(it.netId)
    if not trolley then return say('Get a little closer first.', 'error') end

    local begin = lib.callback.await('npv_admin:trolley', false, 'begin', it.sid, it.oid)
    if not begin or not begin.ok then return say(ERRORS[begin and begin.error] or 'You cannot do that right now.', 'error') end

    local anim = begin.anim
    if not anim or not loadDict(anim.dict) then
        lib.callback.await('npv_admin:trolley', false, 'end', it.sid, it.oid)
        return say('Could not load the grab animation.', 'error')
    end

    Trolley.active = true
    takeControl(trolley)
    local pos, rot = GetEntityCoords(trolley), GetEntityRotation(trolley, 2)
    local origin = { x = pos.x, y = pos.y, z = pos.z, rx = rot.x, ry = rot.y, rz = rot.z } -- fixed: the trolley may be swapped when empty
    SetCurrentPedWeapon(ped, joaat('WEAPON_UNARMED'), true)

    local total = math.max(begin.total or begin.left, 1)
    local left = begin.left

    -- The bag. It plays inside the scene when the animation has bag clips; otherwise it is held in the hand.
    local sceneBag = false
    if Config.TrolleyBag and Config.TrolleyBag.enabled then
        if anim.bag then
            bagObject = makeObject(Config.TrolleyBag.model, ped)
            sceneBag = bagObject ~= nil
        else
            bagObject = handBag(ped)
        end
    end

    local function parts(clip, bagClip, withProp)
        local list = { { ped = true, ent = ped, dict = anim.dict, clip = clip } }
        if sceneBag and bagClip then list[#list + 1] = { ent = bagObject, dict = anim.dict, clip = bagClip } end
        if withProp and anim.prop then list[#list + 1] = { ent = trolley, dict = anim.dict, clip = anim.prop } end
        return list
    end

    local stopped = false
    local scene = playScene(origin, parts(anim.enter, anim.bag and anim.bag.enter), { hold = true })

    -- If the bag clips did not take, fall back to holding a bag instead of leaving it lying on the floor.
    Wait(350)
    if sceneBag and not IsEntityPlayingAnim(bagObject, anim.dict, anim.bag.enter, 3) then
        dropObject(bagObject)
        sceneBag = false
        bagObject = handBag(ped)
    end

    local introMs = math.floor(math.min(math.max(GetAnimDuration(anim.dict, anim.enter), 0.8), 4.0) * 1000)
    local readyAt = GetGameTimer() + introMs
    local grabMs = math.floor(math.min(math.max(begin.seconds, 2), 30) * 1000)
    local propScene = nil -- the trolley's own clip (the cash / gold disappearing), played once and held, never looped
    local grabStart = nil -- set by the click; from then on one stack is paid every grabMs until the trolley is empty
    hint(true) -- greyed out until the intro has finished

    while not stopped and Trolley.active do
        ped = PlayerPedId()
        lockControls()
        local now = GetGameTimer()

        if IsDisabledControlJustPressed(0, CONTROL_BACK) or IsEntityDead(ped) or Nui.open then break end
        if #(GetEntityCoords(ped) - vec3(origin.x, origin.y, origin.z)) > Config.TrolleyMaxDistance + 2.5 then break end

        if not grabStart then
            if now >= readyAt then
                hint(false)
                if IsDisabledControlJustPressed(0, CONTROL_ATTACK) then
                    -- One click starts the grab; it keeps going until everything is taken (or Backspace).
                    scene = playScene(origin, parts(anim.grab, anim.bag and anim.bag.grab, false), { loop = true })
                    if anim.prop then
                        -- Plays once from where the trolley currently is, stretched over the time the remaining stacks take,
                        -- and holds its last frame: the load stays gone, it never restarts.
                        local from = (total - left) / total
                        local want = left * grabMs / 1000
                        local rate = math.min(math.max(GetAnimDuration(anim.dict, anim.prop) * (1.0 - from) / math.max(want, 1.0), 0.3), 3.0)
                        propScene = playScene(origin, { { ent = trolley, dict = anim.dict, clip = anim.prop } }, { hold = true, from = from, rate = rate })
                    end
                    grabStart = now
                    hint(true)
                end
            end
        elseif now - grabStart >= grabMs then
            local res = lib.callback.await('npv_admin:trolley', false, 'stack', it.sid, it.oid)
            if not res or not res.ok then
                say(ERRORS[res and res.error] or 'The grab was interrupted.', 'error')
                break
            end
            say(('You grabbed %s'):format(res.got), 'success')
            grabStart = GetGameTimer()
            left = res.left
            if res.left <= 0 then
                Trolley.empty[key] = true
                say('That is all of it.', 'inform')
                break
            end
        end
        Wait(0)
    end


    -- Leave the scene properly.
    hint(nil)
    ped = PlayerPedId()
    if not IsEntityDead(ped) then
        local exitScene = playScene(origin, parts(anim.exit, anim.bag and anim.bag.exit))
        local exitMs = math.floor(math.min(math.max(GetAnimDuration(anim.dict, anim.exit), 0.5), 3.5) * 1000)
        Wait(exitMs)
        NetworkStopSynchronisedScene(exitScene)
    end
    NetworkStopSynchronisedScene(scene)
    -- Leaving early puts the load back to match what is left; once it is all gone the trolley is not touched again.
    if propScene and not Trolley.empty[key] then NetworkStopSynchronisedScene(propScene) end
    ClearPedTasks(ped)
    dropObject(bagObject)
    bagObject = nil
    lib.callback.await('npv_admin:trolley', false, 'end', it.sid, it.oid)
    RemoveAnimDict(anim.dict)
    Trolley.active = false
end

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() or not Trolley.active then return end
    dropObject(bagObject)
    ClearPedTasksImmediately(PlayerPedId())
    Trolley.active = false
end)
