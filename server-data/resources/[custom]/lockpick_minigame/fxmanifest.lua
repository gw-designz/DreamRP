fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'whale'
description 'Pin-tumbler lockpicking minigame with regular / advanced / sophisticated tiers (Qbox)'
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

client_script 'client.lua'
server_script 'server.lua'

dependencies {
    'ox_lib',
    'ox_inventory',
}
