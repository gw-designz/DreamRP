// Government: state / local notices and ballots (server/app/government). Q / E switch region.
import { useState } from 'react';
import { useDispatch } from 'react-redux';
import { faUser, faBook, faSquarePollVertical, faScaleBalanced, faBullhorn, faSackDollar, faChevronRight, faPlus, faTrash, faCircleCheck } from '@fortawesome/free-solid-svg-icons';
import FaIcon from '../../FaIcon';
import { openDialog } from '../../../store/slices/dialogSlice';
import { NpApp, TopBar, Body, Spinner, Empty, Sheet, Field, Btn, Msg, Keycap, npCall, useNpFetch, useTabKeys, useBack, mdy } from '../../ui/kit';
import './government.css';

const STATE = [
    { id: 'legislation', icon: faBook, title: 'State Legislation', sub: 'View the current state legislation notices and what they mean for you.' },
    { id: 'ballots', icon: faSquarePollVertical, title: 'State Ballots & Voting', sub: 'View previous, current, and upcoming state ballots and make your voice heard.' },
    { id: 'docket', icon: faScaleBalanced, title: 'State Court Docket', sub: 'View previous and upcoming state court cases and see the judicial system in action.' },
];
const LOCAL = (r) => [
    { id: 'announcements', icon: faBullhorn, title: `${r} Announcements`, sub: 'View announcements straight from the local mayoral office in the region.' },
    { id: 'budget', icon: faSackDollar, title: `${r} Budget Rates`, sub: 'View the current budget rates for the region and see where local tax dollars go.' },
];
const MOCK_HOME = {
    ok: true,
    name: 'qweqeqe qwewqeq',
    canEdit: true,
    regions: [
        { id: 'ls', label: 'Los Santos' },
        { id: 'blaine', label: 'Blaine County' },
    ],
};

export default function Government() {
    const [home] = useNpFetch('phone:np:gov:home', {}, MOCK_HOME);
    const [region, setRegion] = useState(null);
    const [section, setSection] = useState(null);
    const regions = (home && home.ok && home.regions) || [];
    const reg = region || (regions[0] && regions[0].id);
    const regLabel = (regions.find((r) => r.id === reg) || {}).label || '';

    useTabKeys(
        regions.map((r) => r.id),
        reg,
        (id) => {
            setRegion(id);
            setSection(null);
        },
        !section,
    );
    useBack(() => (section ? (setSection(null), true) : false));

    if (home === null) return <NpApp theme="light" className="ngv"><Spinner /></NpApp>;
    if (!home.ok) return <NpApp theme="light" className="ngv"><Empty title="Couldn’t reach the government portal" /></NpApp>;

    if (section) {
        const meta = [...STATE, ...LOCAL(regLabel)].find((s) => s.id === section);
        return (
            <NpApp theme="light" className="ngv">
                <Section meta={meta} region={reg} canEdit={home.canEdit} onBack={() => setSection(null)} />
            </NpApp>
        );
    }

    return (
        <NpApp theme="light" className="ngv">
            <Body className="ngv-home">
                <div className="ngv-welcome">
                    <span className="ngv-avatar">
                        <FaIcon icon={faUser} />
                    </span>
                    <span>
                        <em>Welcome Back,</em>
                        <b>{home.name}</b>
                    </span>
                </div>
                <div className="ngv-intro">
                    <em>Government</em>
                    <b>State and Local Government Information</b>
                </div>
                <div className="ngv-group">STATE</div>
                {STATE.map((s) => (
                    <Item key={s.id} s={s} onClick={() => setSection(s.id)} />
                ))}
                <div className="ngv-group">LOCAL</div>
                {LOCAL(regLabel).map((s) => (
                    <Item key={s.id} s={s} onClick={() => setSection(s.id)} />
                ))}
            </Body>
            <nav className="ngv-regions">
                <Keycap k="Q" />
                {regions.map((r) => (
                    <button key={r.id} className={r.id === reg ? 'is-on' : ''} onClick={() => setRegion(r.id)}>
                        {r.label}
                    </button>
                ))}
                <Keycap k="E" />
            </nav>
        </NpApp>
    );
}

function Item({ s, onClick }) {
    return (
        <button className="ngv-item" onClick={onClick}>
            <span className="ngv-item__ico">
                <FaIcon icon={s.icon} />
            </span>
            <span className="ngv-item__main">
                <b>{s.title}</b>
                <em>{s.sub}</em>
            </span>
            <FaIcon icon={faChevronRight} className="ngv-item__chev" />
        </button>
    );
}

function Section({ meta, region, canEdit, onBack }) {
    const dispatch = useDispatch();
    const isBallots = meta.id === 'ballots';
    const [data, reload] = useNpFetch(
        'phone:np:gov:list',
        { section: meta.id, region },
        isBallots
            ? { ok: true, ballots: [{ id: 1, title: 'Prop 12: Highway speed limits', description: 'Raise the highway limit to 80 mph?', options: ['Yes', 'No'], open: true, closesAt: Date.now() / 1000 + 86400 }] }
            : { ok: true, posts: [] },
    );
    const [composing, setComposing] = useState(false);

    const vote = async (b, i) => {
        const r = await npCall('phone:np:gov:vote', { id: b.id, choice: i + 1 }, { ok: true });
        if (r.ok) reload();
    };
    const remove = async (id) => {
        const ok = await dispatch(
            openDialog({
                title: 'Remove this entry?',
                buttons: [
                    { text: 'Cancel', style: 'cancel', value: false },
                    { text: 'Remove', style: 'destructive', value: true },
                ],
            }),
        );
        if (!ok) return;
        await npCall('phone:np:gov:delete', { id, ballot: isBallots }, { ok: true });
        reload();
    };

    return (
        <>
            <TopBar
                title={meta.title}
                onBack={onBack}
                right={
                    canEdit && (
                        <button className="npk-round" onClick={() => setComposing(true)} aria-label="Publish">
                            <FaIcon icon={faPlus} />
                        </button>
                    )
                }
            />
            <Body>
                {data === null ? (
                    <Spinner />
                ) : !data.ok ? (
                    <Empty title="Couldn’t load" action="Retry" onAction={reload} />
                ) : isBallots ? (
                    data.ballots.length === 0 ? (
                        <Empty icon={meta.icon} title="No ballots right now" />
                    ) : (
                        data.ballots.map((b) => {
                            const total = b.tallies ? b.tallies.reduce((a, n) => a + n, 0) : 0;
                            return (
                                <div key={b.id} className="ngv-card">
                                    <div className="ngv-card__head">
                                        <b>{b.title}</b>
                                        <span className={`npk-pill ${b.open ? 'npk-pill--ok' : 'npk-pill--mute'}`}>{b.open ? `Open until ${mdy(b.closesAt)}` : 'Closed'}</span>
                                    </div>
                                    {b.description && <p>{b.description}</p>}
                                    <div className="ngv-options">
                                        {b.options.map((o, i) => {
                                            const n = b.tallies ? b.tallies[i] || 0 : null;
                                            const pct = total ? Math.round((n / total) * 100) : 0;
                                            return (
                                                <button key={i} className={`ngv-opt${b.myVote === i + 1 ? ' is-mine' : ''}`} disabled={!b.open || !!b.myVote} onClick={() => vote(b, i)}>
                                                    {n !== null && <span className="ngv-opt__bar" style={{ width: `${pct}%` }} />}
                                                    <span className="ngv-opt__label">
                                                        {b.myVote === i + 1 && <FaIcon icon={faCircleCheck} />} {o}
                                                    </span>
                                                    {n !== null && <span className="ngv-opt__pct">{pct}%</span>}
                                                </button>
                                            );
                                        })}
                                    </div>
                                    {canEdit && (
                                        <button className="ngv-del" onClick={() => remove(b.id)}>
                                            <FaIcon icon={faTrash} /> Remove
                                        </button>
                                    )}
                                </div>
                            );
                        })
                    )
                ) : data.posts.length === 0 ? (
                    <Empty icon={meta.icon} title="Nothing published yet" />
                ) : (
                    data.posts.map((p) => (
                        <div key={p.id} className="ngv-card">
                            <div className="ngv-card__head">
                                <b>{p.title}</b>
                                <span className="ngv-date">{mdy(p.ts)}</span>
                            </div>
                            {p.body && <p>{p.body}</p>}
                            <div className="ngv-by">
                                {p.author}
                                {canEdit && (
                                    <button className="ngv-del" onClick={() => remove(p.id)}>
                                        <FaIcon icon={faTrash} />
                                    </button>
                                )}
                            </div>
                        </div>
                    ))
                )}
            </Body>
            {composing && (isBallots ? <BallotForm region={region} onClose={() => setComposing(false)} onDone={reload} /> : <PostForm meta={meta} region={region} onClose={() => setComposing(false)} onDone={reload} />)}
        </>
    );
}

function PostForm({ meta, region, onClose, onDone }) {
    const [title, setTitle] = useState('');
    const [body, setBody] = useState('');
    const [err, setErr] = useState('');
    const save = async () => {
        const r = await npCall('phone:np:gov:post', { section: meta.id, region, title, body }, { ok: true });
        if (r.ok) {
            onDone();
            onClose();
        } else setErr(r.reason === 'denied' ? 'You can’t publish here.' : 'Could not publish.');
    };
    return (
        <Sheet title={`Publish to ${meta.title}`} onClose={onClose}>
            <Field label="Title" value={title} max={80} onChange={setTitle} autoFocus />
            <Field label="Details" value={body} max={3000} area onChange={setBody} />
            <Msg>{err}</Msg>
            <Btn className="npk-btn--block" disabled={!title.trim()} onClick={save}>
                Publish
            </Btn>
        </Sheet>
    );
}

function BallotForm({ region, onClose, onDone }) {
    const [title, setTitle] = useState('');
    const [desc, setDesc] = useState('');
    const [opts, setOpts] = useState(['Yes', 'No']);
    const [days, setDays] = useState('3');
    const [scope, setScope] = useState('state');
    const [err, setErr] = useState('');
    const save = async () => {
        const r = await npCall('phone:np:gov:ballot', { region: scope === 'state' ? 'state' : region, title, description: desc, options: opts, days: Number(days) || 3 }, { ok: true });
        if (r.ok) {
            onDone();
            onClose();
        } else setErr(r.reason === 'options' ? 'Add a title and at least two options.' : 'Could not open the ballot.');
    };
    return (
        <Sheet title="Open a Ballot" onClose={onClose}>
            <Field label="Question" value={title} max={80} onChange={setTitle} autoFocus />
            <Field label="Description" value={desc} max={1000} area onChange={setDesc} />
            {opts.map((o, i) => (
                <Field key={i} label={`Option ${i + 1}`} value={o} max={60} onChange={(v) => setOpts((l) => l.map((x, j) => (j === i ? v : x)))} />
            ))}
            {opts.length < 6 && (
                <Btn kind="muted" className="npk-btn--sm" onClick={() => setOpts((l) => [...l, ''])}>
                    Add option
                </Btn>
            )}
            <Field label="Open for (days)" value={days} max={2} onChange={(v) => setDays(v.replace(/\D/g, ''))} />
            <div className="ngv-scope">
                <button className={scope === 'state' ? 'is-on' : ''} onClick={() => setScope('state')}>
                    State-wide
                </button>
                <button className={scope === 'local' ? 'is-on' : ''} onClick={() => setScope('local')}>
                    This region
                </button>
            </div>
            <Msg>{err}</Msg>
            <Btn className="npk-btn--block" onClick={save}>
                Open Ballot
            </Btn>
        </Sheet>
    );
}
