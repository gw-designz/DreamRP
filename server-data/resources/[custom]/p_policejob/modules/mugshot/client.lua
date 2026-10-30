if not Config.Mugshot.enabled then return end

Mugshot = {}
Mugshot.isActive       = false
Mugshot.boardRendering = false

-- ============================================================
--  Exports
-- ============================================================

exports("isMugshotActive", function()
    return Mugshot.isActive
end)

exports("openMugshotMenu", function(zoneData)
    Mugshot:openMenu(nil, zoneData)
end)

exports("openMugshotGallery", function()
    Mugshot:openGallery()
end)

-- ============================================================
--  Scaleform helpers
-- ============================================================

function Mugshot.loadScaleform(self, name)
    local handle = RequestScaleformMovie(name)
    while not HasScaleformMovieLoaded(handle) do
        Wait(0)
    end
    return handle
end

function Mugshot.createNamedRenderTarget(self, targetName, modelHash)
    if not IsNamedRendertargetRegistered(targetName) then
        RegisterNamedRendertarget(targetName, 0)
    end
    if not IsNamedRendertargetLinked(modelHash) then
        LinkNamedRendertarget(modelHash)
    end
    if IsNamedRendertargetRegistered(targetName) then
        return GetNamedRendertargetRenderId(targetName)
    end
    return 0
end

-- ============================================================
--  Mugshot board
-- ============================================================

-- Loads the mugshot scaleform, creates the named render target for the ID text
-- panel, starts a render thread, and returns the scaleform handle.
function Mugshot.prepareMugshotBoard(self)
    self.boardRendering = true

    local scaleform = self:loadScaleform("mugshot_board_01")
    local renderId  = self:createNamedRenderTarget("ID_Text", -955488312)

    CreateThread(function()
        while self.boardRendering do
            HideHudAndRadarThisFrame()
            SetTextRenderId(renderId)
            Set_2dLayer(4)
            SetScriptGfxDrawBehindPausemenu(1)
            DrawScaleformMovie(scaleform, 0.405, 0.37, 0.81, 0.74, 255, 255, 255, 255, 0)
            SetScriptGfxDrawBehindPausemenu(0)
            SetTextRenderId(GetDefaultScriptRendertargetRenderId())
            Wait(0)
        end
    end)

    return scaleform
end

-- Writes text onto the mugshot board scaleform via SET_BOARD call.
function Mugshot.drawBoard(self, scaleform, boardData)
    BeginScaleformMovieMethod(scaleform, "SET_BOARD")
    PushScaleformMovieMethodParameterString(boardData.title)
    PushScaleformMovieMethodParameterString(boardData.text)
    PushScaleformMovieMethodParameterString(boardData.subtitle)
    PushScaleformMovieMethodParameterString(boardData.footer)
    PushScaleformMovieFunctionParameterInt(0)
    PushScaleformMovieMethodParameterString(boardData.level or "")
    PushScaleformMovieFunctionParameterInt(116)
    EndScaleformMovieMethod()
end

-- Spawns the mugshot board prop and text prop, attaches them to the ped,
-- and returns both entity handles (boardProp, textProp).
function Mugshot.createPlayerBoard(self)
    local ped = cache.ped

    lib.requestModel("prop_police_id_board")
    lib.requestModel("prop_police_id_text")

    local pedCoords = GetEntityCoords(ped)

    -- Board prop (hash -1623189257 = prop_police_id_board)
    local boardProp = CreateObject(-1623189257, pedCoords, true, true, false)
    -- Text prop (hash -955488312 = prop_police_id_text)
    local textProp  = CreateObject(-955488312,  pedCoords, true, true, false)

    -- Attach text prop to board prop at bone 4103
    AttachEntityToEntity(textProp, boardProp, -1, 4103,
        0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
        false, false, false, false, 2, true)

    -- Disarm and clean ped
    SetCurrentPedWeapon(ped, -1569615261, 1)  -- WEAPON_UNARMED
    ClearPedWetness(ped)
    ClearPedBloodDamage(ped)

    -- Attach board prop to ped's left hand (bone 28422 = SKEL_L_Hand)
    local boneIndex = GetPedBoneIndex(ped, 28422)
    AttachEntityToEntity(boardProp, ped, boneIndex,
        0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
        0, 0, 0, 0, 2, 1)

    SetModelAsNoLongerNeeded("prop_police_id_board")
    SetModelAsNoLongerNeeded("prop_police_id_text")

    return boardProp, textProp
end

-- ============================================================
--  Zone target options (per mugshot spot in DepartmentData)
-- ============================================================

CreateThread(function()
    for zoneName, zoneDef in pairs(Config.DepartmentData.mugshots or {}) do
        Bridge.Target.addSphereZone({
            coords     = zoneDef.coords,
            radius     = 0.5,
            drawSprite = true,
            debug      = Config.Debug,
            options    = {
                {
                    name     = "p_policejob:mugshot:take_"  .. zoneName,
                    label    = locale("take_mugshot"),
                    icon     = "fa-solid fa-camera",
                    distance = 2,
                    groups   = Config.Jobs,
                    onSelect = function()
                        Mugshot:takeMugshot(zoneName, zoneDef)
                    end,
                },
                {
                    name     = "p_policejob:mugshot:check_" .. zoneName,
                    label    = locale("check_mugshots"),
                    icon     = "fa-solid fa-images",
                    distance = 2,
                    groups   = Config.Jobs,
                    onSelect = function()
                        Mugshot:openGallery()
                    end,
                },
            },
        })
    end
end)

-- ============================================================
--  Take mugshot (officer-side: get info, find target, trigger server)
-- ============================================================

function Mugshot.takeMugshot(self, zoneName, zoneDef)
    local result = lib.inputDialog(locale("take_mugshot"), {
        { type = "textarea", label = locale("mugshot_info"), required = true },
    })
    if not result then return end

    local closestPlayer = lib.getClosestPlayer(zoneDef.photoCoords, 1.5, false)
    if not closestPlayer then
        return Bridge.Notify.showNotify(locale("no_player_to_mugshot"), "error")
    end

    TriggerServerEvent("p_policejob/server/mugshot/takePhoto", {
        playerId = GetPlayerServerId(closestPlayer),
        name     = zoneName,
        info     = { description = result[1] },
    })
end

-- ============================================================
--  Photo capture callback (runs on the SUSPECT's client)
-- ============================================================

lib.callback.register("p_policejob/client/mugshot/takePhoto", function(data)
    local zoneDef  = Config.DepartmentData.mugshots[data.name]
    local scaleform = Mugshot:prepareMugshotBoard()

    Wait(350)

    Mugshot:drawBoard(scaleform, {
        title    = Config.Mugshot.boardTitle,
        subtitle = Config.Mugshot.boardSubtitle,
        text     = Bridge.Framework.getPlayerName(),
        footer   = data.info.dob,
        level    = "",
    })

    local boardProp, textProp = Mugshot:createPlayerBoard()

    -- Holding-board animation
    local animDict    = lib.requestAnimDict("mp_character_creation@customise@male_a")
    local prevWeapon  = GetSelectedPedWeapon(cache.ped)
    TaskPlayAnim(cache.ped, animDict, "loop", -8.0, 8.0, -1, 1, true)

    -- Scripted camera pointed at the ped
    local cam       = CreateCam("DEFAULT_SCRIPTED_CAMERA", true)
    local pedCoords = GetEntityCoords(cache.ped)
    SetCamCoord(cam, zoneDef.cameraCoords.x, zoneDef.cameraCoords.y, zoneDef.cameraCoords.z)
    PointCamAtCoord(cam, pedCoords.x, pedCoords.y, zoneDef.cameraCoords.z)
    SetCamFov(cam, zoneDef.cameraFov or 50.0)
    RenderScriptCams(true, false, 0, true, true)

    Wait(2000)
    local photoUrl = PolicePhotoCapture()
    Wait(2000)

    -- Clean up
    Mugshot.boardRendering = false
    RenderScriptCams(false, false, 0, true, true)
    DestroyCam(cam)
    DeleteObject(boardProp)
    DeleteObject(textProp)
    StopAnimTask(cache.ped, "mp_character_creation@customise@male_a", "loop", 1.0)
    SetCurrentPedWeapon(cache.ped, prevWeapon, true)

    if photoUrl then
        Config.Mugshot.onPhotoTaken(photoUrl)
    end

    return photoUrl
end)

-- ============================================================
--  Gallery
-- ============================================================

function Mugshot.openGallery(self, searchQuery)
    local records = lib.callback.await("p_policejob/server/mugshot/getMugshots", false, searchQuery)
    if not records then return end

    SendNUIMessage({ action = "setMugshotData",    data = records })
    SendNUIMessage({ action = "setVisibleMugshot", data = true })
    SetNuiFocus(true, true)
end

function Mugshot.closeGallery(self)
    SendNUIMessage({ action = "setVisibleMugshot", data = false })
    SetNuiFocus(false, false)
end

-- ============================================================
--  NUI callbacks
-- ============================================================

RegisterNUICallback("mugshot:remove", function(data, cb)
    if data.id then
        TriggerServerEvent("p_policejob/server/mugshot/remove", data.id)
    end
    cb("ok")
end)

RegisterNUICallback("mugshot:copyUrl", function(data, cb)
    if data.url then
        lib.setClipboard(data.url)
        Bridge.Notify.showNotify(locale("mugshot_url_copied"), "success")
    end
    cb("ok")
end)

-- ============================================================
--  Global event — hide frame
-- ============================================================

AddEventHandler("p_policejob:client:hideFrame", function(data)
    if data.name == "setVisibleMugshot" then
        Mugshot:closeGallery()
    end
end)
