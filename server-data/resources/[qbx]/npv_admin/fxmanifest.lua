fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'npv_admin'
description 'NoPixel V-inspired admin menu + DM tool (scenario builder, dialogue, scripts) for QBox'
version '0.1.0'

ui_page 'web/dist/index.html'

shared_scripts {
    '@ox_lib/init.lua',
    'config/config.lua',
    'config/permissions.lua',
    'config/commands.lua',
    'config/commands_import.lua',
    'shared/utils.lua',
}

client_scripts {
    'client/nui.lua',
    'client/main.lua',
    'client/radial.lua',
    'client/commands.lua',
    'client/noclip.lua',
    'client/appearance.lua',
    'client/editor.lua',
    'client/npcs.lua',
    'client/dialogue.lua',
    'client/ropes.lua',
    'client/trolleys.lua',
    'client/doors.lua',
    'client/scenarios.lua',
    'client/scriptfx.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/database.lua',
    'server/permissions.lua',
    'server/audit.lua',
    'server/players.lua',
    'server/moderation.lua',
    'server/commands.lua',
    'server/commands_import.lua',
    'server/scenarios.lua',
    'server/scripts.lua',
    'server/trolleys.lua',
    'server/doors.lua',
    'server/dmactions.lua',
    'server/main.lua',
}

files {
    'web/dist/index.html',
    'web/dist/assets/*',
}

dependencies {
    'ox_lib',
    'oxmysql',
    'qbx_core',
}
