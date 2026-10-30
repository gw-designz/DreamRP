(() => {
    "use strict";

    const IS_GAME = typeof window.GetParentResourceName === "function";
    const RES = IS_GAME ? window.GetParentResourceName() : "bablo-multicharacter";

    const MONTHS = ["JAN", "FEB", "MAR", "APR", "MAY", "JUN", "JUL", "AUG", "SEP", "OCT", "NOV", "DEC"];
    const DOW = ["SU", "MO", "TU", "WE", "TH", "FR", "SA"];
    const MIN_YEAR = 1920;
    const MAX_YEAR = new Date().getFullYear() - 16;
    const NAME_RE = /^[\p{L}][\p{L}' -]{0,31}$/u;

    // map.png projection (north points left on the image; it's drawn rotated 90°).
    const MAP = { left: 8160, top: 4984, w: 12221, h: 9116 };
    const MAP_ZOOM_MIN = 0.8;
    const MAP_ZOOM_MAX = 6;

    const store = {
        get(k, d) {
            try {
                const v = localStorage.getItem("bmc_" + k);
                return v === null ? d : JSON.parse(v);
            } catch { return d; }
        },
        set(k, v) {
            try { localStorage.setItem("bmc_" + k, JSON.stringify(v)); } catch { /* storage unavailable */ }
        },
    };

    const S = {
        visible: false,
        fading: false,
        view: "title",
        renderedView: null,
        processing: false,
        chars: [],
        spawns: [],
        tr: {},
        cfg: {
            branding: {},
            currency: { pattern: "$ %s", thousands: "," },
            enableSpawnMenu: true,
            allowDeletion: true,
        },
        menuIdx: 1,
        focus: 0,
        detail: null,
        detailIdx: 0,
        spawnIdx: 0,
        optIdx: 0,
        create: null,
        edit: null,
        del: null,
        modal: null,
        busy: false,
        pickLock: false,
        prefs: {
            sound: store.get("sound", true),
            skipStart: store.get("skipStart", false),
            reducedMotion: store.get("reducedMotion", false),
            chooseStart: store.get("chooseStart", true),
        },
        lastPlayed: store.get("lastPlayed", null),
    };

    // Overlays shown in the world after the selector is destroyed.
    const O = { welcome: null, timer: null, tutorial: null };

    const app = document.getElementById("app");
    const overlay = document.getElementById("overlay");

    // ─── Helpers ────────────────────────────────────────────────────────────

    function post(name, data) {
        if (!IS_GAME) {
            console.log("[nui]", name, data || {});
            return Promise.resolve({ success: true, data: name === "UPDATE_IDENTITY" ? mockUpdate(data) : {} });
        }
        return fetch(`https://${RES}/${name}`, {
            method: "POST",
            headers: { "Content-Type": "application/json; charset=UTF-8" },
            body: JSON.stringify(data || {}),
        }).then((r) => r.json()).catch(() => ({ success: false }));
    }

    function t(key, fallback, ...args) {
        let s = S.tr[key] ?? fallback ?? key;
        for (const a of args) s = s.replace("%s", a);
        return s;
    }

    function esc(v) {
        return String(v ?? "").replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]));
    }

    function money(n) {
        const c = S.cfg.currency || {};
        const digits = Math.floor(Number(n) || 0).toString().replace(/\B(?=(\d{3})+(?!\d))/g, c.thousands ?? ",");
        return (c.pattern || "$ %s").replace("%s", digits);
    }

    function playtime(m) {
        m = Math.max(0, Math.floor(Number(m) || 0));
        return `${Math.floor(m / 60)}H ${String(m % 60).padStart(2, "0")}M`;
    }

    function wrap(i, n) { return n ? (i + n) % n : 0; }

    function parseDob(s) {
        const m = /^(\d{4})-(\d{2})-(\d{2})/.exec(String(s || ""));
        return m ? { year: +m[1], month: +m[2], day: +m[3] } : null;
    }

    function dobIso(d) { return `${d.year}-${String(d.month).padStart(2, "0")}-${String(d.day).padStart(2, "0")}`; }

    // UI feedback via GTA's native frontend sounds (played by Lua).
    // kind: move | side | select | back | error
    function blip(kind) {
        if (!S.prefs.sound) return;
        post("PLAY_SOUND", { kind });
    }

    const KEY = {
        move: `<span class="key">◀▶</span>`,
        updown: `<span class="key">▲▼</span>`,
        enter: `<span class="key">↵</span>`,
        esc: `<span class="key">ESC</span>`,
    };

    function hints(list) {
        const parts = list.map(([k, label]) => `${k} <span>${esc(label)}</span>`);
        return `<div class="hints">${parts.join('<span class="sep">/</span>')}</div>`;
    }

    const H_MOVE = () => [KEY.move, t("KEY_MOVE", "Move")];
    const H_NAV = () => [KEY.updown, t("KEY_NAVIGATE", "Navigate")];
    const H_SELECT = () => [KEY.enter, t("KEY_SELECT", "Select")];
    const H_BACK = () => [KEY.esc, t("KEY_BACK", "Back")];
    const H_EXIT = () => [KEY.esc, t("KEY_EXIT", "Exit")];

    function ownedChars() { return S.chars.filter((c) => c && c.id); }

    function continueChar() {
        const owned = ownedChars();
        return owned.find((c) => c.id === S.lastPlayed) || owned[0] || null;
    }

    function firstName(c) { return String(c?.name || "").split(" ")[0]; }

    // ─── View switching ─────────────────────────────────────────────────────

    function setView(view) {
        S.view = view;
        S.pickLock = false;
        // Ped hover/click in Lua is only live on the character-select view.
        post("BLOCK_RAYCAST", { blocked: view !== "chars" });
        if (view === "chars") post("FOCUS_SLOT", { slot: S.focus + 1 });
        render();
    }

    function viewKey() {
        return S.view + (S.view === "create" ? S.create?.step : "");
    }

    function render() {
        app.classList.toggle("visible", S.visible);
        app.classList.toggle("fading", S.fading);
        document.body.classList.toggle("reduced-motion", !!S.prefs.reducedMotion);
        document.documentElement.style.setProperty("--accent", S.cfg.theme?.accent || "#3fdcf2");
        document.documentElement.style.setProperty("--accent-fg", S.cfg.theme?.accentFg || "#0b0b0b");

        const views = {
            title: viewTitle,
            menu: viewMenu,
            options: viewMenu,
            chars: viewChars,
            detail: viewDetail,
            edit: viewEdit,
            delete: viewDelete,
            spawn: viewSpawn,
            create: viewCreate,
            transition: () => "",
        };
        let html = (views[S.view] || views.transition)();
        if (S.processing) html += `<div class="processing heading"><div class="spinner"></div>${esc(t("PROCESSING", "Processing..."))}</div>`;
        if (S.modal) html += viewModal();
        app.innerHTML = html;

        // Re-renders of the same view shouldn't replay entrance animations.
        const key = viewKey();
        if (S.renderedView === key) {
            app.querySelectorAll(".screen, .sheet-wrap, .column, .spawn-panel").forEach((el) => { el.style.animation = "none"; });
        }
        S.renderedView = key;
        if (S.view === "spawn") applyMap();
    }

    // Toggle .focus inside a group without rebuilding the DOM, so CSS
    // transitions (sliding frame, sheet highlight) animate smoothly.
    function syncFocus(group, idx) {
        app.querySelectorAll(`[data-group="${group}"]`).forEach((el) => {
            el.classList.toggle("focus", Number(el.dataset.idx) === idx);
        });
        if (group === "menu") {
            app.querySelectorAll(".frame-wrap").forEach((el) => { el.dataset.slot = idx; });
            const cap = app.querySelector(".frame-wrap:not(.reflection) .frame-caption");
            if (cap) {
                cap.style.left = CAPTION_LEFT[idx];
                cap.textContent = menuItems()[idx].caption;
            }
        }
    }

    // ─── Title ──────────────────────────────────────────────────────────────

    function viewTitle() {
        const b = S.cfg.branding || {};
        return `
        <div class="screen title-screen" data-act="start">
            <div class="title-bg" style="background-image:url('${esc(b.background || "img/bg.png")}')"></div>
            <div class="title-vignette"></div>
            <div class="title-name heading">${esc(b.title || "YOUR CITY")}</div>
            <div class="title-sub heading">${esc(b.subtitle || "ROLEPLAY")}</div>
            <div class="title-press heading">${esc(t("PRESS", "Press"))} ${KEY.enter} ${esc(t("TO_START", "to start"))}</div>
        </div>`;
    }

    // ─── Main menu (+ options sheet on top of it) ───────────────────────────

    const CAPTION_LEFT = ["5.6vw", "33.1vw", "68.6vw"];

    function menuItems() {
        const p = S.cfg.branding?.panels || {};
        const cc = continueChar();
        return [
            {
                label: cc ? t("MENU_CONTINUE_AS", "Continue as %s", cc.name) : t("MENU_NEW_STORY", "Start your story"),
                caption: p.continue?.caption || "START YOUR JOURNEY IN LOS SANTOS",
                image: p.continue?.image || "img/bg.png",
            },
            {
                label: t("MENU_CHARACTERS", "Characters"),
                caption: p.characters?.caption || "CHOOSE WHO YOU WANT TO BE",
                image: p.characters?.image || "img/bg.png",
            },
            {
                label: t("MENU_OPTIONS", "Options"),
                caption: p.options?.caption || "ADJUST YOUR GAME SETTINGS",
                image: p.options?.image || "img/bg.png",
            },
        ];
    }

    function frame(items, reflection) {
        const imgs = items.map((it, i) => `<div class="frame-img i${i}" style="background-image:url('${esc(it.image)}')"></div>`).join("");
        return `
            <div class="frame-wrap ${reflection ? "reflection" : ""}" data-slot="${S.menuIdx}">
                <div class="frame-border"></div>
                <div class="frame-inner">${imgs}</div>
                <div class="frame-caption heading" style="left:${CAPTION_LEFT[S.menuIdx]}">${esc(items[S.menuIdx].caption)}</div>
            </div>`;
    }

    function viewMenu() {
        const items = menuItems();
        const buttons = items.map((it, i) => `
            <button class="menu-btn heading ${i === S.menuIdx ? "focus" : ""}" data-group="menu" data-idx="${i}" data-hover="menu:${i}" data-act="menu:${i}">${esc(it.label)}</button>`).join("");
        const inOptions = S.view === "options";
        return `
        <div class="screen menu-screen">
            <div class="menu-horizon"></div>
            ${frame(items, false)}
            ${frame(items, true)}
            <div class="menu-buttons">${buttons}</div>
            ${inOptions ? viewOptionsSheet() : ""}
            ${hints([H_MOVE(), H_SELECT(), inOptions ? H_BACK() : H_EXIT()])}
        </div>`;
    }

    function menuActivate(i) {
        blip("select");
        if (i === 0) {
            const cc = continueChar();
            if (!cc) {
                const empty = S.chars.findIndex((c) => c && !c.id && !c.locked);
                if (empty >= 0) S.focus = empty;
                return processThen(() => setView("chars"));
            }
            S.processing = true;
            render();
            return playCharacter(cc, { coords: cc.lastLocation || null });
        }
        if (i === 1) return processThen(() => setView("chars"));
        S.optIdx = 0;
        setView("options");
    }

    // Brief "PROCESSING..." beat before cutting to the lineup, like the reference.
    function processThen(fn) {
        S.processing = true;
        render();
        setTimeout(() => {
            S.processing = false;
            fn();
        }, S.prefs.reducedMotion ? 0 : 700);
    }

    function optionItems() {
        const items = [
            { key: "sound", label: t("MENU_SOUNDS", "Menu sounds") },
            { key: "skipStart", label: t("SKIP_START_SCREEN", "Skip start screen") },
            { key: "reducedMotion", label: t("REDUCED_MOTION", "Reduced motion") },
        ];
        if (S.cfg.enableSpawnMenu !== false) items.push({ key: "chooseStart", label: t("CHOOSE_WHERE_TO_START", "Choose where to start") });
        items.push({ key: "game", label: t("GAME_SETTINGS", "Game settings"), action: true });
        items.push({ key: "back", label: t("BACK", "Back"), action: true });
        return items;
    }

    function viewOptionsSheet() {
        const items = optionItems().map((it, i) => {
            const on = S.prefs[it.key];
            const focus = S.optIdx === i;
            const val = it.action ? "" : focus ? `‹ ${on ? "ON" : "OFF"} ›` : on ? "ON" : "OFF";
            return `
            <button class="sheet-item ${focus ? "focus" : ""}" style="--i:${i}" data-group="opt" data-idx="${i}" data-hover="opt:${i}" data-act="opt:${i}">
                <span>${esc(it.label)}</span><span class="val">${esc(val)}</span>
            </button>`;
        }).join("");
        return `
        <div class="sheet-wrap">
            <div class="sheet-edge-outer"></div><div class="sheet-edge"></div>
            <div class="sheet paper"></div>
            <div class="sheet-title heading">${esc(t("OPTIONS_TITLE", "Options"))}</div>
            <div class="sheet-rule"></div>
            <div class="sheet-menu">${items}</div>
        </div>`;
    }

    function optionActivate(i, dir) {
        const it = optionItems()[i];
        if (!it || (dir && it.action)) return; // ◀▶ only flips toggles
        if (it.key === "back") { blip("back"); return setView("menu"); }
        if (it.key === "game") {
            blip("select");
            return post("OPEN_GAME_SETTINGS");
        }
        S.prefs[it.key] = !S.prefs[it.key];
        store.set(it.key, S.prefs[it.key]);
        blip(dir ? "side" : "select");
        render();
    }

    // ─── Character lineup (live peds) ───────────────────────────────────────

    function viewChars() {
        const c = S.chars[S.focus];
        let name = "";
        let btn = "";
        if (c?.locked) { name = t("PREMIUM_SLOT", "Premium slot"); btn = t("VIEW_SLOT", "View slot"); }
        else if (c?.id) { name = c.name; btn = t("SELECT_CHARACTER_BTN", "Select character"); }
        else if (c) { name = t("NEW_CHARACTER", "New character"); btn = t("CREATE", "Create"); }
        let meta = "";
        if (c && c.id) meta = [c.jobLabel || t("JOB_FALLBACK", "Citizen"), c.playtimeMinutes != null ? playtime(c.playtimeMinutes) : null].filter(Boolean).join("  ·  ");
        else if (c && c.locked) meta = t("PREMIUM_SLOT_HINT", "Unlock with a staff member or via the store");
        return `
        <div class="screen chars-screen">
            <div class="top-band"><h1 class="heading">${esc(t("SELECT_CHARACTER_TITLE", "Select character"))}</h1></div>
            <div class="chars-bar">
                <div class="meta">${esc(meta)}</div>
                <div class="name">${esc(name)}</div>
                <div class="row">
                    <button class="arrow" data-act="slot:-1">❮</button>
                    <button class="select heading" data-act="pick">${KEY.enter} ${esc(btn)}</button>
                    <button class="arrow" data-act="slot:1">❯</button>
                </div>
            </div>
            ${hints([H_MOVE(), H_SELECT(), H_BACK()])}
        </div>`;
    }

    function moveSlot(delta) {
        if (!S.chars.length) return;
        S.focus = wrap(S.focus + delta, S.chars.length);
        blip("side");
        post("FOCUS_SLOT", { slot: S.focus + 1 });
        render();
    }

    function pickSlot() {
        if (S.pickLock || !S.chars[S.focus]) return;
        S.pickLock = true;
        setTimeout(() => { S.pickLock = false; }, 800);
        blip("select");
        post("PICK_SLOT", { slot: S.focus + 1 });
    }

    // ─── Character detail ───────────────────────────────────────────────────

    function detailItems() {
        const items = [
            { key: "begin", label: t("BEGIN_STORY", "Begin story") },
            { key: "edit", label: t("EDIT_IDENTITY", "Edit identity") },
        ];
        if (S.cfg.allowDeletion !== false) items.push({ key: "delete", label: t("DELETE", "Delete"), danger: true });
        items.push({ key: "back", label: t("BACK", "Back") });
        return items;
    }

    function detailSub(c) {
        return [
            c.jobLabel ? (c.jobGrade ? `${c.jobLabel} · ${c.jobGrade}` : c.jobLabel) : null,
            c.cash != null ? `${money(c.cash)} ${t("CASH", "Cash")}` : null,
            c.bank != null ? `${money(c.bank)} ${t("BANK", "Bank")}` : null,
            c.playtimeMinutes != null ? playtime(c.playtimeMinutes) : null,
        ].filter(Boolean).join("   |   ");
    }

    function viewDetail() {
        const c = S.detail;
        if (!c) return "";
        const items = detailItems().map((it, i) => `
            <button class="sheet-item ${it.danger ? "danger" : ""} ${S.detailIdx === i ? "focus" : ""}" style="--i:${i}" data-group="detail" data-idx="${i}" data-hover="detail:${i}" data-act="detail:${i}"><span>${esc(it.label)}</span></button>`).join("");
        return `
        <div class="screen detail-screen">
            <div class="sheet-wrap">
                <div class="sheet-edge-outer"></div><div class="sheet-edge"></div>
                <div class="sheet paper"></div>
                <div class="sheet-title heading">${esc(c.name)}</div>
                <div class="sheet-sub">${esc(detailSub(c))}</div>
                <div class="sheet-rule"></div>
                <div class="sheet-menu">${items}</div>
            </div>
            ${hints([H_NAV(), H_SELECT(), H_BACK()])}
        </div>`;
    }

    function detailActivate(i) {
        const it = detailItems()[i];
        if (!it || !S.detail) return;
        if (it.key === "begin") {
            blip("select");
            if (S.cfg.enableSpawnMenu === false || !S.prefs.chooseStart) {
                return playCharacter(S.detail, { coords: S.detail.lastLocation || null });
            }
            S.spawnIdx = 0;
            S.map = null;
            return setView("spawn");
        }
        if (it.key === "edit") {
            blip("select");
            const [first, ...rest] = String(S.detail.name || "").split(" ");
            S.edit = newForm({ first, last: rest.join(" "), dob: parseDob(S.detail.dob) });
            return setView("edit");
        }
        if (it.key === "delete") {
            blip("select");
            S.del = { text: "" };
            return setView("delete");
        }
        detailBack();
    }

    function detailBack() {
        blip("back");
        setView("transition");
        post("UNSELECT_CHARACTER");
    }

    function switchCharacter(delta) {
        const owned = ownedChars();
        if (owned.length < 2 || !S.detail) return;
        const pos = owned.findIndex((o) => o.id === S.detail.id);
        const next = owned[wrap(pos + delta, owned.length)];
        S.detail = next;
        S.focus = S.chars.indexOf(next);
        blip("side");
        post("FOCUS_SLOT", { slot: S.focus + 1 });
        post("SWITCH_CHARACTER", { id: next.id });
        render();
    }

    function playCharacter(c, spawn) {
        if (S.busy) return;
        S.busy = true;
        S.lastPlayed = c.id;
        store.set("lastPlayed", c.id);
        post("SELECT_CHARACTER", { id: c.id, spawn }).then((res) => {
            if (!res || res.success === false) { S.busy = false; S.processing = false; render(); }
        });
    }

    // ─── Shared identity form (create + edit) ───────────────────────────────

    function newForm(init) {
        return Object.assign({ first: "", last: "", dob: null, picker: null, err: "", invalid: {} }, init || {});
    }

    function form() { return S.view === "edit" ? S.edit : S.create; }

    function dobLabel(d) {
        return d ? `${String(d.month).padStart(2, "0")}-${String(d.day).padStart(2, "0")}-${d.year}` : t("SELECT_DOB", "Select date of birth");
    }

    function viewPicker(f) {
        const p = f.picker;
        if (!p) return "";
        let head, grid;
        if (p.mode === "years") {
            const start = p.pageStart;
            head = `<button class="nav" data-act="pk:yearsPage:-12">❮</button><button class="ttl" disabled>${start} – ${start + 11}</button><button class="nav" data-act="pk:yearsPage:12">❯</button>`;
            const cells = [];
            for (let y = start; y < start + 12; y++) {
                const dim = y < MIN_YEAR || y > MAX_YEAR;
                cells.push(`<button class="cell ${dim ? "dim" : ""} ${y === p.year ? "active" : ""}" data-act="pk:year:${y}">${y}</button>`);
            }
            grid = `<div class="grid years">${cells.join("")}</div>`;
        } else if (p.mode === "days") {
            head = `<button class="nav" data-act="pk:month:-1">❮</button><button class="ttl" data-act="pk:mode:months">${MONTHS[p.month - 1]} ${p.year}</button><button class="nav" data-act="pk:month:1">❯</button>`;
            const first = new Date(p.year, p.month - 1, 1).getDay();
            const count = new Date(p.year, p.month, 0).getDate();
            const sel = f.dob;
            const cells = DOW.map((d) => `<div class="dow">${d}</div>`);
            for (let i = 0; i < first; i++) cells.push("<div></div>");
            for (let d = 1; d <= count; d++) {
                const active = sel && sel.year === p.year && sel.month === p.month && sel.day === d;
                cells.push(`<button class="cell ${active ? "active" : ""}" data-act="pk:day:${d}">${d}</button>`);
            }
            grid = `<div class="grid days">${cells.join("")}</div>`;
        } else {
            head = `<button class="nav" data-act="pk:year:${p.year - 1}">❮</button><button class="ttl" data-act="pk:mode:years">${p.year}</button><button class="nav" data-act="pk:year:${p.year + 1}">❯</button>`;
            const sel = f.dob;
            grid = `<div class="grid months">${MONTHS.map((m, i) => `<button class="cell ${sel && sel.year === p.year && sel.month === i + 1 ? "active" : ""}" data-act="pk:pickMonth:${i + 1}">${m}</button>`).join("")}</div>`;
        }
        return `<div class="picker" data-act="noop"><div class="head">${head}</div>${grid}</div>`;
    }

    function identityForm(f, title, lead, confirmAct, cancelAct) {
        const input = (id, labelKey, labelFb, phKey, phFb, value) => `
            <div class="field">
                <label>${esc(t(labelKey, labelFb))}</label>
                <div class="input ${f.invalid[id] ? "invalid" : ""}">
                    <input id="f-${id}" data-field="${id}" maxlength="32" spellcheck="false" autocomplete="off" placeholder="${esc(t(phKey, phFb))}" value="${esc(value)}" />
                    <span class="count" data-count="${id}">${value.length}/32</span>
                </div>
            </div>`;
        return `
        <div class="screen column-screen">
            <div class="column paper">
                <h2 class="heading">${esc(title)}</h2>
                <div class="lead">${esc(lead)}</div>
                ${input("first", "FIRST_NAME", "First name", "FIRST_NAME_PLACEHOLDER", "Enter First Name", f.first)}
                ${input("last", "LAST_NAME", "Last name", "LAST_NAME_PLACEHOLDER", "Enter Last Name", f.last)}
                <div class="field">
                    <label>${esc(t("DATE_OF_BIRTH", "Date of birth"))}</label>
                    <button class="dob-btn ${f.invalid.dob ? "invalid" : ""}" data-act="pk:toggle">${esc(dobLabel(f.dob))}</button>
                    ${viewPicker(f)}
                </div>
                <div class="error">${esc(f.err)}</div>
                <div class="actions">
                    <button class="btn" data-act="${confirmAct}" ${S.busy ? "disabled" : ""}>${esc(t("CONFIRM", "Confirm"))}</button>
                    <button class="btn" data-act="${cancelAct}">${esc(t("CANCEL", "Cancel"))}</button>
                </div>
            </div>
            ${hints([H_SELECT(), H_BACK()])}
        </div>`;
    }

    function pickerAct(cmd, arg) {
        const f = form();
        if (!f) return;
        const v = Number(arg);
        if (cmd === "toggle") {
            f.picker = f.picker ? null : { mode: f.dob ? "days" : "months", year: f.dob?.year || Math.min(1995, MAX_YEAR), month: f.dob?.month || 1 };
        } else if (cmd === "mode") {
            f.picker.mode = arg;
            if (arg === "years") f.picker.pageStart = f.picker.year - (f.picker.year % 12);
        } else if (cmd === "yearsPage") {
            f.picker.pageStart += v;
        } else if (cmd === "year") {
            f.picker.year = Math.max(MIN_YEAR, Math.min(MAX_YEAR, v));
            if (f.picker.mode === "years") f.picker.mode = "months";
        } else if (cmd === "pickMonth") {
            f.picker.month = v;
            f.picker.mode = "days";
        } else if (cmd === "month") {
            let m = f.picker.month + v;
            let y = f.picker.year;
            if (m < 1) { m = 12; y--; }
            if (m > 12) { m = 1; y++; }
            if (y < MIN_YEAR || y > MAX_YEAR) return;
            f.picker.month = m;
            f.picker.year = y;
        } else if (cmd === "day") {
            f.dob = { year: f.picker.year, month: f.picker.month, day: v };
            f.invalid.dob = false;
            f.picker = null;
        }
        blip("move");
        render();
    }

    // Returns true when the form is valid; otherwise flags fields and re-renders.
    function validateForm(f) {
        f.first = f.first.trim();
        f.last = f.last.trim();
        f.invalid = {
            first: !NAME_RE.test(f.first) || f.first.length < 2,
            last: !NAME_RE.test(f.last) || f.last.length < 2,
            dob: !f.dob,
        };
        if (f.invalid.first || f.invalid.last) f.err = t("INVALID_NAME", "Names need 2–32 letters");
        else if (f.invalid.dob) f.err = t("INVALID_DOB", "Select a date of birth");
        else f.err = "";
        if (f.err) { blip("error"); render(); return false; }
        return true;
    }

    // ─── Edit identity / delete ─────────────────────────────────────────────

    function viewEdit() {
        return identityForm(S.edit, t("EDIT_IDENTITY", "Edit identity"), t("EDIT_IDENTITY_SUB", "Change your character's name and date of birth."), "editConfirm", "editCancel");
    }

    function editConfirm() {
        const f = S.edit;
        if (S.busy || !validateForm(f)) return;
        S.busy = true;
        blip("select");
        render();
        post("UPDATE_IDENTITY", { id: S.detail.id, firstName: f.first, lastName: f.last, dob: dobIso(f.dob) }).then((res) => {
            S.busy = false;
            if (res && res.success && res.data && res.data.id) {
                S.detail = res.data;
                S.detailIdx = 1;
                setView("detail");
            } else {
                f.err = t("EDIT_FAILED", "Could not save identity");
                render();
            }
        });
    }

    function viewDelete() {
        const name = S.detail?.name || "";
        const ok = S.del.text.trim().toLowerCase() === name.trim().toLowerCase();
        return `
        <div class="screen column-screen">
            <div class="column paper">
                <h2 class="heading">${esc(t("DELETE_TITLE", "Delete character"))}</h2>
                <div class="lead">${esc(t("DELETE_WARN_NAMED", "This will permanently delete %s. This cannot be undone.", name))}</div>
                <div class="field">
                    <label>${esc(t("DELETE_TYPE_NAME", "Type the character name to confirm"))}</label>
                    <div class="input dark">
                        <input id="f-del" data-field="del" maxlength="64" spellcheck="false" autocomplete="off" placeholder="${esc(name)}" value="${esc(S.del.text)}" />
                    </div>
                </div>
                <div class="actions">
                    <button class="btn" data-act="deleteConfirm" ${ok ? "" : "disabled"}>${esc(t("DELETE", "Delete"))}</button>
                    <button class="btn" data-act="deleteCancel">${esc(t("CANCEL", "Cancel"))}</button>
                </div>
            </div>
            ${hints([H_SELECT(), H_BACK()])}
        </div>`;
    }

    function deleteConfirm() {
        const name = S.detail?.name || "";
        if (S.del.text.trim().toLowerCase() !== name.trim().toLowerCase()) return;
        blip("select");
        post("DELETE_CHARACTER", { id: S.detail.id });
        if (S.lastPlayed === S.detail.id) { S.lastPlayed = null; store.set("lastPlayed", null); }
        setView("transition");
    }

    // ─── Spawn selection (full-screen map) ──────────────────────────────────

    const PIN_ICONS = {
        pin: `<circle cx="12" cy="11.5" r="3.2" fill="currentColor"/>`,
        last: `<circle cx="12" cy="11.5" r="5.2" fill="none" stroke="currentColor" stroke-width="1.6"/><path d="M12 5.2v3M12 14.8v3M5.7 11.5h3M15.3 11.5h3" stroke="currentColor" stroke-width="1.6"/>`,
        house: `<path d="M7 12l5-4.5 5 4.5v4.5h-3.2v-3h-3.6v3H7z" fill="currentColor"/>`,
        parking: `<text x="12" y="15.6" text-anchor="middle" font-size="10" font-weight="800" font-family="Arial" fill="currentColor">P</text>`,
        plane: `<path d="M12 6.5l1 4.2 4.5 2v1.2l-4.5-1-.4 3 1.4 1v.9L12 17.2l-2 .6v-.9l1.4-1-.4-3-4.5 1v-1.2l4.5-2z" fill="currentColor"/>`,
        shield: `<path d="M12 6.5l4.6 1.8v3.4c0 2.8-2 4.6-4.6 5.6-2.6-1-4.6-2.8-4.6-5.6V8.3z" fill="currentColor"/>`,
        heart: `<path d="M12 16.8s-4.8-2.8-4.8-6a2.5 2.5 0 014.8-1 2.5 2.5 0 014.8 1c0 3.2-4.8 6-4.8 6z" fill="currentColor"/>`,
    };

    function spawnOptions() {
        const c = S.detail;
        const list = [];
        if (c?.lastLocation) {
            list.push({
                label: t("LAST_LOCATION", "Last location"),
                sub: t("LAST_SEEN_LOCATION", "Last seen location"),
                desc: t("LAST_LOCATION_DESC", "Just a bad dream or did you really decide to fall asleep there? Either way, you're right back into whatever you were doing before passing out."),
                coords: c.lastLocation,
                kind: "last",
            });
        }
        for (const h of c?.houses || []) {
            list.push({ label: h.label || h.name, sub: t("YOUR_HOUSE_TAG", "Your house"), desc: t("HOUSE_DESC", "Home sweet home. Wake up in your own bed."), coords: h.coords, house: h, kind: "house" });
        }
        for (const p of S.spawns || []) {
            if (p.jobs?.length && !(c && p.jobs.includes(c.job))) continue;
            list.push({
                label: p.label,
                sub: p.jobs?.length ? t("JOB_LOCATION_TAG", "Job location") : t("PUBLIC_LOCATION_TAG", "Public location"),
                desc: p.description || "",
                image: p.image,
                coords: p.coords,
                kind: PIN_ICONS[p.icon] ? p.icon : "pin",
            });
        }
        return list;
    }

    function mapPos(co) {
        return { x: ((MAP.left - co.y) / MAP.w) * 100, y: ((MAP.top - co.x) / MAP.h) * 100 };
    }

    function pinSvg(kind, focus) {
        const fill = focus || kind === "last" ? "#f2b632" : kind === "house" || kind === "parking" || kind === "plane" ? "#3c9be0" : "#ffffff";
        const ink = fill === "#ffffff" ? "#111" : "#111";
        return `<svg viewBox="0 0 24 32"><path d="M12 0C5.4 0 0 5.2 0 11.7 0 20.5 12 32 12 32s12-11.5 12-20.3C24 5.2 18.6 0 12 0z" fill="${fill}"/><circle cx="12" cy="11.5" r="8.3" fill="${fill}" stroke="rgba(0,0,0,.18)" stroke-width="1"/><g style="color:${ink}">${PIN_ICONS[kind] || PIN_ICONS.pin}</g></svg>`;
    }

    function viewSpawn() {
        const opts = spawnOptions();
        const sel = opts[S.spawnIdx] || {};
        const pins = opts.map((o, i) => {
            return `<div class="pin ${S.spawnIdx === i ? "focus" : ""}" data-idx="${i}" data-act="spawn:${i}" title="${esc(o.label)}">${pinSvg(o.kind, S.spawnIdx === i)}</div>`;
        }).join("");
        return `
        <div class="screen spawn-screen">
            <div class="map-viewport" id="map-viewport">
                <div class="map-layer"><div class="map-world" id="map-world"><img src="map.png" alt="" draggable="false" /></div></div>
                <div class="pin-layer">${pins}</div>
            </div>
            <div class="spawn-title heading">${esc(t("SELECT_SPAWN_LOCATION", "Select a spawn location"))}</div>
            <div class="map-help">${esc(t("MAP_HELP", "Drag to move · Scroll to zoom · Double-click a pin to spawn"))}</div>
            <div class="spawn-panel">
                <div class="s-head"><div class="s-title heading">${esc(sel.label || "")}</div><div class="s-sub">${esc(sel.sub || "")}</div></div>
                <div class="s-img" ${sel.image ? `style="background-image:url('${esc(sel.image)}')"` : ""}></div>
                <div class="s-label">${esc(sel.label || "")}</div>
                <div class="s-desc">${esc(sel.desc || "")}</div>
            </div>
            <button class="btn cta spawn-go" data-act="spawnGo" ${S.busy ? "disabled" : ""}>${KEY.enter} ${esc(S.busy ? t("SPAWNING", "Spawning…") : t("SPAWN_AT_LOCATION", "Spawn at location"))}</button>
            ${hints([H_NAV(), [KEY.enter, t("SPAWN", "Spawn")], H_BACK()])}
        </div>`;
    }

    // Pan/zoom state for the spawn map, in screen pixels. The map is shown
    // north-up (map.png rotated 90° clockwise), W×H is its on-screen size at
    // zoom 1, and (x, y) is its top-left corner inside the viewport.
    // Reset each time the spawn screen opens; no transitions anywhere.
    function fitMap(vp) {
        const r = vp.getBoundingClientRect();
        const H = r.height * 0.92;
        const W = (H * MAP.h) / MAP.w;
        // Centre in the area left of the info card (which covers ~27vw).
        const freeW = r.width * 0.73;
        S.map = { W, H, z: 1, x: (freeW - W) / 2, y: (r.height - H) / 2 };
    }

    // Keep at least part of the map on screen while panning/zooming.
    function clampMap(vp) {
        const r = vp.getBoundingClientRect();
        const m = S.map;
        const w = m.W * m.z, h = m.H * m.z;
        m.x = Math.min(r.width * 0.6, Math.max(r.width * 0.4 - w, m.x));
        m.y = Math.min(r.height * 0.6, Math.max(r.height * 0.4 - h, m.y));
    }

    function applyMap() {
        const vp = document.getElementById("map-viewport");
        const world = document.getElementById("map-world");
        if (!vp || !world) return;
        if (!S.map) fitMap(vp);
        const m = S.map;
        world.style.width = `${m.W}px`;
        world.style.height = `${m.H}px`;
        world.style.transform = `translate(${m.x}px, ${m.y}px) scale(${m.z})`;
        const img = world.firstElementChild;
        // Rotate the landscape image into the portrait frame around its centre.
        Object.assign(img.style, { width: `${m.H}px`, height: `${m.W}px`, left: `${(m.W - m.H) / 2}px`, top: `${(m.H - m.W) / 2}px` });

        const opts = spawnOptions();
        vp.querySelectorAll(".pin").forEach((pin) => {
            const o = opts[Number(pin.dataset.idx)];
            if (!o) return;
            const p = mapPos(o.coords);
            // A 90° clockwise turn maps image (u, v) to frame (1 - v, u).
            pin.style.left = `${m.x + (1 - p.y / 100) * m.W * m.z}px`;
            pin.style.top = `${m.y + (p.x / 100) * m.H * m.z}px`;
        });
    }

    function zoomMap(vp, factor, cx, cy) {
        const m = S.map;
        const z = Math.min(MAP_ZOOM_MAX, Math.max(MAP_ZOOM_MIN, m.z * factor));
        // Keep the point under the cursor fixed while zooming.
        m.x = cx - (cx - m.x) * (z / m.z);
        m.y = cy - (cy - m.y) * (z / m.z);
        m.z = z;
        clampMap(vp);
        applyMap();
    }

    function spawnSelect(i) {
        const n = spawnOptions().length;
        if (!n) return;
        const next = wrap(i, n);
        if (next === S.spawnIdx) return;
        S.spawnIdx = next;
        blip("move");
        render(); // keeps the current pan/zoom (S.map)
    }

    function spawnGo() {
        const o = spawnOptions()[S.spawnIdx];
        if (!o || !S.detail) return;
        blip("select");
        playCharacter(S.detail, { coords: o.coords, house: o.house });
        render();
    }

    // ─── Create: body → identity → character info ───────────────────────────

    function viewCreate() {
        const c = S.create;
        if (c.step === "body") return viewBody(c);
        if (c.step === "info") return viewInfo(c);
        return identityForm(c, t("IDENTITY_TITLE", "Identity creation"), t("IDENTITY_SUB", "Enter your character's identity details in order to proceed."), "identityConfirm", "identityCancel");
    }

    function viewBody(c) {
        const opt = (g, side, label) => `
            <button class="body-opt ${side} ${c.gender === g ? "focus" : ""}" data-group="body" data-idx="${g === "Male" ? 0 : 1}" data-act="gender:${g}">
                ${side === "left" ? `<span class="chev">❮</span>` : ""}
                <span class="pill heading">${KEY.enter}<span class="slash">/</span>${esc(label)}</span>
                ${side === "right" ? `<span class="chev">❯</span>` : ""}
            </button>`;
        return `
        <div class="screen body-screen">
            <div class="top-band"><h1 class="heading">${esc(t("BODY_SELECTION", "Body selection"))}</h1></div>
            ${opt("Male", "left", t("TYPE_A", "Type A"))}
            ${opt("Female", "right", t("TYPE_B", "Type B"))}
            ${hints([H_MOVE(), H_SELECT(), H_BACK()])}
        </div>`;
    }

    function setGender(g) {
        const c = S.create;
        if (c.gender === g) return;
        c.gender = g;
        blip("side");
        post("PREVIEW_BODY", { gender: g });
        syncFocus("body", g === "Male" ? 0 : 1);
    }

    function identityConfirm() {
        const c = S.create;
        if (!validateForm(c)) return;
        blip("select");
        c.step = "info";
        c.infoIdx = c.tutorial ? 0 : 1;
        render();
    }

    function viewInfo(c) {
        const choice = (i, titleKey, titleFb, subKey, subFb) => `
            <button class="choice ${c.infoIdx === i ? "focus" : ""} ${(i === 0) === c.tutorial ? "chosen" : ""}" data-group="info" data-idx="${i}" data-hover="info:${i}" data-act="info:${i}">
                <span class="c-title">${esc(t(titleKey, titleFb))}</span>
                <span class="c-sub">${esc(t(subKey, subFb))}</span>
            </button>`;
        return `
        <div class="screen column-screen">
            <div class="column wide paper">
                <h2 class="heading">${esc(t("CHARACTER_INFO_TITLE", "Character info"))}</h2>
                <div class="lead">${esc(t("CHARACTER_INFO_SUB", "Choose how you want to begin your story."))}</div>
                <div class="step">${esc(t("READY_TO_BEGIN", "Ready to begin"))}</div>
                <div class="section-label">${esc(t("TUTORIAL", "Tutorial"))}</div>
                <div class="choices">
                    ${choice(0, "VIEW_TUTORIAL", "View Tutorial", "VIEW_TUTORIAL_SUB", "Guided introduction to some of the basics")}
                    ${choice(1, "SKIP_TUTORIAL", "Skip Tutorial", "SKIP_TUTORIAL_SUB", "Jump right in")}
                </div>
                <div class="error">${esc(c.err)}</div>
                <div class="info-actions">
                    <button class="btn deco" data-act="infoBack">${KEY.esc} ${esc(t("BACK", "Back"))}</button>
                    <button class="btn deco" data-act="finish" ${S.busy ? "disabled" : ""}>${KEY.enter} ${esc(S.busy ? t("LOADING", "Loading…") : t("FINISH", "Finish"))}</button>
                </div>
            </div>
        </div>`;
    }

    function finishCreate() {
        const c = S.create;
        if (S.busy) return;
        S.busy = true;
        c.err = "";
        blip("select");
        post("CREATE_CHARACTER", {
            firstName: c.first,
            lastName: c.last,
            dob: dobIso(c.dob),
            height: 180,
            nationality: "Unknown",
            gender: c.gender,
            tutorial: c.tutorial,
        }).then((res) => {
            if (res && res.success === false && res.message !== "in progress") {
                S.busy = false;
                c.err = res.message === "no_free_slot" ? t("NO_FREE_SLOT", "No free character slot") : t("CREATE_FAILED", "Could not create character");
                render();
            }
        });
        render();
    }

    function cancelCreate() {
        blip("back");
        setView("transition");
        post("CANCEL_CREATE_CHARACTER");
    }

    // ─── Premium modal ──────────────────────────────────────────────────────

    function viewModal() {
        return `
        <div class="modal-wrap">
            <div class="modal paper">
                <h3 class="heading">${esc(t("PREMIUM_SLOT", "Premium slot"))}</h3>
                <p>${esc(t("PREMIUM_SLOT_BODY", "This slot is reserved for premium players."))}</p>
                <div class="row"><button class="btn focus" data-act="modalClose">${KEY.enter} ${esc(t("CLOSE", "Close"))}</button></div>
            </div>
        </div>`;
    }

    function modalClose() {
        S.modal = null;
        blip("back");
        render();
    }

    // ─── Overlays ───────────────────────────────────────────────────────────

    let timerTick;

    function renderOverlay() {
        let html = "";
        if (O.welcome) {
            html += `
            <div class="welcome">
                <div class="w-top">${esc(t("WELCOME", "Welcome to the city"))}</div>
                <div class="w-name heading">${esc(O.welcome.name)}</div>
                <div class="w-bar"></div>
            </div>`;
        }
        if (O.timer) {
            html += `
            <div class="timer paper">
                <div class="t-head heading">${esc(t("FIND_SPOT_TITLE", "Find a good spot"))}</div>
                <div class="t-body">
                    <div class="t-sub">${esc(t("FIND_SPOT_SUB", "You will be able to customize your character shortly"))}</div>
                    <div class="t-count heading" id="t-count"></div>
                    <div class="t-track"><div class="t-fill" id="t-fill"></div></div>
                </div>
            </div>`;
        }
        if (O.tutorial) {
            const { steps, index } = O.tutorial;
            const step = steps[index - 1];
            if (step) {
                const dots = steps.map((_, i) => `<i class="${i === index - 1 ? "on" : ""}"></i>`).join("");
                const keyBtn = step.key ? `<div class="btn"><span class="key">${esc(step.key)}</span> ${esc(step.hint || "")}</div>` : "";
                const last = index === steps.length;
                html += `
                <div class="tut ${esc(step.position || "center")} paper">
                    <div class="t-head heading">${esc(step.title || "")}</div>
                    <div class="t-body">
                        <div class="t-text">${esc(step.body || "")}</div>
                        <div class="t-actions">${keyBtn}<div class="btn"><span class="key">↵</span> ${esc(last ? t("FINISH", "Finish") : t("NEXT", "Next"))}</div></div>
                        <div class="t-foot"><span class="dots">${dots}</span><span>${index}/${steps.length}</span></div>
                    </div>
                </div>`;
            }
        }
        overlay.innerHTML = html;
        updateTimer();
    }

    function updateTimer() {
        if (!O.timer) return;
        const left = Math.max(0, O.timer.end - Date.now());
        const count = document.getElementById("t-count");
        const fill = document.getElementById("t-fill");
        if (count) count.textContent = `${Math.ceil(left / 1000)}`;
        if (fill) fill.style.transform = `scaleX(${left / O.timer.duration})`;
    }

    // ─── Input: clicks, hover, keyboard ─────────────────────────────────────

    function act(name, arg, arg2) {
        switch (name) {
            case "start": blip("select"); S.menuIdx = continueChar() ? 0 : 1; return setView("menu");
            case "menu":
                if (S.view === "options") return setView("menu");
                S.menuIdx = Number(arg);
                return menuActivate(S.menuIdx);
            case "opt": S.optIdx = Number(arg); return optionActivate(S.optIdx);
            case "slot": return moveSlot(Number(arg));
            case "pick": return pickSlot();
            case "detail": S.detailIdx = Number(arg); return detailActivate(S.detailIdx);
            case "spawn":
                if (mapDrag?.moved) return null; // the click ended a drag
                return spawnSelect(Number(arg));
            case "spawnGo": return spawnGo();
            case "gender":
                if (S.create.gender === arg) { blip("select"); S.create.step = "identity"; return render(); }
                return setGender(arg);
            case "pk": return pickerAct(arg, arg2);
            case "identityConfirm": return identityConfirm();
            case "identityCancel": blip("back"); S.create.step = "body"; S.create.picker = null; return render();
            case "editConfirm": return editConfirm();
            case "editCancel": blip("back"); return setView("detail");
            case "deleteConfirm": return deleteConfirm();
            case "deleteCancel": blip("back"); return setView("detail");
            case "info":
                S.create.infoIdx = Number(arg);
                S.create.tutorial = Number(arg) === 0;
                blip("side");
                return render();
            case "infoBack": blip("back"); S.create.step = "identity"; return render();
            case "finish": return finishCreate();
            case "modalClose": return modalClose();
            default: return null;
        }
    }

    app.addEventListener("click", (e) => {
        const el = e.target.closest("[data-act]");
        if (!el) {
            // Clicking outside an open date picker closes it.
            const f = form();
            if (f?.picker && !e.target.closest(".picker")) { f.picker = null; render(); }
            return;
        }
        const [name, a, b] = el.dataset.act.split(":");
        if (name === "noop") return; // click landed on the picker's background
        e.stopPropagation();
        act(name, a, b);
    });

    // Spawn map: wheel zooms toward the cursor, drag pans, double-click a pin spawns.
    let mapDrag = null;

    app.addEventListener("wheel", (e) => {
        const vp = e.target.closest?.("#map-viewport");
        if (!vp || !S.map) return;
        const r = vp.getBoundingClientRect();
        zoomMap(vp, e.deltaY < 0 ? 1.2 : 1 / 1.2, e.clientX - r.left, e.clientY - r.top);
    }, { passive: true });

    app.addEventListener("mousedown", (e) => {
        const vp = e.target.closest?.("#map-viewport");
        if (!vp || e.button !== 0 || !S.map) return;
        mapDrag = { sx: e.clientX, sy: e.clientY, x: S.map.x, y: S.map.y, moved: false };
        vp.classList.add("dragging");
    });

    window.addEventListener("mousemove", (e) => {
        if (!mapDrag || !S.map) return;
        const dx = e.clientX - mapDrag.sx;
        const dy = e.clientY - mapDrag.sy;
        if (!mapDrag.moved && Math.hypot(dx, dy) < 4) return;
        mapDrag.moved = true;
        S.map.x = mapDrag.x + dx;
        S.map.y = mapDrag.y + dy;
        const vp = document.getElementById("map-viewport");
        if (vp) { clampMap(vp); applyMap(); }
    });

    window.addEventListener("mouseup", () => {
        if (!mapDrag) return;
        document.getElementById("map-viewport")?.classList.remove("dragging");
        // Let the click that ends this mouseup see `moved`, then clear it.
        const drag = mapDrag;
        setTimeout(() => { if (mapDrag === drag) mapDrag = null; }, 0);
    });

    app.addEventListener("dblclick", (e) => {
        const pin = e.target.closest?.(".pin");
        if (!pin || S.view !== "spawn") return;
        S.spawnIdx = Number(pin.dataset.idx);
        spawnGo();
    });

    app.addEventListener("mouseover", (e) => {
        const el = e.target.closest("[data-hover]");
        if (!el) return;
        const [group, v] = el.dataset.hover.split(":");
        const idx = Number(v);
        if (group === "menu" && S.view === "options") return;
        const key = { menu: "menuIdx", opt: "optIdx", detail: "detailIdx" }[group];
        if (key && S[key] !== idx) {
            S[key] = idx;
            blip("move");
            if (group === "opt") render(); else syncFocus(group, idx);
        } else if (group === "info" && S.create && S.create.infoIdx !== idx) {
            S.create.infoIdx = idx;
            syncFocus("info", idx);
        }
    });

    app.addEventListener("input", (e) => {
        const field = e.target.dataset?.field;
        if (!field) return;
        if (field === "del") {
            S.del.text = e.target.value;
            const ok = S.del.text.trim().toLowerCase() === String(S.detail?.name || "").trim().toLowerCase();
            const btn = app.querySelector('[data-act="deleteConfirm"]');
            if (btn) btn.disabled = !ok;
            return;
        }
        const f = form();
        if (!f) return;
        f[field] = e.target.value;
        const count = app.querySelector(`[data-count="${field}"]`);
        if (count) count.textContent = `${e.target.value.length}/32`;
        if (f.invalid[field]) {
            f.invalid[field] = false;
            e.target.parentElement.classList.remove("invalid");
        }
    });

    app.addEventListener("focusin", (e) => {
        if (e.target.tagName !== "INPUT") return;
        e.target.parentElement.classList.add("focus");
        const f = form();
        if (f?.picker) {
            f.picker = null;
            app.querySelector(".picker")?.remove();
        }
        post("SET_INPUT_FOCUS", { focused: true });
    });

    app.addEventListener("focusout", (e) => {
        if (e.target.tagName !== "INPUT") return;
        e.target.parentElement.classList.remove("focus");
        post("SET_INPUT_FOCUS", { focused: false });
    });

    function focusField(id) {
        const el = document.getElementById("f-" + id);
        if (el) { el.focus(); el.setSelectionRange(el.value.length, el.value.length); }
    }

    function moveFocus(group, key, delta, count, sound = "move") {
        S[key] = wrap(S[key] + delta, count);
        blip(sound);
        syncFocus(group, S[key]);
    }

    const isBack = (k) => k === "Escape" || k === "Backspace";

    const keyHandlers = {
        title(k) {
            if (k === "Enter" || k === " ") act("start");
        },
        menu(k) {
            if (k === "ArrowLeft") moveFocus("menu", "menuIdx", -1, 3, "side");
            else if (k === "ArrowRight") moveFocus("menu", "menuIdx", 1, 3, "side");
            else if (k === "Enter") menuActivate(S.menuIdx);
            else if (isBack(k)) { blip("back"); setView("title"); }
        },
        options(k) {
            const n = optionItems().length;
            if (k === "ArrowUp") { S.optIdx = wrap(S.optIdx - 1, n); blip("move"); render(); }
            else if (k === "ArrowDown") { S.optIdx = wrap(S.optIdx + 1, n); blip("move"); render(); }
            else if (k === "ArrowLeft" || k === "ArrowRight") optionActivate(S.optIdx, true);
            else if (k === "Enter" || k === " ") optionActivate(S.optIdx);
            else if (isBack(k)) { blip("back"); setView("menu"); }
        },
        chars(k) {
            if (k === "ArrowLeft") moveSlot(-1);
            else if (k === "ArrowRight") moveSlot(1);
            else if (k === "Enter") pickSlot();
            else if (isBack(k)) { blip("back"); setView("menu"); }
        },
        detail(k) {
            const n = detailItems().length;
            if (k === "ArrowUp") moveFocus("detail", "detailIdx", -1, n);
            else if (k === "ArrowDown") moveFocus("detail", "detailIdx", 1, n);
            else if (k === "ArrowLeft") switchCharacter(-1);
            else if (k === "ArrowRight") switchCharacter(1);
            else if (k === "Enter") detailActivate(S.detailIdx);
            else if (isBack(k)) detailBack();
        },
        edit(k) {
            if (isBack(k)) {
                if (S.edit.picker) { S.edit.picker = null; render(); } else act("editCancel");
            } else if (k === "Enter" && !S.edit.picker) editConfirm();
        },
        delete(k) {
            if (isBack(k)) act("deleteCancel");
            else if (k === "Enter") deleteConfirm();
        },
        spawn(k) {
            if (k === "ArrowUp" || k === "ArrowLeft") spawnSelect(S.spawnIdx - 1);
            else if (k === "ArrowDown" || k === "ArrowRight") spawnSelect(S.spawnIdx + 1);
            else if (k === "Enter") spawnGo();
            else if (isBack(k)) { blip("back"); setView("detail"); }
        },
        create(k) {
            const c = S.create;
            if (c.step === "body") {
                if (k === "ArrowLeft") setGender("Male");
                else if (k === "ArrowRight") setGender("Female");
                else if (k === "Enter") act("gender", c.gender);
                else if (isBack(k)) cancelCreate();
            } else if (c.step === "identity") {
                if (isBack(k)) {
                    if (c.picker) { c.picker = null; render(); } else act("identityCancel");
                } else if (k === "Enter" && !c.picker) identityConfirm();
            } else if (c.step === "info") {
                if (k === "ArrowLeft" || k === "ArrowRight") act("info", c.infoIdx === 0 ? 1 : 0);
                else if (k === "Enter") finishCreate();
                else if (isBack(k)) act("infoBack");
            }
        },
    };

    window.addEventListener("keydown", (e) => {
        if (!S.visible || S.fading || S.processing) return;
        const k = e.key;
        if (e.repeat && (k === "Enter" || k === "Escape")) return;

        const active = document.activeElement;
        if (active && active.tagName === "INPUT") {
            if (k === "Enter") {
                e.preventDefault();
                if (active.dataset.field === "del") { active.blur(); return deleteConfirm(); }
                if (active.dataset.field === "first") focusField("last");
                else if (!form()?.dob) { active.blur(); pickerAct("toggle"); }
                else { active.blur(); S.view === "edit" ? editConfirm() : identityConfirm(); }
            } else if (k === "Escape") {
                active.blur();
            }
            return;
        }

        if (["ArrowUp", "ArrowDown", "ArrowLeft", "ArrowRight", " ", "Backspace"].includes(k)) e.preventDefault();

        if (S.modal) {
            if (k === "Enter" || isBack(k)) modalClose();
            return;
        }

        keyHandlers[S.view]?.(k, e);
    });

    // ─── Messages from Lua ──────────────────────────────────────────────────

    const handlers = {
        SET_VISIBLE(v) {
            S.visible = !!v;
            S.busy = false;
            S.processing = false;
            S.modal = null;
            if (v) {
                S.view = S.prefs.skipStart ? "menu" : "title";
                S.menuIdx = continueChar() ? 0 : 1;
                post("BLOCK_RAYCAST", { blocked: true });
            } else {
                // The page stays loaded between sessions; re-announce so the
                // next Init (relog) doesn't wait on a boot signal.
                post("UI_BOOTED");
            }
            render();
        },
        SET_FADING(v) { S.fading = !!v; render(); },
        SET_TRANSLATIONS(d) { S.tr = d?.translations || {}; render(); },
        SET_CONFIG(d) {
            S.cfg = Object.assign(S.cfg, d || {});
            render();
        },
        SET_CHARACTERS(list) {
            S.chars = Array.isArray(list) ? list : [];
            if (S.focus >= S.chars.length) S.focus = 0;
            if (S.view === "title" || S.view === "menu") S.menuIdx = continueChar() ? S.menuIdx : 1;
            if (["menu", "chars"].includes(S.view)) render();
        },
        SET_SPAWN_POSITIONS(list) { S.spawns = Array.isArray(list) ? list : []; },
        BEGIN_TRANSITION() { S.view = "transition"; render(); },
        OPEN_CHARACTER_DETAIL(d) {
            S.detail = d;
            S.detailIdx = 0;
            S.busy = false;
            const i = S.chars.findIndex((c) => c && c.id === d?.id);
            if (i >= 0) S.focus = i;
            setView("detail");
            post("PANEL_SHOWN");
        },
        CLOSE_CHARACTER_DETAIL() {
            if (["detail", "spawn", "edit", "delete", "transition"].includes(S.view) && S.visible) {
                S.modal = null;
                setView("chars");
            }
        },
        OPEN_CREATE_CHARACTER() {
            S.create = Object.assign(newForm(), { step: "body", gender: "Male", tutorial: true, infoIdx: 0 });
            S.busy = false;
            setView("create");
            post("PREVIEW_BODY", { gender: S.create.gender });
        },
        CLOSE_CREATE_CHARACTER() {
            S.busy = false;
            if (["create", "transition"].includes(S.view) && S.visible) setView("chars");
        },
        OPEN_PREMIUM_INFO() { S.modal = { kind: "premium" }; render(); },
        CLOSE_PREMIUM_INFO() { if (S.modal) { S.modal = null; render(); } },
        HOVER_SLOT(d) {
            const i = Number(d?.slot) - 1;
            if (i >= 0 && i !== S.focus && i < S.chars.length) {
                S.focus = i;
                if (S.view === "chars") render();
            }
        },
        GAME_SETTINGS_CLOSED() { render(); },
        SHOW_WELCOME(d) {
            O.welcome = { name: d?.name || "" };
            renderOverlay();
            setTimeout(() => { O.welcome = null; renderOverlay(); }, 5700);
        },
        HIDE_WELCOME() { O.welcome = null; renderOverlay(); },
        SHOW_CLOTHING_TIMER(d) {
            const duration = Number(d?.durationMs) || 15000;
            O.timer = { duration, end: Date.now() + duration };
            clearInterval(timerTick);
            timerTick = setInterval(updateTimer, 100);
            renderOverlay();
        },
        HIDE_CLOTHING_TIMER() { O.timer = null; clearInterval(timerTick); renderOverlay(); },
        SHOW_TUTORIAL(d) { O.tutorial = { steps: d?.steps || [], index: 1 }; renderOverlay(); },
        TUTORIAL_STEP(d) {
            if (!O.tutorial) return;
            O.tutorial.index = Number(d?.index) || 1;
            renderOverlay();
        },
        HIDE_TUTORIAL() { O.tutorial = null; renderOverlay(); },
    };

    window.addEventListener("message", (e) => {
        const msg = e.data;
        if (!msg || typeof msg.action !== "string") return;
        const fn = handlers[msg.action];
        if (fn) fn(msg.data);
    });

    // ─── Boot ───────────────────────────────────────────────────────────────

    render();
    post("UI_BOOTED");

    // Browser preview: open index.html?view=<title|menu|options|chars|detail|
    // edit|delete|spawn|body|identity|info|tutorial> to iterate on styling.
    function mockUpdate(data) {
        const c = S.chars.find((x) => x && x.id === data.id);
        if (c) Object.assign(c, { name: `${data.firstName} ${data.lastName}`, dob: data.dob });
        return c;
    }

    if (!IS_GAME) {
        const q = new URLSearchParams(location.search);
        const sample = [
            { id: "A1", name: "Victor Francis", gender: "Male", dob: "1980-02-05", cash: 2500, bank: 48210, playtimeMinutes: 3271, job: "police", jobLabel: "Police", jobGrade: "Lieutenant", lastLocation: { x: 425.1, y: -979.5, z: 30.7 } },
            { id: false, name: "Create New" },
            { id: "A3", name: "Vc Tc", gender: "Female", dob: "2008-09-28", cash: 120, bank: 9100, playtimeMinutes: 640, job: "ambulance", jobLabel: "EMS", jobGrade: "Paramedic" },
            { id: false, name: "Create New" },
            { id: false, name: "Premium", locked: true },
        ];
        handlers.SET_CHARACTERS(sample);
        handlers.SET_SPAWN_POSITIONS([
            { label: "Legion Park", icon: "pin", coords: { x: 233.2, y: -896.9, z: 30.6 }, description: "The heart of downtown." },
            { label: "Sandy Shores", icon: "pin", coords: { x: 1678.6, y: 3765.6, z: 34.5 } },
            { label: "Paleto Bay", icon: "pin", coords: { x: -62.5, y: 6426.8, z: 31.4 } },
            { label: "LSIA", icon: "plane", coords: { x: -1037.0, y: -2737.0, z: 20.1 } },
        ]);
        handlers.SET_VISIBLE(true);
        document.body.style.background = "#2a3340";
        const view = q.get("view") || "title";
        if (q.has("menu")) S.menuIdx = Number(q.get("menu"));
        if (q.has("opt")) S.optIdx = Number(q.get("opt"));
        if (["menu", "options", "chars"].includes(view)) setView(view);
        else if (["detail", "spawn", "edit", "delete"].includes(view)) {
            handlers.OPEN_CHARACTER_DETAIL(sample[0]);
            if (view === "spawn") setView("spawn");
            if (view === "edit") act("detail", 1);
            if (view === "delete") act("detail", 2);
        } else if (["body", "identity", "info"].includes(view)) {
            handlers.OPEN_CREATE_CHARACTER();
            Object.assign(S.create, { step: view, first: "Victor", last: "" });
            if (q.get("picker")) S.create.picker = { mode: q.get("picker"), year: 1980, month: 2, pageStart: 1980 };
            render();
        } else if (view === "processing") {
            setView("menu");
            S.processing = true;
            render();
        } else if (view === "tutorial") {
            S.visible = false;
            render();
            handlers.SHOW_TUTORIAL({ steps: [
                { title: "NAVIGATION", position: "top-right", key: "M", hint: "OPEN MAP", body: "Use your map to find jobs, shops, and points of interest around the city." },
            ] });
        }
    }
})();
