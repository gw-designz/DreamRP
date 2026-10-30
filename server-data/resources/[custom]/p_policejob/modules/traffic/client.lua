while true do
    if Config and Config.Traffic then break end
    Citizen.Wait(500)
end

if not Config.Traffic.enabled then return end

Traffic = {}
Traffic.activeZones = {}
Traffic.editing     = false
Traffic.markerData  = {}

-- ============================================================
--  Access check (job + grade)
-- ============================================================

local function hasJobAccess()
    local job = Bridge.Framework.fetchPlayerJob()
    if not (job and Config.Jobs[job.name]) then return false end
    if (job.grade or 0) < Config.Jobs[job.name] then return false end
    return true
end

-- ============================================================
--  Remove any zone whose coords are within its radius of a point
-- ============================================================

local function removeZonesAt(coords)
    for zoneId, zone in pairs(Traffic.activeZones) do
        if zone then
            local dist = #(coords - zone.coords)
            if dist <= zone.radius then
                RemoveSpeedZone(zone.speedZone)
                RemoveBlip(zone.blip)
                if zone.radiusBlip then RemoveBlip(zone.radiusBlip) end
                Traffic.activeZones[zoneId] = nil
            end
        end
    end
end

-- ============================================================
--  Create blip + radius blip for a zone
--  Returns: blip, radiusBlip
-- ============================================================

local function createZoneBlips(coords, name, radius)
    local blipCfg = Config.Traffic.BlipSettings

    local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(blip, blipCfg.sprite)
    SetBlipColour(blip, blipCfg.color)
    SetBlipScale(blip, blipCfg.scale)
    SetBlipRoute(blip, false)

    if blipCfg.showLabel then
        BeginTextCommandSetBlipName("STRING")
        AddTextComponentString(name)
        EndTextCommandSetBlipName(blip)
    end

    local radiusBlip = AddBlipForRadius(coords.x, coords.y, coords.z, radius)
    SetBlipColour(radiusBlip, blipCfg.color)
    SetBlipAlpha(radiusBlip, 50)

    return blip, radiusBlip
end

-- ============================================================
--  Draw marker for a zone (called each frame)
-- ============================================================

local function drawZoneMarker(coords, radius)
    local mCfg = Config.Traffic.MarkerSettings
    DrawMarker(
        mCfg.type,
        coords.x, coords.y, coords.z,
        0.0, 0.0, 0.0,
        0.0, 180.0, 0.0,
        radius * 2, radius * 2, 10.0,
        mCfg.color.r, mCfg.color.g, mCfg.color.b, mCfg.color.a,
        false, true, 2, nil, nil, false)
end

-- ============================================================
--  createZone
-- ============================================================

function Traffic.createZone(self, _, radius)
    if not hasJobAccess() then
        Bridge.Notify.showNotify(locale("traffic_no_access"), "error")
        return
    end

    radius = radius or Config.Traffic.DefaultRadius

    local result = lib.inputDialog(locale("traffic_dialog_create_zone"), {
        {
            type     = "input",
            label    = locale("traffic_dialog_name"),
            required = true,
            default  = "Zone_" .. tostring(math.floor(GetGameTimer() % 10000)),
        },
        {
            type     = "number",
            label    = locale("traffic_dialog_speed"),
            min      = 0,
            default  = 30,
            required = true,
        },
    })
    if not result then return end

    local zoneName  = result[1]
    local speed     = result[2]
    local coords    = GetEntityCoords(cache.ped)

    removeZonesAt(coords)

    local zoneId   = #Traffic.activeZones + 1
    local speedZone = AddSpeedZoneForCoord(coords.x, coords.y, coords.z, radius, speed, false)
    local blip, radiusBlip = createZoneBlips(coords, zoneName, radius)

    Traffic.activeZones[zoneId] = {
        id        = zoneId,
        name      = zoneName,
        coords    = coords,
        radius    = radius,
        speedLimit = speed,
        speedZone = speedZone,
        blip      = blip,
        radiusBlip = radiusBlip,
        createdAt = GetGameTimer(),
    }

    Bridge.Notify.showNotify(locale("traffic_zone_created", zoneName), "success")
    return zoneId
end

-- ============================================================
--  editZoneRadius
-- ============================================================

function Traffic.editZoneRadius(self, zoneId)
    if not hasJobAccess() then
        Bridge.Notify.showNotify(locale("traffic_no_access"), "error"); return
    end

    local zone = Traffic.activeZones[zoneId]
    if not zone then
        Bridge.Notify.showNotify(locale("traffic_zone_not_found"), "error"); return
    end

    local result = lib.inputDialog(locale("traffic_edit_radius"), {
        {
            type     = "number",
            label    = locale("traffic_dialog_radius"),
            min      = Config.Traffic.MinRadius,
            max      = Config.Traffic.MaxRadius,
            default  = zone.radius,
            required = true,
        },
    })
    if not result then return end

    local newRadius = result[1]
    RemoveSpeedZone(zone.speedZone)
    Citizen.Wait(10)

    zone.speedZone = AddSpeedZoneForCoord(
        zone.coords.x, zone.coords.y, zone.coords.z,
        newRadius, zone.speedLimit, false)
    zone.radius = newRadius

    -- Update radius blip
    if zone.radiusBlip then
        RemoveBlip(zone.radiusBlip)
        local _, radiusBlip = createZoneBlips(zone.coords, zone.name, newRadius)
        zone.radiusBlip = radiusBlip
    end

    Bridge.Notify.showNotify(locale("traffic_radius_updated", newRadius), "success")
end

-- ============================================================
--  editZoneSpeed
-- ============================================================

function Traffic.editZoneSpeed(self, zoneId)
    if not hasJobAccess() then
        Bridge.Notify.showNotify(locale("traffic_no_access"), "error"); return
    end

    local zone = Traffic.activeZones[zoneId]
    if not zone then
        Bridge.Notify.showNotify(locale("traffic_zone_not_found"), "error"); return
    end

    local result = lib.inputDialog(locale("traffic_edit_speed"), {
        {
            type     = "number",
            label    = locale("traffic_dialog_speed"),
            min      = 0,
            default  = zone.speedLimit,
            required = true,
        },
    })
    if not result then return end

    local newSpeed = result[1]
    RemoveSpeedZone(zone.speedZone)
    Citizen.Wait(10)

    zone.speedZone = AddSpeedZoneForCoord(
        zone.coords.x, zone.coords.y, zone.coords.z,
        zone.radius, newSpeed, false)
    zone.speedLimit = newSpeed

    Bridge.Notify.showNotify(locale("traffic_speed_updated", newSpeed), "success")
end

-- ============================================================
--  removeZone
-- ============================================================

function Traffic.removeZone(self, zoneId)
    if not hasJobAccess() then
        Bridge.Notify.showNotify(locale("traffic_no_access"), "error"); return
    end

    local zone = Traffic.activeZones[zoneId]
    if not zone then
        Bridge.Notify.showNotify(locale("traffic_zone_not_found"), "error"); return
    end

    RemoveSpeedZone(zone.speedZone)
    RemoveBlip(zone.blip)
    if zone.radiusBlip then RemoveBlip(zone.radiusBlip) end
    Traffic.activeZones[zoneId] = nil

    Bridge.Notify.showNotify(locale("traffic_zone_removed", zone.name), "success")
end

-- ============================================================
--  listZones — context menu of all active zones
-- ============================================================

function Traffic.listZones(self)
    if not hasJobAccess() then
        Bridge.Notify.showNotify(locale("traffic_no_access"), "error"); return
    end

    local options = {}
    for zoneId, zone in pairs(Traffic.activeZones) do
        if zone then
            local id = zoneId
            options[#options + 1] = {
                title       = zone.name,
                description = locale("traffic_zone_desc"):format(zone.speedLimit, zone.radius),
                args        = { zoneId = id },
                icon        = "fa-solid fa-road",
            }
        end
    end

    if #options == 0 then
        Bridge.Notify.showNotify(locale("traffic_no_zones"), "warning"); return
    end

    lib.registerContext({
        id      = "traffic_zones_list",
        title   = locale("traffic_active_zones"),
        options = options,
        onSelect = function(selected)
            Traffic:showZoneMenu(selected.args.zoneId)
        end,
    })
    lib.showContext("traffic_zones_list")
end

-- ============================================================
--  showZoneMenu — per-zone action sub-menu
-- ============================================================

function Traffic.showZoneMenu(self, zoneId)
    local zone = Traffic.activeZones[zoneId]
    if not zone then return end

    lib.registerContext({
        id    = "traffic_zone_menu_" .. zoneId,
        title = zone.name,
        menu  = "traffic_zones_list",
        options = {
            {
                title       = locale("traffic_edit_radius"),
                description = locale("traffic_edit_radius_desc"):format(zone.radius),
                icon        = "fa-solid fa-expand",
                onSelect    = function()
                    Traffic:editZoneRadius(zoneId)
                    Citizen.Wait(500)
                    Traffic:showZoneMenu(zoneId)
                end,
            },
            {
                title       = locale("traffic_edit_speed"),
                description = locale("traffic_edit_speed_desc"):format(zone.speedLimit),
                icon        = "fa-solid fa-gauge",
                onSelect    = function()
                    Traffic:editZoneSpeed(zoneId)
                    Citizen.Wait(500)
                    Traffic:showZoneMenu(zoneId)
                end,
            },
            {
                title    = locale("traffic_goto_zone"),
                icon     = "fa-solid fa-map-pin",
                onSelect = function()
                    local heading = GetEntityHeading(cache.ped)
                    SetEntityCoords(cache.ped,
                        zone.coords.x, zone.coords.y, zone.coords.z,
                        false, false, false, false)
                    SetEntityHeading(cache.ped, heading)
                    Bridge.Notify.showNotify(
                        locale("traffic_zone_teleported"):format(zone.name), "success")
                end,
            },
            {
                title       = locale("traffic_delete_zone"),
                description = locale("traffic_delete_zone_desc"),
                icon        = "fa-solid fa-trash",
                onSelect    = function()
                    Traffic:removeZone(zoneId)
                    lib.hideContext()
                end,
            },
        },
    })
    lib.showContext("traffic_zone_menu_" .. zoneId)
end

-- ============================================================
--  applyPreset
-- ============================================================

function Traffic.applyPreset(self, presetIndex)
    if not hasJobAccess() then
        Bridge.Notify.showNotify(locale("traffic_no_access"), "error"); return
    end

    local preset = Config.Traffic.Presets[presetIndex]
    if not preset then
        Bridge.Notify.showNotify(locale("traffic_preset_not_found"), "error"); return
    end

    local zoneName = preset.label .. "_" .. tostring(math.floor(GetGameTimer() % 10000))
    local coords   = GetEntityCoords(cache.ped)

    removeZonesAt(coords)

    local zoneId    = #Traffic.activeZones + 1
    local speedZone = AddSpeedZoneForCoord(coords.x, coords.y, coords.z, preset.radius, preset.speed, false)
    local blip, radiusBlip = createZoneBlips(coords, zoneName, preset.radius)

    Traffic.activeZones[zoneId] = {
        id        = zoneId,
        name      = zoneName,
        coords    = coords,
        radius    = preset.radius,
        speedLimit = preset.speed,
        speedZone = speedZone,
        blip      = blip,
        radiusBlip = radiusBlip,
        createdAt = GetGameTimer(),
    }

    Bridge.Notify.showNotify(locale("traffic_preset_applied", preset.label), "success")
    return zoneId
end

-- ============================================================
--  showPresetsMenu
-- ============================================================

function Traffic.showPresetsMenu(self)
    if not hasJobAccess() then
        Bridge.Notify.showNotify(locale("traffic_no_access"), "error"); return
    end

    local options = {}
    for i, preset in ipairs(Config.Traffic.Presets) do
        local idx = i
        options[#options + 1] = {
            title       = preset.label,
            description = locale("traffic_zone_desc"):format(preset.speed, preset.radius),
            icon        = "fa-solid fa-sliders",
            onSelect    = function() Traffic:applyPreset(idx) end,
        }
    end

    lib.registerContext({
        id      = "traffic_presets_menu",
        title   = locale("traffic_presets_title"),
        options = options,
    })
    lib.showContext("traffic_presets_menu")
end

-- ============================================================
--  showMainMenu
-- ============================================================

function Traffic.showMainMenu(self)
    if not hasJobAccess() then
        Bridge.Notify.showNotify(locale("traffic_no_access"), "error"); return
    end

    lib.registerContext({
        id    = "traffic_main_menu",
        title = locale("traffic_menu_title"),
        options = {
            {
                title       = locale("traffic_create_zone"),
                description = locale("traffic_create_zone_desc"),
                icon        = "fa-solid fa-plus",
                onSelect    = function() Traffic:createZone() end,
            },
            {
                title       = locale("traffic_apply_preset"),
                description = locale("traffic_apply_preset_desc"),
                icon        = "fa-solid fa-star",
                onSelect    = function() Traffic:showPresetsMenu() end,
            },
            {
                title       = locale("traffic_manage_zones"),
                description = locale("traffic_manage_zones_desc"),
                icon        = "fa-solid fa-sliders",
                onSelect    = function() Traffic:listZones() end,
            },
            {
                title       = locale("traffic_clear_all"),
                description = locale("traffic_clear_all_desc"),
                icon        = "fa-solid fa-ban",
                onSelect    = function()
                    for zoneId in pairs(Traffic.activeZones) do
                        Traffic:removeZone(zoneId)
                    end
                    Bridge.Notify.showNotify(locale("traffic_zones_cleared"), "success")
                    lib.hideContext()
                end,
            },
        },
    })
    lib.showContext("traffic_main_menu")
end

-- ============================================================
--  /trafficmenu command
-- ============================================================

RegisterCommand("trafficmenu", function() Traffic:showMainMenu() end, false)
TriggerEvent("chat:addSuggestion", "/trafficmenu", "Open traffic management menu", {})

-- ============================================================
--  Exports
-- ============================================================

exports("createTrafficZone", function(name, radius, speed)
    if not hasJobAccess() then return nil end
    local coords   = GetEntityCoords(cache.ped)
    radius = radius or Config.Traffic.DefaultRadius
    speed  = speed  or 0.0

    removeZonesAt(coords)

    local zoneId    = #Traffic.activeZones + 1
    local speedZone = AddSpeedZoneForCoord(coords.x, coords.y, coords.z, radius, speed, false)
    local zoneName  = name or ("Zone_" .. zoneId)
    local blip, radiusBlip = createZoneBlips(coords, zoneName, radius)

    Traffic.activeZones[zoneId] = {
        id        = zoneId,
        name      = zoneName,
        coords    = coords,
        radius    = radius,
        speedLimit = speed,
        speedZone = speedZone,
        blip      = blip,
        radiusBlip = radiusBlip,
        createdAt = GetGameTimer(),
    }
    return zoneId
end)

exports("removeTrafficZone",  function(zoneId)           Traffic:removeZone(zoneId) end)
exports("getActiveZones",     function()                  return Traffic.activeZones end)
exports("getZoneInfo",        function(zoneId)            return Traffic.activeZones[zoneId] end)
exports("applyTrafficPreset", function(presetIndex)       return Traffic:applyPreset(presetIndex) end)

exports("updateTrafficZone", function(zoneId, newRadius, newSpeed)
    local zone = Traffic.activeZones[zoneId]
    if not zone then return false end
    if newRadius then Traffic:editZoneRadius(zoneId) end
    if newSpeed  then Traffic:editZoneSpeed(zoneId)  end
    return true
end)
