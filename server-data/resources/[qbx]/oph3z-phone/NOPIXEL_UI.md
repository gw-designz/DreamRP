# NoPixel-style UI edition

This edition turns oph3z-phone into a NoPixel V–style foldable phone. Every app on the home screen has a working screen. Apps that need data are backed by server code, which validates every request; nothing trusts amounts or ownership sent by the client.

## Install / update

1. Replace the resource folder. `build/` is already compiled, so you don't need Node.js unless you change `web/src`.
2. Start the resource. All new tables (and the `place` column on `oph3z_phone_photos`) are created automatically. If you manage your schema by hand, run the "NoPixel-style apps" section at the end of `install.sql`. No existing table or column is changed or dropped.
3. Review `config.lua`. New blocks: `Config.UI`, `Config.Socials`, `Config.Licenses`, `Config.Garage`, `Config.Business`, `Config.Crypto`, `Config.Calendar`, `Config.Government`, `Config.News`, `Config.Events`, `Config.Property`, `Config.Guber`, `Config.Roach`, `Config.ScootE`, `Config.LemonList`, plus the new `Config.Apps` layout.
4. Restart. New characters start with the **Ember** wallpaper. Existing players can pick it (or **Graphite**) under Settings › Wallpaper.

## Controls

| Key | Action |
|---|---|
| T | Fold / unfold (narrow phone ↔ wide tablet). Each character's last choice is remembered. |
| Y | Home |
| Enter | Activate the focused item (arrow keys move focus) |
| Backspace | Back. Closes the top sheet first, then the app's own screen stack, then the app. |
| Q / E | Previous / next bottom tab in every app (months in Calendar, regions in Government) |
| Esc | Close the phone (in fullscreen camera: leave fullscreen) |
| Clock in the status bar | Notification panel |

Keys are ignored while typing. The Calculator, Keypad and the money/crypto keypads use digits and Backspace themselves.

Every button and app plays GTA frontend sounds (hover, click, Enter, back, app open, home). Change or mute them in `Config.UI.Sounds`; players can turn them off under Settings › Sounds › Interface Sounds. Add `data-sound="none"` to an element to silence it.

## Apps

| App | Backend | What works |
|---|---|---|
| Bank | existing wallet | Branded as the provider picked in **Phone Setup** on the first open: Fleeca (green), Pacific Standard (blue) or Paleto (red). It can be changed under Settings › Appearance › Bank Provider, and `Config.UI.PhoneSetup = false` turns the setup off. Balance, Account ID, latest transactions, transfer by **Account ID (citizenid) or phone number**, invoices, full history, account info |
| Business | `server/app/business` | Create businesses (name/description/code), invite by phone, accept/decline invites, owner/manager/employee roles, announcements, promote/fire, edit, delete, leave |
| Calendar | `server/app/calendar` | Month grid, Q/E months, personal events, optional shared (public) events |
| Grey Book | `server/app/misc` | Opt-in people directory: title, bio, show number, search, call/message |
| Crypto (LCN) | `server/app/crypto` | Server-side prices that move every `TickMinutes`, purchase with bank money, withdraw to bank, transfer coins by phone number, portfolio, market chart |
| Garage | framework vehicles | Vehicle list with fuel/engine/body. **Track** sets a waypoint if the car is out. **Keys** gives the nearest player keys (`Config.Garage.GiveKeys`). **Take Out** fires `Config.Garage.TakeOutEvent` (disabled if not set). |
| Government | `server/app/government` | State legislation, court docket, regional announcements and budget notices; ballots with one vote per character. Publishing is limited to `Config.Government.Editors`. |
| Guber | `server/app/guber` | Customer: pick a destination or your GPS waypoint; the fare is computed server-side. Driver: go online, receive offers, accept, confirm pickup (distance-checked), complete at drop-off (distance-checked). The customer is charged, the driver paid, the customer rates the ride, and the driver profile shows rating, rides and feedback. |
| Lemon List | existing marketplace | Text ads in configurable categories (Mechanic, Services, Food, Taxi…), search, call/message the poster, delete your own ad |
| Licenses | framework | ID card and licence list (known licences + held ones). **Show** displays it to the nearest player. |
| Weazel News | `server/app/news` | Category feed, article view, publishing for `Config.News.Jobs`, breaking news notifies everyone online, delete own or as editor |
| Gallery | existing photos | Photos / Favorites / **Places** (zone recorded for new shots), viewer with favourite, share, set as wallpaper, delete |
| Property | `server/app/property` | Your properties and keyholders, listings for sale, buy (bank), sell back (`SellBackPercent`), waypoint |
| Real Estate | `server/app/property` | All listings with search, sort (alphabetical / price / distance), range filters, zone/type/listing chips, details, buy |
| Scoot-E | `server/app/misc` | Paid, timed scooter rental. The scooter spawns next to you; you can locate it or end the ride, and it is removed when time runs out. |
| Settings | existing settings | Account name, number (copy), share contact, nearby-visibility, airplane mode, wallpaper (presets + URL), control-hint legend, brightness, size, language, ringtone, notification sound, per-app notifications |
| Socials | existing Twexa | Join screen (pick a username), All/Following feed, posts with images, likes, reposts, replies, bookmarks, view counts, thread view, notifications, search, profiles, follow, **mute/block**, **transfer ownership**, sign out (and "Continue as" to sign back in) |
| Roach | `server/app/misc` | Dark-web browser. Type an address in the bar (`name` or `name.onion`, sub-pages like `name.onion/about`) and press Enter. Pages come from `Config.Roach.Sites` or from other resources via `exports['oph3z-phone']:RegisterRoachSite(address, { title, body, hints, source })`; any other .onion address is a 404, and non-onion addresses show "Unable to connect". The ⋮ menu has Back / Forward / Reload / Home / **View Page Source** (or Ctrl+U), and Backspace goes back. In the source, .onion addresses are clickable. Configured sites show their generated source plus any `hints` (or a custom `source`); unknown addresses show a decoy full of fake leads to other dead addresses (the same for every visit, reshuffled by `DecoySeed`). Bookmarks and notes are saved per character. **Host a Site** (⋮ menu): players publish their own pages (title, text with `[[links]]`, hidden source comments). The first page on a name claims it, and only the owner can add sub-pages; limits and an optional claim fee are set in `Config.Roach.Hosting`. Admins can publish anywhere (including the home page) and edit or take down any page. A failed request now shows "Connection failed" instead of a 404. Ships with example sites `board.onion`, `board.onion/rules` and `mirror.onion`. |
| Calculator | existing | Restyled |
| Events | `server/app/events` | Anyone proposes an event (location = where you stand). It's scheduled after `VotesToSchedule` votes; host jobs schedule directly. Join/leave, waypoint, cancel, My Events. |
| Phone / Messages / Contacts (dock) | existing contacts, calls, messages, groups | One suite with Contacts · Chats · Calls · Keypad. Chats support text, photos, locations (with waypoint), live location, money requests, groups and new chats. Contacts can be created, edited, favourited and deleted. |
| Camera (dock) | existing camera | Grid overlay, and a **fullscreen mode**: the phone hides and the controls go over the live game view (click = shutter, F flip, G grid, H hide UI, Esc exit, RMB look) |
| Store (dock) | existing App Store | Unchanged |

Maps, Clock and Mail sit on a 6th row of the home grid that scrolls up (the first five rows match the reference). Set `enabled = false` in `Config.Apps` to hide them. `Config.UI.HomeStyle = 'ios'` restores the original iPhone interface and its original app screens.

### Integrating your other resources

- **Housing.** `Config.Property.OnPurchase / OnSell / OnKeyChange` are called on the server with the listing, so your housing script can grant the real interior. The resource exports `GetPropertyOwner(id)` and `HasPropertyAccess(id, citizenid)`.
- **Vehicle keys.** `Config.Garage.GiveKeys(src, target, plate, vehicle)` runs on the server. The default tries `qbx_vehiclekeys` (export `GiveKeys(target, vehicle)`, which needs the car to be out) and then `qb-vehiclekeys` (event `vehiclekeys:client:SetOwner`). Check that this matches your keys resource. Scoot-E uses `Config.ScootE.KeysEvent`.
- **Hand an app to another resource.** Add `clientEvent` or `command` to that app's entry in `Config.Apps`, or register a third-party app with the same id through `exports['oph3z-phone']:RegisterApp`.

## New NUI → server callbacks

Each `phone:np:<name>` NUI callback maps to the server callback `oph3z-phone:server:np:<name>` (bridged in `client/app/nopixel/main.lua`):

`licenses`, `licenses:show`, `garage`, `garage:track`, `garage:keys`, `garage:takeout`, `biz:list|create|get|invites|respond|invite|post|role|fire|cancelInvite|leave|edit|delete`, `crypto:home|history|buy|sell|transfer`, `cal:month|add|delete`, `gov:home|list|post|delete|ballot|vote`, `news:list|get|publish|delete`, `ev:list|create|join|vote|locate|delete`, `prop:list|buy|sell|keys|giveKey|removeKey|locate`, `guber:state|request|cancel|online|accept|decline|pickup|complete|rate|profile`, `roach:state|open|save|sites|publish|unpublish`, `gb:list|save|remove`, `scoot:state|rent|end`.

There are also client-only callbacks: `phone:np:config`, `phone:np:waypoint`, `phone:np:bridge`, `phone:np:scoot:locate`.

Socials adds `phone:x:join|resume|mute|block|relations|transfer|bookmark|bookmarks`. Bank transfers now accept an Account ID. `Wallet.Log(citizenid, tx)` lets server code add rows to the Bank history.

Client events: `oph3z-phone:client:np:guber`, `oph3z-phone:client:np:licenseShown`, `oph3z-phone:client:np:scootEnd`.

No existing event, export, item name or callback was renamed or removed.

## Security notes

- **Money.** Every money movement goes through the server (`NP.charge` / `NP.pay`, using the existing `Bank` bridge). Prices, fares and crypto amounts are computed on the server.
- **Double spending.**
  - Property purchases reserve the row before charging and refund the reservation if payment fails.
  - Crypto actions are serialised per player.
  - Guber completion is gated on the driver being near the drop-off.
- **Permissions.**
  - Business roles, editor/publisher jobs, post/ad/event ownership and vehicle ownership (by plate, from the framework table) are all checked on the server.
  - Unique keys stop duplicate votes, bookmarks, follows and mutes.
- **Distance checks** (licence showing, key giving, Guber pickup and completion) use server-side ped positions, so they need OneSync, which Qbox requires anyway.

## Rebuilding the UI

```bash
cd web
npm install
npm run dev     # browser preview with mock data at http://127.0.0.1:5173
npm run build   # writes ../build
```

The NoPixel layer lives in `web/src/np/`: the shared kit is in `np/ui` and every app is in `np/apps`. Socials is in `web/src/app/socials/`. The server helpers are in `server/np_lib.lua`.

Original project: oph3z-phone by Oph3Z. See README.md for the license and credit terms.
