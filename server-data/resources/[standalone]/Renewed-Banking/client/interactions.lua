RenewedBanking = RenewedBanking or {}
local RB = RenewedBanking

RB.Client.interactions = RB.Client.interactions or {}
local spawnPoints, interactionPoints, peds, blips = {}, {}, {}, {}
local targetAvailable = false
local interactAvailable = false
local interactModelsAdded = false -- interact has no way to remove a model interaction; it is added once
local pedInteractions = {}
local textOwner = nil

local function capabilities(kind, location)
    if kind == 'atm' then return Config.interaction.atmCapabilities end
    local data = {}
    for key, value in pairs(Config.interaction.bankCapabilities) do data[key] = value end
    if location and location.createAccounts ~= nil then data.createSharedAccount = location.createAccounts == true end
    return data
end

local function open(kind, locationId, location)
    TriggerEvent('Renewed-Banking:client:v3:open', {
        type = kind,
        locationId = locationId,
        capabilities = capabilities(kind, location)
    })
end

local function createBlip(location)
    if not location.blip or location.blip.enabled == false then return end
    local coords = location.coords
    local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(blip, location.blip.sprite or 108)
    SetBlipDisplay(blip, 4)
    SetBlipScale(blip, location.blip.scale or 0.8)
    SetBlipColour(blip, location.blip.colour or 2)
    SetBlipAsShortRange(blip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentString(locale('bank_name'))
    EndTextCommandSetBlipName(blip)
    blips[#blips + 1] = blip
end

local function useAtm(entity)
    -- Machines with a screen in Config.atm.screens use it; any other model opens the bank UI.
    if RB.Client.atm.canUse(entity) then
        RB.Client.atm.use(entity, { type = 'atm', locationId = 'atm', capabilities = capabilities('atm') })
    else
        open('atm', 'atm')
    end
end

local function atmOption()
    return {
        name = 'renewed_banking_v3_atm',
        label = locale('view_bank'),
        canInteract = function() return RB.Client.state.initialized and not RB.Client.atm.isActive() end,
        action = function(entity) useAtm(entity) end
    }
end

-- entity -> { id, at }: the point on each nearby machine's screen
local atmPoints = {}

--- Keeps a point on the screen of every machine nearby (from client/atm.lua's
--- scan), moving it when the screen is lined up somewhere new.
function RB.Client.interactions.syncAtms(machines)
    if not interactAvailable or not RB.Client.state.initialized then return end
    local settings = Config.interaction.interact
    local seen = {}
    for _, machine in ipairs(machines) do
        local entity, screen = machine.entity, machine.info.screen
        seen[entity] = true
        -- A few centimetres out from the middle of the glass.
        local tilt = math.rad(screen.tilt or 0.0)
        local at = vec3(screen.x, screen.y - math.cos(tilt) * 0.03, screen.z + math.sin(tilt) * 0.03)
        local point = atmPoints[entity]
        if not point or #(point.at - at) > 0.001 then
            -- Adding to an entity that has a point already moves it.
            local id = exports.interact:AddLocalEntityInteraction({
                entity = entity,
                offset = at,
                distance = settings.distance,
                interactDst = settings.interactDst,
                options = { atmOption() }
            })
            atmPoints[entity] = { id = id, at = at }
        end
    end
    for entity, point in pairs(atmPoints) do
        if not seen[entity] then
            exports.interact:RemoveInteraction(point.id)
            atmPoints[entity] = nil
        end
    end
end

local function addPedTarget(ped, location)
    if interactAvailable then
        local offset = Config.interaction.interact.pedOffset
        pedInteractions[location.id] = exports.interact:AddLocalEntityInteraction({
            entity = ped,
            offset = vec3(offset.x, offset.y, offset.z),
            distance = Config.interaction.interact.distance,
            interactDst = Config.interaction.interact.interactDst,
            options = { {
                name = 'renewed_banking_v3_bank_' .. location.id,
                label = locale('view_bank'),
                action = function() open('bank', location.id, location) end
            } }
        })
        return
    end
    if not targetAvailable then return end
    exports.ox_target:addLocalEntity(ped, {{
        name = 'renewed_banking_v3_bank_' .. location.id,
        icon = 'fa-solid fa-building-columns',
        label = locale('view_bank'),
        distance = Config.interaction.targetDistance,
        onSelect = function() open('bank', location.id, location) end
    }})
end

local function removePedTarget(ped, location)
    if pedInteractions[location.id] then
        exports.interact:RemoveInteraction(pedInteractions[location.id])
        pedInteractions[location.id] = nil
        return
    end
    if targetAvailable and DoesEntityExist(ped) then
        exports.ox_target:removeLocalEntity(ped, { 'renewed_banking_v3_bank_' .. location.id })
    end
end

local function createSpawnPoint(location)
    local c = location.coords
    local point = lib.points.new({
        coords = vec3(c.x, c.y, c.z),
        distance = Config.interaction.pedSpawnDistance,
        location = location,
        ped = nil
    })

    function point:onEnter()
        lib.requestModel(self.location.model, 10000)
        local coords = self.location.coords
        self.ped = CreatePed(0, joaat(self.location.model), coords.x, coords.y, coords.z - 1.0, coords.w, false, false)
        SetEntityHeading(self.ped, coords.w)
        FreezeEntityPosition(self.ped, true)
        SetEntityInvincible(self.ped, true)
        SetBlockingOfNonTemporaryEvents(self.ped, true)
        TaskStartScenarioInPlace(self.ped, 'PROP_HUMAN_STAND_IMPATIENT', 0, true)
        SetModelAsNoLongerNeeded(joaat(self.location.model))
        peds[self.location.id] = self.ped
        addPedTarget(self.ped, self.location)
    end

    function point:onExit()
        if self.ped then
            removePedTarget(self.ped, self.location)
            if DoesEntityExist(self.ped) then DeletePed(self.ped) end
            peds[self.location.id] = nil
            self.ped = nil
        end
    end

    spawnPoints[#spawnPoints + 1] = point
end

local function createFallbackPoint(location)
    if interactAvailable or targetAvailable or not Config.interaction.fallbackTextUi then return end
    local c = location.coords
    local point = lib.points.new({ coords = vec3(c.x, c.y, c.z), distance = 2.5, location = location })

    function point:nearby()
        if textOwner ~= self.location.id then
            if textOwner then lib.hideTextUI() end
            lib.showTextUI(('[E] %s'):format(locale('view_bank')))
            textOwner = self.location.id
        end
        if IsControlJustReleased(0, 38) then open('bank', self.location.id, self.location) end
    end

    function point:onExit()
        if textOwner == self.location.id then lib.hideTextUI(); textOwner = nil end
    end

    interactionPoints[#interactionPoints + 1] = point
end

function RB.Client.interactions.initialize()
    if RB.Client.state.initialized then return end
    interactAvailable = Config.interaction.useInteract and GetResourceState('interact') == 'started'
    targetAvailable = not interactAvailable and Config.interaction.useOxTarget and GetResourceState('ox_target') == 'started'
    if interactAvailable and not interactModelsAdded then
        local settings = Config.interaction.interact
        local hasScreen = {}
        for name in pairs(Config.atm.screens or {}) do hasScreen[joaat(name)] = true end
        for _, model in ipairs(Config.atms) do
            -- Machines with a screen get their point on it, one each (syncAtms);
            -- the rest share one for the model.
            if not (hasScreen[model] and Config.atm.screen) then
                exports.interact:AddModelInteraction({
                    modelData = { { model = model, offset = vec3(settings.atmOffset.x, settings.atmOffset.y, settings.atmOffset.z) } },
                    distance = settings.distance,
                    interactDst = settings.interactDst,
                    options = { atmOption() }
                })
            end
        end
        interactModelsAdded = true
    end
    if targetAvailable then
        exports.ox_target:addModel(Config.atms, {{
            name = 'renewed_banking_v3_atm',
            icon = 'fa-solid fa-money-check-dollar',
            label = locale('view_bank'),
            distance = Config.interaction.targetDistance,
            onSelect = function(data) useAtm(data.entity) end
        }})
    end
    for _, location in ipairs(Config.locations) do
        createSpawnPoint(location)
        createFallbackPoint(location)
        createBlip(location)
    end
    RB.Client.state.initialized = true
end

function RB.Client.interactions.cleanup()
    if textOwner then lib.hideTextUI(); textOwner = nil end
    for _, point in pairs(atmPoints) do exports.interact:RemoveInteraction(point.id) end
    atmPoints = {}
    if targetAvailable then exports.ox_target:removeModel(Config.atms, { 'renewed_banking_v3_atm' }) end
    for _, point in ipairs(spawnPoints) do
        if point.ped then removePedTarget(point.ped, point.location); if DoesEntityExist(point.ped) then DeletePed(point.ped) end end
        point:remove()
    end
    for _, point in ipairs(interactionPoints) do point:remove() end
    for _, blip in ipairs(blips) do if DoesBlipExist(blip) then RemoveBlip(blip) end end
    spawnPoints, interactionPoints, peds, blips = {}, {}, {}, {}
    RB.Client.state.initialized = false
end
