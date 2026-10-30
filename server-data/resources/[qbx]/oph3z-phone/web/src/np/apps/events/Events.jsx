// Events (server/app/events): Home = scheduled events, Voting = proposals, My Events.
import { useEffect, useState } from 'react';
import { useDispatch, useSelector } from 'react-redux';
import { faHouse, faSquarePollVertical, faListUl, faClock, faClockRotateLeft, faUserGroup, faCalendarDays, faPlus, faLocationDot, faTrash } from '@fortawesome/free-solid-svg-icons';
import FaIcon from '../../FaIcon';
import { pushToast } from '../../../store/slices/toastSlice';
import { openDialog } from '../../../store/slices/dialogSlice';
import { NpApp, TabBar, Body, Spinner, Empty, Splash, useSplash, Sheet, Field, Btn, Msg, Chips, npCall, useNpFetch, useBack, useStatusTone, hm } from '../../ui/kit';
import './events.css';

const TABS = [
    { id: 'home', icon: faHouse, label: 'Home' },
    { id: 'voting', icon: faSquarePollVertical, label: 'Voting' },
    { id: 'mine', icon: faListUl, label: 'My Events' },
];
const HEAD = {
    home: ['Available Events', 'Discover and vote for exciting events that are happening around you!'],
    voting: ['Vote on Events', 'Proposed events go live once enough people vote for them.'],
    mine: ['My Events', 'Events you created or joined.'],
};
const ERR = { title: 'Give the event a name.', time: 'Pick when it starts.', limit: 'You already have the maximum number of upcoming events.', slow: 'Wait a bit before creating another event.', full: 'This event is full.', closed: 'This event is no longer open.', own: 'You can’t vote for your own event.', denied: 'Only event hosts can create events.' };
const now = Math.floor(Date.now() / 1000);
const MOCK = {
    ok: true,
    isHost: false,
    events: [{ id: 1, title: 'Racing Event', description: 'Racing Event starting soon at Chiliad Wilderness.', location: 'Chiliad Wilderness', startsAt: now + 660, status: 'scheduled', participants: 0, votes: 5, votesNeeded: 5, joined: false, hasLocation: true }],
};

function timeLeft(ts, nowTs) {
    const s = ts - nowTs;
    if (s <= 0) return 'Ended';
    if (s < 3600) return `${Math.ceil(s / 60)}m`;
    if (s < 86400) return `${Math.floor(s / 3600)}h ${Math.floor((s % 3600) / 60)}m`;
    return `${Math.floor(s / 86400)}d`;
}

export default function Events() {
    const dispatch = useDispatch();
    const [splash] = useSplash(1000);
    const [tab, setTab] = useState('home');
    const [open, setOpen] = useState(null);
    const [creating, setCreating] = useState(false);
    const [clock, setClock] = useState(Math.floor(Date.now() / 1000));
    const [data, reload] = useNpFetch('phone:np:ev:list', { tab }, MOCK);
    useStatusTone(splash ? 'light' : 'dark');
    useBack(() => (open ? (setOpen(null), true) : creating ? (setCreating(false), true) : false));

    useEffect(() => {
        const t = setInterval(() => setClock(Math.floor(Date.now() / 1000)), 30000);
        return () => clearInterval(t);
    }, []);

    if (splash)
        return (
            <NpApp theme="light" className="nev">
                <Splash bg="linear-gradient(180deg, #7de3df 0%, #6a7cf0 45%, #5b2cf5 100%)" icon={faCalendarDays} title="JOIN EVENTS" tagline="Discover events and connect with others" className="nev-splash" />
            </NpApp>
        );

    const act = async (endpoint, payload, okMsg) => {
        const r = await npCall(endpoint, payload, { ok: true });
        if (r.ok) {
            if (okMsg) dispatch(pushToast({ title: 'Events', body: okMsg }));
            reload();
            setOpen(null);
        } else dispatch(pushToast({ title: 'Events', body: ERR[r.reason] || 'That didn’t work.' }));
    };

    const [title, sub] = HEAD[tab];
    return (
        <NpApp theme="light" className="nev">
            <div className="nev-head">
                <div className="nev-head__row">
                    <h1>{title}</h1>
                    <button className="nev-add" onClick={() => setCreating(true)} aria-label="Create event">
                        <FaIcon icon={faPlus} />
                    </button>
                </div>
                <p>{sub}</p>
            </div>
            <Body>
                {data === null ? (
                    <Spinner />
                ) : !data.ok ? (
                    <Empty title="Couldn’t load events" action="Retry" onAction={reload} />
                ) : data.events.length === 0 ? (
                    <Empty icon={faCalendarDays} title={tab === 'voting' ? 'Nothing to vote on' : tab === 'mine' ? 'You haven’t joined any events' : 'No events scheduled'} body="Create one with +." />
                ) : (
                    data.events.map((e) => (
                        <div key={e.id} className="nev-card">
                            <div className="nev-card__top">
                                <span>
                                    <b>{e.title}</b>
                                    <em>{e.description || e.location}</em>
                                </span>
                                <button className="nev-btn" onClick={() => setOpen(e)}>
                                    {e.status === 'voting' ? 'Vote' : 'Event'}
                                </button>
                            </div>
                            <div className="nev-card__stats">
                                <span>
                                    <FaIcon icon={faClock} />
                                    <span>
                                        <small>Schedule Time</small>
                                        <b className="is-purple">{hm(e.startsAt)}</b>
                                    </span>
                                </span>
                                <span>
                                    <FaIcon icon={faClockRotateLeft} />
                                    <span>
                                        <small>Time Left</small>
                                        <b className="is-orange">{timeLeft(e.startsAt, clock)}</b>
                                    </span>
                                </span>
                                <span>
                                    <FaIcon icon={e.status === 'voting' ? faSquarePollVertical : faUserGroup} />
                                    <span>
                                        <small>{e.status === 'voting' ? 'Votes' : 'Participants'}</small>
                                        <b>{e.status === 'voting' ? `${e.votes}/${e.votesNeeded}` : String(e.participants).padStart(2, '0')}</b>
                                    </span>
                                </span>
                            </div>
                        </div>
                    ))
                )}
            </Body>
            <TabBar variant="label" tabs={TABS} active={tab} onChange={setTab} className="nev-tabs" />
            {open && (
                <Sheet title={open.title} sub={`${open.location || 'Location set by host'} · ${hm(open.startsAt)}`} onClose={() => setOpen(null)}>
                    {open.description && <p className="nev-desc">{open.description}</p>}
                    <div className="nev-actions">
                        {open.status === 'voting' ? (
                            <Btn disabled={open.voted || open.mine} onClick={() => act('phone:np:ev:vote', { id: open.id }, 'Vote counted.')}>
                                {open.voted ? 'Voted' : 'Vote for this event'}
                            </Btn>
                        ) : (
                            <Btn kind={open.joined ? 'muted' : 'primary'} onClick={() => act('phone:np:ev:join', { id: open.id, on: !open.joined }, open.joined ? 'You left the event.' : 'You’re in!')}>
                                {open.joined ? 'Leave' : 'Join'}
                            </Btn>
                        )}
                        {open.hasLocation && (
                            <Btn kind="muted" onClick={() => act('phone:np:ev:locate', { id: open.id }, 'Waypoint set.')}>
                                <FaIcon icon={faLocationDot} /> Waypoint
                            </Btn>
                        )}
                        {open.mine && (
                            <Btn
                                kind="danger"
                                onClick={async () => {
                                    const ok = await dispatch(
                                        openDialog({
                                            title: 'Cancel this event?',
                                            buttons: [
                                                { text: 'Keep', style: 'cancel', value: false },
                                                { text: 'Cancel event', style: 'destructive', value: true },
                                            ],
                                        }),
                                    );
                                    if (ok) act('phone:np:ev:delete', { id: open.id }, 'Event cancelled.');
                                }}
                            >
                                <FaIcon icon={faTrash} />
                            </Btn>
                        )}
                    </div>
                </Sheet>
            )}
            {creating && <CreateEvent isHost={data && data.isHost} onClose={() => setCreating(false)} onDone={() => (setCreating(false), reload())} />}
        </NpApp>
    );
}

const WHEN = [
    { id: '15', label: 'In 15 min' },
    { id: '30', label: 'In 30 min' },
    { id: '60', label: 'In 1 hour' },
    { id: '120', label: 'In 2 hours' },
    { id: '1440', label: 'Tomorrow' },
];

function CreateEvent({ isHost, onClose, onDone }) {
    const zone = useSelector((s) => s.phone.zone);
    const [title, setTitle] = useState('');
    const [desc, setDesc] = useState('');
    const [location, setLocation] = useState(zone || '');
    const [when, setWhen] = useState('30');
    const [busy, setBusy] = useState(false);
    const [err, setErr] = useState('');
    const save = async () => {
        setBusy(true);
        const r = await npCall('phone:np:ev:create', { title, description: desc, location, startsIn: Number(when) }, { ok: true });
        setBusy(false);
        if (r.ok) onDone();
        else setErr(ERR[r.reason] || 'Could not create the event.');
    };
    return (
        <Sheet title="Create Event" sub={isHost ? 'It goes live right away.' : 'It goes live once enough people vote for it.'} onClose={onClose}>
            <Field label="Name" value={title} max={60} onChange={setTitle} autoFocus />
            <Field label="Description" value={desc} max={400} area onChange={setDesc} />
            <Field label="Location (your current position is used for the waypoint)" value={location} max={64} onChange={setLocation} />
            <Chips items={WHEN} value={when} onChange={setWhen} className="nev-when" />
            <Msg>{err}</Msg>
            <Btn className="npk-btn--block" busy={busy} disabled={title.trim().length < 3} onClick={save}>
                {isHost ? 'Create Event' : 'Propose Event'}
            </Btn>
        </Sheet>
    );
}
