fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'oph3z-phone'
author 'Oph3Z'
description 'Advanced phone script for FiveM made by Oph3Z (NoPixel-style UI edition)'
version '1.1.0'

shared_scripts {
    'config.lua',
    'GetCore.lua',
    'locales/*.lua',
    'shared/locale.lua',
}

client_scripts {
    'client/utilities.lua',
    'client/*.lua',
    'client/app/**/*.lua',
}

server_scripts {
    'server_config.lua',
    'server/utilities.lua',
    'server/sql.lua',
    'server/database.lua',
    'server/migrate.lua',
    'server/schema.lua',
    'server/notifications.lua',
    'server/api.lua',
    'server/airdrop.lua',
    'server/main.lua',
    'server/np_lib.lua', -- helpers for the NoPixel-style apps (must load before server/app)
    'server/app/**/*.lua',
}

ui_page 'build/index.html'

files {
    'build/index.html',
    'build/assets/*.js',
    'build/assets/*.css',
    'build/assets/*.png',
    'build/assets/*.svg',
    'build/assets/*.jpg',
    'build/assets/*.webp',
    'build/assets/*.woff',
    'build/assets/*.woff2',
    'build/audio/*.ogg',
    'build/audio/*.mp3',
    'build/audio/*.wav',
    'build/gamerender/**/*',
    'build/mapStyles/**/*',
}