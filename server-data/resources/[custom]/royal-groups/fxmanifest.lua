fx_version 'cerulean'
game 'gta5'
lua54 'yes'

description 'Royal Groups'
author 'Royal'
repository 'https://github.com/royal-fivem/'

ui_page 'web/build/index.html'
-- ui_page 'http://localhost:5173/' -- dev

shared_scripts {
    '@ox_lib/init.lua',
    'shared/**/*.lua',
}

client_scripts {
    'client/**/*.lua',
}

server_scripts {
    'server/**/*.lua',
}

files {
    'web/build/index.html',
    'web/build/**/*',
}

dependencies {
    'ox_lib',
}
