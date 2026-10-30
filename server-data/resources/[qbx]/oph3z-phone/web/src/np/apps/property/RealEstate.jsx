// Real Estate: browse / filter every listing and buy (shares server/app/property with Property).
import { useMemo, useState } from 'react';
import {
    faMagnifyingGlassLocation,
    faHouseUser,
    faSliders,
    faLocationDot,
    faShapes,
    faCar,
    faBuildingUser,
    faArrowDownAZ,
    faTag,
    faPersonWalking,
    faCheck,
    faKey,
} from '@fortawesome/free-solid-svg-icons';
import FaIcon from '../../FaIcon';
import { NpApp, TabBar, Splash, useSplash, Spinner, Empty, Sheet, SearchBox, useBack, money } from '../../ui/kit';
import { useProperties, usePropertyActions, KeysSheet, TYPE_LABEL } from './shared';
import './realestate.css';

const TABS = [
    { id: 'all', icon: faMagnifyingGlassLocation, label: 'Properties' },
    { id: 'mine', icon: faHouseUser, label: 'Your Properties' },
];

const range = (list, key) => {
    const v = list.map((p) => Number(p[key]) || 0);
    return v.length ? [Math.min(...v), Math.max(...v)] : [0, 0];
};

function freshFilter(list) {
    return {
        sort: 'price',
        price: range(list, 'price'),
        garage: range(list, 'garage'),
        size: range(list, 'size'),
        distance: range(list, 'distance').map(Math.ceil),
        zone: null,
        type: null,
        listing: null,
    };
}

export default function RealEstate() {
    const [splash] = useSplash(1000);
    const [tab, setTab] = useState('all');
    const [q, setQ] = useState('');
    const [filter, setFilter] = useState(null);
    const [editing, setEditing] = useState(false);
    const [detail, setDetail] = useState(null);
    const [keys, setKeys] = useState(null);
    const [data, reload] = useProperties();
    const act = usePropertyActions(reload);
    useBack(() => (editing ? (setEditing(false), true) : detail ? (setDetail(null), true) : false));

    const all = (data && data.ok && data.listings) || [];
    const f = filter || freshFilter(all);
    const list = useMemo(() => {
        const n = q.trim().toLowerCase();
        let l = tab === 'mine' ? all.filter((p) => p.mine || p.hasKey) : all.filter((p) => !p.sold);
        if (n) l = l.filter((p) => `${p.label} ${p.zone} ${p.street}`.toLowerCase().includes(n));
        if (filter) {
            const inR = (v, [a, b]) => (Number(v) || 0) >= a && (Number(v) || 0) <= b;
            l = l.filter(
                (p) =>
                    inR(p.price, f.price) &&
                    inR(p.garage, f.garage) &&
                    inR(p.size, f.size) &&
                    (p.distance == null || inR(Math.ceil(p.distance), f.distance)) &&
                    (!f.zone || p.zone === f.zone) &&
                    (!f.type || p.type === f.type) &&
                    (!f.listing || p.listing === f.listing),
            );
        }
        const by = { alpha: (a, b) => a.label.localeCompare(b.label), price: (a, b) => a.price - b.price, distance: (a, b) => (a.distance || 0) - (b.distance || 0) }[f.sort];
        return by ? [...l].sort(by) : l;
    }, [all, tab, q, filter, f]);

    if (splash)
        return (
            <NpApp className="nre">
                <Splash
                    bg="radial-gradient(circle at 50% 25%, #5e1f4d 0%, #2c1830 55%, #1c1626 100%)"
                    glyph={
                        <span className="nre-splash__tile">
                            <FaIcon icon={faKey} />
                        </span>
                    }
                    title="REAL ESTATE"
                    tagline="Explore your next property"
                    className="nre-splash"
                />
            </NpApp>
        );

    return (
        <NpApp theme="dark" className="nre">
            <div className="nre-tools">
                <SearchBox value={q} onChange={setQ} />
                <div className="nre-tools__row">
                    <button className="nre-filter" onClick={() => setEditing(true)}>
                        <FaIcon icon={faSliders} /> Filter
                    </button>
                    <button className="nre-reset" onClick={() => (setFilter(null), setQ(''))}>
                        Reset
                    </button>
                </div>
            </div>
            <div className="nre-list">
                {data === null ? (
                    <Spinner />
                ) : !data.ok ? (
                    <Empty title="Couldn’t load listings" action="Retry" onAction={reload} />
                ) : list.length === 0 ? (
                    <Empty title={tab === 'mine' ? 'You don’t own any property yet' : 'No properties match'} />
                ) : (
                    list.map((p) => (
                        <div key={p.id} className="nre-card">
                            <div className="nre-card__img" style={p.image ? { backgroundImage: `url("${p.image}")` } : undefined}>
                                <button className="nre-pin" onClick={() => act.locate(p)} aria-label="Waypoint">
                                    <FaIcon icon={faLocationDot} />
                                </button>
                                <b>{p.street || p.label}</b>
                            </div>
                            <Row icon={faLocationDot} k="Zone" v={p.zone} />
                            <Row icon={faShapes} k="Type" v={TYPE_LABEL[p.type] || p.type} />
                            <Row icon={faCar} k="Garage Slots" v={p.garage} />
                            <Row icon={faBuildingUser} k="Realtor" v={p.realtor || 'None'} />
                            <div className="nre-card__bottom">
                                <span>
                                    <em>Size</em>
                                    <b>{p.size} m²</b>
                                </span>
                                <span className="nre-price">
                                    <em>Price</em>
                                    <b>{money(p.price)}</b>
                                </span>
                            </div>
                            <button className="nre-more" onClick={() => setDetail(p)}>
                                See More
                            </button>
                        </div>
                    ))
                )}
            </div>
            <TabBar variant="label" tabs={TABS} active={tab} onChange={setTab} className="nre-tabs" />
            {editing && <FilterSheet all={all} value={f} onClose={() => setEditing(false)} onApply={(v) => (setFilter(v), setEditing(false))} />}
            {detail && (
                <Sheet title={detail.label} sub={`${detail.zone} · ${TYPE_LABEL[detail.type] || detail.type}`} onClose={() => setDetail(null)}>
                    {detail.description && <p className="nre-desc">{detail.description}</p>}
                    <div className="nre-facts">
                        <span>
                            <em>Price</em>
                            <b>{money(detail.price)}</b>
                        </span>
                        <span>
                            <em>Size</em>
                            <b>{detail.size} m²</b>
                        </span>
                        <span>
                            <em>Garage</em>
                            <b>{detail.garage}</b>
                        </span>
                        <span>
                            <em>Listing</em>
                            <b>{detail.listing === 'auction' ? 'Auction' : 'Open House'}</b>
                        </span>
                    </div>
                    <div className="nre-actions">
                        {!detail.sold && (
                            <button className="nre-buy" onClick={async () => (await act.buy(detail)) && setDetail(null)}>
                                Buy for {money(detail.price)}
                            </button>
                        )}
                        {detail.mine && (
                            <button className="nre-ghost" onClick={() => (setKeys(detail), setDetail(null))}>
                                Keyholders
                            </button>
                        )}
                        {detail.mine && data.sellBack > 0 && (
                            <button className="nre-ghost" onClick={async () => (await act.sell(detail, data.sellBack)) && setDetail(null)}>
                                Sell ({data.sellBack}%)
                            </button>
                        )}
                        <button className="nre-ghost" onClick={() => act.locate(detail)}>
                            Set Waypoint
                        </button>
                    </div>
                </Sheet>
            )}
            {keys && <KeysSheet property={keys} onClose={() => setKeys(null)} />}
        </NpApp>
    );
}

function Row({ icon, k, v }) {
    return (
        <div className="nre-row">
            <FaIcon icon={icon} />
            <span>{k}</span>
            <b>{v}</b>
        </div>
    );
}

function Dual({ label, value, bounds, fmt, onChange }) {
    const [lo, hi] = bounds;
    const step = Math.max(1, Math.round((hi - lo) / 200));
    return (
        <div className="nre-range">
            <div className="nre-range__top">
                <span>{label}</span>
                <b>
                    {fmt(value[0])} - {fmt(value[1])}
                </b>
            </div>
            <div className="nre-range__track">
                <span style={{ left: `${hi > lo ? ((value[0] - lo) / (hi - lo)) * 100 : 0}%`, right: `${hi > lo ? 100 - ((value[1] - lo) / (hi - lo)) * 100 : 0}%` }} />
                <input type="range" min={lo} max={hi} step={step} value={value[0]} onChange={(e) => onChange([Math.min(Number(e.target.value), value[1]), value[1]])} />
                <input type="range" min={lo} max={hi} step={step} value={value[1]} onChange={(e) => onChange([value[0], Math.max(Number(e.target.value), value[0])])} />
            </div>
        </div>
    );
}

function Pick({ items, value, onChange, labels = {} }) {
    return (
        <div className="nre-pick">
            <button className={value === null ? 'is-on' : ''} onClick={() => onChange(null)}>
                -
            </button>
            {items.map((i) => (
                <button key={i} className={value === i ? 'is-on' : ''} onClick={() => onChange(i)}>
                    {labels[i] || i}
                </button>
            ))}
        </div>
    );
}

function FilterSheet({ all, value, onClose, onApply }) {
    const [v, setV] = useState(value);
    const bounds = freshFilter(all);
    const uniq = (k) => [...new Set(all.map((p) => p[k]).filter(Boolean))].sort();
    const set = (k) => (x) => setV((cur) => ({ ...cur, [k]: x }));
    return (
        <Sheet onClose={onClose} className="nre-sheet">
            <div className="nre-label">Sort</div>
            <div className="nre-sort">
                {[
                    ['alpha', faArrowDownAZ, 'Alphabetical'],
                    ['price', faTag, 'Price'],
                    ['distance', faPersonWalking, 'Distance'],
                ].map(([id, icon, label]) => (
                    <button key={id} className={v.sort === id ? 'is-on' : ''} onClick={() => set('sort')(id)}>
                        <FaIcon icon={icon} /> {label}
                    </button>
                ))}
            </div>
            <Dual label="Price" value={v.price} bounds={bounds.price} fmt={(n) => money(n)} onChange={set('price')} />
            <Dual label="Garage" value={v.garage} bounds={bounds.garage} fmt={(n) => n} onChange={set('garage')} />
            <Dual label="Size" value={v.size} bounds={bounds.size} fmt={(n) => `${n} m²`} onChange={set('size')} />
            <Dual label="Distance" value={v.distance} bounds={bounds.distance} fmt={(n) => `${n} m`} onChange={set('distance')} />
            <div className="nre-label">Zone</div>
            <Pick items={uniq('zone')} value={v.zone} onChange={set('zone')} />
            <div className="nre-label">Type</div>
            <Pick items={uniq('type')} value={v.type} onChange={set('type')} labels={TYPE_LABEL} />
            <div className="nre-label">Listing</div>
            <Pick items={uniq('listing')} value={v.listing} onChange={set('listing')} labels={{ open: 'Open House', auction: 'Auction' }} />
            <button className="nre-confirm" onClick={() => onApply(v)}>
                <FaIcon icon={faCheck} /> Confirm
            </button>
        </Sheet>
    );
}
