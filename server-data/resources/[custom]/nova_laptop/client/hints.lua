--- The key hints along the bottom of the screen (the game's instructional buttons).
Hints = {}

local swallowing = false

--- Keeps the Escape that closed something from also opening the pause menu:
--- the pause keys stay off until Escape is let go, and a moment after.
function Hints.swallowPause()
    if swallowing then return end
    swallowing = true
    CreateThread(function()
        local deadline, released = GetGameTimer() + 1500, nil
        while GetGameTimer() < deadline do
            DisableControlAction(0, 199, true)
            DisableControlAction(0, 200, true)
            if IsPauseMenuActive() then SetFrontendActive(false) end
            if not IsDisabledControlPressed(0, 200) and not IsDisabledControlPressed(0, 199) then
                released = released or GetGameTimer()
                if GetGameTimer() - released > 250 then break end
            else
                released = nil
            end
            Wait(0)
        end
        swallowing = false
    end)
end

-- The NUI page draws them (web/src/KeyHints.tsx); this side says which.
-- Mouse buttons are named the way my-hud's Config.KeyLabels names them.
local BUTTONS = { b_100 = 'LMB', b_101 = 'RMB', b_102 = 'MMB', b_115 = 'WHEEL', b_116 = 'WHEEL', b_2000 = 'SPACE' }
local NAMES = { [24] = 'LMB', [25] = 'RMB', [241] = 'WHEEL', [242] = 'WHEEL', [177] = 'BACKSPACE', [200] = 'ESC', [202] = 'ESC' }
local shown, lastDrawn = nil, 0

--- The key bound to a control, as the player has it mapped ("t_E" -> "E").
local function keyName(control)
    local button = GetControlInstructionalButton(0, control, true) or ''
    return button:match('^t_(.+)$') or BUTTONS[button] or NAMES[control] or '?'
end

local function hide()
    if not shown then return end
    shown = nil
    SendNUIMessage({ type = 'hints', hints = false })
end

--- Shows this frame's hints, a list of { control, label }. They go to the
--- page only when a different list is passed, and leave once no one draws them.
function Hints.draw(list)
    lastDrawn = GetGameTimer()
    if shown == list then return end
    shown = list
    local out = {}
    for i, hint in ipairs(list) do
        out[i] = { key = keyName(hint[1]), label = hint[2] }
    end
    SendNUIMessage({ type = 'hints', hints = out })
end

--- Takes them down at once (before a photo, so they stay out of it).
Hints.hide = hide

CreateThread(function()
    while true do
        if shown and GetGameTimer() - lastDrawn > 100 then hide() end
        Wait(shown and 50 or 300)
    end
end)
