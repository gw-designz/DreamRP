const root = document.getElementById('breakout');
const plate = root.querySelector('.plate');
const titleEl = document.getElementById('title');
const subtitleEl = document.getElementById('subtitle');
const instructionEl = document.getElementById('instruction');
const timerEl = document.getElementById('timer');
const percentEl = document.getElementById('percent');
const progressEl = document.getElementById('progress');
const timeEl = document.getElementById('time');
const keyEl = document.getElementById('key');

let duration = 1;
let hideTimeout = null;

// Same scaling as my-hud: 1 at 1080p
function rescale() {
    document.documentElement.style.setProperty('--k', window.innerHeight / 1080);
}
window.addEventListener('resize', rescale);
rescale();

function setProgress(value) {
    progressEl.style.setProperty('--v', value / 100);
    percentEl.textContent = Math.floor(value) + '%';
}

function setTime(elapsed) {
    const remaining = Math.max(0, duration - elapsed);
    timerEl.textContent = (remaining / 1000).toFixed(1);
    timerEl.classList.toggle('low', remaining < 1500);
    timeEl.style.setProperty('--t', remaining / duration);
}

function jolt() {
    plate.classList.remove('jolt');
    void plate.offsetWidth; // restart the animation
    plate.classList.add('jolt');
}

window.addEventListener('message', ({ data }) => {
    switch (data.action) {
        case 'open':
            clearTimeout(hideTimeout);
            duration = data.duration;
            titleEl.textContent = data.title;
            subtitleEl.textContent = data.subtitle;
            instructionEl.textContent = data.instruction;
            // Officer counter-game shows a key instead of the mouse
            keyEl.textContent = data.key || '';
            plate.classList.toggle('counter', !!data.key);
            plate.classList.remove('success', 'fail', 'jolt');
            setProgress(0);
            setTime(0);
            root.classList.remove('hidden');
            break;

        case 'update':
            setProgress(data.progress);
            setTime(data.elapsed);
            if (data.shook) jolt();
            break;

        case 'tap':
            jolt();
            break;

        case 'close':
            plate.classList.add(data.success ? 'success' : 'fail');
            timerEl.classList.remove('low');
            if (data.success) setProgress(100);
            subtitleEl.textContent = data.success ? data.successText : data.failText;
            hideTimeout = setTimeout(() => root.classList.add('hidden'), 1200);
            break;
    }
});
