-- Shared NUI response builder used by all callbacks in this file.
local function nuiResponse(success, data, message)
    return { success = success, data = data, message = message }
end

-- Tracks whether a character-creation request is currently in flight.
-- Guards against duplicate CREATE_CHARACTER calls from a double-click.
local createInProgress = false

local function clearCreateInProgress()
    createInProgress = false
end

-- UI_BOOTED: fired by the NUI page once its JS bundle has initialised.
RegisterNUICallback("UI_BOOTED", function(data, cb)
    Main.uiBooted = true
    Trace(("[Main] NUI booted at %d"):format(GetGameTimer()))
    cb(nuiResponse(true, {}, "OK"))
end)

-- PANEL_SHOWN: fired when the character-detail side-panel has finished rendering.
RegisterNUICallback("PANEL_SHOWN", function(data, cb)
    Trace(("[Main] character detail panel rendered at %d"):format(GetGameTimer()))
    cb(nuiResponse(true, {}, "OK"))
end)

-- NUI_JAM: fired by the JS watchdog when the NUI thread was blocked.
-- Logged server-side for diagnostics; no game-state change required.
RegisterNUICallback("NUI_JAM", function(data, cb)
    local duration    = (data and data.duration)    or 0
    local attribution = (data and data.attribution) or ""
    local suffix      = (attribution ~= "") and (" by " .. attribution) or ""
    Trace(("[Main] NUI thread was BLOCKED for %dms%s"):format(duration, suffix))
    cb(nuiResponse(true, {}, "OK"))
end)

-- CLOSE_UI: player dismissed the multichar screen (e.g. pressed Escape).
RegisterNUICallback("CLOSE_UI", function(data, cb)
    Main:Destroy()
    cb(nuiResponse(true, {}, "OK"))
end)

-- UNSELECT_CHARACTER: player clicked away from a selected character card.
RegisterNUICallback("UNSELECT_CHARACTER", function(data, cb)
    Main:unSelectCharacter()
    cb(nuiResponse(true, {}, "OK"))
end)

-- FOCUS_SLOT: keyboard arrows moved the highlight to another slot (1-based).
RegisterNUICallback("FOCUS_SLOT", function(data, cb)
    local slot = data and tonumber(data.slot)
    if slot and Main.characters[slot] then
        Main.focusedSlot = slot
    end
    cb(nuiResponse(true, {}, "OK"))
end)

-- PICK_SLOT: Enter / on-screen "Select" button on the focused slot.
-- Ignored unless the ped-selection view is live, so it can't double-fire.
RegisterNUICallback("PICK_SLOT", function(data, cb)
    local slot = data and tonumber(data.slot)
    local char = slot and Main.characters[slot]
    if char and Main.selectingCharacter and not Main.raycastBlocked then
        Main.focusedSlot = slot
        CreateThread(function() Main:onPedClicked(char) end)
    end
    cb(nuiResponse(true, {}, "OK"))
end)

-- PREVIEW_BODY: body-type step of character creation. Respawns the empty
-- slot's showcase ped as the male/female freemode model so the player sees it.
RegisterNUICallback("PREVIEW_BODY", function(data, cb)
    local slot = Main.focusedSlot
    local char = slot and Main.characters[slot]
    local sex  = (data and data.gender == "Female") and 1 or 0

    if char and not char.identifier and not char._locked and char.sex ~= sex then
        char.sex = sex
        CreateThread(function()
            local oldPed = char.pedHandle
            Main:spawnPedForSlot(slot)
            if oldPed and oldPed ~= char.pedHandle and DoesEntityExist(oldPed) then
                for i, ped in ipairs(Main.peds) do
                    if ped == oldPed then
                        table.remove(Main.peds, i)
                        break
                    end
                end
                DeleteEntity(oldPed)
            end
        end)
    end

    cb(nuiResponse(true, {}, "OK"))
end)

-- UPDATE_IDENTITY: "Edit identity" on the detail panel. The server re-validates
-- and checks ownership; on success the cached record and NUI list are refreshed.
RegisterNUICallback("UPDATE_IDENTITY", function(data, cb)
    local ok = lib.callback.await("bablo-multicharacter:updateIdentity", false, data) == true
    local updated
    if ok then
        for _, char in ipairs(Main.characters) do
            if char.identifier and char.identifier == data.id then
                char.firstname = data.firstName
                char.lastname  = data.lastName
                char.dob       = data.dob
                updated        = Main:exportCharacter(char)
                break
            end
        end
        SendNUIMessage({ action = "SET_CHARACTERS", data = Main:exportCharacters() })
        if Main.pedLabelsDui then Main.pedLabelsDui:SetSlots(Main:buildDuiSlots()) end
    end
    cb(nuiResponse(ok, updated or {}, ok and "OK" or "failed"))
end)

-- OPEN_GAME_SETTINGS: show GTA's own settings menu over the selector, then
-- hand focus back to the NUI once the player closes it.
RegisterNUICallback("OPEN_GAME_SETTINGS", function(data, cb)
    cb(nuiResponse(true, {}, "OK"))
    SetNuiFocus(false, false)
    ActivateFrontendMenu(GetHashKey("FE_MENU_VERSION_LANDING_MENU"), false, -1)
    CreateThread(function()
        Wait(500)
        while IsPauseMenuActive() do Wait(100) end
        if Main.isOpen then
            SetNuiFocus(true, true)
            SetNuiFocusKeepInput(true)
        end
        SendNUIMessage({ action = "GAME_SETTINGS_CLOSED" })
    end)
end)

-- PLAY_SOUND: UI feedback through GTA's native frontend sounds (same set the
-- pause menu uses). Only whitelisted names are played.
local FRONTEND_SOUNDS = {
    move   = "NAV_UP_DOWN",
    side   = "NAV_LEFT_RIGHT",
    select = "SELECT",
    back   = "BACK",
    error  = "ERROR",
}

RegisterNUICallback("PLAY_SOUND", function(data, cb)
    local name = FRONTEND_SOUNDS[data and data.kind]
    if name then
        PlaySoundFrontend(-1, name, "HUD_FRONTEND_DEFAULT_SOUNDSET", true)
    end
    cb(nuiResponse(true, {}, "OK"))
end)

-- GET_SPAWN_POSITIONS: NUI requests the list of available spawn locations for the spawn menu.
RegisterNUICallback("GET_SPAWN_POSITIONS", function(data, cb)
    cb(nuiResponse(true, Main:exportSpawnPositions(), "OK"))
end)

-- SELECT_CHARACTER: player pressed "Play" on a character card.
-- Resolves the correct spawn strategy (home interior / custom event / world point)
-- then calls Framework.LoadCharacter before spawning.
RegisterNUICallback("SELECT_CHARACTER", function(data, cb)
    local spawnData  = data and data.spawn
    local spawnCoords = spawnData and spawnData.coords
    local houseEntry  = spawnData and spawnData.house
    local charId      = data and data.id

    -- Custom spawn is active when the config enables it AND the spawn menu is disabled.
    local useCustomSpawn = Config.CustomSpawn
        and Config.CustomSpawn.enabled
        and (Config.EnableSpawnMenu == false)

    local function doSpawn()
        if houseEntry and houseEntry.name then
            Main:spawnAtHome(houseEntry)
        elseif useCustomSpawn then
            Main:spawnCustom(charId)
        else
            Main:spawnAtPoint(spawnCoords)
        end
    end

    if charId then
        Framework:LoadCharacter(charId, function(success)
            if success then
                doSpawn()
            else
                Trace(("[NUI] LoadCharacter failed for id=%s"):format(tostring(charId)))
            end
        end)
    end

    cb(nuiResponse(true, {}, "OK"))
end)

-- CREATE_CHARACTER: player submitted the character-creation form.
-- Guarded by createInProgress to prevent duplicate submissions.
RegisterNUICallback("CREATE_CHARACTER", function(data, cb)
    if createInProgress then
        cb(nuiResponse(false, {}, "in progress"))
        return
    end

    -- Check that at least one free (non-locked, empty) slot exists.
    local hasFreeSlot = false
    for _, char in ipairs(Main.characters or {}) do
        if not char.identifier and not char._locked then
            hasFreeSlot = true
            break
        end
    end

    if not hasFreeSlot then
        Trace("[NUI] CreateCharacter blocked — no free (non-locked) slot available")
        cb(nuiResponse(false, {}, "no_free_slot"))
        return
    end

    createInProgress = true

    if data then
        Framework:CreateCharacter(data, function(success, charData)
            if success then
                Main:submitCreate(data, charData)
            else
                Trace("[NUI] CreateCharacter failed")
                Main:cancelCreate()
                createInProgress = false
            end
        end)
    else
        Main:cancelCreate()
        createInProgress = false
    end

    cb(nuiResponse(true, {}, "OK"))
end)

-- CANCEL_CREATE_CHARACTER: player backed out of the creation form.
RegisterNUICallback("CANCEL_CREATE_CHARACTER", function(data, cb)
    Main:cancelCreate()
    cb(nuiResponse(true, {}, "OK"))
end)

-- SWITCH_CHARACTER: player chose a different character while already logged in.
RegisterNUICallback("SWITCH_CHARACTER", function(data, cb)
    if data and data.id then
        Main:switchToCharacter(data.id)
    end
    cb(nuiResponse(true, {}, "OK"))
end)

-- DELETE_CHARACTER: player confirmed character deletion.
RegisterNUICallback("DELETE_CHARACTER", function(data, cb)
    if Config.AllowCharacterDeletion == false then
        cb(nuiResponse(false, {}, "deletion_disabled"))
        return
    end

    local charId = data and data.id
    if charId then
        Framework:DeleteCharacter(charId, function(success)
            if success then
                Main:refreshCast(charId)
            else
                Trace(("[NUI] DeleteCharacter failed — id=%s"):format(tostring(charId)))
            end
        end)
    end

    cb(nuiResponse(true, {}, "OK"))
end)

-- SELECT_SPAWN: player picked a spawn point from the spawn-selection menu.
RegisterNUICallback("SELECT_SPAWN", function(data, cb)
    local coords = data and data.coords
    Main:spawnAtPoint(coords)
    cb(nuiResponse(true, {}, "OK"))
end)

-- Clear createInProgress when the UI is torn down (resource stop or explicit close).
AddEventHandler("onResourceStop", function(resourceName)
    if resourceName == GetCurrentResourceName() then
        clearCreateInProgress()
    end
end)

AddEventHandler(eventName .. "client:closeUI",           clearCreateInProgress)
AddEventHandler(eventName .. "client:multicharDestroyed", clearCreateInProgress)
