// Armoury management panel (standalone, runs next to the React UI).
// Opened by the client with SendNUIMessage({ action: "setVisibleArmouryManage", data })
(function () {
    'use strict';

    const RESOURCE = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'p_policejob';
    const ALL = '__all';

    let data = null;          // last payload from the server
    let items = [];           // working copy being edited
    let original = '';        // serialised items at load time, for dirty tracking
    let itemLookup = {};      // name -> label from availableItems
    let activeCategory = ALL;
    let search = '';
    let openCards = new Set();
    let closeArmed = false;
    let saving = false;
    let uidCounter = 0;

    // ── Helpers ─────────────────────────────────────────────

    const t = (key, ...args) => {
        let text = (data && data.labels && data.labels[key]) || key;
        args.forEach((arg) => { text = text.replace('%s', arg); });
        return text;
    };

    const esc = (value) => String(value == null ? '' : value)
        .replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');

    const el = (id) => document.getElementById(id);

    const post = (endpoint, body) => fetch(`https://${RESOURCE}/${endpoint}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify(body || {}),
    }).then((res) => res.json()).catch(() => null);

    const serialise = () => JSON.stringify(items.map(({ uid, ...rest }) => rest));
    const isDirty = () => serialise() !== original;

    const itemLabel = (item) => itemLookup[item.name] || (item.name ? item.name : t('newItem'));
    const itemImage = (name) => (name ? `https://cfx-nui-ox_inventory/web/images/${name}.png` : null);

    const categoryList = () => {
        const seen = [];
        items.forEach((item) => {
            const category = (item.category || 'misc').toLowerCase();
            if (!seen.includes(category)) seen.push(category);
        });
        return seen;
    };

    const visibleItems = () => {
        const query = search.trim().toLowerCase();
        return items.filter((item) => {
            if (activeCategory !== ALL && (item.category || 'misc').toLowerCase() !== activeCategory) return false;
            if (!query) return true;
            return item.name.toLowerCase().includes(query) || itemLabel(item).toLowerCase().includes(query);
        });
    };

    // ── Skeleton ────────────────────────────────────────────

    function build() {
        const link = document.createElement('link');
        link.rel = 'stylesheet';
        link.href = './armoury_manage.css';
        document.head.appendChild(link);

        const root = document.createElement('div');
        root.id = 'am-root';
        root.innerHTML = `
            <div class="am-container">
                <div class="am-sidebar">
                    <div class="am-sidebar-header">
                        <div class="am-title"><i class="fa-solid fa-warehouse"></i><span id="am-title"></span></div>
                        <div class="am-subtitle" id="am-subtitle"></div>
                    </div>
                    <div class="am-nav" id="am-nav"></div>
                    <div class="am-sidebar-footer">
                        <button class="am-btn am-full" id="am-add"><i class="fa-solid fa-plus"></i><span></span></button>
                        <button class="am-btn am-full am-gray am-xs" id="am-discard"><i class="fa-solid fa-rotate-left"></i><span></span></button>
                    </div>
                </div>
                <div class="am-main">
                    <div class="am-header">
                        <div class="am-header-title" id="am-header-title"></div>
                        <div class="am-header-right">
                            <span class="am-dirty" id="am-dirty"><i class="fa-solid fa-circle-exclamation"></i><span></span></span>
                            <input class="am-input am-search" id="am-search" type="text" autocomplete="off" />
                            <button class="am-btn am-filled" id="am-save"><i class="fa-solid fa-floppy-disk"></i><span></span></button>
                            <button class="am-close" id="am-close"><i class="fa-solid fa-xmark"></i></button>
                        </div>
                    </div>
                    <div class="am-content">
                        <div class="am-error" id="am-error"></div>
                        <div id="am-list"></div>
                    </div>
                </div>
            </div>
            <datalist id="am-item-options"></datalist>
            <datalist id="am-category-options"></datalist>`;
        document.body.appendChild(root);

        el('am-add').addEventListener('click', addItem);
        el('am-discard').addEventListener('click', discard);
        el('am-save').addEventListener('click', save);
        el('am-close').addEventListener('click', requestClose);
        el('am-search').addEventListener('input', (e) => { search = e.target.value; renderList(); });
        el('am-list').addEventListener('input', onFieldInput);
        el('am-list').addEventListener('click', onListClick);
    }

    // ── Rendering ───────────────────────────────────────────

    function renderStatic() {
        el('am-title').textContent = t('title');
        el('am-subtitle').textContent = `${t('subtitle')} · ${data.armouryId}`;
        el('am-add').querySelector('span').textContent = t('addItem');
        el('am-discard').querySelector('span').textContent = t('discard');
        el('am-save').querySelector('span').textContent = t('save');
        el('am-dirty').querySelector('span').textContent = t('unsaved');
        el('am-search').placeholder = t('search');

        el('am-item-options').innerHTML = (data.availableItems || [])
            .map((item) => `<option value="${esc(item.name)}">${esc(item.label)}</option>`).join('');
    }

    function renderSidebar() {
        const categories = categoryList();
        const count = (category) => items.filter((item) => (item.category || 'misc').toLowerCase() === category).length;

        if (activeCategory !== ALL && !categories.includes(activeCategory)) activeCategory = ALL;

        const navButton = (key, icon, label, amount) => `
            <button class="am-nav-item ${activeCategory === key ? 'am-active' : ''}" data-category="${esc(key)}">
                <i class="fa-solid ${icon}"></i><span>${esc(label)}</span><span class="am-count">${amount}</span>
            </button>`;

        el('am-nav').innerHTML = navButton(ALL, 'fa-layer-group', t('allItems'), items.length)
            + categories.map((category) => navButton(category, category === 'weapons' ? 'fa-gun' : 'fa-box', category, count(category))).join('');

        el('am-nav').querySelectorAll('.am-nav-item').forEach((button) => {
            button.addEventListener('click', () => {
                activeCategory = button.dataset.category;
                renderSidebar();
                renderList();
            });
        });

        el('am-category-options').innerHTML = categories.map((category) => `<option value="${esc(category)}"></option>`).join('');
        el('am-header-title').textContent = activeCategory === ALL ? t('allItems') : activeCategory;
    }

    function cardHeader(item) {
        const image = itemImage(item.name);
        const icon = image
            ? `<img src="${esc(image)}" onerror="this.replaceWith(Object.assign(document.createElement('i'),{className:'fa-solid fa-box'}))" />`
            : '<i class="fa-solid fa-box"></i>';
        const stock = data.useStock ? `<span><i class="fa-solid fa-cubes"></i> ${esc(item.stock)}</span>` : '';

        return `
            <div class="am-card-left">
                <div class="am-card-icon">${icon}</div>
                <div style="min-width:0">
                    <div class="am-card-name">${esc(itemLabel(item))}</div>
                    <div class="am-card-meta">${esc(item.name || '—')}</div>
                </div>
            </div>
            <div class="am-card-right">
                ${stock}
                <span class="am-card-price">${Number(item.price) > 0 ? '$' + esc(item.price) : 'FREE'}</span>
                <i class="fa-solid ${openCards.has(item.uid) ? 'fa-chevron-up' : 'fa-chevron-down'}"></i>
            </div>`;
    }

    function cardBody(item) {
        const field = (label, inner) => `<div class="am-field"><label>${esc(label)}</label>${inner}</div>`;
        const input = (key, type, value, extra = '') =>
            `<input class="am-input" data-field="${key}" type="${type}" value="${esc(value)}" autocomplete="off" ${extra} />`;

        let grades = '';
        for (let grade = 0; grade <= (data.maxGrade || 0); grade++) {
            const value = item.limits[String(grade)];
            grades += field(t('grade', grade),
                `<input class="am-input" data-limit="${grade}" type="number" min="0" placeholder="∞" value="${value == null ? '' : esc(value)}" />`);
        }

        return `
            <div class="am-row">
                ${field(t('itemName'), input('name', 'text', item.name, 'list="am-item-options" spellcheck="false"'))}
                ${field(t('price'), input('price', 'number', item.price, 'min="0"'))}
            </div>
            <div class="am-row">
                ${field(t('category'), input('category', 'text', item.category, 'list="am-category-options" spellcheck="false"'))}
                ${field(t('minGrade'), input('minGrade', 'number', item.minGrade == null ? '' : item.minGrade, `min="0" max="${data.maxGrade}" placeholder="0"`))}
                ${data.useStock ? field(t('stock'), input('stock', 'number', item.stock, 'min="0"')) : ''}
            </div>
            <div class="am-row">
                ${field(t('licenses'), input('licenses', 'text', item.licenses.join(', '), 'spellcheck="false" placeholder="weapon"'))}
            </div>
            <div class="am-limits-title">${esc(t('limits'))}</div>
            <div class="am-limits-hint">${esc(t('limitsHint'))}</div>
            <div class="am-limits-grid">${grades}</div>
            <div style="margin-top:0.875rem">
                <button class="am-btn am-red am-xs" data-action="remove"><i class="fa-solid fa-trash"></i>${esc(t('removeItem'))}</button>
            </div>`;
    }

    function renderList() {
        const list = visibleItems();
        if (!list.length) {
            el('am-list').innerHTML = `<div class="am-empty">${esc(t('empty'))}</div>`;
        } else {
            el('am-list').innerHTML = list.map((item) => `
                <div class="am-card ${openCards.has(item.uid) ? 'am-open' : ''}" data-uid="${item.uid}">
                    <div class="am-card-header" data-action="toggle">${cardHeader(item)}</div>
                    <div class="am-card-body">${cardBody(item)}</div>
                </div>`).join('');
        }
        updateDirty();
    }

    function refreshCardHeader(item) {
        const header = document.querySelector(`.am-card[data-uid="${item.uid}"] .am-card-header`);
        if (header) header.innerHTML = cardHeader(item);
    }

    function updateDirty() {
        const dirty = isDirty();
        el('am-dirty').classList.toggle('am-show', dirty);
        el('am-save').disabled = !dirty || saving;
        el('am-discard').disabled = !dirty;
        if (!dirty) closeArmed = false;
    }

    function showError(message) {
        el('am-error').textContent = message || '';
        el('am-error').classList.toggle('am-show', !!message);
    }

    // ── Events ──────────────────────────────────────────────

    const findItem = (node) => {
        const card = node.closest('.am-card');
        return card ? items.find((item) => item.uid === Number(card.dataset.uid)) : null;
    };

    function onFieldInput(e) {
        const item = findItem(e.target);
        if (!item) return;
        const value = e.target.value;

        if (e.target.dataset.limit !== undefined) {
            const grade = e.target.dataset.limit;
            if (value === '') delete item.limits[grade];
            else item.limits[grade] = Math.max(0, Math.floor(Number(value) || 0));
        } else {
            switch (e.target.dataset.field) {
                case 'name': item.name = value.trim(); break;
                case 'price': item.price = Math.max(0, Math.floor(Number(value) || 0)); break;
                case 'stock': item.stock = Math.max(0, Math.floor(Number(value) || 0)); break;
                case 'minGrade': item.minGrade = value === '' ? null : Math.max(0, Math.floor(Number(value) || 0)); break;
                case 'category': item.category = value.trim().toLowerCase(); renderSidebar(); break;
                case 'licenses': item.licenses = value.split(',').map((s) => s.trim()).filter(Boolean); break;
            }
        }

        e.target.closest('.am-card').classList.remove('am-invalid');
        refreshCardHeader(item);
        updateDirty();
    }

    function onListClick(e) {
        const action = e.target.closest('[data-action]');
        if (!action) return;
        const item = findItem(action);
        if (!item) return;

        if (action.dataset.action === 'toggle') {
            if (openCards.has(item.uid)) openCards.delete(item.uid); else openCards.add(item.uid);
            action.closest('.am-card').classList.toggle('am-open');
            refreshCardHeader(item);
        } else if (action.dataset.action === 'remove') {
            items = items.filter((other) => other !== item);
            openCards.delete(item.uid);
            renderSidebar();
            renderList();
        }
    }

    function addItem() {
        const item = {
            uid: ++uidCounter,
            name: '',
            price: 0,
            category: activeCategory === ALL ? 'misc' : activeCategory,
            minGrade: null,
            licenses: [],
            stock: data.defaultStock || 0,
            limits: {},
        };
        items.push(item);
        openCards.add(item.uid);
        search = '';
        el('am-search').value = '';
        renderSidebar();
        renderList();

        const card = document.querySelector(`.am-card[data-uid="${item.uid}"]`);
        if (card) {
            card.scrollIntoView({ behavior: 'smooth', block: 'center' });
            card.querySelector('[data-field="name"]').focus();
        }
    }

    function discard() {
        load(data);
    }

    function validate() {
        const seen = new Set();
        const known = (data.availableItems || []).length > 0;

        for (const item of items) {
            let error = null;
            if (!item.name) error = t('errEmptyName');
            else if (seen.has(item.name)) error = t('errDuplicate', item.name);
            else if (known && !itemLookup[item.name]) error = t('errUnknown', item.name);
            seen.add(item.name);

            if (error) {
                activeCategory = ALL;
                search = '';
                el('am-search').value = '';
                openCards.add(item.uid);
                renderSidebar();
                renderList();
                const card = document.querySelector(`.am-card[data-uid="${item.uid}"]`);
                if (card) {
                    card.classList.add('am-invalid');
                    card.scrollIntoView({ behavior: 'smooth', block: 'center' });
                }
                return error;
            }
        }
        return null;
    }

    function serverError(code) {
        if (!code) return t('saveFailed');
        const [kind, name] = String(code).split(':');
        if (kind === 'empty_name') return t('errEmptyName');
        if (kind === 'duplicate') return t('errDuplicate', name);
        if (kind === 'unknown_item') return t('errUnknown', name);
        return t('saveFailed');
    }

    async function save() {
        if (saving) return;
        const error = validate();
        showError(error);
        if (error) return;

        saving = true;
        updateDirty();
        const payload = items.map(({ uid, ...rest }) => rest);
        const result = await post('armoury/manage/save', { items: payload });
        saving = false;

        if (result && result.success) {
            showError(null);
            if (result.data) load(result.data, true); else { original = serialise(); updateDirty(); }
        } else {
            showError(serverError(result && result.error));
            updateDirty();
        }
    }

    function requestClose() {
        if (isDirty() && !closeArmed) {
            closeArmed = true;
            showError(t('confirmClose'));
            return;
        }
        hide();
        post('armoury/manage/close');
    }

    // ── Lifecycle ───────────────────────────────────────────

    function load(payload, keepView) {
        data = payload;
        itemLookup = {};
        (data.availableItems || []).forEach((item) => { itemLookup[item.name] = item.label; });

        items = (data.items || []).map((item) => {
            if (item.label && !itemLookup[item.name]) itemLookup[item.name] = item.label;
            return {
                uid: ++uidCounter,
                name: item.name,
                price: Number(item.price) || 0,
                category: (item.category || 'misc').toLowerCase(),
                minGrade: item.minGrade == null ? null : Number(item.minGrade),
                licenses: Array.isArray(item.licenses) ? item.licenses : [],
                stock: Number(item.stock) || 0,
                limits: Object.assign({}, Array.isArray(item.limits) ? {} : item.limits),
            };
        });
        original = serialise();
        openCards = new Set();
        closeArmed = false;
        if (!keepView) {
            activeCategory = ALL;
            search = '';
            el('am-search').value = '';
        }

        showError(null);
        renderStatic();
        renderSidebar();
        renderList();
    }

    function show(payload) {
        load(payload);
        el('am-root').classList.add('am-visible');
    }

    function hide() {
        el('am-root').classList.remove('am-visible');
        data = null;
        items = [];
    }

    window.addEventListener('message', (event) => {
        const message = event.data;
        if (!message || message.action !== 'setVisibleArmouryManage') return;
        if (message.data) show(message.data); else hide();
    });

    window.addEventListener('keydown', (e) => {
        if (e.key === 'Escape' && el('am-root').classList.contains('am-visible')) requestClose();
    });

    if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', build);
    else build();
})();
