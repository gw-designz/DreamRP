Config = {}

-- ────────────────────────────────────────────────────────────────
-- GENERAL
-- ────────────────────────────────────────────────────────────────

-- Qbox permission GROUP required for /createdoor, /doormanager, and
-- every server-side create/edit/delete/toggle request. This is Qbox's
-- own permission system (exports.qbx_core:HasPermission), the same
-- one behind qbx_core's /addpermission — NOT a FiveM ace permission.
-- Checked server-side on EVERY request via isAdmin() — the client is
-- never trusted. Common Qbox groups: 'admin', 'god', 'mod'. Can also
-- be a table, e.g. { 'admin', 'god' }, if your qbx_core build's
-- HasPermission accepts a list — see server/main.lua's isAdmin().
Config.CreatorPermission = 'admin'

-- Player-facing lock/unlock interaction is entirely custom (no
-- ox_target): a lib.points proximity check shows a small custom-built
-- NUI prompt (web/app.js, see the #prompt element) with a keybind
-- badge + label, and Config.InteractKey opens/toggles the door. See
-- client/main.lua's CreateInteractionPoint().
Config.InteractKey = 38 -- INPUT_PICKUP (E)

-- Text shown inside the prompt's keybind badge for Config.InteractKey.
-- There is no reliable native to turn a control id back into display
-- text for an arbitrary remapped key, so this is just what gets shown
-- - update it if you change Config.InteractKey away from E.
Config.InteractKeyLabel = 'E'

-- Distance (units) at which a door's lib.points starts evaluating it
-- at all (registers proximity checking, nothing drawn yet). Keeps
-- idle resmon near 0.00ms by not running any logic for doors far from
-- every player. Config.PromptDistance (below) is the much tighter
-- radius at which the prompt itself actually appears.
Config.InteractDistance = 8.0

-- Distance (units) at which the interaction prompt actually becomes
-- visible once a player is within Config.InteractDistance of a door.
Config.PromptDistance = 1.5

-- Screen anchor for the custom interaction prompt. One of:
-- 'center', 'bottom-center', 'right-center'. Purely a CSS concern -
-- see the #prompt rules in web/style.css.
Config.PromptPosition = 'center'

-- Default seconds before a door auto re-locks after being unlocked via
-- player interaction. 0 or nil = never auto-locks. Per-door auto_close
-- in the DB overrides this; this is only the NUI form's default value.
Config.DefaultAutoClose = 0

-- Max number of doors that may share one group_id. Prevents an admin
-- from accidentally chaining half the map together.
Config.MaxDoorsPerGroup = 8

-- ────────────────────────────────────────────────────────────────
-- SOUND
-- ────────────────────────────────────────────────────────────────

Config.Sound = {
    enabled = true,
    lock = { name = 'Hack_Success', set = 'DLC_HEIST_HACKING_SNAKE_SOUNDS' },
    unlock = { name = 'Remote_Control_Failed_Penned_In', set = 'DLC_HEIST_HACKING_SNAKE_SOUNDS' },
    denied = { name = 'Place_Prop_Fail', set = 'DLC_Dmod_Prop_Editor_Sounds' },
}

-- ────────────────────────────────────────────────────────────────
-- PASSWORD HASHING
-- 'sha256' works with zero extra dependencies (native Lua/oxmysql).
-- 'bcrypt' requires a bcrypt-capable resource/native exposed as
-- exports['qb-doorcreator']:HashBcrypt / CompareBcrypt is NOT bundled
-- by default because bcrypt has no pure-Lua/FiveM-native implementation;
-- if you have a bcrypt binary module resource, wire it in
-- server/access.lua (HashPassword / VerifyPassword) and flip this.
-- ────────────────────────────────────────────────────────────────
Config.PasswordHashing = 'sha256' -- 'sha256' | 'bcrypt'

-- ────────────────────────────────────────────────────────────────
-- NATIVE DOOR SYSTEM
-- ────────────────────────────────────────────────────────────────

-- When true (default) doors are registered with the game's native
-- door system (AddDoorToSystem) so they stay in sync with any other
-- resource that also touches doors (MLO interiors, other scripts).
-- When a specific door's model isn't a real "door" entity known to
-- the door system (e.g. a custom prop being reused as a door), set
-- that door's `fallback` flag (per-door, stored in DB) to true and
-- client/main.lua will freeze/heading-toggle it instead. See
-- client/main.lua ApplyDoorState() for the branch.
Config.NativeDoorsDefault = true

-- Automatic open/close rate passed to DoorSystemSetAutomaticRate for
-- native doors flagged as automatic (currently unused by default
-- doors, exposed for future/manual use).
Config.DoorAutoRate = 1.0

-- ────────────────────────────────────────────────────────────────
-- KEYRING INTEGRATION
-- ────────────────────────────────────────────────────────────────

-- Generic item name used for the "keys" access category (§4). A key
-- item grants access to a door when its ox_inventory metadata table
-- contains `doorId` matching that door's id, e.g. metadata =
-- { doorId = 7, label = 'House Key' }. How keys get handed out
-- (crafting, /givekey admin command, a housing script, etc.) is
-- outside this resource's scope — it only ever *checks* for them.
Config.KeyItemName = 'door_key'

-- ────────────────────────────────────────────────────────────────
-- CREATOR / RAYCAST PLACEMENT MODE
-- ────────────────────────────────────────────────────────────────

Config.Creator = {
    maxDistance = 15.0,       -- max raycast distance while placing
    modifierKey = 21,         -- INPUT_SPRINT (LShift) held = multi-select
    confirmKey = 38,          -- INPUT_PICKUP (E) = confirm/select entity
    cancelKey = 194,          -- INPUT_FRONTEND_DELETE (Backspace) = cancel placement
    outlineColor = { r = 40, g = 200, b = 255, a = 180 },
    multiSelectColor = { r = 255, g = 180, b = 40, a = 200 },
}

-- ────────────────────────────────────────────────────────────────
-- ACCESS SUMMARY DISPLAY (used by NUI list view, purely cosmetic)
-- ────────────────────────────────────────────────────────────────
Config.AccessTypeLabels = {
    jobs = 'Job',
    gangs = 'Gang',
    identifiers = 'Owner',
    items = 'Item',
    password = 'Password',
    permission = 'Admin Perm',
    keys = 'Keyring',
}

-- If a player has literally zero matching access rules on a door,
-- should the interaction prompt be hidden entirely (true) or shown
-- and still clickable but always denied server-side (false)?
Config.HideInteractIfNoAccess = false

Config.Debug = false
