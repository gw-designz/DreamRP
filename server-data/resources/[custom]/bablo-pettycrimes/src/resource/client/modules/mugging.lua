if not Config.Modules.MUGGING then return end

Mugging = {
    inAction                    = false,
    foundTarget                 = false,
    lastPoliceNotification      = 0,
    lastRetaliationNotification = 0,
    meterStage                  = 100,
    lastTalk                    = 0,
}

-- Restores the victim NPC to normal autonomous behaviour after the mugging ends
local function releaseMuggingVictim(targetPed)
    FreezeEntityPosition(targetPed, false)
    ClearPedTasksImmediately(targetPed)
    SetBlockingOfNonTemporaryEvents(targetPed, false)
    SetPedFleeAttributes(targetPed, 0,    true)
    SetPedFleeAttributes(targetPed, 512,  true)
    SetPedFleeAttributes(targetPed, 1024, true)
    SetPedFleeAttributes(targetPed, 2048, true)
    SetPedCombatAttributes(targetPed, 17, false)
    SetPedCombatAttributes(targetPed, 46, false)
    SetPedSeeingRange(targetPed, 40.0)
    SetPedHearingRange(targetPed, 20.0)
    SetPedAlertness(targetPed, 3)
    SetEntityAsMissionEntity(targetPed, false, false)
end

-- Puts the victim NPC into a hands-up, frozen, unresponsive state during robbery
local function freezeMuggingVictim(targetPed)
    ClearPedTasksImmediately(targetPed)
    SetEntityAsMissionEntity(targetPed, true, true)
    SetBlockingOfNonTemporaryEvents(targetPed, true)
    SetPedFleeAttributes(targetPed, 0, false)
    SetPedCombatAttributes(targetPed, 17, true)
    SetPedSeeingRange(targetPed, 0.0)
    SetPedHearingRange(targetPed, 0.0)
    SetPedAlertness(targetPed, 0)
    FreezeEntityPosition(targetPed, true)
    Main:playAnimation({ ped = targetPed, dict = "random@mugging3", lib = "handsup_standing_base", flag = 1 })
end

local function maybeSendDispatch(targetPed)
    local roll = math.random(1, 100)
    if roll >= Config.Mugging.AlertChance then return end

    Dispatch:Send(BuildDispatchData({
        coords      = GetEntityCoords(targetPed),
        jobs        = { "police", "lspd", "bcso" },
        message     = Translate("MUGGING_DISPATCH_TITLE"),
        description = Translate("MUGGING_DISPATCH_DESC"),
        blip        = {
            sprite = 458,
            color  = 1,
            scale  = 1.0,
            text   = Translate("MUGGING_DISPATCH_BLIP"),
            flash  = true,
        },
    }, Config.Mugging.Dispatch))
end

-- Makes the NPC retaliate: clears flee state, arms them, triggers combat
local function triggerRetaliation(targetPed)
    ClearPedTasks(targetPed)
    ClearPedTasksImmediately(targetPed)

    SetPedFleeAttributes(targetPed, 0,    false)
    SetPedFleeAttributes(targetPed, 512,  false)
    SetPedFleeAttributes(targetPed, 1024, false)
    SetPedFleeAttributes(targetPed, 2048, false)
    SetBlockingOfNonTemporaryEvents(targetPed, true)
    SetPedCombatAttributes(targetPed, 46, true)
    SetPedCombatAttributes(targetPed, 0,  true)
    SetPedCombatAttributes(targetPed, 5,  true)
    SetPedCombatAttributes(targetPed, 1,  true)
    SetPedCombatAttributes(targetPed, 17, false)
    SetPedCombatAttributes(targetPed, 58, false)
    SetPedCombatRange(targetPed, 2)
    SetPedCombatMovement(targetPed, 2)
    SetPedAsEnemy(targetPed, true)
    SetPedCanRagdoll(targetPed, true)
    RemoveAllPedWeapons(targetPed, true)

    local weapons = Config.Mugging.RetaliationWeapons or { "WEAPON_UNARMED" }
    local chosenWeapon = weapons[math.random(#weapons)]
    Trace("Giving NPC weapon: " .. chosenWeapon)

    local weaponHash = GetHashKey(chosenWeapon)
    GiveWeaponToPed(targetPed, weaponHash, 1, false, true)
    SetCurrentPedWeapon(targetPed, weaponHash, true)

    PlayAmbientSpeech1(targetPed, "GENERIC_INSULT_HIGH", "SPEECH_PARAMS_FORCE_SHOUTED_CRITICAL")
    TaskCombatPed(targetPed, cache.ped, 0, 16)

    -- Re-issue combat task after a short delay to ensure it sticks
    Citizen.SetTimeout(100, function()
        if DoesEntityExist(targetPed) and not IsEntityDead(targetPed) then
            TaskCombatPed(targetPed, cache.ped, 0, 16)
        end
    end)
end

-- On success: hands the victim the "give" anim, claims loot, restores victim
local function completeMugging(self, targetPed)
    ClearPedTasksImmediately(targetPed)
    self.inAction = false

    Citizen.Wait(500)
    Main:playAnimation({ ped = targetPed, dict = "mp_common", lib = "givetake1_a", flag = 1 })
    Citizen.Wait(1000)

    local itemName = SelectRandomItem(Config.Mugging.LootTables).name
    local result = TriggerServerCallback({
        eventName = eventName .. "server:giveMuggingReward",
        args      = { { itemName = itemName } },
    })

    if result.status then
        Framework:onFinished("MUGGING")
        if result.message then
            Framework:Notify(result.message)
        end
    else
        Framework:Notify(Translate("NOTHING_FOUND"))
    end

    self.foundTarget = false
    ClearPedTasks(targetPed)
    FreezeEntityPosition(targetPed, false)
    releaseMuggingVictim(targetPed)
    TaskReactAndFleePed(targetPed, cache.ped)

    -- Ensure the NPC actually flees and isn't stuck standing still
    Citizen.SetTimeout(500, function()
        if not DoesEntityExist(targetPed) or IsEntityDead(targetPed) then return end
        local dist = #(GetEntityCoords(targetPed) - GetEntityCoords(cache.ped))
        if dist < 10.0 and GetEntitySpeed(targetPed) < 1.0 then
            ClearPedTasks(targetPed)
            TaskSmartFleePed(targetPed, cache.ped, 100.0, -1, false, false)
        end
    end)
end

-- Called when the mugging is interrupted (player moved away, target died, meter drained)
local function abortMugging(self, targetPed)
    self.inAction   = false
    self.foundTarget = false
    FreezeEntityPosition(targetPed, false)
    ClearPedTasksImmediately(targetPed)
    releaseMuggingVictim(targetPed)

    Citizen.Wait(100)
    TaskReactAndFleePed(targetPed, cache.ped)

    Citizen.SetTimeout(500, function()
        if not DoesEntityExist(targetPed) or IsEntityDead(targetPed) then return end
        local dist = #(GetEntityCoords(targetPed) - GetEntityCoords(cache.ped))
        if dist < 10.0 and GetEntitySpeed(targetPed) < 1.0 then
            ClearPedTasks(targetPed)
            TaskSmartFleePed(targetPed, cache.ped, 100.0, -1, false, false)
        end
    end)
end

function Mugging:startMugging(targetPed)
    local retaliationChance = (Config.Mugging and Config.Mugging.RetaliationChance) or 0
    Trace("Starting mugging attempt, RetaliationChance: " .. tostring(retaliationChance))

    local progressDuration = math.random(Config.Mugging.ProgressTime.min, Config.Mugging.ProgressTime.max)

    if not Framework:canDoAction("MUGGING") then
        Trace("Failed on 'Framework:canDoAction'")
        return
    end

    local dist = #(GetEntityCoords(cache.ped) - GetEntityCoords(targetPed))
    if dist > 5.0 then
        Trace("Failed on distance check")
        return
    end

    if IsEntityPositionFrozen(targetPed) then
        Trace("Failed on IsEntityPositionFrozen")
        return
    end

    if IsEntityAMissionEntity(targetPed) then
        Trace("Failed on IsEntityDead")  -- original message preserved
        return
    end

    for _, blacklistedHash in pairs(Config.Mugging.BlacklistedModels) do
        if GetEntityModel(targetPed) == blacklistedHash then
            Trace("Failed on blacklisted models")
            return
        end
    end

    local _, currentWeaponHash = GetCurrentPedWeapon(cache.ped)
    for _, weaponName in pairs(Config.Mugging.BlacklistedWeapons) do
        if currentWeaponHash == GetHashKey(weaponName) then
            Trace("Failed on blacklisted weapons")
            return
        end
    end

    if IsPedAPlayer(targetPed) then
        Trace("Failed on IsPedAPlayer")
        return
    end

    if not HasEntityClearLosToEntityInFront(cache.ped, targetPed) then
        Trace("Failed on HasEntityClearLosToEntityInFront")
        return
    end

    -- Target must be unarmed
    if GetBestPedWeapon(targetPed, 0) ~= GetHashKey("WEAPON_UNARMED") then
        Trace("Using WEAPON_UNARMED")
        return
    end

    if IsPedInAnyVehicle(targetPed) or IsPedInAnyVehicle(cache.ped) then
        TaskReactAndFleePed(targetPed, cache.ped)
        Trace("Failed on IsPedInAnyVehicle")
        return
    end

    if IsEntityDead(targetPed) then
        Trace("Failed on IsEntityDead")
        return
    end

    if Entity(targetPed).state.isMugged then
        Trace("Failed on Entity(targetPed).state.isMugged")
        return
    end

    if Main:getPoliceCount() < Config.Mugging.PoliceRequired then
        local now = GetGameTimer()
        if now - self.lastPoliceNotification >= 5000 then
            Framework:Notify(Translate("NOT_ENOUGH_POLICE"))
            Trace("Not enough police")
            self.lastPoliceNotification = now
        end
        return
    end

    -- Retaliation check
    local roll = math.random(1, 100)
    Trace("Retaliation check: roll=" .. roll .. " vs chance=" .. retaliationChance ..
          " (Config exists: " .. tostring(Config.Mugging ~= nil) .. ")")

    if retaliationChance >= roll then
        Trace("Retaliation triggered!")
        local now = GetGameTimer()
        if now - self.lastRetaliationNotification >= 5000 then
            Framework:Notify(Translate("MUGGING_RETALIATION"))
            self.lastRetaliationNotification = now
        end
        triggerRetaliation(targetPed)
        return
    end

    Trace("Retaliation not triggered, proceeding with normal mugging")

    maybeSendDispatch(targetPed)

    Main:setEntityStateBag(targetPed, { isMugged = true })
    PlayAmbientSpeech1(targetPed, "GENERIC_FRIGHTENED_HIGH", "SPEECH_PARAMS_FORCE_SHOUTED_CRITICAL")
    PlayFacialAnim(targetPed, "mood_sulk_1", "facials@gen_male@base")

    self.foundTarget = targetPed
    self.inAction    = true
    self.meterStage  = 100
    self.lastTalk    = GetGameTimer()

    local muggingCancelled = false

    -- Progress bar thread (the timed robbery window)
    Citizen.CreateThread(function()
        Framework:doProgress({
            text = Translate("MUGGING_IN_PROGRESS"),
            time = progressDuration,
        }, function(succeeded)
            if succeeded and self.inAction then
                local targetDist = #(GetEntityCoords(cache.ped) - GetEntityCoords(self.foundTarget))
                if targetDist < 5.0 and not muggingCancelled then
                    completeMugging(self, targetPed)
                end
            else
                Trace("Mugging failed")
            end
        end)
    end)

    -- Victim control thread: holds the NPC in place, updates the scare meter,
    -- and cancels the mugging if the player moves away or the meter runs out
    Citizen.CreateThread(function()
        freezeMuggingVictim(targetPed)

        while self.inAction do
            -- Re-apply hands-up if the animation dropped
            if not IsEntityPlayingAnim(targetPed, "random@mugging3", "handsup_standing_base", 3) then
                Main:playAnimation({ ped = targetPed, dict = "random@mugging3", lib = "handsup_standing_base", flag = 1 })
            end

            local dist = #(GetEntityCoords(cache.ped) - GetEntityCoords(targetPed))

            -- Abort conditions: moved away, target died, target no longer found
            if dist > 5.0 or IsEntityDead(targetPed) or not self.foundTarget then
                self.inAction = false
                muggingCancelled = true
                if lib.progressActive() then lib.cancelProgress() end
                break
            end

            Main:hint(Translate("MUGGING_SCARED_HINT"))
            self:scaryBar(self.meterStage, Translate("MUGGING_SCARED_BAR"))

            -- Mic input raises the scare meter; silence drains it
            local now = GetGameTimer()
            if NetworkIsPlayerTalking(PlayerId()) then
                if now - self.lastTalk >= 300 then
                    self.lastTalk = now
                    if self.meterStage < 100 then
                        self.meterStage = self.meterStage + 0.3
                    end
                end
            elseif now - self.lastTalk >= 400 then
                self.meterStage = self.meterStage - 0.2
            end

            if self.meterStage <= 0 then
                self.inAction = false
                muggingCancelled = true
                if lib.progressActive() then lib.cancelProgress() end
                break
            end

            Citizen.Wait(0)
        end

        if muggingCancelled then
            abortMugging(self, targetPed)
        end
    end)
end

-- Draws the NPC scare meter HUD element
function Mugging:scaryBar(meterValue, label)
    local safeZoneOffset = (1.0 - math.floor(GetSafeZoneSize(), 2)) * 100 * 0.005
    local barX = 1.415 - safeZoneOffset
    local barY = 1.475 - safeZoneOffset
    local fillWidth = meterValue * 8.5e-4
    local barHeight = 0.0125

    if not HasStreamedTextureDictLoaded("timerbars") then
        RequestStreamedTextureDict("timerbars")
        while not HasStreamedTextureDictLoaded("timerbars") do Citizen.Wait(0) end
    end

    Set_2dLayer(0)
    DrawSprite("timerbars", "all_black_bg", barX, barY, 0.15, 0.0325, 0.0, 255, 255, 255, 180)

    Set_2dLayer(1)
    DrawRect(barX + 0.0275, barY, 0.085, barHeight, 100, 0, 0, 180)

    Set_2dLayer(2)
    DrawRect(barX - 0.015 + fillWidth / 2, barY, fillWidth, barHeight, 150, 0, 0, 180)

    SetTextColour(255, 255, 255, 180)
    SetTextFont(0)
    SetTextScale(0.3, 0.3)
    SetTextCentre(true)
    SetTextEntry("STRING")
    AddTextComponentString(label)
    Set_2dLayer(3)
    DrawText(barX - 0.04, barY - 0.012)
end

-- Detection loop: watches for player aiming at an NPC and triggers mugging
Citizen.CreateThread(function()
    WaitForConfigSync()

    while true do
        local waitMs = 500
        local playerId = PlayerId()
        local targetEntity = GetPlayerTargetEntity(playerId)

        if not Mugging.inAction and targetEntity and targetEntity ~= 0 then
            waitMs = 5

            local _, aimEntity = GetEntityPlayerIsFreeAimingAt(playerId)

            local entity = (targetEntity ~= 0 and targetEntity) or (aimEntity ~= 0 and aimEntity)
            if entity and not Mugging.foundTarget then
                Mugging:startMugging(entity)
            end
        elseif IsPlayerFreeAiming(playerId) then
            local _, aimEntity = GetEntityPlayerIsFreeAimingAt(playerId)
            if aimEntity and aimEntity ~= 0 and not Mugging.foundTarget then
                Mugging:startMugging(aimEntity)
            end
            waitMs = 5
        end

        Wait(waitMs)
    end
end)

-- Debug helper
Citizen.CreateThread(function()
    if not Config.Debug then return end
    RegisterCommand("givepistol", function()
        GiveWeaponToPed(cache.ped, GetHashKey("WEAPON_PISTOL"), 1000, false, true)
    end)
end)

exports("isMugged", function(entity)
    if not entity or entity == 0 then return false end
    return Entity(entity).state.isMugged or false
end)

exports("setMugged", function(entity, value)
    if not entity or entity == 0 then return false end
    Entity(entity).state.isMugged = value
end)

exports("isMugging", function()
    return Mugging.inAction
end)
