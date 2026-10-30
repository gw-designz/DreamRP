'use strict';
// Browser preview: index.html?demo with sample values (see README). Never runs in game.

if (!IS_FIVEM && /[?&]demo\b/.test(location.search)) {
    const q = new URLSearchParams(location.search);
    const num = (key, fallback) => (q.has(key) ? Number(q.get(key)) : fallback);
    const send = (data) => window.postMessage(data, '*');
    // stand-in for the game world so white elements stay visible (&bg=none to drop it)
    if (q.get('bg') !== 'none') document.body.style.background = 'radial-gradient(ellipse at 60% 35%, #2a3138 0%, #14181c 55%, #0b0d10 100%)';
    if (q.has('scale')) state.settings.scale = num('scale', 1);
    if (q.get('style') === 'classic') state.settings.hudStyle = 'classic';
    if (q.has('status')) state.settings.statusStyle = q.get('status');
    if (q.has('map')) state.settings.mapStyle = q.get('map');
    if (q.has('loc')) state.settings.locationStyle = q.get('loc');
    if (q.has('speedo')) state.settings.speedoStyle = q.get('speedo');
    applySettings();
    // Mirrors baseRect() and layoutMinimap() in client/minimap.lua with its default config; redone
    // on resize and on every settings, editor or calibration change, like Lua does in game.
    const map = make('div');
    if (!q.has('nomap')) document.body.prepend(map);
    // Config.Minimap, its styles.classic override and Config.Minimap.circle
    const GEOMETRY = { circuit: [295, 193, 10, 86], classic: [295, 194, 38, 84], circle: [205, 205, 24, 86] };
    const placeMap = () => {
        const round = styleOf('mapStyle') === 'circle';
        const [gw, gh, gl, gb] = round ? GEOMETRY.circle : GEOMETRY[state.settings.hudStyle] || GEOMETRY.circuit;
        const k = kr() * state.settings.scale;
        const mw = gw * k;
        const mh = gh * k;
        const mx = gl * k;
        const my = window.innerHeight - gb * k - mh;
        // the radar carries the editor offset / size and the calibration; the frame gets the base rect
        const l = getLayout('minimap');
        const st = state.settings;
        const w = mw * l.s;
        const h = mh * l.s;
        const x = mx + l.x * kr() + st.mapOffsetX * k - (w - mw) / 2;
        const y = my + l.y * kr() + st.mapOffsetY * k - (h - mh) / 2;
        // stand-in for the game radar: grey blocks and roads like the light map style
        Object.assign(map.style, {
            position: 'fixed', left: `${x}px`, top: `${y}px`, width: `${w}px`, height: `${h}px`,
            borderRadius: round ? '50%' : `${5 * k}px`, overflow: 'hidden',
            background: `linear-gradient(160deg, transparent 0 18%, #c9b25a 18% 26%, transparent 26%),
                repeating-linear-gradient(28deg, #8c9094 0 ${3 * k}px, transparent ${3 * k}px ${34 * k}px),
                repeating-linear-gradient(-62deg, #8c9094 0 ${3 * k}px, transparent ${3 * k}px ${30 * k}px),
                #5d6166`,
        });
        send({ action: 'minimap', cx: (mx + mw / 2) / window.innerWidth, cy: (my + mh / 2) / window.innerHeight, kh: k / window.innerHeight, width: gw, height: gh });
    };
    placeMap();
    previewSync = placeMap;
    window.addEventListener('resize', placeMap);
    send({ action: 'visible', value: true });
    send({ action: 'update', group: 'map', data: { show: true } });
    send({ action: 'update', group: 'compass', data: { heading: num('heading', 180) } });
    send({ action: 'update', group: 'location', data: {
        zone: q.get('style') === 'classic' ? 'Pillbox Hill' : 'Vespucci Canals', street: 'San Andreas Ave',
        cross: q.get('style') === 'classic' || q.has('cross') ? 'Peaceful St' : '',
        waypoint: num('waypoint', -1), wpBearing: num('wpbearing', 120),
    } });
    send({ action: 'update', group: 'status', data: {
        health: num('health', 100), armor: num('armor', 100), hunger: num('hunger', 75), thirst: num('thirst', 80),
        stress: num('stress', 0), stamina: num('stamina', 100), oxygen: num('oxygen', 100), underwater: q.has('underwater'),
        dev: q.has('dev'),
    } });
    send({ action: 'update', group: 'info', data: {
        job: 'Law Enforcement', grade: 'Recruit', cash: 10000024350, bank: 98958447, id: 3, time: '02:00',
    } });
    if (q.has('vcontrols')) {
        send({ action: 'vcontrols', open: true });
        send({ action: 'update', group: 'vc', data: { engine: true, locked: false, indLeft: false, indRight: false, lights: true, cruise: false,
            neon: false, doors: { 0: true }, windows: {}, seats: { 0: true }, seatCount: 4 } });
    }
    send({ action: 'update', group: 'voice', data: { range: 2, talking: q.has('talking'), radio: q.has('radio'), channel: num('channel', 0) } });
    if (q.has('vehicle')) {
        const mode = q.get('vehicle') || 'car';
        send({ action: 'update', group: 'vehicle', data: {
            show: true, mode, speed: num('speed', mode === 'air' ? 90 : 28),
            unit: mode === 'air' || mode === 'boat' ? 'KNOTS' : q.get('unit') || 'MPH',
            rpm: num('rpm', 38), gear: q.get('gear') || '2', altitude: '794 ft',
            fuel: num('fuel', 55), engine: num('enginehp', 92), belt: q.has('belt'), beltable: true, moving: false, lights: true, locked: q.has('locked'),
            indLeft: ['left', 'both'].includes(q.get('ind')), indRight: ['right', 'both'].includes(q.get('ind')),
            limit: num('limit', 35), heading: num('heading', 161), pitch: num('pitch', 6), roll: num('roll', 9),
            alt: num('alt', 896), altUnit: 'ft', climb: num('climb', -1280), braking: q.has('brake'), doorsOpen: q.has('doors'),
        } });
        if (q.has('hints')) send({ action: 'hints', items: SAMPLE_CONTROLS });
    }
    if (q.has('ammo')) send({ action: 'update', group: 'ammo', data: { show: true, clip: 9, reserve: 54, name: 'Pistol' } });
    if (q.has('toasts')) SAMPLE_TOASTS.forEach((t) => send({ action: 'toast', ...t, sticky: true }));
    if (q.has('prompts')) {
        send({ action: 'prompts', items: [
            { key: 'LT', label: 'Aim' }, { key: 'RT', label: 'Cast' },
            { key: 'B', label: 'Bait', circle: true }, { key: 'Y', label: 'Put away', circle: true },
        ] });
    }
    if (q.has('engine')) {
        send({ action: 'hints', items: [
            { key: 'WHEELUP', label: 'Engine on' }, { key: 'WHEELDOWN', label: 'Engine off' },
            { key: 'B', label: 'Seatbelt' }, { key: 'F', label: 'Exit' },
        ] });
    }
    if (q.has('settings')) {
        menu.page = q.get('tab') || 'home';
        send({ action: 'openSettings', settings: state.settings, dev: true });
    }
    if (q.has('editor')) setTimeout(() => openEditor(q.get('editor')), 50);
    if (q.has('calibrate')) setTimeout(startCalibration, 50);
    if (q.has('devpanel')) setTimeout(openDevPanel, 50);
    if (q.has('map3d')) {
        // after map3d.js has loaded and is listening
        window.addEventListener('load', () => {
            map.style.display = 'none';
            // mirrors Config.Map3D.paint / paintNight in config.lua
            const paint = {
                land: [214, 172, 174], road: [234, 202, 204], lot: [224, 188, 190], sand: [226, 196, 190],
                footprint: [200, 152, 156], rail: [192, 148, 152], lane: [176, 122, 128, 0.3], water: [124, 120, 130],
                shallow: [150, 144, 154], roof: [198, 130, 136], wall: [170, 98, 106], haze: [238, 212, 214],
            };
            const paintNight = {
                land: [20, 18, 20], road: [58, 42, 46], lot: [30, 26, 28], sand: [34, 28, 30],
                footprint: [28, 24, 26], rail: [44, 34, 36], lane: [150, 60, 70, 0.25], water: [10, 11, 14],
                shallow: [16, 17, 22], roof: [46, 32, 36], wall: [24, 16, 18], haze: [38, 24, 28],
            };
            send({ action: 'map3d', load: true, show: true, config: { paint, paintNight } });
            send({ action: 'map3dPos', x: num('x', 215), y: num('y', -905), c: num('cam', 20), h: num('cam', 20), s: 0, g: 0 });
            if (q.has('night')) send({ action: 'map3d', night: 1 });
        });
    }
    if (q.has('spin')) {
        let h = num('heading', 180);
        setInterval(() => {
            h = (h + 3) % 360;
            send({ action: 'update', group: 'compass', data: { heading: h } });
        }, 60);
    }
}
