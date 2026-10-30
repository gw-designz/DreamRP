AccentColor = "#88E52B" -- Here you can change the accent color of the UI

local loaded = false

function TriggerUIEvent(eventName, ...)
    if loaded then
        SendNUIMessage({
            type = eventName,
            args = {...}
        })
    else
        local args = {...}
        CreateThread(function()
            while not loaded do
                Wait(0)
            end

            SendNUIMessage({
                type = eventName,
                args = args,
            })
        end)
    end
end

function SetNuiActive(state)
    if state then -- order matters here
        SetNuiFocus(true, true)
        SetNuiFocusKeepInput(true)
    else
        SetNuiFocusKeepInput(false)
        SetNuiFocus(false, false)
    end
end

RegisterNUICallback("loaded", function(data, cb)
    loaded = true
    cb("true")
end)

local function split(inputstr, sep)
    if sep == nil then
        sep = "%s"
    end
    local t = {}
    for str in string.gmatch(inputstr, "([^"..sep.."]+)") do
        t[#t + 1] = str
    end
    return t
end

CreateThread(function()
    while not loaded do
        Wait(0)
    end

    local iconUrl = ""
    local iconExt = ""

    local format = split(bridge.inv.getItemImageUrl(";"), ";")

    iconUrl = format[1]
    iconExt = format[2]
    iconExt = iconExt:sub(2)

    TriggerUIEvent("tablet:setItemIconsURL", iconUrl)
    TriggerUIEvent("tablet:setItemIconsExt", iconExt)
end)