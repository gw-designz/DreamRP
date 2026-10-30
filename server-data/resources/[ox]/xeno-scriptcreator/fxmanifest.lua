fx_version "cerulean"
game "gta5"
lua54 "yes"

name "decision-tree-creator"
author "XenoShop"
description "Visual no-code decision tree engine for FiveM"
version "5.0.0"

ui_page "web/dist/index.html"

files{ "web/dist/index.html", "web/dist/assets/*", "web/dist/assets/uploads/*", "examples/*.json" }

shared_scripts{ "@ox_lib/init.lua", "config/config.lua" }

escrow_ignore {
    "config/config.lua",
    "editable/**/*"
}

client_scripts{
	"@PolyZone/client.lua",
	"@PolyZone/CircleZone.lua",
	"@PolyZone/BoxZone.lua",
	"@PolyZone/EntityZone.lua",
	"client/lib/*.lua",
	"client/core/*.lua",
	"client/actions/*.lua",
	"client/npc_manager.lua",
	"client/ui/*.lua",
	"client/zones.lua",
	"client/editor/*.lua",
	"client/triggers.lua",
}

server_scripts{
	"@oxmysql/lib/MySQL.lua",
	"server/lib/*.lua",
	"editable/bridge/server/*.lua",
	"server/core/*.lua",
	"server/actions/*.lua",
	"server/npc_manager.lua",
	"server/ui/*.lua",
	"server/net/*.lua",
	"server/bootstrap.lua",
}

dependency"PolyZone"

dependency '/assetpacks'