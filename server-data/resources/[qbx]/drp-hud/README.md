# my-hud

A flat, minimal GTA V RP HUD for FiveM. Works with QBCore, Qbox and ESX, or standalone. Voice comes from pma-voice.

| Widget | Where | What it shows |
| --- | --- | --- |
| Health, armor & needs | bottom left, under the minimap | One white icon per stat with a short colored bar underneath: health (teal), armor (cyan, in three pieces), hunger (orange) and thirst (blue). Low values turn the icon and bar orange / red. While active, extra icons join the row: voice (mic, bar = range), radio channel (purple), stress (red), oxygen underwater (cyan) and dev mode (green). |
| Minimap & location | bottom left / top center | Rectangular radar with rounded corners inside a thin dark frame. The top-center bar shows the direction you face (N, NE, E ...), the street and the zone with blue icons, plus the waypoint distance with an arrow pointing at it (ft/m when close). |
| Speedometer | bottom right | Glowing blue RPM arc numbered 0-9 (numbers light up as it passes them, red at the redline), digital 3-digit speed with a dimmed leading zero and MP/H or KM/H underneath, a white fuel arc on the left with the fuel icon, a red seatbelt icon while unbuckled, a lock icon while locked and two headlight dashes. Electric vehicles get a plug icon; helicopters and planes show altitude and knots. |
| Classic style | everywhere | Second look, picked per player in **/hud > General > HUD style**: ring gauges (gap at the bottom) around the status icons, armor hidden at zero, location items on soft dark pills with the cross street after a blue x, and a needle speedometer: a blue wedge sweeps up to a white needle over a tick ring, with big white digits, MPH and the gear underneath. The map moves slightly (`Config.Minimap.styles.classic`). |
| Weapon | top right | A chip with the gun icon and the rounds in the clip. |
| Stamina & oxygen | bottom center | A framed runner bar: white for stamina, amber for oxygen. |
| Key hints | bottom right (moves left of the speedometer while driving) | One key bar for every script. It shows prompts pushed with `ShowPrompts` (e.g. fishing), and the vehicle key hints when you get in as the driver. Keys follow each player's own bindings. Prompts a script already draws itself (ox_lib / qb / ESX text UI, interact) are not repeated unless turned on in `Config.Controls.capture`. Script prompts take over while they are up; hiding them brings the vehicle hints back if those are still showing. |
| Player info | top left / top right | Voice box (mic level, voice range and a headshot of your character), job with grade and the game clock on the left; bank, cash, your server ID and the radio channel on the right. |
| Speed limit | right | The road's speed limit as a US sign or a minimal chip, flashing while you speed. |
| Boat / flight info | above the minimap | Boats: compass heading and bow trim. Aircraft: attitude indicator, altitude with climb rate, and heading. |
| Vehicle controls | bottom center | Button panel for engine, lock, indicators, doors, windows, seats, lights, cruise and neon (`/vehcontrols`, F6). |
| Item toasts | top right | Cards for "Pistol — Equipped / Holstered" (automatic) and any item an inventory pushes. |

Players can move and resize every widget in the `/hud` layout editor.

## File tree

```
my-hud/
├── fxmanifest.lua
├── config.lua
├── bridge/
│   ├── shared.lua      framework auto-detection
│   ├── client.lua      hunger / thirst / job / load events per framework
│   └── server.lua      stress persistence + job lookup per framework
├── client/
│   ├── utils.lua       Hud table, change-only NUI pushes, screen metrics
│   ├── settings.lua    /hud menu, layout + KVP persistence
│   ├── minimap.lua     runtime rounded mask, radar placement, frame sync, zoom
│   ├── voice.lua       pma-voice range / talking / radio
│   ├── vehicle.lua     speed, rpm, gear, fuel, lights, lock, seatbelt, crash ejection
│   ├── stress.lua      shooting / speeding gain, screen shake
│   ├── controls.lua    key hints bar: ShowPrompts / HidePrompts, text UI capture, key binding lookup
│   └── main.lua        visibility, status, oxygen, compass, location, waypoint, ammo, per-frame hides
├── server/
│   └── main.lua        authoritative stress (player state bag) + exports
└── html/
    ├── index.html
    ├── style.css       every color and size is a CSS variable in :root
    ├── script.js
    ├── fonts/          Barlow Condensed SemiBold/Bold/ExtraBold Italic (SIL OFL, see OFL.txt)
    └── icons/          heart, shield, utensils, burger, burger-fries, cup, mic, brain, bolt, fuel, seatbelt, gun,
                        runner, swimmer, lights, lock, unlock, code, radio, lungs, wallet, bank,
                        plug (SVG, drawn for this resource)
```

## Settings menu, edit mode and calibration

`/hud` opens the **HUD Settings** window: an icon sidebar on the left, the page on the right, and **Edit Sizes, Positions & Visibility**, **Reset All** and **Save Changes** along the bottom. Changes show on the HUD straight away; **Save Changes** keeps them, and closing the window without saving puts the last saved settings back. Colour fields open a picker (saturation square, hue bar, hex input).

| Page | What it sets |
| --- | --- |
| Home | Search across every setting, performance mode (how often the HUD updates), speed unit, distance unit (feet / meters), full width on ultrawide screens, HUD scale, HUD style (Circuit / Classic), item toasts, stress screen shake |
| Minimap & Compass | Minimap style, location style, minimap on foot, 3D minimap, compass / heading / street / waypoint, zoom, calibrate |
| Player Stats | Stats style (bars, hexagons, squares, circles), which stats show, low warnings, and progress / icon / background colours for health, armour, hunger, thirst, stamina, oxygen and stress |
| Cars & Bikes | Speedometer style, speed limit sign (US sign / minimal), flash the sign while speeding, indicator sounds, seatbelt chime, seatbelt click, RPM arc / text / engine bar / fuel bar colours |
| Bicycles | Speedometer style, speed unit, speed display, bell sounds, cadence, heart rate, text and heart colours |
| Boats | Speedometer style, speed unit (knots / mph / km/h), compass heading panel, trim panel, needle / center / fuel needle colours |
| Air | Speedometer style, speed unit, attitude, altitude & climb rate and heading panels, accent colour |
| Trains | Speedometer style, speed unit, speed display, door status, brake indicator, RPM bar / red zone / gear box and indicator / cruise / headlight / seatbelt colours |
| Player Info | Avatar and radio channel on/off, voice box alignment, border radius, voice active / idle colours, card background and icon colours |
| Weapons | Weapon chip border radius and background / icon / text colours |
| Vehicle Controls | Panel border radius and its eight colours |
| Import & Export | Your settings as a JSON code to copy and share, or paste someone else's and **Import Code** (then Save Changes) |

The speedometer styles are Modern Pro, Classic Analog, Digital Linear, Tesla Style, Classic Dual and Fitness Watch, picked separately for cars & bikes, bicycles, boats, aircraft and trains.

**Controls**: arrow up / down (d-pad) walk the fields, left / right change them, Q / E (LB / RB) switch pages, Space / Enter (A) toggles, Esc (B) closes. The mouse works everywhere.

**Edit mode** (Edit Sizes, Positions & Visibility) dims the game behind a grid and outlines every element. Drag an element to move it, drag a corner dot to resize it, and click its eye to hide or show it. **Snap to grid** snaps to a 16 px grid; **Show hidden components** keeps hidden elements visible (faded) while editing. **Undo**, **Redo** and **Reset** work on the layout; **Discard** drops this session's changes and **Save** keeps them. Offsets are stored in 1080p pixels, so a layout keeps its proportions at any resolution.

**Calibration** (Minimap & Compass) moves the game radar inside the frame with the arrow keys, in case it renders off-centre on your game build.

Settings are stored per player with KVP. `Config.MenuBlur = false` turns off the background blur.

### Vehicle control panel

`/vehcontrols` (F6 by default, `Config.VehicleControls`) opens a panel at the bottom while in a vehicle: engine, lock, left / hazard / right indicators, hood, trunk, lights, cruise control, neon, the four doors, the four windows and the seats. A dot on each button shows its state. You can keep driving while it is open; Esc closes it. The lock button runs `Config.VehicleControls.lockCommand` (e.g. your vehicle keys script) when it exists.

### Speed limit sign

Shown while driving cars and motorbikes. Limits come from `Config.SpeedLimits` (mph per street name, with a default), and are rounded to the nearest 10 for km/h players.

### Dev tab

Players allowed by `Config.Dev` get a **Dev** page in `/hud` (`/huddev` opens it directly). Access is an ACE check (`my-hud.dev` or `admin` by default, e.g. `add_ace group.admin my-hud.dev allow`) or, on ESX, the `admin` / `superadmin` group. The server checks again on every change.

- **Override status values** draws your own health, armor, hunger, thirst, stress and oxygen sliders instead of the real values. This only changes your HUD.
- **Apply to character** sets your real health and armor, and your hunger, thirst and stress through the framework (Qbox / QBCore metadata, esx_status, or the HUD itself on standalone).
- **Show speedometer / weapon & ammo / key hints / radio / dev mode icon** force those widgets on with sample values. **Test item toast** shows a sample card.
- **Open dev panel** swaps the big menu for a small panel docked on the left with the same controls, so the whole HUD stays visible while you tweak. **Back to menu** returns; Esc or the close button exits. In the browser preview a **DEV** button on the right opens it (or add `&devpanel`).
- Nothing on this tab is saved. **Reset dev tools** turns it all off and goes back to the live values.

## Install

1. Copy the `my-hud` folder into your `resources` directory. Keep the folder name `my-hud`, because other scripts call `exports['my-hud']`.
2. Stop any other HUD that draws health, armor, minimap or seatbelt (for example `qb-hud`, `ps-hud` or `esx_hud`). Remove any seatbelt script too, since this resource provides one.
3. In `server.cfg`, ensure it **after** your framework and pma-voice:
   ```
   ensure qb-core        # or qbx_core / es_extended
   ensure pma-voice
   ensure my-hud
   ```
4. Restart the server and join. Type `/hud` to open the settings panel.
5. Optional: change `Config.Framework` if auto-detection picks the wrong one, and `Config.Vehicle.fuel` to force a fuel resource.

ESX: hunger and thirst come from `esx_status`. Stress persists through `xPlayer.setMeta`, which needs ESX Legacy 1.9 or newer.

Standalone: stress persists per license in resource KVP. Hunger and thirst stay full unless another resource calls `exports['my-hud']:SetNeeds(hunger, thirst)`. The money panel stays hidden until something calls `SetMoney(cash, bank)`.

Money comes from `PlayerData.money` on QBCore/Qbox and from the `money` and `bank` accounts on ESX. Weapon names for toasts come from the QBCore/Qbox shared weapon list; on ESX or standalone they come from `Config.Toasts.weaponLabels`. Add your addon electric vehicles to `Config.Vehicle.electric`, and adjust `Config.Vehicle.hints` to your server's keys script: items with `command` show whatever key the player bound to that script's key mapping, and `key` is only the fallback.

## Exports

Client:

| Export | Description |
| --- | --- |
| `ShowPrompts(list)` | Shows the prompts in the key hints bar (bottom right), replacing captured text UI and the vehicle hints while they are up. Each item is `{ label = 'Aim', key = 'LT', control = 25 }`. The keyboard key comes from `command` (another script's key mapping name, so rebinds show) or `control` (a GTA control); `key` is the controller glyph and the fallback, `pad` / `kbd` override the controller / keyboard label, and `resource` hides the item unless that resource is started. `WHEELUP` / `WHEELDOWN` draw the mouse wheel. |
| `HidePrompts()` | Removes the prompts (the vehicle hints come back if they are still active). Prompts also clear automatically when the resource that showed them stops. |
| `ToggleHud(bool)` | `false` hides the whole HUD and radar, `true` shows it, and `nil` toggles it. |
| `IsHudVisible()` | Returns whether the HUD is currently shown. |
| `IsSeatbeltOn()` / `SetSeatbelt(bool)` | Reads or sets the seatbelt state. |
| `SetNeeds(hunger, thirst)` | Feeds hunger and thirst values in standalone mode. |
| `SetMoney(cash, bank)` | Feeds the money panel (standalone or custom economies). |
| `ShowItemToast(label, status, image, icon)` | Shows a card under the minimap, e.g. `('Water', 'Used x1', 'nui://ox_inventory/web/images/water.png')`. `image` must be a `nui://` or `https://` URL. Without one, `icon` picks a bundled icon (`gun`, `cup`, `utensils`, `burger`, ...). The server can trigger the same thing with the `my-hud:client:itemToast` event. |
| `SetDevMode(bool)` | Shows or hides the green dev-mode icon (`nil` toggles). qb-adminmenu's dev-mode toggle is picked up automatically. |
| `AddStress(amount)` / `RelieveStress(amount)` | Changes stress from the client (it is batched and sent to the server). |

Server: `AddStress(src, amount)`, `RemoveStress(src, amount)`, `SetStress(src, value)`, `GetStress(src)`.

Events kept for compatibility with qb-hud: `hud:server:GainStress`, `hud:server:RelieveStress` and `hud:client:UpdateNeeds`. The client also fires `my-hud:client:seatbelt` (state), and `LocalPlayer.state.seatbelt` mirrors it.

## interact prompts (Renewed-Banking and others)

The `interact` resource draws its floating "E" prompts itself and has no way to ask which one is up, so it needs a small hook to show them in the key hints bar. In `interact/client/interacts.lua`, add this above `local function CreateInteractions()`:

```lua
local announced
local function announcePrompt(label, amount)
    local key = label and (label .. '|' .. amount) or nil
    if key == announced then return end
    announced = key
    TriggerEvent('interact:promptChanged', label and { label = label, amount = amount } or nil)
end
```

Then call `announcePrompt(nil)` in both early returns of `CreateInteractions` (`screenCount == 0` and `not active`) and in the fast thread when it skips (`else announcePrompt(nil)`), and right after `utils.drawPrompt(...)`:

```lua
local selected = visibleOptions[CURRENT_SELECTION]
announcePrompt(selected and selected.label or 'Interact', activeAmount)
```

The event is local and fires only when the prompt changes. Re-apply it if you update `interact`.

## Example: fishing prompts

```lua
-- fishing/client.lua
local fishing = false

local function startFishing()
    fishing = true
    exports['my-hud']:ShowPrompts({
        { key = 'LT', control = 25,  label = 'Aim' },      -- INPUT_AIM
        { key = 'RT', control = 24,  label = 'Cast' },     -- INPUT_ATTACK
        { key = 'B',  control = 45,  label = 'Bait' },     -- INPUT_RELOAD (R on keyboard)
        { key = 'Y',  control = 23,  label = 'Put away' }, -- INPUT_ENTER (F on keyboard)
    })

    CreateThread(function()
        while fishing do
            if IsControlJustPressed(0, 24) then
                -- cast the line, then switch to the reel-in prompts
                exports['my-hud']:ShowPrompts({
                    { key = 'RT', control = 24, label = 'Reel in' },
                    { key = 'Y',  control = 23, label = 'Cancel' },
                })
            elseif IsControlJustPressed(0, 23) then
                fishing = false
            end
            Wait(0)
        end
        exports['my-hud']:HidePrompts()
    end)
end

RegisterCommand('fish', startFishing, false)
```

They appear in the key hints bar at the bottom right, in the same style as the vehicle key hints. On a controller the bar shows `[LT] AIM  [RT] CAST  (B) BAIT  (Y) PUT AWAY`, with the face buttons drawn as circles. On keyboard and mouse it switches automatically to `[RMB] AIM  [LMB] CAST  [R] BAIT  [F] PUT AWAY`. The key names come from `GetControlInstructionalButton`, so they follow each player's own key bindings.

## Minimap notes

**Shape.** At startup a 256px anti-aliased white disc is drawn into a runtime texture, which replaces `radarmasksm` and `radarmask1g`. No binary `.ytd` file is shipped.

**Placement.** The resource computes the map rectangle from the resolution, safezone, HUD scale, `Config.Minimap` (`width`, `height`, `marginLeft`, `marginBottom`) and the player's layout-editor offset and size. It places the radar components with `'L','T'` alignment, and the NUI frame applies the same formula. It is re-run whenever the resolution, safezone or layout changes.

**Calibration.** The radar's internal padding can differ between game builds, so the frame and the map can end up a few pixels apart. If that happens, use **Map & Compass > Start calibration** in `/hud` (saved per player). To change the default for everyone, edit `Config.Minimap.components`, where each radar layer has its own `scale`, `x` and `y`.

**Colors.** No native recolors the radar's land or water. `SetMinimapComponent` only toggles overlay components, and the HUD-colour natives don't affect radar tiles. To get the flat light-blue water and mint land look:

1. Extract `minimap_sea_0_0` … and `minimap_0_0` … from `x64b.rpf/levels/gta5/…/minimap*.ytd` with CodeWalker or OpenIV.
2. Recolor them in an image editor. A posterize filter plus hue mapping works well, for example water `#7cc3f0` and land `#a8e6c4`.
3. Rebuild them into a `.ytd` with the same names and put it in a `stream/` folder inside this resource. FiveM streams every file in `stream/` automatically, so no manifest change is needed.

Only use textures you have extracted and edited yourself.

## Performance

- Every loop sleeps 500–1000 ms while its element is hidden.
- Values are rounded and diffed in Lua, so the NUI only receives fields that actually changed.
- The only per-frame thread hides the default HUD components (GTA resets these every frame), strips the radar health/armor bars while the map is visible, and blocks vehicle exit while belted.
- Stress gains are batched and sent to the server every 5 s.

## Browser preview

Serve `html/` with any static server and open `index.html?demo` to see the HUD with sample values. Extra flags: `&vehicle` / `&vehicle=electric` / `&vehicle=air` (with `&speed=`, `&rpm=`, `&gear=`, `&fuel=`, `&belt`), `&ammo`, `&money`, `&toasts`, `&prompts`, `&engine` (mouse wheel hints), `&waypoint=2400` (meters, with `&wpbearing=`), `&dev`, `&channel=1`, `&underwater&oxygen=20`, `&stamina=60`, `&settings&tab=car` (home, map, stats, car, bike, boat, air, train, info, weapons, vcontrols, transfer, dev), `&editor`, `&vcontrols`, `&limit=50`, `&pitch=` / `&roll=` / `&alt=` / `&climb=` / `&heading=` (boat and flight panels), `&calibrate`, `&devpanel`, `&talking`, `&radio`, `&spin`, `&nomap`, `&scale=1.25`, `&style=classic`, `&speedo=modern` (modern, analog, linear, ev, dual, watch), `&vehicle=bicycle` / `&vehicle=boat` / `&vehicle=train`, `&enginehp=40`, `&ind=left` (right, both), `&status=hex` (bars, hex, square, circle), `&map=circle` (brackets, clean, minimal, circle), `&loc=compass` (bar, pills, compass, minimal), `&health=20&armor=70&hunger=24&thirst=12&stress=80`. The preview code only runs outside FiveM.
