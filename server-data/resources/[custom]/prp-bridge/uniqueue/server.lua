IsTotalyBlocked = true -- If true, that means no matter what, the queue will not process any parties
QueueDevMode = false -- If true, debug prints will be shown

Queues = {} ---@type table<string, UniQueue> -- key: queueName
QueuesByType = {} ---@type table<UniQueueType, table<string, boolean>> -- key: queueType, value: table<queueName, true>

Parties = {} ---@type table<string, UniQueueParty> -- key: uuid
PartiesByType = {} ---@type table<UniQueueType, table<string, boolean>> -- key: queueType, value: table<partyUuid, true>

PlayersToParties = {} ---@type table<string, table<string, boolean>> -- key: playerIdentifier, value: partyUuid

function QueuePrint(queueId, ...)
    if not QueueDevMode then return end
    lib.print.debug(queueId, ...)
end

--- Returns a queue by its name
---@param name string
---@return UniQueue | nil
function GetQueue(name)
    return Queues[name]
end

--- Returns a map of queue names by type
---@param type UniQueueType
---@return table<string, boolean> -- key: queueName, value: true
function GetQueuesByType(type)
    local queueMap = QueuesByType[type]
    if not queueMap then
        return {}
    end

    return queueMap
end

--- Returns a party by its UUID
---@param uuid string
---@return UniQueueParty | nil
function GetParty(uuid)
    return Parties[uuid]
end

--- Returns a map of party UUIDs by type
---@param queueType UniQueueType
---@return table<string, boolean> -- key: partyUuid, value: true
function GetPartiesByType(queueType)
    local partyMap = PartiesByType[queueType]
    if not partyMap then
        return {}
    end

    return partyMap
end

--- Returns a map of party UUIDs the player is a member of
---@param identifier string
---@return table<string, boolean> -- key: partyUuid, value: true
function GetPartiesFromPlayer(identifier)
    local identifierStr = tostring(identifier)
    local partyMap = PlayersToParties[identifierStr]
    if not partyMap then
        return {}
    end

    return partyMap
end

CreateThread(function()
    Wait(BridgeConfig.Uniqueue.HoldQueuesOnStartTime * 1000)
    IsTotalyBlocked = false
end)

CreateThread(function()
    Wait(1000)
    while true do
        QueuePrint("MAIN THREAD", "^3-------------------------------^7")
        QueuePrint("MAIN THREAD", "^3Proccesing main UniQueue thread^7")

        if IsTotalyBlocked then
            QueuePrint("MAIN THREAD", "^8UniQueue is totaly blocked^7")
        end

        for queueName, queue in pairs(Queues) do
            local status, err = pcall(function()
                queue.process()
            end)

            if not status then
                lib.print.debug(("Proccesing queue: ^2%s^7 failed with error: ^1%s^7"):format(queueName, err))
            end
            Wait(1000)
        end

        Wait(10000)
    end
end)

exports("CreateQueue", CreateUniqueue)
exports("CreateParty", CreateUniqueueParty)
exports("GetQueue", GetQueue)
exports("GetQueuesByType", GetQueuesByType)
exports("GetParty", GetParty)
exports("GetPartiesByType", GetPartiesByType)
exports("GetPartiesFromPlayer", GetPartiesFromPlayer)

---@param identifier string
local function removePlayerOnDrop(identifier)
    local parties = GetPartiesFromPlayer(identifier)

    for partyUuid, _ in pairs(parties or {}) do
        local party = GetParty(partyUuid)
        if party then
            party.removeMember(identifier)
        end
    end
end

AddEventHandler("onPlayerDropped", function()
    local src = source
    local identifier = bridge.fw.getIdentifier(src)
    if not identifier then return end
    removePlayerOnDrop(identifier)
end)

AddEventHandler("prp-bridge:server:playerUnload", function(src)
    local identifier = bridge.fw.getIdentifier(src)
    if not identifier then return end
    removePlayerOnDrop(identifier)
end)

AddEventHandler("prp-bridge:unique:unload", function(src, identifier)
    removePlayerOnDrop(identifier)
end)

bridge.fw.registerCommand("uni_findplayer", locale("FIND_A_PLAYER_IN_QUEUES"), {
    { name = "identifier", type = "string", help = locale("CMD_FIND_PLAYER_IN_QUEUES_IDENTIFIER") },
}, "group.admin", function(src, args)
    local identifier = tostring(args.identifier)
    local parties = GetPartiesFromPlayer(identifier)

    if not parties or next(parties) == nil then
        bridge.fw.notify(src, "inform", locale("NO_PARTIES_FOUND_FOR_PLAYER", identifier))
        return
    end

    local message = ("Party UUIDs for identifier %s:\n"):format(identifier)
    for partyUuid, _ in pairs(parties) do
        message = message .. ("- %s\n"):format(partyUuid)
    end

    if src == 0 then
        print(message)
    else
        bridge.fw.notify(src, "inform", message)
    end
end)

bridge.fw.registerCommand("uni_setprio", locale("SET_PRIO_FOR_PARTY"), {
    { name = "partyUuid", type = "string", help = locale("PARTY_UUID") },
    { name = "priority", type = "number", help = locale("PRIO_TO_SET") },
}, "group.admin", function(src, args)
    local partyUuid = tostring(args.partyUuid)
    local party = GetParty(partyUuid)
    if not party then
        if src == 0 then
            print(locale("PARTY_NOT_FOUND", partyUuid))
        else
            bridge.fw.notify(src, "error", locale("PARTY_NOT_FOUND", partyUuid))
        end
        return
    end

    local priority = tonumber(args.priority) or 0
    party.setPriority(priority)

    local message = locale("PRIO_SET_SUCCESSFULLY", partyUuid, priority)

    if src == 0 then
        print(message)
    else
        bridge.fw.notify(src, "inform", message)
    end
end)

bridge.fw.registerCommand("uni_rmfromque", locale("REMOVE_PARTY_FROM_QUEUE"), {
    { name = "partyUuid", type = "string", help = locale("PARTY_UUID") },
    { name = "queueName", type = "string", help = locale("QUEUE_NAME") },
}, "group.admin", function(src, args)
    local queue = GetQueue(tostring(args.queueName))
    if not queue then
        if src == 0 then
            print(locale("QUEUE_NOT_FOUND", tostring(args.queueName)))
        else
            bridge.fw.notify(src, "error", locale("QUEUE_NOT_FOUND", tostring(args.queueName)))
        end
        return
    end

    local partyUuid = tostring(args.partyUuid)
    local party = GetParty(partyUuid)
    if not party then
        if src == 0 then
            print(locale("PARTY_NOT_FOUND", partyUuid))
        else
            bridge.fw.notify(src, "error", locale("PARTY_NOT_FOUND", partyUuid))
        end
        return
    end

    queue.remove(party)
end)

bridge.fw.registerCommand("uni_setblocked", locale("SET_QUEUE_BLOCKED_STATE"), {
    { name = "queueName", type = "string", help = locale("QUEUE_NAME") },
    { name = "state", type = "number", help = locale("BLOCKED_STATE_TO_SET") },
}, "group.admin", function(src, args)
    local queue = GetQueue(tostring(args.queueName))
    if not queue then
        if src == 0 then
            print(locale("QUEUE_NOT_FOUND", tostring(args.queueName)))
        else
            bridge.fw.notify(src, "error", locale("QUEUE_NOT_FOUND", tostring(args.queueName)))
        end
        return
    end

    local state = args.state == 1 and true or false
    queue.setBlocked(state)

    local message = locale("SET_BLOCKED_QUEUE_STATE", tostring(args.queueName), tostring(state))

    if src == 0 then
        print(message)
    else
        bridge.fw.notify(src, "inform", message)
    end
end)

bridge.fw.registerCommand("uni_setcooldown", locale("SET_COOLDOWN_FOR_QUEUE"), {
    { name = "queueName", type = "string", help = locale("QUEUE_NAME") },
    { name = "timestamp", type = "number", help = locale("TIMESTAMP_IN_SECONDS") },
}, "group.admin", function(src, args)
    local queue = GetQueue(tostring(args.queueName))
    if not queue then
        if src == 0 then
            print(locale("QUEUE_NOT_FOUND", tostring(args.queueName)))
        else
            bridge.fw.notify(src, "error", locale("QUEUE_NOT_FOUND", tostring(args.queueName)))
        end
        return
    end

    local timestamp = tonumber(args.timestamp) or 0
    queue.setCooldown(timestamp)

    local message = locale("SET_COOLDOWN_QUEUE", tostring(args.queueName), timestamp)
    if src == 0 then
        print(message)
    else
        bridge.fw.notify(src, "inform", message)
    end
end)

bridge.fw.registerCommand("uni_clearcooldown", locale("CLEAR_QUEUE_COOLDOWN"), {
    { name = "queueName", type = "string", help = locale("QUEUE_NAME") },
}, "group.admin", function(src, args)
    local queue = GetQueue(tostring(args.queueName))
    if not queue then
        if src == 0 then
            print(locale("QUEUE_NOT_FOUND", tostring(args.queueName)))
        else
            bridge.fw.notify(src, "error", locale("QUEUE_NOT_FOUND", tostring(args.queueName)))
        end
        return
    end

    queue.clearCooldown()

    local message = locale("CLEARED_COOLDOWN_QUEUE", tostring(args.queueName))
    if src == 0 then
        print(message)
    else
        bridge.fw.notify(src, "inform", message)
    end
end)

bridge.fw.registerCommand("uni_totalblock", locale("SET_QUEUE_TOTAL_BLOCK"), {
    { name = "state", type = "number", help = locale("SET_QUEUE_TOTAL_BLOCK2") },
}, "group.admin", function(src, args)
    IsTotalyBlocked = args.state == 1 and true or false

    local message = locale("QUEUE_TOTAL_BLOCK_SET", tostring(IsTotalyBlocked))
    if src == 0 then
        print(message)
    else
        bridge.fw.notify(src, "inform", message)
    end
end)

bridge.fw.registerCommand("uni_cleartask", locale("CLEAR_EXECUTING_TASK_FROM_QUEUE"), {
    { name = "queueName", type = "string", help = locale("QUEUE_NAME") },
    { name = "taskId", type = "string", help = locale("TASK_ID_TO_CLEAR") },
}, "group.admin", function(src, args)
    local queue = GetQueue(tostring(args.queueName))
    if not queue then
        if src == 0 then
            print(locale("QUEUE_NOT_FOUND", tostring(args.queueName)))
        else
            bridge.fw.notify(src, "error", locale("QUEUE_NOT_FOUND", tostring(args.queueName)))
        end
        return
    end

    local taskId = tostring(args.taskId)

    queue.setTaskIsExecuting(taskId, false)

    local message = locale("EXECUTING_TASK_CLEARED", taskId, tostring(args.queueName))
    if src == 0 then
        print(message)
    else
        bridge.fw.notify(src, "inform", message)
    end
end)

bridge.fw.registerCommand("uni_devmode", locale("QUEUE_DEVMODE_CMD"), {}, "group.admin", function(src, args)
    QueueDevMode = not QueueDevMode

    local message = locale("QUEUE_DEVMODE_SET", tostring(QueueDevMode))
    if src == 0 then
        print(message)
    else
        bridge.fw.notify(src, "inform", message)
    end
end)