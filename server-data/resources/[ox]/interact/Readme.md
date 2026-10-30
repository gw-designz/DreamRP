<div align="center">

# interact

**A NoPixel V inspired interaction system for FiveM**

Walk up to something, look at it, press **E**.<br>
No third-eye menus, no clutter, just minimal in-world prompts.

[![Discord](https://img.shields.io/badge/Discord-Join-5865F2?style=for-the-badge&logo=discord&logoColor=white)](https://discord.gg/karmadevelopments)
[![Store](https://img.shields.io/badge/Store-karmadevelopments.shop-F97316?style=for-the-badge&logo=shopify&logoColor=white)](https://karmadevelopments.shop)
[![Preview](https://img.shields.io/badge/Preview-Streamable-0F90FA?style=for-the-badge&logo=youtube&logoColor=white)](https://streamable.com/p2criy)

</div>

---

## About

This is the default **[interact](https://github.com/darktrovx/interact)** resource by **[darktrovx](https://github.com/darktrovx)**, restyled by **Karma Developments** to take its look from **NoPixel V**.

It will be a dependency of several upcoming systems from **Karma Developments**, so install it now to be ready for them.

🛒 **Store:** [karmadevelopments.shop](https://karmadevelopments.shop)<br>
💬 **Discord:** [discord.gg/karmadevelopments](https://discord.gg/karmadevelopments)

---

## 📑 Table of Contents

- [Features](#-features)
- [Installation](#-installation)
- [Controls](#-controls)
- [How Distances Work](#-how-distances-work)
- [Options](#-options)
- [Exports](#-exports)
- [Configuration](#%EF%B8%8F-configuration)
- [Credits & License](#-credits--license)

---

## ✨ Features

| | |
| --- | --- |
| 🔵 **Ring dots** | Every nearby interaction point is marked, so players can see everything they can interact with |
| 🎯 **Crosshair hover** | A small dot in the centre of the screen selects the in-range point closest to it. Move the camera to switch points |
| ⌨️ **`[E] LABEL` prompt** | Condensed italic HUD font drawn in-game (no NUI), so it stays attached to the world without lag |
| 📜 **Multiple options** | Scroll with the arrow keys or mouse wheel. The selected option gets the key badge |
| 🔒 **`canInteract` filtering** | Options that fail their check are hidden, and points with no options left disappear |
| 🧩 **Flexible targets** | Coords, local entities, networked entities, entity bones and model-wide interactions |
| 🚫 **Auto-disable** | Turns off on death, NUI focus, in vehicles and while cuffed (configurable) |
| ⚡ **Lightweight** | ~44 KB of assets downloaded once, no server-side work, a few sprite draws per frame |

---

## 📦 Installation

1. Place the folder in your resources directory and **name it `interact`**. Exports use the folder name as the resource name.
2. Make sure [ox_lib](https://github.com/overextended/ox_lib) starts first.
3. Add to your `server.cfg`:

```cfg
ensure ox_lib
ensure interact
```

---

## 🎮 Controls

| Key | Action |
| --- | --- |
| 🖱️ Camera / mouse | Hover the crosshair over a point |
| `E` | Use the selected option |
| `↑` / `↓` or mouse wheel | Change option when a point has several |

---

## 📏 How Distances Work

| Field | Meaning | Default |
| --- | --- | --- |
| `distance` | How close the player must be for the **dot** to appear | `8.0` (`10.0` for networked entities / bones) |
| `interactDst` | How close the player must be for the **prompt** to appear and `E` to work | `1.0` |
| `offset` | `vec3` offset from the entity where the point is placed | `vec3(0, 0, 0)` |

---

## 🧰 Options

Every export takes an `options` list. Each option supports:

```lua
{
    name = 'my:option',       -- optional, used by RemoveInteractionOption and to replace an existing option
    label = 'Pickup Hot Dog - $25',
    canInteract = function(entity, coords, args)
        return true           -- return false to hide this option
    end,

    -- Pick ONE of the following (checked in this order):
    action = function(entity, coords, args) end,
    serverEvent = 'my:server:event', -- TriggerServerEvent(serverEvent, args)
    event = 'my:client:event',       -- TriggerEvent(event, option)

    args = { any = 'data' },
}
```

---

## 🔌 Exports

Every `Add*` export takes a single table. Call exports with brackets: `exports['interact']`.

<details>
<summary><b>AddInteraction</b>: point at fixed coords</summary>

<br>

Returns the interaction id.

```lua
local id = exports['interact']:AddInteraction({
    coords = vec3(55.869, -1545.9351, 29.8501),
    distance = 2.0,
    interactDst = 1.0,
    name = 'laundromat_hack',
    options = {
        {
            label = 'Hack Security',
            event = 'sizan-robbery:client:UseBlueLaptop',
            canInteract = function()
                return true
            end,
        },
    },
})
```

</details>

<details>
<summary><b>AddLocalEntityInteraction</b>: point on a client-side entity</summary>

<br>

For non-networked entities. Returns the interaction id.

```lua
local id = exports['interact']:AddLocalEntityInteraction({
    entity = ped,
    offset = vec3(0.0, 0.0, 0.3),
    distance = 4.0,
    interactDst = 1.5,
    options = {
        {
            label = 'Talk',
            action = function(entity)
                print(('Talking to %s'):format(entity))
            end,
        },
    },
})
```

</details>

<details>
<summary><b>AddEntityInteraction</b>: point on a networked entity</summary>

<br>

`netId` accepts a network id or an entity handle. Non-networked entities fall back to `AddLocalEntityInteraction`. Returns the interaction id.

```lua
local id = exports['interact']:AddEntityInteraction({
    netId = NetworkGetNetworkIdFromEntity(vehicle),
    distance = 5.0,
    interactDst = 1.5,
    options = {
        { label = 'Search Vehicle', serverEvent = 'my:server:searchVehicle' },
    },
})
```

</details>

<details>
<summary><b>AddEntityBoneInteraction</b>: point on an entity bone</summary>

<br>

```lua
exports['interact']:AddEntityBoneInteraction({
    entity = vehicle,
    bone = 'boot',
    distance = 3.0,
    interactDst = 1.5,
    options = {
        { label = 'Open Trunk', action = function(entity) SetVehicleDoorOpen(entity, 5, false, false) end },
    },
})
```

</details>

<details>
<summary><b>AddModelInteraction</b>: point on every object of a model</summary>

<br>

Adds a point to every spawned object of the given models.

```lua
exports['interact']:AddModelInteraction({
    modelData = {
        { model = 'p_dumpster_t', offset = vec3(0.0, 0.0, 1.0) },
        { model = 'prop_dumpster_02a', offset = vec3(0.0, 0.0, 1.0) },
    },
    distance = 8.0,
    interactDst = 1.0,
    options = {
        {
            label = 'Search Trash',
            action = function(entity, coords, args)
                SearchTrash(entity)
            end,
        },
    },
})
```

</details>

### Removing & Updating

```lua
exports['interact']:RemoveInteraction(id)                    -- remove by id
exports['interact']:RemoveInteractionByEntity(entity)        -- remove everything on an entity
exports['interact']:RemoveInteractionOption(id, 'my:option') -- remove a single named option
exports['interact']:UpdateInteraction(id, newOptions)        -- replace the options list
```

> [!NOTE]
> Interactions are removed automatically when the resource that created them stops.

### Disable

```lua
exports['interact']:Disable(true)  -- hide and block all interactions
exports['interact']:Disable(false)
```

---

## ⚙️ Configuration

All settings are in [`shared/settings.lua`](shared/settings.lua).

### Prompt

> [!TIP]
> Sizes are fractions of screen height. Divide the pixel size you want at 1080p by 1080.

| Setting | Default | Description |
| --- | --- | --- |
| `key` | `'E'` | Letter shown in the key badge |
| `uppercase` | `true` | Render labels in uppercase |
| `textHeight` | `0.0125` | Label cap height (~13px) |
| `keySize` | `0.0167` | Key badge size (~18px) |
| `keyTextHeight` | `0.0095` | Letter size inside the badge |
| `keyGap` | `0.0075` | Space between badge and label |
| `dotSize` | `0.0155` | Interaction dot size (~16px) |
| `crosshairSize` | `0.0055` | Crosshair dot size |
| `crosshair` | `true` | Show the crosshair while points are nearby |
| `hoverRadius` | `0.06` | How close the crosshair must be to a point to select it |
| `rowSpacing` | `0.024` | Spacing between options on the same point |
| `textColor` / `keyColor` / `keyTextColor` | white / white / near-black | RGBA colours |
| `dimmedAlpha` | `140` | Opacity of non-selected options |
| `shadowAlpha` | `110` | Label drop shadow strength (`0` to disable) |

### Disable

| Setting | Default | Description |
| --- | --- | --- |
| `onDeath` | `true` | Disable while dead |
| `onNuiFocus` | `true` | Disable while NUI has focus |
| `onVehicle` | `true` | Disable while in a vehicle |
| `onHandCuff` | `true` | Disable while cuffed |

---

## 📄 Credits & License

- **Original resource:** [interact](https://github.com/darktrovx/interact) by [darktrovx](https://github.com/darktrovx).
- **NoPixel V restyle:** [Karma Developments](https://karmadevelopments.shop).
- Prompt font: [Barlow Condensed](https://github.com/jpt/barlow) SemiBold Italic, SIL Open Font License 1.1.
- Licensed under [CC BY-NC-SA 4.0](LICENSE).

<div align="center">

<br>

**Made with ❤️ by [Karma Developments](https://karmadevelopments.shop)**

[Discord](https://discord.gg/karmadevelopments) • [Store](https://karmadevelopments.shop)

</div>
