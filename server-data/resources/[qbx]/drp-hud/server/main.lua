-- Stress is owned by the server and replicated to each client through the
-- `stress` player state bag, then persisted through the framework bridge.

local stress = {}
local lastGain = {}
local lastReport = {}

local function clamp(v)
    v = math.floor((tonumber(v) or 0) + 0.5)
    if v < 0 then return 0 elseif v > 100 then return 100 end
    return v
end

local function setStress(src, value, persist)
    value = clamp(value)
    if stress[src] == value then return value end
    stress[src] = value
    Player(src).state:set('stress', value, true)
    if persist ~= false then Bridge.setStress(src, value) end
    return value
end

local function isWhitelisted(src)
    local job, onDuty = Bridge.getJob(src)
    return job ~= nil and Config.Stress.whitelistedJobs[job] == true and onDuty ~= false
end

local function addStress(src, amount)
    amount = tonumber(amount) or 0
    if not Config.Stress.enabled or amount <= 0 or isWhitelisted(src) then return stress[src] or 0 end
    lastGain[src] = os.time()
    return setStress(src, (stress[src] or 0) + amount)
end

local function removeStress(src, amount)
    amount = tonumber(amount) or 0
    if amount <= 0 then return stress[src] or 0 end
    return setStress(src, (stress[src] or 0) - amount)
end

local function load(src)
    stress[src] = nil
    setStress(src, Bridge.getStress(src) or 0, false)
end

-- Client reported gain (shooting / speeding). Clamped and rate limited.
local function onClientGain(amount)
    local src = source
    local now = GetGameTimer()
    if lastReport[src] and now - lastReport[src] < 1000 then return end
    lastReport[src] = now
    amount = math.min(tonumber(amount) or 0, Config.Stress.maxPerEvent)
    addStress(src, amount)
end

RegisterNetEvent('my-hud:server:gainStress', onClientGain)
RegisterNetEvent('hud:server:GainStress', onClientGain) -- qb-hud compatibility

RegisterNetEvent('hud:server:RelieveStress', function(amount)
    removeStress(source, math.min(tonumber(amount) or 0, 100))
end)

RegisterNetEvent('my-hud:server:requestStress', function()
    load(source)
end)

Bridge.onPlayerLoaded(load)

AddEventHandler('playerDropped', function()
    local src = source
    stress[src], lastGain[src], lastReport[src] = nil, nil, nil
end)

AddEventHandler('onResourceStart', function(res)
    if res ~= GetCurrentResourceName() then return end
    for _, id in ipairs(GetPlayers()) do load(tonumber(id)) end
end)

if Config.Stress.decayPerMinute > 0 then
    CreateThread(function()
        while true do
            Wait(60000)
            local now = os.time()
            for src, value in pairs(stress) do
                if value > 0 and now - (lastGain[src] or 0) >= 60 then
                    removeStress(src, Config.Stress.decayPerMinute)
                end
            end
        end
    end)
end

exports('AddStress', addStress)
exports('RemoveStress', removeStress)
exports('SetStress', function(src, value) return setStress(src, value) end)
exports('GetStress', function(src) return stress[src] or 0 end)
