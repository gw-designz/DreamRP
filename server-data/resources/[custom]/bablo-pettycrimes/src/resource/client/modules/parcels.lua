if not Config.Modules.PARCEL_THEFT then return end

Parcels = {
    parcels       = {},
    isTriggered   = false,
    parcelEntity  = nil,
}

-- Disabled controls while carrying a parcel (attack, aim, weapon-switch, etc.)
local CARRY_DISABLED_CONTROLS = { 22, 23, 24, 25, 36, 47, 58, 140, 141, 142, 143, 257, 263, 264 }

local function drawWorldLabel(coords, text)
    local onScreen, screenX, screenY = World3dToScreen2d(coords.x, coords.y, coords.z)
    if not onScreen then return end

    SetTextScale(0.35, 0.35)
    SetTextFont(4)
    SetTextProportional(1)
    SetTextColour(255, 255, 255, 215)
    SetTextOutline()
    SetTextEntry("STRING")
    SetTextCentre(1)
    AddTextComponentString(text)
    DrawText(screenX, screenY)
end

local function getEntityNetId(entity)
    if NetworkGetEntityIsNetworked(entity) then
        local netId = NetworkGetNetworkIdFromEntity(entity)
        if netId then return netId end
    end
    return nil
end

local function maybeSendDispatch()
    local roll = math.random(1, 100)
    if roll > Config.Parcels.AlertChance then return end

    Dispatch:Send(BuildDispatchData({
        message = Translate("PARCEL_DISPATCH"),
        coords  = GetEntityCoords(cache.ped),
        jobs    = { "police", "lspd", "bcso" },
        blip    = {
            sprite = 458,
            color  = 1,
            scale  = 1.0,
            text   = Translate("PARCEL_DISPATCH_BLIP"),
            flash  = true,
        },
    }, Config.Parcels.Dispatch))
end

-- Spawns the world label and proximity point for a single parcel entry.
-- Called once per parcel during Init.
local function setupParcelPoint(parcelId, parcelData)
    local point = lib.points.new({
        coords   = parcelData.coords,
        distance = parcelData.distance or 25.0,
    })

    point.onEnter = function()
        local parcel = Parcels.parcels[parcelId]
        if not parcel.cooldown and not parcel.entity then
            Parcels:spawnParcelEntity(parcelId)
        end
    end

    point.onExit = function()
        Parcels:removeParcelEntity(parcelId)
    end

    point.nearby = function()
        local parcel = Parcels.parcels[parcelId]

        if Config.Debug then
            if parcel.cooldown then
                drawWorldLabel(parcel.coords, "Parcel is on cooldown " .. parcelId)
            else
                drawWorldLabel(parcel.coords, "Not on cooldown can be picked up " .. parcelId)
            end
        end

        if parcel.cooldown then
            if parcel.entity then
                Parcels:removeParcelEntity(parcelId)
            end
        elseif not parcel.entity then
            Parcels:spawnParcelEntity(parcelId)
        end
    end

    parcelData.point = point
end

-- Fetches parcel data from the server, sets up proximity points, and
-- restores the carry prop if the player already had a package.
function Parcels:Init()
    if self.isTriggered then return end
    self.isTriggered = true

    local result = TriggerServerCallback({
        eventName = eventName .. "server:getParcels",
        args      = {},
    })

    if not result.status then
        Trace(result.message)
        return
    end

    self.parcels = result.parcels

    -- Restore carry prop if the player already has a bpackage item
    local hasPackage = TriggerServerCallback({
        eventName = eventName .. "server:hasItem",
        args      = { "bpackage" },
    })
    if hasPackage.status then
        self:holdParcel()
    end

    -- Create proximity points for each parcel
    for parcelId, parcelData in pairs(self.parcels) do
        if parcelData.coords and parcelData.prop then
            setupParcelPoint(parcelId, parcelData)
        else
            Trace("Skipping parcel " .. parcelId .. " - missing coords or prop data")
        end
    end
end

-- Validates action conditions and then steals the targeted parcel entity
function Parcels:onStealParcel(parcelId, entity)
    if not Framework:canDoAction("PARCEL_THEFT") then
        Framework:Notify(Translate("CANT_DO_ACTION"))
        return
    end

    if Main:getPoliceCount() < Config.Parcels.PoliceRequired then
        Framework:Notify(Translate("NOT_ENOUGH_POLICE"))
        return
    end

    Main:playAnimation({ ped = cache.ped, dict = "missheist_agency2aig_13", lib = "pickup_briefcase", flag = 1 })

    maybeSendDispatch()

    Citizen.Wait(1000)
    ClearPedTasks(cache.ped)

    local result = TriggerServerCallback({
        eventName = eventName .. "server:stealParcel",
        args      = { parcelId },
    })

    if result.status then
        Framework:onFinished("PARCEL_THEFT")
        self:holdParcel()
    else
        Framework:Notify(Translate("NO_PACKAGE_TOO_STEAL"))
        Trace(result.message or "No message provided")
    end
end

-- Opens a collected parcel item: rolls for bomb, gives loot, updates carry state
function Parcels:openParcel(itemData)
    local giveLoot = true

    if Config.Parcels.BombEnabled ~= false then
        local roll = math.random(1, 100)
        if roll <= Config.Parcels.ParcelBombProbability then
            self:createBomb()
            giveLoot = false
        end
    end

    local itemName = Main:selectRandomItem(Config.Parcels.LootTables).name
    local lootResult = TriggerServerCallback({
        eventName = eventName .. "server:giveParcelLoot",
        args      = { { itemName = itemName, itemData = itemData, giveLoot = giveLoot } },
    })

    if lootResult.success then
        if lootResult.message then
            Framework:Notify(lootResult.message)
        end
    else
        Framework:Notify(Translate("NOTHING_FOUND"))
    end

    -- Sync carry state: re-attach prop if still holding a package, or clean up
    local hasPackage = TriggerServerCallback({
        eventName = eventName .. "server:hasItem",
        args      = { "bpackage" },
    })

    if hasPackage.status then
        if not self.parcelEntity then
            self:holdParcel()
        end
    else
        if self.parcelEntity then
            DeleteEntity(self.parcelEntity)
        end
        self.parcelEntity = nil
        ClearPedTasks(cache.ped)
    end
end

-- Spawns a parcel box prop in the world at the given parcel location and
-- registers a target interaction on it.
function Parcels:spawnParcelEntity(parcelId)
    local parcelData = self.parcels[parcelId]
    if not parcelData then return end
    if parcelData.entity or parcelData.cooldown then return end
    if not parcelData.coords or not parcelData.prop then
        Trace("Parcel " .. parcelId .. " missing required data: coords or prop")
        return
    end

    local entity = Main:spawnLocalObject(parcelData.prop, parcelData.coords, parcelData.heading)

    while not DoesEntityExist(entity) do
        Wait(0)
    end

    Target:addTargetEntity(entity, {
        label       = Translate("STEAL_PARCEL_LABEL"),
        icon        = "fas fa-box",
        action      = function(targetEntity)
            self:onStealParcel(parcelId, targetEntity)
        end,
        canInteract = function() return true end,
    })

    parcelData.entity    = entity
    parcelData.contextId = "parcel-theft-" .. parcelId
end

-- Deletes the world prop and removes its target for the given parcel
function Parcels:removeParcelEntity(parcelId)
    local parcelData = self.parcels[parcelId]
    if not parcelData or not parcelData.entity then return end

    if DoesEntityExist(parcelData.entity) then
        DeleteEntity(parcelData.entity)
        if parcelData.contextId then
            Target:removeTargetEntity(parcelData.entity, parcelData.contextId)
        end
    end

    parcelData.entity    = nil
    parcelData.contextId = nil
end

-- Attaches a parcel box to the player's hand and loops the carry animation/controls
-- until the entity is deleted (item consumed or resource stopped).
function Parcels:holdParcel()
    if Config.HoldParcelAfterCollect == false then return end

    local prop = CreateObject("v_serv_abox_02", 0, 0, 0, true, true, true)
    self.parcelEntity = prop

    local boneIdx = GetPedBoneIndex(cache.ped, 60309)
    AttachEntityToEntity(
        prop, cache.ped, boneIdx,
        0.095, -0.1, 0.21, -70.0, 0.0, 10.0,
        true, true, false, false, 0, true
    )

    Citizen.CreateThread(function()
        while DoesEntityExist(self.parcelEntity) do
            if not IsEntityPlayingAnim(cache.ped, "anim@heists@box_carry@", "idle", 3) then
                Main:playAnimation({ ped = cache.ped, dict = "anim@heists@box_carry@", lib = "idle", flag = 49 })
            end

            for _, control in ipairs(CARRY_DISABLED_CONTROLS) do
                DisableControlAction(0, control, true)
            end

            Citizen.Wait(0)
        end

        -- Prop was deleted externally; check if player still has the item
        local hasPackage = TriggerServerCallback({
            eventName = eventName .. "server:hasItem",
            args      = { "bpackage" },
        })
        if hasPackage.status then
            self:holdParcel()
        end
    end)
end

-- Places a ticking bomb box prop, starts the disarm progress bar,
-- and either cleans up on success or detonates on failure.
function Parcels:createBomb()
    local pedCoords  = GetEntityCoords(cache.ped)
    local forward    = GetEntityForwardVector(cache.ped)
    local dropPos    = pedCoords + forward * 0.8
    local groundZ    = GetGroundCoord(dropPos)

    local bombEntity = CreateObject("v_serv_abox_02", dropPos.x, dropPos.y, groundZ, true, true, true)
    FreezeEntityPosition(bombEntity, true)
    SetEntityHeading(bombEntity, GetEntityHeading(cache.ped))

    TriggerServerEvent("InteractSound_SV:PlayWithinDistance", 5, "lock", 0.3)

    local soundData = {
        sound    = "./sounds/bomb-ticking.ogg",
        coords   = dropPos,
        volume   = 0.5,
        distance = 5.0,
        loop     = false,
        synced   = true,
    }

    local soundResult = TriggerServerCallback({
        eventName = eventName .. "server:playSound",
        args      = { soundData },
    })

    if not soundResult.status then
        Trace(soundResult.message)
        return
    end

    local soundId    = soundResult.uniqueId
    local bombNetId  = getEntityNetId(bombEntity)
    local disarmTime = 30000
    local startTime  = GetGameTimer()
    local disarmed   = nil  -- nil = pending, true = success, false = failed

    Main:playAnimation({ ped = cache.ped, dict = "amb@medic@standing@tendtodead@idle_a", lib = "idle_a", flag = 1 })

    -- Sync smoke particles to all clients for the bomb duration
    TriggerServerEvent(eventName .. "server:syncParticles", "smoke", {
        netId    = bombNetId,
        duration = disarmTime,
    })

    Framework:doProgress({
        text = Translate("DISARMING_BOMB"),
        time = disarmTime,
    }, function(succeeded)
        local elapsed      = GetGameTimer() - startTime
        local timeRemaining = math.max(0, disarmTime - elapsed)

        if succeeded then
            disarmed = true
            ClearPedTasks(cache.ped)
            Framework:Notify(Translate("BOMB_DISARMED"))
            TriggerServerEvent(eventName .. "server:stopSound", soundId)
        else
            disarmed = false
            ClearPedTasks(cache.ped)
        end

        -- Wait for disarmed flag to be set (it's set just above, so this loop
        -- is a safety poll in case of any async gap)
        Citizen.Wait(1500)
        while disarmed == nil do Citizen.Wait(250) end

        if disarmed then
            if DoesEntityExist(bombEntity) then
                Citizen.Wait(2000)
                DeleteEntity(bombEntity)
            end
            return
        end

        -- Disarm failed: extend smoke, wait, explode
        local bombNetIdFail = getEntityNetId(bombEntity)
        TriggerServerEvent(eventName .. "server:syncParticles", "smoke", {
            netId    = bombNetIdFail,
            duration = timeRemaining + 3000,
        })
        Citizen.Wait(timeRemaining + 3000)

        TriggerServerEvent(eventName .. "server:stopSound", soundId)

        if DoesEntityExist(bombEntity) then
            DeleteEntity(bombEntity)
        end

        AddExplosion(dropPos.x, dropPos.y, groundZ, 0, 1.0, true, false, 1.0)

        Dispatch:Send(BuildDispatchData({
            message = Translate("PARCEL_BOMB_DISPATCH"),
            coords  = vector3(dropPos.x, dropPos.y, groundZ),
            jobs    = { "police", "lspd", "bcso" },
            blip    = {
                sprite = 436,
                color  = 1,
                scale  = 1.0,
                text   = Translate("PARCEL_BOMB_DISPATCH_BLIP"),
                flash  = true,
            },
        }, Config.Parcels.BombDispatch))
    end)
end

-- Startup: wait for framework core, then init if character is already loaded
Citizen.CreateThread(function()
    while not Framework or not Framework.getCore do
        Citizen.Wait(0)
    end
    WaitForConfigSync()
    if Framework:isCharacterLoaded() then
        Parcels:Init()
    end
end)

RegisterNetEvent(eventName .. "client:characterLoaded")
AddEventHandler(eventName .. "client:characterLoaded", function()
    Parcels:Init()
end)

-- Server pushes cooldown changes for individual parcels
RegisterNetEvent(eventName .. "client:updateParcels")
AddEventHandler(eventName .. "client:updateParcels", function(updates)
    for parcelId, updateData in pairs(updates) do
        local parcel = Parcels.parcels[parcelId]
        if not parcel then goto continue end

        local prevCooldown = parcel.cooldown
        parcel.cooldown    = updateData.cooldown

        if prevCooldown ~= updateData.cooldown then
            if updateData.cooldown then
                Parcels:removeParcelEntity(parcelId)
            else
                -- Respawn if the player is still within range
                local point = parcel.point
                if point and point.currentDistance then
                    local spawnDist = parcel.distance or 25.0
                    if point.currentDistance <= spawnDist then
                        Parcels:spawnParcelEntity(parcelId)
                    end
                end
            end
        end

        ::continue::
    end
end)

-- Inventory system event: attach carry prop when a package item is received
RegisterNetEvent("inventory:receiveItem")
AddEventHandler("inventory:receiveItem", function(data)
    if data.item.config.id == "package" then
        if not Parcels.parcelEntity then
            Parcels:holdParcel()
        end
    end
end)

-- Use the held parcel item → open it
RegisterNetEvent(eventName .. "client:useParcelItem")
AddEventHandler(eventName .. "client:useParcelItem", function(itemData)
    Parcels:openParcel(itemData)
end)

AddEventHandler("onResourceStop", function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end

    for _, parcelData in pairs(Parcels.parcels) do
        if parcelData.entity and DoesEntityExist(parcelData.entity) then
            DeleteEntity(parcelData.entity)
            Target:removeTargetEntity(parcelData.entity, parcelData.contextId)
        end
        if parcelData.point then
            parcelData.point:remove()
        end
    end

    if Parcels.parcelEntity and DoesEntityExist(Parcels.parcelEntity) then
        DeleteEntity(Parcels.parcelEntity)
        ClearPedTasks(cache.ped)
    end
end)

if Config.Debug then
    RegisterCommand("testbomb", function()
        Parcels:createBomb()
    end)
end

exports("isHoldingParcel", function()
    return Parcels.parcelEntity ~= nil
end)

exports("deleteHoldingEntity", function()
    if Parcels.parcelEntity and DoesEntityExist(Parcels.parcelEntity) then
        DeleteEntity(Parcels.parcelEntity)
    end
    Parcels.parcelEntity = nil
end)