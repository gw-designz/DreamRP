fx_version 'cerulean'
use_experimental_fxv2_oal 'yes'
game 'gta5'
lua54 'yes'

description 'Properties system for FiveM.'
author 'NoLag Development'
version '2.4.12'

shared_scripts {
  '@ox_lib/init.lua',
  'config.lua',
  'shared/init.lua',
  'furniture.lua',
  'ipls.lua',
  'custom/garages/*.lua',
  'custom/weather/*.lua',
  'custom/inventory/*.lua',
  'custom/clothes/*.lua',
  'custom/shells/*.lua',
  'custom/furniture/*.lua',
  'custom/dispatch/*.lua',
}

ox_libs {
  'locale',
  'table',
}

client_scripts {
  'client/property/*.lua',
  'client/building/*.lua',
  'client/doors/*.lua',
  'client/polyzone/client.lua',
  'client/polyzone/BoxZone.lua',
  'client/frameworks/*.lua',
  'client/creation/*.lua',
  'client/furniture/*.lua',
  'client/*.lua',
}

server_scripts {
  '@oxmysql/lib/MySQL.lua',
  'server/frameworks/*.lua',
  'custom/logs/*.lua',
  'custom/banking/*.lua',
  'server/*.lua',
}

-- ui_page 'http://localhost:5173'
ui_page 'web/build/index.html'
nui_callback_strict_mode 'true'

files {
  'web/build/index.html',
  'web/build/**/*',
  'custom/shells/*.json',
  'locales/*.json',
  'data/nolag_properties.dat54.rel',
	'audiodirectory/properties_sounds.awc',
  'stream/nolag_switches.ytyp'
}

data_file 'AUDIO_WAVEPACK' 'audiodirectory'
data_file 'AUDIO_SOUNDDATA' 'data/nolag_properties.dat'
data_file 'DLC_ITYP_REQUEST' 'stream/nolag_switches.ytyp'

escrow_ignore {
  'client/frameworks/*.lua',
  'client/Editable.lua',
  'server/frameworks/*.lua',
  'server/Functions.lua',
  'server/Hooks.lua',
  'server/Camera.lua',
  'custom/garages/*.lua',
  'custom/weather/*.lua',
  'custom/inventory/*.lua',
  'custom/clothes/*.lua',
  'custom/shells/*.lua',
  'custom/furniture/*.lua',
  'custom/logs/*.lua',
  'custom/banking/*.lua',
  'custom/dispatch/*.lua',
  'ipls.lua',
  'furniture.lua',
  'config.lua'
}

dependencies {
  '/server:9549',
  '/onesync',
  'oxmysql',
  'ox_lib',
  'bob74_ipl',
  'screencapture'
}

dependency '/assetpacks'