fx_version 'cerulean'

description 'YSeries Bundle'
author 'TeamsGG Development'
version '2.1.1'

lua54 'yes'

games {
  'gta5',
}


ui_page 'ui/build/index.html'
nui_callback_strict_mode 'true'

shared_scripts {
  '@ox_lib/init.lua',
  'config/*.lua',
  'shared/dlcs.lua',
  'shared/functions.lua',
  'shared/resourceDetection.lua',
  'shared/spotfinder_math.lua',
}

client_script 'client/**/*.lua'

server_scripts {
  '@oxmysql/lib/MySQL.lua',
  'server/**/*.lua',
}

files {
  'sql/migrations/*.sql',
  'ui/build/**/*',
  'config/*.json',
  'sql/*.sql',
}

escrow_ignore {
  'config/**/*',

  'client/apps/framework/**/*.lua',
  'client/apps/framework/**/*.lua',
  'server/apps/framework/**/*.lua',

  'shared/functions.lua',
  'shared/resourceDetection.lua',

  'client/custom/**/*.lua',
  'server/custom/**/*.lua',
  'server/apiKeys.lua'
}

dependencies {
  '/server:9549',
  '/onesync',
  'oxmysql',
  'ox_lib',
}

dependency '/assetpacks'