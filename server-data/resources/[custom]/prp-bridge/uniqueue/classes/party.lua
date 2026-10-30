local mt = {
    __index = function(self, key)

    end
}

---@class UniQueuePartyMember
---@field identifier string
---@field enterTime number

---@class UniQueueParty
---@field setUUID fun(uuid: string) Allows to set party's UUID to something else, for example when connecting groups to parties.
---@field getUUID fun(): string
---@field getPosition fun(): number
---@field getEnterId fun(): number
---@field getPriority fun(): number
---@field getOverTimePrioAdded fun(): number
---@field getOverTimePrioAddTime fun(): number
---@field setPosition fun(pos: number)
---@field setEnterId fun(id: number)
---@field addOverTimePrio fun()
---@field addMember fun(identifier: string): { success: boolean, error: string? }
---@field removeMember fun(identifier: string)
---@field getMembers fun(): table<string, UniQueuePartyMember> -- key: identifier, value: UniQueuePartyMember
---@field getMembersAsArray fun(): string[]
---@field getType fun(): UniQueueType
---@field setPriority fun(priority: number)
---@field destroy fun()

---@return string, any
local function generateUUID()
    local template = "xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx"
    return template:gsub("[xy]", function(c)
        local v = (c == "x") and math.random(0, 15) or math.random(8, 11)
        return string.format("%x", v)
    end)
end

---@param type UniQueueType
---@return UniQueueParty
function CreateUniqueueParty(type)
    local public = {}
    local private = {
        uuid = generateUUID(),
        position = 0,
        enterId = 0,
        priority = 0,
        leaveTime = nil,
        overTimePrioAdded = 0,
        overTimePrioAddTime = 0,
        type = type,
        members = {}, ---@type table<string, UniQueuePartyMember> -- key: identifier
    }

    setmetatable(public, mt)

    --- Allows to set party's UUID to something else, for example when connecting groups to parties.
    ---@param uuid string
    public.setUUID = function(uuid)
        Parties[private.uuid] = nil -- clear old reference
        PartiesByType[private.type][private.uuid] = nil
        private.uuid = uuid
        Parties[private.uuid] = public
        PartiesByType[private.type][private.uuid] = true
    end

    ---@return string
    public.getUUID = function()
        return private.uuid
    end

    public.getType = function()
        return private.type
    end

    ---@return number
    public.getPosition = function()
        return private.position
    end

    ---@return number
    public.getEnterId = function()
        return private.enterId
    end

    ---@return number
    public.getPriority = function()
        return private.priority
    end

    ---@return number
    public.getOverTimePrioAdded = function()
        return private.overTimePrioAdded
    end

    ---@return number
    public.getOverTimePrioAddTime = function()
        return private.overTimePrioAddTime
    end

    ---@param pos number
    public.setPosition = function(pos)
        private.position = pos
    end

    ---@param id number
    public.setEnterId = function(id)
        private.enterId = id
    end

    ---@param identifier string
    ---@return { success: boolean, error: string? }
    public.addMember = function(identifier)
        identifier = tostring(identifier)

        local partiesUUIDs = GetPartiesFromPlayer(identifier)
        for partyUuid, _ in pairs(partiesUUIDs or {}) do
            local party = GetParty(partyUuid)
            if party and party.getType() == private.type then
                return { success = false, error = locale("PLAYER_ALREADY_IN_PARTY_TYPE") }
            end
        end

        private.members[identifier] = {
            identifier = identifier,
            enterTime = os.time(),
        }

        local identifierStr = tostring(identifier)
        PlayersToParties[identifierStr] = PlayersToParties[identifierStr] or {}
        PlayersToParties[identifierStr][private.uuid] = true

        return { success = true }
    end

    ---@param identifier string
    public.removeMember = function(identifier)
        identifier = tostring(identifier)
        private.members[identifier] = nil

        local identifierStr = tostring(identifier)
        PlayersToParties[identifierStr] = PlayersToParties[identifierStr] or {}
        PlayersToParties[identifierStr][private.uuid] = nil
    end

    ---@return table<string, UniQueuePartyMember> -- key: identifier, value: UniQueuePartyMember
    public.getMembers = function()
        return private.members
    end

    ---@return string[]
    public.getMembersAsArray = function()
        local membersArray = {}
        for identifier, member in pairs(private.members) do
            membersArray[#membersArray + 1] = identifier
        end
        return membersArray
    end

    public.addOverTimePrio = function()
        if private.overTimePrioAdded >= BridgeConfig.Uniqueue.MaxOverTimePriority then
            return
        end

        local time = os.time()

        if time - public.getOverTimePrioAddTime() >= BridgeConfig.Uniqueue.AddOverTimePriorityTime then
            private.overTimePrioAdded = private.overTimePrioAdded + 1
            private.overTimePrioAddTime = time
            private.priority = private.priority + 1
        end
    end

    ---@param priority number
    public.setPriority = function(priority)
        private.priority = priority
    end

    public.destroy = function()
        local members = public.getMembers()
        for identifier, _ in pairs(members) do
            local identifierStr = tostring(identifier)
            PlayersToParties[identifierStr] = PlayersToParties[identifierStr] or {}
            PlayersToParties[identifierStr][private.uuid] = nil
        end
        PartiesByType[public.getType()][private.uuid] = nil
        Parties[private.uuid] = nil

        TriggerEvent('prp-bridge:uniqueue:partyDestroyed', private.uuid)
    end

    Parties[private.uuid] = public
    PartiesByType[private.type] = PartiesByType[private.type] or {}
    PartiesByType[private.type][private.uuid] = true

    return public
end