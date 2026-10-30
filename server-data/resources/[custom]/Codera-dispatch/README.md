# Codera-Dispatch

A dispatch script for the **QBCore** framework, built for emergency jobs such as police (LSPD) and ambulance (LSMD).

---

## Requirements

- **QBCore Framework**
- This resource must start **after** `qb-core` in your `server.cfg`.

---

## Installation

1. Place the `Codera-dispatch` folder inside your server's `resources` directory.
2. Add this line to your `server.cfg`:
   ```
   ensure Codera-dispatch
   ```
3. Configure which jobs should receive dispatches in `config.lua` (explained below).

---

## Main Files

| File | Purpose |
|---|---|
| `config.lua` | Job list, menu key/command, blip display duration |
| `editable_client.lua` | How the blip is created on the map (customizable) |
| `client.lua` | Client-side logic + example test dispatch commands (`cd1`) |
| `server.lua` | Stores and broadcasts dispatches, manages units |
| `html/` | Dispatch menu UI (NUI) |

---

## How to Add a New Dispatch

Dispatches are sent using the exported function `sendDispatch(data)` defined in `client.lua`. There are two main ways to call it:

### Method 1: Via export (recommended for other scripts)

From any other client-side script (e.g. when a player presses a 911 button), you can send a dispatch like this:

```lua
exports['Codera-dispatch']:sendDispatch({
    title = "Armed Robbery",
    code = "10-90",
    values = {
        { text = "Downtown Street", icon = "fa-solid fa-location-dot" },
        { text = "Priority 1",       icon = "fa-solid fa-hashtag" },
    },
    valuestwo = {},        -- DON'T TOUCH (filled by the server)
    active = false,         -- DON'T TOUCH
    dispatchnumber = nil,   -- DON'T TOUCH (filled by the server)
    jobs = {"police"},      -- which jobs should see this dispatch
    coords = vector3(215.6, -810.2, 30.7), -- map coordinates
    blip = {
        blipid = 161,       -- GTA blip sprite ID
        blipcolor = 1,      -- GTA blip color ID
    },
})
``````lua

local function SendCoderaDispatch(data)
    exports['Codera-dispatch']:sendDispatch({
        title = data.title or 'Unknown Alert',
        code = data.code or '10-80',
        values = data.values or {},
        valuestwo = {},         -- DON'T TOUCH
        active = false,          -- DON'T TOUCH
        dispatchnumber = nil,    -- DON'T TOUCH
        jobs = data.jobs or { 'police' },
        coords = data.coords or vector3(0.0, 0.0, 0.0),
        blip = {
            blipid = data.sprite or 1,
            blipcolor = data.color or 1,
        }
    })
end

--------------------------------------------------
-- Store Robbery
--------------------------------------------------
```lua
local function StoreRobbery()
    local coords = GetEntityCoords(PlayerPedId())
    SendCoderaDispatch({
        title = 'Store Robbery',
        code = '10-31',
        values = {
            { text = 'Someone is trying to rob a store', icon = 'fa-solid fa-store' },
            { text = GetStreetAndZone and GetStreetAndZone(coords) or '', icon = 'fa-solid fa-location-dot' },
        },
        jobs = { 'police' },
        coords = coords,
        sprite = 628,
        color = 3,
    })
end
exports('StoreRobbery', StoreRobbery)

--------------------------------------------------
-- Car Jacking
--------------------------------------------------
```lua
local function CarJacking()
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)

    local vehicle = QBCore.Functions.GetClosestVehicle(coords)
    if not vehicle or vehicle == 0 then
        QBCore.Functions.Notify('No vehicle nearby', 'error')
        return
    end

    local plate = QBCore.Functions.GetPlate(vehicle) or 'UNKNOWN'
    local vehName = GetDisplayNameFromVehicleModel(GetEntityModel(vehicle))

    SendCoderaDispatch({
        title = 'Car Jacking',
        code = '10-34',
        values = {
            { text = 'Vehicle carjacking in progress', icon = 'fa-solid fa-car' },
            { text = vehName,                            icon = 'fa-solid fa-car-side' },
            { text = plate,                               icon = 'fa-solid fa-hashtag' },
            { text = GetStreetAndZone and GetStreetAndZone(coords) or '', icon = 'fa-solid fa-location-dot' },
        },
        jobs = { 'police' },
        coords = coords,
        sprite = 225,
        color = 3,
    })

    QBCore.Functions.Notify('Car Jacking alert sent!', 'success')
end
exports('carjacking', CarJacking)

RegisterCommand('carjack', function()
    CarJacking()
end, false)

```lua
--------------------------------------------------
-- Explosion
--------------------------------------------------
local function Explosion()
    local coords = GetEntityCoords(PlayerPedId())
    SendCoderaDispatch({
        title = 'Explosion',
        code = '10-70',
        values = {
            { text = 'An explosion has occurred', icon = 'fa-solid fa-fire' },
            { text = GetStreetAndZone and GetStreetAndZone(coords) or '', icon = 'fa-solid fa-location-dot' },
        },
        jobs = { 'police', 'ambulance' },
        coords = coords,
        sprite = 436,
        color = 3,
    })
end
exports('Explosion', Explosion)

### Method 2: Via command (for quick testing)

`client.lua` already has a sample command (`cd1`). You can add a new command using the same pattern:

```lua
RegisterCommand('mydispatch', function()
    sendDispatch({
        title = "Traffic Accident",
        code = "10-50",
        values = {
            { text = "North Highway", icon = "fa-solid fa-car-burst" },
            { text = "Priority 2",     icon = "fa-solid fa-hashtag" },
        },
        valuestwo = {},
        active = false,
        dispatchnumber = nil,
        jobs = {"police", "ambulance"},
        coords = vector3(-500.0, -200.0, 38.0),
        blip = {
            blipid = 380,
            blipcolor = 3,
        },
    })
end)
```

### `data` Field Reference

| Field | Description |
|---|---|
| `title` | Dispatch title (shown in the menu and on the map blip) |
| `code` | Display code, e.g. police/EMS radio code (`10-90`) |
| `values` | Array of `{text, icon}` — extra dispatch details (icons use Font Awesome classes) |
| `jobs` | Array of job names that should receive this dispatch; must match a `name` defined in `Config.EmergencyJobs` |
| `coords` | `vector3` coordinates of the incident on the map |
| `blip.blipid` | GTA V blip sprite ID |
| `blip.blipcolor` | GTA V blip color ID |
| `valuestwo` | **DON'T TOUCH** — filled by the server when a unit sets the dispatch active |
| `active` | **DON'T TOUCH** — always send `false` |
| `dispatchnumber` | **DON'T TOUCH** — auto-assigned by the server |

> Note: Keep the fields marked "DON'T TOUCH" exactly as shown in the examples. The server (in `server.lua`, event `Codera-dispatch:addDispatch`) automatically fills in `dispatchnumber` and `date`.

---

## Adding a New Job to Dispatches

If you want another emergency job (e.g. fire department or mechanic) to be able to receive dispatches, add it in `config.lua`:

```lua
Config.EmergencyJobs = {
    { name = "police",    displayname = "LSPD" },
    { name = "ambulance", displayname = "LSMD" },
    { name = "fire",      displayname = "LSFD" }, -- new job
}
```

Then, for any dispatch you want this job to see, add its `name` to the `jobs = {...}` array, e.g. `jobs = {"police", "fire"}`.

---

## Other Settings in `config.lua`

```lua
Config.MenuCommand = "openDispatchMenu" -- command to open the dispatch menu
Config.MenuKey = "j"                    -- default keybind to open the menu
Config.RemoveBlipAfter = 60000          -- how long (ms) before the blip is removed from the map
Config.BlipScale = 1.0                  -- size of the map blip
```

---

## Quick Summary

1. Set up `Config.EmergencyJobs`.
2. Wherever you want to send a dispatch, call `exports['Codera-dispatch']:sendDispatch({...})` with the fields listed above.
3. Only fill in `title`, `code`, `values`, `jobs`, `coords`, and `blip` yourself; copy the rest of the fields as-is and don't modify them.
