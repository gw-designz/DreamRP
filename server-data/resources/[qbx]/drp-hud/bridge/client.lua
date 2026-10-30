-- Client side of the framework bridge.
-- Exposes Bridge.needs (hunger / thirst, 0-100), Bridge.money (cash / bank, nil when the
-- framework has none), Bridge.loaded, Bridge.job (name), Bridge.jobLabel / Bridge.gradeLabel
-- (shown on the job card), Bridge.weaponLabel(hash) and
-- Bridge.onLoaded(cb) / Bridge.onUnloaded(cb).

Bridge.needs = { hunger = 100, thirst = 100 }
Bridge.money = nil
Bridge.loaded = false
Bridge.job = nil

local loadedCbs, unloadedCbs = {}, {}

function Bridge.onLoaded(cb) loadedCbs[#loadedCbs + 1] = cb end
function Bridge.onUnloaded(cb) unloadedCbs[#unloadedCbs + 1] = cb end

local function setLoaded(state)
    if Bridge.loaded == state then return end
    Bridge.loaded = state
    for _, cb in ipairs(state and loadedCbs or unloadedCbs) do cb() end
end

local function clamp(v)
    v = tonumber(v) or 100
    if v < 0 then return 0 elseif v > 100 then return 100 end
    return v
end

local function applyMetadata(meta)
    if not meta then return end
    if meta.hunger then Bridge.needs.hunger = clamp(meta.hunger) end
    if meta.thirst then Bridge.needs.thirst = clamp(meta.thirst) end
end

-- qb-hud compatible event fired by qb-core / qbx consumables.
RegisterNetEvent('hud:client:UpdateNeeds', function(hunger, thirst)
    Bridge.needs.hunger = clamp(hunger)
    Bridge.needs.thirst = clamp(thirst)
end)

if Bridge.name == 'qb' or Bridge.name == 'qbox' then
    local function getPlayerData()
        if Bridge.name == 'qbox' then return exports.qbx_core:GetPlayerData() end
        return exports['qb-core']:GetCoreObject().Functions.GetPlayerData()
    end

    local function setJob(job)
        Bridge.job = job.name or Bridge.job
        Bridge.jobLabel = job.label or Bridge.job
        Bridge.gradeLabel = type(job.grade) == 'table' and job.grade.name or nil
    end

    local function sync(data)
        if not data then return end
        applyMetadata(data.metadata)
        if data.job then setJob(data.job) end
        if data.money then
            Bridge.money = { cash = data.money.cash or 0, bank = data.money.bank or 0 }
        end
    end

    local weapons
    function Bridge.weaponLabel(hash)
        if weapons == nil then
            local ok, list = pcall(function()
                if Bridge.name == 'qbox' then return exports.qbx_core:GetWeapons() end
                return exports['qb-core']:GetCoreObject().Shared.Weapons
            end)
            weapons = ok and list or false
        end
        local w = weapons and weapons[hash]
        return w and w.label or Config.Toasts.weaponLabels[hash]
    end

    RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
        sync(getPlayerData())
        setLoaded(true)
    end)

    RegisterNetEvent('QBCore:Client:OnPlayerUnload', function()
        setLoaded(false)
    end)

    RegisterNetEvent('QBCore:Player:SetPlayerData', sync)

    RegisterNetEvent('QBCore:Client:OnJobUpdate', function(job)
        if job then setJob(job) end
    end)

    -- qbx_core mirrors hunger / thirst into player state bags.
    if Bridge.name == 'qbox' then
        for _, key in ipairs({ 'hunger', 'thirst' }) do
            AddStateBagChangeHandler(key, ('player:%s'):format(GetPlayerServerId(PlayerId())), function(_, _, value)
                if value ~= nil then Bridge.needs[key] = clamp(value) end
            end)
        end
    end

    CreateThread(function()
        if LocalPlayer.state.isLoggedIn then
            sync(getPlayerData())
            setLoaded(true)
        end
    end)

elseif Bridge.name == 'esx' then
    local ESX = exports.es_extended:getSharedObject()

    local function setJob(job)
        if not job then return end
        Bridge.job = job.name or Bridge.job
        Bridge.jobLabel = job.label or Bridge.job
        Bridge.gradeLabel = job.grade_label
    end

    local function syncAccounts(accounts)
        if not accounts then return end
        Bridge.money = Bridge.money or { cash = 0, bank = 0 }
        for _, account in ipairs(accounts) do
            if account.name == 'money' then Bridge.money.cash = account.money
            elseif account.name == 'bank' then Bridge.money.bank = account.money end
        end
    end

    RegisterNetEvent('esx:playerLoaded', function(xPlayer)
        setJob(xPlayer and xPlayer.job)
        syncAccounts(xPlayer and xPlayer.accounts)
        setLoaded(true)
    end)

    RegisterNetEvent('esx:setAccountMoney', function(account)
        if account then syncAccounts({ account }) end
    end)

    RegisterNetEvent('esx:onPlayerLogout', function()
        setLoaded(false)
    end)

    RegisterNetEvent('esx:setJob', setJob)

    -- esx_status sends every status once per tick; percent is already 0-100.
    AddEventHandler('esx_status:onTick', function(statuses)
        for _, s in ipairs(statuses) do
            if s.name == 'hunger' then Bridge.needs.hunger = clamp(s.percent)
            elseif s.name == 'thirst' then Bridge.needs.thirst = clamp(s.percent) end
        end
    end)

    CreateThread(function()
        if ESX.IsPlayerLoaded() then
            local data = ESX.GetPlayerData()
            setJob(data.job)
            syncAccounts(data.accounts)
            setLoaded(true)
        end
    end)

else
    -- Standalone: the HUD is live as soon as the player has a ped. Needs stay full
    -- unless another resource calls exports['my-hud']:SetNeeds(hunger, thirst).
    AddEventHandler('playerSpawned', function() setLoaded(true) end)

    CreateThread(function()
        while not NetworkIsPlayerActive(PlayerId()) do Wait(500) end
        setLoaded(true)
    end)
end

-- ESX and standalone have no shared weapon list, so they use the config fallback.
if not Bridge.weaponLabel then
    function Bridge.weaponLabel(hash)
        return Config.Toasts.weaponLabels[hash]
    end
end

-- Standalone servers (or custom economies) can feed the money panel themselves.
exports('SetMoney', function(cash, bank)
    Bridge.money = { cash = tonumber(cash) or 0, bank = tonumber(bank) or 0 }
end)

exports('SetNeeds', function(hunger, thirst)
    if hunger ~= nil then Bridge.needs.hunger = clamp(hunger) end
    if thirst ~= nil then Bridge.needs.thirst = clamp(thirst) end
end)
