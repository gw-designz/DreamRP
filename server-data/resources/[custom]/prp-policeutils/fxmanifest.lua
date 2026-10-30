name "prp-policeutils"
lua54 "yes"
fx_version "cerulean"
game "gta5"

author "Prodigy Studios"
version "1.0.2"

files {
    "locales/*.json",
}

client_scripts {
	"client/**/*.lua",
}

shared_scripts {
    "@ox_lib/init.lua",
    "@prp-bridge/import.lua",
    "init.lua",
    "shared/**/*.lua",
}

server_scripts {
	"server/**/*.lua",
}

escrow_ignore {
    "server/**/*.lua",
    "config/**/*.lua",
    "shared/**/*.lua",
    "init.lua"
}
dependency '/assetpacks'