
fx_version 'adamant'
game 'gta5'
version '2.0.5'
author 'Bablo Resources'
lua54 'yes'

dependencies {
    'ox_lib',
    'xsound'
}

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
    'module-defaults.lua',
    'locales/*.lua',
    'parcel-locations.lua',
    'src/resource/shared/**/*.lua',
    'src/inventories/*.lua'
}

client_scripts {
    'src/resource/client/**/*.lua',
    'src/targets/*.lua',
    'src/dispatches/*.lua',
    'frameworks/qbox/client.lua',
    'frameworks/esx/client.lua',
    'frameworks/qbcore/client.lua'
}

ui_page 'src/web/dist/index.html'

files {
    'vehicleHashes.json',
    'src/web/dist/index.html',
    'src/web/dist/**/*',
}

server_scripts {
    "webhooks.lua",
    'src/resource/server/**/*.lua',
    'frameworks/qbox/server.lua',
    'frameworks/esx/server.lua',
    'frameworks/qbcore/server.lua',
    'frameworks/custom/server.lua'
}

escrow_ignore {
    'frameworks/**/*.lua',
    'parcel-locations.lua',
    'locales/*.lua',
    'src/inventories/*.lua',
    'src/targets/*.lua',
    'src/dispatches/*.lua',
    'src/resource/shared/funcs.lua',
    'config.lua',
    'webhooks.lua',
    'vehicleHashes.json',
    'editor-overrides.json',
    'editor-overrides.backup.json',
    'data/**/*',
    'src/web/dist/**/*'
}

dependency '/assetpacks'
