fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'my-hud'
description 'CircuitRP-style HUD: square minimap with status icons, top location bar, arc speedometer and control prompts'
author 'my-hud'
version '1.0.0'

shared_scripts {
    'config.lua',
    'bridge/shared.lua',
}

client_scripts {
    'bridge/client.lua',
    'client/utils.lua',
    'client/settings.lua',
    'client/map3d.lua',
    'client/minimap.lua',
    'client/voice.lua',
    'client/vehicle.lua',
    'client/vehcontrol.lua',
    'client/stress.lua',
    'client/controls.lua',
    'client/dev.lua',
    'client/main.lua',
}

server_scripts {
    'bridge/server.lua',
    'server/main.lua',
    'server/dev.lua',
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/script.js',
    'html/ui.js',
    'html/ui.css',
    'html/demo.js',
    'html/fonts/*.ttf',
    'html/icons/*.svg',
    -- the 3D minimap (client/map3d.lua) and the world it draws
    'html/map3d.js',
    'html/map3d/*.bin',
    'html/map3d/*.png',
    'html/map3d/*.json',
}
