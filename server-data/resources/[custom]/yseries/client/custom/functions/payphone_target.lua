if not Config.Payphones or not Config.Payphones.Enabled then return end

if GetResourceState('ox_target') ~= 'started' and GetResourceState('qb-target') ~= 'started' then
    debugPrint('[YSeries] Payphone: No compatible target system detected. Payphone booth interaction disabled.')
    return
end

local timeout = GetGameTimer() + 5000
while not (_G.YSeriesPayphone and _G.YSeriesPayphone.boothsById and _G.YSeriesPayphone.boothStateCache) do
    if GetGameTimer() > timeout then
        debugPrint('[YSeries] Payphone: Timeout while waiting for payphone data. Payphone booth interaction disabled.')
        return
    end
    Wait(500)
end

local payphone = _G.YSeriesPayphone
local boothsById = payphone.boothsById
local boothStateCache = payphone.boothStateCache
local onUsePayphone = payphone.onUsePayphone
local onAnswer = payphone.onAnswer

--- Resolves entity to boothId by matching entity coords to booth coords (closest within 3.0m).
---@param entity number
---@return string|nil
local function entityToBoothId(entity)
    if not entity or not DoesEntityExist(entity) then return nil end
    local ec = GetEntityCoords(entity)
    local bestId, bestDist = nil, 999.0
    for boothId, booth in pairs(boothsById) do
        local d = #(booth.coords - ec)
        if d < (Config.Payphones.BoothFindRadius or 3.0) and d < bestDist then
            bestId, bestDist = boothId, d
        end
    end
    return bestId
end

--- Collect unique booth models for ox_target addModel.
local modelsSet = {}
for _, booth in pairs(boothsById) do
    local m = booth.model
    if m then
        modelsSet[m] = true
    end
end
local payphoneModels = {}
for model in pairs(modelsSet) do
    payphoneModels[#payphoneModels + 1] = joaat(model)
end

if #payphoneModels == 0 then return end

--- Reads `Config.PayphoneStrings[key]` for ox_target / qb-target labels.
---@param key string
---@return string
local function payphoneStr(key)
    local fmt = Config.PayphoneStrings and Config.PayphoneStrings[key]
    return (type(fmt) == 'string' and fmt ~= '') and fmt or key
end

local labelUsePayphone = payphoneStr('targetUsePayphone')
local labelAnswer = payphoneStr('targetAnswer')

if GetResourceState('ox_target') == 'started' then
    exports['ox_target']:addModel(payphoneModels, {
        {
            name = 'usePayphone',
            icon = 'fa-solid fa-phone',
            label = labelUsePayphone,
            distance = Config.Payphones.DefaultInteractionDistance or 1.5,
            canInteract = function(entity)
                local boothId = entityToBoothId(entity)
                if not boothId then return false end
                local cached = boothStateCache[boothId]
                if not cached then return false end
                return cached.booth.state == 'idle' and cached.booth.allowOutgoing
            end,
            onSelect = function(data)
                local boothId = entityToBoothId(data.entity)
                if boothId and onUsePayphone then
                    onUsePayphone(boothId)
                end
            end,
        },
        {
            name = 'answerPayphone',
            icon = 'fa-solid fa-phone-volume',
            label = labelAnswer,
            distance = Config.Payphones.DefaultInteractionDistance or 1.5,
            canInteract = function(entity)
                local boothId = entityToBoothId(entity)
                if not boothId then return false end
                local cached = boothStateCache[boothId]
                return cached and cached.booth.state == 'ringing'
            end,
            onSelect = function(data)
                local boothId = entityToBoothId(data.entity)
                if boothId and onAnswer then
                    onAnswer(boothId)
                end
            end,
        },
    })
elseif GetResourceState('qb-target') == 'started' then
    exports['qb-target']:AddTargetModel(payphoneModels, {
        options = {
            {
                icon = 'fa-solid fa-phone',
                label = labelUsePayphone,
                canInteract = function(entity)
                    local boothId = entityToBoothId(entity)
                    if not boothId then return false end
                    local cached = boothStateCache[boothId]
                    if not cached then return false end
                    return cached.booth.state == 'idle' and cached.booth.allowOutgoing
                end,
                action = function(entity)
                    local boothId = entityToBoothId(entity)
                    if boothId and onUsePayphone then
                        onUsePayphone(boothId)
                    end
                end,
            },
            {
                icon = 'fa-solid fa-phone-volume',
                label = labelAnswer,
                canInteract = function(entity)
                    local boothId = entityToBoothId(entity)
                    if not boothId then return false end
                    local cached = boothStateCache[boothId]
                    return cached and cached.booth.state == 'ringing'
                end,
                action = function(entity)
                    local boothId = entityToBoothId(entity)
                    if boothId and onAnswer then
                        onAnswer(boothId)
                    end
                end,
            },
        },
        distance = Config.Payphones.DefaultInteractionDistance or 1.5,
    })

    AddEventHandler('onResourceStop', function(resourceName)
        if resourceName == GetCurrentResourceName() then
            exports['qb-target']:RemoveTargetModel(payphoneModels, { labelUsePayphone, labelAnswer })
        end
    end)
end
