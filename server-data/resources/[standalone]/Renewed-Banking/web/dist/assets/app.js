const resourceName = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'Renewed-Banking';
const root = document.getElementById('app');
const isDemo = location.hostname === 'localhost';
if (isDemo) document.body.classList.add('demo');

const TABS = ['accounts', 'paychecks', 'bills'];
const TAB_LABELS = { accounts: 'Accounts', paychecks: 'Paychecks', bills: 'Bills' };
const FILTERS = { all: 'All', deposits: 'Deposits', withdrawals: 'Withdrawals', transfers: 'Transfers' };

const state = {
  visible: false,
  session: null,
  context: null,
  selectedKey: null,
  tab: 'accounts',
  subtab: 'history',
  search: '',
  filter: 'all',
  transactions: [],
  nextCursor: null,
  hasMore: false,
  loading: false,
  paychecks: { items: [], loading: false, error: null, loaded: false },
  bills: { items: [], loading: false, error: null, loaded: false },
  collectKey: null,
  payKey: null,
  busy: false,
  requestId: null,
  modal: null,
  brand: { logo: ['FL', 'EE', 'CA'], tagline: 'Fleeca · FDIC insured · Member DIC' }
};

const escapeHtml = (value) => String(value ?? '')
  .replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;')
  .replaceAll('"', '&quot;').replaceAll("'", '&#039;');

const uuid = () => globalThis.crypto?.randomUUID?.() || `${Date.now()}-${Math.random().toString(16).slice(2)}`;

const svg = (size, body, width = 2.2) => `<svg width="${size}" height="${size}" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="${width}" stroke-linecap="round" stroke-linejoin="round">${body}</svg>`;
const icons = {
  close: svg(18, '<line x1="18" y1="6" x2="6" y2="18"/><line x1="6" y1="6" x2="18" y2="18"/>', 2.5),
  plus: svg(16, '<line x1="12" y1="5" x2="12" y2="19"/><line x1="5" y1="12" x2="19" y2="12"/>', 2.5),
  empty: svg(48, '<rect width="20" height="14" x="2" y="5" rx="2"/><line x1="2" x2="22" y1="10" y2="10"/>', 1.5),
  move: svg(20, '<path d="M5 9l-3 3 3 3M9 5l3-3 3 3M15 19l-3 3-3-3M19 9l3 3-3 3M2 12h20M12 2v20"/>', 2),
  enter: svg(20, '<path d="M20 4v7a4 4 0 0 1-4 4H4"/><path d="m9 10-5 5 5 5"/>', 2)
};

// UI feedback sounds. The client plays the matching native GTA frontend sound (mapped in client/nui.lua).
// Minimum time between two plays of the same sound, so sweeping the cursor doesn't spam the client.
const SOUND_INTERVAL = { hover: 50, click: 0, success: 0, error: 0 };
const soundLastPlayed = {};

function playSound(sound) {
  if (isDemo) return;
  const now = Date.now();
  if (now - (soundLastPlayed[sound] ?? 0) < SOUND_INTERVAL[sound]) return;
  soundLastPlayed[sound] = now;
  fetch(`https://${resourceName}/uiSound`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json; charset=UTF-8' },
    body: JSON.stringify(sound)
  }).catch(() => {});
}

async function nui(name, payload = {}) {
  if (isDemo) return mock(name, payload);
  const response = await fetch(`https://${resourceName}/${name}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json; charset=UTF-8' },
    body: JSON.stringify(payload)
  });
  return response.json();
}

/* ------------------------------------------------------------------ */
/* Demo data (only used when served from localhost)                    */
/* ------------------------------------------------------------------ */

const ago = (ms) => new Date(Date.now() - ms).toISOString();
const MIN = 60000, HOUR = 3600000, DAY = 86400000;

const demo = {
  session: {
    framework: 'esx', currency: { code: 'USD', symbol: '$', precision: 0 },
    migrationRequired: false, capabilities: { sharedAccounts: true },
    accounts: [
      { kind: 'personal', key: 'DEMO1001', displayName: 'Alex Morgan', accountType: 'personal', balance: 24500, cash: 1350, status: 'active', role: 'owner', permissions: { view: true, deposit: true, withdraw: true, transfer: true } },
      { kind: 'database', key: 'police', displayName: 'Los Santos Police Department', accountType: 'job', balance: 875000, status: 'active', role: 'group', permissions: { view: true, deposit: true, withdraw: true, transfer: true } },
      { kind: 'database', key: 'family_savings', displayName: 'Family Savings', accountType: 'shared', balance: 64250, status: 'active', role: 'owner', permissions: { view: true, deposit: true, withdraw: true, transfer: true, members: true, rename: true, close: true } }
    ]
  },
  transactions: {
    DEMO1001: [
      { id: 3, direction: 'credit', transaction_type: 'cash_deposit', amount: 2500, counterparty_ref: '', description: 'Cash deposit', created_at: ago(4 * MIN), group_id: 'demo-3' },
      { id: 2, direction: 'debit', transaction_type: 'transfer_debit', amount: 1250, counterparty_ref: 'ambulance', description: 'Equipment reimbursement', created_at: ago(HOUR), group_id: 'demo-2' },
      { id: 1, direction: 'credit', transaction_type: 'migration_credit', amount: 23250, counterparty_ref: 'legacy_v2', description: 'Imported opening balance', created_at: ago(DAY), group_id: 'demo-1' }
    ],
    police: [{ id: 4, direction: 'credit', transaction_type: 'transfer_credit', amount: 12000, counterparty_ref: 'state', description: 'Quarterly budget', created_at: ago(2 * DAY), group_id: 'demo-4' }],
    family_savings: [{ id: 5, direction: 'credit', transaction_type: 'cash_deposit', amount: 5000, counterparty_ref: '', description: 'Monthly savings', created_at: ago(3 * DAY), group_id: 'demo-5' }]
  },
  paychecks: [
    { id: 'pc-1', source: 'Los Santos Police Department', job: 'police', grade: 'Sergeant', amount: 1850, accrued_at: ago(20 * MIN) },
    { id: 'pc-2', source: 'Los Santos Police Department', job: 'police', grade: 'Sergeant', amount: 1850, accrued_at: ago(HOUR + 20 * MIN) },
    { id: 'pc-3', source: 'Pillbox Medical', job: 'ambulance', grade: 'Paramedic', amount: 1420, accrued_at: ago(DAY) }
  ],
  bills: [
    { id: 'b-1', issuer: 'Los Santos Water & Power', reason: 'Utilities — September', amount: 340, issued_at: ago(6 * DAY), due_at: new Date(Date.now() + 3 * DAY).toISOString() },
    { id: 'b-2', issuer: 'Los Santos Police Department', reason: 'Speeding ticket', amount: 750, issued_at: ago(12 * DAY), due_at: new Date(Date.now() - 2 * DAY).toISOString() },
    { id: 'b-3', issuer: 'Dynasty 8 Real Estate', reason: 'Rent — Eclipse Towers', amount: 2200, issued_at: ago(2 * DAY), due_at: new Date(Date.now() + 5 * DAY).toISOString() }
  ]
};

function mock(name, p) {
  const ok = (data) => Promise.resolve({ ok: true, data });
  const bad = (code, message) => Promise.resolve({ ok: false, error: { code, message } });
  const acct = (key) => demo.session.accounts.find((a) => a.key === key);
  const personal = () => demo.session.accounts.find((a) => a.kind === 'personal');
  const addTx = (key, direction, type, amount, ref, description) => {
    (demo.transactions[key] ||= []).unshift({ id: Date.now() + Math.random(), direction, transaction_type: type, amount, counterparty_ref: ref, description, created_at: new Date().toISOString(), group_id: uuid() });
  };
  const amount = Number(p.amount);

  switch (name) {
    case 'getSession': return ok(structuredClone(demo.session));
    case 'transactions': return ok({ items: [...(demo.transactions[p.accountKey] || [])], nextCursor: null, hasMore: false });
    case 'deposit': {
      const a = acct(p.sourceKey), me = personal();
      if (!(amount > 0)) return bad('INVALID_AMOUNT', 'Enter a valid amount.');
      if (me.cash < amount) return bad('INSUFFICIENT_CASH', 'You do not have enough cash on hand.');
      me.cash -= amount; a.balance += amount; addTx(a.key, 'credit', 'cash_deposit', amount, '', p.description || 'Cash deposit');
      return ok({ groupId: uuid(), status: 'committed' });
    }
    case 'withdraw': {
      const a = acct(p.sourceKey), me = personal();
      if (!(amount > 0)) return bad('INVALID_AMOUNT', 'Enter a valid amount.');
      if (a.balance < amount) return bad('INSUFFICIENT_FUNDS', 'Insufficient funds.');
      a.balance -= amount; me.cash += amount; addTx(a.key, 'debit', 'cash_withdrawal', amount, '', p.description || 'Cash withdrawal');
      return ok({ groupId: uuid(), status: 'committed' });
    }
    case 'transfer': {
      const a = acct(p.sourceKey), target = acct(p.recipientKey);
      if (!(amount > 0)) return bad('INVALID_AMOUNT', 'Enter a valid amount.');
      if (a.balance < amount) return bad('INSUFFICIENT_FUNDS', 'Insufficient funds.');
      a.balance -= amount; addTx(a.key, 'debit', 'transfer_debit', amount, p.recipientKey, p.description || 'Transfer');
      if (target) { target.balance += amount; addTx(target.key, 'credit', 'transfer_credit', amount, a.key, p.description || 'Transfer'); }
      return ok({ groupId: uuid(), status: 'committed' });
    }
    case 'getPaychecks': return ok({ items: structuredClone(demo.paychecks) });
    case 'collectPaycheck':
    case 'collectAllPaychecks': {
      const dest = acct(p.destinationKey) || personal();
      const picked = name === 'collectAllPaychecks' ? demo.paychecks : demo.paychecks.filter((c) => c.id === p.paycheckId);
      if (!picked.length) return bad('NOT_FOUND', 'That paycheck is no longer available.');
      const total = picked.reduce((sum, c) => sum + c.amount, 0);
      dest.balance += total;
      picked.forEach((c) => addTx(dest.key, 'credit', 'paycheck', c.amount, c.job, `Paycheck — ${c.source}`));
      demo.paychecks = demo.paychecks.filter((c) => !picked.includes(c));
      return ok({ total });
    }
    case 'getBills': return ok({ items: structuredClone(demo.bills) });
    case 'payBill':
    case 'payAllBills': {
      const src = acct(p.sourceKey) || personal();
      const queue = name === 'payAllBills' ? [...demo.bills] : demo.bills.filter((b) => b.id === p.billId);
      if (!queue.length) return bad('NOT_FOUND', 'That bill no longer exists.');
      let paid = 0;
      for (const bill of queue) {
        if (src.balance < bill.amount) break;
        src.balance -= bill.amount; paid += bill.amount;
        addTx(src.key, 'debit', 'bill_payment', bill.amount, bill.issuer, `Bill — ${bill.reason}`);
        demo.bills = demo.bills.filter((b) => b !== bill);
      }
      return paid ? ok({ total: paid }) : bad('INSUFFICIENT_FUNDS', 'Insufficient funds to pay this bill.');
    }
    default: return ok({ groupId: uuid(), status: 'committed' });
  }
}

/* ------------------------------------------------------------------ */
/* Helpers                                                              */
/* ------------------------------------------------------------------ */

function account() {
  return state.session?.accounts?.find((item) => item.key === state.selectedKey) || state.session?.accounts?.[0];
}
const personalAccount = () => state.session?.accounts?.find((item) => item.kind === 'personal');

function money(value) {
  const currency = state.session?.currency || { code: 'USD', precision: 0 };
  const factor = 10 ** (currency.precision || 0);
  return new Intl.NumberFormat('en-US', { style: 'currency', currency: currency.code || 'USD', minimumFractionDigits: currency.precision || 0, maximumFractionDigits: currency.precision || 0 }).format((Number(value) || 0) / factor);
}

function timeAgo(value) {
  const parsed = value ? new Date(value).valueOf() : NaN;
  if (Number.isNaN(parsed)) return '—';
  const diff = Math.max(0, Date.now() - parsed);
  if (diff < MIN) return 'just now';
  if (diff < HOUR) return `${Math.floor(diff / MIN)}m ago`;
  if (diff < DAY) return `${Math.floor(diff / HOUR)}h ago`;
  if (diff < 30 * DAY) return `${Math.floor(diff / DAY)}d ago`;
  return new Intl.DateTimeFormat('en-US', { dateStyle: 'medium' }).format(new Date(parsed));
}

function dueLabel(value) {
  const due = value ? new Date(value).valueOf() : NaN;
  if (Number.isNaN(due)) return { text: 'No due date', overdue: false };
  const diff = due - Date.now();
  const days = Math.ceil(Math.abs(diff) / DAY);
  if (diff < 0) return { text: `Overdue ${days}d`, overdue: true };
  if (diff < DAY) return { text: 'Due today', overdue: false };
  return { text: `Due in ${days}d`, overdue: false };
}

const sentence = (value) => { const text = String(value || '').replaceAll('_', ' '); return text.charAt(0).toUpperCase() + text.slice(1); };

function errorMessage(result, fallback = 'The banking request failed.') {
  return result?.error?.message || result?.error?.code || fallback;
}

function capabilities() {
  const selected = account();
  const location = state.context?.capabilities || {};
  const permission = selected?.permissions || {};
  return {
    deposit: location.deposit !== false && permission.deposit === true,
    withdraw: location.withdraw !== false && permission.withdraw === true,
    transfer: location.transfer !== false && permission.transfer === true,
    members: permission.members === true,
    create: location.createSharedAccount === true && state.session?.capabilities?.sharedAccounts === true
  };
}

function subtabs() {
  const caps = capabilities();
  return [
    ['history', 'History'],
    caps.deposit && ['deposit', 'Deposit'],
    caps.withdraw && ['withdraw', 'Withdraw'],
    caps.transfer && ['transfer', 'Transfer'],
    caps.members && ['members', 'Members']
  ].filter(Boolean);
}

function toast(message, kind = 'info') {
  playSound(kind === 'error' ? 'error' : 'success');
  root.querySelector('.toast')?.remove();
  const el = document.createElement('div');
  el.className = `toast ${kind === 'error' ? 'error' : ''}`;
  el.textContent = message;
  root.querySelector('.shell')?.appendChild(el);
  setTimeout(() => el.remove(), 4000);
}

function fail(result, fallback) { toast(errorMessage(result, fallback), 'error'); }

function filteredTransactions() {
  const query = state.search.trim().toLowerCase();
  return state.transactions.filter((tx) => {
    const type = String(tx.transaction_type || '');
    const transfer = /transfer/.test(type);
    if (state.filter === 'transfers' && !transfer) return false;
    if (state.filter === 'deposits' && (transfer || tx.direction !== 'credit')) return false;
    if (state.filter === 'withdrawals' && (transfer || tx.direction !== 'debit')) return false;
    if (!query) return true;
    return [tx.description, tx.counterparty_ref, type].some((part) => String(part || '').toLowerCase().includes(query));
  });
}

/* ------------------------------------------------------------------ */
/* Rendering                                                            */
/* ------------------------------------------------------------------ */

function render() {
  root.classList.toggle('visible', state.visible);
  if (!state.visible || !state.session) { root.innerHTML = ''; return; }
  const selected = account();
  if (!selected) { root.innerHTML = `<div class="empty">${icons.empty}<span>No accessible accounts found.</span></div>`; return; }
  if (!subtabs().some(([key]) => key === state.subtab)) state.subtab = 'history';

  const me = personalAccount();
  const pendingPay = state.paychecks.items.length;
  const pendingBills = state.bills.items.length;
  const counts = { accounts: 0, paychecks: pendingPay, bills: pendingBills };
  const focused = focusSignature();

  root.innerHTML = `
    <div class="shell" role="dialog" aria-label="Renewed Banking">
      <header class="header">
        <div class="logo">
          <span class="logo-mark">${escapeHtml(state.brand.logo[0])}<span>${escapeHtml(state.brand.logo[1])}</span>${escapeHtml(state.brand.logo[2])}</span>
        </div>
        <nav class="nav">
          <span class="keycap">Q</span>
          ${TABS.map((tab) => `
            <button class="nav-tab ${state.tab === tab ? 'active' : ''}" data-tab="${tab}">
              ${TAB_LABELS[tab]}${counts[tab] ? `<span class="count">${counts[tab]}</span>` : ''}
            </button>`).join('')}
          <span class="keycap">E</span>
        </nav>
        <div class="cash">
          <div class="cash-label">Cash on hand</div>
          <div class="cash-value">${money(me?.cash ?? 0)}</div>
          <div class="cash-welcome">Welcome, ${escapeHtml(me?.displayName || selected.displayName)}</div>
        </div>
      </header>

      <div class="body">
        ${renderAccountList(selected)}
        <section class="panel" id="main-panel">
          ${state.tab === 'accounts' ? renderAccountPanel(selected) : state.tab === 'paychecks' ? renderPaychecks() : renderBills()}
        </section>
      </div>

      <footer class="footer">
        ${state.brand.tagline ? `<span class="tagline">${escapeHtml(state.brand.tagline)}</span>` : ''}
        <span class="hint"><span class="keycap icon">${icons.move}</span> Move</span><span class="sep">/</span>
        <span class="hint"><span class="keycap">Q</span><span class="keycap">E</span> Switch tab</span><span class="sep">/</span>
        <span class="hint"><span class="keycap icon">${icons.enter}</span> Select</span><span class="sep">/</span>
        <span class="hint"><span class="keycap">ESC</span> Close</span>
      </footer>

      ${renderModal(selected)}
    </div>`;
  restoreFocus(focused);
}

/* ------------------------------------------------------------------ */
/* Keyboard navigation                                                  */
/* ------------------------------------------------------------------ */

const FOCUSABLE = 'button, input:not([type="hidden"]), select, textarea';

// render() rebuilds the DOM, so remember which control had focus and put it back afterwards.
function focusSignature() {
  const el = document.activeElement;
  if (!el || !root.contains(el) || !el.matches?.(FOCUSABLE)) return null;
  const attrs = [...el.attributes].filter((a) => a.name.startsWith('data-') || a.name === 'name').map((a) => `[${a.name}="${CSS.escape(a.value)}"]`).join('');
  return { selector: attrs ? `${el.tagName.toLowerCase()}${attrs}` : null, index: focusables().indexOf(el) };
}

function restoreFocus(previous) {
  if (!previous) return;
  let target = null;
  try { target = previous.selector ? root.querySelector(previous.selector) : null; } catch { /* selector no longer valid */ }
  if (target?.disabled) target = null;
  // The control may be gone (e.g. a collected paycheck row): fall back to whatever now sits in its place.
  if (!target && previous.index >= 0) { const items = focusables(); target = items[Math.min(previous.index, items.length - 1)]; }
  target?.focus({ preventScroll: true });
}

function focusables() {
  const scope = root.querySelector('.modal') || root.querySelector('.shell');
  if (!scope) return [];
  return [...scope.querySelectorAll(FOCUSABLE)].filter((el) => !el.disabled && el.getClientRects().length > 0);
}

function gap(aStart, aEnd, bStart, bEnd) { return Math.max(0, aStart - bEnd, bStart - aEnd); }

// Spatial navigation: jump to the nearest control in the pressed direction.
function moveFocus(direction) {
  const items = focusables();
  if (!items.length) return;
  const current = items.includes(document.activeElement) ? document.activeElement : null;
  if (!current) { (root.querySelector('.modal input, .account-item.active') || items[0]).focus(); return; }
  const from = current.getBoundingClientRect();
  const horizontal = direction === 'left' || direction === 'right';
  const sign = direction === 'right' || direction === 'down' ? 1 : -1;
  let best = null, bestScore = Infinity;
  for (const item of items) {
    if (item === current) continue;
    const to = item.getBoundingClientRect();
    const dCenter = horizontal ? (to.left + to.right - from.left - from.right) / 2 : (to.top + to.bottom - from.top - from.bottom) / 2;
    if (dCenter * sign <= 1) continue;
    const primary = horizontal ? gap(to.left, to.right, from.left, from.right) : gap(to.top, to.bottom, from.top, from.bottom);
    const cross = horizontal ? gap(to.top, to.bottom, from.top, from.bottom) : gap(to.left, to.right, from.left, from.right);
    const score = primary + cross * 4 + Math.abs(dCenter) * 0.01;
    if (score < bestScore) { bestScore = score; best = item; }
  }
  if (best) { best.focus(); best.scrollIntoView({ block: 'nearest' }); playSound('hover'); }
}

function cycleSelect(select, step) {
  const count = select.options.length;
  if (!count) return;
  select.selectedIndex = (select.selectedIndex + step + count) % count;
  select.dispatchEvent(new Event('change', { bubbles: true }));
}

function renderAccountList(selected) {
  const caps = capabilities();
  const total = state.session.accounts.reduce((sum, item) => sum + (Number(item.balance) || 0), 0);
  return `
    <aside class="panel">
      <div class="panel-title"><h2>Accounts</h2></div>
      <div class="scroll">
        ${state.session.accounts.map((item) => `
          <button class="account-item ${item.key === selected.key ? 'active' : ''}" data-account="${escapeHtml(item.key)}">
            <span>
              <strong>${escapeHtml(item.displayName)}</strong>
              <small>${escapeHtml(sentence(item.accountType))} · ${escapeHtml(sentence(item.role || 'member'))} · #${escapeHtml(item.key)}</small>
            </span>
            <b class="account-amount ${Number(item.balance) < 0 ? 'neg' : ''}">${money(item.balance)}</b>
          </button>`).join('')}
        ${caps.create ? `<button class="open-account" data-action="create">${icons.plus} Open account</button>` : ''}
      </div>
      <div class="panel-foot"><span>Total balance</span><b>${money(total)}</b></div>
    </aside>`;
}

function renderAccountPanel(selected) {
  const negative = Number(selected.balance) < 0;
  return `
    <div class="panel-title">
      <div class="title-left">
        <h1>${escapeHtml(selected.displayName)}</h1>
        <span class="sub">${escapeHtml(selected.accountType)} · #${escapeHtml(selected.key)}${selected.status && selected.status !== 'active' ? ` · ${escapeHtml(selected.status.replaceAll('_', ' '))}` : ''}</span>
      </div>
      <div class="title-balance">Account balance: <b class="${negative ? 'account-amount neg' : ''}">${money(selected.balance)}</b></div>
    </div>
    ${state.session.migrationRequired ? '<div class="alert">Legacy balances detected. Database operations locked pending v3 migration.</div>' : ''}
    <div class="subtabs">
      ${subtabs().map(([key, label]) => `<button class="subtab ${state.subtab === key ? 'active' : ''}" data-subtab="${key}">${label}</button>`).join('')}
    </div>
    <div class="scroll pad">
      ${['deposit', 'withdraw', 'transfer'].includes(state.subtab) ? renderMoneyForm(selected)
        : state.subtab === 'members' ? '<div class="empty"><div class="spinner"></div></div>'
        : renderHistory()}
    </div>`;
}

function renderHistory() {
  return `
    <input class="search" data-search placeholder="Search transactions…" value="${escapeHtml(state.search)}" autocomplete="off">
    <div class="chips">
      ${Object.entries(FILTERS).map(([key, label]) => `<button class="chip ${state.filter === key ? 'active' : ''}" data-filter="${key}">${label}</button>`).join('')}
    </div>
    <div class="table-head cols-tx"><span>Description</span><span>Recipient</span><span class="right">Amount</span></div>
    <div class="tx-body">${transactionRows()}</div>
    <div class="tx-more">${moreButton()}</div>`;
}

function transactionRows() {
  if (state.loading) return '<div class="empty"><div class="spinner"></div><span>Loading transactions…</span></div>';
  const rows = filteredTransactions();
  if (!rows.length) return `<div class="empty">${icons.empty}<span>${state.transactions.length ? 'No transactions match your filters.' : 'No recent transactions found.'}</span></div>`;
  return rows.map((tx) => {
    const credit = tx.direction === 'credit';
    return `
      <div class="row cols-tx">
        <div>
          <strong>${escapeHtml(tx.description || sentence(tx.transaction_type))}</strong>
          <small>${timeAgo(tx.created_at)} · ${escapeHtml(sentence(tx.transaction_type))}</small>
        </div>
        <span class="recipient">${escapeHtml(tx.counterparty_ref || '—')}</span>
        <span class="right amount ${credit ? 'credit' : 'debit'}">${credit ? '+' : '−'}${money(tx.amount)}</span>
      </div>`;
  }).join('');
}

const moreButton = () => state.hasMore && !state.loading ? '<button class="btn wide" style="width:100%;margin-top:0.8rem" data-action="more">Load older transactions</button>' : '';

function refreshHistoryBody() {
  const body = root.querySelector('.tx-body');
  if (body) body.innerHTML = transactionRows();
  const more = root.querySelector('.tx-more');
  if (more) more.innerHTML = moreButton();
}

function renderMoneyForm(selected) {
  const action = state.subtab;
  const transfer = action === 'transfer';
  const me = personalAccount();
  const hints = {
    deposit: `Move cash into this account. Cash on hand: ${money(me?.cash ?? 0)}.`,
    withdraw: `Take cash out of this account. Available: ${money(selected.balance)}.`,
    transfer: `Send money from this account. Available: ${money(selected.balance)}.`
  };
  return `
    <form class="form" data-form="money">
      <h3 class="form-title">${escapeHtml(action)}</h3>
      <p class="form-hint">${hints[action]}</p>
      <input type="hidden" name="action" value="${escapeHtml(action)}">
      <label class="field">Account
        <input value="${escapeHtml(selected.displayName)} · #${escapeHtml(selected.key)}" disabled>
      </label>
      ${transfer ? `
        <div class="split">
          <label class="field">Recipient type
            <select name="recipientType"><option value="account">Account key</option><option value="personal">Character ID</option></select>
          </label>
          <label class="field">Recipient
            <input name="recipientKey" maxlength="80" required placeholder="e.g. police or CID123" autocomplete="off">
          </label>
        </div>` : ''}
      <label class="field">Amount
        <input name="amount" type="number" step="any" min="1" inputmode="decimal" autocomplete="off" required placeholder="0">
      </label>
      <label class="field">Note (optional)
        <textarea name="description" maxlength="160" placeholder="Reference note"></textarea>
      </label>
      <div class="form-actions">
        <button type="button" class="btn" data-subtab="history">Cancel</button>
        <button type="submit" class="btn primary" ${state.busy ? 'disabled' : ''}>Confirm ${escapeHtml(action)}</button>
      </div>
    </form>`;
}

function accountOptions(selectedKey, filter = () => true) {
  return state.session.accounts.filter(filter).map((item) => `<option value="${escapeHtml(item.key)}" ${item.key === selectedKey ? 'selected' : ''}>${escapeHtml(item.displayName)} · ${money(item.balance)}</option>`).join('');
}

function renderPaychecks() {
  const { items, loading, error } = state.paychecks;
  const total = items.reduce((sum, item) => sum + (Number(item.amount) || 0), 0);
  const destination = state.collectKey || personalAccount()?.key || account()?.key;
  return `
    <div class="panel-title">
      <div class="title-left"><h1>Paychecks</h1><span class="sub">${items.length} waiting to be collected</span></div>
    </div>
    <div class="summary">
      <div class="summary-figure"><small>Ready to collect</small><b>${money(total)}</b></div>
      <div class="summary-controls">
        <label class="select-wrap">Deposit to
          <select data-collect-account>${accountOptions(destination, (item) => item.permissions?.deposit !== false)}</select>
        </label>
        <button class="btn primary" data-action="collect-all" ${!items.length ? 'disabled' : ''}>Collect all</button>
      </div>
    </div>
    <div class="scroll pad">
      ${loading ? '<div class="empty"><div class="spinner"></div><span>Loading paychecks…</span></div>'
        : error ? `<div class="empty">${icons.empty}<span>${escapeHtml(error)}</span><button class="btn sm" data-action="reload-paychecks">Retry</button></div>`
        : !items.length ? `<div class="empty">${icons.empty}<span>No paychecks to collect right now.</span></div>`
        : `<div class="table-head cols-pay"><span>Employer</span><span>Earned</span><span class="right">Amount</span><span></span></div>
           ${items.map((item) => `
             <div class="row cols-pay">
               <div><strong>${escapeHtml(item.source || sentence(item.job))}</strong><small>${escapeHtml(item.grade || sentence(item.job))}</small></div>
               <span class="recipient">${timeAgo(item.accrued_at)}</span>
               <span class="right amount credit">+${money(item.amount)}</span>
               <button class="btn primary sm right" data-collect="${escapeHtml(item.id)}">Collect</button>
             </div>`).join('')}`}
    </div>`;
}

function renderBills() {
  const { items, loading, error } = state.bills;
  const total = items.reduce((sum, item) => sum + (Number(item.amount) || 0), 0);
  const overdue = items.filter((item) => dueLabel(item.due_at).overdue).length;
  const source = state.payKey || personalAccount()?.key || account()?.key;
  return `
    <div class="panel-title">
      <div class="title-left"><h1>Bills</h1><span class="sub">${items.length} outstanding${overdue ? ` · ${overdue} overdue` : ''}</span></div>
    </div>
    <div class="summary">
      <div class="summary-figure"><small>Total due</small><b>${money(total)}</b></div>
      <div class="summary-controls">
        <label class="select-wrap">Pay from
          <select data-pay-account>${accountOptions(source, (item) => item.permissions?.withdraw === true)}</select>
        </label>
        <button class="btn primary" data-action="pay-all" ${!items.length ? 'disabled' : ''}>Pay all</button>
      </div>
    </div>
    <div class="scroll pad">
      ${loading ? '<div class="empty"><div class="spinner"></div><span>Loading bills…</span></div>'
        : error ? `<div class="empty">${icons.empty}<span>${escapeHtml(error)}</span><button class="btn sm" data-action="reload-bills">Retry</button></div>`
        : !items.length ? `<div class="empty">${icons.empty}<span>You have no unpaid bills.</span></div>`
        : `<div class="table-head cols-bill"><span>Bill</span><span>Status</span><span class="right">Amount</span><span></span></div>
           ${items.map((item) => {
             const due = dueLabel(item.due_at);
             return `
             <div class="row cols-bill">
               <div><strong>${escapeHtml(item.reason || 'Bill')}</strong><small>${escapeHtml(item.issuer || 'Unknown')} · issued ${timeAgo(item.issued_at)}</small></div>
               <span><span class="tag ${due.overdue ? 'overdue' : ''}">${escapeHtml(due.text)}</span></span>
               <span class="right amount debit">${money(item.amount)}</span>
               <button class="btn primary sm right" data-pay="${escapeHtml(item.id)}">Pay</button>
             </div>`;
           }).join('')}`}
    </div>`;
}

function renderModal(selected) {
  if (!state.modal) return '';
  if (state.modal.type === 'create') {
    return `
      <div class="modal-backdrop">
        <form class="modal" data-form="create">
          <div class="modal-head">
            <div><p>Shared account</p><h3>Open new account</h3></div>
            <button type="button" class="icon-button" data-action="dismiss">${icons.close}</button>
          </div>
          <div class="modal-body">
            <label class="field">Account key
              <input name="accountKey" required minlength="3" maxlength="50" pattern="[a-z0-9][a-z0-9_-]*" placeholder="family_savings">
            </label>
            <label class="field">Display name
              <input name="displayName" required maxlength="96" placeholder="Family Savings">
            </label>
            <div class="form-actions">
              <button type="button" class="btn" data-action="dismiss">Cancel</button>
              <button class="btn primary" type="submit">Open account</button>
            </div>
          </div>
        </form>
      </div>`;
  }
  if (state.modal.type === 'members') {
    return `
      <div class="modal-backdrop">
        <div class="modal large">
          <div class="modal-head">
            <div><p>Access management</p><h3>Account members</h3></div>
            <button type="button" class="icon-button" data-action="dismiss">${icons.close}</button>
          </div>
          <div class="modal-body">
            <div class="member-list">
              ${state.modal.loading
                ? '<div class="empty"><div class="spinner"></div><span>Loading members…</span></div>'
                : (state.modal.members || []).map((m) => `
                  <div class="member">
                    <div><strong>${escapeHtml(m.member_identifier)}</strong><small>${escapeHtml(m.role)}</small></div>
                    ${m.role !== 'owner' ? `<button class="danger-link" data-remove-member="${escapeHtml(m.member_identifier)}">Remove</button>` : '<span class="tag">Owner</span>'}
                  </div>`).join('')}
            </div>
            <form class="member-add" data-form="member">
              <input name="identifier" required maxlength="80" placeholder="Character ID">
              <select name="role"><option value="operator">Operator</option><option value="viewer">Viewer</option><option value="admin">Admin</option></select>
              <button class="btn primary">Add member</button>
            </form>
            <div class="management-row">
              ${selected.permissions?.rename ? '<button class="btn" data-action="rename">Rename account</button>' : '<span></span>'}
              ${selected.permissions?.close ? '<button class="btn danger" data-action="close-account">Close account</button>' : ''}
            </div>
          </div>
        </div>
      </div>`;
  }
  return '';
}

/* ------------------------------------------------------------------ */
/* Data loading                                                         */
/* ------------------------------------------------------------------ */

async function refreshSession() {
  const result = await nui('getSession', {});
  if (!result?.ok) return fail(result);
  state.session = result.data;
  if (!state.session.accounts.some((item) => item.key === state.selectedKey)) state.selectedKey = state.session.accounts[0]?.key;
  render();
}

async function loadTransactions(append = false) {
  const selected = account();
  if (!selected) return;
  state.loading = true; render();
  let result;
  try { result = await nui('transactions', { accountKey: selected.key, cursor: append ? state.nextCursor : null, limit: 30, filters: {} }); }
  catch { result = null; }
  state.loading = false;
  if (!result?.ok) { render(); return fail(result); }
  state.transactions = append ? [...state.transactions, ...result.data.items] : result.data.items;
  state.nextCursor = result.data.nextCursor; state.hasMore = result.data.hasMore; render();
}

async function loadList(kind) {
  const slot = state[kind];
  const callback = kind === 'paychecks' ? 'getPaychecks' : 'getBills';
  slot.loading = true; slot.error = null; render();
  let result;
  try { result = await nui(callback, {}); } catch { result = null; }
  slot.loading = false; slot.loaded = true;
  if (result?.ok) slot.items = result.data?.items || [];
  else { slot.items = []; slot.error = result?.error ? errorMessage(result) : `${sentence(kind)} are not available right now.`; }
  render();
}

async function switchTab(tab) {
  if (!TABS.includes(tab) || state.tab === tab) return;
  state.tab = tab; state.modal = null; render();
  if (tab === 'paychecks') await loadList('paychecks');
  if (tab === 'bills') await loadList('bills');
}

async function switchSubtab(key) {
  if (key === 'members') return showMembers();
  state.subtab = key; state.requestId = uuid(); render();
}

async function collect(paycheckId) {
  if (state.busy) return;
  const destinationKey = state.collectKey || personalAccount()?.key || account()?.key;
  state.busy = true; render();
  let result;
  try { result = await nui(paycheckId ? 'collectPaycheck' : 'collectAllPaychecks', { requestId: uuid(), paycheckId, destinationKey }); } catch { result = null; }
  state.busy = false;
  if (!result?.ok) { render(); return fail(result, 'Could not collect paycheck.'); }
  toast(`Collected ${money(result.data?.total ?? 0)}`);
  await refreshSession(); await loadList('paychecks');
  if (state.selectedKey === destinationKey) loadTransactions();
}

async function payBills(billId) {
  if (state.busy) return;
  const sourceKey = state.payKey || personalAccount()?.key || account()?.key;
  state.busy = true; render();
  let result;
  try { result = await nui(billId ? 'payBill' : 'payAllBills', { requestId: uuid(), billId, sourceKey }); } catch { result = null; }
  state.busy = false;
  if (!result?.ok) { render(); return fail(result, 'Could not pay bill.'); }
  toast(`Paid ${money(result.data?.total ?? 0)}`);
  await refreshSession(); await loadList('bills');
  if (state.selectedKey === sourceKey) loadTransactions();
}

async function showMembers() {
  state.modal = { type: 'members', loading: true, members: [] }; render();
  const result = await nui('listMembers', { accountKey: account().key });
  if (!result?.ok) { state.modal = null; render(); return fail(result); }
  state.modal = { type: 'members', loading: false, members: result.data }; render();
}

function dismiss() { state.modal = null; render(); }

async function closeUi() {
  state.visible = false; state.modal = null; render();
  await nui('closeInterface', {});
}

/* ------------------------------------------------------------------ */
/* Events                                                               */
/* ------------------------------------------------------------------ */

root.addEventListener('click', async (event) => {
  const target = event.target;
  const tab = target.closest('[data-tab]');
  if (tab) return switchTab(tab.dataset.tab);

  const accountButton = target.closest('[data-account]');
  if (accountButton) {
    state.selectedKey = accountButton.dataset.account; state.transactions = []; state.nextCursor = null; state.search = ''; state.filter = 'all'; state.subtab = 'history';
    if (state.tab !== 'accounts') state.tab = 'accounts';
    render(); await loadTransactions(); return;
  }

  const subtab = target.closest('[data-subtab]');
  if (subtab) return switchSubtab(subtab.dataset.subtab);

  const filter = target.closest('[data-filter]');
  if (filter) { state.filter = filter.dataset.filter; render(); return; }

  const collectButton = target.closest('[data-collect]');
  if (collectButton) return collect(collectButton.dataset.collect);
  const payButton = target.closest('[data-pay]');
  if (payButton) return payBills(payButton.dataset.pay);

  const remove = target.closest('[data-remove-member]');
  if (remove) {
    if (confirm(`Remove ${remove.dataset.removeMember}?`)) {
      const result = await nui('removeMember', { accountKey: account().key, identifier: remove.dataset.removeMember, requestId: uuid() });
      if (!result.ok) return fail(result);
      await showMembers();
    }
    return;
  }

  const action = target.closest('[data-action]')?.dataset.action;
  if (!action) return;
  if (action === 'close') return closeUi();
  if (action === 'dismiss') return dismiss();
  if (action === 'create') { state.modal = { type: 'create', requestId: uuid() }; return render(); }
  if (action === 'more') return loadTransactions(true);
  if (action === 'collect-all') return collect(null);
  if (action === 'pay-all') return payBills(null);
  if (action === 'reload-paychecks') return loadList('paychecks');
  if (action === 'reload-bills') return loadList('bills');
  if (action === 'rename') {
    const name = prompt('New display name', account().displayName);
    if (!name) return;
    const result = await nui('renameAccount', { accountKey: account().key, displayName: name, requestId: uuid() });
    if (!result.ok) return fail(result);
    await refreshSession(); await showMembers();
  }
  if (action === 'close-account' && confirm('Close this zero-balance account? This keeps its audit history.')) {
    const result = await nui('closeAccount', { accountKey: account().key, reason: 'Closed by owner', requestId: uuid() });
    if (!result.ok) return fail(result);
    dismiss(); await refreshSession(); await loadTransactions();
  }
});

root.addEventListener('input', (event) => {
  if (event.target.matches('[data-search]')) { state.search = event.target.value; refreshHistoryBody(); }
});

root.addEventListener('change', (event) => {
  if (event.target.matches('[data-collect-account]')) state.collectKey = event.target.value;
  if (event.target.matches('[data-pay-account]')) state.payKey = event.target.value;
});

root.addEventListener('submit', async (event) => {
  event.preventDefault();
  const form = event.target;
  const data = Object.fromEntries(new FormData(form));
  if (form.dataset.form === 'money') {
    if (state.busy) return;
    const action = data.action;
    const payload = { requestId: state.requestId || uuid(), sourceKey: account().key, amount: data.amount, description: data.description || '' };
    if (action === 'transfer') { payload.recipientType = data.recipientType; payload.recipientKey = data.recipientKey; }
    const submit = form.querySelector('button[type="submit"]');
    submit.disabled = true; state.busy = true;
    let result;
    try { result = await nui(action, payload); } catch { result = null; }
    state.busy = false;
    if (!result?.ok) { submit.disabled = false; return fail(result, 'Service unavailable.'); }
    toast(`${sentence(action)} completed`);
    state.subtab = 'history'; state.requestId = uuid();
    await refreshSession(); await loadTransactions();
  }
  if (form.dataset.form === 'create') {
    const result = await nui('createAccount', { requestId: state.modal?.requestId || uuid(), accountKey: data.accountKey, displayName: data.displayName });
    if (!result?.ok) return fail(result);
    dismiss(); await refreshSession(); state.selectedKey = result.data.key; state.subtab = 'history'; await loadTransactions();
  }
  if (form.dataset.form === 'member') {
    const result = await nui('addMember', { requestId: uuid(), accountKey: account().key, identifier: data.identifier, role: data.role });
    if (!result?.ok) return fail(result);
    await showMembers();
  }
});

async function openWith(session, context) {
  state.visible = true; state.session = session; state.context = context;
  state.selectedKey = session.accounts[0]?.key; state.tab = 'accounts'; state.subtab = 'history';
  state.search = ''; state.filter = 'all'; state.modal = null; state.requestId = uuid();
  state.collectKey = null; state.payKey = null; state.busy = false;
  state.paychecks = { items: [], loading: false, error: null, loaded: false };
  state.bills = { items: [], loading: false, error: null, loaded: false };
  render();
  root.querySelector('.account-item.active')?.focus({ preventScroll: true });
  // Load everything up front so the Paychecks / Bills tabs can show their pending counts.
  await Promise.all([loadTransactions(), loadList('paychecks'), loadList('bills')]);
}

window.addEventListener('message', async (event) => {
  const message = event.data || {};
  if (message.type === 'renewedBanking:open' && Array.isArray(message.payload.brand?.logo)) state.brand = message.payload.brand;
  if (message.type === 'renewedBanking:open') await openWith(message.payload.session, message.payload.context);
  if (message.type === 'renewedBanking:close') { state.visible = false; render(); }
  if (message.type === 'renewedBanking:atmTyping') atmTyping = message.active === true;
});

// One delegated listener so every button and dropdown gets hover/click feedback.
const INTERACTIVE = 'button:not(:disabled), select:not(:disabled)';

window.addEventListener('mouseover', (event) => {
  if (!state.visible) return;
  const target = event.target.closest?.(INTERACTIVE);
  if (!target || target.contains(event.relatedTarget)) return;
  playSound('hover');
});

window.addEventListener('click', (event) => {
  if (state.visible && event.target.closest?.(INTERACTIVE)) playSound('click');
});

// While a field on an ATM's screen is being typed into, this page holds the keyboard
// (the ATM page, painted in the world, gets none) and passes every key on to it.
let atmTyping = false;

window.addEventListener('keydown', (event) => {
  if (!atmTyping) return;
  event.stopImmediatePropagation();
  if (event.ctrlKey && event.key.toLowerCase() === 'v') return; // let the paste event through
  event.preventDefault();
  if (event.ctrlKey || event.altKey || event.metaKey) return;
  nui('atmKey', { key: event.key, shift: event.shiftKey });
}, true);

window.addEventListener('paste', (event) => {
  if (!atmTyping) return;
  const text = event.clipboardData?.getData('text') || '';
  if (text) nui('atmKey', { text: text.slice(0, 160) });
});

const ARROWS = { ArrowUp: 'up', ArrowDown: 'down', ArrowLeft: 'left', ArrowRight: 'right' };

window.addEventListener('keydown', (event) => {
  if (!state.visible) return;
  if (event.key === 'Escape') { state.modal ? dismiss() : closeUi(); return; }
  const target = event.target;
  const field = target.closest?.('input, textarea, select');

  if (ARROWS[event.key] && !event.altKey && !event.ctrlKey) {
    const direction = ARROWS[event.key];
    // Text fields keep left/right (and textarea up/down) for the caret.
    if (field?.matches('input:not([type="number"]), textarea') && (direction === 'left' || direction === 'right')) return;
    if (field?.matches('input[type="number"]') && (direction === 'left' || direction === 'right')) return;
    if (field?.matches('textarea')) {
      const atStart = field.selectionStart === 0 && field.selectionEnd === 0;
      const atEnd = field.selectionStart === field.value.length && field.selectionEnd === field.value.length;
      if ((direction === 'up' && !atStart) || (direction === 'down' && !atEnd)) return;
    }
    event.preventDefault();
    moveFocus(direction);
    return;
  }

  // Dropdowns: Enter / Space cycles to the next option (Shift goes back) so they work without a mouse.
  if (target.matches?.('select') && (event.key === 'Enter' || event.key === ' ')) {
    event.preventDefault();
    cycleSelect(target, event.shiftKey ? -1 : 1);
    return;
  }

  if (state.modal || field) return;
  const key = event.key.toLowerCase();
  if (key === 'q' || key === 'e') {
    const index = TABS.indexOf(state.tab) + (key === 'e' ? 1 : -1);
    playSound('click');
    switchTab(TABS[(index + TABS.length) % TABS.length]);
  }
});

if (isDemo) {
  openWith(structuredClone(demo.session), { type: 'bank', capabilities: { deposit: true, withdraw: true, transfer: true, createSharedAccount: true } })
    .then(() => switchTab(location.hash.slice(1)));
}
