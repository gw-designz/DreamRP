fx_version "cerulean"
game "gta5"
lua54 "yes"

description "Scenes"
name "prp-scenes"
author "Prodigy Studios"
version "1.0.3"

files {
    "locales/*.json",
    "dui/dist/**/*",
    "ui/**/*.*",
}

ui_page "ui/index.html"

shared_scripts {
    "@ox_lib/init.lua",
    "@prp-bridge/import.lua",
    "locales/locales.lua",
    "editable/**/sh_*.lua",
}

client_scripts {
    "editable/**/cl_*.lua",
    "client/**/*.lua",
}

server_scripts {
    "@oxmysql/lib/MySQL.lua",
    "editable/**/sv_*.lua",
    "server/**/*.lua",
}

escrow_ignore {
    "editable/**/*.lua",
}
dependency '/assetpacks'