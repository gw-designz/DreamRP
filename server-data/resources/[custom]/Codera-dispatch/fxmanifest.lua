
fx_version 'cerulean'
game 'gta5'
lua54 'yes'

shared_script {
	'config.lua',
}

client_scripts {
	'editable_client.lua',
	'client.lua',
}

server_scripts {
	'server.lua'
}

ui_page 'html/index.html'
files {
	'html/*',
	'html/**',
}

escrow_ignore {
	'config.lua',
	'editable_client.lua'
}

