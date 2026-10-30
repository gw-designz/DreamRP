if not (Config and Config.Garage and Config.Garage.Enabled) then return end

Garage = {}
Garage.currentGarage = nil

-- ============================================================
--  Helpers (file-local)
-- ============================================================

-- Resolves numeric model hashes to lowercase name strings, and tries
-- to populate a readable label from GTA's label table.
local function resolveVehicleModels(vehicles)
    for _, v in ipairs(vehicles or {}) do
        local model = v.model
        local hash  = type(model) == "number" and model or tonumber(model)
        if hash then
            local displayName = GetDisplayNameFromVehicleModel(hash)
            if displayName and displayName ~= "" and displayName ~= "CARNOTFOUND" then
                v.model = displayName:lower()
                local labelText = GetLabelText(displayName)
                if labelText and labelText ~= "" and labelText ~= "NULL" then
                    v.label = labelText
                end
            end
        end
    end
    return vehicles
end

-- Spawns and configures a garage NPC ped.
local function spawnGaragePed(pedDef)
    local model = lib.requestModel(pedDef.model)
    if not model then return nil end

    local ped = CreatePed(4, model,
        pedDef.coords.x, pedDef.coords.y, pedDef.coords.z - 1.0, pedDef.coords.w,
        false, true)

    SetEntityInvincible(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    FreezeEntityPosition(ped, true)

    if pedDef.scenario then
        TaskStartScenarioInPlace(ped, pedDef.scenario, 0, true)
    elseif pedDef.anim then
        local animDict = lib.requestAnimDict(pedDef.anim.dict)
        TaskPlayAnim(ped, animDict, pedDef.anim.clip, 8.0, -8.0, -1, 1, 0, false, false, false)
        RemoveAnimDict(animDict)
    end

    if pedDef.onCreate then pedDef.onCreate(ped) end
    SetModelAsNoLongerNeeded(model)
    return ped
end

-- Returns the first spawn point in garageDef that has no nearby vehicles,
-- or nil if all are occupied.
local function findFreeSpawnPoint(garageDef)
    for i = 1, #garageDef.spawnPoints do
        local sp = garageDef.spawnPoints[i]
        local nearby = lib.getNearbyVehicles(vector3(sp.x, sp.y, sp.z), 2.5, true)
        if #nearby == 0 then return sp end
    end
    return nil
end

-- ============================================================
--  Garage methods
-- ============================================================

function Garage.open(self, garageName)
    local garageDef = Config.DepartmentData.garages[garageName]
    if not garageDef then return end

    self.currentGarage = garageName

    local vehicles = lib.callback.await("p_policejob/garage/getVehicles", false, garageName) or {}
    resolveVehicleModels(vehicles)

    SendNUIMessage({ action = "setGarageData", data = {
        garageName  = garageName,
        garageLabel = garageDef.label or garageName,
        vehicles    = vehicles,
        inVehicle   = cache.vehicle ~= nil,
    }})
    SendNUIMessage({ action = "setVisibleGarage", data = true })
    SetNuiFocus(true, true)
end

function Garage.close(self)
    self.currentGarage = nil
    SendNUIMessage({ action = "setVisibleGarage", data = false })
    SetNuiFocus(false, false)
end

function Garage.takeOutVehicle(self, vehicleData, isJobVehicle, garageName)
    local garage = Config.DepartmentData.garages[garageName or self.currentGarage]
    if not garage then return false end

    local model = lib.requestModel(vehicleData.model)
    if not model then return false end

    local spawnPoint = findFreeSpawnPoint(garage)
    if not spawnPoint then
        Bridge.Notify.showNotify(locale("garage_no_free_spawn"), "error")
        SetModelAsNoLongerNeeded(model)
        return false
    end

    -- For owned (non-job) vehicles, confirm server-side and get saved properties
    local properties = nil
    if not isJobVehicle then
        properties = lib.callback.await("p_policejob/garage/takeOutVehicle", false, vehicleData)
        if not properties then
            Bridge.Notify.showNotify(locale("garage_cant_get_vehicle"), "error")
            SetModelAsNoLongerNeeded(model)
            return false
        end
    elseif vehicleData.preconfigured and vehicleData.properties then
        properties = vehicleData.properties
    end

    local vehicle = CreateVehicle(model, spawnPoint.x, spawnPoint.y, spawnPoint.z, spawnPoint.w, true, false)
    SetEntityAsMissionEntity(vehicle, true, true)
    SetVehicleOnGroundProperly(vehicle)

    local netId = NetworkGetNetworkIdFromEntity(vehicle)
    SetNetworkIdCanMigrate(netId, true)
    SetNetworkIdExistsOnAllMachines(netId, true)
    SetVehicleHasBeenOwnedByPlayer(vehicle, true)

    if type(properties) == "table" then
        lib.setVehicleProperties(vehicle, properties)
    else
        if vehicleData.plate then SetVehicleNumberPlateText(vehicle, vehicleData.plate) end
        Entity(vehicle).state:set("isPoliceVehicle", true, true)
    end

    local plate = GetVehicleNumberPlateText(vehicle)
    TaskWarpPedIntoVehicle(cache.ped, vehicle, -1)
    SetModelAsNoLongerNeeded(model)
    Bridge.CarKeys.CreateKeys(plate, vehicle)
    return true
end

function Garage.storeVehicle(self)
    local garage = Config.DepartmentData.garages[self.currentGarage]
    if not garage then return end

    local vehicle = GetVehiclePedIsIn(cache.ped, true)
    if not vehicle or vehicle == 0 or not NetworkGetEntityIsNetworked(vehicle) then
        Bridge.Notify.showNotify(locale("no_vehicle_to_store"), "error")
        return
    end

    local vehicleCoords = GetEntityCoords(vehicle)
    local pedCoords     = GetEntityCoords(cache.ped)
    if #(vehicleCoords - pedCoords) > Config.Garage.maxDistance then
        Bridge.Notify.showNotify(locale("vehicle_too_far"), "error")
        return
    end

    TriggerServerEvent("p_policejob/garage/storeVehicle", {
        plate       = GetVehicleNumberPlateText(vehicle),
        model       = GetEntityModel(vehicle),
        netId       = NetworkGetNetworkIdFromEntity(vehicle),
        properties  = lib.getVehicleProperties(vehicle),
        garageName  = self.currentGarage,
    })
end

-- ============================================================
--  NUI callbacks
-- ============================================================

RegisterNUICallback("garage:takeOut", function(data, cb)
    if not Garage.currentGarage or not data.vehicle then
        cb({ success = false }); return
    end
    local garageName = Garage.currentGarage
    Garage:close()
    local ok = Garage:takeOutVehicle(data.vehicle, data.vehicle.isJobVehicle, garageName)
    cb({ success = ok or false })
end)

RegisterNUICallback("garage:store", function(data, cb)
    if not Garage.currentGarage then cb({ success = false }); return end
    Garage:storeVehicle()
    Garage:close()
    cb({ success = true })
end)

RegisterNUICallback("garage:refresh", function(data, cb)
    if not Garage.currentGarage then cb({}); return end
    local vehicles = lib.callback.await("p_policejob/garage/getVehicles", false, Garage.currentGarage) or {}
    cb(resolveVehicleModels(vehicles))
end)

-- ============================================================
--  Net events
-- ============================================================

RegisterNetEvent("p_policejob/garage/vehicleStored", function(plate)
    if plate then Bridge.CarKeys.RemoveKeys(plate) end
    Bridge.Notify.showNotify(locale("vehicle_stored"), "success")
end)

-- ============================================================
--  Global event — hide frame
-- ============================================================

AddEventHandler("p_policejob:client:hideFrame", function(data)
    if data.name == "setVisibleGarage" then Garage:close() end
end)

-- ============================================================
--  Ped spawning + blips + target options (per garage)
-- ============================================================

Citizen.CreateThread(function()
    for garageName, garageDef in pairs(Config.DepartmentData.garages or {}) do
        -- Optional map blip
        if garageDef.blip and garageDef.blip.enabled then
            local blip = AddBlipForCoord(garageDef.blip.coords.x, garageDef.blip.coords.y, garageDef.blip.coords.z)
            SetBlipSprite(blip,        garageDef.blip.sprite)
            SetBlipColour(blip,        garageDef.blip.color)
            SetBlipScale(blip,         garageDef.blip.scale)
            SetBlipAsShortRange(blip,  true)
            BeginTextCommandSetBlipName("STRING")
            AddTextComponentSubstringPlayerName(garageDef.blip.label)
            EndTextCommandSetBlipName(blip)
        end

        -- Proximity point — spawns/despawns the NPC and attaches target options
        local point = lib.points.new({
            coords   = vector3(garageDef.ped.coords.x, garageDef.ped.coords.y, garageDef.ped.coords.z),
            distance = 50,
        })

        function point:onEnter()
            self.ped = spawnGaragePed(garageDef.ped)
            if not self.ped then return end

            local options = {
                {
                    name     = "garage_open_" .. garageName,
                    label    = locale("open_police_garage"),
                    icon     = "fa-solid fa-warehouse",
                    distance = 2.5,
                    groups   = Config.Jobs,
                    onSelect = function() Garage:open(garageName) end,
                },
            }

            -- Only add "store" option when not in spawner-only mode
            if not garageDef.spawnerMode then
                options[#options + 1] = {
                    name     = "garage_store_" .. garageName,
                    label    = locale("store_vehicle"),
                    icon     = "fa-solid fa-square-parking",
                    distance = 2.5,
                    groups   = Config.Jobs,
                    onSelect = function()
                        Garage.currentGarage = garageName
                        Garage:storeVehicle()
                    end,
                }
            end

            Bridge.Target.addLocalEntity(self.ped, options)
        end

        function point:onExit()
            if not self.ped then return end
            Bridge.Target.removeLocalEntity(self.ped, {
                "garage_open_"  .. garageName,
                "garage_store_" .. garageName,
            })
            DeleteEntity(self.ped)
            self.ped = nil
        end
    end
end)
