export function fmtTime(sec) {
    const s = Math.max(0, Math.floor(sec || 0));
    const m = Math.floor(s / 60);
    return `${m}:${String(s % 60).padStart(2, '0')}`;
}

const GRADS = [
    ['#fb2c48', '#3d0b16'],
    ['#ff5a6e', '#33141a'],
    ['#c81f39', '#2a0a12'],
    ['#ff7a5c', '#331a12'],
    ['#e0345a', '#2e0d18'],
];

function hash(str) {
    const key = String(str || '?');
    let h = 0;
    for (let i = 0; i < key.length; i++) h = (h * 31 + key.charCodeAt(i)) >>> 0;
    return h;
}

export function gradientFor(str) {
    const [a, b] = GRADS[hash(str) % GRADS.length];
    return `linear-gradient(145deg, ${a}, ${b})`;
}