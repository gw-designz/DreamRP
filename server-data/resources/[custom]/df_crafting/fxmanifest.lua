fx_version 'cerulean'
game 'gta5'

name "df_crafting"
description "A Dynamic Crafting System"
author "DFScripts"
version "2026.08.09"
lua54 'yes'

shared_scripts {
	'@ox_lib/init.lua',
	'configuration/config.lua',
	'shared/locale.lua'
}

client_scripts {
    'integrations/client.lua',
	'client/*.lua'
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'configuration/server_config.lua',
    'server/init.lua',
    'integrations/server.lua',
    'server/logs.lua',
    'server/database.lua',
    'server/admin.lua',
	'server/main.lua'
}

ui_page 'nui/index.html'

files {
    'nui/index.html',
    'nui/app.css',
    'nui/app.js',
    'nui/assets/*.webp',
    'locales/*.json'
}

escrow_ignore {
  'configuration/*.lua',
  'integrations/*.lua',
  'locales/*.json',
}

dependency '/assetpacks'