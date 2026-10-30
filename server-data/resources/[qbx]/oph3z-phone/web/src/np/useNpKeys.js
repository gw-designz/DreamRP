// Keyboard / controller navigation for the phone (the on-screen legend's keys):
//   T fold/unfold · Y home · Enter select · Backspace back · Esc close (App.jsx)
//   Arrow keys move a visible focus ring between whatever is clickable on screen.
//   Q / E fire `np:tab` so apps with a bottom bar (Socials) can cycle their tabs.
// Everything is skipped while the player is typing, and Enter/Backspace are left alone
// while an app marks itself `data-np-keys="own"` (calculator, dial keypad, money pad).
import { useEffect } from 'react';
import { useDispatch, useStore } from 'react-redux';
import { closeApp, setControlCenter } from '../store/slices/phoneSlice';
import { setLightbox } from '../store/slices/photosSlice';
import { toggleFold } from './lifecycle';
import { playSound } from './sound';

const FOCUSABLE =
    'button:not([disabled]), [role="button"], a[href], input:not([disabled]):not([type="hidden"]), textarea:not([disabled]), [data-nav]';

const BACK_SELECTORS = [
    '[data-np-back]',
    '[aria-label="Back"]',
    '.set__back',
    '.set__backcircle',
    '[class*="__back"]:not([class*="backdrop"]):not(.pa-keypad__back)',
];

const ARROWS = { ArrowUp: 'up', ArrowDown: 'down', ArrowLeft: 'left', ArrowRight: 'right' };

let marked = null;

const isTyping = (el) =>
    !!el &&
    (el.tagName === 'INPUT' ||
        el.tagName === 'TEXTAREA' ||
        el.tagName === 'SELECT' ||
        el.isContentEditable);

const screenEl = () => document.querySelector('.phone__screen');

function hittable(el, bounds) {
    const r = el.getBoundingClientRect();
    if (r.width < 2 || r.height < 2) return false;
    const cx = r.left + r.width / 2;
    const cy = r.top + r.height / 2;
    if (cx < bounds.left || cx > bounds.right || cy < bounds.top || cy > bounds.bottom)
        return false;
    const hit = document.elementFromPoint(cx, cy);
    return !!hit && (hit === el || el.contains(hit));
}

function candidates(screen) {
    const bounds = screen.getBoundingClientRect();
    return [...screen.querySelectorAll(FOCUSABLE)].filter(
        (el) => !el.closest('.statusbar') && hittable(el, bounds),
    );
}

function mark(el) {
    if (marked && marked !== el) marked.removeAttribute('data-np-focus');
    marked = el;
    if (!el) return;
    if (!el.hasAttribute('data-np-focus')) playSound('hover');
    el.setAttribute('data-np-focus', '');
    document.body.classList.add('np-kbd');
    el.scrollIntoView({ block: 'nearest', inline: 'nearest' });
}

const center = (r) => ({ x: r.left + r.width / 2, y: r.top + r.height / 2 });

function scrollerOf(el, screen) {
    let n = el && el.parentElement;
    while (n && n !== screen) {
        const oy = getComputedStyle(n).overflowY;
        if ((oy === 'auto' || oy === 'scroll') && n.scrollHeight > n.clientHeight + 2) return n;
        n = n.parentElement;
    }
    return null;
}

function move(dir, retry = true) {
    const screen = screenEl();
    if (!screen) return;
    const list = candidates(screen);
    const cur = marked && document.contains(marked) && list.includes(marked) ? marked : null;

    if (!cur) {
        const first = list.sort((a, b) => {
            const ra = a.getBoundingClientRect();
            const rb = b.getBoundingClientRect();
            return ra.top - rb.top || ra.left - rb.left;
        })[0];
        mark(first || null);
        return;
    }

    const c = center(cur.getBoundingClientRect());
    const vertical = dir === 'up' || dir === 'down';
    let best = null;
    let bestScore = Infinity;
    for (const el of list) {
        if (el === cur) continue;
        const q = center(el.getBoundingClientRect());
        const dx = q.x - c.x;
        const dy = q.y - c.y;
        const primary = dir === 'down' ? dy : dir === 'up' ? -dy : dir === 'right' ? dx : -dx;
        if (primary <= 2) continue;
        const orth = vertical ? Math.abs(dx) : Math.abs(dy);
        const score = primary + orth * (vertical ? 2 : 3);
        if (score < bestScore) {
            bestScore = score;
            best = el;
        }
    }

    if (best) {
        mark(best);
        return;
    }

    // Nothing further in view: scroll the list we're in and try once more.
    const sc = vertical ? scrollerOf(cur, screen) : null;
    if (sc && retry) {
        sc.scrollBy({ top: (dir === 'down' ? 1 : -1) * sc.clientHeight * 0.6 });
        requestAnimationFrame(() => move(dir, false));
    }
}

function findBackButton(screen) {
    const bounds = screen.getBoundingClientRect();
    for (const sel of BACK_SELECTORS) {
        const found = [...screen.querySelectorAll(sel)].filter((el) => hittable(el, bounds));
        if (found.length) {
            found.sort((a, b) => a.getBoundingClientRect().top - b.getBoundingClientRect().top);
            return found[0];
        }
    }
    return null;
}

export function useNpKeys() {
    const dispatch = useDispatch();
    const store = useStore();

    useEffect(() => {
        const goHome = () => {
            playSound('home');
            dispatch(setLightbox(null));
            dispatch(setControlCenter(false));
            dispatch(closeApp());
        };

        const goBack = () => {
            playSound('back');
            const st = store.getState();
            if (st.photos.lightbox) {
                dispatch(setLightbox(null));
                return;
            }
            if (st.phone.controlCenterOpen) {
                dispatch(setControlCenter(false));
                return;
            }
            // Apps with their own navigation stack call preventDefault() on this event.
            const ev = new CustomEvent('np:back', { cancelable: true });
            if (!window.dispatchEvent(ev)) return;
            const screen = screenEl();
            const btn = screen && findBackButton(screen);
            if (btn) {
                btn.click();
                return;
            }
            if (st.phone.activeApp) dispatch(closeApp());
        };

        const onKey = (e) => {
            const st = store.getState();
            if (!st.phone.visible || st.phone.phase !== 'open') return;
            if (e.ctrlKey || e.altKey || e.metaKey) return;
            if (isTyping(e.target)) return;

            const keys = st.phone.ui.keys || {};
            const code = e.code;
            const isKey = (k) => !!k && code === `Key${String(k).toUpperCase()}`;

            if (isKey(keys.fold)) {
                if (e.repeat) return;
                e.preventDefault();
                dispatch(toggleFold());
                return;
            }
            if (isKey(keys.home)) {
                if (e.repeat) return;
                e.preventDefault();
                goHome();
                return;
            }
            if (isKey(keys.tabLeft) || isKey(keys.tabRight)) {
                if (e.repeat) return;
                window.dispatchEvent(
                    new CustomEvent('np:tab', { detail: isKey(keys.tabLeft) ? -1 : 1 }),
                );
                return;
            }

            const owned = !!document.querySelector('[data-np-keys="own"]');
            if (e.key === 'Backspace') {
                if (owned) return;
                e.preventDefault();
                if (!e.repeat) goBack();
                return;
            }
            if (e.key === 'Enter') {
                if (owned) return;
                const el = marked;
                if (el && document.contains(el) && document.body.classList.contains('np-kbd')) {
                    e.preventDefault();
                    if (!e.repeat) el.click();
                }
                return;
            }
            const dir = ARROWS[e.key];
            if (dir) {
                e.preventDefault();
                move(dir);
            }
        };

        const onMouse = () => {
            if (document.body.classList.contains('np-kbd')) document.body.classList.remove('np-kbd');
        };

        window.addEventListener('keydown', onKey);
        window.addEventListener('mousemove', onMouse, { passive: true });
        return () => {
            window.removeEventListener('keydown', onKey);
            window.removeEventListener('mousemove', onMouse);
        };
    }, [dispatch, store]);
}

export function clearNpFocus() {
    mark(null);
    document.body.classList.remove('np-kbd');
}
