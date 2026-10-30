// Scoot-E: rent an electric scooter (server/app/misc charges and times the rental, the client
// spawns / removes the vehicle).
import { useEffect, useState } from 'react';
import { useDispatch } from 'react-redux';
import { faLocationDot, faStopwatch, faBolt } from '@fortawesome/free-solid-svg-icons';
import FaIcon from '../../FaIcon';
import { useNuiEvent } from '../../../hooks/useNuiEvent';
import { pushToast } from '../../../store/slices/toastSlice';
import { NpApp, Spinner, Empty, Msg, npCall, useNpFetch, money } from '../../ui/kit';
import './scoote.css';

const ERR = { funds: 'Not enough money in your bank.', active: 'You already have a scooter.', slow: 'One moment…', model: 'No scooter available right now.' };

const ScooterArt = () => (
    <svg viewBox="0 0 100 100" className="nsc-art">
        <g fill="none" stroke="currentColor" strokeWidth="6" strokeLinecap="round">
            <path d="M60 14h16" />
            <path d="M69 15L78 68" />
            <path d="M28 72h46" />
        </g>
        <circle cx="24" cy="74" r="10" fill="none" stroke="currentColor" strokeWidth="6" />
        <circle cx="80" cy="74" r="10" fill="none" stroke="currentColor" strokeWidth="6" />
    </svg>
);

export default function ScootE() {
    const dispatch = useDispatch();
    const [data, reload, setData] = useNpFetch('phone:np:scoot:state', {}, { ok: true, price: 50, minutes: 30, active: null });
    const [busy, setBusy] = useState(false);
    const [err, setErr] = useState('');
    const [now, setNow] = useState(Date.now() / 1000);
    const [offset, setOffset] = useState(0);

    useEffect(() => {
        const t = setInterval(() => setNow(Date.now() / 1000), 1000);
        return () => clearInterval(t);
    }, []);
    useEffect(() => {
        if (data && data.ok && data.active) setOffset(data.active.now - Date.now() / 1000);
    }, [data]);
    useNuiEvent('phone:np:scootEnd', () => setData((d) => ({ ...d, active: null })));

    if (data === null) return <NpApp className="nsc"><Spinner /></NpApp>;
    if (!data.ok) return <NpApp className="nsc"><Empty title="Scoot-E is unavailable" action="Retry" onAction={reload} /></NpApp>;

    const left = data.active ? Math.max(0, Math.floor(data.active.expires - (now + offset))) : 0;
    const rent = async () => {
        setBusy(true);
        setErr('');
        const r = await npCall('phone:np:scoot:rent', {}, { ok: true, expires: Date.now() / 1000 + data.minutes * 60, now: Date.now() / 1000 });
        setBusy(false);
        if (r.ok) {
            setData((d) => ({ ...d, active: { expires: r.expires, now: r.now } }));
            dispatch(pushToast({ title: 'Scoot-E', body: 'Enjoy your ride!' }));
        } else setErr(ERR[r.reason] || 'Couldn’t rent a scooter.');
    };
    const end = async () => {
        await npCall('phone:np:scoot:end', {}, { ok: true });
        setData((d) => ({ ...d, active: null }));
    };

    return (
        <NpApp className="nsc">
            <div className="nsc-hero">
                <ScooterArt />
                <h1>Scoot-E</h1>
                <p>Electric scooters, anywhere in the city.</p>
            </div>
            <div className="nsc-body">
                {data.active ? (
                    <>
                        <div className="nsc-card">
                            <FaIcon icon={faStopwatch} />
                            <span>
                                <em>Time left</em>
                                <b>
                                    {Math.floor(left / 60)}:{String(left % 60).padStart(2, '0')}
                                </b>
                            </span>
                        </div>
                        <button className="nsc-btn nsc-btn--ghost" onClick={() => npCall('phone:np:scoot:locate', {}, { ok: true }).then((r) => dispatch(pushToast({ title: 'Scoot-E', body: r.ok ? 'Waypoint set to your scooter.' : 'Your scooter is gone.' })))}>
                            <FaIcon icon={faLocationDot} /> Locate Scooter
                        </button>
                        <button className="nsc-btn nsc-btn--dark" onClick={end}>
                            End Ride
                        </button>
                    </>
                ) : (
                    <>
                        <div className="nsc-card">
                            <FaIcon icon={faBolt} />
                            <span>
                                <em>{data.minutes} minute ride</em>
                                <b>{money(data.price)}</b>
                            </span>
                        </div>
                        <p className="nsc-note">The scooter appears next to you and is removed when the time runs out or you end the ride.</p>
                        <Msg>{err}</Msg>
                        <button className="nsc-btn nsc-btn--dark" disabled={busy} onClick={rent}>
                            {busy ? 'Unlocking…' : 'Rent a Scoot-E'}
                        </button>
                    </>
                )}
            </div>
        </NpApp>
    );
}
