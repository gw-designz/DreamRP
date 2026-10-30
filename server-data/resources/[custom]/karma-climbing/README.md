# 🧗 FREE - Karma Developments - nopixel V Inspired Climbing Roofs System

## Karma Developments

If you like this free resource, consider joining the **Karma Developments Discord** for **support, updates, announcements, and future releases**.

- **Discord:** https://discord.gg/karmadevelopments
- **Store:** https://karmadevelopments.shop

You can also check out our store for more FiveM scripts and systems from **Karma Developments**.

![Alt text](https://i.postimg.cc/K4SwGzpV/PSD-Script-s-Temp-(5).jpg)

**Karma Developments Climbing Roofs System** is a standalone FiveM resource that adds NoPixel V inspired **ledge grabbing & parkour climbing** to your server. 
Jump from roof to roof — if a ledge is within arm's reach while you're airborne, your character grabs it and pulls themselves up instead of falling.
No framework dependencies. Drop it in and it just works.

---

## ✨ Features

- **Ledge grab parkour** — catch roof edges mid-air instead of falling past them
- **Natural feel** — uses GTA's native `TaskClimb` with a small velocity assist, no teleporting
- **Smart detection** — checks for reachable edges in the player's movement/velocity direction
- **Standalone** — works on QBox, ESX, qb-core or any framework

## ⚙️ Main Configuration (`config.lua`)

| Setting | Description |
|---|---|
| `ClimbMaxHeight` / `ClimbMinHeight` | Reachable ledge height range |
| `Climb.LedgeGrab.DetectDistance` | When the NUI guide bar starts showing |
| `Climb.LedgeGrab.ArmReachDistance` | Distance at which the grab triggers |
| `Climb.LedgeGrab.VelocityAssist` / `UpwardAssist` | Small natural push into the native climb |
| `Climb.LedgeGrab.UseFallbackPlacement` | Optional forced placement if native climb fails |
| `Climb.AllowedMaterials` | Restrict climbing to specific material hashes (default: all) |

## 📦 Exports

```lua
exports['karma-climbing']:TriggerLedgeClimb() -- Force a ledge climb
exports['karma-climbing']:IsMantling()        -- Returns true while climbing
```

## 🔧 Installation

1. Drop the `karma-climbing` folder into your `resources` directory
2. Add `ensure karma-climbing` to your `server.cfg`
3. Restart the server — that's it

---

<div align="center">
  <sub>Made with ❤️ by <b>KARMA Developments</b></sub>
</div>
