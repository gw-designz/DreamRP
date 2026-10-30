'use strict';

const IS_FIVEM = typeof GetParentResourceName === 'function';
const RESOURCE = IS_FIVEM ? GetParentResourceName() : 'my-hud';

function post(name, data = {}) {
    if (!IS_FIVEM) return Promise.resolve(null);
    return fetch(`https://${RESOURCE}/${name}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify(data),
    }).then((r) => r.json()).catch(() => null);
}

const $ = (sel, root = document) => root.querySelector(sel);
const $$ = (sel, root = document) => [...root.querySelectorAll(sel)];
const clamp = (v, lo, hi) => Math.min(hi, Math.max(lo, Number(v) || 0));
const NS = 'http://www.w3.org/2000/svg';

function make(tag, className, text) {
    const e = document.createElement(tag);
    if (className) e.className = className;
    if (text !== undefined) e.textContent = text;
    return e;
}

function setText(e, text) {
    text = String(text);
    if (e.textContent !== text) e.textContent = text;
}

const root = document.documentElement;
const el = {
    hud: $('#hud'),
    strip: $('#strip'),
    voice: $('#voice'),
    minimap: $('#w-minimap'),
    map3d: $('#map3d'),
    heading: $('#heading'),
    zone: $('#zone'),
    street: $('#street'),
    cross: $('#cross'),
    locCross: $('#loc-cross'),
    wpArrow: $('.wp-arrow'),
    toastList: $('#toast-list'),
    controlBar: $('#control-bar'),
    gGear: $('#g-gear'),
    gLabel: $('#g-label'),
    fuelIco: $('#fuel-ico'),
    waypoint: $('#mm-waypoint'),
    wpDist: $('#wp-dist'),
    ammo: $('#w-ammo'),
    ammoClip: $('#ammo-clip'),
    bars: $('#w-bars'),
    barStamina: $('#bar-stamina'),
    barOxygen: $('#bar-oxygen'),
    speedo: $('#w-speedo'),
    gauge: $('.gauge'),
    rpmSegs: $('#rpm-segs'),
    rpmTrack: $('#rpm-track'),
    rpmInner: $('#rpm-inner'),
    rpmTicks: $('#rpm-ticks'),
    rpmFill: $('#rpm-fill'),
    clWedge: $('#cl-wedge'),
    clTrack: $('#cl-track'),
    clTicks: $('#cl-ticks'),
    clEdge: $('#cl-edge'),
    clNeedle: $('#cl-needle'),
    clTip: $('#cl-tip'),
    lnBar: $('#ln-bar'),
    fuelTrack: $('#fuel-track'),
    fuelFill: $('#fuel-fill'),
    gear: $('#gear'),
    speed: $('#speed'),
    speedDim: $('#speed-dim'),
    speedUnit: $('#speed-unit'),
    icoLights: $('#ico-lights'),
    icoBelt: $('#ico-belt'),
    icoLock: $('#ico-lock'),
    loc: $('#w-location'),
    settings: $('#settings'),
    editor: $('#editor'),
    calibrate: $('#calibrate'),
    calX: $('#cal-x'),
    calY: $('#cal-y'),
};

// One tile per stat under the minimap.
const stats = {};
$$('.st').forEach((e) => {
    stats[e.dataset.stat] = { el: e };
});

// Editor order.
const WIDGETS = {
    minimap: $('#w-minimap'),
    status: $('#w-status'),
    bars: $('#w-bars'),
    speedo: $('#w-speedo'),
    location: $('#w-location'),
    ammo: $('#w-ammo'),
    controls: $('#w-controls'),
    toasts: $('#w-toasts'),
    voicebox: $('#w-voicebox'),
    job: $('#w-job'),
    money: $('#w-money'),
    pid: $('#w-pid'),
    radio: $('#w-radio'),
    limit: $('#w-limit'),
    boat: $('#w-boat'),
    air: $('#w-air'),
    vcontrols: $('#w-vcontrols'),
};
const WIDGET_LABELS = {
    minimap: 'Minimap', status: 'Player status', bars: 'Stamina', speedo: 'Speedometer', location: 'Location',
    ammo: 'Weapon', controls: 'Key hints', toasts: 'Item toasts', voicebox: 'Voice', job: 'Job & clock',
    money: 'Money', pid: 'Player ID', radio: 'Radio channel', limit: 'Speed limit', boat: 'Boat info',
    air: 'Flight info', vcontrols: 'Vehicle controls',
};

const DEFAULT_SETTINGS = {
    hudStyle: 'circuit', statusStyle: 'auto', mapStyle: 'auto', locationStyle: 'auto', speedoStyle: 'modern', speedoBicycle: 'watch', speedoBoat: 'analog', speedoAir: 'modern', speedoTrain: 'linear', scale: 1.0, speedUnit: 'mph',
    showStatus: true, showVoice: true, showNeeds: true, hideFullNeeds: false, hideArmorAtZero: false,
    lowWarnings: true, showCircles: true, showBars: true, stressShake: true,
    showMinimap: true, minimapOnFoot: true, showCompass: true, showHeading: false, showLocation: true,
    showWaypoint: true, map3d: true, mapZoom: 0, mapOffsetX: 0, mapOffsetY: 0,
    showVehicle: true, beltWarning: true, showControls: true,
    showAmmo: true, showToasts: true,
    snapGrid: true,
    layout: {},
};

const state = {
    settings: JSON.parse(JSON.stringify(DEFAULT_SETTINGS)),
    config: {
        subIcons: { health: ['hunger'], armor: ['thirst', 'stress'] },
        thresholds: { lowHealth: 25, lowArmor: 25, needWarn: 30, needCrit: 15, fuelWarn: 20, oxygenCrit: 25 },
    },
    status: { health: 100, armor: 0, hunger: 100, thirst: 100, stress: 0, stamina: 100, oxygen: 100, underwater: false, dev: false },
    vehicle: { show: false, mode: 'car', speed: 0, unit: 'MPH', rpm: 0, gear: 'N', altitude: '', fuel: 100, engine: 100, indLeft: false, indRight: false, belt: false, beltable: true, moving: false, lights: false, locked: false },
    voice: { range: 2, talking: false, radio: false, channel: 0 },
    map: { show: false },
    compass: { heading: 0 },
    location: { zone: '', street: '', cross: '', waypoint: -1, wpBearing: 0 },
    ammo: { show: false, clip: 0, reserve: 0, name: '' },
    layout: { mx: 0, my: 0 },
    minimap: null,
    mode: 'hud', // 'hud' | 'menu' | 'editor' | 'calibrate'
    devAccess: false,
    dev: null, // set from DEV_DEFAULTS below
};

const kr = () => window.innerHeight / 1080;
const classic = () => state.settings.hudStyle === 'classic';

// Per-module styles; 'auto' follows the HUD style (mapStyle() in client/minimap.lua mirrors this).
const AUTO_STYLES = {
    statusStyle: { circuit: 'tiles', classic: 'rings' },
    mapStyle: { circuit: 'brackets', classic: 'clean' },
    locationStyle: { circuit: 'bar', classic: 'pills' },
};
function styleOf(key) {
    const v = state.settings[key];
    return v && v !== 'auto' ? v : AUTO_STYLES[key][classic() ? 'classic' : 'circuit'];
}

/* ---------- layout ---------- */

function getLayout(name) {
    const l = state.settings.layout[name] || {};
    return { x: Number(l.x) || 0, y: Number(l.y) || 0, s: Number(l.s) || 1 };
}

function setLayout(name, patch) {
    const next = Object.assign(getLayout(name), patch);
    if (next.x === 0 && next.y === 0 && next.s === 1) delete state.settings.layout[name];
    else state.settings.layout[name] = next;
    applyWidget(name);
    if (name === 'minimap' && previewSync) previewSync();
}

function applyWidget(name) {
    if (name === 'minimap') return applyMinimap();
    const w = WIDGETS[name];
    const l = getLayout(name);
    w.style.setProperty('--ox', l.x);
    w.style.setProperty('--oy', l.y);
    w.style.setProperty('--s', l.s);
}

function applyLayout() {
    const h = window.innerHeight;
    const w = window.innerWidth;
    root.style.setProperty('--mx', `${state.layout.mx * w}px`);
    root.style.setProperty('--my', `${state.layout.my * h}px`);
    root.style.setProperty('--k', kr() * state.settings.scale);
    root.style.setProperty('--kr', kr());
    root.style.setProperty('--km', Math.min(h / 1080, w / 1920));
    Object.keys(WIDGETS).forEach(applyWidget);
}

// Lua sends the map center without the editor offset; the offset and size are applied
// here and in client/minimap.lua with the same formula, so frame and radar stay together.
function applyMinimap() {
    const m = state.minimap;
    if (!m) return;
    const l = getLayout('minimap');
    el.minimap.style.setProperty('--mm-w', `${m.width}px`);
    el.minimap.style.setProperty('--mm-h', `${m.height}px`);
    const x = m.cx * window.innerWidth + l.x * kr();
    const y = m.cy * window.innerHeight + l.y * kr();
    const s = m.kh * window.innerHeight * l.s;
    el.minimap.style.transform = `translate(${x}px, ${y}px) scale(${s})`;
    // 3D minimap canvas: the map rectangle plus OVERHANG (0.1 of its height) on each side
    const w = m.width * s;
    const h = m.height * s;
    const o = h * 0.1;
    // the round map is a square whose corner radius is half its side
    const corner = styleOf('mapStyle') === 'circle' ? m.height / 2 : 2;
    Object.assign(el.map3d.style, {
        left: `${x - w / 2 - o}px`, top: `${y - h / 2 - o}px`,
        width: `${w + 2 * o}px`, height: `${h + 2 * o}px`, letterSpacing: `${corner * s}px`,
    });
}

window.addEventListener('resize', applyLayout);

/* ---------- status ---------- */

// --v (0-1) drives the tile level / ring / bar of each status style; --n (whole percent)
// is the readout of the numbers style.
function setBar(name, value) {
    const v = clamp(value, 0, 100);
    stats[name].el.style.setProperty('--v', v / 100);
    stats[name].el.style.setProperty('--n', Math.round(v));
}

function levelClass(e, level, st, th) {
    e.classList.toggle('warn', st.lowWarnings && level < th.needWarn && level >= th.needCrit);
    e.classList.toggle('crit', st.lowWarnings && level < th.needCrit);
}

const setV = (e, value) => e.style.setProperty('--v', clamp(value, 0, 100) / 100);

// Extra stats (stress, oxygen, radio, dev, voice) only show while they have something to say.
function setExtra(name, show, value) {
    stats[name].el.classList.toggle('off', !show);
    setBar(name, value);
}

function renderStatus() {
    const s = state.status;
    const st = state.settings;
    const th = state.config.thresholds;

    setBar('health', s.health);
    setBar('armor', s.armor);
    stats.health.el.classList.toggle('low', st.lowWarnings && s.health <= th.lowHealth);
    stats.armor.el.classList.toggle('low', st.lowWarnings && s.armor > 0 && s.armor <= th.lowArmor);
    // the rings drop armor while there is none
    stats.armor.el.classList.toggle('off', st.hideArmorAtZero && s.armor <= 0);
    setBar('stamina', s.stamina);

    for (const name of ['hunger', 'thirst']) {
        setBar(name, s[name]);
        stats[name].el.classList.toggle('off', !st.showNeeds || (st.hideFullNeeds && s[name] >= 100));
        levelClass(stats[name].el, s[name], st, th);
    }
    setExtra('dev', Boolean(s.dev), 100);
    setExtra('stress', s.stress > 0, s.stress);
    setExtra('oxygen', Boolean(s.underwater), s.oxygen);

    // Stamina / oxygen bars only while draining.
    setV($('.sbar-fill', el.barStamina), s.stamina);
    setV($('.sbar-fill', el.barOxygen), s.oxygen);
    el.barOxygen.classList.toggle('full', !s.underwater && s.oxygen >= 100);
    el.barOxygen.classList.toggle('crit', st.lowWarnings && s.oxygen <= th.oxygenCrit);
    el.bars.classList.toggle('off', s.stamina >= 100 && s.oxygen >= 100 && !s.underwater);
}

// The mic shows while talking or tuned to a radio; its split bar is the voice range.
function renderVoice() {
    const v = state.voice;
    const range = clamp(v.range, 1, 3);
    el.voice.dataset.range = range;
    el.voice.classList.toggle('talking', Boolean(v.talking));
    el.voice.classList.toggle('radio', Boolean(v.radio));
    setExtra('voice', Boolean(v.talking || v.radio), (range / 3) * 100);
    setExtra('radio', v.channel > 0, 100);
    if (typeof renderVoiceBox === 'function') renderVoiceBox();
}

/* ---------- speedometer ---------- */

// Arc angles in degrees clockwise from 12 o'clock. The RPM arc runs 0-9 (x1000) around
// the speed; the fuel arc sits outside it on the left and fills from the bottom up.
const RPM_FROM = -140;
const RPM_TO = 140;
const RPM_R = 112;
const NUM_R = 95;
const NUM_FROM = -135;
const NUM_STEP = 30;
const FUEL_R = 134;
const FUEL_FROM = -132;
const FUEL_TO = -44;
const REDLINE = 90;
const TICK_R = 121; // tick ring just outside the RPM arc; majors line up with the numerals
const TICK_STEP = 5;
const INNER_R = 78;

const polar = (r, deg) => {
    const a = (deg * Math.PI) / 180;
    return `${(Math.sin(a) * r).toFixed(2)} ${(-Math.cos(a) * r).toFixed(2)}`;
};
// clockwise when to > from, else anticlockwise (so a fill can grow upwards on the right side)
const arc = (r, from, to) => `M ${polar(r, from)} A ${r} ${r} 0 ${Math.abs(to - from) > 180 ? 1 : 0} ${to >= from ? 1 : 0} ${polar(r, to)}`;

function buildGauge() {
    el.rpmTrack.setAttribute('d', arc(RPM_R, RPM_FROM, RPM_TO));
    el.rpmFill.setAttribute('d', arc(RPM_R, RPM_FROM, RPM_TO));
    const frag = document.createDocumentFragment();
    for (let i = 0; i <= 9; i++) {
        const t = document.createElementNS(NS, 'text');
        const [x, y] = polar(NUM_R, NUM_FROM + i * NUM_STEP).split(' ');
        t.setAttribute('x', x);
        t.setAttribute('y', y);
        t.textContent = String(i);
        frag.appendChild(t);
    }
    el.rpmSegs.replaceChildren(frag);
    const ticks = document.createDocumentFragment();
    for (let a = RPM_FROM; a <= RPM_TO; a += TICK_STEP) {
        const major = (a - NUM_FROM) % NUM_STEP === 0;
        const [x1, y1] = polar(TICK_R, a).split(' ');
        const [x2, y2] = polar(TICK_R + (major ? 8 : 4), a).split(' ');
        const line = document.createElementNS(NS, 'line');
        Object.entries({ x1, y1, x2, y2 }).forEach(([k, v]) => line.setAttribute(k, v));
        if (major) line.setAttribute('class', 'major');
        ticks.appendChild(line);
    }
    el.rpmTicks.replaceChildren(ticks);
    el.rpmInner.setAttribute('d', arc(INNER_R, RPM_FROM, RPM_TO));
    el.fuelTrack.setAttribute('d', arc(FUEL_R, FUEL_FROM, FUEL_TO));
    el.fuelFill.setAttribute('d', arc(FUEL_R, FUEL_FROM, FUEL_TO));
}

// Classic: a red wedge from the start of the sweep to a needle, over a tick ring.
const CL_R = 118;
const CL_FROM = -128;
const CL_TO = 128;
const CL_TICKS = 21;

function buildClassicGauge() {
    el.clTrack.setAttribute('d', arc(CL_R, CL_FROM, CL_TO));
    const frag = document.createDocumentFragment();
    for (let i = 0; i < CL_TICKS; i++) {
        const deg = CL_FROM + (i * (CL_TO - CL_FROM)) / (CL_TICKS - 1);
        const [x1, y1] = polar(CL_R - 18, deg).split(' ');
        const [x2, y2] = polar(CL_R - 12, deg).split(' ');
        const line = document.createElementNS(NS, 'line');
        Object.entries({ x1, y1, x2, y2 }).forEach(([k, v]) => line.setAttribute(k, v));
        frag.appendChild(line);
    }
    el.clTicks.replaceChildren(frag);
}

function renderClassicGauge(rpm) {
    const deg = CL_FROM + (rpm / 100) * (CL_TO - CL_FROM);
    const sweep = Math.max(deg, CL_FROM + 0.5);
    el.clWedge.setAttribute('d', `M 0 0 L ${polar(CL_R, CL_FROM)} A ${CL_R} ${CL_R} 0 ${sweep - CL_FROM > 180 ? 1 : 0} 1 ${polar(CL_R, sweep)} Z`);
    el.clEdge.setAttribute('d', arc(CL_R, CL_FROM, sweep));
    const [x1, y1] = polar(18, deg).split(' ');
    const [x2, y2] = polar(CL_R, deg).split(' ');
    Object.entries({ x1, y1, x2, y2 }).forEach(([k, v]) => el.clNeedle.setAttribute(k, v));
    el.clTip.setAttribute('cx', x2);
    el.clTip.setAttribute('cy', y2);
}

// Speedometer styles (Modern Pro, Classic Analog, Classic Dual, Digital Linear, Tesla Style,
// Fitness Watch) are declared in index.html: [data-arc="r from to"] paths, [data-scale] tick
// groups, .ndl needles driven by CSS variables, and [data-bind] text filled in renderVehicle.
// Scales: max / step (majors) / minor in scale units, base = label of the first major.
const SCALES = {
    mp: { max: 4, step: 1, minor: 1, base: 1 },    // modern pro: 1-5
    an: { max: 8, step: 1, minor: 0.5, base: 1 },  // classic analog: 1-9 (x1000 RPM)
    anf: { max: 8, step: 2, minor: 1 },            // classic analog fuel gauge
    dd: { max: 4, step: 1, minor: 1 },             // classic dual: plain majors
};
const SPEED_SCALES = { MPH: { max: 160, step: 20, minor: 10 }, KMH: { max: 280, step: 40, minor: 20 }, KNOTS: { max: 160, step: 20, minor: 10 } };
const speedScale = (unit) => SPEED_SCALES[String(unit).toUpperCase()] || SPEED_SCALES.MPH;
const LN_COUNT = 20;
let scaleUnit = '';

function buildScale(g, unit) {
    const { max, step, minor, base = 0 } = g.dataset.scale === 'speed' ? speedScale(unit) : SCALES[g.dataset.scale];
    const r = Number(g.dataset.r);
    const len = Number(g.dataset.len);
    const numR = Number(g.dataset.numR);
    const from = Number(g.dataset.from ?? -135);
    const to = Number(g.dataset.to ?? 135);
    const redFrom = Number(g.dataset.redFrom ?? Infinity);
    const frag = document.createDocumentFragment();
    for (let i = 0; i * minor <= max; i++) {
        const s = i * minor;
        const deg = from + (s / max) * (to - from);
        const major = Math.abs(s / step - Math.round(s / step)) < 1e-6;
        const [x1, y1] = polar(r - (major ? len : len / 2), deg).split(' ');
        const [x2, y2] = polar(r, deg).split(' ');
        const line = document.createElementNS(NS, 'line');
        Object.entries({ x1, y1, x2, y2 }).forEach(([k, v]) => line.setAttribute(k, v));
        line.setAttribute('class', `${major ? 'major' : ''} ${s >= redFrom ? 'red' : ''}`.trim());
        frag.appendChild(line);
        if (!major || !numR) continue;
        const t = document.createElementNS(NS, 'text');
        const [x, y] = polar(numR, deg).split(' ');
        t.setAttribute('x', x);
        t.setAttribute('y', y);
        t.textContent = String(base + s);
        frag.appendChild(t);
    }
    g.replaceChildren(frag);
}

function buildStyleGauges() {
    $$('[data-arc]', el.gauge).forEach((p) => p.setAttribute('d', arc(...p.dataset.arc.split(' ').map(Number))));
    $$('[data-scale]:not([data-scale="speed"])', el.gauge).forEach((g) => buildScale(g));
    // digital linear: rounded upright RPM cells; the last tenth turns red when lit
    const frag = document.createDocumentFragment();
    for (let i = 0; i < LN_COUNT; i++) {
        const p = document.createElementNS(NS, 'rect');
        Object.entries({ x: -140 + i * 10.6, y: -59, width: 6.4, height: 52, rx: 2.5 }).forEach(([k, v]) => p.setAttribute(k, v));
        if (i >= LN_COUNT * REDLINE / 100) p.setAttribute('class', 'red');
        frag.appendChild(p);
    }
    el.lnBar.replaceChildren(frag);
}

const binds = $$('[data-bind]', el.gauge);
const ODO_UNITS = { MPH: 'MI', KMH: 'KM', KNOTS: 'NM' };
let trip = 0;
let tripAt = 0;

// Distance driven since getting in, from speed (per hour) x time.
function updateTrip(show, speed) {
    if (!show) {
        trip = 0;
        tripAt = 0;
        return;
    }
    const now = performance.now();
    if (tripAt) trip += (speed * Math.min(now - tripAt, 2000)) / 3.6e6;
    tripAt = now;
}

// Settings > Vehicle picks a style per vehicle class.
const CLASS_STYLES = { bicycle: 'speedoBicycle', boat: 'speedoBoat', air: 'speedoAir', train: 'speedoTrain' };
const SPEEDO_IDS = ['modern', 'analog', 'linear', 'ev', 'dual', 'watch'];
function speedoStyle() {
    const v = state.settings[CLASS_STYLES[state.vehicle.mode] || 'speedoStyle'];
    return SPEEDO_IDS.includes(v) ? v : DEFAULT_SETTINGS[CLASS_STYLES[state.vehicle.mode] || 'speedoStyle'];
}

let litCells = -1;

const UNIT_LABELS = { MPH: 'MP/H', KMH: 'KM/H' };
let litSegments = -1;

function renderVehicle() {
    const v = state.vehicle;
    const st = state.settings;
    const th = state.config.thresholds;
    const show = Boolean(v.show && st.showVehicle);
    el.speedo.classList.toggle('off', !show);
    el.hud.classList.toggle('in-vehicle', show);

    const rpm = clamp(v.rpm, 0, 100);
    // --rpm / --fuel are set on the gauge so every style's fill inherits them
    el.gauge.style.setProperty('--rpm', rpm);
    el.gauge.classList.toggle('redline', rpm >= REDLINE);
    // a number lights once the arc reaches its angle
    const fillAngle = RPM_FROM + (rpm / 100) * (RPM_TO - RPM_FROM);
    const lit = rpm > 0 ? Math.floor((fillAngle - NUM_FROM) / NUM_STEP) + 1 : 0;
    if (lit !== litSegments) {
        litSegments = lit;
        el.rpmSegs.childNodes.forEach((t, i) => t.classList.toggle('on', i < lit));
    }
    renderClassicGauge(rpm);
    const cells = Math.round((rpm / 100) * LN_COUNT);
    if (cells !== litCells) {
        litCells = cells;
        el.lnBar.childNodes.forEach((c, i) => c.classList.toggle('on', i < cells));
    }
    if (v.unit !== scaleUnit) {
        scaleUnit = v.unit;
        $$('[data-scale="speed"]', el.gauge).forEach((g) => buildScale(g, v.unit));
    }
    root.dataset.speedo = speedoStyle();

    const speed = Math.min(999, Math.max(0, Math.round(v.speed)));
    const digits = speed > 0 ? String(speed) : '';
    setText(el.speed, digits);
    setText(el.speedDim, '0'.repeat(3 - digits.length));
    setText(el.speedUnit, speedoStyle() === 'arc' ? UNIT_LABELS[String(v.unit).toUpperCase()] || v.unit : v.unit);
    el.gauge.style.setProperty('--spd', clamp((speed / speedScale(v.unit).max) * 100, 0, 100));
    const engine = clamp(v.engine ?? 100, 0, 100);
    el.gauge.style.setProperty('--engine', engine);
    updateTrip(show, speed);

    // car | electric | air | boat | bicycle | train: redline, plug vs pump icon, gear vs altitude
    const MODES = ['car', 'electric', 'air', 'boat', 'bicycle', 'train'];
    const mode = MODES.includes(v.mode) ? v.mode : 'car';
    for (const m of MODES) el.gauge.classList.toggle(m, m === mode);
    const odo = Math.floor(trip);
    const values = {
        speed, speedDim: '0'.repeat(3 - digits.length), speedLit: digits, speed1: speed.toFixed(1),
        gear: mode === 'air' ? v.altitude : v.gear, unit: v.unit, unitLower: String(v.unit).toLowerCase(),
        fuelPct: `${Math.round(clamp(v.fuel, 0, 100))}%`, enginePct: `${Math.round(engine)}%`,
        odo5: String(odo).padStart(5, '0'), odo6: String(odo).padStart(6, '0'), odoUnit: ODO_UNITS[String(v.unit).toUpperCase()] || 'MI',
        // the watch style's heart rate and cadence are made up from speed and stamina
        heart: Math.round(68 + Math.min(speed, 50) * 1.5 + (100 - clamp(state.status.stamina, 0, 100)) * 0.35),
        cadence: Math.round(Math.min(speed, 45) * 3.2),
    };
    binds.forEach((b) => setText(b, values[b.dataset.bind]));
    el.gauge.classList.toggle('engine-low', st.lowWarnings && engine <= 30);
    el.gauge.classList.toggle('ind-left', Boolean(v.indLeft));
    el.gauge.classList.toggle('ind-right', Boolean(v.indRight));
    el.gauge.classList.toggle('lights-on', Boolean(v.lights));
    el.gauge.classList.toggle('locked', Boolean(v.locked));
    const air = mode === 'air';
    el.gGear.classList.toggle('alt', air);
    setText(el.gear, air ? v.altitude : v.gear);
    el.fuelIco.classList.toggle('i-plug', mode === 'electric');
    el.fuelIco.classList.toggle('i-fuel', mode !== 'electric');

    el.gauge.style.setProperty('--fuel', clamp(v.fuel, 0, 100));
    el.gauge.classList.toggle('fuel-low', st.lowWarnings && v.fuel <= th.fuelWarn);

    el.icoLights.classList.toggle('on', Boolean(v.lights));
    el.icoLock.classList.toggle('on', Boolean(v.locked));
    // the belt icon only shows (red) while unbuckled
    const unbuckled = v.beltable && !v.belt;
    el.icoBelt.classList.toggle('alert', unbuckled);
    el.icoBelt.classList.toggle('blink', unbuckled && v.moving && st.beltWarning);
    el.gauge.classList.toggle('belted', Boolean(v.beltable && v.belt));
    el.gauge.classList.toggle('belt-blink', unbuckled && v.moving && st.beltWarning);
    if (typeof renderVehicleExtras === 'function') renderVehicleExtras();
}

/* ---------- minimap ---------- */

const DIRECTIONS = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];

// Compass location style: a tape of ticks and directions from -180 to 540 degrees, slid so the
// heading sits under the centre mark. The window shows CMP_HALF degrees either side, so any
// heading in 0-359 stays inside the tape and the wrap at north never shows.
const CMP_PPD = 2.4;  // tape px per degree
const CMP_W = 300;    // window width, .compass in style.css
const CMP_HALF = CMP_W / 2 / CMP_PPD;

function buildCompass() {
    const frag = document.createDocumentFragment();
    for (let d = -180; d <= 540; d += 15) {
        const t = make('span', d % 45 === 0 ? 'cmp-tick major' : 'cmp-tick');
        t.style.left = `${(d + 180) * CMP_PPD}px`;
        if (d % 45 === 0) {
            const dir = DIRECTIONS[(((d / 45) % 8) + 8) % 8];
            t.appendChild(make('b', d % 90 === 0 ? 'cardinal' : '', dir));
        }
        frag.appendChild(t);
    }
    $('#cmp-strip').replaceChildren(frag);
}

// Heading arrives as a compass bearing (client/main.lua converts it): 90 = east.
function renderCompass() {
    const h = Math.round(state.compass.heading) % 360;
    const dir = DIRECTIONS[Math.round(h / 45) % 8];
    setText(el.heading, state.settings.showHeading ? `${dir} ${h}°` : dir);
    $('#cmp-strip').style.transform = `translateX(${CMP_W / 2 - (h + 180) * CMP_PPD}px)`;
    setText($('#cmp-deg'), `${h}°`);
    renderWaypointArrow();
}

let wpRotation = 0;
let wpLastRel = null;

// The arrow points at the waypoint relative to where the camera faces (unwrapped like the ring).
function renderWaypointArrow() {
    const rel = (((state.location.wpBearing - state.compass.heading) % 360) + 360) % 360;
    wpRotation = wpLastRel === null ? rel : wpRotation + ((rel - wpLastRel + 540) % 360) - 180;
    wpLastRel = rel;
    el.wpArrow.style.setProperty('--wp-rot', `${wpRotation}deg`);
    // the compass tape marks the waypoint, pinned to the nearer edge while it is off the tape
    const side = rel > 180 ? rel - 360 : rel;
    const edge = CMP_HALF - 6;
    const wp = $('#cmp-wp');
    wp.style.left = `${CMP_W / 2 + clamp(side, -edge, edge) * CMP_PPD}px`;
    wp.classList.toggle('off', !(state.location.waypoint >= 0));
    wp.classList.toggle('edge', Math.abs(side) > edge);
}

// Short distances switch to feet / meters.
function formatDistance(meters) {
    if (state.settings.speedUnit === 'kmh') {
        return meters < 1000 ? `${Math.round(meters / 10) * 10} m` : `${(meters / 1000).toFixed(2)} km`;
    }
    const miles = meters / 1609.344;
    return miles < 0.1 ? `${Math.round((meters * 3.28084) / 10) * 10} ft` : `${miles.toFixed(2)} mi`;
}

function renderLocation() {
    const l = state.location;
    setText(el.zone, l.zone || '');
    setText(el.street, l.street || '');
    setText(el.cross, l.cross || '');
    el.locCross.classList.toggle('off', !l.cross);
    $('#loc-zone').classList.toggle('empty', !l.zone);
    $('#loc-street').classList.toggle('empty', !l.street);
    const hasWaypoint = l.waypoint >= 0;
    el.waypoint.classList.toggle('off', !hasWaypoint);
    setText(el.wpDist, formatDistance(hasWaypoint ? l.waypoint : 0));
    renderWaypointArrow();
}

function renderMap() {
    el.minimap.classList.toggle('off', !state.map.show);
    WIDGETS.location.classList.toggle('off', state.map.location === false);
}

function renderAmmo() {
    const a = state.ammo;
    el.ammo.classList.toggle('off', !a.show);
    setText(el.ammoClip, a.clip);
}

/* ---------- item toasts ---------- */

const MAX_TOASTS = 4;
const SAMPLE_TOASTS = [{ label: 'Pistol', status: 'Equipped', icon: 'gun' }, { label: 'Water', status: 'Used x1', icon: 'cup' }];

function showToast(t) {
    const card = make('div', 'toast');
    const img = make('div', 'toast-img');
    // Only nui:// and https:// images (inventory item images); anything else falls back to an icon.
    if (typeof t.image === 'string' && /^(nui|https):\/\//.test(t.image)) {
        const i = make('img');
        i.src = t.image;
        i.alt = '';
        img.appendChild(i);
    } else {
        img.appendChild(make('i', `ico i-${/^[a-z]+$/.test(t.icon || '') ? t.icon : 'gun'}`));
    }
    const body = make('div', 'toast-body');
    body.append(make('div', 'toast-name', t.label || ''), make('div', 'toast-status', t.status || ''));
    card.append(img, body);
    el.toastList.prepend(card);
    while (el.toastList.childElementCount > MAX_TOASTS) el.toastList.lastElementChild.remove();
    if (t.sticky) return;
    setTimeout(() => {
        card.classList.add('out');
        setTimeout(() => card.remove(), 320);
    }, clamp(t.duration || 4000, 1000, 15000));
}

/* ---------- controls bar ---------- */

// One bar for two channels, both resolved to final key labels by client/controls.lua:
// prompts (ShowPrompts or text UI captured from other scripts) and the vehicle key hints.
// Prompts win while they are up; hiding them brings the vehicle hints back if still active.
const controls = { prompts: null, hints: null, dev: null, sample: null };

const SAMPLE_CONTROLS = [
    { key: 'L', label: 'Lock' }, { key: 'G', label: 'Engine' }, { key: 'B', label: 'Seatbelt' },
    { key: 'H', label: 'Lights' }, { key: 'F', label: 'Exit' },
];

// Keys drawn as an icon instead of text.
const KEY_ICONS = { WHEELUP: 'i-wheel-up', WHEELDOWN: 'i-wheel-down' };

function renderControlBar() {
    const items = controls.prompts || controls.hints || controls.dev || controls.sample;
    el.controlBar.classList.toggle('off', !items);
    if (!items) return;
    const frag = document.createDocumentFragment();
    for (const item of items) {
        const p = make('div', 'prompt');
        if (item.key) {
            const icon = KEY_ICONS[item.key.toUpperCase()];
            const g = make('span', item.circle ? 'glyph circle' : 'glyph', icon ? '' : item.key);
            if (icon) {
                g.classList.add('icon');
                g.appendChild(make('i', `ico ${icon}`));
            }
            p.appendChild(g);
        }
        if (item.label) p.appendChild(make('span', 'prompt-label', item.label));
        frag.appendChild(p);
    }
    el.controlBar.replaceChildren(frag);
}

/* ---------- settings ---------- */

// Browser preview only: redraws the stand-in radar, which Lua places in game (set by the demo block).
let previewSync = null;

function applySettings() {
    const st = state.settings;
    root.dataset.style = classic() ? 'classic' : 'circuit';
    root.dataset.status = styleOf('statusStyle');
    root.dataset.map = styleOf('mapStyle');
    root.dataset.loc = styleOf('locationStyle');
    root.dataset.speedo = speedoStyle();
    applyLayout();
    for (const name of ['health', 'armor', 'hunger', 'thirst']) stats[name].el.classList.toggle('disabled', !st.showStatus);
    el.voice.classList.toggle('disabled', !st.showVoice);
    WIDGETS.ammo.classList.toggle('disabled', !st.showAmmo);
    WIDGETS.toasts.classList.toggle('disabled', !st.showToasts);
    WIDGETS.controls.classList.toggle('disabled', !st.showControls);
    for (const name of ['stress', 'oxygen', 'radio', 'dev']) stats[name].el.classList.toggle('disabled', !st.showCircles);
    WIDGETS.bars.classList.toggle('disabled', !st.showBars);
    WIDGETS.speedo.classList.toggle('disabled', !st.showVehicle);
    el.loc.classList.toggle('no-compass', !st.showCompass);
    el.loc.classList.toggle('no-heading', !st.showHeading);
    el.loc.classList.toggle('no-location', !st.showLocation);
    el.loc.classList.toggle('no-waypoint', !st.showWaypoint);
    WIDGETS.location.classList.toggle('disabled', !st.showCompass && !st.showLocation && !st.showWaypoint);
    renderStatus();
    renderVehicle();
    renderCompass();
    renderLocation();
    if (typeof applyUiSettings === 'function') applyUiSettings();
    if (previewSync) previewSync();
}

/* ---------- minimap calibration ---------- */

function renderCalibration() {
    setText(el.calX, state.settings.mapOffsetX);
    setText(el.calY, state.settings.mapOffsetY);
}

function startCalibration() {
    renderCalibration();
    setMode('calibrate');
}

function nudgeMap(dx, dy) {
    state.settings.mapOffsetX = clamp(state.settings.mapOffsetX + dx, -60, 60);
    state.settings.mapOffsetY = clamp(state.settings.mapOffsetY + dy, -60, 60);
    renderCalibration();
    if (previewSync) previewSync();
    saveSettings(80);
}

function calibrateNav(action, shift) {
    const ARROW = { left: [-1, 0], right: [1, 0], up: [0, -1], down: [0, 1] }[action];
    if (action === 'back' || action === 'accept') return openMenu();
    if (!ARROW) return;
    const step = shift ? 5 : 1;
    nudgeMap(ARROW[0] * step, ARROW[1] * step);
}

$('#cal-reset').addEventListener('click', () => nudgeMap(-state.settings.mapOffsetX, -state.settings.mapOffsetY));
$('#cal-done').addEventListener('click', () => openMenu());

/* ---------- keyboard + gamepad ---------- */

// One action vocabulary for both: the keyboard maps here directly, the gamepad arrives from
// Lua as 'nav' messages (d-pad, shoulders, south / east buttons).
function dispatch(action, shift = false) {
    if (state.mode === 'menu') menuNav(action);
    else if (state.mode === 'editor') editorNav(action, shift);
    else if (state.mode === 'calibrate') calibrateNav(action, shift);
    else if (state.mode === 'devpanel') devPanelNav(action);
}

const KEYS = {
    ArrowUp: 'up', ArrowDown: 'down', ArrowLeft: 'left', ArrowRight: 'right',
    Tab: 'focus', ' ': 'accept', Enter: 'accept', Escape: 'back', q: 'prevTab', Q: 'prevTab', e: 'nextTab', E: 'nextTab',
};

window.addEventListener('keydown', (e) => {
    if (state.mode === 'hud') return;
    const action = KEYS[e.key];
    if (!action) return;
    // typing in the menu's search, hex and code boxes
    if (/^(INPUT|TEXTAREA)$/.test(e.target.tagName) && e.target.type !== 'range' && action !== 'back') return;
    e.preventDefault();
    dispatch(action, e.shiftKey);
});

/* ---------- dev menu overrides ---------- */

// Last values the game sent per group. What the HUD draws is these plus the dev overlay, so
// switching a dev option off falls straight back to the live values.
const real = {};
for (const g of ['status', 'vehicle', 'ammo', 'voice']) real[g] = { ...state[g] };

const DEV_DEFAULTS = {
    override: false, health: 100, armor: 100, hunger: 100, thirst: 100, stress: 0, oxygen: 100,
    vehicle: false, ammo: false, hints: false, radio: false, devmode: false,
};
state.dev = { ...DEV_DEFAULTS };

function devOverlay(group) {
    const d = state.dev;
    if (group === 'status') {
        const o = d.devmode ? { dev: true } : {};
        if (d.override) {
            Object.assign(o, {
                health: d.health, armor: d.armor, hunger: d.hunger, thirst: d.thirst,
                stress: d.stress, oxygen: d.oxygen, underwater: d.oxygen < 100,
            });
        }
        return o;
    }
    if (group === 'vehicle' && d.vehicle) {
        return { show: true, mode: 'car', speed: 39, unit: 'MPH', rpm: 62, gear: '2', fuel: 64, belt: false, beltable: true, moving: true, lights: true, locked: false };
    }
    if (group === 'ammo' && d.ammo) return { show: true, clip: 9, reserve: 54, name: 'Pistol' };
    if (group === 'voice' && d.radio) return { radio: true, channel: 1 };
    return {};
}

function applyGroup(group) {
    state[group] = Object.assign({}, real[group] || state[group], devOverlay(group));
    const render = renderers[group];
    if (render) render();
}

function changeDev(key, value) {
    state.dev[key] = value;
    ['status', 'vehicle', 'ammo', 'voice'].forEach(applyGroup);
    controls.dev = state.dev.hints ? SAMPLE_CONTROLS : null;
    renderControlBar();
    renderControls();
    dp.rows.forEach((r) => r.update());
}

/* ---------- compact dev panel ---------- */

// Same rows as the Dev tab, in a small panel docked left so the HUD stays visible.
const dp = { body: $('#dp-body'), rows: [], index: 0 };

function buildDevPanel() {
    const defs = DEV_ROWS.filter((d) => !d.menuOnly);
    const frag = document.createDocumentFragment();
    let sep = false;
    dp.rows = defs.map((def, i) => {
        const row = make('div', 'dp-row');
        let update = () => {};
        if (def.type === 'action') {
            if (!sep) {
                frag.appendChild(make('div', 'dp-sep'));
                sep = true;
            }
            row.classList.add('action');
            row.textContent = def.title;
        } else {
            row.appendChild(make('span', 'dp-label', def.title));
        }
        if (def.type === 'toggle') {
            const pill = make('span', 'dp-pill');
            row.appendChild(pill);
            update = () => {
                const on = Boolean(getValue(def));
                row.classList.toggle('on', on);
                setText(pill, on ? 'On' : 'Off');
            };
        } else if (def.type === 'range') {
            const [min, max, step] = def.range;
            const input = make('input');
            Object.assign(input, { type: 'range', min, max, step });
            const out = make('output');
            input.addEventListener('input', () => setValue(def, Number(input.value)));
            input.addEventListener('click', (e) => e.stopPropagation());
            row.append(input, out);
            update = () => {
                const v = getValue(def);
                input.value = v;
                input.style.setProperty('--p', `${((v - min) / (max - min)) * 100}%`);
                setText(out, def.fmt(v));
            };
        }
        row.addEventListener('click', () => {
            dp.index = i;
            activateDevRow();
        });
        frag.appendChild(row);
        const r = { def, el: row, update };
        update();
        return r;
    });
    dp.body.replaceChildren(frag);
}

function renderDevFocus() {
    dp.rows.forEach((r, i) => r.el.classList.toggle('focus', i === dp.index));
    const r = dp.rows[dp.index];
    if (r) r.el.scrollIntoView({ block: 'nearest' });
}

function activateDevRow(dir = 1) {
    const { def } = dp.rows[dp.index] || {};
    if (!def) return;
    if (def.type === 'toggle') setValue(def, !getValue(def));
    else if (def.type === 'action') def.action();
    else if (def.type === 'range') {
        const [min, max, step] = def.range;
        setValue(def, clamp(getValue(def) + dir * step, min, max));
    }
    renderDevFocus();
}

function devPanelNav(action) {
    const last = dp.rows.length - 1;
    if (action === 'up') dp.index = Math.max(0, dp.index - 1);
    else if (action === 'down') dp.index = Math.min(last, dp.index + 1);
    else if (action === 'left' || action === 'right') {
        const { def } = dp.rows[dp.index] || {};
        if (def && def.type !== 'action') activateDevRow(action === 'left' ? -1 : 1);
    } else if (action === 'accept') activateDevRow();
    else if (action === 'back') return closeDevPanel();
    renderDevFocus();
}

function openDevPanel() {
    if (!dp.rows.length) buildDevPanel();
    setMode('devpanel');
    renderDevFocus();
}

// In game this also releases NUI focus; in the browser preview it just hides the panel.
function closeDevPanel() {
    if (IS_FIVEM) requestClose();
    else setMode('hud');
}

$('#dp-close').addEventListener('click', closeDevPanel);
$('#dp-menu').addEventListener('click', () => {
    menu.page = 'dev';
    openMenu();
});

// Browser preview: a DEV button stands in for the /huddev command.
if (!IS_FIVEM) {
    state.devAccess = true;
    const fab = $('#dev-fab');
    fab.classList.remove('off');
    fab.addEventListener('click', () => (state.mode === 'devpanel' ? setMode('hud') : openDevPanel()));
}

function resetDev() {
    Object.assign(state.dev, DEV_DEFAULTS);
    changeDev('override', false);
}

// Writes the slider values to the character itself (server checks permission again).
function applyDevToCharacter() {
    const d = state.dev;
    post('devApply', { health: d.health, armor: d.armor, hunger: d.hunger, thirst: d.thirst, stress: d.stress });
}

/* ---------- messages ---------- */

const renderers = {
    status: renderStatus,
    vehicle: renderVehicle,
    voice: renderVoice,
    map: renderMap,
    compass: renderCompass,
    location: renderLocation,
    ammo: renderAmmo,
};

const handlers = {
    init(d) {
        Object.assign(state.config, d.config);
        applyServerSettings(d.settings);
    },
    update(d) {
        real[d.group] = Object.assign(real[d.group] || { ...state[d.group] }, d.data);
        applyGroup(d.group);
    },
    visible(d) {
        el.hud.classList.toggle('hidden', !d.value);
    },
    layout(d) {
        state.layout = d;
        applyLayout();
    },
    minimap(d) {
        state.minimap = d;
        applyMinimap();
    },
    settings(d) {
        if (state.mode === 'hud') applyServerSettings(d.settings);
    },
    toast(d) {
        showToast(d);
    },
    hints(d) {
        controls.hints = d.items && d.items.length ? d.items : null;
        renderControlBar();
    },
    hideHints() {
        controls.hints = null;
        renderControlBar();
    },
    prompts(d) {
        controls.prompts = d.items && d.items.length ? d.items : null;
        renderControlBar();
    },
    hidePrompts() {
        controls.prompts = null;
        renderControlBar();
    },
    // gamepad input forwarded by client/settings.lua
    nav(d) {
        dispatch(d.key, false);
    },
};

window.addEventListener('message', (e) => {
    const d = e.data;
    if (!d || typeof d.action !== 'string') return;
    const handler = handlers[d.action];
    if (handler) handler(d);
});

buildGauge();
buildClassicGauge();
buildStyleGauges();
buildCompass();
applySettings();
renderCompass();
renderVehicle();
post('ready');

