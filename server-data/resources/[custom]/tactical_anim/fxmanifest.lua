fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'pulsar_tactical_anim'
author 'Fear'
description 'Tactical pistol and rifle movement and cover reanimations - Non Pulsar FW Version'
version '1.1.0'

ui_page 'html/index.html'

shared_script 'config.lua'

client_script 'client/main.lua'

server_scripts {
	'server/validate.lua',
	'server/main.lua',
}

files {
	'html/index.html',
	'html/style.css',
	'html/app.js',
	'html/fonts/*.ttf',
	'html/icons/*.svg',
	'data/weaponanimations.meta',
	'data/dlc/**/weaponanimations.meta',
	'data/pedpersonality.ymt',
}

data_file 'WEAPON_ANIMATIONS_FILE' 'data/weaponanimations.meta'
data_file 'WEAPON_ANIMATIONS_FILE' 'data/dlc/**/weaponanimations.meta'
data_file 'PED_PERSONALITY_FILE' 'data/pedpersonality.ymt'
