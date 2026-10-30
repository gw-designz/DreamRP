'use strict';
// Settings menu, edit mode, colours and the player info / speed limit / boat / air /
// vehicle control widgets. Loaded after script.js and uses its globals (state, el, $, make, ...).

const ico = (name, extra = '') => make('i', `ico i-${name}${extra ? ` ${extra}` : ''}`);

/* ---------- colours ---------- */

// Every colour the menu can change, keyed as stored in settings.colors. Each one becomes
// --col-<key> (and --col-<key>-rgb) on <html>; CSS reads those.
const COLOR_DEFAULTS = {
    'health.progress': '#f98476', 'health.icon': '#f98476', 'health.background': '#f98476',
    'armor.progress': '#a5cdfa', 'armor.icon': '#a5cdfa', 'armor.background': '#a5cdfa',
    'hunger.progress': '#f3c08d', 'hunger.icon': '#f3c08d', 'hunger.background': '#f3c08d',
    'thirst.progress': '#a7efbc', 'thirst.icon': '#a7efbc', 'thirst.background': '#a7efbc',
    'stamina.progress': '#f7fc9f', 'stamina.icon': '#f7fc9f', 'stamina.background': '#f7fc9f',
    'oxygen.progress': '#e484a4', 'oxygen.icon': '#e484a4', 'oxygen.background': '#e484a4',
    'stress.progress': '#d36ba6', 'stress.icon': '#d36ba6', 'stress.background': '#d36ba6',
    carRpm: '#ff2a3d', carText: '#ffffff', carEngine: '#ff2a3d', carFuel: '#ff2a3d',
    bikeText: '#dddddd', bikeHeart: '#de3134',
    boatNeedle: '#de3134', boatHub: '#dddddd', boatFuelNeedle: '#de3134',
    airAccent: '#ff2a3d',
    trainBars: '#d9d9d9', trainRed: '#ff0000', trainGear: '#d9d9d9',
    trainInd: '#ff2a3d', trainCruise: '#87ceeb', trainLights: '#4169e1', trainBelt: '#ff6b7a',
    voiceActive: '#ff2a3d', voiceIdle: '#4a4a4a', infoBg: '#161616', infoIcon: '#ff2a3d',
    weaponBg: '#161616', weaponIcon: '#ffffff', weaponText: '#c4c4c4',
    vcBg: '#161616', vcButton: '#262626', vcIcon: '#ffffff', vcInactive: '#333333',
    vcOff: '#4a4a4a', vcOn: '#ff2a3d', vcText: '#c4c4c4', vcBadge: '#ff2a3d',
};
const HEX = /^#[0-9a-f]{6}$/i;
const colorOf = (key) => {
    const v = state.settings.colors && state.settings.colors[key];
    return HEX.test(v || '') ? v.toLowerCase() : COLOR_DEFAULTS[key];
};
const rgbOf = (hex) => [1, 3, 5].map((i) => parseInt(hex.slice(i, i + 2), 16)).join(', ');

Object.assign(DEFAULT_SETTINGS, {
    performance: 'performance', distanceUnit: 'feet', ultrawide: false, statusStyle: 'bars', showStamina: true,
    limitStyle: 'us', flashLimit: true, indicatorSounds: true, beltSound: true, beltPlugSound: true,
    bikeUnit: 'mph', bikeSpeed: true, bellSounds: true, showCadence: true, showHeart: true,
    boatUnit: 'knots', showBoatHeading: true, showTrim: true,
    airUnit: 'knots', showAttitude: true, showAltitude: true, showAirHeading: true,
    trainUnit: 'kmh', showTrainSpeed: true, doorStatus: false, brakeIndicator: false,
    showAvatar: true, showRadioChannel: true, voiceAlign: 'right', voiceRadius: 'slight',
    infoRadius: 'slight', weaponRadius: 'slight', vcRadius: 'slight',
    colors: {}, hidden: {},
});
AUTO_STYLES.statusStyle = { circuit: 'bars', classic: 'circle' };
// script.js copied the defaults before the keys above existed
for (const [key, value] of Object.entries(DEFAULT_SETTINGS)) {
    if (!(key in state.settings)) state.settings[key] = JSON.parse(JSON.stringify(value));
}

state.info = { job: '', grade: '', cash: null, bank: null, id: 0, time: '', avatar: '' };
state.vc = { open: false };

// Called at the end of applySettings() in script.js.
function applyUiSettings() {
    const st = state.settings;
    for (const key of Object.keys(COLOR_DEFAULTS)) {
        const hex = colorOf(key);
        const name = `--col-${key.replace('.', '-')}`;
        root.style.setProperty(name, hex);
        root.style.setProperty(`${name}-rgb`, rgbOf(hex));
    }
    Object.assign(root.dataset, {
        limit: st.limitStyle, valign: st.voiceAlign, vradius: st.voiceRadius,
        iradius: st.infoRadius, wradius: st.weaponRadius, vcradius: st.vcRadius,
    });
    root.classList.toggle('no-avatar', !st.showAvatar);
    const hidden = st.hidden || {};
    for (const [name, w] of Object.entries(WIDGETS)) w.classList.toggle('hidden-w', hidden[name] === true);
    stats.stamina.el.classList.toggle('disabled', !st.showStamina);
    renderInfo();
    renderVoiceBox();
}

/* ---------- player info ---------- */

const money = (v) => `$${Math.round(Number(v) || 0).toLocaleString('en-US')}`;

function renderInfo() {
    const i = state.info;
    setText($('#job-label'), i.grade ? `${i.job} (${i.grade})` : i.job || 'Unemployed');
    setText($('#clock'), i.time || '00:00');
    setText($('#bank'), money(i.bank));
    setText($('#cash'), money(i.cash));
    WIDGETS.money.classList.toggle('off', i.cash === null && i.bank === null && state.mode !== 'editor');
    setText($('#pid'), `#${i.id || 0}`);
    const img = $('#vb-avatar');
    if (i.avatar && img.getAttribute('src') !== i.avatar) img.src = i.avatar;
    $('.vbox').classList.toggle('has-avatar', Boolean(i.avatar));
}

function renderVoiceBox() {
    const v = state.voice;
    const box = $('.vbox');
    box.dataset.range = clamp(v.range, 1, 3);
    box.classList.toggle('talking', Boolean(v.talking));
    const ch = v.channel > 0 && state.settings.showRadioChannel;
    WIDGETS.radio.classList.toggle('off', !ch && state.mode !== 'editor');
    setText($('#radio-ch'), `CH ${v.channel || 1}`);
}

/* ---------- speed limit, boat / air panels, train flags, sounds ---------- */

const DIRS = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
const dirOf = (deg) => DIRS[Math.round((((deg % 360) + 360) % 360) / 45) % 8];

// Called at the end of renderVehicle() in script.js.
function renderVehicleExtras() {
    const v = state.vehicle;
    const st = state.settings;
    const show = Boolean(v.show && st.showVehicle);
    const editing = state.mode === 'editor';
    const road = show && (v.mode === 'car' || v.mode === 'electric');
    const limit = Number(v.limit) || 0;
    WIDGETS.limit.classList.toggle('off', !(road && limit > 0) && !editing);
    setText($('#limit-us'), limit || 35);
    setText($('#limit-min'), limit || 35);
    setText($('#limit-unit'), String(v.unit || 'MPH').toLowerCase());
    WIDGETS.limit.classList.toggle('speeding', road && limit > 0 && st.flashLimit && v.speed > limit);

    const heading = Math.round(Number(v.heading) || 0);
    const pitch = Math.round(Number(v.pitch) || 0);
    WIDGETS.boat.classList.toggle('off', !(show && v.mode === 'boat') && !editing);
    $('#boat-heading-box').classList.toggle('disabled', !st.showBoatHeading);
    $('#boat-trim-box').classList.toggle('disabled', !st.showTrim);
    setText($('#boat-deg'), `${heading}°`);
    setText($('#boat-dir'), dirOf(heading));
    setText($('#trim-label'), pitch > 3 ? 'BOW UP' : pitch < -3 ? 'BOW DOWN' : 'LEVEL');
    setText($('#trim-deg'), `${Math.abs(pitch)}°`);
    $('#trim-bar').style.transform = `rotate(${clamp(-pitch, -45, 45)}deg)`;

    WIDGETS.air.classList.toggle('off', !(show && v.mode === 'air') && !editing);
    $('#air-att').classList.toggle('disabled', !st.showAttitude);
    $('#air-alt').classList.toggle('disabled', !st.showAltitude);
    $('#air-hdg').classList.toggle('disabled', !st.showAirHeading);
    const roll = Math.round(Number(v.roll) || 0);
    $('#att-horizon').style.transform = `rotate(${-roll}deg) translateY(${clamp(pitch, -40, 40) * 1.2}px)`;
    setText($('#att-p'), `P: ${pitch}°`);
    setText($('#att-r'), `R: ${roll}°`);
    const climb = Math.round(Number(v.climb) || 0);
    setText($('#alt-val'), `${Math.round(Number(v.alt) || 0)} ${v.altUnit || 'ft'}`);
    setText($('#alt-rate'), `${climb} ${v.altUnit || 'ft'}/m`);
    $('#air-alt').classList.toggle('down', climb < -50);
    setText($('#air-deg'), `${heading}°`);

    const train = show && v.mode === 'train';
    el.speedo.classList.toggle('disabled', !st.showVehicle || (train && !st.showTrainSpeed) || (v.mode === 'bicycle' && !st.bikeSpeed));
    $('#tf-brake').classList.toggle('on', train && st.brakeIndicator && Boolean(v.braking));
    $('#tf-doors').classList.toggle('on', train && st.doorStatus && Boolean(v.doorsOpen));
    el.gauge.classList.toggle('cruise', Boolean(v.cruise));
    el.gauge.classList.toggle('no-cadence', !st.showCadence);
    el.gauge.classList.toggle('no-heart', !st.showHeart);

    sounds.indicators = show && st.indicatorSounds && Boolean(v.indLeft || v.indRight);
    sounds.belt = show && st.beltSound && v.beltable && !v.belt && Boolean(v.moving);
    runSounds();
}

// Indicator ticks and the seatbelt chime, made with WebAudio so no sound files are needed.
const sounds = { ctx: null, indicators: false, belt: false, timer: 0, phase: 0 };
function beep(freq, ms, gain = 0.06, type = 'square') {
    try {
        sounds.ctx = sounds.ctx || new AudioContext();
        const o = sounds.ctx.createOscillator();
        const g = sounds.ctx.createGain();
        o.type = type;
        o.frequency.value = freq;
        g.gain.value = gain;
        o.connect(g).connect(sounds.ctx.destination);
        o.start();
        o.stop(sounds.ctx.currentTime + ms / 1000);
    } catch (e) { /* no audio device */ }
}
function runSounds() {
    const want = sounds.indicators || sounds.belt;
    if (want && !sounds.timer) {
        sounds.timer = setInterval(() => {
            sounds.phase += 1;
            if (sounds.indicators) beep(sounds.phase % 2 ? 1800 : 1500, 12, 0.05);
            if (sounds.belt && sounds.phase % 3 === 0) beep(880, 160, 0.04, 'sine');
        }, 400);
    } else if (!want && sounds.timer) {
        clearInterval(sounds.timer);
        sounds.timer = 0;
    }
}

/* ---------- vehicle control panel ---------- */

// [action, label, icon, badge, index]; rows of groups like the reference panel.
const VC_LAYOUT = [
    [[['engine', 'Engine', 'engine'], ['lock', 'Lock', 'lock']], [['left', 'Left', 'turn'], ['hazard', 'Hazard', 'hazard'], ['right', 'Right', 'turn']],
        [['door', 'Door', 'door', 'FL', 0], ['door', 'Door', 'door', 'FR', 1]], [['window', 'Window', 'window', 'FL', 0], ['window', 'Window', 'window', 'FR', 1]],
        [['seat', 'Seat', 'seat', 'Driver', -1], ['seat', 'Seat', 'seat', 'Pass', 0]]],
    [[['door', 'Hood', 'hood', '', 4], ['door', 'Trunk', 'trunk', '', 5]], [['lights', 'Lights', 'headlight'], ['cruise', 'Cruise', 'cruise'], ['neon', 'Neon', 'star']],
        [['door', 'Door', 'door', 'RL', 2], ['door', 'Door', 'door', 'RR', 3]], [['window', 'Window', 'window', 'RL', 2], ['window', 'Window', 'window', 'RR', 3]],
        [['seat', 'Seat', 'seat', 'RL', 1], ['seat', 'Seat', 'seat', 'RR', 2]]],
];
const vcButtons = [];

function buildVehicleControls() {
    const panel = $('#vc-panel');
    for (const row of VC_LAYOUT) {
        const r = make('div', 'vc-row');
        for (const group of row) {
            const g = make('div', 'vc-group');
            for (const [action, label, icon, badge, index] of group) {
                const b = make('button', 'vc-btn');
                b.type = 'button';
                b.append(make('span', 'vc-dot'), ico(icon, action === 'right' ? 'flip' : ''), make('span', 'vc-label', label));
                if (badge) b.appendChild(make('span', 'vc-badge', badge));
                b.addEventListener('click', () => post('vcAction', { action, index }));
                g.appendChild(b);
                vcButtons.push({ b, action, index });
            }
            r.appendChild(g);
        }
        panel.appendChild(r);
    }
}

function renderVc() {
    const s = state.vc;
    const editing = state.mode === 'editor';
    WIDGETS.vcontrols.classList.toggle('off', !s.open && !editing);
    WIDGETS.vcontrols.classList.toggle('interactive', Boolean(s.open));
    const has = (list, i) => !list || list[String(i)] !== false;
    for (const { b, action, index } of vcButtons) {
        let on = false;
        let usable = true;
        if (action === 'engine') on = s.engine;
        else if (action === 'lock') on = s.locked;
        else if (action === 'left') on = s.indLeft && !s.indRight;
        else if (action === 'right') on = s.indRight && !s.indLeft;
        else if (action === 'hazard') on = s.indLeft && s.indRight;
        else if (action === 'lights') on = s.lights;
        else if (action === 'cruise') on = s.cruise;
        else if (action === 'neon') { on = s.neon; usable = s.hasNeon !== false; }
        else if (action === 'door') { on = Boolean(s.doors && s.doors[String(index)]); usable = has(s.hasDoor, index); }
        else if (action === 'window') { on = Boolean(s.windows && s.windows[String(index)]); usable = has(s.hasDoor, index); }
        else if (action === 'seat') { on = Boolean(s.seats && s.seats[String(index + 1)]); usable = index + 2 <= (s.seatCount || 4); }
        b.classList.toggle('on', Boolean(on));
        b.classList.toggle('na', !usable);
    }
}

$('#vc-close').addEventListener('click', () => post('vcClose'));

/* ---------- settings menu ---------- */

const SPEEDO_OPTIONS = [
    ['modern', 'Modern Pro'], ['analog', 'Classic Analog'], ['linear', 'Digital Linear'],
    ['ev', 'Tesla Style'], ['dual', 'Classic Dual'], ['watch', 'Fitness Watch'],
];
const RADIUS = [['slight', 'Slightly Rounded'], ['rounded', 'Rounded'], ['full', 'Full Rounded']];
const SPEED_UNITS = [['mph', 'MPH'], ['kmh', 'KM/H']];
const WATER_UNITS = [['knots', 'Knots'], ['mph', 'MPH'], ['kmh', 'KM/H']];

const sel = (key, label, options, icon = 'layers') => ({ type: 'select', key, label, options, icon });
const tog = (key, label) => ({ type: 'toggle', key, label });
const col = (key, label) => ({ type: 'color', key, label });
const rng = (key, label, range, fmt) => ({ type: 'range', key, label, range, fmt });
const act = (label, button, run) => ({ type: 'action', label, button, run });
const statColors = (stat, label, icon) => ({
    title: label, icon, fields: [col(`${stat}.progress`, 'Progress Color'), col(`${stat}.icon`, 'Icon Color'), col(`${stat}.background`, 'Background Color')],
});

const PAGES = [
    {
        id: 'home', icon: 'home', title: 'Home', home: true,
        cards: [
            { title: 'Performance Mode', fields: [sel('performance', 'Mode', [['performance', 'Performance Mode'], ['balanced', 'Balanced Mode'], ['quality', 'Quality Mode']])] },
            { title: 'Measurement', cols: 2, fields: [sel('speedUnit', 'Speed', SPEED_UNITS, 'gauge-o'), sel('distanceUnit', 'Distance', [['feet', 'Feet'], ['meters', 'Meters']])] },
            { bare: true, fields: [tog('ultrawide', 'Use full screen width on ultrawide displays')] },
            { title: 'General', cols: 2, fields: [
                rng('scale', 'HUD Scale', [0.75, 1.25, 0.05], (v) => `${Math.round(v * 100)}%`),
                sel('hudStyle', 'HUD Style', [['circuit', 'Circuit'], ['classic', 'Classic']]),
                tog('showToasts', 'Show item toasts'), tog('stressShake', 'Stress screen shake'),
            ] },
        ],
    },
    {
        id: 'map', icon: 'map-o', title: 'Minimap & Compass',
        cards: [
            { title: 'Style', cols: 2, fields: [
                sel('mapStyle', 'Minimap Style', [['auto', 'Auto'], ['brackets', 'Brackets'], ['clean', 'Clean'], ['minimal', 'Minimal'], ['circle', 'Round']]),
                sel('locationStyle', 'Location Style', [['auto', 'Auto'], ['bar', 'Bar'], ['pills', 'Pills'], ['compass', 'Compass'], ['minimal', 'Minimal']]),
                tog('minimapOnFoot', 'Show minimap on foot'), tog('map3d', '3D minimap'),
                tog('showCompass', 'Show compass direction'), tog('showHeading', 'Show heading degrees'),
                tog('showLocation', 'Show street and zone'), tog('showWaypoint', 'Show waypoint distance'),
            ] },
            { title: 'Minimap', cols: 2, fields: [
                rng('mapZoom', 'Zoom', [0, 1400, 50], (v) => (v === 0 ? 'Auto' : String(v))),
                act('Calibrate', 'Start', () => startCalibration()),
            ] },
        ],
    },
    {
        id: 'stats', icon: 'heart-o', title: 'Player Stats',
        cards: [
            { title: 'Style', cols: 2, fields: [
                sel('statusStyle', 'Stats Style', [['bars', 'Style 1 - Bars'], ['hex', 'Style 2 - Hexagon'], ['square', 'Style 3 - Square'], ['circle', 'Style 4 - Circle']]),
                { type: 'spacer' },
                tog('showNeeds', 'Show hunger & thirst'), tog('showStamina', 'Show stamina'),
                tog('showVoice', 'Show voice indicator'), tog('showCircles', 'Show stress, oxygen & radio'),
                tog('lowWarnings', 'Low status warnings'), tog('hideArmorAtZero', 'Hide armour at zero'),
                tog('hideFullNeeds', 'Hide full hunger & thirst'),
            ] },
            { grid: [statColors('health', 'Health', 'heart-solid'), statColors('armor', 'Armour', 'shield'),
                statColors('hunger', 'Hunger', 'utensils'), statColors('thirst', 'Thirst', 'glass'),
                statColors('stamina', 'Stamina', 'runner'), statColors('oxygen', 'Oxygen', 'lungs'),
                statColors('stress', 'Stress', 'brain')] },
        ],
    },
    {
        id: 'car', icon: 'car-o', title: 'Cars & Bikes',
        cards: [
            { title: 'Style', cols: 2, fields: [
                sel('speedoStyle', 'Speedometer Style', SPEEDO_OPTIONS),
                { ...sel('limitStyle', 'Speed Limit Sign Style', [['us', 'US Style Sign'], ['minimal', 'Minimal']], 'gauge-o'), preview: 'limit' },
                tog('flashLimit', 'Flash speed limit sign speeding'), tog('beltSound', 'Enable seatbelt warning sound'),
                tog('indicatorSounds', 'Enable indicator sounds'), tog('beltPlugSound', 'Enable seatbelt plug & unplug'),
            ] },
            { grid: [
                { title: 'Colours', fields: [col('carRpm', 'RPM Arc'), col('carText', 'Text Colour')] },
                { title: 'Status Colours', fields: [col('carEngine', 'Engine Bar'), col('carFuel', 'Fuel Bar')] },
            ] },
            { title: 'Display', cols: 2, fields: [tog('showVehicle', 'Show speedometer'), tog('beltWarning', 'Blink seatbelt icon'), tog('showControls', 'Show key hints')] },
        ],
    },
    {
        id: 'bike', icon: 'bike-o', title: 'Bicycles',
        cards: [
            { title: 'Style', cols: 2, fields: [
                sel('speedoBicycle', 'Speedometer Style', SPEEDO_OPTIONS), sel('bikeUnit', 'Speed Unit', SPEED_UNITS, 'gauge-o'),
                tog('bikeSpeed', 'Show speed display'), tog('showCadence', 'Show cadence meter'),
                tog('bellSounds', 'Enable bell sounds'), tog('showHeart', 'Show heart rate monitor'),
            ] },
            { grid: [
                { title: 'Colours', fields: [col('bikeText', 'Text Colour')] },
                { title: 'Status Colours', fields: [col('bikeHeart', 'Heart Icon')] },
            ] },
        ],
    },
    {
        id: 'boat', icon: 'boat-o', title: 'Boats',
        cards: [
            { title: 'Style', cols: 2, fields: [
                sel('speedoBoat', 'Speedometer Style', SPEEDO_OPTIONS), sel('boatUnit', 'Speed Unit', WATER_UNITS, 'gauge-o'),
                tog('showBoatHeading', 'Show compass heading'), tog('showTrim', 'Show trim indicator'),
            ] },
            { grid: [
                { title: 'Colours', fields: [col('boatNeedle', 'Needle Colour'), col('boatHub', 'Center Circle')] },
                { title: 'Status Colours', fields: [col('boatFuelNeedle', 'Fuel Needle')] },
            ] },
        ],
    },
    {
        id: 'air', icon: 'plane-o', title: 'Air',
        cards: [
            { title: 'Style', cols: 2, fields: [
                sel('speedoAir', 'Speedometer Style', SPEEDO_OPTIONS), sel('airUnit', 'Speed Unit', WATER_UNITS, 'gauge-o'),
                tog('showAttitude', 'Show attitude indicator'), tog('showAltitude', 'Show altitude & climb rate'),
                tog('showAirHeading', 'Show compass heading'),
            ] },
            { grid: [{ title: 'Colours', fields: [col('airAccent', 'Accent Colour')] }] },
        ],
    },
    {
        id: 'train', icon: 'train-o', title: 'Trains',
        cards: [
            { title: 'Style', cols: 2, fields: [
                sel('speedoTrain', 'Speedometer Style', SPEEDO_OPTIONS), sel('trainUnit', 'Speed Unit', SPEED_UNITS, 'gauge-o'),
                tog('showTrainSpeed', 'Show speed display'), tog('doorStatus', 'Show door status'),
                tog('brakeIndicator', 'Brake indicator'),
            ] },
            { grid: [
                { title: 'Colours', fields: [col('trainBars', 'RPM Bars'), col('trainRed', 'RPM Red Zone'), col('trainGear', 'Gear Box')] },
                { title: 'Status Colours', fields: [col('trainInd', 'Indicators'), col('trainCruise', 'Cruise Control'), col('trainLights', 'Headlights'), col('trainBelt', 'Seatbelt')] },
            ] },
        ],
    },
    {
        id: 'info', icon: 'user-o', title: 'Player Info',
        cards: [
            { title: 'Player Voice & Radio', fields: [
                { type: 'toggles', label: 'Toggle Visibility', items: [tog('showAvatar', 'Avatar'), tog('showRadioChannel', 'Radio Channel')] },
                sel('voiceAlign', 'Player Voice Alignment Within Container', [['left', 'Left'], ['right', 'Right']]),
                sel('voiceRadius', 'Border Radius', RADIUS),
                col('voiceActive', 'Voice Chat Active Colour'), col('voiceIdle', 'Voice Chat Idle Colour'),
            ] },
            { title: 'Player Info', fields: [sel('infoRadius', 'Border Radius', RADIUS), col('infoBg', 'Background Colour'), col('infoIcon', 'Icon Colour')] },
        ],
    },
    {
        id: 'weapons', icon: 'crosshair', title: 'Weapons',
        cards: [
            { title: 'Style', cols: 2, fields: [
                { ...sel('weaponRadius', 'Border Radius', RADIUS), wide: true },
                col('weaponBg', 'Background Colour'), col('weaponIcon', 'Icon Colour'), col('weaponText', 'Text Color'),
                tog('showAmmo', 'Show weapon & ammo'),
            ] },
        ],
    },
    {
        id: 'vcontrols', icon: 'sliders', title: 'Vehicle Controls',
        cards: [
            { title: 'Style', fields: [sel('vcRadius', 'Border Radius', RADIUS)] },
            { title: 'Colours', cols: 2, fields: [
                col('vcBg', 'Background Colour'), col('vcButton', 'Button Background Colour'),
                col('vcIcon', 'Icon Colour'), col('vcInactive', 'Status Inactive Colour'),
                col('vcOff', 'Status Off Colour'), col('vcOn', 'Status On Colour'),
                col('vcText', 'Text Colour'), col('vcBadge', 'Badge Colour'),
            ] },
        ],
    },
    { id: 'transfer', icon: 'transfer', title: 'Import & Export', transfer: true },
    { id: 'dev', icon: 'code-o', title: 'Dev Tools', dev: true },
];

// Dev rows read and write state.dev (never saved); the compact dev panel uses them too.
const toggle = (key, title, desc, widget) => ({ key, title, desc, widget, type: 'toggle' });
const devToggle = (key, title, desc, widget) => ({ ...toggle(key, title, desc, widget), store: 'dev' });
const devRange = (key, title, widget, desc = 'Value drawn while overriding, and what Apply sets.') => ({
    key, title, desc, widget, store: 'dev', type: 'range', range: [0, 100, 5], fmt: (v) => `${v}%`,
});
const getValue = (def) => (def.store === 'dev' ? state.dev : state.settings)[def.key];
function setValue(def, value) {
    if (def.store === 'dev') changeDev(def.key, value);
    else changeSetting(def.key, value);
}
const DEV_ROWS = [
    { title: 'Open dev panel', desc: 'Switch to a small panel docked at the side so the whole HUD stays in view.', type: 'action', label: 'Open', action: () => openDevPanel(), menuOnly: true },
    devToggle('override', 'Override status values', 'Draw the values below instead of your real ones (only on your HUD).', 'status'),
    devRange('health', 'Health', 'status'),
    devRange('armor', 'Armor', 'status'),
    devRange('hunger', 'Hunger', 'status'),
    devRange('thirst', 'Thirst', 'status'),
    devRange('stress', 'Stress', 'status'),
    devRange('oxygen', 'Oxygen', 'status', 'Below 100 also shows the underwater oxygen icon.'),
    { title: 'Apply to character', desc: 'Set your real health, armor, hunger, thirst and stress to the values above.', type: 'action', label: 'Apply', action: applyDevToCharacter },
    devToggle('vehicle', 'Show speedometer', 'Show the speedometer with sample values while on foot.', 'speedo'),
    devToggle('ammo', 'Show weapon & ammo', 'Show the ammo counter with a sample weapon.', 'ammo'),
    devToggle('hints', 'Show key hints', 'Show the key hints bar with the vehicle hints.', 'controls'),
    devToggle('radio', 'Show radio', 'Show the mic in radio color and the radio icon.', 'status'),
    devToggle('devmode', 'Show dev mode icon', 'Show the green dev mode icon in the status row.', 'status'),
    { title: 'Test item toast', desc: 'Show a sample item card.', type: 'action', label: 'Show', action: () => SAMPLE_TOASTS.forEach((t) => showToast(t)) },
    { title: 'Reset dev tools', desc: 'Turn every option here off and go back to your live values.', type: 'action', label: 'Reset', action: resetDev },
];

const menu = { page: 'home', search: '', items: [], index: -1, saved: null, dom: {} };
const visiblePages = () => PAGES.filter((p) => !p.dev || state.devAccess);
const snapshot = () => JSON.stringify(state.settings);

function buildMenuShell() {
    const m = make('div', 'pm');
    m.innerHTML = `
        <nav class="pm-side"></nav>
        <div class="pm-main">
            <header class="pm-head">
                <span class="pm-logo cut"><i class="ico i-gear"></i></span>
                <div class="pm-title"><h1>HUD Settings</h1><p>Customize your HUD in here. Press save.</p></div>
                <button type="button" class="pm-x"><i class="ico i-x"></i></button>
            </header>
            <div class="pm-content"></div>
            <footer class="pm-foot">
                <button type="button" class="pm-btn pm-edit cut"><i class="ico i-move"></i>Edit Sizes, Positions &amp; Visibility</button>
                <span class="pm-gap"></span>
                <button type="button" class="pm-btn pm-reset cut"><i class="ico i-reset-o"></i>Reset All</button>
                <button type="button" class="pm-btn pm-save cut"><i class="ico i-save-o"></i>Save Changes</button>
            </footer>
        </div>`;
    el.settings.replaceChildren(m);
    menu.dom = { side: $('.pm-side', m), content: $('.pm-content', m), save: $('.pm-save', m) };
    $('.pm-x', m).addEventListener('click', requestClose);
    $('.pm-edit', m).addEventListener('click', () => openEditor());
    $('.pm-save', m).addEventListener('click', () => saveSettings());
    $('.pm-reset', m).addEventListener('click', resetAll);
    m.addEventListener('pointerdown', (e) => {
        if (!e.target.closest('.dd, .cp, .cf')) closePopups();
    });
}

function buildSide() {
    const frag = document.createDocumentFragment();
    for (const page of visiblePages()) {
        const b = make('button', 'pm-tab cut');
        b.type = 'button';
        b.dataset.page = page.id;
        b.title = page.title;
        b.appendChild(ico(page.icon));
        b.addEventListener('click', () => {
            menu.search = '';
            showPage(page.id);
        });
        frag.appendChild(b);
    }
    menu.dom.side.replaceChildren(frag);
}

function markDirty() {
    menu.dom.save.classList.toggle('dirty', snapshot() !== menu.saved);
}

function changeSetting(key, value) {
    state.settings[key] = value;
    applySettings();
    renderControls();
    markDirty();
}

function setColor(key, hex) {
    state.settings.colors = Object.assign({}, state.settings.colors, { [key]: hex });
    if (hex === COLOR_DEFAULTS[key]) delete state.settings.colors[key];
    applySettings();
    renderControls();
    markDirty();
}

function saveSettings() {
    menu.saved = snapshot();
    markDirty();
    post('saveSettings', state.settings);
}

function resetAll() {
    if (!IS_FIVEM) {
        applyServerSettings(DEFAULT_SETTINGS);
        return;
    }
    post('resetSettings').then((res) => applyServerSettings(res && res.settings));
}

/* fields */

function fieldLabel(text, icon) {
    const l = make('div', 'pf-label');
    if (icon) l.appendChild(ico(icon));
    l.appendChild(make('span', '', text));
    return l;
}

function buildToggle(def) {
    const t = make('button', 'pt');
    t.type = 'button';
    t.append(make('span', 'pt-track'), make('span', 'pt-text', def.label));
    t.addEventListener('click', () => setValue(def, !getValue(def)));
    return { node: t, def, update: () => t.classList.toggle('on', Boolean(getValue(def))), step: () => setValue(def, !getValue(def)) };
}

function closePopups() {
    $$('.dd.open', el.settings).forEach((d) => d.classList.remove('open'));
    const cp = $('.cp', el.settings);
    if (cp) cp.remove();
}

function buildSelect(def) {
    const wrap = make('div', 'pf');
    wrap.appendChild(fieldLabel(def.label, def.icon));
    const row = make('div', 'pf-row');
    const dd = make('div', 'dd');
    const btn = make('button', 'dd-btn');
    btn.type = 'button';
    const val = make('span', 'dd-val');
    btn.append(val, ico('chevron'));
    const list = make('div', 'dd-list');
    const opts = def.options.map(([value, label]) => {
        const o = make('button', 'dd-opt');
        o.type = 'button';
        o.append(make('span', '', label), ico('check'));
        o.addEventListener('click', () => {
            dd.classList.remove('open');
            setValue(def, value);
        });
        list.appendChild(o);
        return [value, o, label];
    });
    btn.addEventListener('click', () => {
        const open = !dd.classList.contains('open');
        closePopups();
        dd.classList.toggle('open', open);
    });
    dd.append(btn, list);
    row.appendChild(dd);
    let preview = null;
    if (def.preview === 'limit') {
        preview = make('div', 'pf-preview');
        row.appendChild(preview);
    }
    wrap.appendChild(row);
    const update = () => {
        const v = getValue(def);
        const cur = opts.find(([value]) => value === v) || opts[0];
        setText(val, cur[2]);
        opts.forEach(([value, o]) => o.classList.toggle('sel', value === v));
        if (preview) {
            preview.innerHTML = v === 'us'
                ? '<div class="sign-us"><small>SPEED<br>LIMIT</small><b>35</b></div>'
                : '<div class="sign-min"><b>35</b><small>mph</small></div>';
        }
    };
    const step = (dir) => {
        const i = def.options.findIndex(([value]) => value === getValue(def));
        setValue(def, def.options[(i + dir + def.options.length) % def.options.length][0]);
    };
    return { node: wrap, def, update, step };
}

function buildRange(def) {
    const wrap = make('div', 'pf');
    wrap.appendChild(fieldLabel(def.label, 'layers'));
    const box = make('div', 'pr');
    const [min, max, stepSize] = def.range;
    const input = make('input');
    Object.assign(input, { type: 'range', min, max, step: stepSize });
    const out = make('output');
    input.addEventListener('input', () => setValue(def, Number(input.value)));
    box.append(input, out);
    wrap.appendChild(box);
    const update = () => {
        const v = getValue(def);
        if (Number(input.value) !== v) input.value = v;
        input.style.setProperty('--p', `${((v - min) / (max - min)) * 100}%`);
        setText(out, def.fmt(v));
    };
    const step = (dir) => setValue(def, Math.round(clamp(getValue(def) + dir * stepSize, min, max) * 100) / 100);
    return { node: wrap, def, update, step };
}

function buildAction(def) {
    const wrap = make('div', 'pf');
    wrap.appendChild(fieldLabel(def.label, 'layers'));
    const b = make('button', 'pm-btn pa cut', def.button);
    b.type = 'button';
    b.addEventListener('click', def.run);
    wrap.appendChild(b);
    return { node: wrap, def, update: () => {}, step: () => def.run() };
}

function buildColor(def) {
    const wrap = make('div', 'pf');
    wrap.appendChild(fieldLabel(def.label, 'bucket'));
    const f = make('button', 'cf');
    f.type = 'button';
    const sw = make('span', 'cf-sw');
    const hex = make('span', 'cf-hex');
    f.append(sw, hex);
    f.addEventListener('click', () => openPicker(f, def.key));
    wrap.appendChild(f);
    const update = () => {
        const c = colorOf(def.key);
        sw.style.background = c;
        setText(hex, c.toUpperCase());
    };
    return { node: wrap, def, update, step: () => openPicker(f, def.key) };
}

function buildToggles(def) {
    const wrap = make('div', 'pf');
    wrap.appendChild(fieldLabel(def.label, 'layers'));
    const row = make('div', 'pf-toggles');
    const items = def.items.map((d) => buildToggle(d));
    items.forEach((i) => row.appendChild(i.node));
    wrap.appendChild(row);
    return { node: wrap, def, update: () => items.forEach((i) => i.update()), step: () => items[0].step(), children: items };
}

function buildField(def) {
    if (def.type === 'select') return buildSelect(def);
    if (def.type === 'toggle') return buildToggle(def);
    if (def.type === 'color') return buildColor(def);
    if (def.type === 'range') return buildRange(def);
    if (def.type === 'action') return buildAction(def);
    if (def.type === 'toggles') return buildToggles(def);
    return { node: make('div', 'pf-spacer'), def, update: () => {} };
}

function buildCard(card, items) {
    const c = make('section', card.bare ? 'pc bare' : 'pc');
    if (card.title) {
        const h = make('h3', 'pc-title');
        if (card.icon) h.appendChild(ico(card.icon));
        h.appendChild(make('span', '', card.title));
        if (!card.icon) h.appendChild(make('b', 'pc-dot', '•'));
        c.appendChild(h);
    }
    const body = make('div', card.cols === 2 ? 'pc-body cols' : 'pc-body');
    for (const def of card.fields) {
        const item = buildField(def);
        if (def.wide) item.node.classList.add('wide');
        if (def.type === 'toggle') item.node.classList.add('pt-field');
        body.appendChild(item.node);
        if (item.children) items.push(...item.children);
        else if (def.type !== 'spacer') items.push(item);
    }
    c.appendChild(body);
    return c;
}

function buildCards(cards, frag, items) {
    for (const card of cards) {
        if (card.grid) {
            const g = make('div', 'pc-grid');
            card.grid.forEach((sub) => g.appendChild(buildCard(sub, items)));
            frag.appendChild(g);
        } else frag.appendChild(buildCard(card, items));
    }
}

function buildHome(frag, items) {
    const search = make('label', 'ps');
    const input = make('input');
    input.placeholder = 'Search HUD Settings...';
    input.value = menu.search;
    input.addEventListener('input', () => {
        menu.search = input.value;
        showPage('home', true);
    });
    search.append(ico('search'), input);
    frag.appendChild(search);
    if (menu.search.trim()) return buildSearch(frag, items);
    const welcome = make('section', 'pc');
    welcome.innerHTML = `<h3 class="pc-title"><span>Welcome to your HUD</span></h3>
        <p class="pc-text">Explore your HUD settings using the menus on the left. In addition to changing colors and
        preferences, you can choose from unique vehicle styles like classic, modern, or minimalist.</p>
        <p class="pc-text">You can also freely adjust the size and position of any element, including the minimap. Just
        click "Edit Sizes, Positions &amp; Visibility" at the bottom left.</p>`;
    frag.appendChild(welcome);
    buildCards(PAGES[0].cards, frag, items);
}

// Every field whose label matches, grouped under its page.
function buildSearch(frag, items) {
    const q = menu.search.trim().toLowerCase();
    let found = 0;
    for (const page of visiblePages()) {
        if (!page.cards) continue;
        const fields = [];
        const walk = (cards) => cards.forEach((c) => {
            if (c.grid) return walk(c.grid);
            c.fields.forEach((f) => {
                const text = `${c.title || ''} ${f.label || ''} ${(f.items || []).map((i) => i.label).join(' ')}`.toLowerCase();
                if (f.type !== 'spacer' && text.includes(q)) fields.push(f.type === 'color' ? { ...f, label: `${c.title} - ${f.label}` } : f);
            });
        });
        walk(page.cards);
        if (!fields.length) continue;
        found += fields.length;
        frag.appendChild(buildCard({ title: page.title, icon: page.icon, cols: 2, fields }, items));
    }
    if (!found) frag.appendChild(make('p', 'pc-empty', 'No settings match your search.'));
}

function buildTransfer(frag) {
    const c = make('section', 'pc px');
    c.innerHTML = `
        <div class="px-head">
            <div><h3 class="pc-title"><span>Your HUD Settings</span></h3><p class="pc-sub">Share this code with others or import someone else's settings</p></div>
            <button type="button" class="pm-btn px-copy cut"><i class="ico i-copy"></i>Copy Code</button>
            <button type="button" class="pm-btn px-import cut"><i class="ico i-import"></i>Import Code</button>
        </div>
        <div class="px-code"><div class="px-gutter"></div><div class="px-edit"><pre class="px-hl" aria-hidden="true"></pre><textarea spellcheck="false"></textarea></div></div>
        <p class="px-msg"></p>`;
    const ta = $('textarea', c);
    const hl = $('.px-hl', c);
    const gutter = $('.px-gutter', c);
    const msg = $('.px-msg', c);
    const exportable = () => {
        const out = { ...state.settings };
        delete out.layoutVersion;
        return JSON.stringify(out, null, 4);
    };
    const esc = (s) => s.replace(/&/g, '&amp;').replace(/</g, '&lt;');
    const paint = () => {
        hl.innerHTML = `${esc(ta.value)
            .replace(/("(?:[^"\\]|\\.)*")(\s*:)/g, '<span class="k">$1</span>$2')
            .replace(/:\s*("(?:[^"\\]|\\.)*")/g, ': <span class="s">$1</span>')
            .replace(/\b(true|false|null)\b/g, '<span class="b">$1</span>')
            .replace(/(:\s*)(-?\d+(?:\.\d+)?)/g, '$1<span class="n">$2</span>')}\n`;
        const lines = ta.value.split('\n').length;
        gutter.textContent = Array.from({ length: lines }, (_, i) => i + 1).join('\n');
    };
    ta.value = exportable();
    paint();
    ta.addEventListener('input', paint);
    ta.addEventListener('scroll', () => {
        hl.scrollTop = ta.scrollTop;
        hl.scrollLeft = ta.scrollLeft;
        gutter.scrollTop = ta.scrollTop;
    });
    $('.px-copy', c).addEventListener('click', () => {
        ta.select();
        document.execCommand('copy');
        ta.setSelectionRange(0, 0);
        setText(msg, 'Copied to your clipboard.');
    });
    $('.px-import', c).addEventListener('click', () => {
        let data;
        try {
            data = JSON.parse(ta.value);
        } catch (e) {
            setText(msg, 'That code is not valid JSON.');
            return;
        }
        if (!data || typeof data !== 'object' || Array.isArray(data)) {
            setText(msg, 'That code is not a HUD settings code.');
            return;
        }
        const next = { ...state.settings };
        for (const key of Object.keys(DEFAULT_SETTINGS)) {
            if (key in data && typeof data[key] === typeof DEFAULT_SETTINGS[key]) next[key] = data[key];
        }
        state.settings = next;
        applySettings();
        markDirty();
        setText(msg, 'Imported. Press Save Changes to keep it.');
    });
    frag.appendChild(c);
}

function buildDev(frag, items) {
    const c = make('section', 'pc');
    c.appendChild(make('h3', 'pc-title', 'Dev Tools'));
    c.appendChild(make('p', 'pc-sub', 'Preview HUD states without playing them out. Nothing here is saved.'));
    const body = make('div', 'pc-body cols');
    for (const row of DEV_ROWS) {
        let item;
        if (row.type === 'toggle') item = buildToggle({ ...row, label: row.title });
        else if (row.type === 'range') item = buildRange({ ...row, label: row.title });
        else item = buildAction({ label: row.title, button: row.label, run: row.action });
        if (row.type === 'toggle') item.node.classList.add('pt-field');
        body.appendChild(item.node);
        items.push(item);
    }
    c.appendChild(body);
    frag.appendChild(c);
}

function showPage(id, keepSearch) {
    const pages = visiblePages();
    const page = pages.find((p) => p.id === id) || pages[0];
    menu.page = page.id;
    if (!keepSearch && page.id !== 'home') menu.search = '';
    closePopups();
    $$('.pm-tab', menu.dom.side).forEach((b) => b.classList.toggle('on', b.dataset.page === page.id));
    const frag = document.createDocumentFragment();
    const items = [];
    if (!page.home) {
        const crumb = make('div', 'pm-crumb');
        crumb.append(ico(page.icon), make('span', '', page.title));
        frag.appendChild(crumb);
    }
    if (page.home) buildHome(frag, items);
    else if (page.transfer) buildTransfer(frag);
    else if (page.dev) buildDev(frag, items);
    else buildCards(page.cards, frag, items);
    const scroll = keepSearch ? menu.dom.content.scrollTop : 0;
    menu.dom.content.replaceChildren(frag);
    menu.dom.content.scrollTop = scroll;
    menu.items = items;
    menu.index = -1;
    if (keepSearch) {
        const input = $('.ps input', menu.dom.content);
        input.focus();
        input.setSelectionRange(input.value.length, input.value.length);
    }
    renderControls();
}

function renderControls() {
    menu.items.forEach((item) => item.update());
}

function renderFocus() {
    menu.items.forEach((item, i) => item.node.classList.toggle('focus', i === menu.index));
    const f = menu.items[menu.index];
    if (f) f.node.scrollIntoView({ block: 'nearest' });
}

function switchPage(dir) {
    const pages = visiblePages();
    const i = pages.findIndex((p) => p.id === menu.page);
    showPage(pages[(i + dir + pages.length) % pages.length].id);
}

// Keyboard / gamepad: up / down walk the fields, left / right change them, Q / E or the
// shoulders switch pages.
function menuNav(action) {
    if ($('.cp', el.settings) || $('.dd.open', el.settings)) {
        if (action === 'back' || action === 'accept') closePopups();
        return;
    }
    const f = menu.items[menu.index];
    const last = menu.items.length - 1;
    switch (action) {
        case 'up': menu.index = Math.max(0, menu.index - 1); break;
        case 'down': menu.index = Math.min(last, menu.index + 1); break;
        case 'left': if (f && f.def.type !== 'color' && f.def.type !== 'action') f.step(-1); break;
        case 'right': if (f && f.def.type !== 'color' && f.def.type !== 'action') f.step(1); break;
        case 'accept': if (f) f.step(1); break;
        case 'prevTab': switchPage(-1); return;
        case 'nextTab': case 'focus': switchPage(1); return;
        case 'back': requestClose(); return;
        default: return;
    }
    renderFocus();
}

/* colour picker */

function hexToHsv(hex) {
    const [r, g, b] = rgbOf(hex).split(', ').map((n) => n / 255);
    const max = Math.max(r, g, b);
    const d = max - Math.min(r, g, b);
    let h = 0;
    if (d) h = max === r ? ((g - b) / d) % 6 : max === g ? (b - r) / d + 2 : (r - g) / d + 4;
    return [(h * 60 + 360) % 360, max ? d / max : 0, max];
}
function hsvToHex(h, s, v) {
    const f = (n) => {
        const k = (n + h / 60) % 6;
        return Math.round((v - v * s * Math.max(0, Math.min(k, 4 - k, 1))) * 255).toString(16).padStart(2, '0');
    };
    return `#${f(5)}${f(3)}${f(1)}`;
}

function openPicker(field, key) {
    closePopups();
    let [h, s, v] = hexToHsv(colorOf(key));
    const cp = make('div', 'cp');
    cp.innerHTML = `<div class="cp-sv"><i class="cp-knob"></i></div><div class="cp-hue"><i class="cp-knob"></i></div>
        <div class="cp-row"><span class="cp-prev"></span><label class="cp-hex">#<input maxlength="6" spellcheck="false"></label></div>`;
    const sv = $('.cp-sv', cp);
    const hue = $('.cp-hue', cp);
    const input = $('input', cp);
    const draw = (fromInput) => {
        const hex = hsvToHex(h, s, v);
        sv.style.background = `linear-gradient(to top, #000, transparent), linear-gradient(to right, #fff, transparent), hsl(${h}, 100%, 50%)`;
        $('.cp-knob', sv).style.cssText = `left:${s * 100}%;top:${(1 - v) * 100}%;background:${hex}`;
        $('.cp-knob', hue).style.cssText = `left:${(h / 360) * 100}%;background:hsl(${h}, 100%, 50%)`;
        $('.cp-prev', cp).style.background = hex;
        if (!fromInput) input.value = hex.slice(1).toUpperCase();
        return hex;
    };
    const drag = (area, fn) => area.addEventListener('pointerdown', (e) => {
        area.setPointerCapture(e.pointerId);
        const move = (ev) => {
            const r = area.getBoundingClientRect();
            fn(clamp((ev.clientX - r.left) / r.width, 0, 1), clamp((ev.clientY - r.top) / r.height, 0, 1));
            setColor(key, draw());
        };
        move(e);
        area.onpointermove = move;
        area.onpointerup = () => { area.onpointermove = null; };
    });
    drag(sv, (x, y) => { s = x; v = 1 - y; });
    drag(hue, (x) => { h = x * 359.9; });
    input.addEventListener('input', () => {
        const hex = `#${input.value}`;
        if (!HEX.test(hex)) return;
        [h, s, v] = hexToHsv(hex.toLowerCase());
        draw(true);
        setColor(key, hex.toLowerCase());
    });
    draw();
    const host = field.closest('.pf');
    host.appendChild(cp);
}

/* open / close */

function setMode(mode) {
    state.mode = mode;
    el.settings.classList.toggle('off', mode !== 'menu');
    el.editor.classList.toggle('off', mode !== 'editor');
    el.calibrate.classList.toggle('off', mode !== 'calibrate');
    $('#devpanel').classList.toggle('off', mode !== 'devpanel');
    el.hud.classList.toggle('editing', mode === 'editor');
    el.hud.classList.toggle('calibrating', mode === 'calibrate');
    // the editor shows every widget with sample content
    renderInfo();
    renderVoiceBox();
    renderVehicleExtras();
    renderVc();
    post('menuMode', { mode });
}

function openMenu() {
    showPage(menu.page);
    markDirty();
    setMode('menu');
}

// Closing drops unsaved changes.
function requestClose() {
    closePopups();
    if (menu.saved && snapshot() !== menu.saved) applyServerSettings(JSON.parse(menu.saved));
    setMode('hud');
    post('closeSettings');
}

function applyServerSettings(settings) {
    if (!settings) return;
    state.settings = Object.assign(JSON.parse(JSON.stringify(DEFAULT_SETTINGS)), settings);
    // Lua encodes an empty table as [], which would drop string keys on the next save.
    for (const key of ['layout', 'colors', 'hidden']) {
        if (!state.settings[key] || Array.isArray(state.settings[key])) state.settings[key] = {};
    }
    menu.saved = snapshot();
    applySettings();
    renderControls();
    if (menu.dom.save) markDirty();
}

function resetLayout() {
    state.settings.layout = {};
    state.settings.hidden = {};
    applySettings();
}

/* ---------- edit mode ---------- */

const GRID = 16; // snap step in 1080p px
const ed = { frames: {}, drag: null, loop: 0, history: [], future: [], start: null, showHidden: true };

function widgetRect(name) {
    if (name === 'minimap') return $('.mm-frame', el.minimap).getBoundingClientRect();
    const inner = { controls: el.controlBar, toasts: el.toastList, status: el.strip, vcontrols: $('#vc-panel') };
    return (inner[name] || WIDGETS[name]).getBoundingClientRect();
}

const layoutState = () => JSON.stringify({ layout: state.settings.layout, hidden: state.settings.hidden });
function pushHistory() {
    ed.history.push(layoutState());
    if (ed.history.length > 60) ed.history.shift();
    ed.future = [];
    renderEditorButtons();
}
function restoreLayout(json) {
    const s = JSON.parse(json);
    state.settings.layout = s.layout;
    state.settings.hidden = s.hidden;
    applySettings();
    renderEditorButtons();
}

function buildEditor() {
    el.editor.innerHTML = `
        <div class="ed-grid"></div>
        <div class="ed-frames"></div>
        <div class="ed-card">
            <header class="pm-head"><span class="pm-logo cut"><i class="ico i-gear"></i></span>
                <div class="pm-title"><h1>Edit Mode</h1><p>Customize your HUD in here. Press save.</p></div></header>
            <p class="ed-text">Drag, hide any HUD component. To move around, simply click and drag; to hide, click the eye icon.</p>
            <section class="pc"><h3 class="pc-title"><span>Edit Hud</span><b class="pc-dot">•</b></h3>
                <div class="pc-body ed-toggles"></div></section>
            <div class="ed-hist">
                <button type="button" class="ed-undo"><i class="ico i-undo"></i>Undo</button>
                <button type="button" class="ed-redo"><i class="ico i-redo"></i>Redo</button>
                <button type="button" class="ed-reset"><i class="ico i-reset-o"></i>Reset</button>
            </div>
            <div class="ed-actions">
                <button type="button" class="pm-btn pm-reset ed-discard cut"><i class="ico i-reset-o"></i>Discard</button>
                <button type="button" class="pm-btn pm-save dirty ed-save cut"><i class="ico i-save-o"></i>Save</button>
            </div>
        </div>`;
    const toggles = $('.ed-toggles', el.editor);
    const snap = buildToggle({ key: 'snapGrid', label: 'Snap to grid' });
    snap.node.addEventListener('click', () => snap.update());
    const hidden = { node: make('button', 'pt'), update: () => {} };
    hidden.node.type = 'button';
    hidden.node.append(make('span', 'pt-track'), make('span', 'pt-text', 'Show hidden components'));
    hidden.update = () => {
        hidden.node.classList.toggle('on', ed.showHidden);
        el.hud.classList.toggle('show-hidden', ed.showHidden);
    };
    hidden.node.addEventListener('click', () => {
        ed.showHidden = !ed.showHidden;
        hidden.update();
    });
    toggles.append(snap.node, hidden.node);
    ed.toggles = [snap, hidden];
    $('.ed-undo', el.editor).addEventListener('click', () => {
        if (!ed.history.length) return;
        ed.future.push(layoutState());
        restoreLayout(ed.history.pop());
    });
    $('.ed-redo', el.editor).addEventListener('click', () => {
        if (!ed.future.length) return;
        ed.history.push(layoutState());
        restoreLayout(ed.future.pop());
    });
    $('.ed-reset', el.editor).addEventListener('click', () => {
        pushHistory();
        resetLayout();
    });
    $('.ed-discard', el.editor).addEventListener('click', () => {
        restoreLayout(ed.start);
        closeEditor();
    });
    $('.ed-save', el.editor).addEventListener('click', () => {
        saveSettings();
        closeEditor();
    });
    $('.ed-card', el.editor).addEventListener('pointerdown', (e) => e.stopPropagation());

    const frames = $('.ed-frames', el.editor);
    for (const name of Object.keys(WIDGETS)) {
        const f = make('div', 'ed-frame');
        f.append(make('i', 'ed-dot tl'), make('i', 'ed-dot tr'), make('i', 'ed-dot bl'), make('i', 'ed-dot br'));
        const eye = make('button', 'ed-eye');
        eye.type = 'button';
        eye.appendChild(ico('eye'));
        eye.addEventListener('pointerdown', (e) => e.stopPropagation());
        eye.addEventListener('click', () => {
            pushHistory();
            const hiddenMap = { ...state.settings.hidden };
            if (hiddenMap[name]) delete hiddenMap[name];
            else hiddenMap[name] = true;
            state.settings.hidden = hiddenMap;
            applySettings();
        });
        f.appendChild(eye);
        f.title = WIDGET_LABELS[name];
        f.addEventListener('pointerdown', (e) => {
            const l = getLayout(name);
            const r = widgetRect(name);
            const corner = e.target.classList.contains('ed-dot');
            pushHistory();
            ed.drag = { name, corner, x: e.clientX, y: e.clientY, ox: l.x, oy: l.y, os: l.s, left: r.left, top: r.top, size: Math.max(r.width, r.height) };
            f.classList.add('dragging');
            f.setPointerCapture(e.pointerId);
        });
        f.addEventListener('pointermove', (e) => {
            const d = ed.drag;
            if (!d || d.name !== name) return;
            let dx = e.clientX - d.x;
            let dy = e.clientY - d.y;
            if (d.corner) {
                // dragging a corner outwards grows the element
                const grow = (Math.abs(e.clientX - (d.left + d.size / 2)) - Math.abs(d.x - (d.left + d.size / 2))) / d.size;
                setLayout(name, { s: Math.round(clamp(d.os * (1 + grow * 2), 0.5, 1.5) * 100) / 100 });
                return;
            }
            // snap the element's top-left corner to the grid, not the offset
            if (state.settings.snapGrid) {
                const g = GRID * kr();
                dx = Math.round((d.left + dx) / g) * g - d.left;
                dy = Math.round((d.top + dy) / g) * g - d.top;
            }
            setLayout(name, { x: Math.round(d.ox + dx / kr()), y: Math.round(d.oy + dy / kr()) });
            if (name === 'minimap' && previewSync) previewSync();
        });
        const end = () => {
            if (!ed.drag) return;
            ed.drag = null;
            f.classList.remove('dragging');
            if (state.settings.layout[name] === undefined && name === 'minimap') post('saveSettings', state.settings);
        };
        f.addEventListener('pointerup', end);
        f.addEventListener('pointercancel', end);
        ed.frames[name] = f;
        frames.appendChild(f);
    }
}

function renderEditorButtons() {
    $('.ed-undo', el.editor).disabled = !ed.history.length;
    $('.ed-redo', el.editor).disabled = !ed.future.length;
}

function positionFrames() {
    const hidden = state.settings.hidden || {};
    for (const [name, f] of Object.entries(ed.frames)) {
        const r = widgetRect(name);
        const pad = 6;
        const visible = r.width > 0 && (!hidden[name] || ed.showHidden);
        f.style.display = visible ? '' : 'none';
        f.style.left = `${r.left - pad}px`;
        f.style.top = `${r.top - pad}px`;
        f.style.width = `${r.width + pad * 2}px`;
        f.style.height = `${r.height + pad * 2}px`;
        f.classList.toggle('is-hidden', Boolean(hidden[name]));
        $('.ed-eye .ico', f).className = `ico i-${hidden[name] ? 'eye-off' : 'eye'}`;
    }
    ed.loop = requestAnimationFrame(positionFrames);
}

function fillEditorSamples() {
    if (!controls.prompts && !controls.hints) {
        controls.sample = SAMPLE_CONTROLS;
        renderControlBar();
    }
    if (!el.toastList.childElementCount) {
        SAMPLE_TOASTS.forEach((t) => showToast({ ...t, sticky: true }));
        el.toastList.querySelectorAll('.toast').forEach((t) => t.classList.add('sample'));
    }
}

function clearEditorSamples() {
    controls.sample = null;
    renderControlBar();
    el.toastList.querySelectorAll('.toast.sample').forEach((t) => t.remove());
}

function openEditor() {
    closePopups();
    ed.start = layoutState();
    ed.history = [];
    ed.future = [];
    fillEditorSamples();
    setMode('editor');
    ed.toggles.forEach((t) => t.update());
    renderEditorButtons();
    cancelAnimationFrame(ed.loop);
    positionFrames();
}

function closeEditor() {
    cancelAnimationFrame(ed.loop);
    ed.drag = null;
    clearEditorSamples();
    openMenu();
}

function editorNav(action) {
    if (action === 'back') closeEditor();
}

el.editor.addEventListener('pointerdown', () => {});

/* ---------- messages ---------- */

Object.assign(renderers, { info: renderInfo, vc: renderVc });
Object.assign(handlers, {
    openSettings(d) {
        applyServerSettings(d.settings);
        state.devAccess = Boolean(d.dev);
        buildSide();
        if (d.page) menu.page = d.page;
        openMenu();
    },
    closeSettings() {
        cancelAnimationFrame(ed.loop);
        if (state.mode === 'editor') clearEditorSamples();
        closePopups();
        setMode('hud');
    },
    vcontrols(d) {
        state.vc.open = Boolean(d.open);
        renderVc();
    },
});

buildMenuShell();
buildSide();
buildEditor();
buildVehicleControls();
applySettings();
renderVc();
