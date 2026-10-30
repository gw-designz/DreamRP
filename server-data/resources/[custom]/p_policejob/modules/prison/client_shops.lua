if not (Config and Config.Prison and Config.Prison.Enabled) then return end

-- Zone handles for ox_target sphere zones (commissary / illegal shop)
local sphereZones = {}
-- Entity handles for spawned shop NPC peds
local spawnedPeds = {}

-- ─── NPC Spawning ────────────────────────────────────────────────────────────

-- Spawns a shop NPC ped with optional animation or scenario; returns entity handle or nil
local function SpawnShopPed(pedConfig)
    local modelHash = joaat(pedConfig.model)
    lib.requestModel(pedConfig.model)

    if not HasModelLoaded(modelHash) then return nil end

    local coords = pedConfig.coords
    local ped    = CreatePed(4, modelHash,
        coords.x, coords.y, coords.z - 1.0,
        coords.w or 0.0,
        false, true
    )

    SetEntityHeading(ped, coords.w or 0.0)
    FreezeEntityPosition(ped, true)
    SetEntityInvincible(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetPedFleeAttributes(ped, 0, false)
    SetPedCombatAttributes(ped, 46, true)
    SetPedCanRagdollFromPlayerImpact(ped, false)

    -- Play animation or scenario
    if pedConfig.anim and pedConfig.anim.dict and pedConfig.anim.clip then
        lib.requestAnimDict(pedConfig.anim.dict)
        TaskPlayAnim(ped, pedConfig.anim.dict, pedConfig.anim.clip,
            4.0, -4.0, -1, pedConfig.anim.flag or 1, 0, false, false, false)
    elseif pedConfig.scenario then
        TaskStartScenarioInPlace(ped, pedConfig.scenario, 0, true)
    end

    SetModelAsNoLongerNeeded(modelHash)
    return ped
end

-- ─── Target Zone Registration ─────────────────────────────────────────────────

-- Registers either a local-entity target (ped) or a sphere zone (coords table)
-- depending on whether `locationOrPed` has a .model field
local function AddShopTarget(locationOrPed, targetOption)
    if type(locationOrPed) == "table" and locationOrPed.model then
        -- ped config: spawn the ped and attach a local entity target
        local ped = SpawnShopPed(locationOrPed)
        if not ped then return end

        spawnedPeds[#spawnedPeds + 1] = ped
        Bridge.Target.addLocalEntity(ped, { targetOption })
    else
        -- plain coords: add an ox_target sphere zone
        local zone = exports.ox_target:addSphereZone({
            coords  = vec3(locationOrPed.x, locationOrPed.y, locationOrPed.z),
            radius  = 1.2,
            debug   = false,
            options = { targetOption },
        })
        sphereZones[#sphereZones + 1] = zone
    end
end

-- ─── Init Thread ─────────────────────────────────────────────────────────────

CreateThread(function()
    while not Config.Prison do Wait(100) end
    while not Prison.Map   do Wait(100) end

    -- Commissary shop
    if Config.Prison.Commissary.enabled and Prison.Map.commissary then
        AddShopTarget(Prison.Map.commissary, {
            name   = "p_policejob:prison:commissary",
            label  = locale("prison_commissary"),
            icon   = "fa-solid fa-cart-shopping",
            canInteract = function()
                return Prison.isInPrison == true
            end,
            onSelect = function()
                openShopNui("commissary")
            end,
        })
    end

    -- Illegal shop
    if Config.Prison.IllegalShop.enabled and Prison.Map.illegalShop then
        AddShopTarget(Prison.Map.illegalShop, {
            name   = "p_policejob:prison:illegalShop",
            label  = locale("prison_illegal_shop"),
            icon   = "fa-solid fa-mask",
            canInteract = function()
                return Prison.isInPrison == true
            end,
            onSelect = function()
                openShopNui("illegal")
            end,
        })
    end
end)

-- ─── Cleanup ─────────────────────────────────────────────────────────────────

AddEventHandler("onResourceStop", function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end

    for _, zone in ipairs(sphereZones) do
        pcall(function()
            exports.ox_target:removeZone(zone)
        end)
    end

    for _, ped in ipairs(spawnedPeds) do
        if DoesEntityExist(ped) then
            Bridge.Target.removeLocalEntity(ped)
            DeleteEntity(ped)
        end
    end
end)
