-- Contextual control prompts, shown in the controls bar (bottom center). While prompts are up
-- they replace the vehicle key hints; HidePrompts brings the hints back if still driving.
--
-- exports['my-hud']:ShowPrompts({
--     { key = 'LT', control = 25, label = 'Aim' },
--     { key = 'B', control = 177, label = 'Bait', kbd = 'R' }, -- kbd overrides the keyboard label
-- })
-- exports['my-hud']:HidePrompts()

local items
local owner
local keyboard = true

local function keyboardLabel(item)
    if item.kbd then return tostring(item.kbd) end
    if not item.control then return item.key end
    local btn = GetControlInstructionalButton(0, item.control, true)
    if type(btn) == 'string' then
        if btn:sub(1, 2) == 't_' then return btn:sub(3) end
        if Config.KeyLabels[btn] then return Config.KeyLabels[btn] end
    end
    return item.key
end

local function send()
    local list = {}
    for i, item in ipairs(items) do
        local key = tostring(item.key or '?')
        local kbd = keyboard and keyboardLabel(item) or nil
        list[i] = {
            label = tostring(item.label or ''),
            key = keyboard and kbd or key,
            circle = not keyboard and Config.CircleKeys[key:upper()] == true,
        }
    end
    Hud.send('prompts', { items = list })
end

local watcher = 0

local function watchInputMode(id)
    while items and watcher == id do
        local now = IsUsingKeyboard(0)
        if now ~= keyboard then
            keyboard = now
            send()
        end
        Wait(250)
    end
end

local function show(list)
    if type(list) ~= 'table' or #list == 0 then return end
    local wasShowing = items ~= nil
    items = list
    owner = GetInvokingResource()
    keyboard = IsUsingKeyboard(0)
    send()
    if not wasShowing then
        watcher = watcher + 1
        local id = watcher
        CreateThread(function() watchInputMode(id) end)
    end
end

local function hide()
    if not items then return end
    items, owner = nil, nil
    Hud.send('hidePrompts')
end

exports('ShowPrompts', show)
exports('HidePrompts', hide)

-- Clear prompts left behind by a resource that stopped while showing them.
AddEventHandler('onResourceStop', function(res)
    if owner and res == owner then hide() end
end)

-- After a NUI reload, put the current prompts back.
function Hud.resendPrompts()
    if items then send() end
end
