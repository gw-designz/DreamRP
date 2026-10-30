-- Wait for Config.Impound to be available
while not (Config and Config.Impound) do Citizen.Wait(500) end

if not Config.Impound.Enabled then return end

-- Global Impound object shared across the resource
Impound = {
    activePoints       = {},
    currentEntity      = nil,
    currentImpoundData = {},
}

local isCapturingPhoto = false

-- ─── Internal Helpers ─────────────────────────────────────────────────────────

-- Formats a total-seconds integer as "HH:MM:SS"
function FormatImpoundDuration(totalSeconds)
    local h = math.floor(totalSeconds / 3600)
    local m = math.floor((totalSeconds % 3600) / 60)
    local s = totalSeconds % 60
    return string.format("%02d:%02d:%02d", h, m, s)
end

-- Returns the display name label for the model of the given vehicle entity.
-- Falls back to the raw model name if the label text is "NULL" or empty.
function GetVehicleModelLabel(vehicleEntity)
    local modelName = GetDisplayNameFromVehicleModel(GetEntityModel(vehicleEntity))
    local label     = GetLabelText(modelName)
    return (label == "NULL" or label == "") and modelName or label
end

-- Checks if the vehicle is owned and handles the unowned case.
-- Returns true when the vehicle is confirmed owned (officer may proceed to impound).
function ValidateVehicleOwnership(vehicleEntity, plate)
    local netId = NetworkGetNetworkIdFromEntity(vehicleEntity)
    if not (netId and netId ~= 0) then
        Bridge.Notify.showNotify(locale("impound_vehicle_error"), "error")
        return false
    end

    local isOwned = lib.callback.await("p_policejob/server/impound/checkOwnedVehicle", false, plate, netId)

    if not isOwned then
        local unownedConfig = Config.Impound.UnownedVehicles
        if unownedConfig and unownedConfig.remove then
            RemoveUnownedVehicle(vehicleEntity, netId)
        else
            Bridge.Notify.showNotify(locale("impound_vehicle_not_owned"), "error")
        end
        return false
    end

    return true
end

-- Triggers the unowned-vehicle removal progress bar then fires the server event
function RemoveUnownedVehicle(vehicleEntity, netId)
    local unownedConfig = Config.Impound.UnownedVehicles

    local completed = Bridge.Progress.Start({
        duration     = unownedConfig.removeTime,
        label        = locale("impound_removing_vehicle"),
        useWhileDead = false,
        canCancel    = true,
        disable      = { move = false, car = true, combat = true },
    })

    if not completed then return end
    if not DoesEntityExist(vehicleEntity) then return end

    TriggerServerEvent("p_policejob/server/impound/removeUnownedVehicle", netId)
end

-- ─── Impound Menu ─────────────────────────────────────────────────────────────

-- Opens the impound NUI for the given vehicle entity
function OpenImpoundMenu(vehicleEntity)
    if not DoesEntityExist(vehicleEntity) then
        Bridge.Notify.showNotify(locale("impound_vehicle_error"), "error")
        return
    end

    local plate = GetVehicleNumberPlateText(vehicleEntity)
    if not ValidateVehicleOwnership(vehicleEntity, plate) then return end

    local modelLabel  = GetVehicleModelLabel(vehicleEntity)
    local officerName = Bridge.Framework.getPlayerName() or ""
    local photoConfig = Config.Impound.Photo or {}

    Impound.currentEntity = vehicleEntity
    Impound.currentImpoundData = {
        netId      = NetworkGetNetworkIdFromEntity(vehicleEntity),
        plate      = plate,
        model      = GetEntityModel(vehicleEntity),
        modelLabel = modelLabel,
        officer    = officerName,
    }

    SendNUIMessage({ action = "setImpoundLocations",  data = Config.Impound.Locations })
    SendNUIMessage({
        action = "setImpoundVehicleInfo",
        data   = {
            plate         = plate,
            model         = modelLabel,
            officer       = officerName,
            photoEnabled  = (photoConfig.enabled == true),
            photoRequired = (photoConfig.required == true),
            offences      = Config.Impound.Offences or {},
        },
    })
    SendNUIMessage({ action = "setVisibleImpound", data = true })
    SetNuiFocus(true, true)
end

exports("openImpoundMenu", OpenImpoundMenu)

-- ─── Impound Lot Viewer ────────────────────────────────────────────────────────

-- Fetches the impounded vehicle list for the given location and populates the NUI
function Impound:openImpoundLot(locationId)
    local vehicles = FetchImpoundedVehicles(locationId)

    if #vehicles == 0 then
        Bridge.Notify.showNotify(locale("impound_no_vehicles"), "error")
        return
    end

    SendNUIMessage({ action = "setImpoundedVehicles", data = vehicles })
    SendNUIMessage({ action = "setVisibleImpoundLot",  data = true })
    SetNuiFocus(true, true)
end

-- Fetches and formats the impounded vehicle list for a location from the server
function FetchImpoundedVehicles(locationId)
    local rows    = lib.callback.await("p_policejob/server/impound/getImpoundedVehicles", false, locationId) or {}
    local results = {}

    for _, row in pairs(rows) do
        local vehicleData = json.decode(row.vehicle)
        local modelName   = GetDisplayNameFromVehicleModel(vehicleData.model)
        local label       = GetLabelText(modelName)

        results[#results + 1] = {
            id       = row.plate,
            plate    = row.plate,
            name     = (label ~= "NULL" and label) or modelName,
            price    = row.price,
            reason   = row.reason,
            notes    = row.notes,
            photo    = row.photo,
            officer  = row.officer_name,
            timeLeft = row.timeLeft,
            location = locationId,
        }
    end

    return results
end

-- Pays out (retrieves) a vehicle from the impound lot and refreshes the list
function Impound:payoutVehicle(plate, locationId)
    local success = lib.callback.await("p_policejob/server/impound/payoutVehicle", false, {
        plate    = plate,
        location = locationId,
    })

    if success then
        local refreshed = FetchImpoundedVehicles(locationId)
        SendNUIMessage({ action = "setImpoundedVehicles", data = refreshed })
    end

    return success
end

-- ─── Proximity Points and Ped Spawning ────────────────────────────────────────

-- Creates a lib.points proximity zone for an impound location.
-- Spawns the attendant ped on enter and deletes it on exit.
function CreateImpoundPoint(locationId, locationData)
    local point = lib.points.new({
        coords   = locationData.coords,
        distance = 30,
    })

    point.onEnter = function(self)
        local modelHash = lib.requestModel(locationData.ped.model)
        if not modelHash then return end

        local ped = CreatePed(4, modelHash,
            locationData.coords.x, locationData.coords.y, locationData.coords.z - 1.0,
            locationData.coords.w or 0.0,
            false, true
        )

        FreezeEntityPosition(ped, true)
        SetEntityInvincible(ped, true)
        SetBlockingOfNonTemporaryEvents(ped, true)

        -- Animation or scenario
        local animConfig = locationData.anim
        if animConfig then
            if animConfig.dict then
                local dict = lib.requestAnimDict(animConfig.dict)
                if dict then
                    TaskPlayAnim(ped, dict, animConfig.name, 8.0, 8.0, -1, animConfig.flag or 1, 0, false, false, false)
                    RemoveAnimDict(dict)
                end
            elseif animConfig.scenario then
                TaskStartScenarioInPlace(ped, animConfig.scenario, 0, true)
            end
        end

        SetModelAsNoLongerNeeded(modelHash)

        if locationData.ped.onCreate then
            locationData.ped.onCreate(ped)
        end

        Bridge.Target.addLocalEntity(ped, {
            {
                name     = "p_policejob/impound/checkImpound_" .. locationId,
                label    = locale("check_impound"),
                icon     = "fa-solid fa-file",
                distance = 2.5,
                onSelect = function()
                    Impound:openImpoundLot(locationId)
                end,
            },
        })

        self.ped = ped
    end

    point.onExit = function(self)
        if self.ped and DoesEntityExist(self.ped) then
            DeleteEntity(self.ped)
            self.ped = nil
        end
    end

    return point
end

-- ─── Photo Capture ────────────────────────────────────────────────────────────

-- Launches the photo capture flow: exits NUI, shows a hint, waits for input,
-- then returns focus to the NUI with the photo result.
function CaptureImpoundPhoto()
    if isCapturingPhoto then return end
    if not (Config.Impound.Photo and Config.Impound.Photo.enabled) then
        SendNUIMessage({ action = "setImpoundPhoto", data = false })
        return
    end

    isCapturingPhoto = true
    SetNuiFocus(false, false)

    CreateThread(function()
        lib.showTextUI(locale("impound_photo_hint"), { position = "bottom-center" })

        local previousCamMode = GetFollowPedCamViewMode()
        SetFollowPedCamViewMode(4)

        local photoUrl = nil
        local done     = false

        while not done do
            Wait(0)

            -- Enter / F key → capture
            if IsControlJustPressed(0, 38) then
                lib.hideTextUI()
                Bridge.Notify.showNotify(locale("impound_photo_capturing"), "inform")
                photoUrl = PolicePhotoCapture()
                done     = true

            -- Backspace / ESC → cancel
            elseif IsControlJustPressed(0, 177) then
                done = true
            end
        end

        SetFollowPedCamViewMode(previousCamMode)
        lib.hideTextUI()
        SetNuiFocus(true, true)

        if photoUrl then
            Bridge.Notify.showNotify(locale("impound_photo_saved"), "success")
        end

        SendNUIMessage({ action = "setImpoundPhoto", data = photoUrl or false })
        isCapturingPhoto = false
    end)
end

-- ─── NUI Callbacks ────────────────────────────────────────────────────────────

RegisterNUICallback("impound/close", function(_, cb)
    SetNuiFocus(false, false)
    SendNUIMessage({ action = "setVisibleImpound",    data = false })
    SendNUIMessage({ action = "setVisibleImpoundLot", data = false })
    cb("ok")
end)

RegisterNUICallback("impound/submitForm", function(payload, cb)
    if not (Impound.currentEntity and DoesEntityExist(Impound.currentEntity)) then
        return cb(false)
    end

    TriggerServerEvent("p_policejob/server/impound/startImpound", {
        netId    = Impound.currentImpoundData.netId,
        price    = payload.price or 0,
        reason   = payload.reason,
        notes    = payload.notes,
        photo    = payload.photo,
        releaseAt = payload.releaseAt,
        time     = payload.time or 1,
        location = payload.location,
        model    = payload.model or Impound.currentImpoundData.modelLabel,
    })

    SetNuiFocus(false, false)
    SendNUIMessage({ action = "setVisibleImpound", data = false })
    Impound.currentEntity      = nil
    Impound.currentImpoundData = {}
    cb(true)
end)

RegisterNUICallback("impound/capturePhoto", function(_, cb)
    cb("ok")
    CaptureImpoundPhoto()
end)

RegisterNUICallback("impound/payoutVehicle", function(payload, cb)
    local success = Impound:payoutVehicle(payload.plate, payload.location)
    cb(success or false)
end)

-- ─── Init Thread ─────────────────────────────────────────────────────────────

Citizen.CreateThread(function()
    -- Register a target option on all vehicles (impound from outside)
    Bridge.Target.addVehicle({
        {
            name     = "p_policejob/impound/startImpound",
            label    = locale("impound_vehicle"),
            icon     = "fa-solid fa-car",
            distance = 2.0,
            groups   = Config.Jobs,
            onSelect = function(targetData)
                -- Check if a garage export should handle this instead
                if Config.Impound.UseGarageExport then
                    if GetResourceState("qs-advancedgarages") == "started" then
                        exports["qs-advancedgarages"]:ImpoundVehicle()
                        return
                    elseif GetResourceState("jg-advancedgarages") == "started" then
                        TriggerEvent("jg-advancedgarages:client:show-impound-form")
                        return
                    elseif GetResourceState("cd_garage") == "started" then
                        ExecuteCommand("impound")
                        return
                    elseif GetResourceState("okokGarage") == "started" then
                        TriggerEvent("okokGarage:openPoliceImpound")
                        return
                    elseif GetResourceState("mt_garages") == "started" then
                        exports.mt_garages:openImpound()
                        return
                    end
                end

                -- Native impound menu
                local entity = (type(targetData) == "number") and targetData or targetData.entity
                OpenImpoundMenu(entity)
            end,
        },
    })

    -- Create proximity points for each impound location
    for locationId, locationData in pairs(Config.Impound.Locations) do
        Impound.activePoints[locationId] = CreateImpoundPoint(locationId, locationData)
    end
end)
