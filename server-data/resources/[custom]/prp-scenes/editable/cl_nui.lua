---@param focus boolean
function SetUIFocus(focus)
    SetNuiFocus(focus, focus)
end

---@param app string
---@param actionName string
---@param data any
function SendAppAction(app, actionName, data)
    SendNUIMessage({
        event = "sendAppEvent",
        app = "sceneEditor",
        action = actionName,
        payload = data,
    })
end

local function loadParticle(name)
	if not HasNamedPtfxAssetLoaded(name) then
		RequestNamedPtfxAsset(name)
	end
    local timeout = 0
	while not HasNamedPtfxAssetLoaded(name) and timeout < 30 do
		Wait(0)
        timeout = timeout + 1
	end
	SetPtfxAssetNextCall(name)
end

local function hexToRgb(hex)
    local r = tonumber(hex:sub(2, 3), 16)
    local g = tonumber(hex:sub(4, 5), 16)
    local b = tonumber(hex:sub(6, 7), 16)
    return r, g, b
end

RegisterNUICallback("sceneEditor:sceneData", function(data, cb)
    if not CreatorRunning then
        cb(false)
        return
    end

    CreatorSceneData = data
    SendRendererAction(CreatorRenderer, "setSceneData", data)
    ComputeTargetRotation()

    cb(true)
end)

local function saveScene(data, cb)
    if not CreatorRunning or not CreatorSceneData then
        cb({success = false, error = locale("NO_SCENE_DATA")})
        return
    end

    if GraffitiMode then
        SetUIFocus(false)
        local diff = TargetCoords - GetEntityCoords(cache.ped, true)

        local heading = GetHeadingFromVector_2d(diff.x, diff.y)
        SetEntityHeading(cache.ped, heading)

        local objectId = lib.callback.await("prp-scenes:createSprayCan", 500)

        loadParticle('core')

        Wait(100)

        UseParticleFxAssetNextCall("core")

        local startTime = GetGameTimer()
        local spraycan = 0

        while not DoesEntityExist(spraycan) do
            Wait(0)
            spraycan = exports["prp-bridge"]:GetObjectHandle(objectId)

            if GetGameTimer() - startTime > 1000 then
                break
            end
        end

        local spray = StartParticleFxLoopedOnEntity("ent_amb_steam", spraycan, 0.0, 0.13, 0.0, 90.0, 90.0, 0.0, 0.2, false, false, false)

        local r, g, b = hexToRgb(CreatorSceneData.fontColor)
        SetParticleFxLoopedAlpha(spray, 255.0)
        SetParticleFxLoopedColour(spray, r/255, g/255, b/255, false)

        local finished = bridge.fw.progressBar({
            label = locale("SPRAYING_GRAFFITI"),
            duration = SPRAYING_GRAFFITI_PROG_DURATION,
            useWhileDead = false,
            canCancel = true,
            animation = {
                animDict = "switch@franklin@lamar_tagging_wall",
                animClip = "lamar_tagging_exit_loop_lamar",
                flag = 1
            },
            controlDisables = {
                disableMovement = true,
                disableCombat = true,
                disableMouse = false,
                disableSprint = true,
            }
        })

        TriggerServerEvent("prp-scenes:deleteSprayCan")
        StopParticleFxLooped(spray, false)

        SetUIFocus(true)

        if not finished then
            cb({success = false, error = locale("CANCELED")})
            return
        end
    end

    local resp = lib.callback.await("prp-scenes:createScene", 1000, CreatorSceneData, TargetCoords, TargetRotation, CreatorStaffMode, GraffitiMode)

    if resp and resp.success then
        CreatorRunning = false

        if not GraffitiMode then
            if not SceneHistory then
                SceneHistory = {}
                SceneHistory = lib.callback.await("prp-scenes:getScenesHistory", 1000)
                SendAppAction("sceneEditor", "setHistory", SceneHistory or {})
            end
            if #SceneHistory >= 5 then
                table.remove(SceneHistory, #SceneHistory)
            end

            resp.scene.displayData.isGraffiti = GraffitiMode

            table.insert(SceneHistory, 1, resp.scene.displayData)
        end
    end

    cb(resp)
end

local savingScene = false
RegisterNUICallback("sceneEditor:saveScene", function(data, cb)
    if savingScene then
        cb({ success = false, error = locale("CANCELED") })
        return
    end

    savingScene = true

    local s, e = pcall(saveScene, data, cb)

    savingScene = false

    if not s then
        print("Error saving scene:", e)
    end
end)

RegisterNUICallback("sceneEditor:close", function(data, cb)
    CreatorRunning = false
    cb('ok')
end)

RegisterNUICallback("sceneEditor:editPosition", function(data, cb)
    CreatorPlacing = true
    SetUIFocus(false)
    cb('ok')
end)

RegisterNUICallback("getLocale", function(data, cb)
    cb({
        lang = lib.getLocaleKey()
    })
end)