fx_version 'cerulean'
use_experimental_fxv2_oal 'yes'
lua54 'yes'
game 'gta5'

name 'ox_fuel'
author 'Overextended'
version '1.5.4'
repository 'https://github.com/overextended/ox_fuel'
description 'Fuel management system with pump nozzles, hoses and interactive pump screens'

dependencies {
	'ox_lib',
	'ox_inventory',
}

shared_scripts {
	'@ox_lib/init.lua',
	'config.lua'
}

server_scripts {
	'server.lua'
}

client_script 'client/init.lua'

files {
	'locales/*.json',
	'data/stations.lua',
	'data/screens.json',
	'client/*.lua',
	'web/index.html',
	'web/app.js',
	'web/style.css',
	'web/colors.css',
}

ox_libs {
	'math',
	'locale',
}
