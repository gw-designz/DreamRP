local scenesLoaded = false
local items = {}

local playerLastTimeMinigame = {} ---@type table<string, table<number, number>>

local function round(x, n)
    n = math.pow(10, n or 0)
    x = x * n
    if x >= 0 then x = math.floor(x + 0.5) else x = math.ceil(x - 0.5) end
    return x / n
end

function Logger(src, category, text, data)
    local title = ("Staff Events Player %s (%s)"):format(GetPlayerName(src), src)
    bridge.log.send(LogWebhookUrl, title, text, data)
end

CreateThread(function()
    Wait(500)
    while not DB_READY do
        Wait(100)
    end
    Wait(50)

    local staffEventObjectsRows = DB:query_async("select * from staff_event_objects", {})
    local staffEventObjects = {}
    for i=1, #staffEventObjectsRows do
        local coords = json.decode(staffEventObjectsRows[i].coords)
        local rotation = json.decode(staffEventObjectsRows[i].rotation)

        if not staffEventObjects[staffEventObjectsRows[i].sceneId] then
            staffEventObjects[staffEventObjectsRows[i].sceneId] = {}
        end

        staffEventObjects[staffEventObjectsRows[i].sceneId][staffEventObjectsRows[i].id] = {
            id = staffEventObjectsRows[i].id,
            model = staffEventObjectsRows[i].model,
            coords = vector3(coords.x, coords.y, coords.z),
            rotation = vector3(rotation.x, rotation.y, rotation.z),
            enabled = staffEventObjectsRows[i].enabled,
            type = staffEventObjectsRows[i].type,
            settings = json.decode(staffEventObjectsRows[i].settings or "{}") or {},
        }
    end

    local staffEvents = DB:query_async("select * from staff_events", {})

    for i=1, #staffEvents do
        NewEventScene({
            id = staffEvents[i].id,
            name = staffEvents[i].name,
            enabled = staffEvents[i].enabled,
            objects = staffEventObjects[staffEvents[i].id] or {},
            boundingBoxMargin = staffEvents[i].boundingBoxMargin or 1.0,
            createdBy = staffEvents[i].createdBy or -1,
            createdAt = staffEvents[i].createdAt or 0,
            lastUpdatedAt = staffEvents[i].lastUpdatedAt or 0,
        })
    end
end)

CreateThread(function()
    Wait(3000)

    local invItems = bridge.inv.getRegisteredItems()
    for itemName, item in pairs(invItems) do
        items[#items+1] = {
            name = itemName,
            label = item.label,
        }
    end

    local stashesRows = DB:query_async("select * from staff_event_stashes", {})
    for i=1, #stashesRows do
        NewEventStash({
            id = stashesRows[i].id,
            name = stashesRows[i].name,
            items = json.decode(stashesRows[i].items) or {},
        })
    end

    scenesLoaded = true
end)

lib.callback.register("prp-staffevents:getItems", function(src)
    while not items or #items == 0 do Wait(100) end
    return items
end)

---@param src string | number
---@param name string
---@param enabledByDefault boolean?
---@return { success: boolean, error?: string, scene?: ServerEventScene }
function CreateEventScene(src, name, enabledByDefault)
    if not name or name == "" then
        return {
            success = false,
            error = "Name cannot be nil or empty",
        }
    end

    if string.len(name) > 250 then
        return {
            success = false,
            error = "Name cannot be nil or empty or longer than 250 characters",
        }
    end

    local stateId = bridge.fw.getIdentifier(src)

    local id = DB:insert_async("insert into staff_events (name, createdBy) values (?, ?)", { name, stateId })

    if not id or id < 1 then
        return {
            success = false,
            error = "Failed to create event scene",
        }
    end

    local enabled = true
    if enabledByDefault ~= nil then
        enabled = enabledByDefault
    end

    local scene = NewEventScene({
        id = id,
        name = name,
        enabled = enabled,
        createdBy = stateId,
        createdAt = os.time() * 1000,
        lastUpdatedAt = os.time() * 1000,
    })

    if not scene then
        return {
            success = false,
            error = "Failed to create event scene",
        }
    end

    SetTimeout(0, function()
        TriggerClientEvent("prp-staffevents:createdScene", -1, scene)
    end)

    return { success = true, scene = scene }
end

RegisterBPSCallback("prp-staffevents:getEventScenes", function(src)
    while not scenesLoaded do Wait(100) end
    return ServerEventScenes
end)

lib.callback.register("prp-staffevents:getEventSceneObjects", function(src, sceneId)
    while not scenesLoaded do Wait(100) end
    local scene = GetEventScene(sceneId)
    if not scene then return nil end
    return scene.objects
end)

lib.callback.register("prp-staffevents:createEventScene", function(src, name)
    local stateId = bridge.fw.getIdentifier(src)
    if not EventPermission:HasPermission(stateId, "edit_scene") then
        return { success = false, error = locale("NO_PERM_CREATE_SCENE") }
    end

    Logger(src, "EventScene", "Created event scene", {
        eventScene = name,
    })

    return CreateEventScene(src, name)
end)

lib.callback.register("prp-staffevents:canEditScene", function(src, sceneId)
    local stateId = bridge.fw.getIdentifier(src)
    if not EventPermission:HasPermission(stateId, "edit_scene") then
        return false
    end

    ---@diagnostic disable-next-line: assign-type-mismatch
    local scene = GetEventScene(sceneId) ---@type ServerEventScene
    if not scene then return false end

    scene:AddEditor(src)
    return true
end)

lib.callback.register("prp-staffevents:sceneAddObject", function(src, sceneId, obj)
    local stateId = bridge.fw.getIdentifier(src)
    if not EventPermission:HasPermission(stateId, "edit_scene") then
        return { success = false, error = locale("NO_PERM_ADD_OBJECT") }
    end

    ---@diagnostic disable-next-line: assign-type-mismatch
    local scene = GetEventScene(sceneId) ---@type ServerEventScene
    if not scene then return { success = false, error = locale("SCENE_DOES_NOT_EXIST") } end
    if not scene:IsEditor(src) then return { success = false, error = locale("YOU_ARE_NOT_EDITOR")} end

    local resp = scene:AddObject(obj)

    Logger(src, "EventScene", "Added object to event scene", {
        eventScene = scene.name,
        objectModel = obj.model,
        objectType = obj.type,
        objectId = resp.objectId,
    })

    return resp
end)

lib.callback.register("prp-staffevents:sceneRemoveObject", function(src, sceneId, objId)
    local stateId = bridge.fw.getIdentifier(src)
    if not EventPermission:HasPermission(stateId, "edit_scene") then
        return { success = false, error = locale("NO_PERM_REMOVE_OBJECT") }
    end

    ---@diagnostic disable-next-line: assign-type-mismatch
    local scene = GetEventScene(sceneId) ---@type ServerEventScene
    if not scene then return { success = false, error = locale("SCENE_DOES_NOT_EXIST") } end
    if not scene:IsEditor(src) then return { success = false, error = locale("YOU_ARE_NOT_EDITOR") } end

    local obj = scene.objects[objId]

    Logger(src, "EventScene", "Removed object from event scene", {
        eventScene = scene.name,
        objectModel = obj?.model,
        objectType = obj?.type,
        objectId = objId,
    })

    return scene:RemoveObject(objId)
end)

lib.callback.register("prp-staffevents:sceneUpdateObjectSetting", function(src, sceneId, objId, settingName, settingValue)
    ---@diagnostic disable-next-line: assign-type-mismatch
    local scene = GetEventScene(sceneId) ---@type ServerEventScene
    if not scene then
        return { success = false, error = locale("SCENE_DOES_NOT_EXIST") }
    end
    if not scene:IsEditor(src) then
        return { success = false, error = locale("YOU_ARE_NOT_EDITOR") }
    end

    if settingName == "stashName" or settingName == "isStash" then
        local stateId = bridge.fw.getIdentifier(src)
        if not EventPermission:HasPermission(stateId, "add_stash_to_object") then
            return { success = false, error = locale("NO_PERM_ASSIGN_STASH") }
        end
    end

    local obj = scene.objects[objId]

    Logger(src, "EventScene", "Updated object setting in event scene", {
        eventScene = scene.name,
        objectModel = obj?.model,
        objectType = obj?.type,
        objectId = objId,
        settingName = settingName,
        settingValue = tostring(settingValue),
    })

    scene:UpdateObjectSetting(src, objId, settingName, settingValue)
    return { success = true }
end)

lib.callback.register("prp-staffevents:sceneCopyObject", function(src, sceneId, objId)
    local stateId = bridge.fw.getIdentifier(src)
    if not EventPermission:HasPermission(stateId, "edit_scene") then
        return { success = false, error = locale("NO_PERM_ADD_OBJECT") }
    end

    ---@diagnostic disable-next-line: assign-type-mismatch
    local scene = GetEventScene(sceneId) ---@type ServerEventScene
    if not scene then return { success = false, error = locale("SCENE_DOES_NOT_EXIST") } end
    if not scene:IsEditor(src) then return { success = false, error = locale("YOU_ARE_NOT_EDITOR") } end

    local obj = scene.objects[objId]

    Logger(src, "EventScene", "Copied object in event scene", {
        eventScene = scene.name,
        objectModel = obj?.model,
        objectType = obj?.type,
        objectId = objId,
    })

    return scene:CopyObject(objId)
end)

lib.callback.register("prp-staffevents:getCharacter", function(src, targetSrc)
    local accessRows = {}

    local stateId = bridge.fw.getIdentifier(targetSrc)

    if bridge.usedFw == "qbx_core" then
        accessRows = DB:single_async([[
            select
                JSON_VALUE(c.charinfo, '$.firstname') as firstName,
                JSON_VALUE(c.charinfo, '$.lastname') as lastName,
                c.name as username
            from players c
            where
                c.citizenid = ?
            LIMIT 1
        ]], { stateId })
    elseif bridge.usedFw == "qb-core" then
        accessRows = DB:single_async([[
            select
                JSON_VALUE(c.charinfo, '$.firstname') as firstName,
                JSON_VALUE(c.charinfo, '$.lastname') as lastName,
                c.name as username
            from players c
            where
                c.citizenid = ?
        ]], { stateId })
    elseif bridge.usedFw == "es_extended" then
        accessRows = DB:single_async([[
            select
                s.*,
                firstname as firstName,
                lastname as lastName,
                firstname as username
            from users c
            where
                c.identifier = ?
        ]], { stateId })
    elseif bridge.usedFw == "nd_core" then
        accessRows = DB:single_async([[
            select
                s.*,
                firstname as firstName,
                lastname as lastName,
                c.name as username
            from users c
            where
                c.charid = ?
        ]], { stateId })
    end

    return accessRows
end)

lib.callback.register("prp-staffevents:getAccessCharacters", function(src, query, offset)
    local isAdmin = bridge.fw.isAdmin(src)
    if not isAdmin then
        return {}
    end

    local accessRows = {}

    if bridge.usedFw == "qbx_core" then
        accessRows = DB:query_async([[
            select
                s.*,
                JSON_VALUE(c.charinfo, '$.firstname') as firstName,
                JSON_VALUE(c.charinfo, '$.lastname') as lastName,
                c.name as username
            from staff_events_access s
                join players c on c.citizenid = s.stateId
            where
                JSON_VALUE(c.charinfo, '$.firstname') like concat('%', ?, '%') or
                JSON_VALUE(c.charinfo, '$.lastname') like concat('%', ?, '%')
            order by firstName LIMIT ?, 25
        ]], { query, query, offset })
    elseif bridge.usedFw == "qb-core" then
        accessRows = DB:query_async([[
            select
                s.*,
                JSON_VALUE(c.charinfo, '$.firstname') as firstName,
                JSON_VALUE(c.charinfo, '$.lastname') as lastName,
                c.name as username
            from staff_events_access s
                join players c on c.citizenid = s.stateId
            where
                JSON_VALUE(c.charinfo, '$.firstname') like concat('%', ?, '%') or
                JSON_VALUE(c.charinfo, '$.lastname') like concat('%', ?, '%')
            order by firstName LIMIT ?, 25
        ]], { query, query, offset })
    elseif bridge.usedFw == "es_extended" then
        accessRows = DB:query_async([[
            select
                s.*,
                firstname as firstName,
                lastname as lastName,
                firstname as username
            from staff_events_access s
                join users c on c.identifier = s.stateId
            where
                firstname like concat('%', ?, '%') or
                lastname like concat('%', ?, '%')
            order by firstname LIMIT ?, 25
        ]], { query, query, offset })
    elseif bridge.usedFw == "nd_core" then
        accessRows = DB:query_async([[
            select
                s.*,
                firstname as firstName,
                lastname as lastName,
                c.name as username
            from staff_events_access s
                join users c on c.charid = s.stateId
            where
                firstname like concat('%', ?, '%') or
                lastname like concat('%', ?, '%')
            order by firstname LIMIT ?, 25
        ]], { query, query, offset })
    end

    return accessRows
end)

lib.callback.register("prp-staffevents:setAccess", function(src, targetSrc, permissions)
    local isAdmin = bridge.fw.isAdmin(src)
    if not isAdmin then
        return { success = false, error = locale("NO_PERM_SET_EVENT_ACCESS") }
    end

    local targetStateId = bridge.fw.getIdentifier(targetSrc)
    if not targetStateId then
        return { success = false, error = locale("INVALID_STATE_ID") }
    end

    local addedBy = bridge.fw.getIdentifier(src)

    local resp = EventPermission:SetAccess(targetStateId, permissions, addedBy)
    if not resp then
        return { success = false, error = locale("FAILED_TO_SET_ACCESS") }
    end

    DB:insert_async([[
        insert into staff_events_access (stateId, permissions, addedBy)
        values (?, ?, ?)
        on duplicate key update
            permissions = values(permissions),
            addedBy = values(addedBy),
            createdAt = current_timestamp()
    ]], {
        targetStateId,
        json.encode(permissions),
        addedBy,
    })

    Logger(src, "EventScene", "Set access for event scene", {
        targetStateId = targetStateId,
        permissions = json.encode(permissions),
    })

    return { success = true }
end)

lib.callback.register("prp-staffevents:removeAccess", function(src, stateId)
    local isAdmin = bridge.fw.isAdmin(src)
    if not isAdmin then
        return { success = false, error = locale("NO_PERM_REMOVE_EVENT_ACCESS") }
    end

    local targetStateId = tonumber(stateId)
    if not targetStateId then
        return { success = false, error = locale("INVALID_STATE_ID") }
    end

    local resp = EventPermission:RemoveAccess(targetStateId)
    if not resp then
        return { success = false, error = locale("FAILED_TO_REMOVE_ACCESS") }
    end

    Logger(src, "EventScene", "Removed access for event scene", {
        targetStateId = targetStateId,
    })

    return { success = true }
end)

RegisterNetEvent("prp-staffevents:setSceneEnabled", function(sceneId, enabled)
    local src = source
    local stateId = bridge.fw.getIdentifier(src)
    if not EventPermission:HasPermission(stateId, "disable_scene") then
        return
    end

    ---@diagnostic disable-next-line: assign-type-mismatch
    local scene = GetEventScene(sceneId) ---@type ServerEventScene
    if not scene then return print(("Player (%s): Scene (%s) does not exist to set enabled"):format(src, sceneId)) end

    Logger(src, "EventScene", (enabled and "Enabled" or "Disabled") .. " event scene", {
        eventScene = scene.name,
        enabled = enabled,
    })

    scene:SetEnabled(src, enabled)
end)

RegisterNetEvent("prp-staffevents:setSceneName", function(sceneId, name)
    local src = source
    local stateId = bridge.fw.getIdentifier(src)
    if not EventPermission:HasPermission(stateId, "edit_scene") then
        return
    end

    ---@diagnostic disable-next-line: assign-type-mismatch
    local scene = GetEventScene(sceneId) ---@type ServerEventScene
    if not scene then return print(("Player (%s): Scene (%s) does not exist to set name"):format(src, sceneId)) end

    Logger(src, "EventScene", "Renamed event scene", {
        eventScene = scene.name,
        newName = name,
    })

    scene:SetName(name)
end)

RegisterNetEvent("prp-staffevents:setSceneBoundingBoxMargin", function(sceneId, margin)
    local src = source
    local stateId = bridge.fw.getIdentifier(src)
    if not EventPermission:HasPermission(stateId, "edit_scene") then
        return
    end

    ---@diagnostic disable-next-line: assign-type-mismatch
    local scene = GetEventScene(sceneId) ---@type ServerEventScene
    if not scene then return print(("Player (%s): Scene (%s) does not exist to set name"):format(src, sceneId)) end

    Logger(src, "EventScene", "Set event scene loading radius", {
        eventScene = scene.name,
        newRadius = margin,
    })

    scene:SetBoundingBoxMargin(margin)
end)

RegisterNetEvent("prp-staffevents:syncSceneObject", function(sceneId, data)
    local src = source
    ---@diagnostic disable-next-line: assign-type-mismatch
    local scene = GetEventScene(sceneId) ---@type ServerEventScene
    if not scene then return print(("Player (%s): Scene (%s) does not exist to sync object"):format(src, sceneId)) end
    if not scene:IsEditor(src) then return print(("Player (%s): Scene (%s) is not an editor"):format(src, sceneId)) end

    local objId = data.id ---@type number
    if not objId then return end

    scene:UpdateObject(src, objId, data)
end)

RegisterNetEvent("prp-staffevents:sceneRemoveEditor", function(sceneId)
    local src = source
    ---@diagnostic disable-next-line: assign-type-mismatch
    local scene = GetEventScene(sceneId) ---@type ServerEventScene
    if not scene then return print(("Player (%s): Scene (%s) does not exist to remove editor"):format(src, sceneId)) end
    scene:RemoveEditor(src)
end)

RegisterNetEvent("prp-staffevents:sceneUpdateObjectCoords", function(sceneId, objId, c_x, c_y, c_z, r_x, r_y, r_z)
    local src = source
    ---@diagnostic disable-next-line: assign-type-mismatch
    local scene = GetEventScene(sceneId) ---@type ServerEventScene
    if not scene then return print(("Player (%s): Scene (%s) does not exist to update object"):format(src, sceneId)) end
    if not scene:IsEditor(src) then return print(("Player (%s): Scene (%s) is not an editor"):format(src, sceneId)) end
    scene:UpdateCoordsRotation(
        src,
        objId,
        vec3(round(c_x, 4), round(c_y, 4), round(c_z, 4)),
        vec3(round(r_x, 4), round(r_y, 4), round(r_z, 4))
    )
end)

RegisterNetEvent("prp-staffevents:sceneDelete", function(sceneId)
    local src = source
    local stateId = bridge.fw.getIdentifier(src)
    if not EventPermission:HasPermission(stateId, "remove_scene") then
        return
    end

    ---@diagnostic disable-next-line: assign-type-mismatch
    local scene = GetEventScene(sceneId) ---@type ServerEventScene
    if not scene then return print(("Player (%s): Scene (%s) does not exist to remove scene"):format(src, sceneId)) end

    Logger(src, "EventScene", "Deleted event scene", {
        eventScene = scene.name,
    })

    scene:Delete()
end)

AddEventHandler("playerDropped", function(reason)
    local src = source
    playerLastTimeMinigame[tostring(src)] = nil
    for _, scene in pairs(ServerEventScenes) do
        scene:RemoveEditor(src)
        scene:SetPlayerInZone(src, false)
    end
end)

RegisterBPSCallback("prp-staffevents:getEventStashes", function(src)
    while not scenesLoaded do Wait(100) end
    local stashes = {}
    for id, stash in pairs(EventStashes) do
        stashes[id] = {
            id = stash.id,
            name = stash.name,
            items = stash.items,
        }
    end
    return stashes
end)

lib.callback.register("prp-staffevents:createEventStash", function(src, name)
    local stateId = bridge.fw.getIdentifier(src)
    if not EventPermission:HasPermission(stateId, "add_stash") then
        return { success = false, error = locale("NO_PERM_CREATE_EVENT_STASH") }
    end

    if not name or name == "" then
        return { success = false, error = locale("INVALID_NAME") }
    end

    if string.len(name) > 250 then
        return { success = false, error = locale("INVALID_NAME_2") }
    end

    local id = DB:insert_async("insert into staff_event_stashes (name, items) values (?, ?)", { name, json.encode({}) })

    if not id or id < 1 then
        return { success = false, error = locale("FAILED_TO_CREATE_EVENT_STASH") }
    end

    local stash = NewEventStash({
        id = id,
        name = name,
        items = {},
    })

    if not stash then
        return { success = false, error = locale("FAILED_TO_CREATE_EVENT_STASH") }
    end

    SetTimeout(0, function()
        TriggerClientEvent("prp-staffevents:createdEventStash", -1, stash)
    end)

    Logger(src, "EventScene", "Created event stash", {
        eventStashId = stash.id,
        eventStash = name
    })

    return { success = true, id = stash.id }
end)

lib.callback.register("prp-staffevents:deleteEventStash", function(src, stashId)
    local stateId = bridge.fw.getIdentifier(src)
    if not EventPermission:HasPermission(stateId, "remove_stash") then
        return { success = false, error = locale("NO_PERM_REMOVE_EVENT_STASH") }
    end

    local stash = GetEventStash(stashId)
    if not stash then
        return { success = false, error = locale("STASH_DOES_NOT_EXIST") }
    end

    Logger(src, "EventScene", "Deleted event stash", {
        eventStashId = stash.id,
        eventStash = stash.name,
    })

    stash:Delete()

    SetTimeout(0, function()
        TriggerClientEvent("prp-staffevents:deletedEventStash", -1, stash.id)
    end)

    return { success = true }
end)

lib.callback.register("prp-staffevents:updateEventStash", function(src, stashId, key, value)
    local stateId = bridge.fw.getIdentifier(src)
    if not EventPermission:HasPermission(stateId, "edit_stash_items") then
        return { success = false, error = locale("NO_PERM_EDIT_EVENT_STASH_ITEMS") }
    end

    local stash = GetEventStash(stashId)
    if not stash then
        return { success = false, error = locale("STASH_DOES_NOT_EXIST") }
    end

    if key == "items" then
        Logger(src, "EventScene", "Updated event stash items", {
            eventStashId = stash.id,
            eventStash = stash.name,
            items = json.encode(value),
        })
    else
        Logger(src, "EventScene", "Updated event stash", {
            eventStashId = stash.id,
            eventStash = stash.name,
            key = key,
            value = value,
        })
    end

    stash:Update(key, value)

    return { success = true }
end)

lib.callback.register("prp-staffevents:openStash", function(src, data)
    local stateId = bridge.fw.getIdentifier(src)
    if not stateId then return { success = false, error = locale("INVALID_STATE_ID") } end

    local ped = GetPlayerPed(src)
    if not ped or ped == 0 or not DoesEntityExist(ped) then
        return { success = false, error = locale("INVALID_PLAYER_ENTITY") }
    end

    local stashId = tonumber(data.stashId)
    if not stashId then
        return { success = false, error = locale("INVALID_STASH_ID") }
    end

    local sceneId = tonumber(data.sceneId)
    if not sceneId then
        return { success = false, error = locale("INVALID_SCENE_ID") }
    end

    local objectId = tonumber(data.objectId)
    if not objectId then
        return { success = false, error = locale("INVALID_OBJECT_ID") }
    end

    local scene = GetEventScene(sceneId)
    if not scene then
        return { success = false, error = locale("SCENE_DOES_NOT_EXIST") }
    end

    local obj = scene.objects[objectId] ---@type Object?
    if not obj then
        return { success = false, error = locale("OBJECT_DOES_NOT_EXIST") }
    end

    local coords = GetEntityCoords(ped)

    if #(coords - obj.coords) > 4.0 then
        return { success = false, error = locale("TO_FAR_AWAY_FROM_STASH") }
    end

    local stash = GetEventStash(stashId)
    if not stash then
        return { success = false, error = locale("STASH_DOES_NOT_EXIST") }
    end

    local inventoryId = stash:PrepareInventory(stateId, obj)
    if not inventoryId then
        return { success = false, error = locale("FAILED_TO_PREPARE_INVENTORY") }
    end

    if not playerLastTimeMinigame[tostring(src)] then
        playerLastTimeMinigame[tostring(src)] = {}
    end

    if not playerLastTimeMinigame[tostring(src)][obj.id] then
        playerLastTimeMinigame[tostring(src)][obj.id] = 0
    end

    if obj.settings["minigames"] and os.time() - playerLastTimeMinigame[tostring(src)][obj.id] > (60 * 10) then -- 10 minutes
        local minigames = obj.settings["minigames"] or {}
        for i=1, #minigames do
            local minigameName = minigames[i].name
            local minigameSetting = minigames[i].optionsName
            local minigameOptions = Minigames[minigameName]?[minigameSetting]
            if minigameOptions then
                local resp = lib.callback.await("prp-bridge:minigame", src, minigameName, minigameOptions, {})
                if not resp then
                    return { success = false, error = locale("MINIGAME_FAILED") }
                end
            end
        end

        playerLastTimeMinigame[tostring(src)][obj.id] = os.time()
    end

    if obj.settings["stashUseProgressBar"] then
        local duration = tonumber(obj.settings["stashProgressBarDuration"]) or 5000
        local anim = obj.settings["stashProgressBarAnim"]
        local animation = nil
        if anim ~= nil and Animations[anim] ~= nil then
            animation = {
                animDict = Animations[anim].AnDictionary,
                animClip = Animations[anim].AnAnim,
                animFlag = Animations[anim].flag or 0,
            }
        end

        local finished = lib.callback.await("prp-bridge:progress", src, {
            name = "event_stash_search",
            duration = duration,
            label = locale("SEARCHING"),
            useWhileDead = false,
            canCancel = true,
            disarm = false,
            controlDisables = {
                disableMovement = true,
                disableCarMovement = true,
                disableMouse = false,
                disableCombat = true,
            },
            animation = animation
        }, nil, true)

        if not finished then
            return { success = false, error = locale("CANCELED_SEARCHING_STASH") }
        end
    end

    bridge.inv.openStash(src, inventoryId)

    local inventoryItems = bridge.inv.getInventoryItems(inventoryId)
    local items = inventoryItems or {}

    Logger(src, "EventScene", "Opened event stash", {
        eventStashId = stash.id,
        eventStash = stash.name,
        sceneId = scene.id,
        sceneName = scene.name,
        objectId = obj.id,
        objectModel = obj.model,
        eventStashInventoryId = inventoryId,
        eventStashItems = json.encode(items),
    })

    return { success = true }
end)

lib.callback.register("prp-staffevents:refillEventStash", function(src, sceneId, objectId)
    local stateId = bridge.fw.getIdentifier(src)
    if not EventPermission:HasPermission(stateId, "refill_stash") then
        return { success = false, error = locale("NO_PERM_REFILL_EVENT_STASH") }
    end

    local scene = GetEventScene(sceneId)
    if not scene then
        return { success = false, error = locale("SCENE_DOES_NOT_EXIST") }
    end

    local obj = scene.objects[objectId] ---@type Object?
    if not obj then
        return { success = false, error = locale("OBJECT_DOES_NOT_EXIST") }
    end

    if not obj.settings["isStash"] or not obj.settings["stashName"] then
        return { success = false, error = locale("OBJECT_IS_NOT_STASH") }
    end

    local stashId = tonumber(obj.settings["stashName"])
    if not stashId then
        return { success = false, error = locale("INVALID_STASH_ID") }
    end

    local stash = GetEventStash(stashId)
    if not stash then
        return { success = false, error = locale("STASH_DOES_NOT_EXIST") }
    end

    stash:Refill(objectId)

    Logger(src, "EventScene", "Refilled event stash", {
        eventStashId = stash.id,
        eventStash = stash.name,
        sceneId = scene.id,
        sceneName = scene.name,
        objectId = obj.id,
        objectModel = obj.model,
    })

    return { success = true }
end)

lib.callback.register("prp-staffevents:teleport", function(src, data)
    local stateId = bridge.fw.getIdentifier(src)
    if not stateId then return { success = false, error = locale("INVALID_STATE_ID") } end

    local ped = GetPlayerPed(src)
    if not ped or ped == 0 or not DoesEntityExist(ped) then
        return { success = false, error = locale("INVALID_PLAYER_ENTITY") }
    end

    local sceneId = tonumber(data.sceneId)
    if not sceneId then
        return { success = false, error = locale("INVALID_SCENE_ID") }
    end

    local objectId = tonumber(data.objectId)
    if not objectId then
        return { success = false, error = locale("INVALID_OBJECT_ID") }
    end

    local scene = GetEventScene(sceneId)
    if not scene then
        return { success = false, error = locale("SCENE_DOES_NOT_EXIST") }
    end

    local obj = scene.objects[objectId] ---@type Object?
    if not obj then
        return { success = false, error = locale("OBJECT_DOES_NOT_EXIST") }
    end

    local coords = GetEntityCoords(ped)

    if #(coords - obj.coords) > 4.0 then
        return { success = false, error = locale("TO_FAR_AWAY") }
    end

    if not obj.settings.teleport then
        return { success = false, error = "Unknown error" }
    end

    local teleport = nil

    for i=1, #obj.settings.teleport do
        if obj.settings.teleport[i].uuid == data.teleportUuid then
            teleport = obj.settings.teleport[i]
            break
        end
    end

    if not teleport then
        return { success = false, error = locale("TELEPORT_DOES_NOT_EXIST") }
    end

    local c = teleport.coords
    local tpCoords = vec4(c.x, c.y, c.z, c.w)

    return { success = true, coords = tpCoords }
end)

RegisterNetEvent("prp-staffevents:zoneStatus", function(sceneId, inZone)
    local src = source
    local scene = GetEventScene(sceneId)
    if not scene then return end
    scene:SetPlayerInZone(src, inZone)
end)

RegisterNetEvent("prp-staffevents:setTpCoords", function(sceneId, objectId, tpUuid, coords)
    local src = source
    local scene = GetEventScene(sceneId)
    if not scene then return print(("Player (%s): Scene (%s) does not exist to set teleport coords"):format(src, sceneId)) end
    if not scene:IsEditor(src) then return print(("Player (%s): Scene (%s) is not an editor"):format(src, sceneId)) end

    local obj = scene.objects[objectId]
    if not obj then return print(("Player (%s): Scene (%s) object (%s) does not exist to set teleport coords"):format(src, sceneId, objectId)) end

    scene:UpdateTeleportCoords(objectId, tpUuid, coords)
end)

lib.callback.register("prp-staffevents:getEventScenesUi", function(src)
    local resp = DB:query_async([[
        select
            s.id,
            s.name,
            s.enabled,
            s.boundingBoxMargin,
            s.createdBy,
            s.lastUpdatedAt,
            s.createdAt,
            (
                select count(*) from staff_event_objects o where o.sceneId = s.id
            ) as numOfObjects
        from staff_events s
        order by 
            s.enabled DESC,
            s.createdAt DESC
    ]], {})

    return resp
end)