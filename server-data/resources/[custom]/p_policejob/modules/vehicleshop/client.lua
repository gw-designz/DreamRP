if not (Config and Config.VehicleShop and Config.VehicleShop.Enabled) then return end

VehicleShop = {}
VehicleShop.shopCam           = nil
VehicleShop.previewVehicle    = nil
VehicleShop.currentShop       = nil
VehicleShop.testDriveVehicle  = nil
VehicleShop.testDriveTimer    = nil
VehicleShop.testDriveCoords   = nil
VehicleShop.inShop            = false
VehicleShop.rotationId        = 0
VehicleShop.isSpawning        = false

-- ============================================================
--  Stat cache (avoids repeated native calls for the same model)
-- ============================================================

local statCache = {}  -- [model] = { maxSpeed, acceleration, braking, handling, seats }

-- Normalises a value to a 0-100 percentage relative to the class max.
local function toPercent(value, classMax)
    if not classMax or classMax <= 0 then return 0 end
    local pct = math.floor(value / classMax * 100 + 0.5)
    return math.max(0, math.min(100, pct))
end

-- Returns a stats table for the given model name or hash.
local function getModelStats(model)
    if statCache[model] then return statCache[model] end

    local hash = (type(model) == "number") and model or joaat(model)

    if not IsModelInCdimage(hash) or not IsModelAVehicle(hash) then
        statCache[model] = { maxSpeed = 0, acceleration = 0, braking = 0, handling = 0, seats = 0 }
        return statCache[model]
    end

    local class       = GetVehicleClassFromName(hash)
    local classSpeed  = GetVehicleClassEstimatedMaxSpeed(class)
    local classAccel  = GetVehicleClassMaxAcceleration(class)
    local classBrake  = GetVehicleClassMaxBraking(class)
    local classTract  = GetVehicleClassMaxTraction(class)

    statCache[model] = {
        maxSpeed     = toPercent(GetVehicleModelEstimatedMaxSpeed(hash), classSpeed),
        acceleration = toPercent(GetVehicleModelAcceleration(hash),      classAccel),
        braking      = toPercent(GetVehicleModelMaxBraking(hash),         classBrake),
        handling     = toPercent(GetVehicleModelMaxTraction(hash),        classTract),
        seats        = GetVehicleModelNumberOfSeats(hash),
    }
    return statCache[model]
end

-- ============================================================
--  Vehicle list builder
-- ============================================================

-- Returns a flat array of vehicle entries for the NUI, filtered by job/grade access.
local function buildVehicleList(jobName, jobGrade)
    local list = {}

    for category, vehicles in pairs(Config.VehicleShop.Vehicles) do
        for _, v in ipairs(vehicles) do
            -- Determine if the player has the right job AND grade for this specific vehicle
            local jobAllowed = false
            for _, allowedJob in ipairs(v.allowedJobs) do
                if allowedJob == jobName then jobAllowed = true; break end
            end

            local locked = not jobAllowed
            if jobAllowed then
                local minGrade = v.allowedGrades and v.allowedGrades[jobName]
                if minGrade and jobGrade < minGrade then locked = true end
            end

            local stats  = getModelStats(v.model)
            local armor  = 0
            if v.armor then
                armor = (math.max(0, math.min(4, v.armor)) + 1) * 20
            end

            list[#list + 1] = {
                id           = v.id,
                name         = v.name,
                model        = v.model,
                category     = category,
                price        = v.price,
                maxSpeed     = stats.maxSpeed,
                acceleration = stats.acceleration,
                braking      = stats.braking,
                handling     = stats.handling,
                seats        = stats.seats,
                armor        = armor,
                description  = v.description,
                locked       = locked,
                rank         = v.rank,
            }
        end
    end

    return list
end

-- ============================================================
--  Salesperson NPC helper
-- ============================================================

-- Spawns a stationary NPC for a vehicle shop location.
local function spawnSalesperson(pedCfg)
    local model = lib.requestModel(pedCfg.model)
    if not model then return nil end

    local ped = CreatePed(4, model,
        pedCfg.coords.x, pedCfg.coords.y, pedCfg.coords.z - 1.0, pedCfg.coords.w,
        false, true)

    SetEntityInvincible(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    FreezeEntityPosition(ped, true)

    if pedCfg.scenario then
        TaskStartScenarioInPlace(ped, pedCfg.scenario, 0, true)
    elseif pedCfg.anim then
        local dict = lib.requestAnimDict(pedCfg.anim.dict)
        TaskPlayAnim(ped, dict, pedCfg.anim.clip, 8.0, -8.0, -1, 1, 0, false, false, false)
        RemoveAnimDict(dict)
    end

    SetModelAsNoLongerNeeded(model)
    return ped
end

-- ============================================================
--  Camera
-- ============================================================

function VehicleShop.initCamera(self, shopCfg)
    local cam = CreateCam("DEFAULT_SCRIPTED_CAMERA", true)
    self.shopCam = cam
    SetCamCoord(cam, shopCfg.camera.coords.x, shopCfg.camera.coords.y, shopCfg.camera.coords.z)
    PointCamAtCoord(cam, shopCfg.camera.pointAt.x, shopCfg.camera.pointAt.y, shopCfg.camera.pointAt.z)
    SetCamFov(cam, shopCfg.camera.fov or 50.0)
    SetCamActive(cam, true)
    RenderScriptCams(true, true, 500, true, true)
end

function VehicleShop.destroyCamera(self)
    if self.shopCam then
        RenderScriptCams(false, true, 500, true, true)
        DestroyCam(self.shopCam, true)
        self.shopCam = nil
    end
end

-- ============================================================
--  Preview vehicle
-- ============================================================

function VehicleShop.deletePreviewVehicle(self)
    if self.previewVehicle and DoesEntityExist(self.previewVehicle) then
        DeleteVehicle(self.previewVehicle)
        self.previewVehicle = nil
    end
end

-- Spawns a rotating preview vehicle at the shop's vehicleSpawn point.
function VehicleShop.spawnPreviewVehicle(self, model, shopCfg)
    if self.isSpawning then return end
    self.isSpawning = true

    self.rotationId = self.rotationId + 1
    local currentRotId = self.rotationId

    self:deletePreviewVehicle()

    local hash = lib.requestModel(model)
    if not hash or self.rotationId ~= currentRotId then
        self.isSpawning = false
        return
    end

    local spawn   = shopCfg.vehicleSpawn
    local vehicle = CreateVehicle(hash, spawn.x, spawn.y, spawn.z, spawn.w, false, false)
    self.previewVehicle = vehicle

    SetEntityAsMissionEntity(vehicle, true, true)
    SetVehicleOnGroundProperly(vehicle)
    SetVehicleDoorsLocked(vehicle, 2)
    FreezeEntityPosition(vehicle, true)
    SetVehicleNumberPlateText(vehicle, "PREVIEW")
    SetModelAsNoLongerNeeded(hash)
    self.isSpawning = false

    -- Slow-rotation thread (stops when rotationId changes or shop closes)
    local veh = vehicle
    Citizen.CreateThread(function()
        local heading = spawn.w
        while self.rotationId == currentRotId and veh and DoesEntityExist(veh) and self.inShop do
            heading = heading + 0.2
            if heading > 360 then heading = 0 end
            SetEntityHeading(veh, heading)
            Citizen.Wait(25)
        end
    end)
end

-- ============================================================
--  Open / close
-- ============================================================

function VehicleShop.open(self, shopName)
    local shopCfg = Config.DepartmentData.vehicleShops[shopName]
    if not shopCfg then return end

    self.currentShop = shopName
    self.inShop      = true

    TriggerServerEvent("p_policejob/vehicleshop/setBucket", true)

    local playerJob = Bridge.Framework.fetchPlayerJob()
    local money     = lib.callback.await("p_bridge/server/framework/getMoney", false)
    local vehicles  = buildVehicleList(playerJob.name, playerJob.grade)

    self:initCamera(shopCfg)

    SendNUIMessage({ action = "setVehicleShopItems", data = vehicles })
    SendNUIMessage({ action = "setPlayerMoney", data = {
        cash = (money and money.money) or 0,
        bank = (money and money.bank)  or 0,
    }})
    SendNUIMessage({ action = "setVisibleVehicleShop", data = true })
    SetNuiFocus(true, true)
end

function VehicleShop.close(self)
    self.inShop      = false
    self.currentShop = nil
    self:deletePreviewVehicle()
    self:destroyCamera()
    TriggerServerEvent("p_policejob/vehicleshop/setBucket", false)
    SendNUIMessage({ action = "setVisibleVehicleShop", data = false })
    SetNuiFocus(false, false)
end

-- ============================================================
--  Test drive
-- ============================================================

function VehicleShop.endTestDrive(self)
    if self.testDriveTimer then self.testDriveTimer = nil end

    if not self.testDriveVehicle then return end
    if not DoesEntityExist(self.testDriveVehicle) then return end

    local ped = cache.ped
    if GetVehiclePedIsIn(ped, false) == self.testDriveVehicle then
        TaskLeaveVehicle(ped, self.testDriveVehicle, 0)
        Citizen.Wait(1500)
    end

    DeleteVehicle(self.testDriveVehicle)
    self.testDriveVehicle = nil

    if self.testDriveCoords then
        SetEntityCoords(ped, self.testDriveCoords.x, self.testDriveCoords.y,
            self.testDriveCoords.z, false, false, false, false)
        SetEntityHeading(ped, self.testDriveCoords.w)
        self.testDriveCoords = nil
    end

    local returnMsg = Config.VehicleShop.TestDrive.returnMessage
    if returnMsg then Bridge.Notify.showNotify(returnMsg, "inform") end
end

function VehicleShop.startTestDrive(self, model)
    if not Config.VehicleShop.TestDrive.enabled then
        return Bridge.Notify.showNotify(locale("vehicle_shop_test_drive_disabled"), "error")
    end

    if self.testDriveVehicle then self:endTestDrive() end

    local shopCfg = Config.DepartmentData.vehicleShops[self.currentShop]
    if not shopCfg then return end

    -- Save current player position to return to after the test drive
    local ped = cache.ped
    local coords = GetEntityCoords(ped)
    self.testDriveCoords = vec4(coords.x, coords.y, coords.z, GetEntityHeading(ped))

    self:close()

    local hash = lib.requestModel(model)
    if not hash then return end

    local spawnBase  = shopCfg.purchaseSpawn
    local offset     = Config.VehicleShop.TestDrive.spawnOffset
    local vehicle    = CreateVehicle(hash,
        spawnBase.x + offset.x, spawnBase.y + offset.y, spawnBase.z + offset.z,
        spawnBase.w, false, false)
    self.testDriveVehicle = vehicle

    SetEntityAsMissionEntity(vehicle, true, true)
    SetVehicleOnGroundProperly(vehicle)
    SetVehicleNumberPlateText(vehicle, "TESTDRV")
    SetModelAsNoLongerNeeded(hash)
    TaskWarpPedIntoVehicle(cache.ped, vehicle, -1)

    local durationSec = Config.VehicleShop.TestDrive.duration
    Bridge.Notify.showNotify(locale("vehicle_shop_test_drive_started", durationSec), "success")

    self.testDriveTimer = true
    Citizen.SetTimeout(durationSec * 1000, function()
        if self.testDriveTimer then self:endTestDrive() end
    end)
end

-- ============================================================
--  NUI callbacks
-- ============================================================

AddEventHandler("p_policejob:client:hideFrame", function(data)
    if data.name == "setVisibleVehicleShop" then
        VehicleShop:close()
    end
end)

RegisterNUICallback("vehicleShop:preview", function(data, cb)
    if VehicleShop.currentShop and data.model then
        local shopCfg = Config.DepartmentData.vehicleShops[VehicleShop.currentShop]
        if shopCfg then
            VehicleShop:spawnPreviewVehicle(data.model, shopCfg)
        end
    end
    cb("ok")
end)

RegisterNUICallback("vehicleShop:purchase", function(data, cb)
    if not VehicleShop.currentShop or not data.vehicle then
        cb({ success = false })
        return
    end
    TriggerServerEvent("p_policejob/vehicleshop/purchase", {
        shopName      = VehicleShop.currentShop,
        vehicleId     = data.vehicle.id,
        paymentMethod = data.paymentMethod or "bank",
    })
    cb({ success = true })
end)

RegisterNUICallback("vehicleShop:testDrive", function(data, cb)
    if data.model then VehicleShop:startTestDrive(data.model) end
    cb("ok")
end)

-- ============================================================
--  Net events
-- ============================================================

RegisterNetEvent("p_policejob/vehicleshop/purchaseSuccess", function(info)
    VehicleShop:close()
    Bridge.Notify.showNotify(locale("vehicle_shop_purchased", info.price), "success")
    Bridge.Notify.showNotify(locale("vehicle_shop_in_garage"), "inform")
end)

RegisterNetEvent("p_policejob/vehicleshop/purchaseFailed", function(reason)
    local msg = reason or locale("vehicle_shop_purchase_failed")
    Bridge.Notify.showNotify(msg, "error")
end)

RegisterNetEvent("p_policejob/vehicleshop/updateMoney", function(moneyData)
    SendNUIMessage({ action = "setPlayerMoney", data = moneyData })
end)

-- ============================================================
--  Startup: blips + salesperson NPCs + ox_target interactions
-- ============================================================

Citizen.CreateThread(function()
    Citizen.Wait(1000)

    local shops = Config.DepartmentData.vehicleShops or {}

    for shopName, shopCfg in pairs(shops) do
        -- Optional map blip
        if shopCfg.blip and shopCfg.blip.enabled then
            local b = shopCfg.blip
            local blip = AddBlipForCoord(b.coords.x, b.coords.y, b.coords.z)
            SetBlipSprite(blip, b.sprite)
            SetBlipColour(blip, b.color)
            SetBlipScale(blip, b.scale)
            SetBlipAsShortRange(blip, true)
            BeginTextCommandSetBlipName("STRING")
            AddTextComponentSubstringPlayerName(b.label)
            EndTextCommandSetBlipName(blip)
        end

        -- Proximity point that spawns/despawns the salesperson NPC
        local name = shopName
        local cfg  = shopCfg
        lib.points.new({
            coords   = vector3(cfg.ped.coords.x, cfg.ped.coords.y, cfg.ped.coords.z),
            distance = 50,
            onEnter  = function(point)
                point.ped = spawnSalesperson(cfg.ped)
                if point.ped then
                    Bridge.Target.addLocalEntity(point.ped, {{
                        name     = "vehicleshop_" .. name,
                        label    = locale("open_vehicle_shop"),
                        icon     = "fa-solid fa-car",
                        distance = 2.5,
                        groups   = Config.Jobs,
                        onSelect = function()
                            VehicleShop:open(name)
                        end,
                    }})
                end
            end,
            onExit   = function(point)
                if point.ped then
                    Bridge.Target.removeLocalEntity(point.ped, { "vehicleshop_" .. name })
                    DeleteEntity(point.ped)
                    point.ped = nil
                end
            end,
        })
    end
end)

-- ============================================================
--  Resource stop cleanup
-- ============================================================

AddEventHandler("onResourceStop", function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    VehicleShop:deletePreviewVehicle()
    VehicleShop:destroyCamera()
    VehicleShop:endTestDrive()
end)
