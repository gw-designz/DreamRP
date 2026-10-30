fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'whale'
description 'Shake-the-mouse minigame for breaking out of p_policejob cuffs (Qbox)'
version '1.0.0'

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/script.js',
    'html/fonts/*.ttf',
}

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
}

client_scripts {
    '@qbx_core/modules/playerdata.lua',
    'client.lua',
}
server_script 'server.lua'

dependencies {
    'ox_lib',
    'qbx_core',
    'p_policejob',
}
