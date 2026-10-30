--[[
    Setting the laptop (or the newsroom printer) down. It appears where the
    player is looking and is handed to object_gizmo (W move, R rotate, Alt
    snap to the surface, Enter puts it down, Esc cancels). Without
    object_gizmo it follows the aim instead, the wheel turns it, E puts it
    down and Backspace cancels.

    Once it is down (server/placement.lua makes the real one), its owner can
    use or pick it up: interact's point on it, or E / G standing at it.
]]

LaptopPlacement = {}

local MODEL = GetHashKey(Config.Placement.Prop)
local KINDS = {
    laptop = { model = MODEL, state = 'novaLaptop', label = 'laptop' },
    printer = { model = GetHashKey(Config.News.Printing.Prop), state = 'novaPrinter', label = 'printer' },
}
local CANCEL = { 177, 194 } -- Backspace
local FREE_HINTS = { { 38, 'Put down' }, { 241, 'Turn' }, { 177, 'Cancel' } }
local placing = false

local function loadModel(model)
    if not IsModelInCdimage(model) then return false end
    RequestModel(model)
    local deadline = GetGameTimer() + 4000
    while not HasModelLoaded(model) and GetGameTimer() < deadline do Wait(20) end
    return HasModelLoaded(model)
end

--- Where the player is looking, on the first surface within reach.
local function aimPoint()
    local ped = PlayerPedId()
    local from = GetGameplayCamCoord()
    local rot = GetGameplayCamRot(2)
    local pitch, heading = math.rad(rot.x), math.rad(rot.z)
    local dir = vector3(-math.sin(heading) * math.cos(pitch), math.cos(heading) * math.cos(pitch), math.sin(pitch))
    local to = from + dir * 8.0
    local probe = StartShapeTestLosProbe(from.x, from.y, from.z, to.x, to.y, to.z, 1 | 16, ped, 4)
    local status, hit, at = GetShapeTestResult(probe)
    while status == 1 do Wait(0) status, hit, at = GetShapeTestResult(probe) end
    local origin = GetEntityCoords(ped)
    if hit == 1 and #(at - origin) <= Config.Placement.MaxDistance then return at end
    -- Nothing in reach: just in front of the player, at their feet.
    local ahead = origin + GetEntityForwardVector(ped) * 0.9
    return vector3(ahead.x, ahead.y, origin.z - 0.95)
end

local function cancelled()
    for _, control in ipairs(CANCEL) do
        if IsControlJustPressed(0, control) or IsDisabledControlJustPressed(0, control) then return true end
    end
    return false
end

--- Puts the laptop down with object_gizmo (v3): Enter keeps it, Esc cancels.
--- Returns coords and rotation, or nil.
local function withGizmo(preview)
    local result = exports.object_gizmo:useGizmo(preview, {
        enableScale = false,
        snapToGround = true,
        distanceLimit = Config.Placement.MaxDistance,
    })
    if not result or result.cancelled or result.confirmed == false or not DoesEntityExist(preview) then return nil end
    return result.position or GetEntityCoords(preview), result.rotation or GetEntityRotation(preview, 2)
end

--- Without the gizmo: the laptop follows the aim, the wheel turns it.
local function withAim(preview)
    local heading = GetEntityHeading(PlayerPedId())
    while true do
        DisableControlAction(0, 24, true)
        DisableControlAction(0, 25, true)
        DisableControlAction(0, 241, true)
        DisableControlAction(0, 242, true)
        DisablePlayerFiring(PlayerId(), true)
        Hints.draw(FREE_HINTS)
        local at = aimPoint()
        SetEntityCoordsNoOffset(preview, at.x, at.y, at.z, false, false, false)
        if IsDisabledControlPressed(0, 241) then heading = heading + 5.0 end
        if IsDisabledControlPressed(0, 242) then heading = heading - 5.0 end
        SetEntityRotation(preview, 0.0, 0.0, heading, 2, true)
        if IsControlJustPressed(0, 38) then return GetEntityCoords(preview), GetEntityRotation(preview, 2) end
        if cancelled() then return nil end
        Wait(0)
    end
end

--- Shows a laptop (kind 'laptop') or printer ('printer') to set down and
--- lets the player place it. Returns the chosen coords and rotation, or nil
--- when they cancel.
function LaptopPlacement.run(kind)
    kind = KINDS[kind] or KINDS.laptop
    if placing or not loadModel(kind.model) then return nil end
    placing = true
    local ped = PlayerPedId()
    local at = aimPoint()
    local preview = CreateObject(kind.model, at.x, at.y, at.z, false, false, false)
    SetModelAsNoLongerNeeded(kind.model)
    -- The model's front faces its -Y: turned like the player, it faces them.
    SetEntityRotation(preview, 0.0, 0.0, GetEntityHeading(ped), 2, true)
    PlaceObjectOnGroundProperly(preview)

    local coords, rotation
    if GetResourceState('object_gizmo') == 'started' then coords, rotation = withGizmo(preview)
    else coords, rotation = withAim(preview) end

    if DoesEntityExist(preview) then DeleteEntity(preview) end
    placing = false
    if coords and #(coords - GetEntityCoords(ped)) > Config.Placement.MaxDistance then
        return nil, ('That is too far away to put the %s down.'):format(kind.label)
    end
    return coords, rotation
end

function LaptopPlacement.active() return placing end

-- ── using a laptop that is down ────────────────────────────────────────

--- Whether a laptop is one this player set down. Only server-made laptops
--- carry an owner: the one being placed and laptops built into the map exist
--- on this computer alone, and asking for their state is an error.
local function owns(entity, state)
    if not entity or entity == 0 or not DoesEntityExist(entity) or not NetworkGetEntityIsNetworked(entity) then return false end
    return Entity(entity).state[state] == GetPlayerServerId(PlayerId())
end
local function mine(entity) return owns(entity, 'novaLaptop') end

--- The player's own laptop near them, if any.
function LaptopPlacement.nearby(distance)
    local me = GetEntityCoords(PlayerPedId())
    for _, object in ipairs(GetGamePool('CObject')) do
        if GetEntityModel(object) == MODEL and mine(object) and #(GetEntityCoords(object) - me) <= (distance or Config.Placement.UseDistance) then
            return object
        end
    end
end

function LaptopPlacement.setup(use, pickUp)
    -- A point on every laptop of the model; only its owner sees the options.
    -- (The printer's options are in client/printer.lua.)
    if GetResourceState('interact') == 'started' then
        exports.interact:AddModelInteraction({
            modelData = { { model = Config.Placement.Prop, offset = vec3(0.0, 0.0, 0.12) } },
            distance = Config.Placement.UseDistance + 2.0,
            interactDst = Config.Placement.UseDistance,
            options = {
                { name = 'nova_laptop:use', label = 'Use laptop', canInteract = mine, action = function() use() end },
                { name = 'nova_laptop:pickup', label = 'Pick up laptop', canInteract = mine, action = function() pickUp() end },
            },
        })
        return
    end
    -- Without interact: a prompt when standing at your own laptop.
    CreateThread(function()
        while true do
            local laptop = not LaptopPlacement.busy() and LaptopPlacement.nearby()
            if laptop then
                BeginTextCommandDisplayHelp('STRING')
                AddTextComponentSubstringPlayerName('~INPUT_CONTEXT~ Use laptop  ~INPUT_DETONATE~ Pick up')
                EndTextCommandDisplayHelp(0, false, false, -1)
                if IsControlJustPressed(0, 38) then use() elseif IsControlJustPressed(0, 47) then pickUp() end
                Wait(0)
            else
                Wait(500)
            end
        end
    end)
end

-- Set by main.lua: whether the laptop is open or being opened.
LaptopPlacement.busy = function() return placing end

-- interact removes this resource's points itself when it stops.
