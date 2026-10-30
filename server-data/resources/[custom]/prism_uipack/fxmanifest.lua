
fx_version 'cerulean'
use_experimental_fxv2_oal 'yes'
game 'gta5'
lua54 'yes'
author 'Prism Scripts - Zykem'
version '1.4.0'

dependency 'ox_lib'

file 'init.lua'
file 'config_init.lua'

client_scripts {
    'modules/*.lua',
    'main.lua',
    "nui.lua"
}

server_scripts {
    "server_modules/*.lua",
    "nui.lua"
}

ui_page 'web/build/index.html'
files {
    'web/build/**',
    'locales/*.lua',
    "config.lua"
}

escrow_ignore {
    'config_init.lua',
    'locales/*.lua',
    'client/events.lua',
    'init.lua',
    'config.lua',
    'modules/*.lua',
    'server_modules/*.lua'
}
dependency '/assetpacks'
