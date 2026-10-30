while true do
    if Config and Config.DivingSuit then break end
    Citizen.Wait(500)
end

if not Config.DivingSuit.enabled then return end

DivingSuit = {}
DivingSuit.isActive      = false
DivingSuit.originalOutfit = {}
DivingSuit.hudThread     = false

local hudEditMode = false  -- true while the player is repositioning the HUD

local SUIT_ANIM = {
    dict = "clothingshirt",
    clip = "try_shirt_positive_d",
    flag = 1,
}

-- ============================================================
--  Oxygen HUD thread
-- ============================================================

local function startHudThread()
    if DivingSuit.hudThread then return end
    DivingSuit.hudThread = true

    SendNUIMessage({ action = "setVisibleDivingSuitHud", data = true })

    CreateThread(function()
        local maxTime = Config.DivingSuit.underwaterTime
        if maxTime <= 0 then maxTime = 1.0 end

        while DivingSuit.isActive do
            local remaining = GetPlayerUnderwaterTimeRemaining(cache.playerId)
            remaining = math.max(0, math.min(remaining, maxTime))
            local percent = math.floor((remaining / maxTime) * 100 + 0.5)

            SendNUIMessage({ action = "setDivingSuitOxygen", data = {
                remaining = remaining,
                percent   = percent,
                max       = maxTime,
            }})

            Wait(500)
        end

        SendNUIMessage({ action = "setVisibleDivingSuitHud", data = false })
        DivingSuit.hudThread = false
    end)
end

-- ============================================================
--  Outfit helpers
-- ============================================================

function DivingSuit.saveOutfit(self)
    self.originalOutfit = {}
    local ped = cache.ped
    for _, comp in ipairs(Config.DivingSuit.outfit) do
        table.insert(self.originalOutfit, {
            component = comp.component,
            drawable  = GetPedDrawableVariation(ped, comp.component),
            texture   = GetPedTextureVariation(ped, comp.component),
        })
    end
end

function DivingSuit.applyOutfit(self, outfit)
    local ped = cache.ped
    for _, comp in ipairs(outfit) do
        SetPedComponentVariation(ped, comp.component, comp.drawable, comp.texture, 0)
    end
end

-- ============================================================
--  Activate / Deactivate
-- ============================================================

function DivingSuit.activate(self)
    if self.isActive then return end

    local completed = lib.progressBar({
        duration     = Config.DivingSuit.progressBarDuration,
        label        = locale("using_diving_suit"),
        useWhileDead = false,
        canCancel    = true,
        allowSwimming = true,
        disable      = { car = true, move = true, combat = true },
        anim         = SUIT_ANIM,
    })

    if not completed then
        Bridge.Notify.showNotify(locale("diving_suit_cancelled"), "error")
        return
    end

    self:saveOutfit()
    self:applyOutfit(Config.DivingSuit.outfit)

    local ped = cache.ped
    if Config.DivingSuit.scubaEnabled then
        SetEnableScuba(ped, true)
        SetPedMaxTimeUnderwater(ped, Config.DivingSuit.underwaterTime)
    end

    self.isActive = true
    Config.DivingSuit.onSuitActivated()
    Bridge.Notify.showNotify(locale("diving_suit_activated"), "success")

    if Config.DivingSuit.scubaEnabled then
        startHudThread()
    end

    ClearPedTasks(ped)
end

function DivingSuit.deactivate(self)
    if not self.isActive then return end

    local completed = lib.progressBar({
        duration     = Config.DivingSuit.progressBarDuration,
        label        = locale("removing_diving_suit"),
        useWhileDead = false,
        canCancel    = true,
        allowSwimming = true,
        disable      = { car = true, move = true, combat = true },
        anim         = SUIT_ANIM,
    })

    if not completed then
        Bridge.Notify.showNotify(locale("diving_suit_removal_cancelled"), "error")
        return
    end

    -- Restore outfit: saved components, or fall back to database skin
    if #self.originalOutfit > 0 then
        self:applyOutfit(self.originalOutfit)
    else
        local ok, skinData = pcall(function() return Bridge.Appearance.fetchDatabaseSkin() end)
        if ok and skinData then
            pcall(function() Bridge.Appearance.setPlayerSkin(skinData) end)
        end
    end

    local ped = cache.ped
    if Config.DivingSuit.scubaEnabled then
        SetEnableScuba(ped, false)
        SetPedMaxTimeUnderwater(ped, 10.0)
    end

    self.isActive       = false
    self.originalOutfit = {}

    Config.DivingSuit.onSuitDeactivated()
    Bridge.Notify.showNotify(locale("diving_suit_removed"), "success")
    ClearPedTasks(ped)
end

-- ============================================================
--  HUD edit mode (move/reposition HUD overlay)
-- ============================================================

local function setHudEditMode(enabled)
    hudEditMode = enabled
    if enabled then
        SetNuiFocus(true, true)
        SendNUIMessage({ action = "setVisibleDivingSuitHud", data = true })
        SendNUIMessage({ action = "setDivingSuitOxygen", data = { remaining = 30, percent = 75, max = 40 } })
        SendNUIMessage({ action = "setDivingSuitHudEdit", data = true })
    else
        SendNUIMessage({ action = "setDivingSuitHudEdit", data = false })
        SetNuiFocus(false, false)
        if not DivingSuit.isActive then
            SendNUIMessage({ action = "setVisibleDivingSuitHud", data = false })
        end
    end
end

RegisterCommand(Config.DivingSuit.hudMoveCommand or "divingsuithud", function()
    setHudEditMode(not hudEditMode)
end, false)

-- ============================================================
--  Optional keybind to remove suit
-- ============================================================

if Config.DivingSuit.allowKeybindRemoval then
    lib.addKeybind({
        name        = "divingsuit_deactivate",
        description = locale("diving_suit_deactivate_keybind"),
        defaultKey  = Config.DivingSuit.deactivateKey,
        onPressed   = function()
            if DivingSuit.isActive then
                DivingSuit:deactivate()
            end
        end,
    })
end

-- ============================================================
--  Exports
-- ============================================================

exports("isDivingSuitActive", function()
    return DivingSuit.isActive
end)

exports("toggleDivingSuit", function()
    if DivingSuit.isActive then
        DivingSuit:deactivate()
    else
        DivingSuit:activate()
    end
end)

-- ============================================================
--  Net events
-- ============================================================

RegisterNetEvent("p_policejob/client/divingsuit/activate", function()
    DivingSuit:activate()
end)

RegisterNetEvent("p_policejob/client/divingsuit/deactivate", function()
    DivingSuit:deactivate()
end)

-- ============================================================
--  Global events
-- ============================================================

AddEventHandler("p_policejob:client:hideFrame", function(data)
    if not data or data.name ~= "setVisibleDivingSuitHud" then return end
    if not hudEditMode then return end

    hudEditMode = false
    SetNuiFocus(false, false)
    if not DivingSuit.isActive then
        SendNUIMessage({ action = "setVisibleDivingSuitHud", data = false })
    end
end)
