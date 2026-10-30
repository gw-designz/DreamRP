
game 'gta5'
fx_version 'cerulean'
lua54 'yes'

ui_page 'web/dist/index.html'

author 'Bablo'
description 'Bablo Billing System'
version '1.0.7'

files {
    'web/dist/assets/*.js',
    'web/dist/assets/*.css',
    'web/dist/index.html',
    'src/locales/*.json'
}

shared_scripts {
    'config.lua',
    'src/utils/callbacks.lua',
    'framework/init.lua',
    'src/utils/table.lua',
    'src/utils/debug.lua',
    'src/utils/error-handling.lua',
    'src/utils/tax.lua',
    'src/utils/payout.lua',
    'src/resource/shared/locale.lua',
    'src/resource/shared/main.lua',
    'src/utils/uuid.lua'
}

client_scripts {
    'framework/esx/client.lua',
    'framework/qbcore/client.lua',
    'framework/qbox/client.lua',
    'target/ox_target.lua',
    'target/qb-target.lua',
    'src/resource/client/*.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'src/database/default-presets.lua',
    'src/database/sql-init.lua',
    'framework/esx/server.lua',
    'framework/qbcore/server.lua',
    'framework/qbox/server.lua',
    'src/resource/server/mock.lua',
    'src/resource/server/*.lua'
}

server_exports {
    'payInvoice',
    'getInvoice',
    'createInvoice',
    'CreateInvoice',
    'deleteInvoice',
}

escrow_ignore {
    'framework/**/*.lua',
    'target/*.lua',
    'config.lua',
    'examples/**/*.lua',
    'src/locales/*.lua',
    'src/resource/server/mock.lua',
    'src/resource/shared/main.lua',
}

dependency '/assetpacks'
