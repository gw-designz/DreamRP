// The ATM screen. The game opens this page off screen (a DUI) and paints it onto the
// machine's glass; the mouse reaches it through SendDuiMouseMove/Down/Up, so ordinary
// clicks and :hover work. A DUI gets no keyboard, so while a field is focused the
// client gives the keyboard to the bank's own (hidden) page, which passes each key
// back here as a 'type' message.
const params = new URLSearchParams(location.search);
const resourceName = params.get('resource') || 'Renewed-Banking';
const root = document.getElementById('atm');
const isDemo = location.hostname === 'localhost';
if (isDemo) document.body.classList.add('demo');

const state = {
  mode: 'idle', // idle | open | finished
  brand: { logo: ['FL', 'EE', 'CA'] },
  session: null,
  context: null,
  quickAmounts: [1000, 5000, 10000, 50000],
  pageSize: 6,
  selectedKey: null,
  screen: 'select', // select | menu | history | deposit | withdraw | transfer
  history: { items: [], cursor: null, hasMore: false, loading: false, page: 0, key: null },
  form: { amount: '', comment: '', recipient: '' },
  focus: null, // the field being typed into
  requestId: null,
  busy: false,
  notice: null,
  // The machine's own side buttons: the page height (px) of each row, when the machine has them.
  softkeys: null,
  keyHover: null // 'left:0' … the side button under the pointer
};

const ERRORS = {
  INSUFFICIENT_FUNDS: 'Insufficient funds',
  RECIPIENT_NOT_FOUND: 'No player with that ID is online',
  SAME_ACCOUNT: 'You cannot send money to yourself',
  INVALID_AMOUNT: 'Enter a valid amount',
  AMOUNT_TOO_LARGE: 'That amount is too large',
  RATE_LIMITED: 'Please wait a moment',
  UNAUTHORIZED: 'Not allowed on this account',
  ACCOUNT_FROZEN: 'This account is frozen',
  ACCOUNT_CLOSED: 'This account is closed',
  MIGRATION_REQUIRED: 'This account is locked pending migration',
  FRAMEWORK_OPERATION_FAILED: 'The transaction could not be completed'
};

const ACTION_LABELS = { history: 'History', deposit: 'Deposit', withdraw: 'Withdraw', transfer: 'Transfer' };
const DEFAULT_NOTES = { deposit: 'ATM cash deposit', withdraw: 'ATM cash withdrawal', transfer: 'ATM transfer' };

const escapeHtml = (value) => String(value ?? '')
  .replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;')
  .replaceAll('"', '&quot;').replaceAll("'", '&#039;');

const uuid = () => globalThis.crypto?.randomUUID?.() || `${Date.now()}-${Math.random().toString(16).slice(2)}`;

const svg = (body, width = 2.6) => `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="${width}" stroke-linecap="round" stroke-linejoin="round">${body}</svg>`;
const icons = {
  right: svg('<polyline points="9 6 15 12 9 18"/>'),
  left: svg('<polyline points="15 6 9 12 15 18"/>'),
  up: svg('<polyline points="6 15 12 9 18 15"/>'),
  down: svg('<polyline points="6 9 12 15 18 9"/>')
};

async function nui(name, payload = {}) {
  if (isDemo) return mock(name, payload);
  try {
    const response = await fetch(`https://${resourceName}/${name}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json; charset=UTF-8' },
      body: JSON.stringify(payload)
    });
    return await response.json();
  } catch {
    return null;
  }
}

function playSound(sound) { if (!isDemo) nui('uiSound', sound); }

/* ------------------------------------------------------------------ */
/* Demo data (only used when served from localhost)                    */
/* ------------------------------------------------------------------ */

const demo = {
  session: {
    framework: 'qbx', currency: { code: 'USD', symbol: '$', precision: 0 }, migrationRequired: false, capabilities: { sharedAccounts: true },
    accounts: [
      { kind: 'personal', key: 'DEMO1001', displayName: 'Alex Morgan', accountType: 'personal', balance: 3556, cash: 1000, status: 'active', role: 'owner', permissions: { view: true, deposit: true, withdraw: true, transfer: true } },
      { kind: 'database', key: 'police', displayName: 'Los Santos Police Department', accountType: 'job', balance: 875000, status: 'active', role: 'group', permissions: { view: true, deposit: true, withdraw: true, transfer: true } }
    ]
  },
  transactions: [
    { id: 2, direction: 'debit', transaction_type: 'cash_withdrawal', amount: 1000, counterparty_ref: 'cash', description: 'ATM cash withdrawal', created_at: new Date().toISOString() },
    { id: 1, direction: 'debit', transaction_type: 'cash_withdrawal', amount: 1000, counterparty_ref: 'cash', description: 'ATM cash withdrawal', created_at: new Date().toISOString() }
  ]
};

function mock(name, p) {
  const ok = (data) => Promise.resolve({ ok: true, data });
  const acct = demo.session.accounts.find((a) => a.key === p.sourceKey);
  switch (name) {
    case 'getSession': return ok(structuredClone(demo.session));
    case 'transactions': return ok({ items: [...demo.transactions], nextCursor: null, hasMore: false });
    case 'withdraw':
    case 'transfer':
    case 'deposit': {
      const amount = Number(p.amount);
      if (name !== 'deposit' && acct.balance < amount) return Promise.resolve({ ok: false, error: { code: 'INSUFFICIENT_FUNDS' } });
      acct.balance += name === 'deposit' ? amount : -amount;
      demo.transactions.unshift({ id: Date.now(), direction: name === 'deposit' ? 'credit' : 'debit', transaction_type: name, amount, counterparty_ref: name === 'transfer' ? p.recipientKey : 'cash', description: p.description, created_at: new Date().toISOString() });
      return ok({ status: 'committed' });
    }
    case 'atmFinish': setTimeout(() => { state.mode = 'idle'; render(); }, 0); return ok(true);
    default: return ok(true);
  }
}

/* ------------------------------------------------------------------ */
/* Helpers                                                              */
/* ------------------------------------------------------------------ */

const accounts = () => (state.session?.accounts || []).filter((item) => item.permissions?.view !== false);
const account = () => accounts().find((item) => item.key === state.selectedKey) || accounts()[0];

function factor() { return 10 ** (state.session?.currency?.precision || 0); }

function money(value) {
  const currency = state.session?.currency || { code: 'USD', precision: 0 };
  const digits = currency.precision || 0;
  return new Intl.NumberFormat('en-US', { style: 'currency', currency: currency.code || 'USD', minimumFractionDigits: digits, maximumFractionDigits: digits }).format((Number(value) || 0) / factor());
}

const sentence = (value) => { const text = String(value || '').replaceAll('_', ' '); return text.charAt(0).toUpperCase() + text.slice(1); };

function accountName(item) {
  return item.kind === 'personal' ? 'Personal' : item.displayName;
}

function actions() {
  const selected = account();
  const location = state.context?.capabilities || {};
  const permission = selected?.permissions || {};
  return ['history', 'deposit', 'withdraw', 'transfer'].filter((key) => key === 'history' || (location[key] !== false && permission[key] === true));
}

function errorText(result, fallback = 'The transaction could not be completed') {
  const code = result?.error?.code;
  return ERRORS[code] || result?.error?.message || fallback;
}

let noticeTimer = null;
function notice(text, kind = 'ok') {
  state.notice = { text, kind };
  playSound(kind === 'error' ? 'error' : 'success');
  clearTimeout(noticeTimer);
  noticeTimer = setTimeout(() => { state.notice = null; render(); }, 3200);
  render();
}

/* ------------------------------------------------------------------ */
/* Rendering                                                            */
/* ------------------------------------------------------------------ */

function logo(size = '') {
  const [a, b, c] = state.brand?.logo || ['FL', 'EE', 'CA'];
  return `<div class="logo ${size}">${escapeHtml(a)}<span>${escapeHtml(b)}</span>${escapeHtml(c)}</div>`;
}

const backButton = () => `<button class="back" data-action="back"><i>${icons.left}</i><span>Back</span></button>`;

function render() {
  const view = state.mode === 'open' ? state.screen : state.mode;
  root.className = `atm view-${view}`;
  root.innerHTML = `
    <div class="bg"><div class="city"></div><div class="slope"></div></div>
    <div class="content">${content(view)}</div>
    ${renderSoftkeyLabels(view)}
    ${state.notice ? `<div class="notice ${state.notice.kind}">${escapeHtml(state.notice.text)}</div>` : ''}`;
}

/* ------------------------------------------------------------------ */
/* The machine's side buttons                                           */
/* ------------------------------------------------------------------ */

function menuItems() {
  return [...actions().map((key) => [key, ACTION_LABELS[key]]), ['finish', 'Finish']];
}

const runMenu = (key) => () => (key === 'finish' ? finish() : go(key));

// The menu in columns beside the side buttons: one column when it fits beside the
// left buttons, otherwise the rest beside the right ones, from the bottom row up.
function menuColumns() {
  const items = menuItems();
  const rows = state.softkeys?.rows.length || 4;
  if (items.length <= rows) return { left: items, right: items, split: false };
  const right = items.slice(rows);
  return { left: items.slice(0, rows), right: [...Array(rows - right.length).fill(null), ...right], split: true };
}

// What each side button does on the current screen: { left: [...], right: [...] },
// each entry { label, run } or null, top row first.
function softkeys(view) {
  const none = { left: [], right: [] };
  if (!state.softkeys || state.mode !== 'open') return none;
  const entry = (label, run) => ({ label, run });
  if (view === 'select') {
    const many = accounts().length > 1;
    return {
      left: [null, null, null, entry('Back', back)],
      right: [many ? entry('Previous', () => cycleAccount(-1)) : null, many ? entry('Next', () => cycleAccount(1)) : null, null, entry('Confirm', () => go('menu'))]
    };
  }
  if (view === 'menu') {
    const { left, right } = menuColumns();
    const wrap = (item) => item && entry(item[1], runMenu(item[0]));
    return { left: left.map(wrap), right: right.map(wrap) };
  }
  const left = actions().map((key) => entry(ACTION_LABELS[key], () => go(key)));
  if (view === 'history') return { left, right: [entry('Previous', () => changePage(-1)), entry('Next', () => changePage(1))] };
  return { left, right: state.quickAmounts.map((value) => entry(money(value * factor()), () => { state.form.amount = String(value); render(); })) };
}

// `silent`: already sounded (the machine beeps for its own buttons).
function pressSoftkey(side, index, silent = false) {
  const view = state.mode === 'open' ? state.screen : state.mode;
  const key = softkeys(view)[side]?.[index];
  if (!key || state.busy) return;
  if (!silent) playSound('click');
  blurField();
  key.run();
}

function renderSoftkeyLabels(view) {
  // The menu's own buttons sit beside the side buttons, so it needs no labels.
  if (!state.softkeys || view === 'menu') return '';
  const keys = softkeys(view);
  return ['left', 'right'].map((side) => keys[side].map((key, index) => {
    const top = state.softkeys.rows[index];
    if (!key || top === undefined) return '';
    const hover = state.keyHover === `${side}:${index}` ? 'hover' : '';
    return `<button class="softkey ${side} ${hover}" data-softkey="${side}:${index}" style="top:${top}px">${side === 'left' ? `<i>${icons.left}</i>` : ''}<span>${escapeHtml(key.label)}</span>${side === 'right' ? `<i>${icons.right}</i>` : ''}</button>`;
  }).join('')).join('');
}

function content(view) {
  if (view === 'idle') return `
    <div class="center">
      ${logo('xl')}
      <p class="idle-title">Welcome</p>
      <p class="idle-sub">Use this machine to access your accounts</p>
    </div>`;
  if (view === 'finished') return `
    <div class="center">
      ${logo('xl')}
      <p class="idle-title">Thank you</p>
      <p class="idle-sub">Please take your card</p>
    </div>`;
  if (view === 'select') return renderSelect();
  if (view === 'menu') return renderMenu();
  return renderTab(view);
}

function renderSelect() {
  const selected = account();
  if (!selected) return `<div class="center">${logo('lg')}<p class="idle-sub">No accessible accounts found.</p></div>${backButton()}`;
  const many = accounts().length > 1;
  return `
    <div class="center">
      ${logo('lg')}
      <div class="select-label">Select your account</div>
      <div class="picker">
        <button class="picker-main" data-action="next">
          <span class="picker-name">${escapeHtml(accountName(selected))}</span>
          <span class="picker-sub">#${escapeHtml(selected.key)} · ${money(selected.balance)}</span>
        </button>
        ${many ? `<div class="picker-arrows">
          <button data-action="prev">${icons.up}</button>
          <button data-action="next">${icons.down}</button>
        </div>` : ''}
      </div>
      <button class="menu-btn dark" data-action="confirm"><i>${icons.right}</i><span>Confirm</span></button>
    </div>
    ${backButton()}`;
}

function renderMenu() {
  if (!state.softkeys) {
    return `
      ${logo('corner')}
      <div class="menu">
        ${menuItems().map(([key, label]) => `<button class="menu-btn" data-menu="${key}"><i>${icons.right}</i><span>${label}</span></button>`).join('')}
      </div>
      ${backButton()}`;
  }
  // Each row level with a side button, so pressing that button picks it.
  const { left, right, split } = menuColumns();
  const button = (item, index, side) => {
    if (!item) return '';
    const hover = state.keyHover === `${side}:${index}` || (!split && state.keyHover?.endsWith(`:${index}`));
    const column = split ? side : 'wide';
    return `<button class="menu-btn keyed ${column} ${hover ? 'key-hover' : ''}" data-menu="${item[0]}" style="top:${state.softkeys.rows[index]}px"><i>${icons.right}</i><span>${item[1]}</span></button>`;
  };
  return `
    ${logo('corner')}
    ${left.map((item, index) => button(item, index, 'left')).join('')}
    ${split ? right.map((item, index) => button(item, index, 'right')).join('') : ''}
    ${backButton()}`;
}

function renderTab(view) {
  const selected = account();
  const tabs = actions();
  return `
    <header class="top">
      ${logo('sm')}
      <nav class="tabs">
        <span class="keycap">Q</span>
        ${tabs.map((key) => `<button class="tab ${key === view ? 'active' : ''}" data-tab="${key}">${ACTION_LABELS[key]}</button>`).join('')}
        <span class="keycap">E</span>
      </nav>
      <div class="balance"><small>Your balance</small><b>${money(selected?.balance)}</b></div>
    </header>
    <main class="main">${view === 'history' ? renderHistory() : renderForm(view, selected)}</main>
    ${backButton()}`;
}

function renderHistory() {
  const { items, loading, page } = state.history;
  const size = state.pageSize;
  const pages = Math.max(1, Math.ceil(items.length / size) + (state.history.hasMore ? 1 : 0));
  const rows = items.slice(page * size, page * size + size);
  const body = loading && !rows.length ? '<div class="empty"><div class="spinner"></div></div>'
    : !rows.length ? '<div class="empty">No recent transactions</div>'
      : rows.map((tx) => {
        const credit = tx.direction === 'credit';
        return `
          <div class="tr">
            <span class="desc">${escapeHtml(tx.description || sentence(tx.transaction_type))}</span>
            <span class="muted">${escapeHtml(sentence(tx.counterparty_ref) || '—')}</span>
            <span class="r ${credit ? 'credit' : 'debit'}">${credit ? '+' : '-'}${money(tx.amount)}</span>
          </div>`;
      }).join('');
  return `
    <div class="table">
      <div class="thead"><span>Description</span><span>Recipient</span><span class="r">Amount</span></div>
      <div class="tbody">${body}</div>
    </div>
    <div class="pager">
      <button data-action="page-prev" ${page <= 0 ? 'disabled' : ''}>${icons.left}</button>
      <span>${page + 1} / ${pages}</span>
      <button data-action="page-next" ${page + 1 >= pages ? 'disabled' : ''}>${icons.right}</button>
    </div>`;
}

// A text box drawn by the page: its text, a caret while it is being typed into,
// and the placeholder when it is empty and not focused.
function field(name, value, placeholder, prefix = '') {
  const focused = state.focus === name;
  // While typing, a long comment shows its end, where the caret is.
  const shown = focused && value.length > 46 ? `…${value.slice(-45)}` : value;
  const text = value ? `<span class="value">${escapeHtml(shown)}</span>`
    : focused ? '' : `<span class="placeholder">${escapeHtml(placeholder)}</span>`;
  return `<button class="field ${name === 'amount' ? 'amount' : ''} ${focused ? 'focused' : ''}" data-input="${name}">${prefix}<span class="text">${text}${focused ? '<i class="caret"></i>' : ''}</span></button>`;
}

function renderForm(action, selected) {
  const transfer = action === 'transfer';
  const cash = accounts().find((item) => item.kind === 'personal')?.cash;
  const titles = { deposit: 'Deposit money', withdraw: 'Withdraw money', transfer: 'Transfer money' };
  const feet = {
    deposit: `Deposits are taken from your cash on hand${cash !== undefined ? ` (${money(cash)})` : ''}`,
    withdraw: 'Withdrawals will be disbursed as cash',
    transfer: "Transfers are sent directly to the recipient's bank account"
  };
  const amount = state.form.amount;
  const shownAmount = amount ? `${Number(amount.split('.')[0]).toLocaleString('en-US')}${amount.includes('.') ? `.${amount.split('.')[1]}` : ''}` : '';
  return `
    <div class="card">
      <div class="card-head"><b>${titles[action]}</b><span>Account balance: <em>${money(selected?.balance)}</em></span></div>
      <div class="card-body">
        ${transfer ? `
          <label>Recipient — online player server ID</label>
          ${field('recipient', state.form.recipient, 'Player ID')}` : ''}
        <label>Amount</label>
        ${field('amount', shownAmount, '0', '<b>$</b>')}
        <div class="chips">
          ${state.quickAmounts.map((value) => `<button class="chip" data-quick="${value}">${money(value * factor())}</button>`).join('')}
        </div>
        <label>Comment (optional)</label>
        ${field('comment', state.form.comment, "What's this for?")}
        <button class="submit" data-action="submit" ${state.busy ? 'disabled' : ''}>${state.busy ? 'Processing…' : ACTION_LABELS[action]}</button>
        <p class="foot">${escapeHtml(feet[action])}</p>
      </div>
    </div>`;
}

/* ------------------------------------------------------------------ */
/* Actions                                                              */
/* ------------------------------------------------------------------ */

function resetForm() {
  state.form = { amount: '', comment: '', recipient: '' };
  state.requestId = uuid();
}

async function refreshSession() {
  const result = await nui('getSession', {});
  if (result?.ok) state.session = result.data;
}

async function loadHistory(append = false) {
  const selected = account();
  if (!selected) return;
  const history = state.history;
  if (!append) { history.items = []; history.cursor = null; history.hasMore = false; history.page = 0; }
  history.loading = true; history.key = selected.key; render();
  const result = await nui('transactions', { accountKey: selected.key, cursor: append ? history.cursor : null, limit: 30, filters: {} });
  history.loading = false;
  if (history.key !== selected.key) return;
  if (!result?.ok) { render(); return notice(errorText(result, 'Could not load history'), 'error'); }
  history.items = append ? [...history.items, ...result.data.items] : result.data.items;
  history.cursor = result.data.nextCursor; history.hasMore = result.data.hasMore;
  render();
}

function go(screen) {
  if (state.busy) return;
  blurField();
  state.screen = screen;
  state.notice = null;
  if (['deposit', 'withdraw', 'transfer'].includes(screen)) resetForm();
  render();
  if (screen === 'history') loadHistory();
}

function cycleAccount(step) {
  const list = accounts();
  if (list.length < 2) return;
  const index = list.findIndex((item) => item.key === account()?.key);
  state.selectedKey = list[(index + step + list.length) % list.length].key;
  render();
}

function cycleTab(step) {
  const tabs = actions();
  const index = tabs.indexOf(state.screen);
  if (index < 0) return;
  go(tabs[(index + step + tabs.length) % tabs.length]);
}

async function changePage(step) {
  const history = state.history;
  const size = state.pageSize;
  const next = history.page + step;
  if (next < 0) return;
  if (next * size >= history.items.length) {
    if (!history.hasMore || history.loading) return;
    await loadHistory(true);
    if (next * size >= history.items.length) return;
  }
  history.page = next;
  render();
}

function finish() {
  if (state.busy) return;
  blurField();
  state.mode = 'finished';
  render();
  setTimeout(() => nui('atmFinish', {}), 1200);
}

function back() {
  if (state.busy || state.mode !== 'open') return;
  if (state.screen === 'select') return finish();
  if (state.screen === 'menu') return go('select');
  go('menu');
}

/* ------------------------------------------------------------------ */
/* Typing                                                               */
/* ------------------------------------------------------------------ */

const FIELD_LIMITS = { amount: 12, recipient: 6, comment: 160 };

function fieldOrder() {
  return state.screen === 'transfer' ? ['recipient', 'amount', 'comment'] : ['amount', 'comment'];
}

// What a field may hold: the amount in whole units (or with decimals when the
// currency has them), the recipient's server ID in digits, the comment as written.
function clean(name, value) {
  const limit = FIELD_LIMITS[name];
  if (name === 'comment') return value.replace(/[\u0000-\u001f]/g, '').slice(0, limit);
  if (name === 'recipient') return value.replace(/\D/g, '').slice(0, limit);
  const precision = state.session?.currency?.precision || 0;
  let digits = value.replace(precision ? /[^\d.]/g : /\D/g, '');
  if (precision) {
    const [whole, ...rest] = digits.split('.');
    digits = rest.length ? `${whole}.${rest.join('').slice(0, precision)}` : whole;
  }
  return digits.replace(/^0+(?=\d)/, '').slice(0, limit);
}

function focusField(name) {
  if (state.busy || state.focus === name) return;
  const had = state.focus;
  state.focus = name;
  render();
  if (!had) nui('atmFocus', { active: true });
}

function blurField() {
  if (!state.focus) return;
  state.focus = null;
  render();
  nui('atmFocus', { active: false });
}

// One key from the keyboard ({ key }) or pasted text ({ text }).
function typeKey(message) {
  const name = state.focus;
  if (!name) return;
  if (message.text) { state.form[name] = clean(name, state.form[name] + message.text); return render(); }
  const key = message.key;
  if (key === 'Escape') return blurField();
  if (key === 'Enter') { blurField(); return submit(); }
  if (key === 'Tab') {
    const order = fieldOrder();
    const next = order[(order.indexOf(name) + (message.shift ? -1 : 1) + order.length) % order.length];
    state.focus = next;
    return render();
  }
  if (key === 'Backspace') state.form[name] = state.form[name].slice(0, -1);
  else if (key === 'Delete') state.form[name] = '';
  else if (typeof key === 'string' && key.length === 1) state.form[name] = clean(name, state.form[name] + key);
  else return;
  render();
}

async function submit() {
  if (state.busy) return;
  const action = state.screen;
  if (!['deposit', 'withdraw', 'transfer'].includes(action)) return;
  blurField();
  const selected = account();
  if (!(Number(state.form.amount) > 0)) return notice('Enter an amount', 'error');
  if (action === 'transfer' && !(Number(state.form.recipient) > 0)) return notice('Enter the recipient’s server ID', 'error');
  const payload = {
    requestId: state.requestId || uuid(),
    sourceKey: selected.key,
    amount: state.form.amount,
    description: state.form.comment || DEFAULT_NOTES[action]
  };
  if (action === 'transfer') { payload.recipientType = 'server'; payload.recipientKey = state.form.recipient; }
  state.busy = true; render();
  const result = await nui(action, payload);
  state.busy = false;
  // A request that reached the server is spent: a retry needs a new id.
  if (result) state.requestId = uuid();
  if (!result?.ok) { render(); return notice(errorText(result), 'error'); }
  const amount = money(Number(state.form.amount) * factor());
  const done = { deposit: `Deposited ${amount}`, withdraw: `Withdrew ${amount}`, transfer: `Sent ${amount} to ID ${state.form.recipient}` };
  resetForm();
  await refreshSession();
  notice(done[action]);
}

/* ------------------------------------------------------------------ */
/* Events                                                               */
/* ------------------------------------------------------------------ */

root.addEventListener('click', (event) => {
  const target = event.target.closest?.('button');
  // A click anywhere but the field being typed into ends the typing.
  if (state.focus && target?.dataset.input !== state.focus) blurField();
  if (!target || target.disabled || state.mode !== 'open') return;
  playSound('click');
  const { action, menu, tab, input, quick, softkey } = target.dataset;
  // The click above already sounded.
  if (softkey) { const [side, index] = softkey.split(':'); return pressSoftkey(side, Number(index), true); }
  if (menu) return menu === 'finish' ? finish() : go(menu);
  if (tab) return go(tab);
  if (input) return focusField(input);
  if (quick) { state.form.amount = quick; return render(); }
  if (action === 'next') return cycleAccount(1);
  if (action === 'prev') return cycleAccount(-1);
  if (action === 'confirm') return go('menu');
  if (action === 'back') return back();
  if (action === 'page-prev') return changePage(-1);
  if (action === 'page-next') return changePage(1);
  if (action === 'submit') return submit();
});

// The client forwards the mouse wheel with SendDuiMouseWheel.
let lastWheel = 0;
window.addEventListener('wheel', (event) => {
  if (state.mode !== 'open' || Date.now() - lastWheel < 120) return;
  lastWheel = Date.now();
  const step = event.deltaY > 0 ? 1 : -1;
  if (state.screen === 'select') cycleAccount(step);
  else if (state.screen === 'history') changePage(step);
});

function open(payload) {
  state.mode = 'open';
  state.session = payload.session;
  state.context = payload.context;
  if (payload.brand) state.brand = payload.brand;
  if (Array.isArray(payload.quickAmounts) && payload.quickAmounts.length) state.quickAmounts = payload.quickAmounts;
  if (payload.pageSize) state.pageSize = payload.pageSize;
  state.softkeys = Array.isArray(payload.softkeys?.rows) && payload.softkeys.rows.length ? payload.softkeys : null;
  state.keyHover = null;
  state.selectedKey = accounts()[0]?.key;
  state.busy = false; state.notice = null; state.focus = null;
  resetForm();
  state.screen = 'select';
  render();
}

window.addEventListener('message', (event) => {
  const message = typeof event.data === 'string' ? JSON.parse(event.data) : event.data || {};
  if (message.type === 'idle') {
    if (message.brand) state.brand = message.brand;
    state.mode = 'idle'; state.session = null; state.busy = false; state.notice = null; state.focus = null;
    render();
  }
  if (message.type === 'type' && state.mode === 'open') typeKey(message);
  if (message.type === 'open') open(message.payload || {});
  // The machine's side buttons, pressed and pointed at in the world.
  if (message.type === 'softkey' && state.mode === 'open') pressSoftkey(message.side, message.index, true);
  if (message.type === 'softkeyHover') {
    const hover = message.side ? `${message.side}:${message.index}` : null;
    if (hover !== state.keyHover) { state.keyHover = hover; render(); }
  }
  if (message.type === 'key' && state.mode === 'open') {
    if (message.key === 'back') back();
    if (message.key === 'q') cycleTab(-1);
    if (message.key === 'e') cycleTab(1);
  }
});

render();
if (isDemo) {
  open({ session: structuredClone(demo.session), context: { type: 'atm', capabilities: { deposit: false, withdraw: true, transfer: true } }, softkeys: { rows: [147, 321, 492, 661] } });
  // In the browser the keyboard reaches this page directly.
  window.addEventListener('keydown', (event) => { if (state.focus) { event.preventDefault(); typeKey({ key: event.key, shift: event.shiftKey }); } });
  const view = location.hash.slice(1);
  if (view === 'idle') { state.mode = 'idle'; render(); } else if (view) go(view);
}
