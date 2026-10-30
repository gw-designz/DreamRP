fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'fantasy_license'
author 'Fantasy Scripts'
description 'License runtime for protected Fantasy Scripts resources.'
version '1.3.0'

client_script 'client.lua'

server_scripts {
  'server/main.lua',
}

-- Protected resources load these from fantasy_license on both sides.
files {
  'shared/crypto.lua',
  'loader.lua',
}
