local active = nil -- promise while a lock is being picked

local itemTiers = {}
for tier, settings in pairs(Config.Tiers) do itemTiers[settings.item] = tier end

local function notify(key, kind)
    lib.notify({ title = Config.Text.title, description = Config.Text[key], type = kind or 'error' })
end

local function setTargeting(disabled)
    if GetResourceState('osm-target') ~= 'started' then return end
    pcall(function() exports['osm-target']:disableTargeting(disabled) end)
end

local function hasItem(item)
    local ok, count = pcall(function() return exports.ox_inventory:Search('count', item) end)
    return ok and (count or 0) > 0
end

-- Best (or worst, see Config.AutoTierPreference) tier the player is carrying.
-- `flag` limits it to tiers with that setting on, e.g. GetBestTier('buildingDoors').
local function getBestTier(flag)
    local order = Config.TierOrder
    local first, last, step = 1, #order, 1
    if Config.AutoTierPreference == 'worst' then first, last, step = #order, 1, -1 end

    for i = first, last, step do
        local tier = order[i]
        local settings = Config.Tiers[tier]
        if settings and (not flag or settings[flag]) and hasItem(settings.item) then
            return tier
        end
    end
end

local DISABLED = { 21, 22, 24, 25, 37, 44, 140, 141, 142, 199, 200, 257, 263, 264 }
local MOVEMENT = { 30, 31, 32, 33, 34, 35 }

---Runs the minigame. Blocks until it ends.
---@param tier 'regular'|'advanced'|'sophisticated'
---@param opts? { override?: table, noBreak?: boolean }
---@return boolean success
---@return 'success'|'fail'|'cancel'|'broke'|'busy'|'invalid' reason
local function start(tier, opts)
    opts = opts or {}
    local base = Config.Tiers[tier]
    if not base then return false, 'invalid' end
    if active then
        notify('busy')
        return false, 'busy'
    end

    local settings = {}
    for k, v in pairs(base) do settings[k] = v end
    if opts.override then
        for k, v in pairs(opts.override) do settings[k] = v end
    end

    local this = promise.new()
    active = this
    setTargeting(true)

    SendNUIMessage({
        action = 'open',
        settings = settings,
        grace = Config.Grace,
        keyLabel = Config.KeyLabel,
        text = Config.Text,
    })

    CreateThread(function()
        -- Never heard back from the page: don't leave the player stuck
        local deadline = GetGameTimer() + settings.time + 3000

        while active == this do
            DisableControlAction(0, Config.Key, true)
            DisableControlAction(0, Config.CancelKey, true)
            for i = 1, #DISABLED do DisableControlAction(0, DISABLED[i], true) end
            if Config.DisableMovement then
                for i = 1, #MOVEMENT do DisableControlAction(0, MOVEMENT[i], true) end
            end

            if IsDisabledControlJustPressed(0, Config.Key) then
                SendNUIMessage({ action = 'press' })
            elseif IsDisabledControlJustPressed(0, Config.CancelKey) then
                SendNUIMessage({ action = 'cancel' })
            end

            local forced = IsEntityDead(cache.ped) and 'cancel' or GetGameTimer() > deadline and 'fail'
            if forced then
                active = nil -- the page's own finish callback is ignored from here on
                SendNUIMessage({ action = 'abort', success = false, cancelled = forced == 'cancel' })
                this:resolve(forced)
                return
            end

            Wait(0)
        end
    end)

    local result = Citizen.Await(this)
    if active == this then active = nil end
    setTargeting(false)

    if result == 'success' then return true, 'success' end
    if result == 'cancel' then return false, 'cancel' end

    if not opts.noBreak and math.random() < (settings.breakChance or 0) then
        TriggerServerEvent('lockpick_minigame:server:break', tier)
        notify('broke')
        return false, 'broke'
    end

    return false, 'fail'
end

RegisterNUICallback('finish', function(data, cb)
    cb(1)
    local current = active
    if not current then return end
    active = nil
    current:resolve(data.cancelled and 'cancel' or data.success and 'success' or 'fail')
end)

-- ox_inventory `client.export` for the three lockpick items (see data/items.lua).
-- Building doors go straight to ox_doorlock; everything else goes out on the old
-- lockpicks:UseLockpick event (vehicles, hotwiring, house robbery), now with the tier.
local function useItem(data)
    local tier = itemTiers[data.name]
    if not tier then return end
    if active then return notify('busy') end

    if Config.Tiers[tier].buildingDoors and GetResourceState('ox_doorlock') == 'started' then
        local ok, canPick = pcall(function() return exports.ox_doorlock:canPickClosestDoor() end)
        if ok and canPick then
            return exports.ox_doorlock:pickClosestDoor()
        end
    end

    TriggerServerEvent('lockpick_minigame:server:used', tier)
end

AddEventHandler('onResourceStop', function(resource)
    if resource ~= cache.resource or not active then return end
    setTargeting(false)
end)

exports('Start', start)
exports('GetBestTier', getBestTier)
exports('IsActive', function() return active ~= nil end)
exports('useItem', useItem)
