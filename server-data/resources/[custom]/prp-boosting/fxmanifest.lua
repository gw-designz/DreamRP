fx_version "cerulean"
games { "gta5" }
lua54 "yes"

ui_page "ui/index.html"

author "Prodigy Studios"
version "1.1.3"

shared_scripts {
    "@ox_lib/init.lua",
    "@prp-bridge/import.lua",
    "sh_config.lua",
}

client_scripts {
    "client/**/*.lua",
}

server_scripts {
    "@oxmysql/lib/MySQL.lua",
    "sv_config.lua",
    "server/*.lua",
    "server/classes/*.lua",
    "server/missions/**/*",
}

escrow_ignore {
    "server/**/*.lua",
    "client/editable_client.lua",
    "sh_config.lua",
    "sv_config.lua",
}

files {
    "ui/index.html",
    "ui/**/*",
    "dui/**/*",
    "locales/*.json"
}
dependency '/assetpacks'