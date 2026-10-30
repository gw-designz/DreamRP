

games {
    "gta5"
}

version "1.1.0"

fx_version "cerulean"

nui_callback_strict_mode "true"

use_experimental_fxv2_oal "yes"

lua54 "yes"

ui_page "src/web/dist/index.html"

files {
    "src/web/dist/index.html",
    "src/web/dist/**/*",
    "dui.html",
    "logo.html",
    "studio.html",
    "silhouette.html",
    "fonts/**/*.woff2",
    "*.png"
}

shared_scripts {
    "@ox_lib/init.lua",
    "config.lua",
    "src/resource/shared/**/*.lua",
    "src/resource/utils/*.lua",
    "locales/*.lua",
    "src/appearance/*.lua",
    "src/housing/*.lua"
}

client_scripts {
    "src/resource/client/**/*.lua",
    "frameworks/qbcore/client.lua",
    "frameworks/qbox/client.lua",
    "frameworks/esx/client.lua"
}

server_scripts {
    "@mysql-async/lib/MySQL.lua",
    "src/resource/server/**/*.lua",
    "frameworks/qbcore/server.lua",
    "frameworks/qbcore/db.lua",
    "frameworks/qbox/server.lua",
    "frameworks/qbox/db.lua",
    "frameworks/esx/server.lua",
    "frameworks/esx/db.lua"
}

dependencies {
    "ox_lib"
}

escrow_ignore {
    "config.lua",
    "src/resource/utils/*.lua",
    "locales/*.lua",
    "logo_example.png",
    "src/appearance/*.lua",
    "src/housing/*.lua",
    "src/resource/client/spawn.lua"
}

dependency '/assetpacks'

