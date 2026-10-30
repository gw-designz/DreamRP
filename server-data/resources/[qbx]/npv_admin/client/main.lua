AdminMode = false

local isStaff = false

local function refreshStaff()
    isStaff = lib.callback.await('npv_admin:isStaff', false) == true
    DmRadial.Sync(isStaff)
    return isStaff
end

local function setAdminMode(on)
    AdminMode = on
    Nui.Send('hud', { adminMode = on })
    TriggerEvent('npv_admin:client:adminModeChanged', on)
    if not on then
        TriggerEvent('npv_admin:client:adminModeOff')
    end
end

RegisterCommand(Config.Command, function()
    if Nui.open then return Nui.Close() end
    Nui.Open('admin')
end, false)
RegisterKeyMapping(Config.Command, 'Open the admin menu', 'keyboard', Config.OpenKey)

RegisterCommand('npv_dm', function()
    if Nui.open then
        if Nui.view == 'dm' then return Nui.Close() end
        return
    end
    Nui.Open('dm')
end, false)
RegisterKeyMapping('npv_dm', 'Toggle the DM tool', 'keyboard', Config.DmKey)

ClientAdminToggle = setAdminMode

-- Optional hotkeys for registry commands that declare a `key` (server still authorises each press).
for _, c in ipairs(Config.Commands) do
    if c.key and c.id ~= 'dm_tool' and not c.args then
        local cmdName = 'npv_cmd_' .. c.id
        RegisterCommand(cmdName, function()
            if not isStaff then return end
            lib.callback.await('npv_admin:rpc', false, 'command.run', { id = c.id, args = {} })
        end, false)
        RegisterKeyMapping(cmdName, ('Admin: %s'):format(c.label), 'keyboard', c.key)
    end
end

CreateThread(function()
    Wait(2000)
    refreshStaff()
    TriggerServerEvent('npv_admin:server:requestInteractables')
end)

-- Re-evaluate staff status when QBox says the player (re)loaded.
RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    TriggerServerEvent('npv_admin:server:refreshRank')
    Wait(1500)
    refreshStaff()
    TriggerServerEvent('npv_admin:server:requestInteractables')
end)

-- Never keep a dead player locked in the menu.
AddEventHandler('gameEventTriggered', function(name, args)
    if name == 'CEventNetworkEntityDamage' and Nui.open and args[1] == PlayerPedId() and IsEntityDead(PlayerPedId()) then
        Nui.Close()
    end
end)

-- Staff HUD badge text: "Scripts running" when any scenario is live.
CreateThread(function()
    local last
    while true do
        local live = GlobalState.npvLive or 0
        if live ~= last then
            last = live
            Nui.Send('hud', { scriptsRunning = live > 0 })
        end
        Wait(2000)
    end
end)

exports('isAdminMode', function() return AdminMode end)
