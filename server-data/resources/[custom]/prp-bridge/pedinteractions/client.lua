---@class PedInteractionPayload
---@field model number | string
---@field coords vector3
---@field heading number
---@field radius number
---@field options table
---@field component? table
---@field anim? table
---@field scenario? string

---@class PedInteraction: PedInteractionPayload
---@field point CPoint
---@field resource string

---@type table<string, any>
local interactions = {}

local function onEnter(self)
    if not interactions[self.interactionId] then
        lib.print.debug("Ped Interaction not found on Enter:", self.interactionId)
        return
    end

    local payload = interactions[self.interactionId]

    if self.entity and DoesEntityExist(self.entity) then
        DeleteEntity(self.entity)
    end

    local model = type(payload.model) == 'string' and joaat(payload.model) or payload.model

    if not IsModelValid(model) or not IsModelAPed(model) then
        lib.print.debug("Ped Interaction model invalid on Enter:", self.interactionId, payload.model)
        return
    end

    lib.requestModel(model)

    self.entity = CreatePed(
        5,
        model,
        payload.coords.x,
        payload.coords.y,
        payload.coords.z,
        payload.heading,
        false,
        false
    )

    SetEntityAsMissionEntity(self.entity, true, true)
    FreezeEntityPosition(self.entity, true)
    SetPedCanRagdoll(self.entity, false)
    TaskSetBlockingOfNonTemporaryEvents(self.entity, true)
    SetBlockingOfNonTemporaryEvents(self.entity, true)
    SetPedFleeAttributes(self.entity, 0, false)
    SetPedCombatAttributes(self.entity, 17, true)
    SetEntityInvincible(self.entity, true)
    SetPedSeeingRange(self.entity, 0)
    SetPedDefaultComponentVariation(self.entity)

    if payload.component and type(payload.component) == "table" then
        SetPedComponentVariation(
            self.entity,
            payload.component.componentId or 0,
            payload.component.drawableId or 0,
            payload.component.textureId or 0,
            payload.component.paletteId or 0
        )
    end

    if payload.anim and type(payload.anim) == "table" and payload.anim.animDict and payload.anim.anim then
        ClearPedTasks(self.entity)
        lib.requestAnimDict(payload.anim.animDict)

        TaskPlayAnim(
            self.entity,
            payload.anim.animDict,
            payload.anim.anim,
            payload.anim.blendIn or 8.0,
            payload.anim.blendOut or 8.0,
            payload.anim.duration or -1,
            payload.anim.flag or 1,
            payload.anim.playback or 0,
            payload.anim.lockX or false,
            payload.anim.lockY or false,
            payload.anim.lockZ or false
        )

        RemoveAnimDict(payload.anim.animDict)
    elseif payload.scenario and type(payload.scenario) == "string" then
        ClearPedTasks(self.entity)
        TaskStartScenarioInPlace(self.entity, payload.scenario, 0, true)
    end

    if payload.weapon then
        GiveWeaponToPed(self.entity, payload.weapon, 1, false, true)
        SetCurrentPedWeapon(self.entity, payload.weapon, true)
    end

    for index, option in pairs(payload.options) do
        option.name = ("%s_%s"):format(self.interactionId, index)
    end

    bridge.target.addLocalEntity(self.entity, payload.options)

    SetModelAsNoLongerNeeded(model)
end

local function onExit(self)
    if self.entity and DoesEntityExist(self.entity) then
        SetEntityAsMissionEntity(self.entity, true, true)
        DeleteEntity(self.entity)

        local options = {}
        for index, _ in pairs(interactions[self.interactionId].options) do
            options[#options + 1] = ("%s_%s"):format(self.interactionId, index)
        end

        bridge.target.removeLocalEntity(self.entity, options)
    end

    self.entity = nil
end

local function remove(id)
    if not id then
        lib.print.debug("Ped Interaction ID missing for removal")
        return false
    end

    if not interactions[id] then
        lib.print.debug("Ped Interaction with ID does not exist for removal:", id)
        return false
    end

    interactions[id].point.onExit(interactions[id].point)
    interactions[id].point:remove()

    interactions[id] = nil

    return true
end
exports('RemovePedInteraction', remove)

---@param id string
---@param payload PedInteractionPayload
---@return boolean, string?
local function add(id, payload)
    if not id or not payload then
        lib.print.debug("Ped Interaction ID or Payload missing:", id, payload)
        return false, "missing"
    end

    if interactions[id] then
        lib.print.debug("Ped Interaction with ID already exists:", id)
        return false, "exists"
    end

    interactions[id] = payload
    interactions[id].resource = GetInvokingResource()

    interactions[id].point = lib.points.new({
        coords = payload.coords,
        distance = payload.radius or 100.0,
        onEnter = onEnter,
        onExit = onExit,
        interactionId = id,
    })

    return true
end
exports('AddPedInteraction', add)

AddEventHandler('onResourceStop', function(resourceName)
    for id, interaction in pairs(interactions) do
        if interaction.resource == resourceName then
            remove(id)
        end
    end
end)