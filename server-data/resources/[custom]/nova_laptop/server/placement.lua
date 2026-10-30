--[[
    Laptops and printers set down in the world. Each player has at most one of
    each; the server makes them, so everyone sees them, and removes them when
    they are picked up, replaced, or their owner leaves. The entity's state
    (`novaLaptop` / `novaPrinter`) names its owner, which the clients use to
    offer "Use" and "Pick up".
]]

Placement = {}

local KINDS = {
    laptop = { model = GetHashKey(Config.Placement.Prop), state = 'novaLaptop', label = 'laptop' },
    printer = { model = GetHashKey(Config.News.Printing.Prop), state = 'novaPrinter', label = 'printer' },
}

local placed = {} -- source -> { laptop = entity, printer = entity, printerKey = owner's citizen id }
local grants = {} -- source -> { kind, via, expires }: may put one down

local function remove(src, kind)
    local mine = placed[src]
    local entity = mine and mine[kind]
    if mine then mine[kind] = nil end
    if entity and DoesEntityExist(entity) then DeleteEntity(entity) end
end

local function removeAll(src)
    for kind in pairs(KINDS) do remove(src, kind) end
    placed[src] = nil
end

--- The player's laptop when they stand close enough to use it.
function Placement.Near(src)
    local entity = placed[src] and placed[src].laptop
    if not entity or not DoesEntityExist(entity) then return nil end
    local distance = #(GetEntityCoords(GetPlayerPed(src)) - GetEntityCoords(entity))
    if distance > Config.Placement.UseDistance + 1.0 then return nil end
    return NetworkGetNetworkIdFromEntity(entity)
end

--- Every placed printer: { key, coords, netId }. The key is its owner's
--- citizen ID, so its trays keep their contents from one session to the next.
function Placement.Printers()
    local list = {}
    for _, mine in pairs(placed) do
        local printer = mine.printer
        if printer and DoesEntityExist(printer) and mine.printerKey then
            list[#list + 1] = { key = mine.printerKey, coords = GetEntityCoords(printer), netId = NetworkGetNetworkIdFromEntity(printer) }
        end
    end
    return list
end

--- Lets the player put a laptop (or a printer) down; the request that led
--- here already checked they may.
function Placement.Grant(src, via, kind)
    kind = kind or 'laptop'
    grants[src] = { kind = kind, via = via, expires = GetGameTimer() + 120000 }
    TriggerClientEvent('nova_laptop:client:place', src, kind)
end

RegisterNetEvent('nova_laptop:server:place', function(coords, rotation)
    local src = source
    local grant = grants[src]
    grants[src] = nil
    if not grant or GetGameTimer() > grant.expires then return end
    if type(coords) ~= 'vector3' or type(rotation) ~= 'vector3' then return end
    local kind = KINDS[grant.kind]
    local ped = GetPlayerPed(src)
    if #(GetEntityCoords(ped) - coords) > Config.Placement.MaxDistance + 1.0 then
        return TriggerClientEvent('nova_laptop:client:denied', src, ('That is too far away to put the %s down.'):format(kind.label))
    end
    remove(src, grant.kind)
    local entity = CreateObjectNoOffset(kind.model, coords.x, coords.y, coords.z, true, true, false)
    local deadline = GetGameTimer() + 3000
    while not DoesEntityExist(entity) and GetGameTimer() < deadline do Wait(0) end
    if not DoesEntityExist(entity) then
        return TriggerClientEvent('nova_laptop:client:denied', src, ('The %s could not be put down. Is OneSync on?'):format(kind.label))
    end
    SetEntityRotation(entity, rotation.x, rotation.y, rotation.z, 2, true)
    FreezeEntityPosition(entity, true)
    Entity(entity).state:set(kind.state, src, true)
    placed[src] = placed[src] or {}
    placed[src][grant.kind] = entity
    if grant.kind == 'printer' then
        local context = Bridge.Context(src)
        placed[src].printerKey = context and context.player and context.player.PlayerData.citizenid or ('player' .. src)
    end
    TriggerClientEvent('nova_laptop:client:placed', src, NetworkGetNetworkIdFromEntity(entity), grant.via, grant.kind)
end)

RegisterNetEvent('nova_laptop:server:pickUp', function(kind)
    local src = source
    kind = KINDS[kind] and kind or 'laptop'
    if not (placed[src] and placed[src][kind]) then return end
    remove(src, kind)
    TriggerClientEvent('nova_laptop:client:pickedUp', src, kind)
end)

AddEventHandler('playerDropped', function()
    removeAll(source)
    grants[source] = nil
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    for src in pairs(placed) do removeAll(src) end
end)
