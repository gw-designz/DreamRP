// Socials: Join screen, Menu page, muted / blocked account lists and ownership transfer.
import { useEffect, useState } from 'react';
import { useDispatch, useSelector } from 'react-redux';
import { faBookmark, faVolumeXmark, faBan, faRightLeft, faRightFromBracket, faChevronRight, faPen } from '@fortawesome/free-solid-svg-icons';
import FaIcon from '../../np/FaIcon';
import { fetchNui } from '../../utils/fetchNui';
import { setSession, doLogout, setMe } from '../../store/slices/xSlice';
import { openDialog } from '../../store/slices/dialogSlice';
import { pushToast } from '../../store/slices/toastSlice';
import { SHeader, BackButton, Loading, StateMsg } from './parts';
import { SAvatar } from './PostCard';
import { SocialsLogo } from './parts';

const JOIN_ERR = {
    handle: 'Usernames are 3–15 letters, numbers or _.',
    taken: 'That username is taken.',
    slow: 'Slow down a moment.',
    already: 'You already have an account.',
};

export function JoinScreen() {
    const dispatch = useDispatch();
    const previous = useSelector((s) => s.x.previous) || [];
    const [handle, setHandle] = useState('');
    const [name, setName] = useState('');
    const [busy, setBusy] = useState(false);
    const [err, setErr] = useState('');
    const clean = handle.replace(/^@/, '');
    const valid = /^[A-Za-z0-9_]{3,15}$/.test(clean);

    const create = async () => {
        if (!valid || busy) return;
        setBusy(true);
        setErr('');
        const r = await fetchNui('phone:x:join', { handle: clean, name: name.trim() }, { ok: true, me: { id: 9, handle: clean, name: name || clean } });
        setBusy(false);
        if (r && r.ok) dispatch(setSession({ me: r.me }));
        else setErr(JOIN_ERR[r && r.reason] || 'Could not create your account.');
    };

    const resume = async (acc) => {
        setBusy(true);
        const r = await fetchNui('phone:x:resume', { id: acc.id }, { ok: true, me: acc });
        setBusy(false);
        if (r && r.ok) dispatch(setSession({ me: r.me }));
        else setErr('Could not sign in to that account.');
    };

    return (
        <div className="sc-app sc-join">
            <SocialsLogo size="2.2em" />
            <h2 className="sc-join__title">Hey, Join Us</h2>
            <p className="sc-join__sub">Pick a username to get started.</p>
            <label className="sc-join__field">
                <span>Username</span>
                <input value={handle} maxLength={16} placeholder="Enter username" onChange={(e) => setHandle(e.target.value)} onKeyDown={(e) => e.key === 'Enter' && create()} />
            </label>
            <label className="sc-join__field">
                <span>Display name</span>
                <input value={name} maxLength={40} placeholder="Enter name (optional)" onChange={(e) => setName(e.target.value)} onKeyDown={(e) => e.key === 'Enter' && create()} />
            </label>
            {err && <div className="sc-compose__err">{err}</div>}
            <button className="sc-join__btn" disabled={!valid || busy} onClick={create}>
                {busy ? 'Creating…' : 'Create'}
            </button>
            {previous.length > 0 && (
                <div className="sc-join__prev">
                    <span>Your previous accounts</span>
                    {previous.map((a) => (
                        <button key={a.id} className="sc-row" onClick={() => resume(a)} disabled={busy}>
                            <SAvatar account={a} />
                            <span className="sc-row__text">
                                <b>Continue as {a.name}</b>
                                <small>@{a.handle}</small>
                            </span>
                        </button>
                    ))}
                </div>
            )}
        </div>
    );
}

function MenuItem({ icon, label, onClick, danger }) {
    return (
        <button className={`sc-mitem${danger ? ' is-danger' : ''}`} onClick={onClick}>
            <FaIcon icon={icon} />
            <span>{label}</span>
            <FaIcon icon={faChevronRight} className="sc-mitem__chev" />
        </button>
    );
}

export function MenuView({ me, onBack, onOpen }) {
    const dispatch = useDispatch();
    const [transfer, setTransfer] = useState(false);

    const signOut = async () => {
        const ok = await dispatch(
            openDialog({
                title: 'Sign out?',
                message: 'You can sign back in from the Join screen on this character.',
                buttons: [
                    { text: 'Cancel', style: 'cancel', value: false },
                    { text: 'Sign out', style: 'destructive', value: true },
                ],
            }),
        );
        if (ok) {
            await dispatch(doLogout());
            dispatch(setSession({ me: null, previous: [me] }));
        }
    };

    return (
        <div className="sc-screen">
            <SHeader left={<BackButton onClick={onBack} />} title="Menu" />
            <div className="sc-scroll sc-menu">
                <button className="sc-menu__me" onClick={() => onOpen({ name: 'edit' })}>
                    <SAvatar account={me} />
                    <span className="sc-row__text">
                        <b>{me.name}</b>
                        <small>@{me.handle}</small>
                    </span>
                    <FaIcon icon={faPen} />
                </button>
                <div className="sc-section">Library</div>
                <MenuItem icon={faBookmark} label="Bookmarks" onClick={() => onOpen({ name: 'bookmarks' })} />
                <MenuItem icon={faVolumeXmark} label="Muted accounts" onClick={() => onOpen({ name: 'relations', type: 'mutes' })} />
                <MenuItem icon={faBan} label="Blocked accounts" onClick={() => onOpen({ name: 'relations', type: 'blocks' })} />
                <div className="sc-section">Session</div>
                <MenuItem icon={faRightLeft} label="Transfer ownership" onClick={() => setTransfer(true)} />
                <MenuItem icon={faRightFromBracket} label="Sign out" danger onClick={signOut} />
            </div>
            {transfer && <TransferSheet me={me} onClose={() => setTransfer(false)} />}
        </div>
    );
}

const TRANSFER_ERR = {
    notfound: 'No phone found with that number.',
    self: 'That’s your own number.',
    hasaccount: 'That person already has a Socials account.',
};

function TransferSheet({ me, onClose }) {
    const dispatch = useDispatch();
    const [number, setNumber] = useState('');
    const [busy, setBusy] = useState(false);
    const [err, setErr] = useState('');
    const submit = async () => {
        const ok = await dispatch(
            openDialog({
                title: `Transfer @${me.handle}?`,
                message: 'The new owner gets full control and you will be signed out.',
                buttons: [
                    { text: 'Cancel', style: 'cancel', value: false },
                    { text: 'Transfer', style: 'destructive', value: true },
                ],
            }),
        );
        if (!ok) return;
        setBusy(true);
        const r = await fetchNui('phone:x:transfer', { number }, { ok: true });
        setBusy(false);
        if (r && r.ok) {
            dispatch(pushToast({ title: 'Socials', body: `@${me.handle} was transferred.` }));
            dispatch(setMe(null));
            dispatch(setSession({ me: null, previous: [] }));
        } else setErr(TRANSFER_ERR[r && r.reason] || 'Transfer failed.');
    };
    return (
        <div className="sc-drawer" onClick={onClose}>
            <div className="sc-sheet" onClick={(e) => e.stopPropagation()}>
                <b>Transfer ownership</b>
                <p>Give @{me.handle} to another player. Enter their phone number.</p>
                <input className="sc-sheet__input" value={number} placeholder="Phone number" onChange={(e) => setNumber(e.target.value)} autoFocus />
                {err && <div className="sc-compose__err">{err}</div>}
                <div className="sc-sheet__btns">
                    <button className="sc-pillbtn sc-pillbtn--ghost" onClick={onClose}>
                        Cancel
                    </button>
                    <button className="sc-pillbtn" disabled={busy || !number.replace(/\D/g, '')} onClick={submit}>
                        {busy ? 'Transferring…' : 'Transfer'}
                    </button>
                </div>
            </div>
        </div>
    );
}

export function RelationsView({ type, onBack, onChanged }) {
    const [items, setItems] = useState(null);
    useEffect(() => {
        fetchNui('phone:x:relations', { type }, { ok: true, accounts: [] }).then((r) => setItems(r && r.ok ? r.accounts || [] : false));
    }, [type]);
    const undo = async (a) => {
        const r = await fetchNui(type === 'blocks' ? 'phone:x:block' : 'phone:x:mute', { id: a.id, on: false }, { ok: true });
        if (r && r.ok) {
            setItems((l) => l.filter((x) => x.id !== a.id));
            onChanged && onChanged();
        }
    };
    const title = type === 'blocks' ? 'Blocked accounts' : 'Muted accounts';
    return (
        <div className="sc-screen">
            <SHeader left={<BackButton onClick={onBack} />} title={title} />
            <div className="sc-scroll">
                {items === null && <Loading />}
                {items === false && <StateMsg title="Couldn’t load this list" />}
                {items && items.length === 0 && (
                    <StateMsg title={type === 'blocks' ? 'You haven’t blocked anyone' : 'You haven’t muted anyone'} body="You can do this from someone’s profile." />
                )}
                {items && items.length > 0 && (
                    <div className="sc-list">
                        {items.map((a) => (
                            <div key={a.id} className="sc-row">
                                <SAvatar account={a} />
                                <span className="sc-row__text">
                                    <b>{a.name}</b>
                                    <small>@{a.handle}</small>
                                </span>
                                <button className="sc-pillbtn sc-pillbtn--ghost" onClick={() => undo(a)}>
                                    {type === 'blocks' ? 'Unblock' : 'Unmute'}
                                </button>
                            </div>
                        ))}
                    </div>
                )}
            </div>
        </div>
    );
}
