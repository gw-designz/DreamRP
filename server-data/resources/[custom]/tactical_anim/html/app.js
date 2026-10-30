const resource = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'tactical_anim';

// Slug endings that are a sprint/run variant of a base stance
const VARIANT_SUFFIXES = ['high_port_sprint', 'sling_sprint', '1hand_run', 'high_run', 'low_run'];
const STANDARD = 'standard';

const WORDS = { sul: 'SUL', '1hand': '1-Hand', '2hand': '2-Hand' };
const TAB_ICONS = { pistol_movement: 'gun', rifle_movement: 'runner' };
const LOCKED_PAGE = 'server';

const $ = (sel) => document.querySelector(sel);
const el = {
    settings: $('#settings'),
    tabs: $('#menu-tabs'),
    content: $('#menu-content'),
    reset: $('#reset-all'),
    resetLabel: $('#reset-all span'),
};

let categories = [];
let selected = {};
let page = null;
let resetTimer = null;

function make(tag, cls, text) {
    const e = document.createElement(tag);
    if (cls) e.className = cls;
    if (text !== undefined) e.textContent = text;
    return e;
}

function post(name, data = {}) {
    return fetch(`https://${resource}/${name}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify(data),
    })
        .then((r) => r.json())
        .catch(() => null);
}

// Lua encodes an empty table as []
function asMap(value) {
    return value && !Array.isArray(value) ? value : {};
}

function prettify(slug) {
    return slug
        .split('_')
        .map((w) => WORDS[w] || w.charAt(0).toUpperCase() + w.slice(1))
        .join(' ');
}

function splitSlug(slug, all) {
    for (const suffix of VARIANT_SUFFIXES) {
        const base = slug.slice(0, -(suffix.length + 1));
        if (slug.endsWith('_' + suffix) && all.includes(base)) {
            return { base, variant: suffix };
        }
    }
    return { base: slug, variant: STANDARD };
}

// base -> { variant -> slug }, keeping config order
function buildStances(styles) {
    const stances = new Map();
    for (const slug of styles) {
        const { base, variant } = splitSlug(slug, styles);
        if (!stances.has(base)) stances.set(base, {});
        stances.get(base)[variant] = slug;
    }
    return stances;
}

function pages() {
    const list = categories
        .filter((c) => !c.locked)
        .map((c) => ({ id: c.key, label: c.label, icon: TAB_ICONS[c.key] || 'gun', cat: c }));
    if (categories.some((c) => c.locked)) {
        list.push({ id: LOCKED_PAGE, label: 'Server Styles', icon: 'lock' });
    }
    return list;
}

function select(category, style) {
    selected = { ...selected };
    if (style) selected[category] = style;
    else delete selected[category];
    render();

    post('select', { category, style: style || false }).then((res) => {
        if (res) {
            selected = asMap(res.selected);
            render();
        }
    });
}

function row(title, desc, control, active, onClick) {
    const r = make('div', 'mrow' + (active ? ' focus' : ''));
    const text = make('div', 'mrow-text');
    text.appendChild(make('div', 'mrow-title', title));
    if (desc) {
        const d = make('div', 'mrow-desc');
        d.innerHTML = desc;
        text.appendChild(d);
    }
    r.append(text, control);
    if (onClick) r.addEventListener('click', onClick);
    else r.classList.add('locked');
    return r;
}

function seg(buttons) {
    const s = make('div', 'seg');
    for (const [label, on, onClick] of buttons) {
        const b = make('button', 'seg-btn' + (on ? ' on' : ''), label);
        b.type = 'button';
        b.addEventListener('click', (e) => {
            e.stopPropagation();
            onClick();
        });
        s.appendChild(b);
    }
    return s;
}

function lockTag() {
    const t = make('span', 'tag');
    t.append(make('i', 'ico i-lock'), make('span', '', 'Server'));
    return t;
}

function head(title, desc) {
    const h = make('div', 'page-head');
    h.append(make('h2', '', title), make('p', '', desc));
    return h;
}

function buildCategoryPage(cat, frag) {
    const current = selected[cat.key];
    const parts = current ? splitSlug(current, cat.styles) : null;
    const stances = buildStances(cat.styles);

    frag.appendChild(head(cat.label, 'Choose how your character carries the weapon.'));

    const defaults = make('div', 'mgroup');
    const useDefault = () => select(cat.key, null);
    defaults.appendChild(row(
        'Server default',
        `Uses the server style: <b>${prettify(cat.serverStyle)}</b>`,
        seg([[current ? 'Use default' : 'Active', !current, useDefault]]),
        !current,
        useDefault,
    ));
    frag.appendChild(defaults);

    const group = make('div', 'mgroup');
    for (const [base, variants] of stances) {
        const keys = Object.keys(variants);
        const active = parts && parts.base === base;
        const pick = (variant) => select(cat.key, variants[variant]);
        const pickStance = () => {
            const keep = parts && variants[parts.variant] ? parts.variant : null;
            pick(keep || (variants[STANDARD] ? STANDARD : keys[0]));
        };

        let desc = '';
        if (keys.length > 1) {
            const kind = keys.some((k) => k.endsWith('sprint')) ? 'sprint' : 'run';
            desc = active ? `Active with <b>${prettify(parts.variant)}</b> ${kind}` : `${keys.length} ${kind} styles`;
        } else if (active) {
            desc = '<b>Active</b>';
        }

        const buttons = keys.length > 1
            ? keys.map((k) => [prettify(k), active && parts.variant === k, () => pick(k)])
            : [[active ? 'Active' : 'Select', active, pickStance]];

        group.appendChild(row(prettify(base), desc, seg(buttons), active, pickStance));
    }
    frag.appendChild(group);
}

function buildLockedPage(frag) {
    frag.appendChild(head('Server Styles', 'Set by the server for everyone. These can’t be changed per player.'));
    const group = make('div', 'mgroup');
    for (const cat of categories.filter((c) => c.locked)) {
        group.appendChild(row(cat.label, prettify(cat.serverStyle), lockTag(), false, null));
    }
    frag.appendChild(group);
}

function buildTabs() {
    const frag = document.createDocumentFragment();
    for (const p of pages()) {
        const b = make('button', 'menu-tab');
        b.type = 'button';
        b.dataset.page = p.id;
        b.append(make('i', `ico i-${p.icon}`), make('span', '', p.label));
        b.addEventListener('click', () => showPage(p.id));
        frag.appendChild(b);
    }
    el.tabs.replaceChildren(frag);
}

function render() {
    const list = pages();
    const p = list.find((x) => x.id === page) || list[0];
    if (!p) return;
    page = p.id;

    el.tabs.querySelectorAll('.menu-tab').forEach((b) => b.classList.toggle('on', b.dataset.page === page));

    const frag = document.createDocumentFragment();
    if (p.cat) buildCategoryPage(p.cat, frag);
    else buildLockedPage(frag);

    const scroll = el.content.scrollTop;
    el.content.replaceChildren(frag);
    el.content.scrollTop = scroll;
}

function showPage(id) {
    page = id;
    render();
    el.content.scrollTop = 0;
}

function stepPage(dir) {
    const list = pages();
    const i = list.findIndex((p) => p.id === page);
    showPage(list[(i + dir + list.length) % list.length].id);
}

function clearResetConfirm() {
    clearTimeout(resetTimer);
    resetTimer = null;
    el.reset.classList.remove('confirm');
    el.resetLabel.textContent = 'Reset to default';
}

function close() {
    clearResetConfirm();
    post('close');
}

function fit() {
    document.documentElement.style.setProperty('--km', Math.min(innerHeight / 1080, innerWidth / 1920));
}

el.reset.addEventListener('click', () => {
    if (!resetTimer) {
        el.reset.classList.add('confirm');
        el.resetLabel.textContent = 'Click again to confirm';
        resetTimer = setTimeout(clearResetConfirm, 3000);
        return;
    }

    clearResetConfirm();
    selected = {};
    render();
    post('reset').then((res) => {
        if (res) {
            selected = asMap(res.selected);
            render();
        }
    });
});

$('#menu-close').addEventListener('click', close);
$('#save-close').addEventListener('click', close);

document.addEventListener('keyup', (e) => {
    if (el.settings.classList.contains('off')) return;
    if (e.key === 'Escape') close();
    else if (e.key === 'q' || e.key === 'Q') stepPage(-1);
    else if (e.key === 'e' || e.key === 'E') stepPage(1);
});

window.addEventListener('resize', fit);
fit();

window.addEventListener('message', ({ data }) => {
    if (data.action === 'open') {
        if (data.accent) document.documentElement.style.setProperty('--m-accent-rgb', data.accent);
        categories = data.categories || [];
        selected = asMap(data.selected);
        buildTabs();
        render();
        el.settings.classList.remove('off');
    } else if (data.action === 'close') {
        el.settings.classList.add('off');
    }
});
