// Browser-preview stand-in for server/app/misc (roach:open). In game every page comes from the
// server; this only mirrors its behaviour so the preview can be clicked through.

export function normAddr(a) {
    let s = String(a || '')
        .toLowerCase()
        .replace(/\s+/g, '')
        .replace(/^[a-z]+:\/\//, '')
        .replace(/^\/\//, '')
        .replace(/\/+$/, '');
    const m = s.match(/^([^/]*)(.*)$/);
    let host = m[1];
    if (host && !host.includes('.')) host += '.onion';
    return (host + m[2]).slice(0, 64);
}

export const validAddr = (a) => {
    const host = (a.match(/^([^/]+)/) || [])[1];
    return !!host && /^[a-z0-9][a-z0-9-]*\.onion$/.test(host) && host.length <= 40;
};

// same examples as Config.Roach.Sites
const SITES = {
    'board.onion': {
        title: 'the board',
        body: 'anonymous notes. nothing here is signed.\n\n> meet where the pier lights die. bring nothing.\n> whoever keeps leaving flowers at the observatory: we see you.\n> the old address is gone. ask around.\n\n[[board.onion/rules|rules]] · [[mirror.onion|mirror]]',
        hints: ['mods read this page at night'],
    },
    'board.onion/rules': { title: 'rules', body: '1. no names.\n2. no faces.\n3. if you know, you know.\n\n[[board.onion|back to the board]]' },
    'mirror.onion': { title: 'mirror', body: 'this is a mirror of a mirror.\n\nthe original is gone. so is the copy before this one.\n\n[[board.onion|board]]' },
};

const esc = (t) => String(t).replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');

function siteSource(addr, s) {
    const lines = ['<!doctype html>', '<html>', '<head>', `  <title>${esc(s.title)}</title>`, '  <meta charset="utf-8">'];
    (s.hints || []).forEach((h) => lines.push(`  <!-- ${h} -->`));
    lines.push('</head>', '<body>', `  <h1>${esc(s.title)}</h1>`);
    s.body
        .split('\n')
        .filter(Boolean)
        .forEach((p) => lines.push('  <p>' + esc(p).replace(/\[\[([^|\]]+)\|?([^\]]*)\]\]/g, (_, a, l) => `<a href="//${a}">${l || a}</a>`) + '</p>'));
    lines.push('</body>', '</html>');
    return lines.join('\n');
}

function decoy(addr) {
    let st = 7;
    for (const ch of 'roach:' + addr) st = (st * 31 + ch.charCodeAt(0)) % 2147483647;
    const r = (n) => {
        st = (st * 48271) % 2147483647;
        return (st % n) + 1;
    };
    const onion = () => {
        let s = '';
        for (let i = 0; i < 6; i++) s += 'abcdefghijklmnopqrstuvwxyz'[r(26) - 1];
        return s + '.onion';
    };
    const pool = [
        () => `  <meta name="x-resolved-to" content="${onion()}">`,
        () => `  <!-- 301 moved permanently -> ${onion()} -->`,
        () => `  <!-- puzzle solved. answer is ${onion()}. nothing else on this page matters. -->`,
        () => `  <!-- resolved: ${onion()} -->`,
        () => `  <style>.solution::after{content:"the next door is ${onion()}"}</style>`,
        () => '  <!-- nothing below this line is meant for you -->',
        () => '  <!-- do not index. we know who indexes. -->',
        () => `  <script>window.__ANSWER="${onion()}";</script>`,
    ];
    const head = [];
    for (let i = 0; i < 6; i++) head.push(pool[r(pool.length) - 1]());
    return [
        '<!doctype html>',
        '<html>',
        '<head>',
        '  <title>404</title>',
        '  <meta charset="utf-8">',
        ...head,
        '</head>',
        '<body>',
        '  <h1>Not Found</h1>',
        '  <p>The requested URL was not found on this server.</p>',
        '  <hr>',
        '  <address>husk/0.9.1 (Unix) Server at 127.0.0.1 Port 80</address>',
        `  <!-- @brood // ${1000 + r(8999)} -->`,
        '</body>',
        '</html>',
    ].join('\n');
}

export function mockOpen(raw) {
    const address = normAddr(raw);
    if (!validAddr(address)) return { ok: true, address, invalid: true };
    const s = SITES[address] || HOSTED[address];
    if (s) return { ok: true, address, title: s.title, body: s.body, source: siteSource(address, s) };
    return { ok: true, address, notFound: true, source: decoy(address) };
}

// hosted pages (roach:sites / roach:publish / roach:unpublish), kept in memory for the preview
const HOSTED = {};

export const mockSites = () => ({ ok: true, sites: Object.values(HOSTED).map((p) => ({ ...p, mine: true })) });

export function mockPublish(d) {
    const address = normAddr(d.address);
    if (!validAddr(address)) return { ok: false, reason: 'address' };
    if (SITES[address] || Object.keys(SITES).some((a) => a.split('/')[0] === address.split('/')[0])) return { ok: false, reason: 'taken' };
    if (!String(d.title || '').trim()) return { ok: false, reason: 'title' };
    HOSTED[address] = { address, title: d.title.trim().slice(0, 40), body: d.body || '', hints: d.hints || [], owner: 'You', updated: Math.floor(Date.now() / 1000) };
    return { ok: true, address };
}

export function mockUnpublish(d) {
    delete HOSTED[normAddr(d.address)];
    return { ok: true };
}
