if Config.Framework ~= "qbcore" then return end

-- QBCore shared object; populated once qb-core is started.
local QBCore = nil

CreateThread(function()
    while GetResourceState("qb-core") ~= "started" do
        Wait(50)
    end
    QBCore = exports["qb-core"]:GetCoreObject()
    Trace("[Framework/QBCore] Client initialised")
end)

-- ─── Framework method implementations (client-side) ──────────────────────────

function Framework:GetCharacters(callback)
    lib.callback("bablo-multicharacter:fetchCharacters", false, function(result)
        callback(result or {})
    end)
end

function Framework:GetCharactersSync()
    return lib.callback.await("bablo-multicharacter:fetchCharacters", false) or {}
end

function Framework:LoadCharacter(identifier, callback)
    lib.callback("bablo-multicharacter:loadCharacter", false, function(result)
        if callback then callback(result == true) end
    end, identifier)
end

function Framework:LoadCharacterSync(identifier)
    return lib.callback.await("bablo-multicharacter:loadCharacter", false, identifier) == true
end

function Framework:CreateCharacter(formData, callback)
    lib.callback("bablo-multicharacter:createCharacter", false, function(ok, charRecord)
        if callback then callback(ok == true, charRecord) end
    end, formData)
end

function Framework:CreateCharacterSync(formData)
    local ok, charRecord = lib.callback.await("bablo-multicharacter:createCharacter", false, formData)
    return ok == true, charRecord
end

function Framework:DeleteCharacter(identifier, callback)
    lib.callback("bablo-multicharacter:deleteCharacter", false, function(result)
        if callback then callback(result == true) end
    end, identifier)
end

-- NotifyPlayerLoaded: fire QBCore's server and client spawn events.
function Framework:NotifyPlayerLoaded()
    TriggerServerEvent("QBCore:Server:OnPlayerLoaded")
    TriggerEvent("QBCore:Client:OnPlayerLoaded")
end
