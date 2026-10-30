// GTA frontend sounds for the UI (Config.UI.Sounds; client/nui.lua plays them for phone:sound).
// One set of delegated listeners covers every button in every app: hover, click, Enter and back.
// Sounds fired in the same instant are merged and the most specific one wins, so launching an
// app plays "open" instead of "click" + "open". Add data-sound="none" to an element to mute it,
// or data-sound="<kind>" to pick its sound.
import { fetchNui } from '../utils/fetchNui';
import { isEnvBrowser } from '../utils/misc';

const PRIORITY = { hover: 1, click: 2, enter: 3, back: 4, home: 5, open: 5 };
const HOVER_GAP_MS = 60;

const INTERACTIVE =
    'button:not([disabled]), [role="button"], a[href], [data-nav], select, input[type="checkbox"]:not([disabled]), input[type="radio"]:not([disabled])';
const BACK = '[data-np-back], [aria-label="Back"], .set__back, .set__backcircle';

let serverOn = false; // Config.UI.Sounds.Enabled
let playerOn = true; // Settings › Sounds › Interface Sounds
let pending = null;
let lastHover = 0;
let hovered = null;

export function setUiSounds(on) {
    serverOn = !!on;
}

export function setUiSoundsPref(on) {
    playerOn = on !== false;
}

export function playSound(kind) {
    if (!serverOn || !playerOn || !PRIORITY[kind]) return;
    if (kind === 'hover') {
        const now = performance.now();
        if (now - lastHover < HOVER_GAP_MS) return;
        lastHover = now;
    }
    if (pending) {
        if (PRIORITY[kind] > PRIORITY[pending]) pending = kind;
        return;
    }
    pending = kind;
    setTimeout(() => {
        const k = pending;
        pending = null;
        // browser preview: no game to play natives, so keep a log for debugging instead
        if (isEnvBrowser()) (window.__uiSounds = window.__uiSounds || []).push(k);
        else fetchNui('phone:sound', { kind: k });
    }, 0);
}

// data-sound on the element (or an ancestor) overrides the default; "none" mutes it
function override(el) {
    const tagged = el.closest('[data-sound]');
    return tagged ? tagged.getAttribute('data-sound') : null;
}

export function installUiSounds() {
    const onOver = (e) => {
        const el = e.target instanceof Element ? e.target.closest(INTERACTIVE) : null;
        if (el === hovered) return;
        hovered = el;
        if (el && override(el) !== 'none') playSound('hover');
    };

    const onClick = (e) => {
        const el = e.target instanceof Element ? e.target.closest(INTERACTIVE) : null;
        if (!el) return;
        const tag = override(el);
        if (tag === 'none') return;
        // detail 0 = activated from the keyboard (Enter / useNpKeys' el.click())
        playSound(tag || (el.matches(BACK) ? 'back' : e.detail === 0 ? 'enter' : 'click'));
    };

    // Enter that submits a text field (address bars, chat inputs, search boxes)
    const onKey = (e) => {
        if (e.key === 'Enter' && !e.repeat && e.target instanceof HTMLInputElement && override(e.target) !== 'none')
            playSound('enter');
    };

    document.addEventListener('pointerover', onOver, true);
    document.addEventListener('click', onClick, true);
    document.addEventListener('keydown', onKey, true);
    return () => {
        document.removeEventListener('pointerover', onOver, true);
        document.removeEventListener('click', onClick, true);
        document.removeEventListener('keydown', onKey, true);
    };
}
