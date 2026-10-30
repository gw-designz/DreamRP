# xeno-scriptcreator (Decision Tree Creator System for FiveM)

Production-ready visual scripting engine and suite of creator tools for FiveM.

Users can design gameplay logic as node graphs, build UI templates, create custom NPCs, manage skill trees, and setup crafting systems entirely within a NUI (React) editor. The server executes these components securely through a modular Lua runtime.

## Features

- **Decision Tree Editor**: Visual node editor (Trigger, Condition, Action, Loop, Progress). Drag, connect, and configure nodes.
- **UI Builder**: Visual drag-and-drop builder for custom UI screens and dialogs.
- **NPC Creator**: Configure NPC appearances, animations, and routines dynamically.
- **Skill Tree Editor**: Create elaborate skill progression graphs with XP requirements and branches.
- **Crafting System**: Setup recipes, wait times, and XP rewards.
- **Compiled Lua Pipeline**: JSON graphs are compiled directly into native Lua functions for maximum performance.
- **AI Assist**: Generate and refactor Lua code natively using AI via prompt.
- **Real-Time Collaboration**: Work with other server developers simultaneously in the same document.
- **Multi-Framework**: Out-of-the-box support for QB-Core, QBX-Core, ESX, and standalone.
- **MySQL Persistence**: Fast and reliable database storage (`decision_trees` and related tables auto-migrate on start).

## Architecture

### NUI (React)
- Comprehensive suite of editors built with React, Vite, Tailwind CSS, and Framer Motion.
- Drag and drop capabilities using `@dnd-kit`.
- Virtualized lists for high performance on large graphs.
- NUI bridge (`src/lib/nui.ts`) with LocalStorage fallback for web browser development.

### Runtime (Lua)
- `server/core/engine.lua`: Graph traversal and execution state handling.
- `server/core/compiler.lua`: Compiles node graphs into highly optimized Lua execution paths.
- `server/core/actions_registry.lua`: 30+ registered actions, heavily sandboxed.
- `server/core/conditions.lua`: 25+ condition evaluators for advanced logic.
- `client/editor/placement.lua`: In-world freecam editor for easy entity placement.

### Bridge (`editable/bridge/`)
- Easily customize inventory, framework, and notification events without modifying core files.

## Supported Actions & Conditions

**Actions:**
- `give_item`, `remove_item`, `give_money`
- `spawn_vehicle`, `spawn_ped`, `spawn_target_ped`
- `trigger_client_event`, `trigger_server_event`
- `notify_player`, `set_variable`, `modify_variable`
- `run_custom_code` (sandboxed)
- `start_heist_phase`, `spawn_guard_wave`, `start_hack_minigame`
...and 20+ more.

**Conditions:**
- `has_item`, `has_money`
- `job_check`, `gang_check`, `job_grade_check`, `license_check`
- `is_on_duty`, `in_zone`, `is_wanted`, `cops_online_check`
- `variable_comparison`, `variable_exists`
- `has_skill`, `skill_points_check`
...and 10+ more.

## Setup

1. Install web dependencies (if building from source):

```bash
cd web
npm install
```

2. Build NUI assets:

```bash
npm run build
```

3. Database:
No manual SQL imports are required! `server/core/storage.lua` will automatically create the necessary tables on first start.

4. Add resource to your FiveM `server.cfg`:

```cfg
ensure oxmysql
ensure xeno-scriptcreator

# Give admins permission to use the editor
add_ace group.admin dtree.editor allow
```

5. Open editor in-game:
Use command: `/dtree_editor`

## Security
- **ACE Permissions**: All editor actions (save, delete, compile, publish) are protected by the ACE permission `dtree.editor`.
- **Custom Code Sandbox**: `run_custom_code` actions are sandboxed. They do NOT have access to the global `_G` table and can only invoke whitelisted FiveM natives (`GetPlayerPed`, `TriggerClientEvent`, etc).

## Development

Run NUI locally in your browser:
```bash
cd web
npm run dev
```

Validate code:
```bash
npm run lint
npm run build
```
