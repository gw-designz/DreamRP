fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'fs-garages'
author 'Fantasy Scripts'
description 'NoPixel V inspired garages for ESX, QBCore and Qbox: a kiosk with its screen on it, park by driving into a space, garages made in game.'
version '1.0.1'

-- The built React pages: the garage creator an admin sees, and the garage
-- screen the game paints on every kiosk. Run `npm run build` in web/ before
-- shipping; web/build is generated.
ui_page 'web/build/index.html'

files {
    'web/build/index.html',
    'web/build/kiosk.html',
    'web/build/assets/*.js',
    'web/build/assets/*.css',
    'web/build/assets/*.woff2',
    'stream/fs_garages.ytyp',
}

-- The kiosk model, in stream/.
data_file 'DLC_ITYP_REQUEST' 'stream/fs_garages.ytyp'

shared_scripts {
    'config/config.lua',
    'config/integrations.lua',
    'locales/*.lua',
    'shared/util.lua',
    -- The game's vehicle names and the extras each must keep on.
    'shared/models.lua',
    -- Car keys and fuel: the known scripts first, then the owner's own, so
    -- custom.lua can replace any of them.
    'integrations/init.lua',
    'integrations/known.lua',
    'integrations/custom.lua',
    -- Where everything is on the kiosk screen: the same lines on both sides.
    'shared/kiosk.lua',
    -- The three adapters register themselves; init.lua then picks one, so
    -- it loads after them.
    'bridge/esx.lua',
    'bridge/qbcore.lua',
    'bridge/qbox.lua',
    'bridge/init.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/db.lua',
    'server/main.lua',
    'server/garages.lua',
    'server/vehicles.lua',
}

client_scripts {
    'client/main.lua',
    'client/prompt.lua',
    'client/props.lua',
    'client/parking.lua',
    'client/kiosk.lua',
    'client/creator.lua',
}

dependency 'oxmysql'

-- Left open (not encrypted) when the resource is escrowed, so server owners
-- can change the settings, the words, the framework code, the car keys and
-- fuel hooks, and the saved garages in data/.
escrow_ignore {
    'config/*.lua',
    'locales/*.lua',
    'bridge/*.lua',
    'integrations/*.lua',
    'data/*',
}
