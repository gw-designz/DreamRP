const root = document.getElementById('lockpick');
const plate = root.querySelector('.plate');
const titleEl = document.getElementById('title');
const subtitleEl = document.getElementById('subtitle');
const instructionEl = document.getElementById('instruction');
const timerEl = document.getElementById('timer');
const pinsEl = document.getElementById('pins');
const trackEl = document.getElementById('track');
const zoneEl = document.getElementById('zone');
const markerEl = document.getElementById('marker');
const missesEl = document.getElementById('misses');
const timeEl = document.getElementById('time');
const keyEl = document.getElementById('key');

const resource = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'lockpick_minigame';

// The game runs here so the hit test uses exactly what's on screen; client.lua only
// forwards key presses and waits for the result.
let game = null;
let text = {};
let hideTimeout = null;
let flashTimeout = null;

// Same scaling as my-hud: 1 at 1080p
function rescale() {
    document.documentElement.style.setProperty('--k', window.innerHeight / 1080);
}
window.addEventListener('resize', rescale);
rescale();

function jolt() {
    plate.classList.remove('jolt');
    void plate.offsetWidth; // restart the animation
    plate.classList.add('jolt');
}

function flash(cls) {
    clearTimeout(flashTimeout);
    trackEl.classList.remove('hit', 'miss');
    void trackEl.offsetWidth;
    trackEl.classList.add(cls);
    flashTimeout = setTimeout(() => trackEl.classList.remove(cls), 160);
}

function renderPins() {
    [...pinsEl.children].forEach((pin, i) => {
        pin.classList.toggle('set', i < game.pin);
        pin.classList.toggle('active', i === game.pin);
    });
}

function renderMisses() {
    const s = game.settings;
    missesEl.textContent = `${text.misses || 'Misses'} ${game.misses}/${s.maxMisses}`;
    missesEl.classList.toggle('warn', game.misses >= s.maxMisses - 1);
}

// New sweet spot for the current pin, never right under the marker (no free pins)
function placeZone() {
    const s = game.settings;
    const width = Math.min(Math.max(s.zone, 0.02), 0.9);
    let start = 0;
    for (let tries = 0; tries < 20; tries++) {
        start = 0.04 + Math.random() * (0.92 - width);
        const centre = start + width / 2;
        if (Math.abs(centre - game.pos) > width + 0.1) break;
    }
    game.zoneStart = start;
    game.zoneWidth = width;
    game.speed = s.speed * (1 + s.speedStep * game.pin);
    zoneEl.style.setProperty('--zs', start);
    zoneEl.style.setProperty('--zw', width);
}

// Marker bounces between the ends of the track at game.speed track-lengths per second
function advance(now) {
    const dt = Math.min(now - game.last, 100) / 1000;
    game.last = now;
    let pos = game.pos + game.dir * game.speed * dt;
    while (pos > 1 || pos < 0) {
        if (pos > 1) { pos = 2 - pos; game.dir = -1; }
        if (pos < 0) { pos = -pos; game.dir = 1; }
    }
    game.pos = pos;
}

function frame(now) {
    if (!game || game.over) return;
    advance(now);
    markerEl.style.setProperty('--m', game.pos);

    const remaining = Math.max(0, game.settings.time - (now - game.started));
    timerEl.textContent = (remaining / 1000).toFixed(1);
    timerEl.classList.toggle('low', remaining < 3000);
    timeEl.style.setProperty('--t', remaining / game.settings.time);

    if (remaining <= 0) return finish(false, false);
    requestAnimationFrame(frame);
}

function press() {
    if (!game || game.over) return;
    advance(performance.now());

    const grace = game.grace;
    const inZone = game.pos >= game.zoneStart - grace && game.pos <= game.zoneStart + game.zoneWidth + grace;

    if (inZone) {
        flash('hit');
        game.pin++;
        renderPins();
        if (game.pin >= game.settings.pins) return finish(true, false);
        placeZone();
        return;
    }

    game.misses++;
    flash('miss');
    jolt();
    if (game.settings.dropPinOnMiss && game.pin > 0) {
        game.pin--;
        const dropped = pinsEl.children[game.pin];
        dropped.classList.remove('dropped');
        void dropped.offsetWidth;
        dropped.classList.add('dropped');
        renderPins();
        placeZone();
    }
    renderMisses();
    if (game.misses >= game.settings.maxMisses) finish(false, false);
}

// Shows the result. report = false when client.lua already ended the attempt itself.
function finish(success, cancelled, report = true) {
    if (!game || game.over) return;
    game.over = true;

    plate.classList.add(success ? 'success' : 'fail');
    timerEl.classList.remove('low');
    if (success) { game.pin = game.settings.pins; renderPins(); }
    subtitleEl.textContent = success ? text.ui_success : cancelled ? text.ui_cancel : text.ui_fail;
    hideTimeout = setTimeout(() => root.classList.add('hidden'), 1200);

    if (report) {
        fetch(`https://${resource}/finish`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json; charset=UTF-8' },
            body: JSON.stringify({ success, cancelled }),
        }).catch(() => {});
    }
}

function open(data) {
    clearTimeout(hideTimeout);
    text = data.text || {};
    const s = data.settings;
    const now = performance.now();

    game = {
        settings: s,
        grace: data.grace || 0,
        pin: 0,
        misses: 0,
        pos: 0,
        dir: 1,
        speed: s.speed,
        zoneStart: 0,
        zoneWidth: 0,
        started: now,
        last: now,
        over: false,
    };

    titleEl.textContent = text.title;
    subtitleEl.textContent = s.label;
    instructionEl.textContent = text.instruction;
    keyEl.textContent = data.keyLabel || 'E';

    pinsEl.innerHTML = '';
    for (let i = 0; i < s.pins; i++) {
        const pin = document.createElement('div');
        pin.className = 'pin';
        pinsEl.appendChild(pin);
    }

    plate.classList.remove('success', 'fail', 'jolt');
    trackEl.classList.remove('hit', 'miss');
    placeZone();
    renderPins();
    renderMisses();
    root.classList.remove('hidden');
    requestAnimationFrame(frame);
}

window.addEventListener('message', ({ data }) => {
    switch (data.action) {
        case 'open':
            open(data);
            break;
        case 'press':
            press();
            break;
        case 'cancel':
            finish(false, true);
            break;
        case 'abort':
            finish(!!data.success, !!data.cancelled, false);
            break;
    }
});
