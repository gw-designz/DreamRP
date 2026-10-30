fx_version 'cerulean'
game 'gta5'

author 'NRG Development'
description 'Weazel News laptop for Qbox, shown on the laptop prop: LifeInvader staff portal, Weazel Writer, Magazine Editor, Newsstand and Camera'
version '2.0.0'

ui_page 'web/dist/index.html'

shared_scripts {
    'config.lua',
    'shared/screen.lua'
}
client_scripts {
    '@ox_lib/init.lua',
    'client/hints.lua',
    'client/screen.lua',
    'client/camera.lua',
    'client/placement.lua',
    'client/radial.lua',
    'client/printer.lua',
    'client/main.lua'
}
server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server_config.lua',
    'server/bridge.lua',
    'server/storage.lua',
    'server/placement.lua',
    'server/screens.lua',
    'server/news.lua',
    'server/main.lua'
}

files {
    'web/dist/index.html',
    'web/dist/dui.html',
    'web/dist/assets/*',
    'web/dist/wallpaper.svg'
}
