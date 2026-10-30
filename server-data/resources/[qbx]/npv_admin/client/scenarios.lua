-- Live scenario interaction on the client: trigger boxes, "use" prompts, NPC conversation
-- prompts, and the visual effects fired by DM actions.

local interactables = {}
local inside = {} -- ["sid:oid"] = true while the player stands in a trigger box
local registered = {} -- ids returned by exports.interact:AddInteraction

local function useInteract()
    return Config.UseInteractResource and GetResourceState('interact') == 'started'
end

-- In Admin Mode every prompt on a placed thing becomes "Edit" and opens the DM tool on that object.
function EditInMenu(sid, oid)
    if Nui.open then return end
    Nui.Open('dm', { sid = sid, oid = oid })
end

local talkRegs = {} -- ["sid:oid"] = { id, entity } for NPC talk prompts registered on the ped itself

local function clearRegistered()
    for _, id in ipairs(registered) do
        pcall(function() exports.interact:RemoveInteraction(id) end)
    end
    registered = {}
    for k, reg in pairs(talkRegs) do
        pcall(function() exports.interact:RemoveInteraction(reg.id) end)
        talkRegs[k] = nil
    end
end

-- Things that get their prompt on the entity itself (NPC talk, trolleys, doors).
local function onEntity(it)
    return it.netId ~= nil and (it.talk or it.kind == 'trolley' or it.kind == 'door')
end

-- What the prompt(s) on a placed thing offer right now. Admin Mode turns everything into "Edit".
local function optionsFor(it)
    local sid, oid = it.sid, it.oid
    local function guarded(fn) return function() if Nui.open or Editor.placing then return end fn() end end
    if AdminMode then return { { label = 'Edit', action = guarded(function() EditInMenu(sid, oid) end) } } end
    if it.kind == 'door' then
        local list = {}
        if it.locked then
            if it.tmt then list[#list + 1] = { label = 'Plant thermite', action = guarded(function() Door.Thermite(it) end) } end
            if it.hck then list[#list + 1] = { label = 'Hack the panel', action = guarded(function() Door.Hack(it) end) } end
        end
        return list
    end
    if it.talk then return { { label = 'Talk to ' .. (it.label or 'them'), action = guarded(function() OpenDialogue(sid, oid) end) } } end
    return { { label = it.prompt or 'Grab', action = guarded(function() Trolley.Start(it) end) } }
end

-- These prompts are attached to the entity (not to fixed coordinates): interact then anchors them on the
-- ped's skeleton root / the prop's origin plus an offset, wherever it stands or moves. The entity can
-- stream in and out, so this is re-checked regularly and re-registered if the handle or the options changed.
local function registerTalk(it)
    local k = it.sid .. ':' .. it.oid
    if not it.netId or not NetworkDoesNetworkIdExist(it.netId) then return end
    local ent = NetworkGetEntityFromNetworkId(it.netId)
    if not ent or ent == 0 or not DoesEntityExist(ent) then return end
    local opts = optionsFor(it)
    local reg = talkRegs[k]
    if #opts == 0 then
        if reg then pcall(function() exports.interact:RemoveInteraction(reg.id) end) talkRegs[k] = nil end
        return
    end
    local sig = (AdminMode and 'a' or 'p') .. tostring(it.locked)
    if reg and reg.entity == ent and reg.sig == sig then return end
    if reg then pcall(function() exports.interact:RemoveInteraction(reg.id) end) end
    local offset
    if it.kind == 'trolley' then
        offset = vec3(0.0, 0.0, 0.8) -- aim at the middle of the load, not the base
    elseif it.kind == 'door' then
        local mn, mx = GetModelDimensions(GetEntityModel(ent)) -- the middle of the door, not its hinge
        offset = vec3((mn.x + mx.x) / 2, (mn.y + mx.y) / 2, (mn.z + mx.z) / 2)
    end
    local ok, id = pcall(function()
        return exports.interact:AddEntityInteraction({
            netId = it.netId,
            name = ('npv_%s_%s'):format(it.sid, it.oid),
            distance = Config.InteractDistance,
            interactDst = it.talk and (Config.InteractTalkDistance or Config.InteractUseDistance) or (Config.InteractUseDistance + 0.5),
            offset = offset,
            options = opts,
        })
    end)
    if ok and id then talkRegs[k] = { id = id, entity = ent, sig = sig } end
end


CreateThread(function()
    while true do
        if useInteract() then
            local valid = {}
            for _, it in ipairs(interactables) do
                if onEntity(it) then
                    valid[it.sid .. ':' .. it.oid] = true
                    registerTalk(it)
                end
            end
            -- Drop registrations for NPCs that no longer exist in any live scenario.
            for k, reg in pairs(talkRegs) do
                if not valid[k] then
                    pcall(function() exports.interact:RemoveInteraction(reg.id) end)
                    talkRegs[k] = nil
                end
            end
        end
        Wait(2000)
    end
end)

-- "use" / "talk" prompts go through the interact resource when available.
local function registerAll()
    clearRegistered()
    if not useInteract() then return end
    for _, it in ipairs(interactables) do
        local mapDoor = it.kind == 'door' and it.world -- an existing map door has no entity of ours: prompt at a point
        local doorOpts = mapDoor and optionsFor(it) or nil
        if it.kind ~= 'trigger' and (mapDoor and #doorOpts > 0 or (it.kind ~= 'door' and not onEntity(it))) then
            local sid, oid = it.sid, it.oid
            local c = it.coords
            local ok, id = pcall(function()
                return exports.interact:AddInteraction({
                    coords = vec3(c.x, c.y, c.z),
                    distance = Config.InteractDistance,
                    interactDst = mapDoor and (Config.InteractUseDistance + 0.5) or Config.InteractUseDistance,
                    name = ('npv_%s_%s'):format(sid, oid),
                    options = doorOpts or {
                        {
                            label = AdminMode and 'Edit' or (it.prompt or 'Use'),
                            action = function()
                                if Nui.open or Editor.placing then return end
                                if AdminMode then return EditInMenu(sid, oid) end
                                if it.kind == 'trolley' then Trolley.Start(it)
                                elseif it.kind == 'rope' then Rappel.Start(it)
                                else TriggerServerEvent('npv_admin:server:interact', sid, oid, 'use') end
                            end,
                        },
                    },
                })
            end)
            if ok and id then registered[#registered + 1] = id end
        end
    end
end

RegisterNetEvent('npv_admin:client:interactables', function(list)
    interactables = list or {}
    -- Leaving a box that vanished must not leave a stale "inside" flag behind.
    local valid = {}
    for _, it in ipairs(interactables) do valid[it.sid .. ':' .. it.oid] = true end
    for key in pairs(inside) do
        if not valid[key] then inside[key] = nil end
    end
    for _, it in ipairs(interactables) do
        if it.kind == 'trolley' then Trolley.empty[it.sid .. ':' .. it.oid] = nil end -- listed again = refilled
    end
    registerAll()
    Rappel.SetList(interactables)
    Door.SyncWorld(interactables)
end)

-- Prompts are rebuilt when Admin Mode is switched, so their label changes straight away.
AddEventHandler('npv_admin:client:adminModeChanged', function()
    registerAll()
    for _, it in ipairs(interactables) do
        if onEntity(it) then registerTalk(it) end
    end
end)

-- If interact (re)starts after us, register again; if it stops, its interactions vanish with it.
AddEventHandler('onResourceStart', function(res)
    if res == 'interact' then Wait(500) registerAll() end
end)
AddEventHandler('onResourceStop', function(res)
    if res == 'interact' then registered = {} elseif res == GetCurrentResourceName() then clearRegistered() end
end)

local function inBox(p, it)
    local c, s = it.coords, it.size
    return math.abs(p.x - c.x) <= s.x / 2 and math.abs(p.y - c.y) <= s.y / 2 and p.z >= c.z - 1.0 and p.z <= c.z + s.z
end

local function drawPrompt(text)
    BeginTextCommandDisplayHelp('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayHelp(0, false, false, -1)
end

CreateThread(function()
    while true do
        local sleep = 400
        if #interactables > 0 then
            local ped = PlayerPedId()
            local p = GetEntityCoords(ped)
            local best, bestDist
            for _, it in ipairs(interactables) do
                local c = it.coords
                local d = #(p - vec3(c.x, c.y, c.z))
                if it.kind == 'trigger' then
                    if d < 150.0 then
                        sleep = math.min(sleep, 200)
                        local now = inBox(p, it)
                        local key = it.sid .. ':' .. it.oid
                        if now and not inside[key] then
                            inside[key] = true
                            TriggerServerEvent('npv_admin:server:interact', it.sid, it.oid, 'enter')
                        elseif not now and inside[key] then
                            inside[key] = nil
                            TriggerServerEvent('npv_admin:server:interact', it.sid, it.oid, 'leave')
                        end
                    end
                elseif not useInteract() and d <= Config.TalkDistance and (not bestDist or d < bestDist) and (it.kind ~= 'door' or #optionsFor(it) > 0) then
                    best, bestDist = it, d
                end
            end
            if best and not Nui.open and not Editor.placing then
                sleep = 0
                local doorOpts = best.kind == 'door' and optionsFor(best) or nil
                drawPrompt(('Press ~INPUT_PICKUP~ to %s'):format(doorOpts and doorOpts[1].label:lower() or (AdminMode and 'edit' or (best.talk and ('talk to ' .. (best.label or 'them')) or (best.prompt or 'use')))))
                if IsControlJustPressed(0, Config.InteractControl) then
                    if doorOpts then doorOpts[1].action()
                    elseif AdminMode then EditInMenu(best.sid, best.oid)
                    elseif best.talk then OpenDialogue(best.sid, best.oid)
                    elseif best.kind == 'trolley' then Trolley.Start(best)
                    elseif best.kind == 'rope' then Rappel.Start(best)
                    else TriggerServerEvent('npv_admin:server:interact', best.sid, best.oid, 'use') end
                end
            end
        end
        Wait(sleep)
    end
end)

-- DM action effects ------------------------------------------------------------------------------------
local fx = {}

function fx.narrate(d)
    Nui.Send('narrate', { text = d.text, seconds = d.seconds })
end

function fx.flash()
    SetFlash(0, 0, 100, 1500, 100)
    AnimpostfxPlay('FlashOut', 0, false)
    CreateThread(function()
        local alpha = 255
        while alpha > 0 do
            DrawRect(0.5, 0.5, 1.0, 1.0, 255, 255, 255, alpha)
            alpha = alpha - 4
            Wait(0)
        end
    end)
end

function fx.black(d)
    DoScreenFadeOut(400)
    SetTimeout((d.seconds or 4) * 1000, function() DoScreenFadeIn(800) end)
end

function fx.blur(d)
    AnimpostfxPlay('DrugsMichaelAliensFight', 0, true)
    SetTimeout((d.seconds or 5) * 1000, function() AnimpostfxStop('DrugsMichaelAliensFight') end)
end

function fx.shake(d)
    ShakeGameplayCam('LARGE_EXPLOSION_SHAKE', 0.4)
    SetTimeout((d.seconds or 3) * 1000, function() StopGameplayCamShaking(true) end)
end

function fx.knockdown(d)
    local ped = PlayerPedId()
    SetPedToRagdoll(ped, (d.seconds or 5) * 1000, (d.seconds or 5) * 1000, 0, false, false, false)
end

function fx.freeze(d)
    FreezeEntityPosition(PlayerPedId(), d.on == true)
end

function fx.lightning()
    ForceLightningFlash()
end

function fx.blackout(d)
    SetArtificialLightsState(d.on == true)
    SetArtificialLightsStateAffectsVehicles(false)
end

-- Only one client (the staff member) runs this; explosions are networked, so everyone sees them.
function fx.explosion(d)
    local c = d.coords
    local size = (d.size or 1.0) + 0.0
    local spread = d.spread or 0
    for _ = 1, d.count or 1 do
        local ox, oy = (math.random() * 2 - 1) * spread, (math.random() * 2 - 1) * spread
        AddExplosion(c.x + ox, c.y + oy, c.z, d.kind or 0, math.min(size, 1.0), true, false, size)
        Wait(250)
    end
end

function fx.sound(d)
    local def = Config.DmSounds[d.key]
    if not def or not d.coords then return end
    PlaySoundFromCoord(-1, def[1], d.coords.x + 0.0, d.coords.y + 0.0, d.coords.z + 0.0, def[2], false, 80.0, false)
end

function fx.fire(d)
    local c = d.coords
    StartScriptFire(c.x, c.y, c.z, 10, false)
end

RegisterNetEvent('npv_admin:client:dmaction', function(name, data)
    local fn = fx[name]
    if fn then fn(data or {}) end
end)

-- Blackout state for players who join mid-event.
CreateThread(function()
    Wait(3000)
    if GlobalState.npvBlackout then SetArtificialLightsState(true) end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    SetArtificialLightsState(false)
    FreezeEntityPosition(PlayerPedId(), false)
end)
