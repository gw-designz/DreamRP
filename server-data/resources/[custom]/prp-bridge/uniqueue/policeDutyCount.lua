AddedByCommandPolicePower = 0

---@return number
function GetFreePolicePower()
    local policeCount = 0
    for i=1, #BridgeConfig.Uniqueue.PoliceJobs do
        policeCount = policeCount + bridge.fw.getDutyCountJob(BridgeConfig.Uniqueue.PoliceJobs[i])
    end

    local currentPolicePower = policeCount * BridgeConfig.Uniqueue.PoliceStrengthPerPlayer
    for queueName, queue in pairs(Queues) do
        local usedPolicePower = queue.getUsedPolicePower()
        if usedPolicePower > 0 then
            currentPolicePower = currentPolicePower - usedPolicePower
        end
    end
    return currentPolicePower + AddedByCommandPolicePower
end

exports('GetFreePolicePower', GetFreePolicePower)

---@param asKV nil | boolean
---@return number[] | table<number, true>
function GetPoliceOnDuty(asKV)
    local srcList = {}
    local usedSrcs = {}
    for i=1, #BridgeConfig.Uniqueue.PoliceJobs do
        local srcs = bridge.fw.getPlayersOnDuty(BridgeConfig.Uniqueue.PoliceJobs[i])
        for k, v in pairs(srcs) do
            if asKV then
                srcList[k] = true
            else
                if not usedSrcs[k] then
                    table.insert(srcList, k)
                    usedSrcs[k] = true
                end
            end
        end
    end
    return srcList
end

exports('GetPoliceOnDuty', GetPoliceOnDuty)

---@return string[]
function GetPoliceJobs()
    return BridgeConfig.Uniqueue.PoliceJobs
end

exports('GetPoliceJobs', GetPoliceJobs)

bridge.fw.registerCommand("uni_setpolicepower", locale("SET_POLICE_POWER"), {
    { name = "power", type = "number", help = locale("POLICE_POWER_AMOUNT") },
}, "group.admin", function(src, args)
    if src ~= 0 then return end

    local power = tonumber(args.power)

    if power == nil then return end

    AddedByCommandPolicePower = math.abs(power)
    print(locale("POLICE_POWER_SET", AddedByCommandPolicePower))
end)