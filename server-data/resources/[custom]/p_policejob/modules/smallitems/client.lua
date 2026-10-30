while true do
    if Config and Config.SmallItems then break end
    Citizen.Wait(500)
end

if not Config.SmallItems.Enabled then return end

-- Night-vision state
local NV = { isWearing = false, isActive = false }
-- Thermal-vision state
local TV = { isWearing = false, isActive = false }

-- Saved original prop variants before any override
-- [propIndex] = { drawable, texture }
local savedProps = {}

-- ============================================================
--  Access check
-- ============================================================

local function hasJobAccess()
    local job = Bridge.Framework.fetchPlayerJob()
    if not job then return false end
    return Config.Jobs and (Config.Jobs[job.name] ~= nil)
end

-- ============================================================
--  Prop management (hats / accessories)
-- ============================================================

-- Saves the current prop variant for the given index if not already saved,
-- then applies the new prop from the item definition.
local function applyProp(itemCfg)
    if not (itemCfg and itemCfg.enabled) then return end

    local ped       = PlayerPedId()
    local propIndex = itemCfg.propIndex

    -- Save original only once
    if savedProps[propIndex] == nil then
        savedProps[propIndex] = {
            drawable = GetPedPropIndex(ped, propIndex),
            texture  = GetPedPropTextureIndex(ped, propIndex),
        }
    end

    -- Choose male or female variant
    local isMale = GetEntityModel(ped) == 1885233650  -- mp_m_freemode_01
    local variant = isMale and itemCfg.male or itemCfg.female
    SetPedPropIndex(ped, propIndex, variant.drawable, variant.texture, true)
end

-- Restores the saved prop variant for the given item's propIndex.
local function restoreProp(itemCfg)
    if not (itemCfg and itemCfg.enabled) then return end

    local propIndex = itemCfg.propIndex
    local saved     = savedProps[propIndex]
    if saved == nil then return end

    local ped = PlayerPedId()
    if saved.drawable == -1 then
        ClearPedProp(ped, propIndex)
    else
        SetPedPropIndex(ped, propIndex, saved.drawable, saved.texture, true)
    end
    savedProps[propIndex] = nil
end

-- ============================================================
--  Night Vision
-- ============================================================

if Config.SmallItems.NightVision.enabled then
    local NVCfg = Config.SmallItems.NightVision

    local function setNightVisionActive(active)
        NV.isActive = active
        SetNightvision(active)
        -- Mutually exclusive with thermal
        if active and TV.isActive then
            TV.isActive = false
            SetSeethrough(false)
        end
    end

    local function toggleNightVision()
        if NV.isWearing then
            -- Take off
            local ok = Bridge.Progress.Start({
                duration     = NVCfg.putOnTime,
                label        = locale("nightvision_taking_off"),
                useWhileDead = false,
                canCancel    = true,
                disable      = NVCfg.disableControls,
                anim         = NVCfg.putOnAnim,
            })
            if not ok then return end

            NV.isWearing = false
            setNightVisionActive(false)

            -- Restore correct hat: thermal hat if thermal is wearing, else clear NV hat
            if TV.isWearing then
                applyProp(Config.SmallItems.ThermalVision.hat)
            else
                restoreProp(NVCfg.hat)
            end

            Bridge.Notify.showNotify(locale("nightvision_removed"), "inform")
        else
            -- Put on
            if NVCfg.requireJob and not hasJobAccess() then
                Bridge.Notify.showNotify(locale("no_access"), "error")
                return
            end

            local ok = Bridge.Progress.Start({
                duration     = NVCfg.putOnTime,
                label        = locale("nightvision_putting_on"),
                useWhileDead = false,
                canCancel    = true,
                disable      = NVCfg.disableControls,
                anim         = NVCfg.putOnAnim,
            })
            if not ok then return end

            NV.isWearing = true
            setNightVisionActive(true)
            applyProp(NVCfg.hat)
            Bridge.Notify.showNotify(locale("nightvision_equipped"), "success")
        end
    end

    exports("isNightVisionActive", function() return NV.isActive end)

    RegisterNetEvent("p_policejob/client/smallitems/nightvision/use", function()
        toggleNightVision()
    end)
end

-- ============================================================
--  Thermal Vision
-- ============================================================

if Config.SmallItems.ThermalVision.enabled then
    local TVCfg = Config.SmallItems.ThermalVision

    local function setThermalVisionActive(active)
        TV.isActive = active
        SetSeethrough(active)
        -- Mutually exclusive with night vision
        if active and NV.isActive then
            NV.isActive = false
            SetNightvision(false)
        end
    end

    local function toggleThermalVision()
        if TV.isWearing then
            -- Take off
            local ok = Bridge.Progress.Start({
                duration     = TVCfg.putOnTime,
                label        = locale("thermalvision_taking_off"),
                useWhileDead = false,
                canCancel    = true,
                disable      = TVCfg.disableControls,
                anim         = TVCfg.putOnAnim,
            })
            if not ok then return end

            TV.isWearing = false
            setThermalVisionActive(false)

            -- Restore correct hat: NV hat if NV is wearing, else clear TV hat
            if NV.isWearing then
                applyProp(Config.SmallItems.NightVision.hat)
            else
                restoreProp(TVCfg.hat)
            end

            Bridge.Notify.showNotify(locale("thermalvision_removed"), "inform")
        else
            -- Put on
            if TVCfg.requireJob and not hasJobAccess() then
                Bridge.Notify.showNotify(locale("no_access"), "error")
                return
            end

            local ok = Bridge.Progress.Start({
                duration     = TVCfg.putOnTime,
                label        = locale("thermalvision_putting_on"),
                useWhileDead = false,
                canCancel    = true,
                disable      = TVCfg.disableControls,
                anim         = TVCfg.putOnAnim,
            })
            if not ok then return end

            TV.isWearing = true
            setThermalVisionActive(true)
            applyProp(TVCfg.hat)
            Bridge.Notify.showNotify(locale("thermalvision_equipped"), "success")
        end
    end

    exports("isThermalVisionActive", function() return TV.isActive end)

    RegisterNetEvent("p_policejob/client/smallitems/thermalvision/use", function()
        toggleThermalVision()
    end)
end

-- ============================================================
--  Cleanup on resource stop
-- ============================================================

AddEventHandler("onResourceStop", function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    SetNightvision(false)
    SetSeethrough(false)
    restoreProp(Config.SmallItems.NightVision.hat)
    restoreProp(Config.SmallItems.ThermalVision.hat)
end)

-- ============================================================
--  Auto-remove on player death (watches local player's isDead state bag)
-- ============================================================

local myStateBagName = ("player:%s"):format(cache.serverId)

AddStateBagChangeHandler("isDead", myStateBagName, function(_, _, isDead)
    if not isDead then return end

    if NV.isActive then SetNightvision(false) end
    NV.isActive  = false
    NV.isWearing = false

    if TV.isActive then SetSeethrough(false) end
    TV.isActive  = false
    TV.isWearing = false

    restoreProp(Config.SmallItems.NightVision.hat)
    restoreProp(Config.SmallItems.ThermalVision.hat)
end)
