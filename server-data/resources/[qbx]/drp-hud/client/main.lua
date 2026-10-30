-- Visibility, status sampling, compass, location and the per-frame HUD component hiding.

local function sendLayout()
    local m = Hud.metrics()
    Hud.send('layout', { mx = m.marginX / m.resX, my = m.marginY / m.resY })
end

local function sendInit()
    Hud.resetCache()
    Hud.send('init', {
        settings = Hud.settings,
        config = {
            subIcons = Config.SubIcons,
            thresholds = Config.Thresholds,
        },
    })
    sendLayout()
    Hud.send('visible', { value = Hud.visible })
    Hud.push('map', { show = Hud.mapVisible })
    Hud.resendPrompts()
    CreateThread(Hud.layoutMinimap)
end

RegisterNUICallback('ready', function(_, cb)
    sendInit()
    cb(1)
end)

-- Visibility, radar display and layout changes.
CreateThread(function()
    local layoutKey, nextLayoutCheck = nil, 0
    -- Match the starting mapVisible = false; the loop below only touches the radar on a change.
    DisplayRadar(false)
    while true do
        local hidden = Hud.scriptHidden or not Bridge.loaded or IsPauseMenuActive()
            or IsCinematicCamRendering() or IsCinematicIdleCamRendering()
            or IsScreenFadedOut() or IsPlayerSwitchInProgress()
        local visible = not hidden
        if visible ~= Hud.visible then
            Hud.visible = visible
            Hud.send('visible', { value = visible })
        end

        local s = Hud.settings
        -- With pd_watch running, the minimap and location bar only show while its watch is worn.
        local watchAllows = GetResourceState('pd_watch') ~= 'started' or LocalPlayer.state.pdWatchWorn == true
        local map = Hud.forceMap or (watchAllows and visible and s.showMinimap and (Hud.inVehicle or s.minimapOnFoot)) or false
        Hud.push('map', { location = watchAllows })
        -- The 3D minimap stands in for the radar whenever it can (not indoors, not
        -- before its world has loaded); otherwise the engine's radar shows.
        local drawn = map and ViceMap3D.owns() or false
        if map ~= Hud.mapVisible or drawn ~= Hud.mapDrawn then
            Hud.mapVisible = map
            Hud.mapDrawn = drawn
            DisplayRadar(map and not drawn)
            ViceMap3D.show(drawn)
            Hud.push('map', { show = map })
        end
        -- Spawn, character select and clothing menus turn the radar back on by themselves.
        local wantRadar = map and not drawn
        if IsRadarHidden() == wantRadar then DisplayRadar(wantRadar) end

        if Config.Minimap.disableBigmap and IsBigmapActive() then SetBigmapActive(false, false) end
        if map then Hud.tickMinimapZoom() end

        local now = GetGameTimer()
        if now >= nextLayoutCheck then
            nextLayoutCheck = now + 2000
            local m = Hud.metrics()
            local key = ('%d:%d:%.1f:%.1f'):format(m.resX, m.resY, m.marginX, m.marginY)
            if key ~= layoutKey then
                layoutKey = key
                sendLayout()
                Hud.layoutMinimap()
            end
        end
        Wait(200)
    end
end)

-- Health, armor, needs, stress, stamina, oxygen, dev mode.
CreateThread(function()
    local status = {}
    local playerId = PlayerId()
    local maxOxygen = 0
    while true do
        if Hud.visible then
            local ped = PlayerPedId()
            -- Lung capacity varies per character, so the longest time seen on this dive is 100%.
            local underwater = IsPedSwimmingUnderWater(ped)
            if underwater then
                local remaining = GetPlayerUnderwaterTimeRemaining(playerId)
                if remaining > maxOxygen then maxOxygen = remaining end
                status.oxygen = maxOxygen > 0 and Hud.round(Hud.clamp(remaining / maxOxygen * 100, 0, 100)) or 100
            else
                maxOxygen = 0
                status.oxygen = 100
            end
            status.underwater = underwater
            local maxHealth = GetEntityMaxHealth(ped) - 100
            local health = maxHealth > 0 and (GetEntityHealth(ped) - 100) / maxHealth * 100 or 0
            status.health = Hud.round(Hud.clamp(health, 0, 100))
            status.armor = Hud.clamp(GetPedArmour(ped), 0, 100)
            status.hunger = Hud.round(Bridge.needs.hunger)
            status.thirst = Hud.round(Bridge.needs.thirst)
            status.stress = Hud.round(Hud.clamp(LocalPlayer.state.stress or 0, 0, 100))
            status.stamina = Hud.round(Hud.clamp(100 - GetPlayerSprintStaminaRemaining(playerId), 0, 100))
            ViceMap3D.ripple(IsPedSprinting(ped))
            status.dev = Hud.devMode
            Hud.push('status', status)
            Wait(Hud.tick('status'))
        else
            Wait(500)
        end
    end
end)

-- Compass heading. GTA headings run counter-clockwise, so convert to a compass bearing.
CreateThread(function()
    local compass = {}
    while true do
        if Hud.mapVisible then
            local rot = GetFinalRenderedCamRot(2).z
            compass.heading = Hud.round((360.0 - rot) % 360.0) % 360
            Hud.push('compass', compass)
            Wait(Hud.tick('compass'))
        else
            Wait(500)
        end
    end
end)

-- Zone and street names, waypoint distance (meters, -1 when no waypoint is set) and the
-- compass bearing to the waypoint, which the NUI turns into the arrow on the distance tag.
CreateThread(function()
    local location = {}
    while true do
        if Hud.mapVisible then
            local c = GetEntityCoords(PlayerPedId())
            location.waypoint = -1
            if Hud.settings.showWaypoint and IsWaypointActive() then
                local wp = GetBlipInfoIdCoord(GetFirstBlipInfoId(8))
                local dx, dy = wp.x - c.x, wp.y - c.y
                location.waypoint = Hud.round(math.sqrt(dx * dx + dy * dy) / 10) * 10
                location.wpBearing = Hud.round(math.deg(math.atan(dx, dy)) % 360)
            end
            local zoneCode = GetNameOfZone(c.x, c.y, c.z)
            local zone = GetLabelText(zoneCode)
            local streetHash, crossHash = GetStreetNameAtCoord(c.x, c.y, c.z)
            location.zone = (zone == 'NULL' or zone == '') and zoneCode or zone
            location.street = GetStreetNameFromHashKey(streetHash)
            location.cross = crossHash ~= 0 and GetStreetNameFromHashKey(crossHash) or ''
            Hud.push('location', location)
            Wait(Hud.tick('location'))
        else
            Wait(1000)
        end
    end
end)

-- Player info cards: job, money, server ID, game clock and a headshot of the ped for the
-- voice box (shown through the nui-img texture protocol).
local avatar, avatarHandle, avatarPed = '', nil, 0

local function refreshAvatar(ped)
    local handle = RegisterPedheadshot(ped)
    local timeout = GetGameTimer() + 5000
    while not IsPedheadshotReady(handle) and GetGameTimer() < timeout do Wait(100) end
    if not IsPedheadshotReady(handle) or not IsPedheadshotValid(handle) then
        UnregisterPedheadshot(handle)
        return
    end
    if avatarHandle then UnregisterPedheadshot(avatarHandle) end
    avatarHandle = handle
    local txd = GetPedheadshotTxdString(handle)
    avatar = ('https://nui-img/%s/%s'):format(txd, txd)
end

CreateThread(function()
    local info = {}
    local nextAvatar = 0
    while true do
        if Hud.visible then
            local ped = PlayerPedId()
            -- a new ped (character switch, clothing reload) or every few minutes for outfit changes
            if Hud.settings.showAvatar and (ped ~= avatarPed or GetGameTimer() > nextAvatar) then
                avatarPed = ped
                nextAvatar = GetGameTimer() + 180000
                refreshAvatar(ped)
            end
            info.id = GetPlayerServerId(PlayerId())
            info.time = ('%02d:%02d'):format(GetClockHours(), GetClockMinutes())
            info.job = Bridge.jobLabel or Bridge.job or ''
            info.grade = Bridge.gradeLabel or ''
            if Bridge.money then
                info.cash = Bridge.money.cash
                info.bank = Bridge.money.bank
            end
            info.avatar = avatar
            Hud.push('info', info)
            Wait(1000)
        else
            Wait(1000)
        end
    end
end)

local UNARMED = `WEAPON_UNARMED`

-- Item toast card under the minimap. image: nui:// or https:// URL (e.g. an inventory item
-- image); icon: one of the bundled icon names (gun, cup, utensils, ...) used when no image.
local function itemToast(label, status, image, icon)
    if not Hud.settings.showToasts or not label then return end
    Hud.send('toast', {
        label = tostring(label),
        status = status and tostring(status) or '',
        image = image,
        icon = icon,
        duration = Config.Toasts.duration,
    })
end

local function weaponToast(hash, status)
    if not Config.Toasts.weapons then return end
    itemToast(Bridge.weaponLabel(hash) or 'Weapon', status, nil, 'gun')
end

-- Ammo counter (clip / reserve while holding a gun) and weapon equip / holster toasts.
CreateThread(function()
    local ammo = { show = false, clip = 0, reserve = 0 }
    local lastWeapon = UNARMED
    while true do
        local ped = PlayerPedId()
        local weapon = GetSelectedPedWeapon(ped)
        if weapon ~= lastWeapon and Hud.visible then
            if weapon ~= UNARMED then weaponToast(weapon, 'Equipped')
            elseif lastWeapon ~= UNARMED then weaponToast(lastWeapon, 'Holstered') end
        end
        lastWeapon = weapon

        if Hud.visible and Hud.settings.showAmmo and IsPedArmed(ped, 4) then
            local _, clip = GetAmmoInClip(ped, weapon)
            local total = GetAmmoInPedWeapon(ped, weapon)
            ammo.show = true
            ammo.name = Bridge.weaponLabel(weapon) or 'Weapon'
            ammo.clip = clip
            ammo.reserve = math.max(0, total - clip)
            Hud.push('ammo', ammo)
            Wait(Hud.tick('ammo'))
        else
            if ammo.show then
                ammo.show = false
                Hud.push('ammo', ammo)
            end
            Wait(500)
        end
    end
end)

-- Per-frame work that GTA resets every frame. Kept to a handful of native calls.
CreateThread(function()
    local hide = Config.HiddenHudComponents
    local count = #hide
    local hideComponent = HideHudComponentThisFrame
    local disable = DisableControlAction
    local stripBars = Config.Minimap.hideHealthArmour
    local blockExit = Config.Vehicle.disableExitWhenBelted
    local isControlActive = IsControlEnabled
    local radar = RequestScaleformMovie('minimap')

    while true do
        for i = 1, count do hideComponent(hide[i]) end

        if stripBars and Hud.mapVisible then
            BeginScaleformMovieMethod(radar, 'SETUP_HEALTH_ARMOUR')
            ScaleformMovieMethodAddParamInt(3)
            EndScaleformMovieMethod()
        end

        if blockExit and Hud.belted then
            disable(0, 75, true)
            disable(27, 75, true)
        end

        -- Settings > Bicycles > bell sounds off: the horn (the bell on a bicycle) stays silent
        if Hud.muteBell and isControlActive(0, 86) then disable(0, 86, true) end
        Wait(0)
    end
end)

local function toggleHud(state)
    if state == nil then state = Hud.scriptHidden end
    Hud.scriptHidden = not state
end

exports('ToggleHud', toggleHud)
exports('ShowItemToast', itemToast)
RegisterNetEvent('my-hud:client:itemToast', itemToast)

-- Green "</>" circle. qb-adminmenu fires its toggle event; anything else can use the export.
local function setDevMode(state)
    if state == nil then state = not Hud.devMode end
    Hud.devMode = state == true
end

exports('SetDevMode', setDevMode)
RegisterNetEvent('qb-admin:client:ToggleDevmode', function() setDevMode() end)
exports('IsHudVisible', function() return Hud.visible end)
RegisterNetEvent('my-hud:client:toggle', toggleHud)
