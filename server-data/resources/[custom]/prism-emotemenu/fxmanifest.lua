fx_version 'cerulean'
game 'gta5'

name 'prism-emotemenu'
description 'Prism Emote Menu'
author 'Prism'
version '1.0.1'

lua54 'yes'

ui_page 'web/dist/index.html'
-- ui_page 'http://localhost:5174/'

files {
    'web/dist/**/*.*',
    'animations/*'
}

shared_scripts {
    'shared/*.lua',
    'locales/*.lua',
    '@ox_lib/init.lua'
}

client_scripts {
    'client/*.lua'
}

server_scripts {
    'server/server.lua'
}

exports {
    'PlayEmote',
    'CancelEmote',
    'SetWalkStyle'
}


dependency '/assetpacks'

data_file 'DLC_ITYP_REQUEST' 'stream/rpemotesreborn_props.ytyp'
data_file 'DLC_ITYP_REQUEST' 'stream/brummie_props.ytyp'
data_file 'DLC_ITYP_REQUEST' 'stream/bzzz_props.ytyp'
data_file 'DLC_ITYP_REQUEST' 'stream/bzzz_camp_props.ytyp'
data_file 'DLC_ITYP_REQUEST' 'stream/apple_1.ytyp'
data_file 'DLC_ITYP_REQUEST' 'stream/kaykaymods_props.ytyp'
data_file 'DLC_ITYP_REQUEST' 'stream/knjgh_pizzas.ytyp'
data_file 'DLC_ITYP_REQUEST' 'stream/natty_props_lollipops.ytyp'
data_file 'DLC_ITYP_REQUEST' 'stream/ultra_ringcase.ytyp'
data_file 'DLC_ITYP_REQUEST' 'stream/pata_props.ytyp'
data_file 'DLC_ITYP_REQUEST' 'stream/vedere_props.ytyp'
data_file 'DLC_ITYP_REQUEST' 'stream/pnwsigns.ytyp'
data_file 'DLC_ITYP_REQUEST' 'stream/pprp_icefishing.ytyp'
data_file 'DLC_ITYP_REQUEST' 'stream/scully_props.ytyp'
data_file 'DLC_ITYP_REQUEST' 'stream/samnick_prop_lighter01.ytyp'
data_file 'DLC_ITYP_REQUEST' 'stream/bzzz_murderpack.ytyp'
data_file 'DLC_ITYP_REQUEST' 'stream/prop_protestsign_fh.ytyp'