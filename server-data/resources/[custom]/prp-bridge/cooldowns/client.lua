---@param cooldowns table<string, number>
local function openMenu(cooldowns)
    local menuOptions = {}

    for key, minutes in pairs(cooldowns) do
        table.insert(menuOptions, {
            title = key,
            description = locale("SHOW_TIME_UNTIL_RESET", minutes),
            serverEvent = 'prp-bridge:cooldowns:server:resetKey',
            args = key,
            icon = 'refresh',
        })
    end

    bridge.fw.contextMenu({
        id = 'cooldowns-admin-menu',
        title = locale("COOLDOWNS_MENU_TITLE"),
        options = menuOptions,
    })

    bridge.fw.showContext('cooldowns-admin-menu')
end
RegisterNetEvent('prp-bridge:cooldowns:openMenu', openMenu)
