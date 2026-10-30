# Karma Developments - nopixel V Inspired Progressbar System

`karma-progressbar` is a rogress bar script. This README shows how do you install it and how to replace common `ox_lib`, `qb-progressbar`, and `esx_progressbar` progress calls with the Karma Developments Progressbar exports.

## Karma Developments

If you like this free resource, consider joining the **Karma Developments Discord** for **support, updates, announcements, and future releases**.

- **Discord:** https://discord.gg/karmadevelopments
- **Store:** https://karmadevelopments.shop

You can also check out our store for more FiveM scripts and systems from **Karma Developments**.


![Alt text](https://i.postimg.cc/FKg8SMTJ/9f21eab9-91e0-467c-907f-7ebeddc7a4bb.png)

## Installation

1. Download the resource.
2. Put the folder in your server resources directory.
3. Keep the folder name as `karma-progressbar`.
4. Add this to your `server.cfg` before any resource that uses it:

```cfg
ensure karma-progressbar
```

If you rename the folder, you must also change every export call from `exports['karma-progressbar']` to your new folder name.

## Exports

All exports are client-side.

| Export | Usage | Description |
| --- | --- | --- |
| `start` | `exports['karma-progressbar']:start(label, duration, control)` | Starts a progress bar. |
| `show` | `exports['karma-progressbar']:show(label, duration, control)` | Alias for `start`. |
| `stop` | `exports['karma-progressbar']:stop()` | Stops the current progress bar. |
| `hide` | `exports['karma-progressbar']:hide()` | Alias for `stop`. |
| `cancel` | `exports['karma-progressbar']:cancel()` | Cancels the current progress bar. |
| `isOpen` | `exports['karma-progressbar']:isOpen()` | Returns `true` while a progress bar is active. |
| `wasCanceled` | `exports['karma-progressbar']:wasCanceled()` | Returns `true` if the last progress bar was cancelled. |

Parameters:

| Parameter | Type | Description |
| --- | --- | --- |
| `label` | `string` | Text shown on the progress bar. Defaults to `PROGRESS...`. |
| `duration` | `number` | Duration in milliseconds. Example: `5000` is 5 seconds. |
| `control` | `number` | Optional FiveM control id used to cancel. Defaults to `322`, which is ESC. |

## Basic Usage

Start a simple progress bar:

```lua
exports['karma-progressbar']:start('GRABBING ITEM...', 5000)
```

Cancel the current progress bar manually:

```lua
exports['karma-progressbar']:cancel()
```

Check if a progress bar is running:

```lua
if exports['karma-progressbar']:isOpen() then
    print('Progressbar is active')
end
```

## Test Commands

These commands are included for quick in-game testing and YouTube showcases.

| Command | Description |
| --- | --- |
| `/kpb` | Starts a 5 second showcase progressbar. |
| `/kpb 8000 Repairing vehicle...` | Starts a custom progressbar for 8000ms with your label. |
| `/kpb Repairing vehicle...` | Starts a 5 second progressbar with your custom label. |
| `/kpbshort` | Starts a short 3 second progressbar. |
| `/kpblong` | Starts a long 10 second progressbar. |
| `/kpbcancel` | Cancels the active progressbar. |
| `/kpbstatus` | Prints whether the progressbar is open and whether the last one was cancelled. |
| `/kpbshowcase` | Plays a small sequence of progressbars for recording. |

Example:

```text
/kpb 7000 Lockpicking door...
```

## Recommended Helper

Old progressbar systems usually wait until the action finishes, then run finish or cancel code. `karma-progressbar:start()` starts the UI and returns immediately, so use a small helper when replacing old callback-style code.

Add this helper in any client file that uses progressbars:

```lua
local function KarmaProgress(label, duration, cancelControl)
    exports['karma-progressbar']:start(label, duration, cancelControl)

    while exports['karma-progressbar']:isOpen() do
        Wait(0)
    end

    return not exports['karma-progressbar']:wasCanceled()
end
```

Usage:

```lua
CreateThread(function()
    local finished = KarmaProgress('DOING SOMETHING...', 5000)

    if finished then
        print('Finished')
    else
        print('Cancelled')
    end
end)
```

## Replacing ox_lib Progressbars

`ox_lib` commonly uses `lib.progressBar(data)` or `lib.progressCircle(data)`.

### Option 1: Replace ox_lib Globally

Use this method if you want every script that already calls `lib.progressBar()` or `lib.progressCircle()` to show the Karma progressbar automatically.

This means you do not need to edit every script one by one. Instead, you patch ox_lib once and keep using the normal ox_lib calls in your other resources.

Recommended `server.cfg` order:

```cfg
ensure karma-progressbar
ensure ox_lib
ensure your_other_resources
```

Open this file in your ox_lib resource:

```text
ox_lib/resource/interface/client/progress.lua
```

Find the `startProgress(data, nuiMessage)` function. Inside that function, find the line that starts the original ox_lib NUI progress UI:

```lua
SendNUIMessage(nuiMessage)
```

Replace that line with:

```lua
exports['karma-progressbar']:start(data.label or 'PROGRESS...', data.duration or 1)
```

Now, inside the same `while progress do` loop, add this before the loop calls `Wait(0)`:

```lua
if not exports['karma-progressbar']:isOpen() then
    progress = exports['karma-progressbar']:wasCanceled() and false or nil
end
```

Then, after the `while progress do` loop ends, add this before ox_lib cleans up props or animations:

```lua
if progress == false then
    exports['karma-progressbar']:cancel()
else
    exports['karma-progressbar']:stop()
end
```

After this patch, existing code like this:

```lua
if lib.progressBar({
    duration = 5000,
    label = 'Doing something',
    canCancel = true,
}) then
    print('Finished')
else
    print('Cancelled')
end
```

will keep working, but the UI shown to the player will be the Karma progressbar.

This global method keeps most ox_lib behavior because ox_lib is still handling:

- `lib.progressBar()`
- `lib.progressCircle()`
- `lib.progressActive()`
- `lib.cancelProgress()`
- animations
- props
- disabled controls
- return value on finish or cancel

Important notes:

- Back up `ox_lib/resource/interface/client/progress.lua` before editing it.
- ox_lib updates can overwrite this change, so reapply the patch after updating ox_lib.
- The Karma progressbar is a bar UI. `lib.progressCircle()` calls will still use the Karma bar, not a circle.
- The current Karma export uses ESC as its cancel key. If you need exact ox_lib `canCancel = false` behavior, add that rule to your wrapper or to this resource before using this global patch.

### Option 2: Replace Each Script Manually

Use this method if you only want to move selected scripts from ox_lib to Karma.

Before:

```lua
if lib.progressBar({
    duration = 5000,
    label = 'Doing something',
    useWhileDead = false,
    canCancel = true,
    disable = {
        car = true,
    },
}) then
    print('Finished')
else
    print('Cancelled')
end
```

After:

```lua
CreateThread(function()
    local finished = KarmaProgress('Doing something', 5000)

    if finished then
        print('Finished')
    else
        print('Cancelled')
    end
end)
```

For a direct one-line progress bar where you do not need finish or cancel logic:

```lua
exports['karma-progressbar']:start('Doing something', 5000)
```

Replace these ox_lib helpers:

```lua
-- Before
lib.progressActive()

-- After
exports['karma-progressbar']:isOpen()
```

```lua
-- Before
lib.cancelProgress()

-- After
exports['karma-progressbar']:cancel()
```

Search your scripts for:

```text
lib.progressBar
lib.progressCircle
lib.progressActive
lib.cancelProgress
```

Then replace each call using the examples above.

## Replacing qb-progressbar

QBCore scripts commonly use `QBCore.Functions.Progressbar(...)` or `exports['progressbar']:Progress(...)`.

Before:

```lua
QBCore.Functions.Progressbar('random_task', 'Doing something', 5000, false, true, {
    disableMovement = false,
    disableCarMovement = false,
    disableMouse = false,
    disableCombat = true,
}, {
    animDict = 'mp_suicide',
    anim = 'pill',
    flags = 49,
}, {}, {}, function()
    print('Finished')
end, function()
    print('Cancelled')
end)
```

After:

```lua
CreateThread(function()
    local finished = KarmaProgress('Doing something', 5000)

    if finished then
        print('Finished')
    else
        print('Cancelled')
    end
end)
```

If your script uses the old export:

```lua
exports['progressbar']:Progress({
    name = 'random_task',
    duration = 5000,
    label = 'Doing something',
    canCancel = true,
}, function(cancelled)
    if not cancelled then
        print('Finished')
    else
        print('Cancelled')
    end
end)
```

Replace it with:

```lua
CreateThread(function()
    local finished = KarmaProgress('Doing something', 5000)

    if finished then
        print('Finished')
    else
        print('Cancelled')
    end
end)
```

Search your scripts for:

```text
QBCore.Functions.Progressbar
exports['progressbar']:Progress
exports["progressbar"]:Progress
exports['progressbar']:isDoingSomething
exports["progressbar"]:isDoingSomething
```

Common replacements:

```lua
-- Before
exports['progressbar']:isDoingSomething()

-- After
exports['karma-progressbar']:isOpen()
```

## Replacing ESX Progressbars

ESX scripts commonly use `ESX.Progressbar(...)` or `exports['esx_progressbar']:Progressbar(...)`.

Before:

```lua
ESX.Progressbar('Doing something', 5000, {
    FreezePlayer = false,
    onFinish = function()
        print('Finished')
    end,
    onCancel = function()
        print('Cancelled')
    end
})
```

After:

```lua
CreateThread(function()
    local finished = KarmaProgress('Doing something', 5000)

    if finished then
        print('Finished')
    else
        print('Cancelled')
    end
end)
```

If your script uses the old ESX export:

```lua
exports['esx_progressbar']:Progressbar('Doing something', 5000, {
    onFinish = function()
        print('Finished')
    end,
    onCancel = function()
        print('Cancelled')
    end
})
```

Replace it with the same Karma helper:

```lua
CreateThread(function()
    local finished = KarmaProgress('Doing something', 5000)

    if finished then
        print('Finished')
    else
        print('Cancelled')
    end
end)
```

Cancel replacement:

```lua
-- Before
ESX.CancelProgressbar()

-- After
exports['karma-progressbar']:cancel()
```

```lua
-- Before
exports['esx_progressbar']:CancelProgressbar()

-- After
exports['karma-progressbar']:cancel()
```

Search your scripts for:

```text
ESX.Progressbar
ESX.CancelProgressbar
exports['esx_progressbar']:Progressbar
exports["esx_progressbar"]:Progressbar
exports['esx_progressbar']:CancelProgressbar
exports["esx_progressbar"]:CancelProgressbar
```

## Animations, Props, and Control Disables

`karma-progressbar` only handles the progress UI, duration, and cancel state. Old options such as `animation`, `prop`, `propTwo`, `disable`, `controlDisables`, `useWhileDead`, `canCancel`, and `FreezePlayer` are not automatically handled by this export.

If your old progressbar played an animation or froze the player, keep that logic in your script:

```lua
CreateThread(function()
    local ped = PlayerPedId()

    RequestAnimDict('mp_suicide')
    while not HasAnimDictLoaded('mp_suicide') do
        Wait(0)
    end

    TaskPlayAnim(ped, 'mp_suicide', 'pill', 8.0, -8.0, -1, 49, 0, false, false, false)

    local finished = KarmaProgress('Taking pill...', 5000)

    ClearPedTasks(ped)

    if finished then
        print('Finished')
    else
        print('Cancelled')
    end
end)
```

## Notes

- This resource is client-side.
- The default cancel key is ESC.
- The current export does not have a `canCancel = false` option. If an old action was not cancellable, ignore the cancel branch or add that rule in your own wrapper.
- `start()` and `show()` are the same export.
- `stop()` and `hide()` are the same export.
- `wasCanceled()` reports the state of the last progressbar.
- Use `KarmaProgress()` when replacing old progressbars that used callbacks or returned completion status.
