// Garage: the player's owned vehicles from the framework (server/app/nopixel).
// Track = waypoint to the car if it is out in the world; Keys = give keys to the nearest player;
// Take Out = hands off to your garage resource (Config.Garage.TakeOutEvent) when configured.
import { useState } from 'react';
import { useDispatch } from 'react-redux';
import { faCar, faLocationDot, faKey, faShareNodes } from '@fortawesome/free-solid-svg-icons';
import FaIcon from '../../FaIcon';
import { pushToast } from '../../../store/slices/toastSlice';
import { NpApp, Panel, BigHeader, Body, Loaded, Empty, Bar, npCall, useNpFetch, useNpConfig } from '../../ui/kit';
import './garage.css';

const MOCK = {
    ok: true,
    vehicles: [
        { plate: 'LPJZRS1R', label: 'Karin Sultan', garage: 'pillboxgarage', state: 'garaged', fuel: 86, engine: 100, body: 94 },
        { plate: 'LPUK7NG9', label: 'Karin Kuruma', garage: 'pillboxgarage', state: 'out', fuel: 52, engine: 88, body: 71 },
        { plate: 'LPF79JRT', label: 'Truffade Adder', garage: 'motelgarage', state: 'impound', fuel: 12, engine: 40, body: 33 },
    ],
};
const STATE = { garaged: ['Garaged', ''], out: ['Out', 'npk-pill--ok'], impound: ['Impounded', 'npk-pill--bad'] };
const MSG = {
    notfound: 'Couldn’t find that vehicle in the city.',
    noplayer: 'Nobody is close enough.',
    owner: 'That isn’t your vehicle.',
    failed: 'That didn’t work. Try again.',
    unsupported: 'Not available on this server.',
};

export default function Garage() {
    const dispatch = useDispatch();
    const [data, reload] = useNpFetch('phone:np:garage', {}, MOCK);
    const cfg = useNpConfig('garage', { takeOut: false, keys: true }) || {};
    const [open, setOpen] = useState(null);
    const [busy, setBusy] = useState(null);

    const act = async (kind, v) => {
        setBusy(kind + v.plate);
        const r = await npCall(`phone:np:garage:${kind}`, { plate: v.plate }, { ok: true });
        setBusy(null);
        const ok = { track: 'Waypoint set to your vehicle.', keys: `Gave keys to ${r.name || 'the nearest player'}.`, takeout: 'Request sent to the garage.' };
        dispatch(pushToast({ title: 'Garage', body: r.ok ? ok[kind] : MSG[r.reason] || MSG.failed }));
        if (r.ok && kind === 'takeout') reload();
    };

    return (
        <NpApp theme="dark" className="ngr">
            <Panel>
                <BigHeader title="Garage" sub="Manage your vehicles" />
                <Body>
                    <Loaded data={data} onRetry={reload}>
                        {(d) =>
                            d.vehicles.length === 0 ? (
                                <Empty icon={faCar} title="You don’t own any vehicles" />
                            ) : (
                                <div className="npk-list">
                                    {d.vehicles.map((v) => {
                                        const [label, cls] = STATE[v.state] || [v.state, ''];
                                        const isOpen = open === v.plate;
                                        return (
                                            <div key={v.plate} className={`ngr-car${isOpen ? ' is-open' : ''}`}>
                                                <button className="ngr-car__head" onClick={() => setOpen(isOpen ? null : v.plate)}>
                                                    <span className="ngr-car__ico">
                                                        <FaIcon icon={faCar} />
                                                    </span>
                                                    <span className="npk-row__main">
                                                        <span className="ngr-car__name">{v.label}</span>
                                                        <span className="ngr-car__sub">
                                                            {v.plate}
                                                            {v.garage ? ` · ${v.garage}` : ''}
                                                        </span>
                                                    </span>
                                                    <span className={`npk-pill ${cls}`}>{label}</span>
                                                </button>
                                                {isOpen && (
                                                    <div className="ngr-car__body">
                                                        <div className="ngr-bars">
                                                            <Bar label="Fuel" value={v.fuel} color="#3dd68c" />
                                                            <Bar label="Engine" value={v.engine} color="#4a8fe0" />
                                                            <Bar label="Body" value={v.body} color="#f5c542" />
                                                        </div>
                                                        <div className="ngr-actions">
                                                            <button disabled={busy === 'track' + v.plate} onClick={() => act('track', v)}>
                                                                <FaIcon icon={faLocationDot} /> Track
                                                            </button>
                                                            <button
                                                                disabled={!cfg.takeOut || v.state !== 'garaged' || busy === 'takeout' + v.plate}
                                                                title={cfg.takeOut ? '' : 'Retrieve it at a garage'}
                                                                onClick={() => act('takeout', v)}
                                                            >
                                                                <FaIcon icon={faKey} /> Take Out
                                                            </button>
                                                            <button disabled={!cfg.keys || busy === 'keys' + v.plate} onClick={() => act('keys', v)}>
                                                                <FaIcon icon={faShareNodes} /> Keys
                                                            </button>
                                                        </div>
                                                    </div>
                                                )}
                                            </div>
                                        );
                                    })}
                                </div>
                            )
                        }
                    </Loaded>
                </Body>
            </Panel>
        </NpApp>
    );
}
