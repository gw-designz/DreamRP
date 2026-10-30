while true do
    if Config and Config.Creator then break end
    Citizen.Wait(1000)
end

if not Config.Creator.enabled then return end

-- File-local state
local activePanel   = nil   -- which panel is open: "DepartmentCreator" | "PrisonCreator" | nil
local isPlacing     = false -- true while the coord-picker loop is running
local placeCooldown = 0     -- GetGameTimer() timestamp; prevents re-entry spam

-- Map panel name → NUI action suffix
local PANEL_MAP = {
    DepartmentCreator = "departments",
    PrisonCreator     = "prisons",
}

-- ============================================================
--  Helpers
-- ============================================================

local function round4(n)
    return math.floor(n * 10000 + 0.5) / 10000
end

-- Cast a ray from the camera and return the hit world position, or nil
local function getAimCoords()
    local hit, _, coords = lib.raycast.fromCamera(17, 4, 100.0)
    return hit and coords or nil
end

-- Open a creator panel after verifying server-side access
local function openPanel(panelName)
    if activePanel then return end

    local allowed = lib.callback.await("p_policejob/server/creator/canAccess", false)
    if not allowed then
        return Bridge.Notify.showNotify(locale("no_access"), "error")
    end

    activePanel = panelName
    SetNuiFocus(true, true)
    SendNUIMessage({ action = "setVisible" .. panelName, data = true })
end

-- ============================================================
--  Commands
-- ============================================================

RegisterCommand(Config.Creator.commands.department, function()
    openPanel("DepartmentCreator")
end, false)

RegisterCommand(Config.Creator.commands.prison, function()
    openPanel("PrisonCreator")
end, false)

-- ============================================================
--  Coord picker (runs synchronously inside a CreateThread)
-- ============================================================

-- fields:  array of "x","y","z","h" indicating which coords to capture
-- panel:   panel name to return to when done
local function runCoordPicker(fields, panel)
    if isPlacing then return end
    if GetGameTimer() < placeCooldown then return end

    isPlacing = true

    local hasHeading = false
    for _, f in ipairs(fields) do
        if f == "h" then hasHeading = true; break end
    end

    -- Close the panel, show the placement UI
    SetNuiFocus(false, false)
    SendNUIMessage({ action = "setVisible" .. panel, data = false })
    SendNUIMessage({ action = "creatorPlacement", data = {
        visible    = true,
        hasHeading = hasHeading,
        mode       = hasHeading and "ped" or "marker",
    }})

    local pedCoords  = GetEntityCoords(cache.ped)
    local previewPed = nil
    local heading    = 0.0
    local hitCoords  = pedCoords
    local confirmed  = false
    local inputReady = false  -- waits for button release before accepting press

    -- Spawn a semi-transparent preview ped when heading is needed
    if hasHeading then
        local model = lib.requestModel(Config.Creator.previewPed)
        previewPed = CreatePed(26, model, pedCoords.x, pedCoords.y, pedCoords.z, 0.0, false, false)
        SetModelAsNoLongerNeeded(model)
        SetEntityAlpha(previewPed, 200, false)
        SetEntityCollision(previewPed, false, false)
        SetEntityInvincible(previewPed, true)
        FreezeEntityPosition(previewPed, true)
        SetBlockingOfNonTemporaryEvents(previewPed, true)
    end

    -- Marker draw thread
    CreateThread(function()
        while isPlacing do
            Wait(0)
            local color = hasHeading
                and { r = 0,   g = 150, b = 255, a = 150 }
                or  { r = 255, g = 0,   b = 0,   a = 150 }
            DrawMarker(28,
                hitCoords.x, hitCoords.y, hitCoords.z - (hasHeading and 0.98 or 0),
                0, 0, 0, 0, 0, 0,
                0.4, 0.4, 0.4,
                color.r, color.g, color.b, color.a,
                false, false, false, false)
        end
    end)

    -- Main picker loop
    while isPlacing do
        Wait(0)

        local aim = getAimCoords()
        if aim then
            hitCoords = aim
            if previewPed then
                SetEntityCoords(previewPed, aim.x, aim.y, aim.z, false, false, false, false)
            end
        end

        if hasHeading then
            if IsControlPressed(0, 174) then heading = (heading + 1.0)   % 360.0 end  -- Right arrow: +1°
            if IsControlPressed(0, 175) then heading = (heading - 1.0 + 360.0) % 360.0 end  -- Left arrow: -1°
            if IsControlPressed(0, 27)  then heading = (heading + 0.1)   % 360.0 end  -- W: +0.1°
            if IsControlPressed(0, 173) then heading = (heading - 0.1 + 360.0) % 360.0 end  -- S: -0.1°
            if previewPed then SetEntityHeading(previewPed, heading) end
        end

        -- Wait for buttons to be released before accepting a confirm/cancel
        if not inputReady then
            local held = IsControlPressed(0, 191) or IsControlPressed(0, 194)
            if not held then inputReady = true end
        else
            if IsControlJustPressed(0, 191) then  -- Enter / Accept → confirm
                confirmed  = true
                isPlacing  = false
            elseif IsControlJustPressed(0, 194) then  -- Backspace / Cancel → cancel
                confirmed  = false
                isPlacing  = false
            end
        end
    end

    -- Clean up preview ped
    if previewPed and DoesEntityExist(previewPed) then
        DeleteEntity(previewPed)
    end

    SendNUIMessage({ action = "creatorPlacement", data = { visible = false } })
    Wait(350)

    -- Re-open the panel
    SendNUIMessage({ action = "setVisible" .. panel, data = true })
    SetNuiFocus(true, true)
    placeCooldown = GetGameTimer() + 1000

    if confirmed then
        -- Build the result array in field order
        local values = {}
        for _, f in ipairs(fields) do
            if     f == "x" then values[#values + 1] = round4(hitCoords.x)
            elseif f == "y" then values[#values + 1] = round4(hitCoords.y)
            elseif f == "z" then values[#values + 1] = round4(hitCoords.z + 1.0)
            elseif f == "h" then values[#values + 1] = round4(heading)
            end
        end
        SendNUIMessage({ action = "creatorCoordsResult", data = { values = values } })
    end
end

-- ============================================================
--  NUI callbacks
-- ============================================================

RegisterNUICallback("creatorGetCoords", function(data, cb)
    cb(json.encode({ ok = true }))

    local panel  = data.panel or "DepartmentCreator"
    local fields = data.fields or { "x", "y", "z" }

    CreateThread(function()
        runCoordPicker(fields, panel)
    end)
end)

RegisterNUICallback("creatorListMaps", function(data, cb)
    cb(json.encode({ ok = true }))

    local panelName = (data and data.panel) or ""
    local mapType   = PANEL_MAP[panelName]
    if not mapType then return end

    TriggerServerEvent("p_policejob/server/creator/getFiles", mapType)
end)

RegisterNUICallback("creatorLoadMap", function(data, cb)
    cb(json.encode({ ok = true }))

    local panelName = (data and data.panel) or ""
    local mapType   = PANEL_MAP[panelName]
    if not mapType then return end
    if type(data.fileName) ~= "string" then return end

    TriggerServerEvent("p_policejob/server/creator/loadFile", mapType, data.fileName)
end)

RegisterNUICallback("creatorCopyCode", function(data, cb)
    -- Acknowledge the callback immediately so the NUI side doesn't time out
    cb("ok")
    if not (data and data.content) then return end

    -- Small defer so the cb response clears before the clipboard write
    Wait(50)
    lib.setClipboard(data.content)
    Bridge.Notify.showNotify(locale("creator_copied") or "Copied to clipboard", "success")

    -- If the UI provided a fileName and mapType, also persist the file to disk.
    -- The JS sends { content, fileName, mapType } from the Preview → Copy flow.
    if data.fileName and data.mapType then
        TriggerServerEvent(
            "p_policejob/server/creator/saveFile",
            data.mapType, data.fileName, data.content
        )
    end
end)

-- ============================================================
--  Net events (server → client)
-- ============================================================

RegisterNetEvent("p_policejob/client/creator/fileList", function(mapType, fileList)
    local panelName = (mapType == "prisons") and "PrisonCreator" or "DepartmentCreator"
    SendNUIMessage({ action = "creatorMapFiles", data = {
        panel = panelName,
        files = fileList or {},
    }})
end)

RegisterNetEvent("p_policejob/client/creator/loadedMap", function(mapType, fileName, mapData)
    if type(mapData) ~= "table" then return end

    local panelName = (mapType == "prisons") and "PrisonCreator" or "DepartmentCreator"
    SendNUIMessage({ action = "creatorMapLoaded", data = {
        panel    = panelName,
        fileName = fileName,
        map      = mapData,
    }})
    Bridge.Notify.showNotify(locale("creator_map_loaded"), "success")
end)

-- ============================================================
--  Global events
-- ============================================================

AddEventHandler("p_policejob:client:hideFrame", function(data)
    if not data or not data.name then return end
    local name = data.name
    if not name:find("DepartmentCreator") and not name:find("PrisonCreator") then return end

    if isPlacing then return end

    activePanel = nil
    SetNuiFocus(false, false)
end)

AddEventHandler("onResourceStop", function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    isPlacing = false
    if activePanel then
        SetNuiFocus(false, false)
        activePanel = nil
    end
end)
