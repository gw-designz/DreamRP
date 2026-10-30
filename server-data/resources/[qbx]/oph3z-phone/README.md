# oph3z-phone

A custom phone for FiveM. It works on ESX, QBCore and Qbox, and comes with a full set of apps, calls, messages, a camera, a social app and more, all built to feel like a real smartphone.

> This is a beta release. Please read the [Beta and feedback](#beta-and-feedback) part before reporting anything.

> [!IMPORTANT]
> **Join the Discord Community!**
>
> All future updates and new features will be announced in my Discord server. You can also get help, ask questions, and connect with other members of the community there.
>
> New scripts will also be shared in the server, including both **free and paid scripts** that you may find useful.
>
> **I highly recommend joining the community to stay up to date and not miss anything!**
> 
> https://discord.gg/WhP6Fn943E

## Tech stack

- Interface: React 18, Redux Toolkit, Vite, and plain CSS
- Game side: Lua
- Storage: MySQL

## Preview
### [YouTube](https://youtu.be/o3fk0IWO9GM?si=tDGjQTyXOfKsAAxP)

## Features

It scales to any screen size and has a lock screen with a live clock, the date and your notifications, a home screen with apps you can move around, a control center and a dynamic island. There is also a walk mode so you can move around while using it, and the whole interface is available in English and Turkish, with more languages coming later.

You can open the phone with a key (F1 by default), a command, or as an inventory item.

Apps included:

- **Phone** — real voice calls through pma-voice. Contacts, favorites, recents, keypad, ringtones, speaker mode, block list, FaceTime video calls.
- **Messages** — Chats. Send/request money, GIFs, voice notes, photos, videos, live location, group chats, reactions.
- **Camera** — front and back camera. Photo, video, zoom, walk while filming, records your voice.
- **Photos** — your gallery. Favorites, full-screen viewer, share to people nearby.
- **Wallet** — your bank on the phone. Balance, send money, transactions, pay bills.
- **Mail** — every player gets a real email address. Inbox, sent, attachments, system mail.
- **Maps** — live GPS map. Saved places, waypoints, share your location.
- **Clock** — alarms, timers, stopwatch. People nearby hear your alarm go off.
- **Calculator** — everyday calculator. History you can tap to reuse.
- **Settings** — wallpaper, brightness, phone size, language, ringtones, profile photo.
- **Twexa** — social media app. Post, follow, reply, repost, likes, hashtags, mentions, trending, verified badges.
- **Yellow Pages** — buy and sell in the city. Cars, houses, items, photos, prices, call or message the seller.
- **App Store** — install and uninstall apps.

This already covers all the base features you need to use a phone in roleplay, nothing important is missing. I also have a few more custom apps in mind that I will build and add to the phone over time.

## Third-party apps

Developers can build their own apps and add them to the phone without touching the main code. There is a separate starter template for that:

[oph3z-phone-app-template](https://github.com/Oph3Z1/oph3z-phone-example-app)

## Requirements

- One framework: ESX, QBCore or Qbox (older ESX and QB versions work too)
- pma-voice, for calls and voice (Voice command support will be expanded soon...)
- xsound, for ringtones, music and alarm sounds
- A MySQL resource (oxmysql, ghmattimysql or mysql-async). The phone stores everything in MySQL, so this is required
- An inventory (ox_inventory, qb-inventory, qs-inventory or codem-inventory), only if you want the phone as an item

## Installation & configuration
[Gitbook](https://oph3zdev.gitbook.io/docs/free/phone)


## Development

The interface is already built and shipped in the `build` folder, so you do not need Node.js just to run the phone. You only need it if you want to change the interface yourself. For that you need Node.js 18 or newer:

```bash
cd resources/[phone]/oph3z-phone/web
npm install
npm run build
```

This rebuilds the `build` folder at the root of the resource. Run `npm run build` again after each change you make in `web/src`.

## Beta and feedback

Right now this is a beta. I have only been able to test it with two clients on the same PC, so there are probably a few bugs I have not run into yet. If you find one, or you have an idea or a suggestion, join the Discord and let me know:

[Discord server](https://discord.gg/JBekSqrDQH)

## License

This project is free to use and modify for personal and commercial use.

You are allowed to:

* Use this phone script on your own FiveM server.
* Modify, edit, and customize the source code as you wish.
* Create and sell third-party apps, plugins, integrations, or other products that work with this phone.
* Create your own products based on modified versions of this project, as long as they contain significant original work.

You are **not allowed to**:

* Sell or redistribute the original version of this project.
* Sell this project with only minor changes, such as small bug fixes, renaming, cosmetic changes, or minimal modifications.
* Re-upload, publish, or claim this project as your own work.
* Remove the original credits or license information.
* **Publish, distribute, or sell any product, script, resource, modification, or derivative work based on this project without clearly giving credit to the original project and its creators. Credit must be provided wherever the product or project is published, distributed, or sold, including but not limited to GitHub, Tebex, Cfx.re, Discord, websites, marketplaces, and other platforms.**

The credit must clearly identify the original project and include a link to the original project repository when applicable.

The purpose of this license is to allow the community to use, improve, and build upon this project while preventing simple reselling or re-release of the original product, while ensuring that the original creators receive proper credit.

## Screenshots

<img width="310" height="642" alt="lockscreen" src="https://github.com/user-attachments/assets/464b0608-c171-4f2f-941b-9de0ebc3f2d1" />
<img width="310" height="642" alt="homescreen" src="https://github.com/user-attachments/assets/e87e950a-2884-479a-83ba-3aa44e9f6511" />
<img width="310" height="642" alt="homescreen2" src="https://github.com/user-attachments/assets/a13ae800-da7d-4cc9-8a91-4728fd7c22e5" />
<img width="310" height="642" alt="controlcenter" src="https://github.com/user-attachments/assets/c446a68f-3119-4a80-aa4a-9f8e517f8508" />
<img width="310" height="642" alt="settings" src="https://github.com/user-attachments/assets/e8acd8b4-f0a5-4328-aa2a-c3d78cc23fae" />
<img width="310" height="642" alt="5 - phones" src="https://github.com/user-attachments/assets/463a9a0a-3ce5-4926-a4ae-a9b91afeadc0" />
<img width="310" height="642" alt="6 - messages" src="https://github.com/user-attachments/assets/5fef8654-f02a-4028-864b-b81e2bb4a3da" />
<img width="310" height="642" alt="7 - camera" src="https://github.com/user-attachments/assets/ff922ee4-06de-4ec3-84cf-f86783d51fc6" />
<img width="310" height="642" alt="8 - photos" src="https://github.com/user-attachments/assets/d092b879-745e-4f1d-b850-323265119bcc" />
<img width="310" height="642" alt="9 - mail" src="https://github.com/user-attachments/assets/bf2cb5b0-d12e-4e87-9e0b-0e20b7110274" />
<img width="310" height="642" alt="10 - wallet" src="https://github.com/user-attachments/assets/95c6220b-abeb-4a0b-ba48-dd5f78dce646" />
<img width="310" height="642" alt="11 - maps" src="https://github.com/user-attachments/assets/eb60e5ab-ac41-4826-8e60-035b4d407fe1" />
<img width="310" height="642" alt="12 - clock" src="https://github.com/user-attachments/assets/924983d5-5af2-4091-ae13-27e267efbd26" />
<img width="310" height="642" alt="13 - calculator" src="https://github.com/user-attachments/assets/c1b7675d-19af-4f22-9242-5daa322effb5" />
<img width="310" height="642" alt="appstore" src="https://github.com/user-attachments/assets/797f553b-a1d1-4572-b112-8e14bc4aaab6" />
<img width="310" height="642" alt="twexa" src="https://github.com/user-attachments/assets/6b3da3b0-10da-47b1-a12d-28fa1a62e1a4" />
<img width="310" height="642" alt="yellowpages" src="https://github.com/user-attachments/assets/6fd994c0-2387-42ff-bcf2-66a0ba6f26e2" />
