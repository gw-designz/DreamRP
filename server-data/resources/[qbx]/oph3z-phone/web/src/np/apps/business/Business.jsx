// Business: create a business, invite employees by phone number, post announcements, manage
// roles. Backed by server/app/business (all permissions checked there).
import { useEffect, useState } from 'react';
import { useDispatch } from 'react-redux';
import {
    faHouse,
    faBullhorn,
    faUser,
    faUsers,
    faGear,
    faEnvelope,
    faPlus,
    faBuilding,
    faPenToSquare,
    faXmark,
    faUserPlus,
} from '@fortawesome/free-solid-svg-icons';
import FaIcon from '../../FaIcon';
import { openDialog } from '../../../store/slices/dialogSlice';
import { pushToast } from '../../../store/slices/toastSlice';
import { NpApp, TabBar, SearchBox, Empty, Spinner, Sheet, Field, Btn, Msg, npCall, useNpFetch, useBack, mdy, ago } from '../../ui/kit';
import './business.css';

const TABS = [
    { id: 'home', icon: faHouse, label: 'Home' },
    { id: 'posts', icon: faBullhorn, label: 'Announcements' },
    { id: 'profile', icon: faUser, label: 'Profile' },
    { id: 'staff', icon: faUsers, label: 'Employees' },
    { id: 'settings', icon: faGear, label: 'Settings' },
];
const ROLE = { owner: 'Owner', manager: 'Manager', employee: 'Employee' };
const ERR = {
    name: 'Names need at least 3 characters.',
    limit: 'You own the maximum number of businesses.',
    funds: 'You can’t afford the registration fee.',
    denied: 'You don’t have permission for that.',
    notfound: 'No phone found with that number.',
    member: 'They already work here.',
    full: 'This business is full.',
    owner: 'Owners can’t leave. Delete the business instead.',
    slow: 'Slow down a moment.',
};
const now = Math.floor(Date.now() / 1000);
const MOCK_LIST = {
    ok: true,
    me: 'Raptox Doe',
    invites: 1,
    businesses: [{ id: 1, code: 'burger_shot_24', name: 'Burger Shot 24', description: 'Burger Shot location', ownerName: 'Raptox Doe', members: 6, myRole: 'owner' }],
};
const MOCK_DETAIL = {
    ok: true,
    business: MOCK_LIST.businesses[0],
    me: { name: 'Raptox Doe', role: 'owner', hiredAt: now - 86400 * 3 },
    members: [
        { id: 'A', name: 'Raptox Doe', role: 'owner', hiredAt: now - 86400 * 3, isMe: true, number: '555-0142' },
        { id: 'B', name: 'Marta Lamb', role: 'manager', hiredAt: now - 86400, number: '555-0177' },
        { id: 'C', name: 'Tess Lane', role: 'employee', hiredAt: now - 3600, number: '555-0199' },
    ],
    posts: [{ id: 1, author: 'Raptox Doe', text: 'Staff meeting at 8 PM. Don’t be late.', ts: now - 1800 }],
    pending: [],
};

export default function Business() {
    const [tab, setTab] = useState('home');
    const [active, setActive] = useState(null);
    const [creating, setCreating] = useState(false);
    const [inbox, setInbox] = useState(false);
    const [list, reloadList] = useNpFetch('phone:np:biz:list', {}, MOCK_LIST);
    const [detail, reloadDetail, setDetail] = useNpFetch('phone:np:biz:get', active ? { id: active } : { id: 0 }, MOCK_DETAIL, [active]);

    useEffect(() => {
        if (!active && list && list.ok && list.businesses.length) setActive(list.businesses[0].id);
    }, [list, active]);

    useBack(() => {
        if (creating) return setCreating(false), true;
        if (tab !== 'home') return setTab('home'), true;
        return false;
    });

    const has = !!(active && detail && detail.ok);
    const refresh = () => {
        reloadList();
        reloadDetail();
    };

    let body;
    if (creating)
        body = (
            <CreateBusiness
                onClose={() => setCreating(false)}
                onCreated={(b) => {
                    setCreating(false);
                    setActive(b.id);
                    reloadList();
                }}
            />
        );
    else if (tab === 'home')
        body = <HomeTab list={list} active={active} onSelect={setActive} onCreate={() => setCreating(true)} onInbox={() => setInbox(true)} onRetry={reloadList} />;
    else if (!has) body = <NeedBusiness loading={active && detail === null} />;
    else if (tab === 'posts') body = <PostsTab detail={detail} onPosted={reloadDetail} />;
    else if (tab === 'profile') body = <ProfileTab detail={detail} />;
    else if (tab === 'staff') body = <StaffTab detail={detail} onChanged={refresh} />;
    else
        body = (
            <SettingsTab
                detail={detail}
                onChanged={refresh}
                onGone={() => {
                    setActive(null);
                    setDetail(null);
                    setTab('home');
                    reloadList();
                }}
            />
        );

    return (
        <NpApp theme="dark" className="nbz">
            <div className="nbz-stage">{body}</div>
            <TabBar variant="bubble" tabs={TABS} active={creating ? 'home' : tab} onChange={(t) => (setCreating(false), setTab(t))} keys={!creating} />
            {inbox && (
                <Invites
                    onClose={() => setInbox(false)}
                    onJoined={(id) => {
                        setInbox(false);
                        setActive(id);
                        reloadList();
                    }}
                />
            )}
        </NpApp>
    );
}

function NeedBusiness({ loading }) {
    return loading ? <Spinner /> : <Empty icon={faBuilding} title="Pick a business first" body="Open the Home tab and select or create one." />;
}

function HomeTab({ list, active, onSelect, onCreate, onInbox, onRetry }) {
    const [q, setQ] = useState('');
    if (list === null) return <Spinner />;
    if (!list.ok) return <Empty title="Couldn’t load businesses" action="Retry" onAction={onRetry} />;
    const n = q.trim().toLowerCase();
    const items = list.businesses.filter((b) => !n || `${b.name} ${b.code} ${b.description}`.toLowerCase().includes(n));
    return (
        <div className="nbz-page">
            <div className="nbz-search">
                <SearchBox value={q} onChange={setQ} placeholder="Search something..." />
                <button className="nbz-sq" onClick={onInbox} aria-label="Invites">
                    <FaIcon icon={faEnvelope} />
                    {list.invites > 0 && <i>{list.invites}</i>}
                </button>
                <button className="nbz-sq nbz-sq--blue" onClick={onCreate} aria-label="Create business">
                    <FaIcon icon={faPlus} />
                </button>
            </div>
            <div className="nbz-scroll">
                {items.length === 0 ? (
                    <Empty icon={faBuilding} title={n ? 'No matches' : 'You’re not part of a business'} body={n ? null : 'Create one with + or accept an invite.'} />
                ) : (
                    items.map((b) => (
                        <button key={b.id} className={`nbz-card${active === b.id ? ' is-on' : ''}`} onClick={() => onSelect(b.id)}>
                            <span className="nbz-card__top">
                                <span className="nbz-card__ico">
                                    <FaIcon icon={faBuilding} />
                                </span>
                                <span className="nbz-card__main">
                                    <b>{b.name}</b>
                                    <span>{b.description}</span>
                                    <em>Code: {b.code}</em>
                                </span>
                            </span>
                            <span className="nbz-card__foot">
                                <span>
                                    <FaIcon icon={faUser} /> {b.ownerName}
                                </span>
                                <span>
                                    <FaIcon icon={faUsers} /> {b.members} Employee{b.members === 1 ? '' : 's'}
                                </span>
                            </span>
                        </button>
                    ))
                )}
            </div>
        </div>
    );
}

function CreateBusiness({ onClose, onCreated }) {
    const [name, setName] = useState('');
    const [desc, setDesc] = useState('');
    const [busy, setBusy] = useState(false);
    const [err, setErr] = useState('');
    const submit = async () => {
        setBusy(true);
        setErr('');
        const r = await npCall('phone:np:biz:create', { name, description: desc }, { ok: true, business: { id: 2, name } });
        setBusy(false);
        if (r.ok) onCreated(r.business);
        else setErr(ERR[r.reason] || 'Could not create the business.');
    };
    return (
        <div className="nbz-create">
            <div className="nbz-create__head">
                <div>
                    <b>Create Business</b>
                    <span>Create a New Business</span>
                </div>
                <button className="npk-round npk-round--sm" onClick={onClose} aria-label="Close">
                    <FaIcon icon={faXmark} />
                </button>
            </div>
            <div className="nbz-create__body">
                <Field label="Business Name" counter max={30} value={name} onChange={setName} placeholder="Name" autoFocus />
                <Field label="Business Description" counter max={42} value={desc} onChange={setDesc} placeholder="Description" area className="nbz-desc" />
                <Msg>{err}</Msg>
            </div>
            <div className="nbz-create__foot">
                <Btn className="npk-btn--block" busy={busy} disabled={name.trim().length < 3} onClick={submit}>
                    Create Business
                </Btn>
                <Btn kind="ghost" className="npk-btn--block" onClick={onClose}>
                    Cancel
                </Btn>
            </div>
        </div>
    );
}

function Invites({ onClose, onJoined }) {
    const [data, reload] = useNpFetch('phone:np:biz:invites', {}, { ok: true, invites: [{ id: 3, name: 'Bean Machine', description: 'Coffee', code: 'bean_machine', ts: now - 300 }] });
    const respond = async (id, accept) => {
        const r = await npCall('phone:np:biz:respond', { id, accept }, { ok: true });
        if (r.ok && accept) onJoined(id);
        else reload();
    };
    return (
        <Sheet title="Invites" sub="Businesses that want to hire you" onClose={onClose}>
            {data === null ? (
                <Spinner />
            ) : !data.ok || data.invites.length === 0 ? (
                <Empty title="No pending invites" />
            ) : (
                <div className="npk-list">
                    {data.invites.map((i) => (
                        <div key={i.id} className="npk-row">
                            <span className="npk-row__ico">
                                <FaIcon icon={faBuilding} />
                            </span>
                            <span className="npk-row__main">
                                <span className="npk-row__title">{i.name}</span>
                                <span className="npk-row__sub">{i.description || i.code}</span>
                            </span>
                            <Btn className="npk-btn--sm" onClick={() => respond(i.id, true)}>
                                Join
                            </Btn>
                            <Btn kind="muted" className="npk-btn--sm" onClick={() => respond(i.id, false)}>
                                Decline
                            </Btn>
                        </div>
                    ))}
                </div>
            )}
        </Sheet>
    );
}

function PostsTab({ detail, onPosted }) {
    const canPost = detail.me.role === 'owner' || detail.me.role === 'manager';
    const [text, setText] = useState('');
    const [busy, setBusy] = useState(false);
    const [err, setErr] = useState('');
    const post = async () => {
        setBusy(true);
        const r = await npCall('phone:np:biz:post', { id: detail.business.id, text }, { ok: true });
        setBusy(false);
        if (r.ok) {
            setText('');
            setErr('');
            onPosted();
        } else setErr(ERR[r.reason] || 'Could not post.');
    };
    return (
        <div className="nbz-page">
            <div className="nbz-title">Announcements</div>
            <div className="nbz-scroll">
                {canPost && (
                    <div className="nbz-compose">
                        <Field area max={400} value={text} onChange={setText} placeholder={`Message everyone at ${detail.business.name}…`} />
                        <Msg>{err}</Msg>
                        <Btn className="npk-btn--sm" busy={busy} disabled={!text.trim()} onClick={post}>
                            Post
                        </Btn>
                    </div>
                )}
                {detail.posts.length === 0 ? (
                    <Empty icon={faBullhorn} title="No announcements yet" />
                ) : (
                    detail.posts.map((p) => (
                        <div key={p.id} className="nbz-post">
                            <div className="nbz-post__meta">
                                <b>{p.author}</b> · {ago(p.ts)}
                            </div>
                            <div className="nbz-post__text">{p.text}</div>
                        </div>
                    ))
                )}
            </div>
        </div>
    );
}

function ProfileTab({ detail }) {
    return (
        <div className="nbz-page">
            <div className="nbz-title nbz-title--row">
                <span>Profile</span>
            </div>
            <div className="nbz-scroll">
                <div className="nbz-me">
                    <span className="nbz-me__ico">
                        <FaIcon icon={faUser} />
                    </span>
                    <span>
                        <b>{detail.me.name}</b>
                        <em>{ROLE[detail.me.role]}</em>
                    </span>
                </div>
                <div className="nbz-infohead">Information about Employee</div>
                <div className="nbz-info">
                    <span>Employee Role</span>
                    <b>{ROLE[detail.me.role]}</b>
                </div>
                <div className="nbz-info">
                    <span>Hired Date</span>
                    <b>{mdy(detail.me.hiredAt)}</b>
                </div>
                <div className="nbz-info">
                    <span>Business</span>
                    <b>{detail.business.name}</b>
                </div>
            </div>
        </div>
    );
}

function StaffTab({ detail, onChanged }) {
    const dispatch = useDispatch();
    const myRole = detail.me.role;
    const canInvite = myRole === 'owner' || myRole === 'manager';
    const [inviting, setInviting] = useState(false);
    const [manage, setManage] = useState(null);

    const act = async (endpoint, payload, okMsg) => {
        const r = await npCall(endpoint, { id: detail.business.id, ...payload }, { ok: true });
        dispatch(pushToast({ title: 'Business', body: r.ok ? okMsg : ERR[r.reason] || 'That didn’t work.' }));
        if (r.ok) {
            setManage(null);
            onChanged();
        }
    };
    const fire = async (m) => {
        const ok = await dispatch(
            openDialog({
                title: `Remove ${m.name}?`,
                message: 'They lose access to this business.',
                buttons: [
                    { text: 'Cancel', style: 'cancel', value: false },
                    { text: 'Remove', style: 'destructive', value: true },
                ],
            }),
        );
        if (ok) act('phone:np:biz:fire', { cid: m.id }, `${m.name} was removed.`);
    };

    return (
        <div className="nbz-page">
            <div className="nbz-title nbz-title--row">
                <span>Employees</span>
                {canInvite && (
                    <button className="nbz-sq nbz-sq--blue" onClick={() => setInviting(true)} aria-label="Invite">
                        <FaIcon icon={faUserPlus} />
                    </button>
                )}
            </div>
            <div className="nbz-scroll">
                {detail.members.map((m) => {
                    const canManage = !m.isMe && m.role !== 'owner' && (myRole === 'owner' || (myRole === 'manager' && m.role === 'employee'));
                    return (
                        <button key={m.id} className="nbz-member" onClick={() => canManage && setManage(m)} disabled={!canManage}>
                            <span className="nbz-me__ico">
                                <FaIcon icon={faUser} />
                            </span>
                            <span className="npk-row__main">
                                <span className="npk-row__title">
                                    {m.name}
                                    {m.isMe ? ' (you)' : ''}
                                </span>
                                <span className="npk-row__sub">
                                    {m.number} · since {mdy(m.hiredAt)}
                                </span>
                            </span>
                            <span className={`npk-pill nbz-role nbz-role--${m.role}`}>{ROLE[m.role]}</span>
                        </button>
                    );
                })}
                {detail.pending.length > 0 && <div className="npk-section">Pending invites</div>}
                {detail.pending.map((p) => (
                    <div key={p.cid} className="nbz-member">
                        <span className="npk-row__main">
                            <span className="npk-row__title">{p.name || 'Invited'}</span>
                            <span className="npk-row__sub">Invited {ago(p.ts)}</span>
                        </span>
                        {canInvite && (
                            <Btn kind="muted" className="npk-btn--sm" onClick={() => act('phone:np:biz:cancelInvite', { cid: p.cid }, 'Invite cancelled.')}>
                                Cancel
                            </Btn>
                        )}
                    </div>
                ))}
            </div>
            {inviting && <InviteSheet bid={detail.business.id} onClose={() => setInviting(false)} onDone={onChanged} />}
            {manage && (
                <Sheet title={manage.name} sub={ROLE[manage.role]} onClose={() => setManage(null)}>
                    {myRole === 'owner' && (
                        <Btn
                            kind="muted"
                            className="npk-btn--block"
                            onClick={() =>
                                act(
                                    'phone:np:biz:role',
                                    { cid: manage.id, role: manage.role === 'manager' ? 'employee' : 'manager' },
                                    manage.role === 'manager' ? 'Demoted to employee.' : 'Promoted to manager.',
                                )
                            }
                        >
                            {manage.role === 'manager' ? 'Make Employee' : 'Make Manager'}
                        </Btn>
                    )}
                    <Btn kind="danger" className="npk-btn--block" onClick={() => fire(manage)}>
                        Remove from business
                    </Btn>
                </Sheet>
            )}
        </div>
    );
}

function InviteSheet({ bid, onClose, onDone }) {
    const [number, setNumber] = useState('');
    const [busy, setBusy] = useState(false);
    const [err, setErr] = useState('');
    const send = async () => {
        setBusy(true);
        const r = await npCall('phone:np:biz:invite', { id: bid, number }, { ok: true });
        setBusy(false);
        if (r.ok) {
            onDone();
            onClose();
        } else setErr(ERR[r.reason] || 'Could not send the invite.');
    };
    return (
        <Sheet title="Invite Employee" sub="They’ll get a notification to accept" onClose={onClose}>
            <Field label="Phone number" value={number} max={24} onChange={setNumber} autoFocus onEnter={send} />
            <Msg>{err}</Msg>
            <Btn className="npk-btn--block" busy={busy} disabled={!number.replace(/\D/g, '')} onClick={send}>
                Send Invite
            </Btn>
        </Sheet>
    );
}

function SettingsTab({ detail, onChanged, onGone }) {
    const dispatch = useDispatch();
    const isOwner = detail.me.role === 'owner';
    const [editing, setEditing] = useState(false);
    const confirmThen = async (title, message, label, endpoint) => {
        const ok = await dispatch(
            openDialog({
                title,
                message,
                buttons: [
                    { text: 'Cancel', style: 'cancel', value: false },
                    { text: label, style: 'destructive', value: true },
                ],
            }),
        );
        if (!ok) return;
        const r = await npCall(endpoint, { id: detail.business.id }, { ok: true });
        if (r.ok) onGone();
        else dispatch(pushToast({ title: 'Business', body: ERR[r.reason] || 'That didn’t work.' }));
    };
    return (
        <div className="nbz-page">
            <div className="nbz-title nbz-title--row">
                <span>Settings</span>
                {isOwner && (
                    <button className="nbz-sq nbz-sq--blue" onClick={() => setEditing(true)} aria-label="Edit">
                        <FaIcon icon={faPenToSquare} />
                    </button>
                )}
            </div>
            <div className="nbz-scroll">
                <div className="nbz-code">
                    <span>Business Code</span>
                    <b>{detail.business.code}</b>
                </div>
                {isOwner ? (
                    <button className="nbz-danger" onClick={() => confirmThen(`Delete ${detail.business.name}?`, 'Everyone loses access. This can’t be undone.', 'Delete', 'phone:np:biz:delete')}>
                        Delete Business
                    </button>
                ) : (
                    <button className="nbz-danger" onClick={() => confirmThen(`Leave ${detail.business.name}?`, 'You’ll need a new invite to rejoin.', 'Leave', 'phone:np:biz:leave')}>
                        Leave Business
                    </button>
                )}
            </div>
            {editing && <EditSheet detail={detail} onClose={() => setEditing(false)} onSaved={onChanged} />}
        </div>
    );
}

function EditSheet({ detail, onClose, onSaved }) {
    const [name, setName] = useState(detail.business.name);
    const [desc, setDesc] = useState(detail.business.description);
    const [err, setErr] = useState('');
    const save = async () => {
        const r = await npCall('phone:np:biz:edit', { id: detail.business.id, name, description: desc }, { ok: true });
        if (r.ok) {
            onSaved();
            onClose();
        } else setErr(ERR[r.reason] || 'Could not save.');
    };
    return (
        <Sheet title="Edit Business" onClose={onClose}>
            <Field label="Business Name" counter max={30} value={name} onChange={setName} />
            <Field label="Business Description" counter max={42} value={desc} onChange={setDesc} area />
            <Msg>{err}</Msg>
            <Btn className="npk-btn--block" disabled={name.trim().length < 3} onClick={save}>
                Save
            </Btn>
        </Sheet>
    );
}
