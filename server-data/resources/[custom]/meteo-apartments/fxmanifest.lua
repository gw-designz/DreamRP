fx_version 'cerulean'
game 'gta5'
nui_callback_strict_mode 'true'

name 'meteo-apartments'
description 'Apartment system with creator, complexes, rooms, elevator, furniture, and member management'
author 'Meteo Studios'
version '1.1.0'
copyright 'Copyright © 2026 Meteo Studios. All rights reserved.'
-- Website: https://meteofivem.net/
-- Join our community at https://discord.gg/qbVT93GAFT

ox_lib 'locale'

shared_scripts {
    '@ox_lib/init.lua',
    'shared/config.lua',
    'shared/debug.lua',
    'shared/utils.lua',
}

client_scripts {
    'client/source/cl_functions.lua',
    'client/source/cl_alerts.lua',
    'client/cl_main.lua',
    'client/main/cl_spawn.lua',
    'client/source/cl_compatibility.lua',
    'client/main/cl_zones.lua',
    'client/main/cl_elevator.lua',
    'client/main/cl_garage.lua',
    'client/main/cl_npc.lua',
    'client/main/cl_nui.lua',
    'client/main/cl_alarm.lua',
    'client/main/cl_exports.lua',
    'client/main/cl_dev.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/source/sv_alerts.lua',
    'server/source/sv_spawn.lua',
    'server/sv_logs.lua',
    'server/sv_main.lua',
    'server/main/sv_callbacks.lua',
    'server/main/sv_members.lua',
    'server/main/sv_doorlock.lua',
    'server/main/sv_exports.lua',
    'server/main/sv_dev.lua',
}

lua54 'yes'

escrow_ignore {
    'shared/config.lua',
    'shared/debug.lua',
    'shared/main.lua',
    'shared/complexes/*.lua',
    'client/source/*.lua',
    'server/source/*.lua',
    'server/sv_logs.lua',
}


-- [PRODUCTION START]
ui_page 'web/build/index.html'

files {
    'locales/*.json',
    'web/build/index.html',
    'web/build/*.css',
    'web/build/*.js',
    'shared/main.lua',
    'shared/complexes/*.lua',
}
-- [PRODUCTION END]
dependency '/assetpacks'