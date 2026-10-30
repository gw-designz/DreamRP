local opened, opening, nuiReady = false, false, false
local pending, sequence, lastPayload = {}, 0, nil
local openingGeneration = 0
local display = nil -- 'world' (painted on the prop) or 'screen' (overlay) while open

local function notify(message)
    BeginTextCommandThefeedPost('STRING')
    AddTextComponentSubstringPlayerName(message)
    EndTextCommandThefeedPostTicker(false, false)
end

local function canOpen()
    local ped = PlayerPedId()
    if Config.BlockWhenDead and (IsEntityDead(ped) or IsPedFatallyInjured(ped)
        or LocalPlayer.state.isDead or LocalPlayer.state.dead) then
        return false, 'You cannot use the laptop right now.'
    end
    if IsPauseMenuActive() then return false, 'Close the pause menu first.' end
    if IsPedRagdoll(ped) or IsPedFalling(ped) or IsPedSwimming(ped) then return false, 'Stand still to use your laptop.' end
    if not Config.AllowInVehicle and IsPedInAnyVehicle(ped, false) then return false, 'Leave your vehicle to use the laptop.' end
    if IsPedCuffed(ped) then return false, 'You cannot use a laptop while restrained.' end
    return true
end

--- Messages for the desktop go to wherever it is showing.
local function sendUi(message)
    if display == 'world' then LaptopScreen.send(message) else SendNUIMessage(message) end
end

local function closeLaptop()
    local wasActive = opened or opening
    opened, opening, lastPayload, display = false, false, nil, nil
    openingGeneration = openingGeneration + 1
    SetNuiFocus(false, false)
    SetNuiFocusKeepInput(false)
    SendNUIMessage({ type = 'relay', on = false })
    SendNUIMessage({ type = 'close' })
    LaptopScreen.stop()
    if wasActive then
        Hints.swallowPause()
        TriggerServerEvent('nova_laptop:server:close')
    end
end

local function requestOpen(via)
    if opened then closeLaptop() return end
    if Camera.active() or LaptopPlacement.active() then return end
    if opening then return end
    local allowed, reason = canOpen()
    if not allowed then notify(reason) return end
    opening = true
    openingGeneration = openingGeneration + 1
    local requestGeneration = openingGeneration
    TriggerServerEvent('nova_laptop:server:open', via or 'command')
    SetTimeout(10000, function()
        if opening and requestGeneration == openingGeneration then
            opening = false
            TriggerServerEvent('nova_laptop:server:close')
            notify('Laptop connection timed out. Please try again.')
        end
    end)
end

local function showOverlay(payload)
    display = 'screen'
    SetNuiFocus(true, true)
    SetNuiFocusKeepInput(false)
    if nuiReady then SendNUIMessage({ type = 'open', payload = payload }) end
end

--- The laptop the player set down, once it has reached this client.
local function placedLaptop(netId)
    local deadline = GetGameTimer() + 4000
    while not NetworkDoesNetworkIdExist(netId) and GetGameTimer() < deadline do Wait(50) end
    local object = NetworkDoesNetworkIdExist(netId) and NetToObj(netId) or 0
    return object ~= 0 and DoesEntityExist(object) and object or nil
end

RegisterNetEvent('nova_laptop:client:open', function(payload, netId)
    local allowed, reason = canOpen()
    if not allowed then closeLaptop() TriggerServerEvent('nova_laptop:server:close') notify(reason) return end
    opening, opened, lastPayload = false, true, payload
    if not netId then return showOverlay(payload) end

    local generation = openingGeneration
    CreateThread(function()
        local prop = placedLaptop(netId)
        local still = function() return opened and generation == openingGeneration end
        if not still() then return end
        if prop and LaptopScreen.prepare() and still() and LaptopScreen.start(prop) then
            -- The game keeps the mouse and keyboard; the keyboard goes to the
            -- NUI page only while a field on the desktop is being typed into.
            display = 'world'
            -- Sent a few times: the page ignores repeats, and a page still
            -- starting up would otherwise stay blank.
            payload.session = GetGameTimer()
            for _, delay in ipairs({ 0, 700, 2000, 4500 }) do
                SetTimeout(delay, function() if still() and display == 'world' then LaptopScreen.send({ type = 'open', payload = payload }) end end)
            end
        elseif still() then
            showOverlay(payload)
        end
    end)
end)

-- ── setting the laptop down ────────────────────────────────────────────

-- The server lets us set something down: a laptop when there is none near
-- us, or the newsroom printer from the Newsstand.
RegisterNetEvent('nova_laptop:client:place', function(kind)
    opening = false
    kind = kind == 'printer' and 'printer' or 'laptop'
    if kind == 'printer' and opened then closeLaptop() end
    CreateThread(function()
        if kind == 'printer' then Wait(600) end -- the camera eases back first
        local coords, rotation = LaptopPlacement.run(kind)
        if coords then
            TriggerServerEvent('nova_laptop:server:place', coords, rotation)
        else
            notify(rotation or ('You kept the %s.'):format(kind))
        end
    end)
end)

RegisterNetEvent('nova_laptop:client:placed', function(_, via, kind)
    if kind == 'printer' then
        return notify('Printer set up. Print copies from the Newsstand while you stand beside it.')
    end
    -- Straight on to the desktop.
    SetTimeout(300, function() requestOpen(via == 'item' and 'item' or 'placed') end)
end)

RegisterNetEvent('nova_laptop:client:pickedUp', function(kind)
    if kind == 'printer' then return notify('You picked up your printer.') end
    if opened then closeLaptop() end
    notify('You picked up your laptop.')
end)

-- The laptop's menu: Adjust Screen Position (staff), done with the laptop closed.
RegisterNUICallback('adjustScreen', function(_, cb)
    cb({ ok = true })
    ExecuteCommand('laptopscreen')
end)

LaptopScreen.beforeEdit = function() if opened then closeLaptop() end end
LaptopScreen.notify = notify

LaptopPlacement.busy = function() return opened or opening or LaptopPlacement.active() end
LaptopPlacement.setup(function() if not opened then requestOpen('placed') end end, function()
    if opened then closeLaptop() end
    TriggerServerEvent('nova_laptop:server:pickUp', 'laptop')
end)

RegisterNetEvent('nova_laptop:client:denied', function(message)
    opening = false
    notify(message)
end)

RegisterNetEvent('nova_laptop:client:forceClose', closeLaptop)

RegisterNetEvent('nova_laptop:client:jobsChanged', function()
    if opened then sendUi({ type = 'jobsChanged' }) end
end)
RegisterNetEvent('nova_laptop:client:jobsNotice', function(item)
    if type(item) ~= 'table' or type(item.title) ~= 'string' or type(item.body) ~= 'string' then return end
    if opened then sendUi({ type = 'jobsNotice', notice = item }) end
    if not opened then
        local message = (item.title .. ': ' .. item.body):gsub('~', '')
        if utf8.len(message) and utf8.len(message) > 190 then message = message:sub(1, utf8.offset(message, 191) - 1) .. '...' end
        BeginTextCommandThefeedPost('STRING')
        local offset = 1
        while offset <= #message do
            local finish = math.min(offset + 89, #message)
            while finish < #message and message:byte(finish + 1) >= 128 and message:byte(finish + 1) < 192 do finish = finish - 1 end
            AddTextComponentSubstringPlayerName(message:sub(offset, finish))
            offset = finish + 1
        end
        EndTextCommandThefeedPostTicker(false, false)
    end
end)


RegisterNUICallback('ready', function(data, cb)
    cb({ ok = true })
    -- The screen painted on the prop says so too.
    if type(data) == 'table' and data.dui then return end
    nuiReady = true
    if opened and display == 'screen' and lastPayload then SendNUIMessage({ type = 'open', payload = lastPayload }) end
end)

-- Keys typed into a field on the laptop's screen, from the NUI page.
RegisterNUICallback('keys', function(data, cb)
    cb({ ok = true })
    if display == 'world' and type(data) == 'table' and type(data.keys) == 'table' then
        LaptopScreen.send({ type = 'keys', keys = data.keys })
    end
end)

-- A field on the laptop's screen gained or lost the caret.
RegisterNUICallback('typing', function(data, cb)
    cb({ ok = true })
    if display == 'world' and type(data) == 'table' then LaptopScreen.typing(data.active == true) end
end)

RegisterNUICallback('close', function(_, cb)
    closeLaptop()
    cb({ ok = true })
end)

RegisterNUICallback('action', function(data, cb)
    if not opened or type(data) ~= 'table' then cb({ ok = false, error = 'Laptop is closed.' }) return end
    sequence = sequence % 2147483646 + 1
    local id = sequence
    pending[id] = cb
    TriggerServerEvent('nova_laptop:server:request', id, data.action, data.payload or {})
    SetTimeout(8000, function()
        if pending[id] then
            pending[id]({ ok = false, error = 'Server response timed out. Reopen the laptop to check whether your changes saved.' })
            pending[id] = nil
        end
    end)
end)

RegisterNetEvent('nova_laptop:client:response', function(id, response)
    local cb = pending[id]
    if not cb then return end
    pending[id] = nil
    cb(response)
end)

-- Button sounds from the laptop's pages and the radial menu (Config.Sounds).
local SOUNDS = { hover = 'Hover', select = 'Select', back = 'Back' }
RegisterNUICallback('sound', function(data, cb)
    cb({ ok = true })
    local sound = Config.Sounds and Config.Sounds.Enabled and type(data) == 'table' and Config.Sounds[SOUNDS[data.kind] or '']
    if sound then PlaySoundFrontend(-1, sound[1], sound[2], true) end
end)

-- The Camera app: the laptop closes and the player raises a camera.
RegisterNUICallback('camera', function(_, cb)
    cb({ ok = true })
    if not opened then return end
    closeLaptop()
    SetTimeout(450, Camera.start)
end)

-- ── reading a printed copy ─────────────────────────────────────────────

local reading = false

RegisterNetEvent('nova_laptop:client:readIssue', function(issue)
    if opened or opening or reading or type(issue) ~= 'table' then return end
    reading = true
    SetNuiFocus(true, true)
    SendNUIMessage({ type = 'reader', issue = issue })
end)

RegisterNUICallback('readerClose', function(_, cb)
    cb({ ok = true })
    if not reading then return end
    reading = false
    SetNuiFocus(false, false)
    Hints.swallowPause()
end)

exports('ReadMagazine', function(data)
    if opened or reading then return end
    exports.ox_inventory:useItem(data, function(item)
        local issue = item and item.metadata and item.metadata.issue
        if issue then TriggerServerEvent('nova_laptop:server:readIssue', issue) end
    end)
end)

if Config.Command.Enabled then
    RegisterCommand(Config.Command.Name, function() requestOpen('command') end, false)
    if Config.Keybind ~= '' then RegisterKeyMapping(Config.Command.Name, 'Open laptop', 'keyboard', Config.Keybind) end
    CreateThread(function()
        TriggerEvent('chat:addSuggestion', '/' .. Config.Command.Name, 'Open your laptop desktop')
        if Config.News.Printing.Command then
            TriggerEvent('chat:addSuggestion', '/' .. Config.News.Printing.Command, 'Set the newsroom printer down (object_gizmo)')
        end
    end)
end

-- F8 recovery command, available even if the UI fails or /laptop is disabled.
RegisterCommand('laptopclose', closeLaptop, false)

exports('OpenLaptop', function() requestOpen('command') end)
exports('CloseLaptop', closeLaptop)
exports('IsOpen', function() return opened end)
exports('UseLaptop', function(data)
    if opened or opening then return end
    local allowed, reason = canOpen()
    if not allowed then notify(reason) return end
    exports.ox_inventory:useItem(data, function(item)
        if item then requestOpen('item') end
    end)
end)

AddEventHandler('QBCore:Client:OnPlayerUnload', closeLaptop)
RegisterNetEvent('esx:onPlayerLogout', closeLaptop)
AddEventHandler('onResourceStop', function(name)
    if name ~= GetCurrentResourceName() then return end
    closeLaptop()
    TriggerEvent('chat:removeSuggestion', '/' .. Config.Command.Name)
end)

-- No per-frame work while closed. Focus consumes input while open; these
-- controls also protect against input-keeping enabled by another resource.
CreateThread(function()
    while true do
        if opened then
            DisablePlayerFiring(PlayerId(), true)
            DisableControlAction(0, 1, true)
            DisableControlAction(0, 2, true)
            DisableControlAction(0, 24, true)
            DisableControlAction(0, 25, true)
            DisableControlAction(0, 30, true)
            DisableControlAction(0, 31, true)
            DisableControlAction(0, 200, true)
            Wait(0)
        else Wait(350) end
    end
end)

CreateThread(function()
    while true do
        Wait(500)
        if opened then
            local allowed = canOpen()
            if not allowed or (display == 'world' and not LaptopScreen.active()) then closeLaptop() end
            if display == 'world' and not LaptopPlacement.nearby(Config.Placement.UseDistance + 1.0) then closeLaptop() end
        end
    end
end)
