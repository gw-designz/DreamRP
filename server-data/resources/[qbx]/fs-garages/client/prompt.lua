--[[
    fs-garages / client/prompt.lua

    The [E] prompts on the kiosks and the pods, in whichever way the server
    is set up for (Config.Interaction):

      fantasy     Fantasy Scripts' ox_lib world prompts, drawn on the kiosk
      target      look at the kiosk with ox_target or qb-target
      3dtext      floating [E] text of this script's own, works anywhere

    'auto' takes the first of those the server has. If the chosen one will
    not take the prompt, the plain text is used instead, so a kiosk is
    never left without one. The older names (oxlib, ox_target, qb-target,
    text) still work, so a config from before keeps working.

    An option is { label, icon, show = function(entity), action = function(entity) }.
]]

Prompt = {}

local util = Garage.util

--- Asked of ox_lib's files rather than of its name: the standard ox_lib
--- has no world prompts, and trusting its name would leave every kiosk
--- without one.
local function hasOurOxLib()
    return GetResourceState('ox_lib') == 'started'
        and LoadResourceFile('ox_lib', 'resource/interface/client/interact.lua') ~= nil
end

--- Its prompts can also be used from a vehicle seat, which returning a
--- scooter needs. Versions before that turn every prompt off in a vehicle.
local function oxLibWorksSeated()
    local file = hasOurOxLib() and LoadResourceFile('ox_lib', 'resource/interface/client/interact.lua')
    return file and file:find('data.inVehicle', 1, true) ~= nil or false
end

local function anyTarget()
    if GetResourceState('ox_target') == 'started' then return 'ox_target' end
    if GetResourceState('qb-target') == 'started' then return 'qb-target' end
end

local NAMES = { fantasy = 'oxlib', ['3dtext'] = 'text' }

local function pick()
    local wanted = Config.Interaction or 'auto'
    wanted = NAMES[wanted] or wanted
    if wanted == 'target' then
        local found = anyTarget()
        if not found then
            util.error('Config.Interaction is "target", but neither ox_target nor qb-target is started, so a floating [E] text is used.')
        end
        return found or 'text'
    end
    if wanted ~= 'auto' then return wanted end
    if hasOurOxLib() then return 'oxlib' end
    return anyTarget() or 'text'
end

local way = nil
local own = {}
local nextOwn = 0

local function safe(option, entity)
    local ok, shown = pcall(option.show, entity)
    return ok and shown == true
end

local ADD = {}

function ADD.oxlib(entity, offset, options)
    local list = {}
    for i, option in ipairs(options) do
        list[i] = {
            label = option.label,
            icon = option.icon,
            canInteract = function(e) return safe(option, e) end,
            action = function(e) option.action(e) end,
        }
    end
    local id = exports.ox_lib:addLocalEntityInteraction({
        entity = entity,
        offset = offset,
        distance = Config.PromptDistance + 1.5,
        interactDst = Config.PromptDistance,
        options = list,
    })
    return id and { oxlib = id } or nil
end

function ADD.ox_target(entity, _, options)
    local list, names = {}, {}
    for i, option in ipairs(options) do
        local name = ('fs-garages:%d:%d'):format(entity, i)
        names[i] = name
        list[i] = {
            name = name,
            label = option.label,
            icon = option.icon and ('fa-solid fa-' .. option.icon) or nil,
            distance = Config.PromptDistance + 0.5,
            canInteract = function(e) return safe(option, e) end,
            onSelect = function(data) option.action(data.entity or entity) end,
        }
    end
    exports.ox_target:addLocalEntity(entity, list)
    return { oxTarget = entity, names = names }
end

ADD['qb-target'] = function(entity, _, options)
    local list, labels = {}, {}
    for i, option in ipairs(options) do
        labels[i] = option.label
        list[i] = {
            label = option.label,
            icon = option.icon and ('fas fa-' .. option.icon) or nil,
            canInteract = function(e) return safe(option, e) end,
            action = function(e) option.action(e or entity) end,
        }
    end
    exports['qb-target']:AddTargetEntity(entity, { options = list, distance = Config.PromptDistance + 0.5 })
    return { qbTarget = entity, labels = labels }
end

function ADD.text(entity, offset, options)
    nextOwn = nextOwn + 1
    own[nextOwn] = { entity = entity, offset = offset, options = options }
    return { own = nextOwn }
end

--- A prompt on one entity, at an offset in its own directions.
function Prompt.entity(entity, offset, options)
    way = way or pick()
    local add = ADD[way]
    if not add then
        util.error(('Config.Interaction is "%s", which is not one of: auto, fantasy, target, 3dtext.'):format(tostring(Config.Interaction)))
        way = 'text'
        add = ADD.text
    end
    if way ~= 'text' then
        local ok, handle = pcall(add, entity, offset, options)
        if ok and handle then return handle end
        -- One refusal and that way is not used again this session: a
        -- prompt that silently never appears is worse than the plain one.
        util.error(('%s would not take the kiosk prompt, so fs-garages draws its own: %s'):format(way, tostring(handle)))
        way = 'text'
    end
    return ADD.text(entity, offset, options)
end

--[[
    A prompt at a place, used from the seat of a vehicle: the return on a
    pod's bay. Fantasy Scripts' ox_lib draws it when the server uses it and
    its version allows prompts from a seat. Otherwise nil, and the caller
    draws the floating text with Prompt.draw.
]]
function Prompt.seated(coords, option)
    way = way or pick()
    if way ~= 'oxlib' or not oxLibWorksSeated() then return nil end
    local ok, id = pcall(function()
        return exports.ox_lib:addInteraction({
            coords = coords,
            distance = 4.0,
            interactDst = 3.0,
            inVehicle = true,
            options = { {
                label = option.label,
                icon = option.icon,
                canInteract = function() return safe(option) end,
                action = function() option.action() end,
            } },
        })
    end)
    return ok and id and { oxlib = id } or nil
end

function Prompt.remove(handle)
    if not handle then return end
    if handle.oxlib then
        pcall(function() exports.ox_lib:removeInteraction(handle.oxlib) end)
    elseif handle.oxTarget then
        pcall(function() exports.ox_target:removeLocalEntity(handle.oxTarget, handle.names) end)
    elseif handle.qbTarget then
        pcall(function() exports['qb-target']:RemoveTargetEntity(handle.qbTarget, handle.labels) end)
    elseif handle.own then
        own[handle.own] = nil
    end
end

-- ── the plain prompt ───────────────────────────────────────────────────

function Prompt.draw(coords, text)
    SetDrawOrigin(coords.x, coords.y, coords.z, 0)
    SetTextFont(4)
    SetTextScale(0.0, 0.42)
    SetTextColour(255, 255, 255, 235)
    SetTextCentre(true)
    SetTextOutline()
    BeginTextCommandDisplayText('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayText(0.0, 0.0)
    ClearDrawOrigin()
end

local function firstShown(options, entity)
    for _, option in ipairs(options) do
        if safe(option, entity) then return option end
    end
end

-- Only the nearest prompt is offered: two kiosks can stand side by side,
-- and one press of the key must not use both.
CreateThread(function()
    while true do
        local wait = 500
        if next(own) then
            local pos = GetEntityCoords(PlayerPedId())
            local best, bestGap, bestOption, bestEntity
            for _, point in pairs(own) do
                if DoesEntityExist(point.entity) then
                    local anchor = GetOffsetFromEntityInWorldCoords(point.entity, point.offset.x, point.offset.y, point.offset.z)
                    local gap = #(pos - anchor)
                    if gap < Config.PromptDistance + 1.0 then wait = 100 end
                    if gap < Config.PromptDistance and (not bestGap or gap < bestGap) then
                        local option = firstShown(point.options, point.entity)
                        if option then best, bestGap, bestOption, bestEntity = anchor, gap, option, point.entity end
                    end
                end
            end
            if best then
                wait = 0
                Prompt.draw(best, ('[E] %s'):format(bestOption.label:upper()))
                if IsControlJustPressed(0, Config.Key) and not IsNuiFocused() then
                    local option, entity = bestOption, bestEntity
                    CreateThread(function() option.action(entity) end)
                end
            end
        end
        Wait(wait)
    end
end)
