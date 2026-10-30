if Config.Framework ~= "qbox" then return end

-- qbox can run on top of qbx_core (native) or qb-core (legacy shim).
-- We grab the QBCore object only when the legacy qb-core resource is present;
-- qbx_core interactions are done via exports.qbx_core directly.
local QBCore = nil

CreateThread(function()
    -- Wait for either core to start.
    while GetResourceState("qbx_core") ~= "started"
      and GetResourceState("qb-core")  ~= "started" do
        Wait(50)
    end

    -- Only grab the legacy shared object when qb-core is the active resource.
    if GetResourceState("qb-core") == "started" then
        QBCore = exports["qb-core"]:GetCoreObject()
    end

    Trace("[Framework/qbox] Client initialised")
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
-- qbox still uses the QBCore event names for compatibility.
function Framework:NotifyPlayerLoaded()
    TriggerServerEvent("QBCore:Server:OnPlayerLoaded")
    TriggerEvent("QBCore:Client:OnPlayerLoaded")
end
