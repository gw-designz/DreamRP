/*
  web/app.js

  Vanilla-JS NUI panel for qb-doorcreator. No build step, no framework -
  it is loaded directly as a <script> tag by index.html. State lives in
  one `state` object; every user action either mutates `state` and
  re-renders, or calls fetchNui() to talk to client/nui.lua.

  Two independent panel "modes" exist:
    'create' - opened by client/creator.lua after a raycast selection,
               pre-filled with a draft (model/coords/heading). Always
               shows the form directly; closing it (saved or not) ends
               the session and tells Lua so it can chain a queued
               sibling draft (see client/nui.lua's group-linking flow).
    'manage' - opened via /doormanager or the context menu. Shows the
               searchable list first; "Edit" swaps to the same form
               used by create mode, scoped to that one door, and
               "Cancel" there returns to the list instead of closing.
*/

(() => {
  'use strict';

  // ------------------------------------------------------------------
  // State
  // ------------------------------------------------------------------

  const state = {
    mode: null,            // 'create' | 'manage' | null (panel closed)
    view: 'list',          // manage mode only: 'list' | 'edit'
    doors: [],             // full door list, kept live via doorAdded/Updated/Removed
    editingIsCreate: false,
    form: null,            // working copy of the door being created/edited
    activeTab: 'jobs',
    search: '',
    page: 1,
    pageSize: 8,
    confirmDelete: null,   // door id pending delete confirmation
    accessLabels: null,    // Config.AccessTypeLabels, sent by Lua on every 'open' message
  };

  const TAB_ORDER = ['jobs', 'gangs', 'identifiers', 'items', 'password', 'permission', 'keys', 'dependencies'];
  const TAB_LABELS = {
    jobs: 'Jobs', gangs: 'Gangs', identifiers: 'Identifiers', items: 'Items',
    password: 'Password', permission: 'Admin Perm', keys: 'Keyring', dependencies: 'Dependencies',
  };

  // ------------------------------------------------------------------
  // NUI transport
  // ------------------------------------------------------------------

  function parentResourceName() {
    return (typeof GetParentResourceName === 'function') ? GetParentResourceName() : 'qb-doorcreator';
  }

  async function fetchNui(callbackName, data) {
    try {
      const resp = await fetch(`https://${parentResourceName()}/${callbackName}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify(data || {}),
      });
      return await resp.json();
    } catch (err) {
      return { ok: false, error: 'generic_error' };
    }
  }

  // ------------------------------------------------------------------
  // Small helpers
  // ------------------------------------------------------------------

  function esc(value) {
    return String(value === undefined || value === null ? '' : value).replace(/[&<>"']/g, (c) => ({
      '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;',
    }[c]));
  }

  function el(id) {
    return document.getElementById(id);
  }

  // Falls back to these if the server's Config.AccessTypeLabels was
  // not sent (or a key is missing from it) - see state.accessLabels.
  const DEFAULT_ACCESS_LABELS = {
    jobs: 'Job', gangs: 'Gang', identifiers: 'Owner', items: 'Item',
    password: 'Password', permission: 'Admin', keys: 'Keyring',
  };

  function accessLabel(kind) {
    return (state.accessLabels && state.accessLabels[kind]) || DEFAULT_ACCESS_LABELS[kind];
  }

  function summarizeAccess(access) {
    if (!access) return 'Public';
    const parts = [];
    if (access.permission) parts.push(accessLabel('permission'));
    if (access.jobs && access.jobs.length) parts.push(`${accessLabel('jobs')}(${access.jobs.length})`);
    if (access.gangs && access.gangs.length) parts.push(`${accessLabel('gangs')}(${access.gangs.length})`);
    if (access.identifiers && access.identifiers.length) parts.push(`${accessLabel('identifiers')}(${access.identifiers.length})`);
    if (access.items && access.items.length) parts.push(`${accessLabel('items')}(${access.items.length})`);
    if (access.keys && access.keys.enabled) parts.push(accessLabel('keys'));
    if (access.password && access.password.enabled) parts.push(accessLabel('password'));
    return parts.length ? parts.join(', ') : 'Public';
  }

  function uniqueGroups() {
    const set = new Set();
    state.doors.forEach((d) => { if (d.group_id) set.add(d.group_id); });
    return [...set].sort();
  }

  function doorLabelById(id) {
    const d = state.doors.find((x) => x.id === id);
    return d ? `${d.label} (#${d.id})` : `#${id}`;
  }

  function upsertDoor(door) {
    const idx = state.doors.findIndex((d) => d.id === door.id);
    if (idx >= 0) state.doors[idx] = door; else state.doors.push(door);
  }

  // ------------------------------------------------------------------
  // Show / hide
  // ------------------------------------------------------------------

  function show() {
    el('app').classList.remove('hidden');
  }

  function hide() {
    el('app').classList.add('hidden');
    el('app').innerHTML = '';
    state.mode = null;
    state.view = 'list';
    state.form = null;
    state.confirmDelete = null;
  }

  // The interaction prompt (§8) is a separate always-in-DOM element,
  // independent of #app/show()/hide() above - client/main.lua drives
  // it directly with showPrompt/hidePrompt messages, no NUI focus
  // involved, so it can appear while the admin panel is closed (the
  // normal case) or even while it's open, without conflicting.
  function showInteractionPrompt(key, label, position) {
    const prompt = el('prompt');
    if (!prompt) return;
    el('prompt-key').textContent = key || 'E';
    el('prompt-label').textContent = label || '';
    prompt.dataset.position = position || 'center';
    prompt.classList.remove('hidden');
  }

  function hideInteractionPrompt() {
    const prompt = el('prompt');
    if (prompt) prompt.classList.add('hidden');
  }

  // ------------------------------------------------------------------
  // Form (create/edit) state seeding
  // ------------------------------------------------------------------

  function blankAccess() {
    return {
      mode: 'any',
      jobs: [], gangs: [], identifiers: [], items: [],
      permission: '',
      keys: { enabled: false },
      password: { enabled: false, raw: '', hasExisting: false },
    };
  }

  function openFormFor(door, draft, defaults) {
    state.editingIsCreate = !door;

    if (door) {
      state.form = {
        id: door.id,
        label: door.label,
        model: door.model,
        coords: door.coords,
        group_id: door.group_id || '',
        auto_close: door.auto_close || 0,
        fallback: !!door.fallback,
        access: {
          mode: (door.access && door.access.mode) || 'any',
          jobs: ((door.access && door.access.jobs) || []).map((r) => ({ ...r })),
          gangs: ((door.access && door.access.gangs) || []).map((r) => ({ ...r })),
          identifiers: [...((door.access && door.access.identifiers) || [])],
          items: ((door.access && door.access.items) || []).map((r) => ({ ...r })),
          permission: (door.access && door.access.permission) || '',
          keys: { enabled: !!(door.access && door.access.keys && door.access.keys.enabled) },
          password: {
            enabled: !!(door.access && door.access.password && door.access.password.enabled),
            raw: '',
            hasExisting: !!(door.access && door.access.password && door.access.password.hash),
          },
        },
        dependencies: (door.dependencies || []).map((d) => ({ ...d })),
      };
    } else {
      // Config-driven defaults (Config.DefaultAutoClose / Config.NativeDoorsDefault)
      // sent through by client/nui.lua's OpenCreatorPanel - fall back
      // to the same values it would send if `defaults` is missing for
      // any reason, so a brand new door never depends on this arg.
      const d = defaults || { autoClose: 0, fallback: false };
      state.form = {
        id: null,
        label: '',
        model: draft ? draft.model : 0,
        coords: draft ? draft.coords : { x: 0, y: 0, z: 0, heading: 0 },
        group_id: draft && draft.group_id ? draft.group_id : '',
        auto_close: d.autoClose || 0,
        fallback: !!d.fallback,
        access: blankAccess(),
        dependencies: [],
      };
    }

    state.view = 'edit';
    state.activeTab = 'jobs';
  }

  // ------------------------------------------------------------------
  // Rendering - top level
  // ------------------------------------------------------------------

  function render() {
    const app = el('app');
    if (!state.mode) { app.innerHTML = ''; return; }

    if (state.mode === 'create' || (state.mode === 'manage' && state.view === 'edit')) {
      app.innerHTML = `<div class="panel">${renderForm()}</div>`;
    } else {
      app.innerHTML = `<div class="panel">${renderList()}</div>`;
    }
  }

  function updateTableOnly() {
    const container = el('door-table-container');
    if (container) container.innerHTML = renderDoorTable();
  }

  function rerenderTabBody() {
    const body = document.querySelector('.tab-body');
    if (body) body.innerHTML = renderTab(state.activeTab);
    const tabsBar = document.querySelector('.tabs');
    if (tabsBar) tabsBar.innerHTML = renderTabButtons();
  }

  // ------------------------------------------------------------------
  // Rendering - list view
  // ------------------------------------------------------------------

  function filteredDoors() {
    const q = state.search.trim().toLowerCase();
    if (!q) return state.doors;
    return state.doors.filter((d) => {
      const hay = [
        d.label || '',
        String(d.model),
        d.group_id || '',
        summarizeAccess(d.access),
      ].join(' ').toLowerCase();
      return hay.includes(q);
    });
  }

  function paginatedDoors() {
    const list = filteredDoors();
    const start = (state.page - 1) * state.pageSize;
    return { list: list.slice(start, start + state.pageSize), total: list.length };
  }

  function renderList() {
    return `
      <div class="panel-header">
        <h1>Door Manager</h1>
        <div class="header-actions">
          <input id="search-input" type="text" placeholder="Search doors..." value="${esc(state.search)}" />
          <button data-action="placeNewDoor" class="primary">+ Place New Door</button>
          <button data-action="closePanel" class="ghost">Close</button>
        </div>
      </div>
      <div id="door-table-container">${renderDoorTable()}</div>
      ${state.confirmDelete !== null ? renderDeleteModal() : ''}
    `;
  }

  function renderDoorTable() {
    const { list, total } = paginatedDoors();
    const totalPages = Math.max(1, Math.ceil(total / state.pageSize));

    const rows = list.map((d) => `
      <tr>
        <td>${esc(d.label)}</td>
        <td class="mono">${esc(String(d.model))}</td>
        <td>${d.group_id ? esc(d.group_id) : '<span class="muted">—</span>'}</td>
        <td>
          <button class="pill ${d.locked ? 'locked' : 'unlocked'}" data-action="toggleLock" data-id="${d.id}" data-locked="${d.locked ? '0' : '1'}">
            ${d.locked ? 'Locked' : 'Unlocked'}
          </button>
        </td>
        <td class="muted">${esc(summarizeAccess(d.access))}</td>
        <td class="actions">
          <button data-action="editDoor" data-id="${d.id}" title="Edit">✎</button>
          <button data-action="locateDoor" data-id="${d.id}" title="Waypoint">📍</button>
          <button data-action="teleportDoor" data-id="${d.id}" title="Teleport">➜</button>
          <button data-action="confirmDelete" data-id="${d.id}" class="danger" title="Delete">🗑</button>
        </td>
      </tr>
    `).join('');

    return `
      <table class="door-table">
        <thead>
          <tr><th>Label</th><th>Model</th><th>Group</th><th>State</th><th>Access</th><th>Actions</th></tr>
        </thead>
        <tbody>${rows || '<tr><td colspan="6" class="empty">No doors match.</td></tr>'}</tbody>
      </table>
      <div class="pagination">
        <button data-action="prevPage" ${state.page <= 1 ? 'disabled' : ''}>‹ Prev</button>
        <span>Page ${state.page} / ${totalPages}</span>
        <button data-action="nextPage" ${state.page >= totalPages ? 'disabled' : ''}>Next ›</button>
        <span class="muted">${total} door(s)</span>
      </div>
    `;
  }

  function renderDeleteModal() {
    const door = state.doors.find((d) => d.id === state.confirmDelete);
    if (!door) return '';
    return `
      <div class="modal-overlay" data-action="cancelDelete">
        <div class="modal" onclick="event.stopPropagation()">
          <h2>Delete this door?</h2>
          <p>This will permanently remove "${esc(door.label)}" from the database and the native door system.</p>
          <div class="modal-actions">
            <button data-action="cancelDelete" class="ghost">Cancel</button>
            <button data-action="doDelete" data-id="${door.id}" class="danger">Delete</button>
          </div>
        </div>
      </div>
    `;
  }

  // ------------------------------------------------------------------
  // Rendering - create/edit form
  // ------------------------------------------------------------------

  function renderForm() {
    const f = state.form;
    const isEdit = !state.editingIsCreate;

    return `
      <div class="panel-header">
        <h1>${isEdit ? 'Edit Door' : 'New Door'}</h1>
        <div class="header-actions">
          <button data-action="closePanel" class="ghost">Close</button>
        </div>
      </div>
      <div class="form-grid">
        <label>Label
          <input id="f-label" type="text" maxlength="100" value="${esc(f.label)}" placeholder="Front Gate" />
        </label>
        <label>Model Hash
          <input type="text" value="${esc(String(f.model))}" disabled class="mono" />
        </label>
        <label>Auto-Close (seconds, 0 = never)
          <input id="f-autoclose" type="number" min="0" max="86400" value="${f.auto_close}" />
        </label>
        <label>Group
          <div style="display:flex; gap:6px;">
            <input id="f-group" type="text" list="group-options" maxlength="64" value="${esc(f.group_id)}" placeholder="(none)" style="flex:1" />
            ${isEdit ? '<button data-action="linkAnotherDoor" class="ghost small" title="Raycast-pick another door to join this one\'s group (double doors)">+ Link Door</button>' : ''}
          </div>
          <datalist id="group-options">
            ${uniqueGroups().map((g) => `<option value="${esc(g)}">`).join('')}
          </datalist>
        </label>
        <label class="checkbox">
          <input id="f-fallback" type="checkbox" ${f.fallback ? 'checked' : ''} />
          Non-native prop (freeze/heading fallback mode)
        </label>
        <label class="checkbox">
          <input id="f-anymode" type="checkbox" ${f.access.mode === 'all' ? 'checked' : ''} />
          Require ALL configured categories (AND) instead of ANY (OR)
        </label>
      </div>

      <div class="tabs">${renderTabButtons()}</div>
      <div class="tab-body">${renderTab(state.activeTab)}</div>

      <div class="form-footer">
        <button data-action="saveDoor" class="primary">${isEdit ? 'Save Changes' : 'Create Door'}</button>
        <button data-action="cancelForm" class="ghost">Cancel</button>
      </div>
    `;
  }

  function renderTabButtons() {
    return TAB_ORDER.map((t) => `
      <button class="tab ${state.activeTab === t ? 'active' : ''}" data-action="setTab" data-tab="${t}">${TAB_LABELS[t]}</button>
    `).join('');
  }

  function renderTab(tab) {
    switch (tab) {
      case 'jobs': return renderRuleList('jobs', state.form.access.jobs, 'job');
      case 'gangs': return renderRuleList('gangs', state.form.access.gangs, 'gang');
      case 'identifiers': return renderIdentifiers();
      case 'items': return renderItems();
      case 'password': return renderPassword();
      case 'permission': return renderPermission();
      case 'keys': return renderKeys();
      case 'dependencies': return renderDependencies();
      default: return '';
    }
  }

  function renderRuleList(kind, rows, nameField) {
    const rowsHtml = rows.map((r, i) => `
      <div class="rule-row" data-row-kind="${kind}" data-idx="${i}">
        <input type="text" data-field="${nameField}" value="${esc(r[nameField] || '')}" placeholder="${nameField} name" />
        <input type="number" min="0" data-field="grade" value="${r.grade || 0}" placeholder="min grade" />
        <button data-action="removeRule" data-kind="${kind}" data-idx="${i}" class="danger small">×</button>
      </div>
    `).join('');
    return `
      <div class="rule-list">${rowsHtml || `<p class="muted">No rules — this category grants nothing on its own.</p>`}</div>
      <button data-action="addRule" data-kind="${kind}" class="ghost small">+ Add ${TAB_LABELS[kind].replace(/s$/, '')}</button>
    `;
  }

  function renderIdentifiers() {
    const rows = state.form.access.identifiers.map((id, i) => `
      <div class="rule-row" data-row-kind="identifiers" data-idx="${i}">
        <input type="text" data-field="identifier" value="${esc(id)}" placeholder="citizenid or license:..." />
        <button data-action="removeRule" data-kind="identifiers" data-idx="${i}" class="danger small">×</button>
      </div>
    `).join('');
    return `
      <div class="rule-list">${rows || '<p class="muted">No owners set — this is not a personally-owned door.</p>'}</div>
      <button data-action="addRule" data-kind="identifiers" class="ghost small">+ Add Identifier</button>
    `;
  }

  function renderItems() {
    const rows = state.form.access.items.map((r, i) => `
      <div class="rule-row" data-row-kind="items" data-idx="${i}">
        <input type="text" data-field="item" value="${esc(r.item || '')}" placeholder="item name" />
        <label class="checkbox small"><input type="checkbox" data-field="remove" ${r.remove ? 'checked' : ''} /> Consume on use</label>
        <button data-action="removeRule" data-kind="items" data-idx="${i}" class="danger small">×</button>
      </div>
    `).join('');
    return `
      <div class="rule-list">${rows || '<p class="muted">No item requirement.</p>'}</div>
      <button data-action="addRule" data-kind="items" class="ghost small">+ Add Item</button>
    `;
  }

  function renderPassword() {
    const p = state.form.access.password;
    return `
      <label class="checkbox">
        <input id="f-pw-enabled" type="checkbox" ${p.enabled ? 'checked' : ''} />
        Require a password
      </label>
      ${p.enabled ? `
        <label style="margin-top:10px">${p.hasExisting ? 'New code (leave blank to keep the current code)' : 'Code'}
          <input id="f-pw-raw" type="text" maxlength="32" placeholder="${p.hasExisting ? '••••••••' : 'e.g. 4517'}" value="${esc(p.raw)}" />
        </label>
        ${p.hasExisting ? '<p class="muted">A code is already set on this door.</p>' : ''}
      ` : ''}
    `;
  }

  function renderPermission() {
    return `
      <label>Qbox permission group (staff bypass — always grants access, e.g. admin)
        <input id="f-permission" type="text" maxlength="100" value="${esc(state.form.access.permission)}" placeholder="(none)" />
      </label>
      <p class="muted" style="margin-top:10px">Checked against Qbox's own permission groups (exports.qbx_core:HasPermission) — not a FiveM ace permission.</p>
    `;
  }

  function renderKeys() {
    return `
      <label class="checkbox">
        <input id="f-keys-enabled" type="checkbox" ${state.form.access.keys.enabled ? 'checked' : ''} />
        Grant access to anyone holding a tagged key
      </label>
      <p class="muted" style="margin-top:10px">
        Uses the configured keyring item (Config.KeyItemName). Tag a key's inventory metadata with
        <code>doorId = ${state.form.id !== null ? state.form.id : '(assigned on save)'}</code> to grant it.
      </p>
    `;
  }

  function renderDependencies() {
    const rows = state.form.dependencies.map((d, i) => `
      <div class="rule-row">
        <span class="pill">${esc(d.type)}</span>
        <span>${d.type === 'door' ? esc(doorLabelById(d.id)) : esc(String(d.id))}</span>
        <span class="muted">must be ${esc(d.requiredState)}</span>
        <button data-action="removeDependency" data-idx="${i}" class="danger small">×</button>
      </div>
    `).join('');

    const otherDoors = state.doors.filter((d) => d.id !== state.form.id);

    return `
      <div class="rule-list">${rows || '<p class="muted">No dependencies — this door is always operable.</p>'}</div>
      <div class="dependency-builder">
        <select id="dep-type">
          <option value="door">Door</option>
          <option value="switch">Switch</option>
        </select>
        <input id="dep-door-search" type="text" list="dep-door-options" placeholder="Search doors by label..." />
        <datalist id="dep-door-options">
          ${otherDoors.map((d) => `<option value="${esc(d.label)} (#${d.id})">`).join('')}
        </datalist>
        <input id="dep-switch-id" type="text" placeholder="switch id" style="display:none" />
        <select id="dep-required-state">
          <option value="unlocked">Unlocked</option>
          <option value="locked">Locked</option>
        </select>
        <button data-action="addDependency" class="ghost small">+ Add</button>
      </div>
    `;
  }

  // ------------------------------------------------------------------
  // Form <-> state sync
  //
  // Row VALUES are read straight from the DOM only when needed (tab
  // switch, add/remove row, final save) instead of on every keystroke.
  // syncTabIntoState() pulls whatever is currently on screen for the
  // ACTIVE tab back into state.form before that tab's markup gets
  // replaced, so nothing typed is ever lost when switching tabs or
  // adding/removing a row.
  // ------------------------------------------------------------------

  function collectRuleRows(kind, nameField, filterEmpty) {
    const rows = [...document.querySelectorAll(`.rule-row[data-row-kind="${kind}"]`)];
    const result = rows.map((row) => ({
      [nameField]: row.querySelector(`[data-field="${nameField}"]`).value.trim(),
      grade: parseInt(row.querySelector('[data-field="grade"]').value, 10) || 0,
    }));
    return filterEmpty ? result.filter((r) => r[nameField]) : result;
  }

  function collectItemRows(filterEmpty) {
    const rows = [...document.querySelectorAll('.rule-row[data-row-kind="items"]')];
    const result = rows.map((row) => ({
      item: row.querySelector('[data-field="item"]').value.trim(),
      remove: row.querySelector('[data-field="remove"]').checked,
    }));
    return filterEmpty ? result.filter((r) => r.item) : result;
  }

  function collectIdentifierRows(filterEmpty) {
    const rows = [...document.querySelectorAll('.rule-row[data-row-kind="identifiers"]')];
    const result = rows.map((row) => row.querySelector('[data-field="identifier"]').value.trim());
    return filterEmpty ? result.filter(Boolean) : result;
  }

  function syncTabIntoState() {
    const tab = state.activeTab;
    const f = state.form;
    if (!f) return;

    if (tab === 'jobs') f.access.jobs = collectRuleRows('jobs', 'job', false);
    else if (tab === 'gangs') f.access.gangs = collectRuleRows('gangs', 'gang', false);
    else if (tab === 'items') f.access.items = collectItemRows(false);
    else if (tab === 'identifiers') f.access.identifiers = collectIdentifierRows(false);
    else if (tab === 'permission') { const e = el('f-permission'); if (e) f.access.permission = e.value.trim(); }
    else if (tab === 'keys') { const e = el('f-keys-enabled'); if (e) f.access.keys.enabled = e.checked; }
    else if (tab === 'password') {
      const enEl = el('f-pw-enabled');
      const rawEl = el('f-pw-raw');
      if (enEl) f.access.password.enabled = enEl.checked;
      if (rawEl) f.access.password.raw = rawEl.value;
    }
    // 'dependencies' has no free-text rows to sync - it is only ever
    // mutated directly via addDependency()/removeDependency().
  }

  function setTab(newTab) {
    syncTabIntoState();
    state.activeTab = newTab;
    rerenderTabBody();
  }

  function addRule(kind) {
    syncTabIntoState();
    const a = state.form.access;
    if (kind === 'jobs') a.jobs.push({ job: '', grade: 0 });
    else if (kind === 'gangs') a.gangs.push({ gang: '', grade: 0 });
    else if (kind === 'items') a.items.push({ item: '', remove: false });
    else if (kind === 'identifiers') a.identifiers.push('');
    rerenderTabBody();
  }

  function removeRule(kind, idx) {
    syncTabIntoState();
    const a = state.form.access;
    const arr = kind === 'jobs' ? a.jobs : kind === 'gangs' ? a.gangs : kind === 'items' ? a.items : a.identifiers;
    arr.splice(idx, 1);
    rerenderTabBody();
  }

  function addDependency() {
    const type = el('dep-type').value;
    const requiredState = el('dep-required-state').value;
    let id;

    if (type === 'door') {
      const searchVal = el('dep-door-search').value;
      const match = searchVal.match(/#(\d+)\)?\s*$/);
      if (!match) return;
      id = parseInt(match[1], 10);
      if (id === state.form.id) return; // cannot depend on itself
      if (!state.doors.some((d) => d.id === id)) return;
    } else {
      const switchVal = el('dep-switch-id').value.trim();
      if (!switchVal) return;
      id = switchVal;
    }

    state.form.dependencies.push({ type, id, requiredState });
    rerenderTabBody();
  }

  function removeDependency(idx) {
    state.form.dependencies.splice(idx, 1);
    rerenderTabBody();
  }

  // ------------------------------------------------------------------
  // Save / cancel
  // ------------------------------------------------------------------

  function setSaving(isSaving) {
    const btn = document.querySelector('[data-action="saveDoor"]');
    if (!btn) return;
    btn.disabled = isSaving;
    btn.textContent = isSaving ? 'Saving…' : (state.editingIsCreate ? 'Create Door' : 'Save Changes');
  }

  function saveDoor() {
    syncTabIntoState();
    const f = state.form;

    const payload = {
      id: f.id,
      label: (el('f-label').value.trim() || 'Unnamed Door'),
      model: f.model,
      coords: f.coords,
      group_id: el('f-group').value.trim(),
      auto_close: parseInt(el('f-autoclose').value, 10) || 0,
      fallback: !!el('f-fallback').checked,
      access: {
        mode: el('f-anymode').checked ? 'all' : 'any',
        jobs: f.access.jobs.filter((r) => r.job),
        gangs: f.access.gangs.filter((r) => r.gang),
        identifiers: f.access.identifiers.filter(Boolean),
        items: f.access.items.filter((r) => r.item),
        permission: f.access.permission || '',
        keys: { enabled: !!f.access.keys.enabled },
        password: { enabled: !!f.access.password.enabled, raw: f.access.password.raw || '' },
      },
      dependencies: f.dependencies,
    };

    setSaving(true);
    const callbackName = state.editingIsCreate ? 'createDoor' : 'updateDoor';

    fetchNui(callbackName, payload).then((res) => {
      setSaving(false);
      if (res && res.ok) {
        if (!state.editingIsCreate) {
          // Edit sessions stay inside the manage panel - create-mode
          // sessions are closed by the Lua side itself (which also
          // handles chaining a queued linked-group sibling, if any).
          if (res.door) upsertDoor(res.door);
          state.view = 'list';
          state.form = null;
          render();
        }
      }
    });
  }

  function cancelForm() {
    if (state.mode === 'create') {
      fetchNui('close', {});
      hide();
    } else {
      state.view = 'list';
      state.form = null;
      render();
    }
  }

  // ------------------------------------------------------------------
  // Message bus (Lua -> NUI)
  // ------------------------------------------------------------------

  window.addEventListener('message', (event) => {
    const msg = event.data;
    if (!msg || !msg.action) return;

    switch (msg.action) {
      case 'open':
        state.mode = msg.mode;
        state.doors = msg.doors || state.doors;
        state.accessLabels = msg.accessLabels || state.accessLabels;
        state.confirmDelete = null;
        if (msg.mode === 'create') {
          openFormFor(null, msg.draft, msg.defaults);
        } else {
          state.view = 'list';
          state.page = 1;
        }
        show();
        render();
        break;

      case 'close':
        hide();
        break;

      case 'doorAdded':
      case 'doorUpdated':
        upsertDoor(msg.door);
        if (state.mode === 'manage' && state.view === 'list') updateTableOnly();
        break;

      case 'doorRemoved':
        state.doors = state.doors.filter((d) => d.id !== msg.door);
        if (state.mode === 'manage' && state.view === 'list') updateTableOnly();
        break;

      case 'showPrompt':
        showInteractionPrompt(msg.key, msg.label, msg.position);
        break;

      case 'hidePrompt':
        hideInteractionPrompt();
        break;

      default:
        break;
    }
  });

  // ------------------------------------------------------------------
  // DOM event delegation
  // ------------------------------------------------------------------

  // No DOMContentLoaded wrapper needed here: index.html places this
  // <script> tag after the #app div, so by the time this file runs
  // (synchronously, during initial parse) the element already exists.
  {
    const app = el('app');

    app.addEventListener('click', (e) => {
      const target = e.target.closest('[data-action]');
      if (!target) return;

      const action = target.dataset.action;
      const id = target.dataset.id !== undefined ? parseInt(target.dataset.id, 10) : null;

      switch (action) {
        case 'closePanel':
          fetchNui('close', {});
          hide();
          break;

        case 'cancelForm':
          cancelForm();
          break;

        case 'placeNewDoor':
          fetchNui('startCreator', {});
          hide();
          break;

        case 'linkAnotherDoor':
          fetchNui('linkAnotherDoor', { id: state.form.id });
          hide();
          break;

        case 'editDoor': {
          const door = state.doors.find((d) => d.id === id);
          if (door) { openFormFor(door, null); render(); }
          break;
        }

        case 'locateDoor':
          fetchNui('locateDoor', { id });
          break;

        case 'teleportDoor':
          fetchNui('teleportToDoor', { id });
          break;

        case 'confirmDelete':
          state.confirmDelete = id;
          render();
          break;

        case 'cancelDelete':
          state.confirmDelete = null;
          render();
          break;

        case 'doDelete':
          fetchNui('deleteDoor', { id }).then((res) => {
            if (res && res.ok) {
              state.doors = state.doors.filter((d) => d.id !== id);
            }
            state.confirmDelete = null;
            render();
          });
          break;

        case 'toggleLock': {
          const locked = target.dataset.locked === '1';
          // The row live-patches itself via the doorUpdated broadcast
          // (client/main.lua -> NotifyNuiDoorChange), so no local
          // state mutation is needed here.
          fetchNui('toggleLock', { id, locked });
          break;
        }

        case 'setTab':
          setTab(target.dataset.tab);
          break;

        case 'addRule':
          addRule(target.dataset.kind);
          break;

        case 'removeRule':
          removeRule(target.dataset.kind, parseInt(target.dataset.idx, 10));
          break;

        case 'addDependency':
          addDependency();
          break;

        case 'removeDependency':
          removeDependency(parseInt(target.dataset.idx, 10));
          break;

        case 'saveDoor':
          saveDoor();
          break;

        case 'prevPage':
          if (state.page > 1) { state.page -= 1; updateTableOnly(); }
          break;

        case 'nextPage':
          state.page += 1;
          updateTableOnly();
          break;

        default:
          break;
      }
    });

    app.addEventListener('input', (e) => {
      if (e.target.id === 'search-input') {
        state.search = e.target.value;
        state.page = 1;
        updateTableOnly();
      }
    });

    app.addEventListener('change', (e) => {
      if (e.target.id === 'dep-type') {
        const isDoor = e.target.value === 'door';
        el('dep-door-search').style.display = isDoor ? '' : 'none';
        el('dep-switch-id').style.display = isDoor ? 'none' : '';
      } else if (e.target.id === 'f-pw-enabled') {
        // Re-render just the password tab so the code input shows/hides.
        state.form.access.password.enabled = e.target.checked;
        rerenderTabBody();
      }
    });
  }

  document.addEventListener('keydown', (e) => {
    if (e.key !== 'Escape' || !state.mode) return;
    if (state.mode === 'manage' && state.view === 'edit') {
      cancelForm();
    } else {
      fetchNui('close', {});
      hide();
    }
  });
})();
