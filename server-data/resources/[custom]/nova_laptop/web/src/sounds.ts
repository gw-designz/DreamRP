import { isPreview, nui } from './api';

/*
  GTA's own frontend sounds for the laptop and the radial menu: the page asks
  the game to play them (the 'sound' callback, Config.Sounds in config.lua).
*/

export type SoundKind = 'hover' | 'select' | 'back';

let enabled = true;
let lastHover = 0;

/** The laptop's Interface Sounds setting. */
export function setSoundsEnabled(value: boolean) { enabled = value; }

export function playSound(kind: SoundKind) {
  if (!enabled || isPreview) return;
  // Sweeping the pointer across a row of buttons should tick, not rattle.
  if (kind === 'hover') {
    const now = performance.now();
    if (now - lastHover < 60) return;
    lastHover = now;
  }
  void nui('sound', { kind });
}

const CLICKABLE = 'button, [role="button"], [role="menuitem"], select, a[href], .dock-item, .mz-card, .mz-slot, .li-perm, .mb-thumb, .ns-issue';

const usable = (el: Element | null): el is HTMLElement =>
  !!el && !(el as HTMLButtonElement).disabled && el.getAttribute('aria-disabled') !== 'true';

/** A tick when the pointer moves onto anything clickable, a click when it is pressed. */
export function installButtonSounds() {
  let current: Element | null = null;
  document.addEventListener('mouseover', event => {
    const el = (event.target as Element | null)?.closest?.(CLICKABLE) ?? null;
    if (el === current) return;
    current = el;
    if (usable(el)) playSound('hover');
  });
  document.addEventListener('mousedown', event => {
    if (event.button !== 0) return;
    const el = (event.target as Element | null)?.closest?.(CLICKABLE) ?? null;
    if (usable(el)) playSound('select');
  }, true);
}
