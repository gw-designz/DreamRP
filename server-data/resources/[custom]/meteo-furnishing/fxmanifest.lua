fx_version 'cerulean'
game 'gta5'
nui_callback_strict_mode 'true'

name 'meteo-furnishing'
description 'Furnishing system for Meteo apartments and properties'
author 'Meteo Studios'
version '1.1.0'
copyright 'Copyright © 2026 Meteo Studios. All rights reserved.'
-- Website: https://meteofivem.net/
-- Follow us on Github - https://github.com/meteofivem

ox_lib 'locale'

shared_scripts {
    '@ox_lib/init.lua',
    'shared/config.lua',
    'shared/crafting.lua',
    'shared/debug.lua',
    'shared/targets.lua',
    'shared/utils.lua',
}

client_scripts {
    'client/cl_data.lua',
    'client/cl_main.lua',
    'client/cl_freecam.lua',
    'client/cl_gizmo.lua',
    'client/cl_nui.lua',
    'client/cl_functions.lua',
    'client/cl_targets.lua',
    'client/cl_dui.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/sv_main.lua',
    'server/sv_dui.lua',
}

escrow_ignore {
    'shared/config.lua',
    'shared/crafting.lua',
}

lua54 'yes'

-- [PRODUCTION START]
ui_page 'web/build/index.html'

files {
    'locales/*.json',
    'web/build/index.html',
    'web/build/*.css',
    'web/build/*.js',
    'web/build/images/*.webp',
    'dui/org_hq.html',
    'dui/css/style.css',
    'dui/js/main.js',
}
-- [PRODUCTION END]


dependency '/assetpacks'