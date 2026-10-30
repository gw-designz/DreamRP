fx_version   "cerulean"
lua54        "yes"
games        { "gta5" }

ui_page "ui/dist/index.html"

author "Prodigy Studios"
version "1.0.0"

shared_scripts {
    "@ox_lib/init.lua",
    "@prp-bridge/import.lua"
}

files {
    "ui/dist/**/*"
}

client_scripts {
    "client/*.lua"
}

escrow_ignore {
    "client/editableClient.lua"
}
dependency '/assetpacks'