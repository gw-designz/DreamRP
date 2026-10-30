# Weazel News laptop (nova_laptop)

A macOS-style laptop for the Weazel News business on Qbox. You set the laptop down where you want it, and the desktop is drawn on its screen, with a menu bar, red-titled windows and a dock holding five apps and the Trash:

| App | What it does |
| --- | --- |
| **LifeInvader** (staff portal) | News feed of what the newsroom did, Friends (staff list: add, unfriend, change group, pay), Groups (permission groups), Wallet (company account and paying staff), clock in/out |
| **Weazel Writer** | The article desk: headline (75), story (1,000), up to 20 photos from the memory card or phone gallery, submit for review, and the status of your stories |
| **Magazine Editor** | One shared draft of the next issue: pages, layouts, section names, staff columns, approving/rejecting submissions, drag articles onto pages, publish |
| **Newsstand** | Every published issue, readable page by page, with Print copies |
| **Camera** | The memory card (60 photos), and *Take photos*: the laptop closes and you raise a camera |
| **Trash** | Rejected and deleted stories: restore or delete forever |

## Install

1. Keep the folder named `nova_laptop` and add `ensure nova_laptop` to `server.cfg` after `oxmysql`, `qbx_core`, `ox_inventory` and `Renewed-Banking`.
2. The tables (`nova_news_*`) are created on the first start.
3. Put your Fivemanage API key in **`server_config.lua`** (loaded by the server only; never in `config.lua`, which every player receives):

   ```lua
   ServerConfig.Fivemanage = {
       apiKey = 'your-api-key',
       url = 'https://api.fivemanage.com/api/v3/file',
   }
   ```

4. Items: add `paper` and `magazine` from `install/ox_inventory.lua` to `ox_inventory/data/items.lua` (and `laptop`, if you want a usable item).
5. The news job needs a boss grade. The owner is whoever holds an `isboss` grade of `Config.News.Job`:

   ```lua
   ['reporter'] = { label = 'Reporter', defaultDuty = true, offDutyPay = false, grades = {
       [0] = { name = 'Journalist', payment = 50 }, [1] = { name = 'Reporter', payment = 75 },
       [2] = { name = 'Editor', payment = 100 }, [3] = { name = 'Owner', payment = 150, isboss = true, bankAuth = true },
   } },
   ```

6. Renewed-Banking must let this resource move money: add `['nova_laptop'] = true` to `compatibility.allowedResources` in its `config.lua`. The `reporter` business account is created on start if it is missing.

Open with `/laptop` (or the `laptop` item). `/laptopclose` in F8 recovers focus if anything gets stuck.

## Setting the laptop down

`/laptop` (or using the item) away from your laptop brings up a see-through laptop where you are looking. Move it with **object_gizmo** (v3): W move, R rotate, Q local/world, Alt snap to the surface, **Enter** to put it down, **Esc** to cancel. Once it is down the desktop opens on it. Without object_gizmo the laptop follows your aim instead: the mouse wheel turns it, E puts it down.

The server creates the placed laptop (OneSync), so everyone sees it, but only you can use it. Walk up to it: **interact** shows **Use laptop** and **Pick up laptop** on it (press E). Without interact, stand at it and press E to use or G to pick up. `/laptop` next to it opens it too. Each player has one laptop down at a time: placing another replaces it, and it is removed when you leave. Distances are in `Config.Placement`.

## How the business works

- **Staff** are the players with the `reporter` job. *Add Friend* takes a server ID and sets their job; *Unfriend* removes it. The owner (the boss grade) cannot be unfriended.
- **Owners** have every permission and sit in the locked **Owner** group: the citizen IDs in `Config.News.Owners` (staff even without the job) and anyone on the job's boss grade.
- **Groups** decide what everyone except the owner may do: write, review, edit the magazine, publish, print, manage staff, pay staff. New staff land in the built-in *Employee* group (write and print by default). Only the owner edits groups.
- **Stories** go Writer → *pending* → approved or rejected by someone with *review* (in the Magazine Editor's list). Approved stories and the staff columns can be placed on pages. Publishing snapshots the pages into an issue, marks placed stories *published* and starts a fresh draft. Page 1 is the cover: its first slot's headline and first photo are the cover story.
- **Printing** happens beside a printer: one a staff member set down (`prop_printer_01`, from `/printer` or the Print copies dialog's **Place printer**, placed with object_gizmo, picked up again with interact) or a fixed spot in `Config.News.Printing.Printers`. Each printer has two ox_inventory stashes: a **paper tray** (only `paper`, one sheet per copy) and an **output tray** the `magazine` copies come out into, a few seconds per copy. At the printer, interact shows one **Interact**, which opens a radial menu drawn like codera-radialmenu (nova_laptop draws its own; codera-radialmenu is left untouched): **Open Printer** (the output tray), **Make Copy(s)** (pick an issue and how many), **Deposit Paper** (the paper tray) and, for its owner, **Pick Up Printer**. Left click picks, right click or Esc closes. A placed printer's trays belong to its owner's citizen ID and keep their contents; the fixed office printers have their own. Using a copy opens the issue full screen.
- **Photos** are taken with screencapture and uploaded to Fivemanage; the memory card keeps their addresses. Phone photos (oph3z-phone's `GetPhotos`) are copied onto the memory card when attached to a story.
- **Wallet** pays from the Renewed-Banking account `Config.News.Account` into the staff member's bank. They must be in the city.

Settings are in `Config.News` in `config.lua`.

## On the laptop (world mode)

This works the way Renewed-Banking paints its ATMs:

- **Painting.** The desktop page runs off screen as two DUIs. One is a lock screen that every placed laptop nearby shows. The other is your live desktop, shown on the laptop you are using. Both are drawn onto the laptop's glass every frame.
- **Using it.** While you use it, the camera faces the glass and the game keeps the mouse. The cursor's ray is met with the glass and clicks, drags and the wheel go into the page. The keyboard goes to the page only while a text field has the caret (`SetNuiFocusKeepInput`, as the ATMs do). Esc closes menus, then the laptop.
- **Fallback.** Set `Config.Display.Mode = 'screen'` for a full-screen overlay with no laptop to set down.

### Lining the screen up

Where the desktop sits on the glass is per laptop model, in the model's coordinates (front facing -Y): centre, size and how far the top leans back. It comes from `screens.json`, then `Config.Display.Screens`, then a fit from the model's size.

Staff (the ACEs in `Config.Display.EditGroups`, Qbox's `god`/`admin` by default) stand at a placed laptop and run `/laptopscreen`, or choose **Adjust Screen Position** in the laptop's menu:

- An invisible handle sits on the screen. Move it with **object_gizmo** (v3): W move, R rotate, **S scale** (stretch either axis to change the width or height).
- **Enter** saves it to `screens.json` on the server and every player gets it at once. The `config.lua` line is printed in F8. **Esc** cancels.
- `/laptopscreen outline` outlines every nearby screen.
- `/laptopscreen reset` goes back to the default.
- `/laptopscreen x y z width height tilt` sets it by hand.

`/laptopzoom 0.72` changes how much of the view the screen fills while using it (lower shows more of the laptop and desk).

## Controls

| Control | Action |
| --- | --- |
| Click a dock icon | Open the app, or bring it forward |
| Drag a title bar / bottom-right corner | Move / resize a window |
| Double-click a title bar, green light | Zoom |
| Ctrl+Space | Spotlight |
| Escape | Close a dialog, menu or panel, then the laptop |
| In Camera: click / wheel / Esc | Take a photo / zoom / put it away |

## Developing the interface

```bash
cd web
npm ci
npm run dev     # browser preview with sample staff, stories, photos and an issue
npm run build   # what FiveM serves, in web/dist
```

The preview can start on any app: `?app=portal|writer|magazine|newsstand|camera|trash`.

The previous desktop's apps (Home, Notes, Files, Nova Invest, Jobs Hub, Calculator, Settings) are kept in `_unused/` and are not loaded. Delete that folder if you no longer want them.

## Troubleshooting

| Symptom | Check |
| --- | --- |
| Portal says staff only | Your character needs the `Config.News.Job` job. |
| Everything is greyed out | Your group lacks the permission; the owner ticks it in Groups. |
| Company account shows `—` / payments refused | Renewed-Banking is running, the account exists, and `nova_laptop` is in its `allowedResources`. |
| Photos do not save | `ServerConfig.Fivemanage.apiKey` is set in `server_config.lua`, `screencapture` is running, and the memory card is not full. |
| Phone gallery unavailable | `Config.News.PhoneResource` names your running phone and it exports `GetPhotos`. |
| Printing refused | Paper in your pockets, room for the copies, and (if set) standing by a printer. |
| Desktop floats beside the laptop | Tune `Config.Display.Screen` with `laptopscreen`. |
| Opens as an overlay instead of on the laptop | The screen page did not load in time, or `Config.Display.Mode` is `'screen'`; check F8. |
| Laptop will not go down | OneSync must be on (the server creates it); it must be within `Config.Placement.MaxDistance` of you. |
