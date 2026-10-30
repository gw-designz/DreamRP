// Roach: a tiny dark-web browser. Type an address ("name" or "name.onion") to visit it. Sites
// are defined server-side (Config.Roach.Sites / RegisterRoachSite); every other .onion address is
// a 404 with its own decoy source. Back / Forward / Reload / Home live in the ⋮ menu, Backspace
// goes back. Bookmarks + notes are saved per character. Players (and admins) publish their own
// pages from ⋮ › Host a Site (server/app/misc, Config.Roach.Hosting). Best used unfolded.
import { useEffect, useRef, useState } from 'react';
import { useSelector } from 'react-redux';
import { faEllipsisVertical } from '@fortawesome/free-solid-svg-icons';
import FaIcon from '../../FaIcon';
import { NpApp, Spinner, Empty, npCall, useNpFetch, useStatusTone, useBack, money } from '../../ui/kit';
import { isEnvBrowser } from '../../../utils/misc';
import { mockOpen, mockSites, mockPublish, mockUnpublish } from './roachMock';
import './roach.css';

const MOCK_STATE = {
    ok: true,
    bookmarks: [{ address: 'roach.onion', title: '404' }],
    notes: '',
    home: 'roach.onion',
    hosting: { admin: true, cost: 0, maxSites: 3, maxPages: 10, maxBody: 4000 },
};

const CONNECT_ERRORS = {
    noitem: 'you need special equipment to reach the network.',
    auth: 'no identity. reconnect and try again.',
};

export default function Roach() {
    const folded = useSelector((s) => s.phone.folded);
    const [state, reload] = useNpFetch('phone:np:roach:state', {}, MOCK_STATE);
    const [host, setHost] = useState(false);
    const [addr, setAddr] = useState('');
    const [page, setPage] = useState(null);
    const [loading, setLoading] = useState(false);
    const [bookmarks, setBookmarks] = useState([]);
    const [notes, setNotes] = useState('');
    const [panel, setPanel] = useState(false);
    const [menu, setMenu] = useState(false);
    const [viewSource, setViewSource] = useState(false);
    const [hist, setHist] = useState({ list: [], idx: -1 });
    const histRef = useRef(hist);
    histRef.current = hist;
    const reqRef = useRef(0);
    const saveTimer = useRef(null);
    useStatusTone('light');

    // Backspace: close the source / menu first, then walk back through history
    useBack(() => {
        if (viewSource) return setViewSource(false), true;
        if (menu) return setMenu(false), true;
        if (histRef.current.idx > 0) return step(-1), true;
        return false;
    }, 6);

    // Ctrl+U = view source, like a desktop browser
    const pageRef = useRef(null);
    pageRef.current = page;
    useEffect(() => {
        const onKey = (e) => {
            if (e.ctrlKey && (e.key === 'u' || e.key === 'U') && pageRef.current) {
                e.preventDefault();
                setMenu(false);
                setViewSource((v) => !v);
            }
        };
        window.addEventListener('keydown', onKey);
        return () => window.removeEventListener('keydown', onKey);
    }, []);

    useEffect(() => {
        if (state && state.ok) {
            setBookmarks(state.bookmarks || []);
            setNotes(state.notes || '');
            go(state.home);
        }
        // eslint-disable-next-line react-hooks/exhaustive-deps
    }, [state]);

    const persist = (bm, n) => {
        clearTimeout(saveTimer.current);
        saveTimer.current = setTimeout(() => npCall('phone:np:roach:save', { bookmarks: bm, notes: n }, { ok: true }), 600);
    };

    // mode: 'push' (new visit), 'stay' (reload / history step: history handled by caller)
    const load = async (to, mode = 'push') => {
        const a = String(to || '').trim();
        if (!a) return;
        const req = ++reqRef.current;
        setAddr(a);
        setLoading(true);
        setViewSource(false);
        setMenu(false);
        setHost(false);
        const r = await npCall('phone:np:roach:open', { address: a }, mockOpen(a));
        if (req !== reqRef.current) return; // a newer navigation won
        setLoading(false);
        // a failed request is a connection error, not a 404, so players can tell the two apart
        const pageData = r.ok ? r : { failed: r.reason || 'error', address: a };
        const address = pageData.address || a;
        setAddr(address);
        setPage(pageData);
        if (mode === 'push') {
            setHist((h) => {
                if (h.list[h.idx] === address) return h;
                const list = [...h.list.slice(0, h.idx + 1), address].slice(-50);
                return { list, idx: list.length - 1 };
            });
        }
    };
    const go = (to) => load(to, 'push');

    const step = (dir) => {
        const h = histRef.current;
        const idx = h.idx + dir;
        if (idx < 0 || idx >= h.list.length) return;
        setHist({ list: h.list, idx });
        load(h.list[idx], 'stay');
    };
    const canBack = hist.idx > 0;
    const canForward = hist.idx < hist.list.length - 1;
    const home = (state && state.home) || 'roach.onion';

    if (state === null) return <NpApp className="nrc"><Spinner /></NpApp>;
    if (!state.ok)
        return (
            <NpApp className="nrc">
                <Empty title={state.reason === 'noitem' ? 'No connection' : 'Couldn’t start the browser'} body={state.reason === 'noitem' ? 'You need special equipment to reach the network.' : null} action="Retry" onAction={reload} />
            </NpApp>
        );

    const saved = bookmarks.some((b) => b.address === (page && page.address));
    const toggleSave = () => {
        if (!page || !page.address) return;
        const next = saved ? bookmarks.filter((b) => b.address !== page.address) : [...bookmarks, { address: page.address, title: page.notFound ? '404' : page.title }];
        setBookmarks(next);
        persist(next, notes);
    };

    const archive = (
        <aside className="nrc-archive">
            <div className="nrc-archive__head">archive</div>
            <div className="nrc-archive__bm">
                <div className="nrc-archive__row">
                    <b>bookmarks</b>
                    <button className={saved ? 'is-saved' : ''} onClick={toggleSave} disabled={!page}>
                        {saved ? 'saved' : 'save'}
                    </button>
                </div>
                {bookmarks.map((b) => (
                    <div key={b.address} className="nrc-bm">
                        <button onClick={() => go(b.address)}>{b.title || b.address}</button>
                        <small>{b.address}</small>
                        <button
                            className="nrc-bm__x"
                            onClick={() => {
                                const next = bookmarks.filter((x) => x.address !== b.address);
                                setBookmarks(next);
                                persist(next, notes);
                            }}
                            aria-label="Remove"
                        >
                            ×
                        </button>
                    </div>
                ))}
            </div>
            <div className="nrc-archive__notes">
                <b>notes</b>
                <textarea
                    value={notes}
                    maxLength={4000}
                    spellCheck={false}
                    placeholder="scratchpad for ciphers, addresses, anything"
                    onChange={(e) => {
                        setNotes(e.target.value);
                        persist(bookmarks, e.target.value);
                    }}
                />
            </div>
        </aside>
    );

    return (
        <NpApp className={`nrc${folded ? ' is-folded' : ''}`}>
            <div className="nrc-wrap">
                <section className="nrc-browser">
                    <div className="nrc-bar">
                        <input
                            value={addr}
                            spellCheck={false}
                            onChange={(e) => setAddr(e.target.value)}
                            onKeyDown={(e) => {
                                if (e.key === 'Enter') {
                                    e.preventDefault();
                                    go(addr);
                                }
                            }}
                        />
                        <button className={menu ? 'is-on' : ''} onClick={() => setMenu((v) => !v)} aria-label="Menu">
                            <FaIcon icon={faEllipsisVertical} />
                        </button>
                        {menu && (
                            <div className="nrc-menu">
                                <button disabled={!canBack} onClick={() => step(-1)}>
                                    Back
                                </button>
                                <button disabled={!canForward} onClick={() => step(1)}>
                                    Forward
                                </button>
                                <button disabled={!page} onClick={() => load(page.address || addr, 'stay')}>
                                    Reload
                                </button>
                                <button onClick={() => go(home)}>Home</button>
                                {state.hosting && (
                                    <button
                                        onClick={() => {
                                            setMenu(false);
                                            setViewSource(false);
                                            setHost(true);
                                        }}
                                    >
                                        Host a Site
                                    </button>
                                )}
                                <hr />
                                <button
                                    disabled={!page || loading || page.invalid || !!page.failed}
                                    onClick={() => {
                                        setMenu(false);
                                        setViewSource(true);
                                    }}
                                >
                                    View Page Source
                                </button>
                                {folded && (
                                    <button
                                        onClick={() => {
                                            setMenu(false);
                                            setPanel((v) => !v);
                                        }}
                                    >
                                        {panel ? 'Hide Archive' : 'Archive'}
                                    </button>
                                )}
                            </div>
                        )}
                    </div>
                    {host ? (
                        <HostPanel hosting={state.hosting} onClose={() => setHost(false)} onVisit={go} />
                    ) : viewSource && page ? (
                        <SourceView address={page.address || addr} source={page.source} onClose={() => setViewSource(false)} onLink={go} />
                    ) : (
                        <div className="nrc-page">
                            {page && page.failed ? (
                                <div className="nrc-error">
                                    <h1>Connection failed</h1>
                                    <p>roach couldn’t reach {page.address || 'that address'}.</p>
                                    <p>{CONNECT_ERRORS[page.failed] || 'the network didn’t answer. try again in a moment.'}</p>
                                </div>
                            ) : page && page.invalid ? (
                                <div className="nrc-error">
                                    <h1>Unable to connect</h1>
                                    <p>roach can’t establish a connection to {page.address || 'that address'}.</p>
                                    <p>only .onion addresses are reachable on this network. try something like {home}.</p>
                                </div>
                            ) : page && page.notFound ? (
                                <>
                                    <h1>404</h1>
                                    <p>nothing lives at {page.address || 'this address'} anymore.</p>
                                </>
                            ) : page ? (
                                <>
                                    <h1>{page.title}</h1>
                                    <SiteBody text={page.body} onLink={go} />
                                </>
                            ) : null}
                        </div>
                    )}
                    <div className="nrc-status">{loading ? `Connecting to ${addr}…` : 'Done'}</div>
                </section>
                {(!folded || panel) && archive}
                {menu && <div className="nrc-menu__scrim" onClick={() => setMenu(false)} />}
            </div>
        </NpApp>
    );
}

const HOST_ERRORS = {
    address: 'use a .onion address, like name.onion or name.onion/page.',
    taken: 'that address already belongs to someone else.',
    reserved: 'that address is reserved.',
    title: 'give the page a title.',
    limit: 'you already run the maximum number of addresses.',
    pages: 'that address already has the maximum number of pages.',
    funds: 'not enough money in your bank account.',
    slow: 'slow down a little.',
    noitem: 'you need special equipment to reach the network.',
    disabled: 'hosting is switched off on this network.',
    owner: 'that page isn’t yours.',
};

// "roach host": list, create, edit and take down hosted pages. Admins see every page.
function HostPanel({ hosting, onClose, onVisit }) {
    const [sites, setSites] = useState(null);
    const [edit, setEdit] = useState(null); // null = list, {} = new page, page = editing
    const [confirm, setConfirm] = useState(null);
    const [err, setErr] = useState('');

    const refresh = async () => {
        const r = await npCall('phone:np:roach:sites', {}, mockSites());
        setSites(r.ok ? r.sites || [] : []);
        if (!r.ok) setErr(HOST_ERRORS[r.reason] || 'couldn’t load your pages.');
    };
    useEffect(() => {
        refresh();
    }, []);

    useBack(() => {
        if (edit) setEdit(null);
        else onClose();
        return true;
    }, 7);

    const remove = async (address) => {
        if (confirm !== address) return setConfirm(address);
        setConfirm(null);
        const r = await npCall('phone:np:roach:unpublish', { address }, isEnvBrowser() ? mockUnpublish({ address }) : undefined);
        if (!r.ok) setErr(HOST_ERRORS[r.reason] || 'couldn’t take that page down.');
        refresh();
    };

    if (edit)
        return (
            <HostForm
                hosting={hosting}
                page={edit}
                onCancel={() => setEdit(null)}
                onDone={(address) => {
                    setEdit(null);
                    onVisit(address);
                }}
            />
        );

    const mine = (sites || []).filter((s) => s.mine);
    const others = (sites || []).filter((s) => !s.mine);
    const row = (s) => (
        <div key={s.address} className="nrc-host__row">
            <span className="nrc-host__main">
                <button className="nrc-link" onClick={() => onVisit(s.address)}>
                    {s.address}
                </button>
                <small>
                    {s.title}
                    {!s.mine && s.owner ? ` · ${s.owner}` : ''}
                </small>
            </span>
            <button onClick={() => setEdit(s)}>edit</button>
            <button className={confirm === s.address ? 'is-danger' : ''} onClick={() => remove(s.address)}>
                {confirm === s.address ? 'sure?' : 'take down'}
            </button>
        </div>
    );

    return (
        <div className="nrc-src nrc-host">
            <div className="nrc-src__bar">
                <span>roach host{hosting.admin ? ' · admin' : ''}</span>
                <button onClick={() => setEdit({})}>new page</button>
                <button onClick={onClose}>close</button>
            </div>
            <div className="nrc-host__body">
                <p className="nrc-host__intro">
                    publish your own pages on the network. the first page on a name claims it; add sub-pages like name.onion/about.
                    {!hosting.admin && hosting.maxSites > 0 ? ` you can run ${hosting.maxSites} address${hosting.maxSites === 1 ? '' : 'es'}.` : ''}
                    {!hosting.admin && hosting.cost > 0 ? ` claiming a new address costs ${money(hosting.cost)}.` : ''}
                </p>
                {err && <p className="nrc-host__err">{err}</p>}
                <b className="nrc-host__h">your pages</b>
                {sites === null ? (
                    <p className="nrc-host__muted">loading…</p>
                ) : mine.length === 0 ? (
                    <p className="nrc-host__muted">nothing hosted yet.</p>
                ) : (
                    mine.map(row)
                )}
                {hosting.admin && others.length > 0 && (
                    <>
                        <b className="nrc-host__h">everyone else</b>
                        {others.map(row)}
                    </>
                )}
            </div>
        </div>
    );
}

function HostForm({ hosting, page, onCancel, onDone }) {
    const editing = !!page.address;
    const [address, setAddress] = useState(page.address || '');
    const [title, setTitle] = useState(page.title || '');
    const [body, setBody] = useState(page.body || '');
    const [hints, setHints] = useState((page.hints || []).join('\n'));
    const [busy, setBusy] = useState(false);
    const [err, setErr] = useState('');

    const publish = async () => {
        if (!address.trim()) return setErr(HOST_ERRORS.address);
        if (!title.trim()) return setErr(HOST_ERRORS.title);
        const payload = {
            address: address.trim(),
            title: title.trim(),
            body,
            hints: hints.split('\n').map((h) => h.trim()).filter(Boolean).slice(0, 10),
        };
        setBusy(true);
        setErr('');
        const r = await npCall('phone:np:roach:publish', payload, isEnvBrowser() ? mockPublish(payload) : undefined);
        setBusy(false);
        if (r.ok) onDone(r.address || payload.address);
        else setErr(HOST_ERRORS[r.reason] || 'publishing failed.');
    };

    return (
        <div className="nrc-src nrc-host">
            <div className="nrc-src__bar">
                <span>{editing ? `edit ${page.address}` : 'new page'}</span>
                <button onClick={onCancel}>cancel</button>
            </div>
            <div className="nrc-host__body nrc-host__form">
                <label>
                    address
                    <input value={address} disabled={editing} maxLength={64} spellCheck={false} placeholder="name.onion or name.onion/page" onChange={(e) => setAddress(e.target.value)} />
                </label>
                <label>
                    title
                    <input value={title} maxLength={40} spellCheck={false} onChange={(e) => setTitle(e.target.value)} />
                </label>
                <label>
                    page text <em>[[name.onion]] or [[name.onion|label]] makes a link</em>
                    <textarea className="nrc-host__text" value={body} maxLength={hosting.maxBody || 4000} spellCheck={false} onChange={(e) => setBody(e.target.value)} />
                </label>
                <label>
                    hidden comments <em>one per line, only visible in view page source</em>
                    <textarea value={hints} maxLength={1600} spellCheck={false} onChange={(e) => setHints(e.target.value)} />
                </label>
                {err && <p className="nrc-host__err">{err}</p>}
                <button className="nrc-host__publish" disabled={busy} onClick={publish}>
                    {busy ? 'publishing…' : editing ? 'save changes' : 'publish'}
                </button>
            </div>
        </div>
    );
}

// "view-source:" window: line numbers, wrapped lines, HTML comments in green italics.
function SourceView({ address, source, onClose, onLink }) {
    const lines = String(source || '').split('\n');
    return (
        <div className="nrc-src">
            <div className="nrc-src__bar">
                <span>view-source:{address}</span>
                <button onClick={onClose}>close</button>
            </div>
            <div className="nrc-src__body">
                {lines.map((line, i) => (
                    <div key={i} className="nrc-src__line">
                        <span className="nrc-src__num">{i + 1}</span>
                        <code>{highlight(line, onLink)}</code>
                    </div>
                ))}
            </div>
        </div>
    );
}

const ONION_RE = /([a-z0-9][a-z0-9-]*\.onion(?:\/[a-z0-9_\-/]*[a-z0-9_\-])?)/g;

// .onion addresses in the source are clickable (like links in a browser's view-source)
function linkify(text, onLink, keyBase) {
    return text.split(ONION_RE).map((p, i) =>
        i % 2 === 1 ? (
            <button key={keyBase + i} className="nrc-src__link" onClick={() => onLink(p)}>
                {p}
            </button>
        ) : (
            p
        ),
    );
}

function highlight(line, onLink) {
    const parts = line.split(/(<!--.*?-->)/g);
    return parts.map((p, i) =>
        p.startsWith('<!--') ? (
            <span key={i} className="nrc-src__comment">
                {linkify(p, onLink, i + ':')}
            </span>
        ) : (
            <span key={i}>{linkify(p, onLink, i + ':')}</span>
        ),
    );
}

// Plain text; [[address]] or [[address|label]] become links.
function SiteBody({ text, onLink }) {
    const parts = String(text || '').split(/(\[\[[^\]]+\]\])/g);
    return (
        <p>
            {parts.map((p, i) => {
                const m = p.match(/^\[\[([^|\]]+)(?:\|([^\]]+))?\]\]$/);
                if (!m) return <span key={i}>{p}</span>;
                return (
                    <button key={i} className="nrc-link" onClick={() => onLink(m[1])}>
                        {m[2] || m[1]}
                    </button>
                );
            })}
        </p>
    );
}
