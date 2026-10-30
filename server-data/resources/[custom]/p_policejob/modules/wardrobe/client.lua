if not (Config and Config.Wardrobe and Config.Wardrobe.Enabled) then return end

-- Spawn point for the preview ped (underground so it isn't visible to other players)
local PREVIEW_ORIGIN = vector4(0.0, 0.0, -100.0, 0.0)

Wardrobe = {}
Wardrobe.isOpen        = false
Wardrobe.previewPed    = nil
Wardrobe.previewCam    = nil
Wardrobe.currentGender = nil
Wardrobe.previewActive = false

-- ============================================================
--  Preview camera + rotating ped
-- ============================================================

function Wardrobe.startPreview(self)
    if not self.previewPed or not DoesEntityExist(self.previewPed) then return end

    self.previewActive = true

    -- Position camera slightly above and in front of the ped
    local offset  = vector3(0.0, 1.8, 0.1)
    local camPos  = vector3(
        PREVIEW_ORIGIN.x + offset.x,
        PREVIEW_ORIGIN.y + offset.y,
        PREVIEW_ORIGIN.z + offset.z)

    local cam = CreateCamWithParams("DEFAULT_SCRIPTED_CAMERA",
        camPos.x, camPos.y, camPos.z,
        0.0, 0.0, 0.0, 30.0, false, 0)
    self.previewCam = cam

    PointCamAtEntity(cam, self.previewPed, 0.0, 0.0, 0.2, true)
    SetCamActive(cam, true)
    RenderScriptCams(true, false, 0, true, true)

    -- Slow-rotation thread
    Citizen.CreateThread(function()
        local heading = 0.0
        while self.previewActive and self.previewPed and DoesEntityExist(self.previewPed) do
            heading = heading + 0.5
            if heading > 360.0 then heading = 0.0 end
            SetEntityHeading(self.previewPed, heading)
            Citizen.Wait(0)
        end
    end)
end

function Wardrobe.deletePreviewPed(self)
    self.previewActive = false

    if self.previewCam then
        RenderScriptCams(false, false, 0, true, true)
        DestroyCam(self.previewCam, false)
        self.previewCam = nil
    end

    if self.previewPed and DoesEntityExist(self.previewPed) then
        DeleteEntity(self.previewPed)
    end
    self.previewPed = nil
end

function Wardrobe.destroyPreview(self)
    self:deletePreviewPed()
end

-- ============================================================
--  Open / close
-- ============================================================

function Wardrobe.open(self, mode)
    if self.isOpen then return end

    -- Normalise mode: only "select" is a valid alternative; everything else = "manage"
    mode = (mode == "select") and "select" or "manage"

    -- Server access + config check
    local config = lib.callback.await("p_policejob/wardrobe/getConfig", false)
    if not config then
        Bridge.Notify.showNotify(locale("no_access"), "error")
        return
    end

    self.currentGender = Editable.getPlayerGender()

    -- Choose the correct callback depending on mode
    local callbackName = (mode == "select")
        and "p_policejob/wardrobe/getAllowedOutfits"
        or  "p_policejob/wardrobe/getOutfits"

    local outfits = lib.callback.await(callbackName, false, self.currentGender)

    self.isOpen = true
    SendNUIMessage({ action = "setWardrobeMode",    data = mode })
    SendNUIMessage({ action = "setWardrobeConfig",  data = config })
    SendNUIMessage({ action = "setWardrobeOutfits", data = outfits or {} })
    SendNUIMessage({ action = "setVisibleWardrobe", data = true })
    SetNuiFocus(true, true)
end

function Wardrobe.close(self)
    if not self.isOpen then return end
    self.isOpen = false
    self:destroyPreview()
    SendNUIMessage({ action = "setVisibleWardrobe", data = false })
    SetNuiFocus(false, false)
end

-- ============================================================
--  Global event — hide frame
-- ============================================================

AddEventHandler("p_policejob:client:hideFrame", function(data)
    local name = data and data.name or nil
    if name == "setVisibleWardrobe" then Wardrobe:close() end
end)

-- ============================================================
--  NUI callbacks
-- ============================================================

-- Create a new outfit from the player's current skin
RegisterNUICallback("wardrobe:create", function(data, cb)
    local ok, skin = pcall(function() return Bridge.Appearance.fetchCurrentSkin() end)
    if not ok or not skin then
        cb({ success = false, error = "Could not get player skin" })
        Bridge.Notify.showNotify(locale("skin_error"), "error")
        return
    end

    data.skin = skin
    local result = lib.callback.await("p_policejob/wardrobe/create", false, data)

    if not (result and result.success) then
        local errMsg = (result and result.error) or locale("no_access")
        Bridge.Notify.showNotify(errMsg, "error")
    end

    cb(result or { success = false })
end)

-- Apply an outfit to the player
RegisterNUICallback("wardrobe:apply", function(data, cb)
    local outfitId = data and data.outfitId
    if not outfitId then cb({ success = false }); return end

    local skin = lib.callback.await("p_policejob/wardrobe/getOutfitSkin", false, outfitId)
    if not skin then
        Bridge.Notify.showNotify(locale("outfit_not_allowed"), "error")
        cb({ success = false })
        return
    end

    Wardrobe:close()
    Bridge.Appearance.setPlayerClothing(skin)
    Bridge.Notify.showNotify(locale("outfit_applied"), "success")
    cb({ success = true })
end)

-- Delete an outfit (managers only; server enforces permission)
RegisterNUICallback("wardrobe:delete", function(data, cb)
    local result = lib.callback.await("p_policejob/wardrobe/delete", false, data)

    if not (result and result.success) then
        Bridge.Notify.showNotify(locale("no_access"), "error")
    end

    cb(result or { success = false })
end)

-- ============================================================
--  Exports + commands
-- ============================================================

exports("OpenWardrobe",      function() Wardrobe:open() end)
exports("OpenUniformSelect", function() Wardrobe:open("select") end)

RegisterCommand("wardrobe",  function() Wardrobe:open() end,         false)
RegisterCommand("uniforms",  function() Wardrobe:open("select") end, false)
