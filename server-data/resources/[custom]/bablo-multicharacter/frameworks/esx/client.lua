if Config.Framework ~= "esx" then return end

-- ESX shared object; populated asynchronously once es_extended is started.
local ESX = nil

-- Wait for es_extended to start, then grab the shared object.
CreateThread(function()
    while GetResourceState("es_extended") ~= "started" do
        Wait(50)
    end

    local ok, obj = pcall(function() return exports.es_extended:getSharedObject() end)
    ESX = (ok and obj) or _G.ESX

    Trace(("[Framework/ESX] Client initialised — ESX=%s"):format(ESX and "OK" or "NIL"))
end)

-- ─── Framework method implementations (client-side) ──────────────────────────

-- GetCharacters: fire-and-forget, delivers results via callback.
function Framework:GetCharacters(callback)
    lib.callback("bablo-multicharacter:fetchCharacters", false, function(result)
        callback(result or {})
    end)
end

-- GetCharactersSync: blocking await variant.
function Framework:GetCharactersSync()
    return lib.callback.await("bablo-multicharacter:fetchCharacters", false) or {}
end

-- LoadCharacter: fire-and-forget, delivers success flag via callback.
function Framework:LoadCharacter(identifier, callback)
    lib.callback("bablo-multicharacter:loadCharacter", false, function(result)
        if callback then callback(result == true) end
    end, identifier)
end

-- LoadCharacterSync: blocking await variant.
function Framework:LoadCharacterSync(identifier)
    return lib.callback.await("bablo-multicharacter:loadCharacter", false, identifier) == true
end

-- CreateCharacter: fire-and-forget; callback receives (success, charRecord).
function Framework:CreateCharacter(formData, callback)
    lib.callback("bablo-multicharacter:createCharacter", false, function(ok, charRecord)
        if callback then callback(ok == true, charRecord) end
    end, formData)
end

-- CreateCharacterSync: blocking await variant.
function Framework:CreateCharacterSync(formData)
    local ok, charRecord = lib.callback.await("bablo-multicharacter:createCharacter", false, formData)
    return ok == true, charRecord
end

-- DeleteCharacter: fire-and-forget; callback receives success flag.
function Framework:DeleteCharacter(identifier, callback)
    lib.callback("bablo-multicharacter:deleteCharacter", false, function(result)
        if callback then callback(result == true) end
    end, identifier)
end

-- NotifyPlayerLoaded: fires the ESX spawn events.
-- For skinchanger / codem-appearance: also loads the saved skin and corrects the
-- player model to match the skin's gender before firing the spawn events.
function Framework:NotifyPlayerLoaded()
    local appearance = Config.Appearance
    if appearance == "skinchanger" or appearance == "codem-appearance" then
        local skin = lib.callback.await("bablo-multicharacter:fetchActiveSkin", false)
        if skin then
            -- Ensure the player ped model matches the skin's sex.
            local targetModel = (skin.sex == 1) and -1667301416 or 1885233650
            if GetEntityModel(PlayerPedId()) ~= targetModel then
                RequestModel(targetModel)
                local deadline = GetGameTimer() + 5000
                while not HasModelLoaded(targetModel) and GetGameTimer() < deadline do
                    Wait(0)
                end
                if HasModelLoaded(targetModel) then
                    SetPlayerModel(PlayerId(), targetModel)
                    SetPedDefaultComponentVariation(PlayerPedId())
                    SetModelAsNoLongerNeeded(targetModel)
                end
            end
            TriggerEvent("skinchanger:loadSkin", skin)
        end
    end

    TriggerServerEvent("esx:onPlayerSpawn")
    TriggerEvent("esx:onPlayerSpawn")
    TriggerEvent("esx:restoreLoadout")
    Trace("[Framework/ESX] NotifyPlayerLoaded — fired esx:onPlayerSpawn + restoreLoadout")
end
