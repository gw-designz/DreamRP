-- Staff ranks, highest level first. A player's rank is the highest entry whose `group` they hold.
-- `group` is checked through qbx_core's permission system (ACE `group.<name>`), e.g. in server.cfg:
--   add_principal identifier.license:xxxx group.admin
-- `perms` is a list of permission keys, or '*' for everything.
--
-- Permission keys used by the resource:
--   players.view      see the player list and details
--   players.teleport  goto / bring
--   players.heal      heal / revive
--   players.moderate  warn / kick / freeze / notes / announce
--   players.ban       ban / unban
--   self              noclip, cloak, god mode, own model, coords
--   vehicles          spawn / repair / clean / delete vehicles
--   world             weather, time, clear area, delete objects
--   economy           give / remove money
--   items             give items, open/clear inventories and stashes
--   jobs              set jobs and gangs, toggle duty
--   resources         start / stop / restart resources (protected ones excluded)
--   dm                open the DM tool, build + test scenarios
--   dm.publish        switch scenarios live / global
--   dm.run            run DM actions on other players
Config.Ranks = {
    { name = 'owner',   label = 'Owner',          level = 100, group = 'god',       perms = '*' },
    { name = 'head',    label = 'Head Admin',     level = 90,  group = 'headadmin', perms = '*' },
    { name = 'admin',   label = 'Administrator',  level = 80,  group = 'admin',
      perms = { 'players.view', 'players.teleport', 'players.heal', 'players.moderate', 'players.ban', 'self', 'vehicles', 'world', 'economy', 'items', 'jobs', 'dm', 'dm.publish', 'dm.run' } },
    { name = 'dev',     label = 'Developer',      level = 70,  group = 'developer',
      perms = { 'players.view', 'players.teleport', 'players.heal', 'self', 'vehicles', 'world', 'items', 'dm', 'dm.publish', 'dm.run' } },
    { name = 'mod',     label = 'Moderator',      level = 50,  group = 'mod',
      perms = { 'players.view', 'players.teleport', 'players.heal', 'players.moderate', 'self', 'vehicles', 'items', 'jobs', 'dm', 'dm.run' } },
    { name = 'trial',   label = 'Trial Moderator', level = 30, group = 'trial',
      perms = { 'players.view', 'players.teleport', 'players.moderate', 'self' } },
}

-- Staff with a rank level at or above this value may act on other staff of equal rank.
-- Everyone else can only act on targets with a strictly lower level.
Config.PeerActionLevel = 90

-- Permission required to see raw identifiers (license, discord...) in player details.
Config.IdentifierPerm = 'players.ban'
