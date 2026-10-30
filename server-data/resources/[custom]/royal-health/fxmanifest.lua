fx_version 'cerulean'
game 'gta5'

author 'Royal'
description 'Royal Health - bone damage system'
version '1.0.0'
lua54 'yes'

ox_lib 'locale'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
}

files {
    'locales/*.json',
}

client_scripts {
    'bridge/client/*.lua',
    'client/main.lua',
    'client/bones.lua',
    'client/commands.lua',
}

server_scripts {
    'bridge/server/*.lua',
    'server/main.lua',
}

dependencies {
    'ox_lib',
}
