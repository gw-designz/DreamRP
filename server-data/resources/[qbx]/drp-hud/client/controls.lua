-- Controls bar (bottom right): one bar for every script's key prompts.
--
-- Sources, highest priority first:
--   1. ShowPrompts export - scripts that integrate directly
--   2. Prompts captured from other scripts (ox_lib, qb-core, ESX, cd_drawtextui, interact), e.g.
--      "[E] - Open garage" becomes an E glyph with "Open garage"
--   3. Vehicle key hints (Config.Vehicle.hints) while driving
--
-- Item fields (all optional except label):
--   label    text next to the key
--   command  a RegisterKeyMapping / lib.addKeybind name; shows the key the player actually bound
--   control  a GTA control id; shows the key bound to that control
--   key      fallback label when neither resolves (also the controller label without `pad`)
--   pad      controller label (LT, RT, A, B, X, Y, ...)
--   kbd      keyboard label override
--   resource only show this item while that resource is started
--
-- exports['my-hud']:ShowPrompts({
--     { key = 'LT', control = 25, label = 'Aim' },
--     { key = 'B', control = 177, label = 'Bait', kbd = 'R' },
--     { command = 'engine', key = 'G', label = 'Engine' },
-- })
-- exports['my-hud']:HidePrompts()

local exported, exportOwner
local captured, capturedOrder = {}, {}
local hints, hintToken = nil, 0
local keyboard = true
local lastSent = {}

---------------------------------------------------------------- key resolution

local function buttonLabel(btn)
    if type(btn) ~= 'string' or btn == '' then return end
    if btn:sub(1, 2) == 't_' then
        local text = btn:sub(3)
        return text ~= '' and text or nil
    end
    return Config.KeyLabels[btn]
end

-- Registered command names (lowercase), refreshed every few seconds so scripts started later
-- are picked up.
local commands, commandsAt = {}, -10000

local function hasCommand(name)
    local now = GetGameTimer()
    if now - commandsAt > 5000 then
        commandsAt = now
        commands = {}
        for _, c in ipairs(GetRegisteredCommands()) do commands[c.name:lower()] = true end
    end
    return commands[name:lower()] == true
end

-- Key mappings are looked up by the command hash with the high bit set. lib.addKeybind and
-- +/- mappings register as '+name', plain RegisterKeyMapping as 'name', so try both. Only
-- registered commands are asked: for an unknown hash the game returns a stale label (whatever
-- it answered last) instead of nothing, which made every unknown command show the same key.
local function commandLabel(cmd)
    local names = cmd:sub(1, 1) == '+' and { cmd } or { '+' .. cmd, cmd }
    for _, name in ipairs(names) do
        if hasCommand(name) then
            local label = buttonLabel(GetControlInstructionalButton(0, joaat(name) | 0x80000000, true))
            if label then return label end
        end
    end
end

local function keyboardLabel(item)
    if item.kbd then return tostring(item.kbd) end
    if item.command then
        local label = commandLabel(tostring(item.command))
        if label then return label end
    end
    if item.control then
        local label = buttonLabel(GetControlInstructionalButton(0, item.control, true))
        if label then return label end
    end
    return item.key and tostring(item.key) or nil
end

local function resolve(list)
    local out = {}
    for _, item in ipairs(list or {}) do
        if not item.resource or GetResourceState(item.resource) == 'started' then
            local key
            if keyboard then
                key = keyboardLabel(item)
            else
                key = item.pad or item.key or keyboardLabel(item)
                key = key and tostring(key) or nil
            end
            out[#out + 1] = {
                label = tostring(item.label or ''),
                key = key,
                circle = not keyboard and key ~= nil and Config.CircleKeys[key:upper()] == true,
            }
        end
    end
    return #out > 0 and out or nil
end

Hud.resolveControls = resolve

---------------------------------------------------------------- sending

local function sendChannel(channel, list, show, hide)
    local items = list and Hud.settings.showControls and resolve(list) or nil
    local encoded = items and json.encode(items) or ''
    if encoded == lastSent[channel] then return end
    lastSent[channel] = encoded
    if items then Hud.send(show, { items = items }) else Hud.send(hide) end
end

local function activeCaptured()
    for i = #capturedOrder, 1, -1 do
        local items = captured[capturedOrder[i]]
        if items then return items end
    end
end

local function refresh()
    sendChannel('prompts', exported or activeCaptured(), 'prompts', 'hidePrompts')
    sendChannel('hints', hints, 'hints', 'hideHints')
end

local function showing()
    return exported ~= nil or hints ~= nil or activeCaptured() ~= nil
end

-- Follow keyboard / controller switches and rebinds while anything is up. Unchanged
-- results are dropped in sendChannel, so this only reaches the NUI when a label changes.
CreateThread(function()
    while true do
        if showing() then
            keyboard = IsUsingKeyboard(0)
            refresh()
            Wait(250)
        else
            Wait(500)
        end
    end
end)

---------------------------------------------------------------- export source

local function show(list)
    if type(list) ~= 'table' or #list == 0 then return end
    exported = list
    exportOwner = GetInvokingResource()
    keyboard = IsUsingKeyboard(0)
    refresh()
end

local function hide()
    if not exported then return end
    exported, exportOwner = nil, nil
    refresh()
end

exports('ShowPrompts', show)
exports('HidePrompts', hide)

---------------------------------------------------------------- vehicle hints

function Hud.setHints(list, duration)
    hintToken = hintToken + 1
    hints = list and #list > 0 and list or nil
    keyboard = IsUsingKeyboard(0)
    refresh()
    if hints and duration and duration > 0 then
        local token = hintToken
        SetTimeout(duration, function()
            if token == hintToken then Hud.setHints(nil) end
        end)
    end
end

---------------------------------------------------------------- text UI capture

local function tidy(s)
    s = s:gsub('^[%s%-:|>/,]+', ''):gsub('^[Tt][Oo]%s+', ''):gsub('[%s%-:|/,]+$', '')
    return s
end

local function clean(s)
    s = tostring(s or '')
    s = s:gsub('~[%a_]-~', ''):gsub('%^%d', ''):gsub('<[^>]->', ''):gsub('%*%*', '')
    return (s:gsub('^%s+', ''):gsub('%s+$', ''))
end

-- "[E] - Open garage", "Press [E] to open", "[E] Open  [G] Lock", "E - Open", "Press E to open"
local function parseText(text)
    text = clean(text)
    if text == '' then return nil end

    local keys = {}
    for s, key, e in text:gmatch('()%[([^%]]+)%]()') do keys[#keys + 1] = { s = s, key = key, e = e } end
    if #keys > 0 then
        local items = {}
        for i, k in ipairs(keys) do
            local stop = keys[i + 1] and keys[i + 1].s - 1 or #text
            local label = tidy(text:sub(k.e, stop))
            -- "Open garage [E]": the label sits before the key
            if label == '' and i == 1 then label = tidy(text:sub(1, k.s - 1):gsub('^[Pp]ress%s+', '')) end
            items[#items + 1] = { key = tidy(k.key):upper(), label = label }
        end
        return items
    end

    local key, label = text:match('^[Pp]ress%s+(%S+)%s+[Tt][Oo]%s+(.+)$')
    if not key then key, label = text:match('^(%w+)%s*[%-:]%s*(.+)$') end
    if key and #key <= 6 then return { { key = key:upper(), label = tidy(label) } } end
    return { { label = text } }
end

local function storeCaptured(source, items)
    captured[source] = items
    for i = #capturedOrder, 1, -1 do
        if capturedOrder[i] == source then table.remove(capturedOrder, i) end
    end
    if captured[source] then capturedOrder[#capturedOrder + 1] = source end
    keyboard = IsUsingKeyboard(0)
    refresh()
end

local function setCaptured(source, text)
    storeCaptured(source, text and parseText(text) or nil)
end

local capture = Config.Controls.capture

-- ox_lib (also Qbox's DrawText): poll its open state, it has no event to listen to.
if capture.ox_lib then
    CreateThread(function()
        local last
        while true do
            if GetResourceState('ox_lib') == 'started' then
                local ok, open, text = pcall(function() return exports.ox_lib:isTextUIOpen() end)
                local current = ok and open and text or nil
                if current ~= last then
                    last = current
                    setCaptured('ox_lib', current)
                end
                Wait(200)
            else
                Wait(2000)
            end
        end
    end)
end

-- qb-core's DrawText event (scripts calling the export directly are not visible to us).
if capture.qb then
    RegisterNetEvent('qb-core:client:DrawText', function(text) setCaptured('qb', text) end)
    RegisterNetEvent('qb-core:client:ChangeText', function(text) setCaptured('qb', text) end)
    RegisterNetEvent('qb-core:client:HideText', function() setCaptured('qb', nil) end)
    RegisterNetEvent('qb-core:client:KeyPressed', function() setCaptured('qb', nil) end)
end

if capture.esx then
    RegisterNetEvent('ESX:TextUI', function(text) setCaptured('esx', text) end)
    RegisterNetEvent('ESX:HideUI', function() setCaptured('esx', nil) end)
end

if capture.cd_drawtextui then
    RegisterNetEvent('cd_drawtextui:ShowUI', function(action, text)
        setCaptured('cd', action == 'show' and text or nil)
    end)
    RegisterNetEvent('cd_drawtextui:HideUI', function() setCaptured('cd', nil) end)
end

-- interact (floating world prompts, used by Renewed-Banking and others). It has no API for the
-- current prompt, so its client/interacts.lua sends 'interact:promptChanged' (see README).
if capture.interact then
    AddEventHandler('interact:promptChanged', function(prompt)
        if type(prompt) ~= 'table' then return storeCaptured('interact', nil) end
        local items = { { control = 38, key = 'E', label = tostring(prompt.label or 'Interact') } }
        if (tonumber(prompt.amount) or 1) > 1 then
            items[2] = { key = 'WHEELDOWN', pad = 'DPAD', label = 'More options' }
        end
        storeCaptured('interact', items)
    end)
end

---------------------------------------------------------------- lifecycle

-- Clear prompts left behind by a resource that stopped while showing them.
AddEventHandler('onResourceStop', function(res)
    if exportOwner and res == exportOwner then hide() end
    if res == 'ox_lib' then setCaptured('ox_lib', nil) end
    if res == 'interact' then storeCaptured('interact', nil) end
end)

-- After a NUI reload, put the current bar back.
function Hud.resendPrompts()
    lastSent = {}
    refresh()
end

Hud.onSettings(function(new, old)
    if new.showControls ~= old.showControls then refresh() end
end)
