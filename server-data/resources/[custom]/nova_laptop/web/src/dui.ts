/*
  Input for world mode, where the laptop is a page painted on the prop (a DUI).

  The game passes the mouse straight into the DUI, but it has no way to pass
  keys. So the normal NUI page keeps keyboard focus, catches every key and
  sends it to the game, which hands it on to the DUI. Here the DUI page plays
  each key into whatever is focused: the keydown/keyup events the apps listen
  for, plus what the browser would normally do (typing, deleting, moving the
  caret, Tab, Enter). The game keeps the mouse and only lends the keyboard to
  the NUI page while a field on the screen has the caret, which this page
  reports (the 'typing' callback), as Renewed-Banking does for its ATMs.

  An off-screen browser also never shows a <select>'s popup, so those are
  drawn by this file instead.
*/

export type KeyMessage = { key: string; code: string; shift: boolean; ctrl: boolean; alt: boolean; meta: boolean; repeat: boolean };


// ── the NUI page: catch keys while relaying and send them, in order ───────

export function installKeyRelay(send: (keys: KeyMessage[]) => Promise<unknown>) {
  let on = false, sending = false, queue: KeyMessage[] = [];
  const flush = async () => {
    if (sending || !queue.length) return;
    sending = true;
    const keys = queue; queue = [];
    await send(keys);
    sending = false;
    void flush();
  };
  window.addEventListener('message', event => { if (event.data?.type === 'relay') { on = !!event.data.on; queue = []; } });
  window.addEventListener('keydown', event => {
    if (!on) return;
    event.preventDefault();
    queue.push({ key: event.key, code: event.code, shift: event.shiftKey, ctrl: event.ctrlKey, alt: event.altKey, meta: event.metaKey, repeat: event.repeat });
    void flush();
  });
}

// ── the DUI page: play the keys ────────────────────────────────────────────

type Field = HTMLInputElement | HTMLTextAreaElement;
let clipboard = '';

const isField = (el: Element | null): el is Field => el instanceof HTMLTextAreaElement
  || (el instanceof HTMLInputElement && !['checkbox', 'radio', 'button', 'submit', 'reset', 'range', 'color', 'file'].includes(el.type));
// Number and email inputs have no caret position to read or set.
const hasCaret = (field: Field) => field instanceof HTMLTextAreaElement || ['text', 'search', 'url', 'tel', 'password'].includes(field.type);

function setValue(field: Field, value: string) {
  const proto = field instanceof HTMLTextAreaElement ? HTMLTextAreaElement.prototype : HTMLInputElement.prototype;
  // The prototype's setter, so React notices the change.
  Object.getOwnPropertyDescriptor(proto, 'value')!.set!.call(field, value);
  field.dispatchEvent(new Event('input', { bubbles: true }));
}

function insert(field: Field, text: string) {
  if (!hasCaret(field)) { setValue(field, field.value + text); return; }
  const before = field.value;
  const command = text ? document.execCommand('insertText', false, text) : document.execCommand('delete');
  if (command && field.value !== before) return;
  const start = field.selectionStart ?? field.value.length, end = field.selectionEnd ?? start;
  field.setRangeText(text, start, end, 'end');
  field.dispatchEvent(new Event('input', { bubbles: true }));
}

function erase(field: Field, direction: -1 | 1) {
  if (!hasCaret(field)) { if (direction < 0) setValue(field, field.value.slice(0, -1)); return; }
  let start = field.selectionStart ?? 0, end = field.selectionEnd ?? 0;
  if (start === end) {
    if (direction < 0) { if (start === 0) return; start -= 1; }
    else { if (end >= field.value.length) return; end += 1; }
    field.setSelectionRange(start, end);
  }
  insert(field, '');
}

function moveCaret(field: Field, key: string, extend: boolean) {
  if (!hasCaret(field)) return;
  const value = field.value, start = field.selectionStart ?? 0, end = field.selectionEnd ?? 0;
  const backward = field.selectionDirection === 'backward';
  const head = backward ? start : end, anchor = backward ? end : start;
  const lineStart = (at: number) => value.lastIndexOf('\n', at - 1) + 1;
  const lineEnd = (at: number) => { const found = value.indexOf('\n', at); return found < 0 ? value.length : found; };
  const multiline = field instanceof HTMLTextAreaElement;
  let next = head;
  if (key === 'ArrowLeft') next = !extend && start !== end ? start : head - 1;
  else if (key === 'ArrowRight') next = !extend && start !== end ? end : head + 1;
  else if (key === 'Home') next = multiline ? lineStart(head) : 0;
  else if (key === 'End') next = multiline ? lineEnd(head) : value.length;
  else if (key === 'ArrowUp' || key === 'ArrowDown') {
    if (!multiline) next = key === 'ArrowUp' ? 0 : value.length;
    else {
      const column = head - lineStart(head);
      if (key === 'ArrowUp') { const here = lineStart(head); next = here === 0 ? 0 : Math.min(lineStart(here - 1) + column, here - 1); }
      else { const there = lineEnd(head); next = there >= value.length ? value.length : Math.min(there + 1 + column, lineEnd(there + 1)); }
    }
  }
  next = Math.max(0, Math.min(next, value.length));
  if (extend) field.setSelectionRange(Math.min(anchor, next), Math.max(anchor, next), next < anchor ? 'backward' : 'forward');
  else field.setSelectionRange(next, next);
}

function moveFocus(step: number) {
  const scope = document.querySelector('.confirm-dialog') || document;
  const all = [...scope.querySelectorAll<HTMLElement>('button, input, textarea, select, [tabindex]')]
    .filter(el => !(el as HTMLButtonElement).disabled && el.tabIndex >= 0 && el.offsetParent !== null);
  if (!all.length) return;
  const at = all.indexOf(document.activeElement as HTMLElement);
  all[(at + step + all.length) % all.length].focus();
}

function perform(target: HTMLElement, k: KeyMessage) {
  if (k.key === 'Tab') { moveFocus(k.shift ? -1 : 1); return; }
  if (!isField(target)) {
    if ((k.key === 'Enter' || k.key === ' ') && target.matches('button, [role="button"], input[type="checkbox"], input[type="radio"]')) target.click();
    return;
  }
  if (target.disabled || target.readOnly) return;
  // Ctrl+Alt is AltGr on many keyboards, which types a character.
  const shortcut = (k.ctrl || k.meta) && !(k.ctrl && k.alt);
  if (shortcut) {
    const key = k.key.toLowerCase();
    if (key === 'a') target.select();
    else if (key === 'z') document.execCommand(k.shift ? 'redo' : 'undo');
    else if (key === 'y') document.execCommand('redo');
    else if ((key === 'c' || key === 'x') && hasCaret(target)) {
      clipboard = target.value.slice(target.selectionStart ?? 0, target.selectionEnd ?? 0);
      if (key === 'x' && clipboard) insert(target, '');
    } else if (key === 'v' && clipboard) insert(target, target instanceof HTMLTextAreaElement ? clipboard : clipboard.replace(/\n/g, ' '));
    return;
  }
  switch (k.key) {
    case 'Backspace': erase(target, -1); break;
    case 'Delete': erase(target, 1); break;
    case 'Enter':
      if (target instanceof HTMLTextAreaElement) insert(target, '\n');
      else target.form?.requestSubmit();
      break;
    case 'ArrowUp': case 'ArrowDown':
      if (target instanceof HTMLInputElement && target.type === 'number') {
        try { if (k.key === 'ArrowUp') target.stepUp(); else target.stepDown(); } catch { /* not a number yet */ }
        target.dispatchEvent(new Event('input', { bubbles: true }));
      } else moveCaret(target, k.key, k.shift);
      break;
    case 'ArrowLeft': case 'ArrowRight': case 'Home': case 'End': moveCaret(target, k.key, k.shift); break;
    default: if (k.key.length === 1 || /^\p{L}$/u.test(k.key)) insert(target, k.key);
  }
}

function press(k: KeyMessage) {
  const target = document.activeElement instanceof HTMLElement ? document.activeElement : document.body;
  const init: KeyboardEventInit = { key: k.key, code: k.code, shiftKey: k.shift, ctrlKey: k.ctrl, altKey: k.alt,
    metaKey: k.meta, repeat: k.repeat, bubbles: true, cancelable: true };
  if (k.key === 'Escape' && closeSelect()) return;
  if (target.dispatchEvent(new KeyboardEvent('keydown', init))) perform(target, k);
  target.dispatchEvent(new KeyboardEvent('keyup', init));
}

// ── <select> popups ────────────────────────────────────────────────────────

let popup: HTMLElement | null = null;
function closeSelect() {
  if (!popup) return false;
  popup.remove(); popup = null;
  return true;
}

function choose(select: HTMLSelectElement, value: string) {
  Object.getOwnPropertyDescriptor(HTMLSelectElement.prototype, 'value')!.set!.call(select, value);
  select.dispatchEvent(new Event('change', { bubbles: true }));
}

function openSelect(select: HTMLSelectElement) {
  const box = select.getBoundingClientRect();
  const list = document.createElement('div');
  list.className = 'dui-select';
  list.setAttribute('role', 'listbox');
  for (const option of select.options) {
    const item = document.createElement('button');
    item.type = 'button';
    item.textContent = option.textContent;
    item.disabled = option.disabled;
    if (option.selected) item.className = 'selected';
    item.addEventListener('mousedown', event => event.preventDefault());
    item.addEventListener('click', () => { closeSelect(); if (select.value !== option.value) choose(select, option.value); });
    list.appendChild(item);
  }
  list.style.left = `${Math.round(box.left)}px`;
  list.style.minWidth = `${Math.round(box.width)}px`;
  document.body.appendChild(list);
  const below = window.innerHeight - box.bottom - 8;
  if (list.offsetHeight > below && box.top > below) list.style.top = `${Math.max(8, Math.round(box.top - list.offsetHeight - 4))}px`;
  else list.style.top = `${Math.round(box.bottom + 4)}px`;
  list.querySelector<HTMLElement>('.selected')?.scrollIntoView({ block: 'nearest' });
  popup = list;
}

/** Tells the game when a text field gains or loses the caret, so it lends the keyboard. */
function reportTyping(report: (active: boolean) => void) {
  let typing = false;
  const check = () => {
    const now = isField(document.activeElement) && !(document.activeElement as Field).disabled;
    if (now !== typing) { typing = now; report(now); }
  };
  document.addEventListener('focusin', check);
  document.addEventListener('focusout', () => setTimeout(check, 0));
  window.addEventListener('message', event => { if (event.data?.type === 'close') { typing = false; report(false); } });
}

export function installDuiInput(report: (active: boolean) => void) {
  reportTyping(report);
  window.addEventListener('message', event => {
    const data = typeof event.data === 'string' ? (() => { try { return JSON.parse(event.data); } catch { return null; } })() : event.data;
    if (data?.type === 'keys' && Array.isArray(data.keys)) for (const key of data.keys) press(key);
    if (data?.type === 'close') closeSelect();
  });
  document.addEventListener('mousedown', event => {
    const target = event.target as HTMLElement;
    if (popup?.contains(target)) return;
    closeSelect();
    const select = target.closest('select');
    if (!select || select.disabled) return;
    event.preventDefault();
    select.focus();
    openSelect(select);
  }, true);
}
