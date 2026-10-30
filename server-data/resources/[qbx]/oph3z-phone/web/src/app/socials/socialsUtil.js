// Shared helpers for the Socials app (NoPixel-style front end for the Twexa backend).

export const MAX_POST = 280;

export const initials = (name) => {
    const s = String(name || '').replace(/[^A-Za-z0-9]/g, '');
    return (s.slice(0, 2) || '?').toUpperCase();
};

const pad = (n) => String(n).padStart(2, '0');

// Feed date: relative under a day ("now", "5m", "3h"), otherwise MM-DD-YYYY.
export function feedDate(ts) {
    if (!ts) return '';
    const s = Math.max(0, Math.floor(Date.now() / 1000) - ts);
    if (s < 60) return s < 10 ? 'now' : `${s}s`;
    if (s < 3600) return `${Math.floor(s / 60)}m`;
    if (s < 86400) return `${Math.floor(s / 3600)}h`;
    const d = new Date(ts * 1000);
    return `${pad(d.getMonth() + 1)}-${pad(d.getDate())}-${d.getFullYear()}`;
}

// Thread timestamp: 07/01/26, 12:26 AM
export function threadDate(ts) {
    if (!ts) return '';
    const d = new Date(ts * 1000);
    const h = d.getHours();
    const h12 = h % 12 === 0 ? 12 : h % 12;
    const date = `${pad(d.getMonth() + 1)}/${pad(d.getDate())}/${String(d.getFullYear()).slice(2)}`;
    return `${date}, ${h12}:${pad(d.getMinutes())} ${h >= 12 ? 'PM' : 'AM'}`;
}

export function fmtCount(n) {
    n = Number(n) || 0;
    if (n < 1000) return String(n);
    if (n < 1e6) return `${(n / 1000).toFixed(n < 10000 ? 1 : 0).replace('.0', '')}K`;
    return `${(n / 1e6).toFixed(1).replace('.0', '')}M`;
}

export const patchPosts = (list, id, patch) =>
    list ? list.map((p) => (String(p.id) === String(id) ? { ...p, ...patch } : p)) : list;

export const dropPost = (list, id) =>
    list ? list.filter((p) => String(p.id) !== String(id)) : list;

const TOKEN_RE = /(@[A-Za-z0-9_]+|#[A-Za-z0-9_]+)/g;
export function tokenize(text) {
    const str = String(text || '');
    const out = [];
    let last = 0;
    let m;
    TOKEN_RE.lastIndex = 0;
    while ((m = TOKEN_RE.exec(str)) !== null) {
        if (m.index > last) out.push({ type: 'text', value: str.slice(last, m.index) });
        out.push({ type: m[0][0] === '@' ? 'mention' : 'tag', value: m[0], key: m[0].slice(1) });
        last = m.index + m[0].length;
    }
    if (last < str.length) out.push({ type: 'text', value: str.slice(last) });
    return out;
}
