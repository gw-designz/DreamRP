// Property: your homes and storages + listings for sale (server/app/property).
import { useState } from 'react';
import { faHouse, faBuilding, faWarehouse, faLocationDot, faUsersGear, faTag, faHouseChimneyUser } from '@fortawesome/free-solid-svg-icons';
import FaIcon from '../../FaIcon';
import { NpApp, TabBar, Splash, useSplash, Spinner, Empty, useStatusTone, money } from '../../ui/kit';
import { useProperties, usePropertyActions, KeysSheet, TYPE_ICON } from './shared';
import './property.css';

const TABS = [
    { id: 'home', icon: faHouse, label: 'Home' },
    { id: 'homes', icon: faBuilding, label: 'Homes' },
    { id: 'storage', icon: faWarehouse, label: 'Storage' },
];

const PropertyGlyph = () => (
    <span className="npp-glyph">
        <FaIcon icon={faHouse} />
        <FaIcon icon={faBuilding} />
    </span>
);

export default function Property() {
    const [splash] = useSplash(1000);
    const [tab, setTab] = useState('home');
    const [keys, setKeys] = useState(null);
    const [data, reload] = useProperties();
    const act = usePropertyActions(reload);
    useStatusTone(splash ? 'light' : 'dark');

    if (splash)
        return (
            <NpApp className="npp">
                <Splash bg="linear-gradient(180deg, #2b3fd6 0%, #5a4fe0 50%, #a86cf2 100%)" glyph={<PropertyGlyph />} title="PROPERTY" tagline="Enjoy your home" className="npp-splash" />
            </NpApp>
        );

    const all = (data && data.ok && data.listings) || [];
    const mine = all.filter((p) => p.mine || p.hasKey);
    let list;
    // home: what you own / hold keys to first, then everything still for sale
    if (tab === 'home') list = [...mine, ...all.filter((x) => !x.sold && !x.mine && !x.hasKey)];
    else if (tab === 'homes') list = all.filter((p) => !p.sold && p.type !== 'storage');
    else list = all.filter((p) => p.type === 'storage' && (!p.sold || p.mine || p.hasKey));

    return (
        <NpApp theme="light" className="npp">
            <div className="npp-body">
                {tab === 'home' && (
                    <div className="npp-banner">
                        <b>Property</b>
                        <span>Enjoy Your Home</span>
                        <button onClick={() => setTab('homes')}>Get Your New Home</button>
                    </div>
                )}
                {data === null ? (
                    <Spinner />
                ) : !data.ok ? (
                    <Empty title="Couldn’t load properties" action="Retry" onAction={reload} />
                ) : list.length === 0 ? (
                    <Empty icon={faHouseChimneyUser} title={tab === 'home' ? 'You don’t own a property yet' : 'Nothing for sale right now'} body={tab === 'home' ? 'Find one under Homes or Storage.' : null} />
                ) : (
                    list.map((p) => (
                        <div key={p.id} className="npp-card">
                            <div className="npp-card__top">
                                <span className="npp-card__ico">
                                    <FaIcon icon={TYPE_ICON[p.type] || faHouse} />
                                </span>
                                <span className="npp-card__main">
                                    <b>{p.label}</b>
                                    <em>{p.description}</em>
                                </span>
                                <button className="npp-sq" onClick={() => act.locate(p)} aria-label="Waypoint">
                                    <FaIcon icon={faLocationDot} />
                                </button>
                                {p.mine && (
                                    <button className="npp-sq" onClick={() => setKeys(p)} aria-label="Keyholders">
                                        <FaIcon icon={faUsersGear} />
                                    </button>
                                )}
                            </div>
                            {p.mine || p.hasKey ? (
                                <div className="npp-card__foot">
                                    <span>{p.street || p.zone}</span>
                                    {p.mine && data.sellBack > 0 ? (
                                        <button className="npp-sell" onClick={() => act.sell(p, data.sellBack)}>
                                            Sell
                                        </button>
                                    ) : (
                                        !p.mine && <span className="npp-keyed">Keyholder</span>
                                    )}
                                </div>
                            ) : (
                                <div className="npp-card__foot">
                                    <span className="npp-price">
                                        <FaIcon icon={faTag} /> {money(p.price)}
                                    </span>
                                    <button className="npp-buy" onClick={() => act.buy(p)}>
                                        Buy
                                    </button>
                                </div>
                            )}
                        </div>
                    ))
                )}
            </div>
            <TabBar variant="bubble" tabs={TABS} active={tab} onChange={setTab} className="npp-tabs" />
            {keys && <KeysSheet property={keys} onClose={() => setKeys(null)} />}
        </NpApp>
    );
}
