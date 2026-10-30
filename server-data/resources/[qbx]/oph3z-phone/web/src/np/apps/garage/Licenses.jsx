// Licenses: the character's ID and licences from the framework (server/app/nopixel).
// "Show" displays the card to the nearest player (server picks them by distance).
import { useState } from 'react';
import { useDispatch } from 'react-redux';
import { faIdCard, faGun, faCrosshairs, faFish, faPlane, faBriefcase, faCar, faStar, faUser, faScroll } from '@fortawesome/free-solid-svg-icons';
import FaIcon from '../../FaIcon';
import { pushToast } from '../../../store/slices/toastSlice';
import { NpApp, Panel, BigHeader, Body, Loaded, npCall, useNpFetch } from '../../ui/kit';
import './garage.css';

const ICONS = { driver: faIdCard, weapon: faGun, hunting: faCrosshairs, fishing: faFish, pilot: faPlane, business: faBriefcase, bike: faCar };

const MOCK = {
    ok: true,
    person: { name: 'Raptox Doe', citizenid: 'ZPA72845', birthdate: '1994-03-12' },
    licenses: [
        { id: 'driver', label: 'Driver License', active: true },
        { id: 'weapon', label: 'Weapon License', active: true },
        { id: 'hunting', label: 'Hunting License', active: true },
        { id: 'fishing', label: 'Fishing License', active: true },
        { id: 'pilot', label: 'Pilot License', active: false },
        { id: 'business', label: 'Business License', active: false },
    ],
    applyAt: 'City Hall',
};

const MSG = { noplayer: 'Nobody is close enough to see it.', none: 'You don’t have that license.' };

export default function Licenses() {
    const dispatch = useDispatch();
    const [data, reload] = useNpFetch('phone:np:licenses', {}, MOCK);
    const [busy, setBusy] = useState(null);

    const show = async (id) => {
        setBusy(id);
        const r = await npCall('phone:np:licenses:show', { id }, { ok: true, name: 'Marta Lamb' });
        setBusy(null);
        dispatch(pushToast({ title: 'Licenses', body: r.ok ? `Shown to ${r.name || 'the nearest player'}.` : MSG[r.reason] || 'Couldn’t show it.' }));
    };

    return (
        <NpApp theme="dark" className="nlc">
            <Panel>
                <BigHeader title="Licenses" sub="Your ID and permits" />
                <Body>
                    <Loaded data={data} onRetry={reload}>
                        {(d) => (
                            <>
                                <div className="nlc-id">
                                    <div className="nlc-id__top">
                                        <span>STATE OF SAN ANDREAS</span>
                                        <button className="nlc-id__star" onClick={() => show('id')} title="Show ID to nearest player" disabled={busy === 'id'}>
                                            <FaIcon icon={faStar} />
                                        </button>
                                    </div>
                                    <div className="nlc-id__row">
                                        <span className="nlc-id__photo">{d.person.photo ? <img src={d.person.photo} alt="" /> : <FaIcon icon={faUser} />}</span>
                                        <div className="nlc-id__fields">
                                            <div className="nlc-id__f nlc-id__f--wide">
                                                <span>Name</span>
                                                <b>{d.person.name || '—'}</b>
                                            </div>
                                            <div className="nlc-id__f">
                                                <span>State ID</span>
                                                <b>{d.person.citizenid || '—'}</b>
                                            </div>
                                            <div className="nlc-id__f">
                                                <span>DOB</span>
                                                <b>{d.person.birthdate || '—'}</b>
                                            </div>
                                        </div>
                                    </div>
                                </div>
                                <div className="npk-list" style={{ marginTop: '0.55em' }}>
                                    {d.licenses.map((l) => (
                                        <div key={l.id} className={`nlc-row${l.active ? '' : ' is-off'}`}>
                                            <span className="nlc-row__ico">
                                                <FaIcon icon={ICONS[l.id] || faScroll} />
                                            </span>
                                            <span className="npk-row__main">
                                                <span className="nlc-row__title">{l.label}</span>
                                                <span className="nlc-row__sub" style={{ display: 'block' }}>
                                                    {l.active ? 'Valid · Issued' : `Not issued — apply at ${d.applyAt || 'City Hall'}`}
                                                </span>
                                            </span>
                                            <button className="nlc-show" disabled={!l.active || busy === l.id} onClick={() => show(l.id)}>
                                                {l.active ? 'Show' : 'None'}
                                            </button>
                                        </div>
                                    ))}
                                </div>
                            </>
                        )}
                    </Loaded>
                </Body>
            </Panel>
        </NpApp>
    );
}
