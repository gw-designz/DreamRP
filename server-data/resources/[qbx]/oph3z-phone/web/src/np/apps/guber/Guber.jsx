// Guber: ride hailing between players (server/app/guber). Pick Customer or Driver on the splash.
import { useEffect, useState } from 'react';
import { useDispatch } from 'react-redux';
import { faCarSide, faHouse, faUser, faRightFromBracket, faLocationDot, faStar, faCar, faCalendar, faQuoteLeft, faCircleDot, faFlagCheckered } from '@fortawesome/free-solid-svg-icons';
import FaIcon from '../../FaIcon';
import { useNuiEvent } from '../../../hooks/useNuiEvent';
import { pushToast } from '../../../store/slices/toastSlice';
import { NpApp, Spinner, Empty, Sheet, Field, Btn, Msg, npCall, useNpFetch, useBack, useStatusTone, money, ago } from '../../ui/kit';
import NpMap from '../../ui/NpMap';
import './guber.css';

const ERR = {
    busy: 'You already have an active ride.',
    funds: 'Not enough money in your bank for this ride.',
    nodrivers: 'No drivers are online right now.',
    dest: 'Pick a destination.',
    nowaypoint: 'Set a waypoint on your map first.',
    close: 'That destination is too close.',
    slow: 'One moment…',
    far: 'You need to be closer.',
    taken: 'Another driver already took this ride.',
    offline: 'Go online first.',
    inride: 'Finish the current ride first.',
    job: 'Only licensed drivers can drive for Guber.',
    own: 'You can’t accept your own ride.',
};
const ENDED = {
    timeout: 'No driver accepted your ride.',
    driver_cancelled: 'Your driver cancelled.',
    customer_cancelled: 'The customer cancelled the ride.',
    customer_left: 'The customer left the city.',
    driver_left: 'Your driver left the city.',
};
const MOCK_STATE = {
    ok: true,
    name: 'qweqeqe qwewqeq',
    canDrive: true,
    online: false,
    rating: 5,
    destinations: [
        { index: 1, label: 'Mission Row Police Department', miles: 0.92, fare: 114.12, x: 441, y: -982 },
        { index: 2, label: 'Pillbox Hill Medical Center', miles: 0.67, fare: 89.91, x: 298, y: -584 },
        { index: 3, label: 'Legion Square', miles: 0.89, fare: 111.19, x: 195, y: -934 },
        { index: 4, label: 'Los Santos International Airport', miles: 2.18, fare: 235.55, x: -1037, y: -2737 },
    ],
};

export default function Guber() {
    const dispatch = useDispatch();
    const [role, setRole] = useState(null);
    const [page, setPage] = useState('home');
    const [state, reload, setState] = useNpFetch('phone:np:guber:state', {}, MOCK_STATE);
    const [offer, setOffer] = useState(null);
    const [rate, setRate] = useState(null);
    useStatusTone(!role || (role === 'driver' && page === 'profile') ? 'light' : 'dark');
    useBack(() => (page !== 'home' ? (setPage('home'), true) : role ? (setRole(null), true) : false));

    // resume an active ride on open
    useEffect(() => {
        if (state && state.ok && !role) {
            if (state.ride) setRole(state.ride.role);
            else if (state.online) setRole('driver');
        }
        if (state && state.ok && state.offer) {
            setOffer((o) => o || { ...state.offer, until: Date.now() + Math.max(5, (state.offer.expiresAt || 0) - Date.now() / 1000) * 1000 });
        }
        // eslint-disable-next-line react-hooks/exhaustive-deps
    }, [state]);

    useNuiEvent('phone:np:guber', (p) => {
        if (!p) return;
        if (p.type === 'offer') setOffer({ ...p.ride, until: Date.now() + Math.max(5, (p.ride.expiresAt || 0) - Date.now() / 1000) * 1000 });
        else if (p.type === 'offerGone') setOffer((o) => (o && o.id === p.id ? null : o));
        else if (p.type === 'update') setState((s) => ({ ...s, ride: p.ride }));
        else if (p.type === 'ended') {
            setState((s) => ({ ...s, ride: null }));
            if (ENDED[p.reason]) dispatch(pushToast({ title: 'Guber', body: ENDED[p.reason] }));
        } else if (p.type === 'completed') {
            setState((s) => ({ ...s, ride: null }));
            if (p.paid) setRate({ rideId: p.rideId, driver: p.driver, fare: p.fare });
            else dispatch(pushToast({ title: 'Guber', body: 'The ride ended but your payment failed.' }));
        }
    });

    if (state === null) return <NpApp className="ngb"><Spinner /></NpApp>;
    if (!state.ok) return <NpApp className="ngb"><Empty title="Guber is unavailable" action="Retry" onAction={reload} /></NpApp>;

    if (!role)
        return (
            <NpApp className="ngb">
                <div className="ngb-splash">
                    <div className="ngb-splash__grid" />
                    <FaIcon icon={faCarSide} className="ngb-splash__car" />
                    <h1>GUBER</h1>
                    <p>You Ride in Los Santos</p>
                    <button className="ngb-role ngb-role--solid" onClick={() => setRole('customer')}>
                        Customer
                    </button>
                    <button className="ngb-role" onClick={() => setRole('driver')} disabled={!state.canDrive} title={state.canDrive ? '' : ERR.job}>
                        Driver
                    </button>
                </div>
            </NpApp>
        );

    const dark = role === 'driver' && page === 'profile';
    return (
        <NpApp theme={dark ? 'dark' : 'light'} className={`ngb ngb--${role}`}>
            <div className="ngb-top">
                <button className={page === 'home' ? 'is-on' : ''} onClick={() => setPage('home')}>
                    <FaIcon icon={faHouse} /> Home
                </button>
                <button className={page === 'profile' ? 'is-on' : ''} onClick={() => setPage('profile')}>
                    <FaIcon icon={faUser} /> Profile
                </button>
                {role === 'driver' && <OnlineToggle state={state} setState={setState} />}
                <button className="ngb-top__exit" onClick={() => setRole(null)} aria-label="Switch role">
                    <FaIcon icon={faRightFromBracket} />
                </button>
            </div>
            {page === 'profile' ? (
                <Profile role={role} />
            ) : role === 'customer' ? (
                <CustomerHome state={state} setState={setState} />
            ) : (
                <DriverHome state={state} setState={setState} offer={offer} setOffer={setOffer} />
            )}
            {rate && <RateSheet info={rate} onClose={() => setRate(null)} />}
        </NpApp>
    );
}

function OnlineToggle({ state, setState }) {
    const dispatch = useDispatch();
    const toggle = async () => {
        const r = await npCall('phone:np:guber:online', { on: !state.online }, { ok: true, online: !state.online, session: { since: Date.now() / 1000, earned: 0, rides: 0, now: Date.now() / 1000 } });
        if (r.ok) setState((s) => ({ ...s, online: r.online, session: r.session }));
        else dispatch(pushToast({ title: 'Guber', body: ERR[r.reason] || 'Couldn’t change status.' }));
    };
    return (
        <button className={`ngb-online${state.online ? ' is-on' : ''}`} onClick={toggle}>
            <span /> {state.online ? 'Online' : 'Offline'}
        </button>
    );
}

function CustomerHome({ state, setState }) {
    const [sel, setSel] = useState(null);
    const [busy, setBusy] = useState(false);
    const [err, setErr] = useState('');
    const ride = state.ride;

    const request = async (opts) => {
        setBusy(true);
        setErr('');
        const r = await npCall('phone:np:guber:request', opts, { ok: true, ride: { id: 1, state: 'requested', fare: 114.12, dropoff: { label: 'Mission Row' }, pickup: { label: 'Vinewood Hills' } } });
        setBusy(false);
        if (r.ok) setState((s) => ({ ...s, ride: r.ride }));
        else setErr(ERR[r.reason] || 'Couldn’t request a ride.');
    };
    const cancel = async () => {
        const r = await npCall('phone:np:guber:cancel', {}, { ok: true });
        if (r.ok) setState((s) => ({ ...s, ride: null }));
        else setErr(ERR[r.reason] || 'Couldn’t cancel.');
    };

    const markers = ride
        ? [
              { ...ride.pickup, kind: 'pickup' },
              { ...ride.dropoff, kind: 'dropoff' },
          ]
        : sel
          ? [{ ...state.destinations.find((d) => d.index === sel), kind: 'dropoff' }]
          : [];

    return (
        <div className="ngb-mapwrap">
            <NpMap markers={markers} />
            <div className="ngb-panel">
                {ride ? (
                    <>
                        <div className="ngb-panel__head">
                            {ride.state === 'requested' ? 'Looking for a driver…' : ride.state === 'accepted' ? `${ride.driver} is on the way` : `Heading to ${ride.dropoff.label}`}
                        </div>
                        <div className="ngb-route">
                            <Stop icon={faCircleDot} cls="pickup" label={ride.pickup.label} sub="Pickup" />
                            <Stop icon={faLocationDot} cls="dropoff" label={ride.dropoff.label} sub="Dropoff" />
                        </div>
                        <div className="ngb-fare">
                            Fare <b>{money(ride.fare, true)}</b>
                        </div>
                        <Msg>{err}</Msg>
                        {ride.state !== 'pickedup' && (
                            <button className="ngb-cancel" onClick={cancel}>
                                Cancel Ride
                            </button>
                        )}
                    </>
                ) : (
                    <>
                        <div className="ngb-panel__head">Where to?</div>
                        <div className="ngb-dests">
                            {state.destinations.map((d) => (
                                <button key={d.index} className={`ngb-dest${sel === d.index ? ' is-on' : ''}`} onClick={() => setSel(d.index)}>
                                    <span className="ngb-dest__ico">
                                        <FaIcon icon={faLocationDot} />
                                    </span>
                                    <span className="ngb-dest__main">
                                        <b>{d.label}</b>
                                        <em>{d.miles} mi</em>
                                    </span>
                                    <span className="ngb-dest__fare">{money(d.fare, true)}</span>
                                </button>
                            ))}
                            <button className="ngb-dest" onClick={() => request({ waypoint: true })}>
                                <span className="ngb-dest__ico ngb-dest__ico--wp">
                                    <FaIcon icon={faFlagCheckered} />
                                </span>
                                <span className="ngb-dest__main">
                                    <b>My GPS waypoint</b>
                                    <em>Fare calculated on request</em>
                                </span>
                            </button>
                        </div>
                        <Msg>{err}</Msg>
                        <button className="ngb-request" disabled={!sel || busy} onClick={() => request({ index: sel })}>
                            {busy ? 'Requesting…' : 'Request Ride'}
                        </button>
                    </>
                )}
            </div>
        </div>
    );
}

function Stop({ icon, cls, label, sub }) {
    return (
        <div className="ngb-stop">
            <span className={`ngb-stop__ico ngb-stop__ico--${cls}`}>
                <FaIcon icon={icon} />
            </span>
            <span>
                <b>{label}</b>
                <em>{sub}</em>
            </span>
        </div>
    );
}

function DriverHome({ state, setState, offer, setOffer }) {
    const dispatch = useDispatch();
    const [now, setNow] = useState(Date.now());
    const [busy, setBusy] = useState(false);
    useEffect(() => {
        const t = setInterval(() => setNow(Date.now()), 1000);
        return () => clearInterval(t);
    }, []);
    useEffect(() => {
        if (offer && offer.until < now) setOffer(null);
    }, [now, offer, setOffer]);

    const ride = state.ride;
    const s = state.session;
    const call = async (endpoint, payload, okMsg) => {
        setBusy(true);
        const r = await npCall(endpoint, payload || {}, { ok: true, ride: offer, session: s });
        setBusy(false);
        if (!r.ok) return dispatch(pushToast({ title: 'Guber', body: ERR[r.reason] || 'That didn’t work.' }));
        if (okMsg) dispatch(pushToast({ title: 'Guber', body: okMsg }));
        return r;
    };

    const accept = async () => {
        const r = await call('phone:np:guber:accept', { id: offer.id }, 'Ride accepted. Waypoint set to pickup.');
        setOffer(null);
        if (r) setState((st) => ({ ...st, ride: r.ride }));
    };
    const decline = () => {
        npCall('phone:np:guber:decline', { id: offer.id }, { ok: true });
        setOffer(null);
    };

    const markers = ride ? [{ ...ride.pickup, kind: 'pickup' }, { ...ride.dropoff, kind: 'dropoff' }] : offer ? [{ ...offer.pickup, kind: 'pickup' }, { ...offer.dropoff, kind: 'dropoff' }] : [];
    const online = state.online;
    const mins = s ? Math.max(0, Math.floor((now / 1000 - s.since) / 60)) : 0;

    return (
        <div className="ngb-mapwrap">
            <NpMap markers={markers} />
            {online && s && (
                <div className="ngb-session">
                    <em>Current Session</em>
                    <b>{money(s.earned, true)}</b>
                    <span>{s.rides} rides completed</span>
                    <span>
                        Online for {mins} min{mins === 1 ? '' : 's'}
                    </span>
                </div>
            )}
            {!online && !ride && <div className="ngb-hint">Go online to start receiving ride requests.</div>}
            {offer && !ride && (
                <div className="ngb-panel">
                    <div className="ngb-panel__head">Incoming Ride Request ({Math.max(0, Math.ceil((offer.until - now) / 1000))}s)</div>
                    <div className="ngb-offer">
                        <b>{money(offer.fare, true)}</b>
                        <span>
                            <FaIcon icon={faLocationDot} /> {offer.miles} mi
                        </span>
                    </div>
                    <div className="ngb-route">
                        <Stop icon={faCircleDot} cls="pickup" label={offer.pickup.label} sub="Pickup" />
                        <Stop icon={faLocationDot} cls="dropoff" label={offer.dropoff.label} sub="Dropoff" />
                    </div>
                    <button className="ngb-request" disabled={busy} onClick={accept}>
                        Accept
                    </button>
                    <button className="ngb-decline" onClick={decline}>
                        Decline
                    </button>
                </div>
            )}
            {ride && (
                <div className="ngb-panel">
                    <div className="ngb-panel__head">{ride.state === 'accepted' ? `Pick up ${ride.customer}` : `Drop off ${ride.customer}`}</div>
                    <div className="ngb-route">
                        <Stop icon={faCircleDot} cls="pickup" label={ride.pickup.label} sub="Pickup" />
                        <Stop icon={faLocationDot} cls="dropoff" label={ride.dropoff.label} sub="Dropoff" />
                    </div>
                    <div className="ngb-fare">
                        Fare <b>{money(ride.fare, true)}</b>
                    </div>
                    {ride.state === 'accepted' ? (
                        <button
                            className="ngb-request"
                            disabled={busy}
                            onClick={async () => {
                                const r = await call('phone:np:guber:pickup', {}, 'Customer picked up. Waypoint set to drop-off.');
                                if (r) setState((st) => ({ ...st, ride: r.ride }));
                            }}
                        >
                            Customer Picked Up
                        </button>
                    ) : (
                        <button
                            className="ngb-request"
                            disabled={busy}
                            onClick={async () => {
                                const r = await call('phone:np:guber:complete', {}, null);
                                if (r) {
                                    dispatch(pushToast({ title: 'Guber', body: r.paid ? `Earned ${money(r.earned)}.` : 'Ride completed, but the customer couldn’t pay.' }));
                                    setState((st) => ({ ...st, ride: null, session: r.session || st.session }));
                                }
                            }}
                        >
                            Complete Ride
                        </button>
                    )}
                    {ride.state === 'accepted' && (
                        <button
                            className="ngb-decline"
                            onClick={async () => {
                                const r = await call('phone:np:guber:cancel', {}, 'Ride cancelled.');
                                if (r) setState((st) => ({ ...st, ride: null }));
                            }}
                        >
                            Cancel Ride
                        </button>
                    )}
                </div>
            )}
        </div>
    );
}

function Profile({ role }) {
    const [tab, setTab] = useState('overview');
    const [data] = useNpFetch('phone:np:guber:profile', { role }, {
        ok: true,
        name: 'qweqeqe qwewqeq',
        rating: 5,
        rides: 2,
        joinedAt: Date.now() / 1000 - 86400 * 20,
        history: [],
        feedback: [
            { name: 'Marta Lamb', stars: 5, comment: 'Clean car, smooth driver, on time. What more could you ask?', ts: Date.now() / 1000 - 3600 },
            { name: 'Marta Lamb', stars: 5, comment: 'Smooth ride, got me there without a scratch. Five stars.', ts: Date.now() / 1000 - 7200 },
        ],
    });
    if (data === null) return <Spinner />;
    if (!data.ok) return <Empty title="Couldn’t load your profile" />;
    const joined = data.joinedAt ? new Date(data.joinedAt * 1000).toLocaleDateString(undefined, { month: 'long', year: 'numeric' }) : '—';
    return (
        <div className={`ngb-profile ngb-profile--${role}`}>
            <div className="ngb-profile__me">
                <span className="ngb-profile__av">
                    <FaIcon icon={faUser} />
                </span>
                <span>
                    <b>{data.name}</b>
                    {role === 'driver' && (
                        <em>
                            <FaIcon icon={faStar} /> {data.rating ? data.rating.toFixed(2) : 'New'}
                        </em>
                    )}
                </span>
            </div>
            <div className="ngb-seg">
                <button className={tab === 'overview' ? 'is-on' : ''} onClick={() => setTab('overview')}>
                    Overview
                </button>
                <button className={tab === 'history' ? 'is-on' : ''} onClick={() => setTab('history')}>
                    History
                </button>
            </div>
            <div className="ngb-profile__body">
                {tab === 'overview' ? (
                    <>
                        {role === 'driver' && (
                            <div className="ngb-stats">
                                <Stat icon={faStar} k="Rating" v={data.rating ? data.rating.toFixed(2) : '—'} />
                                <Stat icon={faCar} k="Total Rides" v={data.rides} />
                                <Stat icon={faCalendar} k="Joined" v={joined} wide />
                            </div>
                        )}
                        {role === 'driver' ? (
                            <>
                                <div className="ngb-label">CUSTOMER FEEDBACK</div>
                                {data.feedback.length === 0 && <Empty title="No feedback yet" />}
                                {data.feedback.map((f, i) => (
                                    <div key={i} className="ngb-feedback">
                                        <p>
                                            <FaIcon icon={faQuoteLeft} /> {f.comment || 'No comment.'}
                                        </p>
                                        <div>
                                            <span>
                                                <FaIcon icon={faUser} /> <b>{f.name}</b> <em>{ago(f.ts)}</em>
                                            </span>
                                            <span className="ngb-stars">
                                                <FaIcon icon={faStar} /> {f.stars}
                                            </span>
                                        </div>
                                    </div>
                                ))}
                            </>
                        ) : (
                            <Empty icon={faCarSide} title="Ride with Guber" body="Your trips show up under History." />
                        )}
                    </>
                ) : data.history.length === 0 ? (
                    <Empty title="No rides yet" />
                ) : (
                    data.history.map((h) => (
                        <div key={h.id} className="ngb-hist">
                            <span>
                                <b>
                                    {h.pickup} → {h.dropoff}
                                </b>
                                <em>
                                    {h.name} · {ago(h.ts)}
                                </em>
                            </span>
                            <b>{money(h.fare)}</b>
                        </div>
                    ))
                )}
            </div>
        </div>
    );
}

function Stat({ icon, k, v, wide }) {
    return (
        <div className={`ngb-stat${wide ? ' is-wide' : ''}`}>
            <span className="ngb-stat__ico">
                <FaIcon icon={icon} />
            </span>
            <span>
                <em>{k}</em>
                <b>{v}</b>
            </span>
        </div>
    );
}

function RateSheet({ info, onClose }) {
    const [stars, setStars] = useState(5);
    const [comment, setComment] = useState('');
    const [err, setErr] = useState('');
    const send = async () => {
        const r = await npCall('phone:np:guber:rate', { rideId: info.rideId, stars, comment }, { ok: true });
        if (r.ok) onClose();
        else setErr('Couldn’t send your rating.');
    };
    return (
        <Sheet title={`Rate ${info.driver}`} sub={`You paid ${money(info.fare)}`} onClose={onClose}>
            <div className="ngb-rate">
                {[1, 2, 3, 4, 5].map((n) => (
                    <button key={n} className={n <= stars ? 'is-on' : ''} onClick={() => setStars(n)} aria-label={`${n} stars`}>
                        <FaIcon icon={faStar} />
                    </button>
                ))}
            </div>
            <Field value={comment} max={160} area placeholder="Say something about your ride (optional)" onChange={setComment} />
            <Msg>{err}</Msg>
            <Btn className="npk-btn--block" onClick={send}>
                Send Rating
            </Btn>
        </Sheet>
    );
}
