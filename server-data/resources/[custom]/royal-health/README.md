<div align="center">

<h2>royal-health</h2>
royal's bone &amp; limb damage system for FiveM

[![Requires](https://img.shields.io/badge/requires-ox__lib-blue.svg)](https://github.com/overextended/ox_lib)
[![Requires](https://img.shields.io/badge/requires-ox__inventory-blue.svg)](https://github.com/overextended/ox_inventory)
[![License](https://img.shields.io/badge/license-GPL--3.0-green.svg)](LICENSE)

</div>

---

## Installation

1. Download the latest release.
2. Place it inside your `resources` folder.
3. Make sure [ox_lib](https://github.com/overextended/ox_lib) & [ox_inventory](https://github.com/overextended/ox_inventory) are started before it.
4. Ensure `royal-health` in your `server.cfg`.
5. Set your framework at the top of `config.lua` (`QBX`, `ESX`, `ND`, `OX` or `STANDALONE`).
6. Restart the server.

The medical items are already wired in `ox_inventory/data/items.lua` — each one
routes its use to `client.export = 'royal-health.useItem'`. Using a bandage,
first aid, medkit or painkillers heals health and treats bones. When a player is
revived through your framework, every injury is cleared automatically.

## Body parts

Every GTA skeleton bone is folded into one of eleven parts. Neck counts as
`head`, spine/ribs/chest as `torso`, hips as `pelvis`, and fingers as the
matching hand.

```
head        torso        pelvis
left-arm    left-hand    left-leg    left-foot
right-arm   right-hand   right-leg   right-foot
```

## Configuration

`config.lua`:

| Option | Meaning |
| --- | --- |
| `Config.Framework` | Which framework to bridge (`QBX` / `ESX` / `ND` / `OX` / `STANDALONE`) |
| `Config.MinDamage` | Smallest hit that registers as an injury |
| `Config.CheckInterval` | How often (ms) the damage watcher runs |
| `Config.BleedChance` | Percent chance a qualifying hit also causes bleeding |
| `Config.Effects.limp` | Limp when legs, feet or pelvis are hurt |
| `Config.Effects.limpThreshold` | Injury level before limping starts |
| `Config.Effects.bleed` | Bleeding drains health over time |
| `Config.Effects.bleedMinHealth` | Bleeding never drops a player below this |
| `Config.EnableTestCommand` | Registers the `/hurtbone` test commands |

Item effects live in `Config.Items`. Each entry supports `health`, `setHealth`,
`armor`, `setArmor`, `bones` *(number or `'all'`)*, `stopBleed` *(number or
`'all'`)*, `cancelOnDeath` and `notify` (a locale key).

## Server exports

### `Revive(playerID)`

Revives the player through the active framework and clears all of their bone
damage. This is the call your ambulance or medical resource makes.

```lua
exports['royal-health']:Revive(playerId)
```

### `ClearInjuries(playerID)`

Clears every bone injury on a player without reviving them.

```lua
exports['royal-health']:ClearInjuries(playerId)
```

## Client exports

### `GetInjuries()`

The local player's current injuries, keyed by body part. Also mirrored on
`LocalPlayer.state.injuries` so a HUD in another resource can read it.

```lua
local injuries = exports['royal-health']:GetInjuries()
-- { ['left-leg'] = { damage = 60, bleeding = 1 } }
```

### `IsInjured()`

`true` if any body part is currently hurt.

```lua
if exports['royal-health']:IsInjured() then
    -- show the treat button
end
```

### `Injure(partID, amount)`

Adds `amount` damage to a body part. Handy for your own trauma events (car
crashes, falls, tasers).

```lua
exports['royal-health']:Injure('torso', 25)
```

### `HealBones(amount)`

Removes `amount` injury points from every injured part. Pass `'all'` to clear
them completely.

```lua
exports['royal-health']:HealBones(20)
exports['royal-health']:HealBones('all')
```

### `StopBleeding(amount)`

Removes `amount` bleed levels from every bleeding part. Pass `'all'` to stop all
bleeding at once.

```lua
exports['royal-health']:StopBleeding('all')
```

### `ClearInjuries()`

Wipes every injury on the local player — the same thing a revive does.

```lua
exports['royal-health']:ClearInjuries()
```

## Example

Reviving a downed player from your own ambulance script, server side:

```lua
RegisterNetEvent('my-ambulance:server:treatPatient', function(patientId)
    local medic = source

    -- your own job / distance checks go here

    exports['royal-health']:Revive(patientId)
end)
```

Feeding the injury state into a HUD, client side:

```lua
CreateThread(function()
    while true do
        local injuries = exports['royal-health']:GetInjuries()

        for part, injury in pairs(injuries) do
            -- part = 'left-leg', injury.damage = 60, injury.bleeding = 1
            SendNUIMessage({ action = 'injury', part = part, data = injury })
        end

        Wait(1000)
    end
end)
```

## How injuries work

Damage is read from the exact bone the game reports on each hit, so a shot to
the shin lands on `left-leg`, not on your overall health bar. Injured legs, feet
or the pelvis make the player limp; other parts have a chance to bleed, which
slowly drains health down to `Config.Effects.bleedMinHealth` — enough to hurt,
never enough to kill on its own.

Bandages and first aid patch a set number of injury points and stop some
bleeding; a medkit clears everything. A revive from any supported framework
(qbx_medical, esx_ambulancejob, and the others) wipes the slate clean through
the bridge.

## Localization

Text is handled by ox_lib locales. English (`en`) and Danish (`da`) ship in the
`locales/` folder. Pick the language with a server convar:

```cfg
setr ox:locale da
```

Add another language by dropping a `locales/<code>.json` next to the others.

## 🙏 Credits

<table>
  <tr>
    <td align="center">
      <a href="https://github.com/overextended">
        <img src="https://avatars.githubusercontent.com/u/88127058" width="100px;" alt="Overextended"/>
        <br />
        <sub><b>Overextended</b></sub>
      </a>
      <br />
      <sub>ox_lib &amp; ox_inventory</sub>
    </td>
  </tr>
</table>

Notifications, locales and item usage are all handled by
**[ox_lib](https://github.com/overextended/ox_lib)** and
**[ox_inventory](https://github.com/overextended/ox_inventory)** from the
[Overextended](https://github.com/overextended) team.

---

<div align="center">

**[Discord](https://discord.gg/H2bCPuqeT7)**

Made with 💚 by royal for the FiveM community

</div>
