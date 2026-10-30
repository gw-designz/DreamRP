-- Handlers for commands the server has already authorised (npv_admin:client:exec) plus the
-- small effects the server triggers on other players.

local Exec = {}
local state = { god = false, cloak = false, frozen = false }

local function notify(text, kind)
    lib.notify({ description = text, type = kind or 'inform' })
end

local function loadModel(model)
    local hash = type(model) == 'number' and model or joaat(model)
    if not IsModelInCdimage(hash) or not IsModelValid(hash) then return nil end
    lib.requestModel(hash, 5000)
    return hash
end

local function closestVehicle()
    local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped, false)
    if veh ~= 0 then return veh end
    return lib.getClosestVehicle(GetEntityCoords(ped), 6.0, true)
end

function Exec.admin_mode()
    ClientAdminToggle(not AdminMode)
    notify(AdminMode and 'Admin mode on' or 'Admin mode off')
end

function Exec.dm_tool()
    DmRadial.Toggle()
end

function Exec.noclip() Noclip.Toggle() end

function Exec.god_mode()
    state.god = not state.god
    SetPlayerInvincible(PlayerId(), state.god)
    notify(state.god and 'God mode on' or 'God mode off')
end

function Exec.cloak()
    state.cloak = not state.cloak
    local ped = PlayerPedId()
    SetEntityVisible(ped, not state.cloak, false)
    if state.cloak then
        -- Others cannot see you; keep yourself visible locally so you do not lose your own ped.
        CreateThread(function()
            while state.cloak do
                SetLocalPlayerVisibleLocally(true)
                SetEntityAlpha(PlayerPedId(), 120, false)
                Wait(0)
            end
            ResetEntityAlpha(PlayerPedId())
        end)
    end
    notify(state.cloak and 'Cloaked' or 'Visible again')
end

function Exec.heal_self()
    local ped = PlayerPedId()
    SetEntityHealth(ped, GetEntityMaxHealth(ped))
    SetPedArmour(ped, 100)
end

function Exec.change_my_model(args)
    local hash = loadModel(args.model)
    if not hash then return notify('Unknown ped model: ' .. tostring(args.model), 'error') end
    SetPlayerModel(PlayerId(), hash)
    SetModelAsNoLongerNeeded(hash)
    SetPedDefaultComponentVariation(PlayerPedId())
end

function Exec.copy_coords(args)
    local ped = PlayerPedId()
    local c, h = GetEntityCoords(ped), GetEntityHeading(ped)
    local fmt = args.format
    local text
    if fmt == 'vector3' then text = ('vec3(%.3f, %.3f, %.3f)'):format(c.x, c.y, c.z)
    elseif fmt == 'json' then text = json.encode({ x = c.x, y = c.y, z = c.z, h = h })
    else text = ('vec4(%.3f, %.3f, %.3f, %.2f)'):format(c.x, c.y, c.z, h) end
    lib.setClipboard(text)
    notify('Copied ' .. text)
end

local lastCoords -- where we were before the last teleport ("Teleport Back")

local function teleportTo(x, y, z)
    local ped = PlayerPedId()
    lastCoords = GetEntityCoords(ped)
    local ent = GetVehiclePedIsIn(ped, false)
    if ent == 0 then ent = ped end
    DoScreenFadeOut(150)
    while not IsScreenFadedOut() do Wait(0) end
    RequestCollisionAtCoord(x, y, z)
    SetEntityCoords(ent, x, y, z, false, false, false, false)
    local tries = 0
    while not HasCollisionLoadedAroundEntity(ent) and tries < 100 do Wait(10) tries = tries + 1 end
    DoScreenFadeIn(250)
end

function Exec.tp_coords(args) teleportTo(args.x, args.y, args.z) end

function Exec.tp_waypoint()
    local blip = GetFirstBlipInfoId(8)
    if not DoesBlipExist(blip) then return notify('Set a waypoint first', 'error') end
    local c = GetBlipInfoIdCoord(blip)
    -- Probe downward for the ground, then go.
    local z = 1000.0
    local found = false
    for height = 1000, 0, -25 do
        RequestCollisionAtCoord(c.x, c.y, height + 0.0)
        Wait(0)
        local ok, gz = GetGroundZFor_3dCoord(c.x, c.y, height + 0.0, false)
        if ok then z = gz found = true break end
    end
    teleportTo(c.x, c.y, found and z + 1.0 or 50.0)
end

function Exec.clean_vehicle()
    local veh = closestVehicle()
    if not veh then return notify('No vehicle nearby', 'error') end
    SetVehicleDirtLevel(veh, 0.0)
    WashDecalsFromVehicle(veh, 1.0)
end

function Exec.fix_vehicle()
    local veh = closestVehicle()
    if not veh then return notify('No vehicle nearby', 'error') end
    SetVehicleFixed(veh)
    SetVehicleDeformationFixed(veh)
    SetVehicleEngineHealth(veh, 1000.0)
    SetVehicleUndriveable(veh, false)
end

function Exec.delete_vehicle()
    local veh = closestVehicle()
    if not veh then return notify('No vehicle nearby', 'error') end
    SetEntityAsMissionEntity(veh, true, true)
    DeleteEntity(veh)
end

function Exec.spawn_vehicle(args)
    local hash = loadModel(args.model)
    if not hash then return notify('Unknown vehicle model: ' .. tostring(args.model), 'error') end
    local ped = PlayerPedId()
    local c, h = GetEntityCoords(ped), GetEntityHeading(ped)
    local veh = CreateVehicle(hash, c.x, c.y, c.z, h, true, false)
    SetModelAsNoLongerNeeded(hash)
    if veh == 0 then return notify('Could not spawn vehicle', 'error') end
    SetPedIntoVehicle(ped, veh, -1)
    SetVehicleNeedsToBeHotwired(veh, false)
    SetVehicleEngineOn(veh, true, true, false)
end

function Exec.clear_area(args)
    local c = GetEntityCoords(PlayerPedId())
    local r = args.radius + 0.0
    local n = 0
    local pool = args.what == 'vehicles' and GetGamePool('CVehicle')
        or args.what == 'people' and GetGamePool('CPed') or GetGamePool('CObject')
    local me, myVeh = PlayerPedId(), GetVehiclePedIsIn(PlayerPedId(), false)
    for _, e in ipairs(pool) do
        if e ~= me and e ~= myVeh and #(GetEntityCoords(e) - c) <= r then
            local skip = false
            if args.what == 'people' and IsPedAPlayer(e) then skip = true end
            if args.what == 'vehicles' and not IsVehicleSeatFree(e, -1) and IsPedAPlayer(GetPedInVehicleSeat(e, -1)) then skip = true end
            if not skip and NetworkGetEntityIsNetworked(e) and not NetworkHasControlOfEntity(e) then
                NetworkRequestControlOfEntity(e)
            end
            if not skip then
                SetEntityAsMissionEntity(e, true, true)
                DeleteEntity(e)
                n = n + 1
            end
        end
    end
    notify(('Removed %d %s'):format(n, args.what))
end

function Exec.delete_closest_object()
    local c = GetEntityCoords(PlayerPedId())
    local obj = lib.getClosestObject(c, 4.0)
    if not obj then return notify('No object nearby', 'error') end
    SetEntityAsMissionEntity(obj, true, true)
    DeleteEntity(obj)
end

function Exec.clear_wanted()
    ClearPlayerWantedLevel(PlayerId())
end

RegisterNetEvent('npv_admin:client:exec', function(id, args, force)
    local fn = Exec[id]
    if not fn then return end
    fn(args or {})
end)

-- Effects aimed at other players ---------------------------------------------------------------
RegisterNetEvent('npv_admin:client:message', function(text, kind)
    lib.notify({ description = text, type = kind == 'warn' and 'warning' or 'inform', duration = 8000 })
end)

RegisterNetEvent('npv_admin:client:announce', function(text, seconds)
    Nui.Send('announce', { text = text, seconds = seconds })
end)

RegisterNetEvent('npv_admin:client:heal', function()
    local ped = PlayerPedId()
    SetEntityHealth(ped, GetEntityMaxHealth(ped))
    SetPedArmour(ped, 100)
end)

RegisterNetEvent('npv_admin:client:revive', function(reviveEvent)
    local ped = PlayerPedId()
    if reviveEvent and reviveEvent ~= '' then TriggerEvent(reviveEvent) end
    Wait(300)
    if IsEntityDead(ped) or IsPedFatallyInjured(ped) then
        local c = GetEntityCoords(ped)
        NetworkResurrectLocalPlayer(c.x, c.y, c.z, GetEntityHeading(ped), true, false)
        ClearPedBloodDamage(PlayerPedId())
    end
    SetEntityHealth(PlayerPedId(), GetEntityMaxHealth(PlayerPedId()))
end)

RegisterNetEvent('npv_admin:client:freeze', function(on)
    state.frozen = on
    FreezeEntityPosition(PlayerPedId(), on)
end)

-- Kick "kidnap" scene (adapted from sizan19/fivem-kick) ---------------------------------------
local KICK_DICT = 'random@kidnap_girl'
local KICK_RADII = { 4.0, 6.0, 9.0, 12.0, 16.0, 21.0, 27.0, 34.0, 42.0 }
local KICK_ANGLES = 12

local function shapeHit(handle)
    local status, hit
    repeat
        Wait(0)
        status, hit = GetShapeTestResult(handle)
    until status ~= 1
    return hit == true or hit == 1
end

-- The van plus a strip on its right (sliding door) side where the player and guard stand.
-- Fails if anything in that box is world geometry, a vehicle or an object, or the spot is in an MLO.
local function kickSpotClear(c, heading, ignore)
    local r = math.rad(heading)
    local right = vector3(math.cos(r), math.sin(r), 0.0)
    local side = c + right * 2.3
    if GetInteriorAtCoords(c.x, c.y, c.z) ~= 0 or GetInteriorAtCoords(side.x, side.y, side.z) ~= 0 then return false end
    local mid = c + right * 1.2
    return not shapeHit(StartShapeTestBox(mid.x, mid.y, mid.z + 1.4, 4.6, 6.0, 2.4, 0.0, 0.0, heading, 2, 1 | 2 | 16, ignore, 4))
end

local function groundAt(x, y, fromZ)
    local found, z = GetGroundZFor_3dCoord(x, y, fromZ, false)
    return found and z or nil
end

---Nearest outdoor spot around the ped with room for the whole scene. Returns coords, heading.
local function findKickSpot(ped)
    local pos, heading = GetEntityCoords(ped), GetEntityHeading(ped)
    local indoors = GetInteriorFromEntity(ped) ~= 0
    local maxDrop = indoors and 15.0 or 3.0 -- upstairs in an MLO the street can be well below us

    local first = GetOffsetFromEntityInWorldCoords(ped, 2.5, 1.0, 0.0)
    local z = not indoors and groundAt(first.x, first.y, pos.z + 2.0)
    if z and kickSpotClear(vector3(first.x, first.y, z), heading, ped) then return vector3(first.x, first.y, z), heading end

    for _, radius in ipairs(KICK_RADII) do
        for i = 0, KICK_ANGLES - 1 do
            local a = (i / KICK_ANGLES) * 2.0 * math.pi
            local x, y = pos.x + math.cos(a) * radius, pos.y + math.sin(a) * radius
            local gz = groundAt(x, y, pos.z + 3.0)
            if gz and math.abs(gz - pos.z) <= maxDrop then
                local c = vector3(x, y, gz)
                -- Face the van so its door side points back toward where the player was, then try the reverse.
                local toPlayer = math.deg(math.atan(pos.y - y, pos.x - x))
                for _, h in ipairs({ toPlayer, toPlayer + 180.0 }) do
                    h = h % 360.0
                    if kickSpotClear(c, h, ped) then return c, h end
                end
            end
        end
    end

    -- Last resort: the nearest road node is always outside.
    local found, node, nodeHeading = GetClosestVehicleNodeWithHeading(pos.x, pos.y, pos.z, 1, 3.0, 0)
    if found and GetInteriorAtCoords(node.x, node.y, node.z) == 0 then return node, nodeHeading end
    return vector3(first.x, first.y, pos.z), heading
end

RegisterNetEvent('npv_admin:client:kickScene', function()
    local guard, van
    local ok = pcall(function()
        local guardModel = lib.requestModel(Config.KickSceneGuard, 5000)
        local vanModel = lib.requestModel(Config.KickSceneVan, 5000)
        lib.requestAnimDict(KICK_DICT, 5000)

        local ped = PlayerPedId()
        if IsPedInAnyVehicle(ped, false) then
            local c = GetEntityCoords(ped)
            SetEntityCoords(ped, c.x, c.y, c.z + 1.0, false, false, false, false)
        end
        if IsEntityDead(ped) then
            local c = GetEntityCoords(ped)
            NetworkResurrectLocalPlayer(c.x, c.y, c.z, GetEntityHeading(ped), true, false)
            ped = PlayerPedId()
        end
        ClearPedTasksImmediately(ped)
        FreezeEntityPosition(ped, false)

        -- Always spawn our own van so we never drive off with someone's real vehicle, and never
        -- inside a building/MLO: walk the player out to the nearest open spot first.
        local spot, vanHeading = findKickSpot(ped)
        local r = math.rad(vanHeading)
        local stand = spot + vector3(math.cos(r), math.sin(r), 0.0) * 2.3
        SetEntityCoords(ped, stand.x, stand.y, stand.z, false, false, false, false)
        SetEntityHeading(ped, vanHeading)
        van = CreateVehicle(vanModel, spot.x, spot.y, spot.z, vanHeading, true, false)
        SetVehicleOnGroundProperly(van)
        SetVehicleDoorsLocked(van, 2)
        guard = CreatePed(4, guardModel, spot.x - 1.5, spot.y, spot.z, 0.0, true, true)
        SetBlockingOfNonTemporaryEvents(guard, true)
        SetPedCanRagdoll(guard, false)
        SetModelAsNoLongerNeeded(guardModel)
        SetModelAsNoLongerNeeded(vanModel)

        local scene = NetworkCreateSynchronisedScene(GetEntityCoords(van), GetEntityRotation(van, 2), 2, false, false, 1.0, 0, 1.0)
        NetworkAddPedToSynchronisedScene(ped, scene, KICK_DICT, 'ig_1_girl_drag_into_van', 8.0, -4.0, 1, 16, 0, 0)
        NetworkAddPedToSynchronisedScene(guard, scene, KICK_DICT, 'ig_1_guy2_drag_into_van', 8.0, -4.0, 1, 16, 0, 0)
        NetworkAddEntityToSynchronisedScene(van, scene, KICK_DICT, 'drag_into_van_burr', 1.0, 1.0, 1)
        NetworkStartSynchronisedScene(scene)

        local untilTime = GetGameTimer() + math.floor(GetAnimDuration(KICK_DICT, 'drag_into_van_burr') * 1000)
        while GetGameTimer() < untilTime do
            DisableAllControlActions(0)
            Wait(0)
        end
        RemoveAnimDict(KICK_DICT)
    end)
    -- They are "inside" the van now; hide and pin them so nothing is seen before the drop lands.
    local ped = PlayerPedId()
    SetEntityVisible(ped, false, false)
    FreezeEntityPosition(ped, true)
    if not ok then print('[npv_admin] kick scene failed, dropping without it') end
    if guard and DoesEntityExist(guard) then DeleteEntity(guard) end
    if van and DoesEntityExist(van) then DeleteEntity(van) end
    TriggerServerEvent('npv_admin:server:kickSceneDone')
end)

-- Spectate ---------------------------------------------------------------------------------------
local spectating, returnCoords = false, nil
RegisterNetEvent('npv_admin:client:spectate', function(target, netId, coords)
    local ped = PlayerPedId()
    if not target then
        if spectating then
            spectating = false
            NetworkSetInSpectatorMode(false, ped)
            if returnCoords then SetEntityCoords(ped, returnCoords.x, returnCoords.y, returnCoords.z, false, false, false, false) end
            FreezeEntityPosition(ped, false)
            SetEntityVisible(ped, true, false)
        end
        return
    end
    returnCoords = GetEntityCoords(ped)
    -- Move close enough for the target to stream in, then attach the spectator camera.
    SetEntityCoords(ped, coords.x, coords.y, coords.z - 10.0, false, false, false, false)
    FreezeEntityPosition(ped, true)
    SetEntityVisible(ped, false, false)
    local timeout = GetGameTimer() + 5000
    local tped
    while GetGameTimer() < timeout do
        local ply = GetPlayerFromServerId(target)
        tped = ply ~= -1 and GetPlayerPed(ply) or 0
        if tped and tped ~= 0 then break end
        Wait(100)
    end
    if not tped or tped == 0 then
        SetEntityCoords(ped, returnCoords.x, returnCoords.y, returnCoords.z, false, false, false, false)
        FreezeEntityPosition(ped, false)
        SetEntityVisible(ped, true, false)
        return notify('Could not stream the target in', 'error')
    end
    spectating = true
    NetworkSetInSpectatorMode(true, tped)
    notify('Spectating. Run Spectate with no target to stop.')
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    local ped = PlayerPedId()
    SetEntityAlpha(ped, 255, false)
    SetEntityVisible(ped, true, false)
    SetPlayerInvincible(PlayerId(), false)
    if spectating then NetworkSetInSpectatorMode(false, ped) end
end)

-- ---- commands ported from codera-adminmenu ---------------------------------------------------------

function Exec.teleport_back()
    if not lastCoords then return notify('No previous position saved', 'error') end
    local target = lastCoords
    teleportTo(target.x, target.y, target.z)
end

function Exec.teleport_location(args)
    for _, l in ipairs(Config.Locations) do
        if l.label == args.location then
            teleportTo(l.coords.x, l.coords.y, l.coords.z)
            SetEntityHeading(PlayerPedId(), l.coords.w)
            return
        end
    end
    notify('Unknown location', 'error')
end

function Exec.set_ammo(args)
    local ped = PlayerPedId()
    local weapon = GetSelectedPedWeapon(ped)
    if weapon == joaat('WEAPON_UNARMED') then return notify('You are not holding a weapon', 'error') end
    SetPedAmmo(ped, weapon, math.floor(args.amount))
    notify(('Ammo set to %d'):format(args.amount))
end

local ammo = false
function Exec.infinite_ammo()
    ammo = not ammo
    local ped = PlayerPedId()
    SetPedInfiniteAmmoClip(ped, ammo)
    SetPedInfiniteAmmo(ped, ammo, GetSelectedPedWeapon(ped))
    notify(ammo and 'Infinite ammo on' or 'Infinite ammo off')
end

function Exec.refuel_vehicle()
    local veh = GetVehiclePedIsIn(PlayerPedId(), false)
    if veh == 0 then return notify('You are not in a vehicle', 'error') end
    SetVehicleFuelLevel(veh, 100.0)
    Entity(veh).state:set('fuel', 100.0, true) -- ox_fuel and most fuel scripts read this
    notify('Vehicle refuelled')
end

function Exec.max_mods()
    local veh = GetVehiclePedIsIn(PlayerPedId(), false)
    if veh == 0 then return notify('You are not in a vehicle', 'error') end
    SetVehicleModKit(veh, 0)
    for modType = 0, 49 do
        if modType < 17 or modType > 22 then
            local count = GetNumVehicleMods(veh, modType)
            if count > 0 then SetVehicleMod(veh, modType, count - 1, false) end
        end
    end
    ToggleVehicleMod(veh, 18, true)
    ToggleVehicleMod(veh, 20, true)
    ToggleVehicleMod(veh, 22, true)
    SetVehicleWindowTint(veh, 1)
    notify('Vehicle mods maxed')
end

function Exec.change_plate(args)
    local veh = GetVehiclePedIsIn(PlayerPedId(), false)
    if veh == 0 then return notify('You are not in a vehicle', 'error') end
    local plate = args.plate:upper():gsub('[^%w ]', ''):sub(1, 8)
    if plate == '' then return notify('Enter a plate', 'error') end
    SetVehicleNumberPlateText(veh, plate)
    notify('Plate changed to ' .. plate)
end

function Exec.admin_car()
    local veh = GetVehiclePedIsIn(PlayerPedId(), false)
    if veh == 0 then return notify('You have to be in a vehicle', 'error') end
    local props = lib.getVehicleProperties(veh)
    if not props then return notify('Could not read vehicle properties', 'error') end
    local ok, msg = lib.callback.await('npv_admin:adminCar', false, {
        model = GetEntityArchetypeName(veh),
        props = props,
    })
    notify(msg or (ok and 'This vehicle is now yours.' or 'Could not save vehicle'), ok and 'success' or 'error')
end

-- Overlays ---------------------------------------------------------------------------------------
local overlay = { coords = false, names = false, blips = false }

local function drawText2D(x, y, text, scale)
    SetTextFont(4)
    SetTextScale(0.0, scale or 0.4)
    SetTextColour(255, 255, 255, 230)
    SetTextOutline()
    BeginTextCommandDisplayText('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayText(x, y)
end

function Exec.toggle_coords()
    overlay.coords = not overlay.coords
    if not overlay.coords then return end
    CreateThread(function()
        while overlay.coords do
            local ped = PlayerPedId()
            local c = GetEntityCoords(ped)
            drawText2D(0.015, 0.02, ('X: %.2f  Y: %.2f  Z: %.2f  H: %.2f'):format(c.x, c.y, c.z, GetEntityHeading(ped)))
            Wait(0)
        end
    end)
end

function Exec.toggle_names()
    overlay.names = not overlay.names
    notify(overlay.names and 'Player names on' or 'Player names off')
    if not overlay.names then return end
    CreateThread(function()
        while overlay.names do
            local mine = GetEntityCoords(PlayerPedId())
            for _, ply in ipairs(GetActivePlayers()) do
                local ped = GetPlayerPed(ply)
                local c = GetEntityCoords(ped)
                if #(mine - c) < 250.0 then
                    local onScreen, sx, sy = World3dToScreen2d(c.x, c.y, c.z + 1.1)
                    if onScreen then
                        SetTextFont(4) SetTextScale(0.0, 0.32) SetTextCentre(true) SetTextOutline()
                        SetTextColour(255, 255, 255, 230)
                        BeginTextCommandDisplayText('STRING')
                        AddTextComponentSubstringPlayerName(('[%d] %s'):format(GetPlayerServerId(ply), GetPlayerName(ply)))
                        EndTextCommandDisplayText(sx, sy)
                    end
                end
            end
            Wait(0)
        end
    end)
end

local blips = {}
local function clearBlips()
    for id, blip in pairs(blips) do
        if DoesBlipExist(blip) then RemoveBlip(blip) end
        blips[id] = nil
    end
end

function Exec.toggle_blips()
    overlay.blips = not overlay.blips
    notify(overlay.blips and 'Player blips on' or 'Player blips off')
    if not overlay.blips then clearBlips() return end
    CreateThread(function()
        while overlay.blips do
            TriggerServerEvent('npv_admin:server:requestBlips')
            Wait(1500)
        end
        clearBlips()
    end)
end

RegisterNetEvent('npv_admin:client:blipsData', function(list)
    if not overlay.blips then return end
    local me = GetPlayerServerId(PlayerId())
    local seen = {}
    for _, e in ipairs(list) do
        if e.id ~= me then
            seen[e.id] = true
            local blip = blips[e.id]
            if not blip or not DoesBlipExist(blip) then
                blip = AddBlipForCoord(e.x, e.y, e.z)
                SetBlipSprite(blip, 1)
                SetBlipColour(blip, 3)
                SetBlipScale(blip, 0.85)
                SetBlipAsShortRange(blip, false)
                BeginTextCommandSetBlipName('STRING')
                AddTextComponentSubstringPlayerName(('[%d] %s'):format(e.id, e.name))
                EndTextCommandSetBlipName(blip)
                blips[e.id] = blip
            else
                SetBlipCoords(blip, e.x, e.y, e.z)
            end
        end
    end
    for id, blip in pairs(blips) do
        if not seen[id] then
            if DoesBlipExist(blip) then RemoveBlip(blip) end
            blips[id] = nil
        end
    end
end)

-- Events aimed at the staff member or at a target ---------------------------------------------------
RegisterNetEvent('npv_admin:client:openInventory', function(kind, id)
    if GetResourceState('ox_inventory') ~= 'started' then return end
    if kind == 'player' then exports.ox_inventory:openInventory('player', id)
    elseif kind == 'trunk' then exports.ox_inventory:openInventory('trunk', { id = 'trunk' .. id })
    else exports.ox_inventory:openInventory('stash', id) end
end)

local muted = {}
RegisterNetEvent('npv_admin:client:mute', function(target)
    if GetResourceState('pma-voice') ~= 'started' then return notify('pma-voice is not running', 'error') end
    exports['pma-voice']:toggleMutePlayer(target)
    muted[target] = not muted[target]
    notify(('Player %d %s'):format(target, muted[target] and 'muted' or 'unmuted'))
end)

RegisterNetEvent('npv_admin:client:drunk', function(duration)
    local untilTime = GetGameTimer() + (tonumber(duration) or 30000)
    CreateThread(function()
        while GetGameTimer() < untilTime do
            ShakeGameplayCam('DRUNK_SHAKE', 1.2)
            SetPedMotionBlur(PlayerPedId(), true)
            SetTimecycleModifier('drug_drive_incar_01')
            Wait(0)
        end
        StopGameplayCamShaking(true)
        SetPedMotionBlur(PlayerPedId(), false)
        ClearTimecycleModifier()
    end)
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    clearBlips()
    overlay.coords, overlay.names, overlay.blips = false, false, false
    ClearTimecycleModifier()
end)
