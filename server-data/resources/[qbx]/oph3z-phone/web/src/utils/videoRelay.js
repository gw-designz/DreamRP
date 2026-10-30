const FRAME_WIDTH = 256;
const FRAME_INTERVAL = 110;
const JPEG_QUALITY = 0.45;

let timer = null;
let scratch = null;
let inFlight = false;

function scaleCanvas(source) {
    if (!scratch) scratch = document.createElement('canvas');
    const sw = source.width || 1;
    const sh = source.height || 1;
    const w = FRAME_WIDTH;
    const h = Math.max(1, Math.round((sh / sw) * w));
    if (scratch.width !== w || scratch.height !== h) {
        scratch.width = w;
        scratch.height = h;
    }
    const ctx = scratch.getContext('2d');
    if (!ctx) return null;
    try {
        ctx.drawImage(source, 0, 0, w, h);
    } catch (e) {
        return null;
    }
    try {
        return scratch.toDataURL('image/jpeg', JPEG_QUALITY);
    } catch (e) {
        return null;
    }
}

export function startRelaySend(source, send) {
    stopRelaySend();
    if (!source || !send) return;
    inFlight = false;
    timer = setInterval(() => {
        if (inFlight) return;
        const frame = scaleCanvas(source);
        if (!frame) return;
        inFlight = true;
        const done = () => {
            inFlight = false;
        };
        try {
            const p = send(frame);
            if (p && p.then) p.then(done, done);
            else done();
        } catch (e) {
            done();
        }
    }, FRAME_INTERVAL);
}

export function stopRelaySend() {
    if (timer) clearInterval(timer);
    timer = null;
    inFlight = false;
}