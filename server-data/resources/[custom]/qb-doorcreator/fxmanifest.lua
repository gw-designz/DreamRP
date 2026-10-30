fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'qb-doorcreator'
author 'qb-doorcreator'
description 'In-game lockable door creator/manager for Qbox (qbx_core) using ox_lib and oxmysql'
version '1.0.0'

-- ────────────────────────────────────────────────────────────────
-- Dependencies
-- These must all be started BEFORE this resource. Qbox's default
-- server.cfg ordering (ox_lib, oxmysql, qbx_core, then this resource)
-- satisfies this. We also hard-check qbx_core exists at runtime in
-- server/main.lua and client/main.lua and stop the resource with a
-- clear error if it doesn't. Player-facing interaction is a fully
-- custom NUI prompt (§8) - ox_target is NOT used anywhere.
-- ────────────────────────────────────────────────────────────────
dependencies {
    '/server:7290',
    '/onesync',
    'ox_lib',
    'oxmysql',
    'qbx_core',
}

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
    'locales/en.lua',
    'shared/doorgroups.lua',
}

client_scripts {
    'client/main.lua',
    'client/creator.lua',
    'client/nui.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/db.lua',
    'server/access.lua',
    'server/main.lua',
}

ui_page 'web/index.html'

files {
    'web/index.html',
    'web/style.css',
    'web/app.js',
}

-- Admin gating uses Qbox's own permission-group system throughout
-- (exports.qbx_core:HasPermission), NOT FiveM ace permissions.
-- Configurable via Config.CreatorPermission (default 'admin'). Grant
-- with qbx_core's own tooling, e.g. the /addpermission command or its
-- admin menu — see your qbx_core install's permissions setup.

provide 'qb-doorcreator'
