-- Wait for Config.K9 to be available
while not (Config and Config.K9) do Citizen.Wait(500) end

if not Config.K9.enabled then return end

-- Global K9 object shared across the resource
K9 = {
    ped              = nil,
    breed            = nil,
    state            = "follow",
    target           = nil,
    isTargeting      = false,
    lastFollowSpeed  = nil,
    lastFollowIssued = 0,
}

-- Tracks whether the radial menu item is currently registered
local radialMenuRegistered = false

-- ─── Breed / Anim Mappings ────────────────────────────────────────────────────

-- Maps breed config names to the string used in GTA creature anim dict paths
local BREED_ANIM_PREFIX = {
    german_shepherd = "shepherd",
    retriever       = "retriever",
    rottweiler      = "rottweiler",
}

-- Maps K9 state names to their animation data
local STATE_ANIMS = {
    sit    = { suffix = "amb@world_dog_sitting@base",    clip = "base",          scenario = "WORLD_DOG_SITTING"  },
    lay    = { suffix = "amb@sleep_in_kennel@",          clip = "sleep_in_kennel", scenario = "WORLD_DOG_LYING"  },
    search = { suffix = "amb@world_dog_barking@idle_a",  clip = "idle_a",        scenario = "WORLD_DOG_BARKING"  },
}

-- ─── Internal Helpers ─────────────────────────────────────────────────────────

-- Returns true if the local player's job grade meets the K9 access threshold
function PlayerHasK9Access()
    local job = Bridge.Framework.fetchPlayerJob()
    if not job then return false end

    local threshold = Config.Jobs[job.name]
    if not threshold then return false end

    return threshold <= tonumber(job.grade)
end

-- Returns true if the K9 ped exists and is alive
function IsK9Alive()
    local ped = K9.ped
    if ped and DoesEntityExist(ped) then
        return not IsPedDeadOrDying(ped, true)
    end
    return false
end

-- Returns the appropriate follow speed (1–3) based on distance to the target
function GetFollowSpeed(distance)
    if distance > 20.0 then return 3.0 end
    if distance > 8.0  then return 2.0 end
    return 1.0
end

-- Issues a TaskFollowToOffsetOfEntity to the K9 and caches the speed
function IssueFollowTask(targetEntity, speed)
    TaskFollowToOffsetOfEntity(K9.ped, targetEntity, 0.0, -1.5, 0.0, speed, -1, 1.5, true)
    K9.lastFollowSpeed = speed
end

-- Returns the camera forward vector3 from the final rendered camera rotation
function GetCameraForwardVector()
    local rot  = GetFinalRenderedCamRot(2)
    local cosX = math.abs(math.cos(math.rad(rot.x)))
    return vector3(
        -math.sin(math.rad(rot.z)) * cosX,
         math.cos(math.rad(rot.z)) * cosX,
         math.sin(math.rad(rot.x))
    )
end

-- Requests an animation dict with a 1-second timeout (20 × 50ms retries).
-- Returns true if loaded, false on timeout.
function RequestAnimDictWithTimeout(dict)
    RequestAnimDict(dict)
    local tries = 0
    while not HasAnimDictLoaded(dict) and tries < 20 do
        Wait(50)
        tries = tries + 1
    end
    return HasAnimDictLoaded(dict)
end

-- Returns the server id of the given player ped, or nil if it's not a player ped
function GetServerIdFromPed(pedEntity)
    if not (pedEntity and pedEntity ~= 0) then return nil end
    if not IsPedAPlayer(pedEntity) then return nil end

    local playerIndex = NetworkGetPlayerIndexFromPed(pedEntity)
    if not playerIndex or playerIndex == -1 then return nil end

    return GetPlayerServerId(playerIndex)
end

-- ─── Animation Helpers ────────────────────────────────────────────────────────

-- Plays the idle animation for the given state on the given ped.
-- Falls back to rottweiler anim dicts if the breed-specific one is unavailable.
function PlayStateAnim(pedEntity, stateName)
    local animData   = STATE_ANIMS[stateName]
    if not animData then return end

    local breedPrefix = BREED_ANIM_PREFIX[K9.breed] or "rottweiler"
    local dictName    = string.format("creatures@%s@%s", breedPrefix, animData.suffix)
    local loaded      = RequestAnimDictWithTimeout(dictName)

    -- Fallback: try rottweiler dict if breed-specific one failed to load
    if not loaded and breedPrefix ~= "rottweiler" then
        dictName = string.format("creatures@rottweiler@%s", animData.suffix)
        loaded   = RequestAnimDictWithTimeout(dictName)
    end

    if not IsK9Alive() or K9.state ~= stateName then return end

    if loaded then
        TaskPlayAnim(pedEntity, dictName, animData.clip, 8.0, -8.0, -1, 1, 0.0, false, false, false)
    elseif animData.scenario then
        TaskStartScenarioInPlace(pedEntity, animData.scenario, 0, true)
    end
end

-- ─── Radial Menu ─────────────────────────────────────────────────────────────

-- Adds or removes the K9 radial menu item based on current access
function UpdateRadialMenu()
    if PlayerHasK9Access() then
        if not radialMenuRegistered then
            lib.addRadialItem({
                id    = "k9_menu",
                icon  = "dog",
                label = locale("k9_menu_label"),
                menu  = "k9_root_radial",
            })
            radialMenuRegistered = true
        end
    else
        if radialMenuRegistered then
            lib.removeRadialItem("k9_menu")
            radialMenuRegistered = false
        end
    end
end

-- ─── State Machine ────────────────────────────────────────────────────────────

-- Sets the K9 state and optional target entity, then applies the new state immediately
function K9:setState(newState, targetEntity)
    self.state  = newState
    self.target = targetEntity or nil
    ApplyCurrentState()
end

-- Applies the current K9.state: clears existing tasks and issues the correct new one.
-- Stationary states (sit/lay/search) spawn a deferred thread for the anim so
-- ClearPedTasksImmediately has time to flush before TaskPlayAnim fires.
function ApplyCurrentState()
    if not IsK9Alive() then return end

    SetPedFleeAttributes(K9.ped, 0, false)

    local state = K9.state

    if state == "sit" or state == "lay" or state == "search" then
        local ped = K9.ped
        ClearPedTasksImmediately(ped)
        CreateThread(function()
            Wait(100)
            if IsK9Alive() and K9.state == state then
                PlayStateAnim(ped, state)
            end
        end)

    elseif state == "stay" then
        ClearPedTasksImmediately(K9.ped)

    elseif state == "attack" then
        ClearPedTasksImmediately(K9.ped)
        if K9.target and DoesEntityExist(K9.target) then
            SetPedCombatAttributes(K9.ped, 46, true)
            SetPedCombatRange(K9.ped, 0)
            SetPedKeepTask(K9.ped, true)
            TaskCombatPed(K9.ped, K9.target, 0, 0)
        end

    elseif state == "follow" then
        local k9Pos  = GetEntityCoords(K9.ped)
        local pedPos = GetEntityCoords(cache.ped)
        ClearPedTasksImmediately(K9.ped)
        IssueFollowTask(cache.ped, GetFollowSpeed(#(k9Pos - pedPos)))

    elseif state == "follow_player" then
        if K9.target and DoesEntityExist(K9.target) then
            local k9Pos     = GetEntityCoords(K9.ped)
            local targetPos = GetEntityCoords(K9.target)
            ClearPedTasksImmediately(K9.ped)
            IssueFollowTask(K9.target, GetFollowSpeed(#(k9Pos - targetPos)))
        end
    end
end

-- ─── Behaviour Loop ──────────────────────────────────────────────────────────

-- Runs per-state maintenance at 350ms intervals:
-- • Detects K9 death / despawn distance
-- • Re-issues follow tasks when speed needs to change
-- • Auto-transitions from attack/follow_player when target is gone
function K9:startBehaviourLoop()
    CreateThread(function()
        while true do
            if not IsK9Alive() then
                -- K9 died
                lib.callback.await("p_policejob/k9/dismiss", false)
                self.ped    = nil
                self.breed  = nil
                self.state  = "follow"
                self.target = nil
                Bridge.Notify.showNotify(locale("k9_killed"), "error")
                UpdateRadialMenu()
                break
            end

            Wait(350)

            if not IsK9Alive() then break end

            local k9Pos  = GetEntityCoords(self.ped)
            local pedPos = GetEntityCoords(cache.ped)
            local distToHandler = #(k9Pos - pedPos)

            -- Despawn if too far from handler
            if distToHandler > Config.K9.despawnDistance then
                lib.callback.await("p_policejob/k9/dismiss", false)
                DeleteEntity(self.ped)
                self.ped    = nil
                self.breed  = nil
                self.state  = "follow"
                self.target = nil
                Bridge.Notify.showNotify(locale("k9_lost"), "warning")
                UpdateRadialMenu()
                break
            end

            local now = GetGameTimer()

            if self.state == "follow" then
                local speed = GetFollowSpeed(distToHandler)
                -- Re-issue follow task when speed tier changes or it's been 5 seconds
                local speedChanged    = speed ~= self.lastFollowSpeed
                local timeSinceLast   = now - self.lastFollowIssued
                if speedChanged or timeSinceLast > 5000 then
                    IssueFollowTask(cache.ped, speed)
                    self.lastFollowIssued = now
                end

            elseif self.state == "follow_player" then
                if self.target and DoesEntityExist(self.target) and not IsEntityDead(self.target) then
                    local dist  = #(k9Pos - GetEntityCoords(self.target))
                    local speed = GetFollowSpeed(dist)
                    if speed ~= self.lastFollowSpeed or now - self.lastFollowIssued > 5000 then
                        IssueFollowTask(self.target, speed)
                        self.lastFollowIssued = now
                    end
                else
                    -- Target lost or died
                    self:setState("follow")
                    Bridge.Notify.showNotify(locale("k9_target_lost"), "warning")
                end

            elseif self.state == "attack" then
                local targetValid = self.target and DoesEntityExist(self.target) and not IsEntityDead(self.target)
                if targetValid then
                    TaskCombatPed(self.ped, self.target, 0, 0)
                else
                    self:setState("follow")
                    Bridge.Notify.showNotify(locale("k9_neutralised"), "success")
                end
            end
        end
    end)
end

-- ─── K9 Commands ─────────────────────────────────────────────────────────────

-- Spawns a K9 of the given breed (or default breed if unspecified).
-- Validates access, checks server, requests model, configures ped.
function K9:spawn(requestedBreed)
    if not PlayerHasK9Access() then
        return Bridge.Notify.showNotify(locale("no_access"), "error")
    end

    if IsK9Alive() then
        return Bridge.Notify.showNotify(locale("k9_already_deployed"), "error")
    end

    -- Find breed config (default to first entry)
    local modelConfig = Config.K9.models[1]
    for _, entry in ipairs(Config.K9.models) do
        if entry.breed == requestedBreed then
            modelConfig = entry
            break
        end
    end

    -- Server-side spawn permission check
    local allowed = lib.callback.await("p_policejob/k9/spawn", false, modelConfig.breed)
    if not allowed then
        return Bridge.Notify.showNotify(locale("k9_spawn_denied"), "error")
    end

    -- Place K9 slightly in front of the player
    local spawnPos = GetOffsetFromEntityInWorldCoords(cache.ped, 1.5, 0.0, 0.0)
    local heading  = GetEntityHeading(cache.ped)

    local modelHash = lib.requestModel(modelConfig.model)
    if not modelHash then
        return Bridge.Notify.showNotify(locale("k9_model_failed"), "error")
    end

    local ped = CreatePed(28, modelHash, spawnPos.x, spawnPos.y, spawnPos.z, heading, true, false)
    self.ped  = ped
    SetModelAsNoLongerNeeded(modelHash)

    if not DoesEntityExist(ped) then
        self.ped = nil
        return Bridge.Notify.showNotify(locale("k9_create_failed"), "error")
    end

    SetEntityHealth(ped, Config.K9.health)
    SetPedArmour(ped, Config.K9.armor)
    SetEntityInvincible(ped, false)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetPedFleeAttributes(ped, 0, false)
    SetEntityAsMissionEntity(ped, true, true)
    SetPedCanRagdoll(ped, true)

    self.breed  = modelConfig.breed
    self.state  = "follow"
    self.target = nil

    Bridge.Notify.showNotify(locale("k9_deployed"):format(modelConfig.name), "success")
    UpdateRadialMenu()
    self:startBehaviourLoop()
end

-- Dismisses the deployed K9
function K9:dismiss()
    if not PlayerHasK9Access() then
        return Bridge.Notify.showNotify(locale("no_access"), "error")
    end

    if not self.ped then
        return Bridge.Notify.showNotify(locale("k9_no_deployed"), "error")
    end

    lib.callback.await("p_policejob/k9/dismiss", false)

    if DoesEntityExist(self.ped) then
        ClearPedTasksImmediately(self.ped)
        DeleteEntity(self.ped)
    end

    self.ped    = nil
    self.breed  = nil
    self.state  = "follow"
    self.target = nil

    Bridge.Notify.showNotify(locale("k9_dismissed"), "success")
    UpdateRadialMenu()
end

-- Orders K9 to follow the handler
function K9:follow()
    if not PlayerHasK9Access() then return Bridge.Notify.showNotify(locale("no_access"), "error") end
    if not IsK9Alive() then return Bridge.Notify.showNotify(locale("k9_no_deployed"), "error") end

    self:setState("follow")
    Bridge.Notify.showNotify(locale("k9_following_you"), "success")
end

-- Orders K9 to follow a specific player by server id
function K9:followPlayer(targetServerId)
    if not PlayerHasK9Access() then return Bridge.Notify.showNotify(locale("no_access"), "error") end
    if not IsK9Alive() then return Bridge.Notify.showNotify(locale("k9_no_deployed"), "error") end

    local ok, pedNetId = lib.callback.await("p_policejob/k9/getTargetNetId", false, targetServerId)
    if not ok or not pedNetId then
        return Bridge.Notify.showNotify(locale("k9_target_not_found"), "error")
    end

    local targetPed = NetToPed(pedNetId)
    if not DoesEntityExist(targetPed) then
        return Bridge.Notify.showNotify(locale("k9_not_in_range"), "error")
    end

    self:setState("follow_player", targetPed)
    Bridge.Notify.showNotify(locale("k9_following_player"):format(targetServerId), "success")
end

-- Opens targeting mode to select an attack target (ped only)
function K9:attack()
    if not PlayerHasK9Access() then return Bridge.Notify.showNotify(locale("no_access"), "error") end
    if not IsK9Alive() then return Bridge.Notify.showNotify(locale("k9_no_deployed"), "error") end
    if self.isTargeting then return end

    self.isTargeting = true

    CreateThread(function()
        lib.showTextUI(locale("k9_targeting_hint"), { position = "bottom-center" })

        while self.isTargeting do
            Wait(0)

            if not IsK9Alive() then
                self.isTargeting = false
                break
            end

            local camPos = GetFinalRenderedCamCoord()
            local camFwd = GetCameraForwardVector()
            local endPos = camPos + camFwd * 80.0

            local ray    = StartShapeTestRay(camPos.x, camPos.y, camPos.z, endPos.x, endPos.y, endPos.z, 12, cache.ped, 0)
            local _, hitCode, hitPos, _, hitEntity = GetShapeTestResult(ray)

            local k9Origin = vector3(
                GetEntityCoords(self.ped).x,
                GetEntityCoords(self.ped).y,
                GetEntityCoords(self.ped).z + 0.5
            )

            local lockedTarget = nil
            if hitCode == 1 and hitEntity and hitEntity ~= 0
            and DoesEntityExist(hitEntity) and IsEntityAPed(hitEntity)
            and hitEntity ~= cache.ped and hitEntity ~= self.ped
            then
                lockedTarget = hitEntity
            end

            if lockedTarget then
                local targetHead = vector3(
                    GetEntityCoords(lockedTarget).x,
                    GetEntityCoords(lockedTarget).y,
                    GetEntityCoords(lockedTarget).z + 1.0
                )
                DrawLine(k9Origin.x, k9Origin.y, k9Origin.z, targetHead.x, targetHead.y, targetHead.z, 255, 30, 30, 220)
                DrawMarker(1, GetEntityCoords(lockedTarget).x, GetEntityCoords(lockedTarget).y, GetEntityCoords(lockedTarget).z,
                    0, 0, 0, 0, 0, 0, 0.7, 0.7, 0.4, 255, 30, 30, 110, false, false, 2, false, nil, nil, false)
            else
                local lineEnd = (hitCode == 1 and hitPos) or endPos
                DrawLine(k9Origin.x, k9Origin.y, k9Origin.z, lineEnd.x, lineEnd.y, lineEnd.z, 160, 160, 160, 100)
            end

            -- E key: confirm attack
            if IsControlJustPressed(0, 38) and lockedTarget then
                self.isTargeting = false
                self:setState("attack", lockedTarget)
                Bridge.Notify.showNotify(locale("k9_attacking"), "warning")
            end

            -- Space / jump key: cancel
            if IsControlJustPressed(0, 73) then
                self.isTargeting = false
            end
        end

        self.isTargeting = false
        lib.hideTextUI()
    end)
end

-- Calls the K9 back to follow (heel)
function K9:heel()
    if not PlayerHasK9Access() then return Bridge.Notify.showNotify(locale("no_access"), "error") end
    if not IsK9Alive() then return Bridge.Notify.showNotify(locale("k9_no_deployed"), "error") end

    self:setState("follow")
    Bridge.Notify.showNotify(locale("k9_heel"), "success")
end

-- Orders K9 to sit
function K9:sit()
    if not PlayerHasK9Access() then return Bridge.Notify.showNotify(locale("no_access"), "error") end
    if not IsK9Alive() then return Bridge.Notify.showNotify(locale("k9_no_deployed"), "error") end

    self:setState("sit")
    Bridge.Notify.showNotify(locale("k9_sitting"), "success")
end

-- Orders K9 to stay in place
function K9:stay()
    if not PlayerHasK9Access() then return Bridge.Notify.showNotify(locale("no_access"), "error") end
    if not IsK9Alive() then return Bridge.Notify.showNotify(locale("k9_no_deployed"), "error") end

    self:setState("stay")
    Bridge.Notify.showNotify(locale("k9_staying"), "success")
end

-- Orders K9 to lie down
function K9:lay()
    if not PlayerHasK9Access() then return Bridge.Notify.showNotify(locale("no_access"), "error") end
    if not IsK9Alive() then return Bridge.Notify.showNotify(locale("k9_no_deployed"), "error") end

    self:setState("lay")
    Bridge.Notify.showNotify(locale("k9_laying"), "success")
end

-- Opens targeting mode to select a player to search (players only)
function K9:search()
    if not PlayerHasK9Access() then return Bridge.Notify.showNotify(locale("no_access"), "error") end
    if not IsK9Alive() then return Bridge.Notify.showNotify(locale("k9_no_deployed"), "error") end
    if self.isTargeting then return end

    self.isTargeting = true

    CreateThread(function()
        lib.showTextUI(locale("k9_search_hint"), { position = "bottom-center" })

        while self.isTargeting do
            Wait(0)

            if not IsK9Alive() then
                self.isTargeting = false
                break
            end

            local camPos = GetFinalRenderedCamCoord()
            local camFwd = GetCameraForwardVector()
            local endPos = camPos + camFwd * 80.0

            local ray    = StartShapeTestRay(camPos.x, camPos.y, camPos.z, endPos.x, endPos.y, endPos.z, 12, cache.ped, 0)
            local _, hitCode, hitPos, _, hitEntity = GetShapeTestResult(ray)

            local k9Origin = vector3(
                GetEntityCoords(self.ped).x,
                GetEntityCoords(self.ped).y,
                GetEntityCoords(self.ped).z + 0.5
            )

            -- Search mode: only target player peds
            local lockedTarget = nil
            if hitCode == 1 and hitEntity and hitEntity ~= 0
            and DoesEntityExist(hitEntity) and IsEntityAPed(hitEntity) and IsPedAPlayer(hitEntity)
            and hitEntity ~= cache.ped and hitEntity ~= self.ped
            then
                lockedTarget = hitEntity
            end

            if lockedTarget then
                local targetHead = vector3(
                    GetEntityCoords(lockedTarget).x,
                    GetEntityCoords(lockedTarget).y,
                    GetEntityCoords(lockedTarget).z + 1.0
                )
                DrawLine(k9Origin.x, k9Origin.y, k9Origin.z, targetHead.x, targetHead.y, targetHead.z, 40, 120, 255, 220)
                DrawMarker(1, GetEntityCoords(lockedTarget).x, GetEntityCoords(lockedTarget).y, GetEntityCoords(lockedTarget).z,
                    0, 0, 0, 0, 0, 0, 0.7, 0.7, 0.4, 40, 120, 255, 110, false, false, 2, false, nil, nil, false)
            else
                local lineEnd = (hitCode == 1 and hitPos) or endPos
                DrawLine(k9Origin.x, k9Origin.y, k9Origin.z, lineEnd.x, lineEnd.y, lineEnd.z, 160, 160, 160, 100)
            end

            -- E key: begin search
            if IsControlJustPressed(0, 38) then
                if not lockedTarget then
                    Bridge.Notify.showNotify(locale("k9_search_no_target"), "error")
                else
                    self.isTargeting = false
                    local targetServerId = GetServerIdFromPed(lockedTarget)

                    if not targetServerId then
                        Bridge.Notify.showNotify(locale("k9_search_no_target"), "error")
                        break
                    end

                    self:setState("search")
                    lib.hideTextUI()

                    local completed = lib.progressBar({
                        duration     = Config.K9.searchDuration,
                        label        = locale("k9_searching"),
                        useWhileDead = false,
                        canCancel    = true,
                        disable      = { move = true, car = true, combat = true },
                    })

                    if not completed or not IsK9Alive() then
                        Bridge.Notify.showNotify(locale("k9_search_cancelled"), "inform")
                        break
                    end

                    local ok, hasIllegal = lib.callback.await("p_policejob/k9/searchPlayer", false, targetServerId)

                    if not ok then
                        Bridge.Notify.showNotify(locale("k9_search_too_far"), "error")
                        break
                    end

                    if hasIllegal then
                        Bridge.Notify.showNotify(locale("k9_search_illegal"), "warning")
                    else
                        Bridge.Notify.showNotify(locale("k9_search_clean"), "success")
                    end

                    break
                end
            end

            -- Space / jump: cancel search
            if IsControlJustPressed(0, 73) then
                self.isTargeting = false
                Bridge.Notify.showNotify(locale("k9_search_cancelled"), "inform")
            end
        end

        self.isTargeting = false
        lib.hideTextUI()
    end)
end

-- ─── Commands ─────────────────────────────────────────────────────────────────

RegisterCommand("k9dismiss",     function() K9:dismiss()  end, false)
RegisterCommand("k9follow",      function() K9:follow()   end, false)
RegisterCommand("k9attack",      function() K9:attack()   end, false)
RegisterCommand("k9heel",        function() K9:heel()     end, false)
RegisterCommand("k9sit",         function() K9:sit()      end, false)
RegisterCommand("k9stay",        function() K9:stay()     end, false)
RegisterCommand("k9lay",         function() K9:lay()      end, false)
RegisterCommand("k9search",      function() K9:search()   end, false)

RegisterCommand("k9followplayer", function(_, args)
    local targetId = tonumber(args[1])
    if not targetId then
        return Bridge.Notify.showNotify(locale("k9_followplayer_usage"), "error")
    end
    K9:followPlayer(targetId)
end, false)

-- ─── Keybinds ────────────────────────────────────────────────────────────────

lib.addKeybind({
    name          = "k9_spawn",
    description   = locale("k9_keybind_spawn"),
    defaultKey    = "INSERT",
    defaultMapper = "keyboard",
    onPressed     = function() K9:spawn() end,
})

lib.addKeybind({
    name          = "k9_dismiss",
    description   = locale("k9_keybind_dismiss"),
    defaultKey    = "DELETE",
    defaultMapper = "keyboard",
    onPressed     = function() K9:dismiss() end,
})

lib.addKeybind({
    name          = "k9_attack",
    description   = locale("k9_keybind_attack"),
    defaultKey    = "",
    defaultMapper = "keyboard",
    onPressed     = function() K9:attack() end,
})

lib.addKeybind({
    name          = "k9_heel",
    description   = locale("k9_keybind_heel"),
    defaultKey    = "",
    defaultMapper = "keyboard",
    onPressed     = function() K9:heel() end,
})

-- ─── Exports ─────────────────────────────────────────────────────────────────

exports("GetK9Ped",   function()          return K9.ped   end)
exports("IsK9Active", function()          return IsK9Alive() end)
exports("GetK9State", function()          return K9.state end)
exports("SetK9State", function(state, target) K9:setState(state, target) end)
