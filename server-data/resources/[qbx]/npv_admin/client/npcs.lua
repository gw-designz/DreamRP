-- Applies behaviour to scenario NPCs created by the server. The server writes the `npv_npc`
-- state bag on the ped; every client that streams the ped in runs this handler, and the
-- ped's network owner is the one that actually issues tasks and plays speech.

local function animScenario(id)
    for _, a in ipairs(Config.NpcAnimations) do
        if a.id == id then return a.scenario end
    end
end

local CHATTER_MS = { 0, 45000, 25000, 12000 } -- chatter 0..3 => off / rare / sometimes / often
local running = {} -- [ped] = true while a behaviour thread exists

local function hasRoute(cfg)
    return type(cfg.patrol) == 'table' and #cfg.patrol >= 2
end

---Scripts can switch a ped's patrol off/on (set_npc_route block) through the npv_patrol state bag.
local function patrolOn(ped)
    return Entity(ped).state.npv_patrol ~= false
end

local function apply(ped, cfg)
    if not DoesEntityExist(ped) then return end
    SetEntityInvincible(ped, cfg.ai ~= 'npc')
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetPedKeepTask(ped, true)
    if cfg.voice and cfg.voice ~= '' then SetAmbientVoiceName(ped, cfg.voice) end
    local patrols = hasRoute(cfg)
    if cfg.ai ~= 'npc' then
        SetPedFleeAttributes(ped, 0, false)
        SetPedCanRagdoll(ped, false)
        FreezeEntityPosition(ped, not patrols) -- a patrolling statue still has to walk
    end
    if NetworkGetEntityOwner(ped) == PlayerId() and not patrols then
        local scenario = cfg.anim and animScenario(cfg.anim)
        ClearPedTasksImmediately(ped)
        if scenario then TaskStartScenarioInPlace(ped, scenario, 0, true) end
    end
end

local function speak(ped, line)
    PlayPedAmbientSpeechNative(ped, line, 'SPEECH_PARAMS_FORCE_NORMAL')
end

local function behaviour(ped, cfg)
    if running[ped] then return end
    running[ped] = true
    CreateThread(function()
        local greeted = {} -- [playerId] = last greet time
        local nextChat = GetGameTimer() + math.random(5000, 15000)
        local idx, leg = 1, 0
        while DoesEntityExist(ped) do
            local owner = NetworkGetEntityOwner(ped) == PlayerId()
            local now = GetGameTimer()
            if owner then
                local pc = GetEntityCoords(ped)
                -- Greeting when a player walks up.
                if cfg.greet then
                    for _, ply in ipairs(GetActivePlayers()) do
                        local pp = GetPlayerPed(ply)
                        if pp ~= 0 and #(GetEntityCoords(pp) - pc) < 3.5 and (greeted[ply] or 0) + 60000 < now then
                            greeted[ply] = now
                            speak(ped, 'GENERIC_HI')
                        end
                    end
                end
                -- Idle chatter; "chats with NPCs" only speaks while another ped is close.
                local interval = CHATTER_MS[(cfg.chatter or 0) + 1]
                if interval and interval > 0 and now >= nextChat then
                    nextChat = now + interval + math.random(0, 4000)
                    local company = true
                    if cfg.chatNpcs then
                        company = false
                        for _, other in ipairs(GetGamePool('CPed')) do
                            if other ~= ped and not IsPedAPlayer(other) and #(GetEntityCoords(other) - pc) < 4.0 then company = true break end
                        end
                    end
                    if company then speak(ped, 'CHAT_STATE') end
                end
                -- Patrol: walk the points in a loop, pausing briefly at each.
                if hasRoute(cfg) and not patrolOn(ped) then
                    if leg ~= 0 then
                        leg = 0
                        ClearPedTasks(ped)
                        local scenario = cfg.anim and animScenario(cfg.anim)
                        if scenario then TaskStartScenarioInPlace(ped, scenario, 0, true) end
                    end
                elseif hasRoute(cfg) then
                    local p = cfg.patrol[idx]
                    if leg == 0 or #(GetEntityCoords(ped) - vec3(p.x, p.y, p.z)) < 1.2 or now - leg > 25000 then
                        if leg ~= 0 then
                            idx = idx % #cfg.patrol + 1
                            p = cfg.patrol[idx]
                            Wait(2000)
                        end
                        TaskGoStraightToCoord(ped, p.x, p.y, p.z, 1.0, -1, 0.0, 0.5)
                        leg = GetGameTimer()
                    end
                end
            end
            Wait(500)
        end
        running[ped] = nil
    end)
end

AddStateBagChangeHandler('npv_npc', nil, function(bagName, _, value)
    if not value then return end
    local entity = GetEntityFromStateBagName(bagName)
    if entity == 0 then
        -- Not streamed in yet: wait for it, up to a few seconds.
        local t = GetGameTimer() + 5000
        while entity == 0 and GetGameTimer() < t do
            Wait(100)
            entity = GetEntityFromStateBagName(bagName)
        end
        if entity == 0 then return end
    end
    -- Every client dresses the ped itself (clothing is not synced for server-created peds).
    if value.appearance then Appearance.Apply(entity, value.appearance) end
    local waited = 0
    while not NetworkHasControlOfEntity(entity) and waited < 20 and NetworkGetEntityOwner(entity) ~= PlayerId() do
        Wait(100)
        waited = waited + 1
        if not DoesEntityExist(entity) then return end
    end
    apply(entity, value)
    if value.greet or (value.chatter or 0) > 0 or hasRoute(value) then behaviour(entity, value) end
end)

-- Alert NPC block: the ped stops being a statue and goes for the nearest player.
AddStateBagChangeHandler('npv_alert', nil, function(bagName, _, value)
    if not value then return end
    local ped = GetEntityFromStateBagName(bagName)
    if ped == 0 or not DoesEntityExist(ped) then return end
    if NetworkGetEntityOwner(ped) ~= PlayerId() then return end
    FreezeEntityPosition(ped, false)
    SetEntityInvincible(ped, false)
    SetPedCanRagdoll(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, false)
    SetPedCombatAttributes(ped, 46, true)
    local pc = GetEntityCoords(ped)
    local best, bestD
    for _, ply in ipairs(GetActivePlayers()) do
        local pp = GetPlayerPed(ply)
        local d = #(GetEntityCoords(pp) - pc)
        if d < 60.0 and (not bestD or d < bestD) then best, bestD = pp, d end
    end
    if best then
        ClearPedTasksImmediately(ped)
        TaskCombatPed(ped, best, 0, 16)
    end
end)
