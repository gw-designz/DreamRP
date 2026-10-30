-- ATM Robbery module guard
if not Config.Modules.ATM_ROBBERY then
    return
end

-- ─── State ───────────────────────────────────────────────────────────────────

AtmRobbery = {}
AtmRobbery.activeAtm      = nil
AtmRobbery.pedLoopActive  = false
AtmRobbery.spawnedPed     = nil
AtmRobbery.hackBusy       = false
AtmRobbery.collecting     = false
AtmRobbery.cashPileProp   = nil
AtmRobbery.hasHackerItem  = false

local moduleInitialized   = false
local lastItemCheckTime   = 0

-- ─── Helpers ─────────────────────────────────────────────────────────────────

local function isBusy()
    return AtmRobbery.hackBusy or AtmRobbery.collecting
end

local function getRequiredItem()
    if Config.AtmRobbery and Config.AtmRobbery.RequiredItem then
        return Config.AtmRobbery.RequiredItem
    end
    return "batm_hacker"
end

local function notify(translationKey, args)
    Framework:Notify(Translate(translationKey, args))
end

-- ─── Item Check (throttled) ───────────────────────────────────────────────────

function CheckHackerItem()
    local now = GetGameTimer()
    if now - lastItemCheckTime < 2000 then return end
    lastItemCheckTime = now

    TriggerServerCallback({
        eventName = eventName .. "server:hasItem",
        args      = { getRequiredItem() },
        callback  = function(result)
            AtmRobbery.hasHackerItem = result and result.status == true or false
        end,
    })
end

-- ─── Target Setup ─────────────────────────────────────────────────────────────

Citizen.CreateThread(function()
    WaitForConfigSync()
    Citizen.Wait(500)

    if not Config.Modules.ATM_ROBBERY then return end
    if moduleInitialized then return end
    moduleInitialized = true

    local atmModels = Config.AtmRobbery and Config.AtmRobbery.AtmModels
    if not atmModels or #atmModels == 0 then
        Trace("No atm models configured, skipping target setup")
        return
    end

    -- Load and validate ATM models
    local validModels = {}
    for _, modelName in pairs(atmModels) do
        if type(modelName) == "string" and modelName ~= "" then
            local hash = GetHashKey(modelName)
            RequestModel(hash)

            local waited = 0
            while not HasModelLoaded(hash) and waited < 5000 do
                Citizen.Wait(100)
                waited = waited + 100
            end

            if HasModelLoaded(hash) then
                validModels[#validModels + 1] = modelName
                Trace("Successfully loaded atm model: " .. modelName)
            else
                Trace("Failed to load atm model: " .. modelName .. " (hash: " .. hash .. ")")
            end
        end
    end

    if #validModels == 0 then
        Trace("No valid atm models found, skipping target setup")
        return
    end

    local interactDistance = (Config.AtmRobbery and Config.AtmRobbery.InteractDistance) or 2.0

    -- Attach device target
    Target:addTargetModel(validModels, {
        label    = Translate("ATM_ROBBERY_ATTACH_LABEL"),
        icon     = "fas fa-laptop-code",
        distance = interactDistance,
        action   = function(entity)
            AtmRobbery:attachDevice(entity)
        end,
        canInteract = function(entity)
            if isBusy() then return false end
            if AtmRobbery.pedLoopActive then return false end
            if not Framework:canDoAction("ATM_ROBBERY") then return false end
            if Entity(entity).state.atmRobbed then return false end
            if Entity(entity).state.atmHacked then return false end
            CheckHackerItem()
            return AtmRobbery.hasHackerItem
        end,
    })

    -- Drain ATM target
    Target:addTargetModel(validModels, {
        label    = Translate("ATM_ROBBERY_DRAIN_LABEL"),
        icon     = "fas fa-money-bill-wave",
        distance = interactDistance,
        action   = function(entity)
            AtmRobbery:drainAtm(entity)
        end,
        canInteract = function(entity)
            if isBusy() then return false end
            if AtmRobbery.cashPileProp then return false end
            return Entity(entity).state.atmHacked == true
        end,
    })

    -- Remove device target
    Target:addTargetModel(validModels, {
        label    = Translate("ATM_ROBBERY_REMOVE_LABEL"),
        icon     = "fas fa-eject",
        distance = interactDistance,
        action   = function(entity)
            AtmRobbery:removeDevice(entity)
        end,
        canInteract = function(entity)
            if isBusy() then return false end
            if AtmRobbery.cashPileProp then return false end
            return Entity(entity).state.atmHacked == true
        end,
    })

    Trace("Successfully added atm targets for " .. #validModels .. " models")
end)

-- ─── Ped Spawning ─────────────────────────────────────────────────────────────

function AtmRobbery:spawnPed(atmCoords)
    local pedModels = Config.AtmRobbery.PedModels
    local modelName = pedModels[math.random(1, #pedModels)]
    local modelHash = GetHashKey(modelName)

    RequestModel(modelHash)
    local waited = 0
    while not HasModelLoaded(modelHash) do
        Wait(10)
        waited = waited + 10
        if waited > 5000 then return nil end
    end

    -- Find a spawn position near the ATM, preferring a road node
    local spawnCoords = nil
    local nodeFound, nodePos, nodeHeading = GetClosestVehicleNodeWithHeading(
        atmCoords.x, atmCoords.y, atmCoords.z, 1, 3.0, 0
    )

    if nodeFound then
        local distToNode = #(vector3(nodePos.x, nodePos.y, nodePos.z) - atmCoords)
        if distToNode > 15.0 then
            spawnCoords = vector3(nodePos.x, nodePos.y, nodePos.z)
        else
            -- Offset further along the road heading
            local headingRad  = math.rad(nodeHeading)
            local direction   = vector3(math.cos(headingRad), math.sin(headingRad), 0.0)
            local offsetDist  = 20.0 + math.random() * 10.0
            local candidate   = vector3(
                nodePos.x + direction.x * offsetDist,
                nodePos.y + direction.y * offsetDist,
                nodePos.z
            )
            local farNodeFound, farNodePos = GetClosestVehicleNodeWithHeading(
                candidate.x, candidate.y, candidate.z, 1, 3.0, 0
            )
            spawnCoords = farNodeFound
                and vector3(farNodePos.x, farNodePos.y, farNodePos.z)
                or candidate
        end
    end

    -- Fallback: safe coord or random offset
    if not spawnCoords then
        local safeFound, sx, sy, sz = GetSafeCoordForPed(atmCoords.x, atmCoords.y, atmCoords.z, true, 16)
        if safeFound then
            spawnCoords = vector3(sx, sy, sz)
        else
            local angle  = math.random() * 2 * math.pi
            local radius = 25.0 + math.random() * 10.0
            spawnCoords  = vector3(
                atmCoords.x + math.cos(angle) * radius,
                atmCoords.y + math.sin(angle) * radius,
                atmCoords.z
            )
        end
    end

    -- Snap to ground
    local groundFound, groundZ = GetGroundZFor_3dCoord(spawnCoords.x, spawnCoords.y, spawnCoords.z + 50.0, false)
    if groundFound and groundZ > 0.0 then
        spawnCoords = vector3(spawnCoords.x, spawnCoords.y, groundZ + 1.0)
    end

    local ped = CreatePed(4, modelHash, spawnCoords.x, spawnCoords.y, spawnCoords.z, 0.0, true, false)
    SetModelAsNoLongerNeeded(modelHash)

    if not DoesEntityExist(ped) then return nil end

    SetBlockingOfNonTemporaryEvents(ped, true)
    SetPedFleeAttributes(ped, 0, false)
    SetPedCombatAttributes(ped, 17, true)
    TaskGoToCoordAnyMeans(ped, atmCoords.x, atmCoords.y, atmCoords.z, 1.0, 0, false, 786603, -1.0)

    self.spawnedPed = ped
    return ped
end

function AtmRobbery:deletePed(ped)
    if ped and DoesEntityExist(ped) then
        SetEntityAsMissionEntity(ped, true, true)
        DeleteEntity(ped)
    end
    if self.spawnedPed == ped then
        self.spawnedPed = nil
    end
end

function AtmRobbery:cleanupPed()
    self:deletePed(self.spawnedPed)
end

-- ─── Ped Arrival Wait ─────────────────────────────────────────────────────────

function AtmRobbery:waitForPedArrival(ped, targetCoords, timeout)
    local elapsed = 0
    while elapsed < timeout do
        if not self.pedLoopActive then return false end
        if not DoesEntityExist(ped) then return false end
        if #(GetEntityCoords(ped) - targetCoords) < 2.0 then return true end
        if elapsed > 12000 and GetEntitySpeed(ped) < 0.2 then return false end
        Wait(250)
        elapsed = elapsed + 250
    end
    return false
end

-- ─── Ped Fade Out ─────────────────────────────────────────────────────────────

function AtmRobbery:fadeOutPed(ped)
    if not ped or not DoesEntityExist(ped) then return end
    local pedRef = ped
    Citizen.SetTimeout(20000, function()
        if pedRef and DoesEntityExist(pedRef) then
            SetEntityAsMissionEntity(pedRef, true, true)
            DeleteEntity(pedRef)
        end
    end)
end

-- ─── Ped Walk Away ────────────────────────────────────────────────────────────

function AtmRobbery:pedWalkAway(ped, playAtmAnim)
    if not ped or not DoesEntityExist(ped) then return end
    ClearPedTasksImmediately(ped)
    if playAtmAnim then
        Main:loadanimDict("mini@atmenter")
        TaskPlayAnim(ped, "mini@atmenter", "enter", 8.0, -8.0, 4000, 1, 0, false, false, false)
        Wait(4000)
    end
    ClearPedTasks(ped)
    TaskWanderStandard(ped, 10.0, 10)
    self:fadeOutPed(ped)
end

-- ─── Ped React: Angry or Call Police ─────────────────────────────────────────

function AtmRobbery:pedReactAngryOrPolice(ped, atmCoords)
    if not ped or not DoesEntityExist(ped) then return end
    ClearPedTasksImmediately(ped)

    local alertChance = (Config.AtmRobbery and Config.AtmRobbery.AlertChance) or 20
    local roll        = math.random(1, 100)

    if roll <= alertChance then
        -- Call the police
        local dispatchData = BuildDispatchData({
            message = Translate("ATM_ROBBERY_DISPATCH"),
            coords  = atmCoords,
            jobs    = { "police", "lspd", "bcso" },
            blip    = {
                sprite = 434,
                color  = 2,
                scale  = 1.0,
                text   = Translate("ATM_ROBBERY_DISPATCH_BLIP"),
                flash  = true,
            },
        }, Config.AtmRobbery.Dispatch)
        Dispatch:Send(dispatchData)

        Main:loadanimDict("cellphone@")
        TaskPlayAnim(ped, "cellphone@", "cellphone_call_listen_base", 8.0, -8.0, 4000, 49, 0, false, false, false)
        Wait(4000)
        ClearPedTasks(ped)
        TaskReactAndFleePed(ped, cache.ped)
    else
        -- Angry reaction only
        notify("ATM_ROBBERY_PED_ANGRY")
        Main:loadanimDict("gestures@m@standing@casual")
        TaskPlayAnim(ped, "gestures@m@standing@casual", "gesture_damn", 8.0, -8.0, 2500, 49, 0, false, false, false)
        Wait(2500)
        ClearPedTasks(ped)
        TaskWanderStandard(ped, 10.0, 10)
    end

    self:fadeOutPed(ped)
end

-- ─── Attach Device ────────────────────────────────────────────────────────────

function AtmRobbery:attachDevice(atmEntity)
    if self.pedLoopActive or isBusy() then return end
    if not atmEntity or not DoesEntityExist(atmEntity) then return end

    local entityState = Entity(atmEntity).state
    if entityState.atmHacked then
        notify("ATM_ROBBERY_ALREADY_HACKED")
        return
    end
    if entityState.atmRobbed then
        notify("ATM_ROBBERY_COOLDOWN")
        return
    end

    local atmCoords = GetEntityCoords(atmEntity)
    local result    = TriggerServerCallback({
        eventName = eventName .. "server:atmRobberyAttach",
        args      = { { atmCoords = atmCoords } },
    })

    if not result or not result.status then
        if result then
            if result.message == "NO_ITEM" then
                notify("ATM_ROBBERY_NO_ITEM")
            elseif result.message == "NOT_ENOUGH_POLICE" then
                notify("NOT_ENOUGH_POLICE")
            elseif result.message == "COOLDOWN" then
                notify("ATM_ROBBERY_COOLDOWN")
            end
        end
        return
    end

    self.hackBusy = true
    TaskTurnPedToFaceEntity(cache.ped, atmEntity, 1000)
    Wait(1000)
    TaskStartScenarioInPlace(cache.ped, "PROP_HUMAN_ATM", 0, true)

    local completed = lib.progressBar({
        duration     = 5000,
        label        = Translate("ATM_ROBBERY_ATTACHING"),
        useWhileDead = false,
        canCancel    = true,
        disable      = { car = true, combat = true },
    })

    ClearPedTasks(cache.ped)

    if not completed then
        self.hackBusy = false
        TriggerServerCallback({
            eventName = eventName .. "server:atmRobberyAttachCancel",
            args      = {},
        })
        return
    end

    Main:setEntityStateBag(atmEntity, { atmHacked = true })
    self.activeAtm  = atmEntity
    self.hackBusy   = false
    self.pedCount   = 0
    notify("ATM_ROBBERY_DEVICE_ATTACHED")
    self:startPedLoop(atmEntity)
end

-- ─── Remove Device ────────────────────────────────────────────────────────────

function AtmRobbery:removeDevice(atmEntity)
    if isBusy() then return end
    if not atmEntity or not DoesEntityExist(atmEntity) then return end
    if not Entity(atmEntity).state.atmHacked then return end

    self.collecting    = true
    self.pedLoopActive = false
    Wait(200)
    self:cleanupPed()

    TaskTurnPedToFaceEntity(cache.ped, atmEntity, 1000)
    Wait(1000)
    Main:playAnimation({
        ped  = cache.ped,
        dict = "anim@heists@prison_heiststation@heels",
        lib  = "pickup_bus_schedule",
        flag = 49,
        time = 3000,
    })
    Wait(3000)
    ClearPedTasks(cache.ped)

    local result = TriggerServerCallback({
        eventName = eventName .. "server:atmRobberyDetach",
        args      = {},
    })

    Main:setEntityStateBag(atmEntity, { atmHacked = false, atmRobbed = false })

    if result and result.status then
        if result.broke then
            notify("ATM_ROBBERY_ITEM_BROKE")
        end
    elseif result and result.status then
        notify("ATM_ROBBERY_DEVICE_REMOVED")
    end

    Framework:onFinished("ATM_ROBBERY")
    self.activeAtm  = nil
    self.collecting = false
    self.pedCount   = 0
end

-- ─── Money Spray Effect ───────────────────────────────────────────────────────

function AtmRobbery:sprayMoneyEffect(atmEntity)
    local ptfxAsset   = "scr_xs_celebration"
    local ptfxEffect  = "scr_xs_money_rain"
    local spawnPos    = GetOffsetFromEntityInWorldCoords(atmEntity, 0.0, 0.0, 1.0)
    local rotation    = GetEntityRotation(atmEntity, 2)
    local handles     = {}

    for _ = 1, 10 do
        lib.requestNamedPtfxAsset(ptfxAsset)
        UseParticleFxAssetNextCall(ptfxAsset)
        local handle = StartParticleFxLoopedAtCoord(
            ptfxEffect,
            spawnPos.x, spawnPos.y, spawnPos.z,
            60.0, rotation.y, rotation.z,
            1.0, false, false, false, false
        )
        handles[#handles + 1] = handle
        RemoveNamedPtfxAsset(ptfxAsset)
    end
    return handles
end

function AtmRobbery:stopParticles(handles)
    for _, handle in ipairs(handles) do
        StopParticleFxLooped(handle, false)
    end
end

-- ─── Cash Pile ────────────────────────────────────────────────────────────────

function AtmRobbery:spawnCashPile(atmEntity)
    local modelName = "bkr_prop_bkr_cashpile_06"
    local modelHash = GetHashKey(modelName)

    RequestModel(modelHash)
    local waited = 0
    while not HasModelLoaded(modelHash) and waited < 10000 do
        Wait(50)
        waited = waited + 50
    end

    if not HasModelLoaded(modelHash) then
        Trace("Failed to load cash pile model: " .. modelName)
        return nil
    end

    local spawnPos = GetOffsetFromEntityInWorldCoords(atmEntity, 0.0, -1.0, 0.0)
    local prop     = CreateObject(modelHash, spawnPos.x, spawnPos.y, spawnPos.z, false, true, false)
    SetModelAsNoLongerNeeded(modelHash)

    if not prop or prop == 0 or not DoesEntityExist(prop) then
        Trace("Failed to create cash pile object")
        return nil
    end

    PlaceObjectOnGroundProperly(prop)
    FreezeEntityPosition(prop, true)
    self.cashPileProp = prop
    Trace("Cash pile spawned successfully")
    return prop
end

-- ─── Collect Target Loop ──────────────────────────────────────────────────────

function AtmRobbery:setupCollectTarget(cashPile, atmEntity)
    local atmCoords = GetEntityCoords(atmEntity)

    Citizen.CreateThread(function()
        local cashPileCoords = GetEntityCoords(cashPile)
        local uiVisible      = false

        while true do
            if not self.cashPileProp then break end
            if not DoesEntityExist(cashPile) then break end

            local playerCoords = GetEntityCoords(cache.ped)
            local distToCash   = #(playerCoords - cashPileCoords)

            if distToCash < 2.0 then
                if not self.collecting then
                    if not uiVisible then
                        lib.showTextUI(Translate("ATM_ROBBERY_COLLECT_LABEL"), { icon = "fas fa-money-bills" })
                        uiVisible = true
                    end

                    if IsControlJustPressed(0, 38) then
                        lib.hideTextUI()
                        uiVisible      = false
                        self.collecting = true

                        TaskTurnPedToFaceEntity(cache.ped, cashPile, 1000)
                        Wait(1000)
                        Main:loadanimDict("anim@mp_snowball")
                        TaskPlayAnim(cache.ped, "anim@mp_snowball", "pickup_snowball", 8.0, -8.0, -1, 49, 0, false, false, false)

                        local collected = lib.progressBar({
                            duration     = 4000,
                            label        = Translate("ATM_ROBBERY_COLLECTING"),
                            useWhileDead = false,
                            canCancel    = false,
                            disable      = { move = true, car = true, combat = true },
                        })
                        ClearPedTasks(cache.ped)

                        if not collected then
                            self.collecting = false
                        else
                            local drainResult = TriggerServerCallback({
                                eventName = eventName .. "server:atmRobberyDrain",
                                args      = { { atmCoords = atmCoords } },
                            })

                            if drainResult then
                                if drainResult.status then
                                    notify("ATM_ROBBERY_DRAINED", { drainResult.reward })
                                    Main:setEntityStateBag(atmEntity, { atmRobbed = true })
                                elseif drainResult.message == "EMPTY" then
                                    notify("ATM_ROBBERY_POOL_EMPTY")
                                end
                            end

                            if cashPile and DoesEntityExist(cashPile) then
                                DeleteEntity(cashPile)
                            end
                            self.cashPileProp = nil
                            self.collecting   = false
                            self:startPedLoop(atmEntity)
                            return
                        end
                    end
                end
            elseif uiVisible then
                lib.hideTextUI()
                uiVisible = false
            end

            Wait(0)
        end

        if uiVisible then lib.hideTextUI() end
    end)
end

-- ─── Drain ATM ────────────────────────────────────────────────────────────────

function AtmRobbery:drainAtm(atmEntity)
    if isBusy() then return end
    if not atmEntity or not DoesEntityExist(atmEntity) then return end
    if not Entity(atmEntity).state.atmHacked then return end

    self.collecting    = true
    self.pedLoopActive = false
    Wait(200)
    self:cleanupPed()

    TaskTurnPedToFaceEntity(cache.ped, atmEntity, 1000)
    Wait(1000)

    -- Phone prop attached to hand during drain
    local phoneHash = GetHashKey("prop_npc_phone_02")
    RequestModel(phoneHash)
    while not HasModelLoaded(phoneHash) do Wait(10) end

    Main:loadanimDict("cellphone@")
    TaskPlayAnim(cache.ped, "cellphone@", "cellphone_text_read_base", 8.0, -8.0, -1, 49, 0, false, false, false)

    local phoneProp = CreateObject(phoneHash, 0.0, 0.0, 0.0, true, true, false)
    AttachEntityToEntity(
        phoneProp, cache.ped,
        GetPedBoneIndex(cache.ped, 28422),
        0.0, 0.0, 0.0,
        0.0, 0.0, 0.0,
        true, true, false, false, 2, true
    )
    SetModelAsNoLongerNeeded(phoneHash)

    local drainTime   = (Config.AtmRobbery and Config.AtmRobbery.DrainTime) or 10000
    local particles   = self:sprayMoneyEffect(atmEntity)

    local completed = lib.progressBar({
        duration     = drainTime,
        label        = Translate("ATM_ROBBERY_DRAINING"),
        useWhileDead = false,
        canCancel    = true,
        disable      = { move = true, car = true, combat = true },
    })
    ClearPedTasks(cache.ped)

    -- Clean up phone prop
    if phoneProp and DoesEntityExist(phoneProp) then
        DetachEntity(phoneProp, true, true)
        DeleteEntity(phoneProp)
    end

    if not completed then
        self:stopParticles(particles)
        self.collecting = false
        self:startPedLoop(atmEntity)
        return
    end

    -- Check if money pool is still available
    local poolResult = TriggerServerCallback({
        eventName = eventName .. "server:atmRobberyPoolCheck",
        args      = {},
    })

    self:stopParticles(particles)

    local poolEmpty = not poolResult or not poolResult.status or (poolResult.pool and poolResult.pool <= 0)
    if poolEmpty then
        notify("ATM_ROBBERY_POOL_EMPTY")
        self.collecting = false
        self:startPedLoop(atmEntity)
        return
    end

    -- Spawn cash pile and hand off to collect loop
    local cashPile = self:spawnCashPile(atmEntity)
    if not cashPile then
        self.collecting = false
        self:startPedLoop(atmEntity)
        return
    end

    self:setupCollectTarget(cashPile, atmEntity)
    self.collecting = false
end

-- ─── Ped Loop ─────────────────────────────────────────────────────────────────

function AtmRobbery:startPedLoop(atmEntity)
    self.pedLoopActive = true
    if not self.pedCount then self.pedCount = 0 end

    local maxPeds     = (Config.AtmRobbery and Config.AtmRobbery.MaxPeds) or 5
    local atmCoords   = GetEntityCoords(atmEntity)

    Citizen.CreateThread(function()
        while true do
            if not self.pedLoopActive then break end
            if not DoesEntityExist(atmEntity) then break end
            if not Entity(atmEntity).state.atmHacked then break end

            if self.pedCount >= maxPeds then
                notify("ATM_ROBBERY_MAX_PEDS")
                self.pedLoopActive = false
                break
            end

            notify("ATM_ROBBERY_WAITING_PED")

            local delayMin = (Config.AtmRobbery and Config.AtmRobbery.PedDelayMin) or 7000
            local delayMax = (Config.AtmRobbery and Config.AtmRobbery.PedDelayMax) or 15000
            Wait(math.random(delayMin, delayMax))

            if not self.pedLoopActive then break end

            local ped = self:spawnPed(atmCoords)
            if not ped then
                Wait(3000)
            else
                local arrived = self:waitForPedArrival(ped, atmCoords, 35000)

                if not self.pedLoopActive then
                    self:deletePed(ped)
                    break
                end

                if not arrived then
                    self:deletePed(ped)
                    Wait(2000)
                else
                    -- Ped arrived — play ATM animation and show hack prompt
                    TaskTurnPedToFaceEntity(ped, atmEntity, 1000)
                    Wait(1000)
                    Main:loadanimDict("mini@atmenter")
                    TaskPlayAnim(ped, "mini@atmenter", "enter", 8.0, -8.0, -1, 1, 0, false, false, false)

                    local hackMaxDist = (Config.AtmRobbery and Config.AtmRobbery.HackMaxDistance) or 8.0
                    local playerInteracted = false
                    local playerTooFar     = false

                    lib.showTextUI(Translate("ATM_ROBBERY_HACK_LABEL"), { icon = "fas fa-user-secret" })
                    local hackStart = GetGameTimer()

                    while true do
                        local elapsed = GetGameTimer() - hackStart
                        if elapsed >= 15000 or playerInteracted then break end
                        if not self.pedLoopActive then break end

                        local playerDist = #(GetEntityCoords(cache.ped) - atmCoords)
                        if playerDist > hackMaxDist then
                            playerTooFar = true
                            break
                        end

                        if IsControlJustPressed(0, 38) then
                            playerInteracted = true
                        end
                        Wait(0)
                    end

                    lib.hideTextUI()

                    if not self.pedLoopActive then
                        self:deletePed(ped)
                        break
                    end

                    if playerTooFar then
                        notify("ATM_ROBBERY_TOO_FAR")
                        self:pedWalkAway(ped, true)
                        self.spawnedPed = nil
                        Wait(math.random(3000, 6000))

                    elseif not playerInteracted then
                        -- Timed out
                        self:pedWalkAway(ped, true)
                        self.spawnedPed = nil
                        Wait(math.random(3000, 6000))

                    else
                        -- Launch hacking minigame
                        self.hackBusy = true
                        local atmCfg  = Config.AtmRobbery
                        local gameResult = MatchPairs:start({
                            pairs        = atmCfg.MatchPairsPairs,
                            timeLimit    = atmCfg.MatchPairsTimeLimit,
                            gridCols     = atmCfg.MatchPairsGridCols,
                            gridRows     = atmCfg.MatchPairsGridRows,
                            tilesPerPair = atmCfg.MatchPairsTilesPerPair,
                        })

                        if not self.pedLoopActive then
                            self:deletePed(ped)
                            self.hackBusy = false
                            break
                        end

                        if gameResult.cancelled then
                            self:pedWalkAway(ped, true)
                            self.spawnedPed = nil
                            self.hackBusy   = false
                            Wait(math.random(3000, 6000))

                        elseif gameResult.success or Config.Debug then
                            -- ⚠️ Config.Debug bypasses success — this means in debug mode a failed
                            -- minigame still awards pool credit. Preserving original logic.
                            self.pedCount = (self.pedCount or 0) + 1

                            local poolResult = TriggerServerCallback({
                                eventName = eventName .. "server:atmRobberyPoolAdd",
                                args      = {},
                            })

                            if poolResult and poolResult.status then
                                notify("ATM_ROBBERY_POOL_ADDED", { poolResult.added, poolResult.total })
                            else
                                notify("ATM_ROBBERY_SUCCESS")
                            end

                            self:pedReactAngryOrPolice(ped, atmCoords)
                            self.spawnedPed = nil

                        else
                            notify("ATM_ROBBERY_FAIL")
                            self:pedWalkAway(ped, true)
                            self.spawnedPed = nil
                        end

                        self.hackBusy = false
                        Wait(math.random(5000, 10000))
                    end
                end
            end
        end

        self.pedLoopActive = false
    end)
end

-- ─── Debug Command ────────────────────────────────────────────────────────────

RegisterCommand("testatmrobbery", function()
    Citizen.CreateThread(function()
        local playerCoords = GetEntityCoords(cache.ped)
        local closestAtm   = nil
        local closestDist  = 10.0

        local handle, entity = FindFirstObject()
        local found          = true
        while found do
            if DoesEntityExist(entity) then
                local model = GetEntityModel(entity)
                for _, modelName in ipairs(Config.AtmRobbery.AtmModels) do
                    if model == GetHashKey(modelName) then
                        local dist = #(playerCoords - GetEntityCoords(entity))
                        if dist < closestDist then
                            closestAtm  = entity
                            closestDist = dist
                        end
                    end
                end
            end
            found, entity = FindNextObject(handle)
        end
        EndFindObject(handle)

        if closestAtm then
            if Entity(closestAtm).state.atmHacked then
                AtmRobbery:removeDevice(closestAtm)
            else
                AtmRobbery:attachDevice(closestAtm)
            end
        else
            Framework:Notify("No ATM nearby")
        end
    end)
end, false)

-- ─── Resource Cleanup ─────────────────────────────────────────────────────────

AddEventHandler("onResourceStop", function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end

    AtmRobbery.pedLoopActive = false
    AtmRobbery:cleanupPed()

    if AtmRobbery.cashPileProp and DoesEntityExist(AtmRobbery.cashPileProp) then
        DeleteEntity(AtmRobbery.cashPileProp)
        AtmRobbery.cashPileProp = nil
    end
end)