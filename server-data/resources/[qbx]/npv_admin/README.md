# npv_admin

NoPixel V-inspired admin menu and DM tool (scenario builder, dialogue editor, script blocks, DM actions) for **QBox**.

## Requirements

- FiveM server artifact with **OneSync** enabled (server-side entity creation is used for scenario props/NPCs)
- `qbx_core`, `ox_lib`, `oxmysql`
- Optional: `ox_inventory` (storage objects, give/take item blocks, "Give item" DM action)
- Node 18+ only if you want to rebuild the UI (a built copy is in `web/dist`)

## Install

1. Put the folder in `resources/` as `npv_admin`.
2. `ensure` it after `ox_lib`, `oxmysql`, `qbx_core`.
3. Tables are created automatically on start. `sql/install.sql` can also be imported by hand.
4. Give yourself a staff group in `server.cfg`, using the groups listed in `config/permissions.lua`:
   ```
   add_principal identifier.license:YOUR_LICENSE group.admin
   ```
5. In game: `/admin` (default key **F10**), DM tool key **L**.

Rebuild the UI after changing anything in `web/src`:

```
cd web && npm install && npm run build
```

## Configuration

| File | What it controls |
| --- | --- |
| `config/config.lua` | command/keys, limits, webhook, revive event, inventory, police alert hook, NPC/prop/animation catalogues, dialogue roles |
| `config/permissions.lua` | ranks, QBox groups, permission keys, peer-action rule |
| `config/commands.lua` | the command list shown in the menu (id, permission, arguments) |

Every command in `Config.Commands` must have a handler (`server/commands.lua` for `exec = 'server'`, `client/commands.lua` for `exec = 'client'`). The server prints a warning at start for any server command without one.

## How it is built

- **Server is authoritative.** The NUI only calls `rpc` (client → `lib.callback` → `server/main.lua`). Each RPC checks the caller's permission; commands re-validate every argument, apply rank hierarchy, are rate limited, and are written to `npv_admin_audit` (plus an optional Discord webhook that never leaves the server).
- **Scenarios** are stored as JSON in `npv_dm_scenarios` (history in `npv_dm_scenario_versions`). Every save passes `Scenarios.Sanitize`, which whitelists object kinds, models, coordinates, script blocks, dialogue and enforces limits. Going live creates server-side entities, which are deleted when the scenario is disabled, edited, or the resource stops. Live scenarios are restored on server start.
- **Scripts** are a closed set of block types (`server/scripts.lua`), never Lua code. Triggers/uses are reported by the client but re-checked on the server (object exists, player is within range, lock and cooldown state).
- **Dialogue** state lives on the server per player; reply visibility by job and reply triggers are evaluated server-side.

## DM tool quick start

1. `L` → type a name → `+`, or use **Ready-made** (builds a starter scenario where you stand).
2. **Catalog**: pick a model, aim, **Enter** to place (scroll rotates, Q/E height, Backspace cancels).
3. **Placed**: select an item to edit its position, NPC idle, conversation, scripts.
4. **Build** hides the menu so you can see the world and nudge the selected item.
5. **Save**, then **Spawn** (needs `dm.publish`) to make it live. Scripts run only while live.

## Not verified yet

This was developed without a running FiveM server. What has been verified:

- the React UI builds and renders (compared against the reference screenshots in a browser with mock data)
- all Lua files parse, and the script sanitiser, script interpreter, dialogue logic and scenario sanitiser pass unit tests in a Lua VM with stubs

What has **not** been exercised in game and needs a first-run check: placement ray-cast and ground snapping (object/ped z conventions), NPC animation via state bags, `qbx_medical` revive event name, spectate, noclip feel, stash opening, and weather/time (written through `Config.WeatherSync`, which defaults to the Renewed-Weathersync format; edit it if you use another sync resource).

## Known limitations

- No free-fly camera or mouse picking of world entities; select from the Placed list, use numeric fields, **Re-aim** or **Build** nudging.
- Catalogue cards show a letter/icon, not a 3D render of the model.
- Not implemented: shops, grabbables, vehicle slots, NPC patrol routes, hack mini-game blocks, NPC waves, sound actions.
- Ban checks match on license and the first non-IP identifier.
- Fonts are bundled (Barlow / Barlow Condensed) — a close match to the reference's condensed italic display face, not the identical font.
- The reference product's logo/branding is intentionally not reproduced.

## NPC appearance (MP freemode peds)

Place `mp_m_freemode_01` / `mp_f_freemode_01` (NPC tab, "Freemode" shelf) and press **Dress** in its properties. A camera frames the ped (drag to rotate, wheel to zoom) and every change shows live. Quick view: copy your look / the nearest MP ped, 16 presets per gender, randomise. **Design in editor** has Heritage, Face (20 sliders), Hair & eyes, Skin (12 overlays), Clothing (all components, with item names) and Props.

- Item counts come from the game, so addon clothing appears automatically. Names come from root-cause/v-clothingnames; slot ids follow the RAGE wiki Clothes page.
- "Auto-fit arms" asks the game which torso matches the top/undershirt (needs an in-game check).
- Not included: tattoos / hair fades and the Head component (0).
