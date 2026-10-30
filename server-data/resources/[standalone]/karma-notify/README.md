# 🔔 FREE - Karma Developments - Standalone Notify System

## Karma Developments

If you like this free resource, consider joining the **Karma Developments Discord** for **support, updates, announcements, and future releases**.

- **Discord:** https://discord.gg/karmadevelopments
- **Store:** https://karmadevelopments.shop

You can also check out our store for more FiveM scripts and systems from **Karma Developments**.

![Karma Developments Notify System](https://i.postimg.cc/3w2k9G1d/e9891293-e842-4d3c-a5d8-b77d481d4d2a.png)

**Karma Developments Notify System** is a lightweight standalone FiveM NUI notification resource...


Display **success, information, and error notifications** from client-side or server-side scripts with a simple export or event.

No framework dependencies. Drop it in and it just works.

---

## ✨ Features

* **Clean NUI notifications** — simple and modern notification UI
* **Multiple notification types** — supports `success`, `inform`, and `error`
* **Custom duration** — control exactly how long each notification stays visible
* **Client export** — easily trigger notifications from any client resource
* **Client event** — trigger notifications using FiveM events
* **Server-side support** — send notifications to individual players or the entire server
* **Test commands included** — quickly preview every notification type
* **Standalone** — works on QBox, ESX, qb-core or any framework

---

## 🔧 Installation

1. Drop the `karma-notify` folder into your `resources` directory
2. Add the following to your `server.cfg`:

```cfg
ensure karma-notify
```

3. Restart the server — that's it

---

## 📦 Client Export

Trigger a notification from any client-side resource:

```lua
exports['karma-notify']:Notify('Vehicle has been locked', 'success', 4000)

exports['karma-notify']:Notify('Remember to refuel your vehicle', 'inform', 4000)

exports['karma-notify']:Notify('You do not have the keys', 'error', 4000)
```

### Arguments

| Argument   | Type     | Description                                        |
| ---------- | -------- | -------------------------------------------------- |
| `message`  | `string` | Text displayed inside the notification             |
| `type`     | `string` | Notification type: `success`, `inform`, or `error` |
| `duration` | `number` | Duration in milliseconds — defaults to `4000`      |

> `sucess` is also accepted for compatibility.

---

## 🔔 Client Event

You can also trigger notifications using the client event:

```lua
TriggerEvent('karma-notify:notify', 'Vehicle has been locked', 'success', 4000)
```

This is useful when you prefer events instead of exports or need to integrate the notification system into an existing resource.

---

## 🖥️ Server-Side Usage

To send a notification from server-side code, trigger the client event for a specific player:

```lua
TriggerClientEvent('karma-notify:notify', source, 'Vehicle has been locked', 'success', 4000)
```

### Notify Every Player

Use `-1` as the target to send a notification to everyone on the server:

```lua
TriggerClientEvent('karma-notify:notify', -1, 'Server restart soon', 'inform', 5000)
```

---

## 🧪 Test Commands

The resource includes test commands for quickly previewing each notification style:

```text
/notifysuccess
/notifyinform
/notifyerror
```

You can also provide your own notification message after the command:

```text
/notifyerror You do not have the keys
```

```text
/notifysuccess Vehicle successfully stored
```

```text
/notifyinform Remember to refuel your vehicle
```

---

## 💡 Example Integration

Replace another resource's notification function with:

```lua
exports['karma-notify']:Notify('Your message here', 'success', 4000)
```

For example:

```lua
if IsPedInAnyVehicle(PlayerPedId(), false) then
    exports['karma-notify']:Notify('You are currently inside a vehicle', 'inform', 4000)
else
    exports['karma-notify']:Notify('You are not inside a vehicle', 'error', 4000)
end
```

---

## 📋 Notification Types

| Type      | Usage                                |
| --------- | ------------------------------------ |
| `success` | Successful actions and confirmations |
| `inform`  | General information and reminders    |
| `error`   | Errors, denied actions, and warnings |

---

<div align="center">
  <sub>Made with ❤️ by <b>KARMA Developments</b></sub>
</div>
