// Data + actions shared by the Property and Real Estate apps (server/app/property).
import { useState } from 'react';
import { useDispatch } from 'react-redux';
import { faHouse, faBuilding, faWarehouse, faStore, faTrash } from '@fortawesome/free-solid-svg-icons';
import FaIcon from '../../FaIcon';
import { pushToast } from '../../../store/slices/toastSlice';
import { openDialog } from '../../../store/slices/dialogSlice';
import { Sheet, Field, Btn, Msg, Spinner, Empty, npCall, useNpFetch, money } from '../../ui/kit';

export const TYPE_ICON = { residential: faHouse, apartment: faBuilding, storage: faWarehouse, commercial: faStore };
export const TYPE_LABEL = { residential: 'Residential', apartment: 'Apartment', storage: 'Storage', commercial: 'Commercial' };

const MOCK = {
    ok: true,
    sellBack: 60,
    listings: [
        { id: 'lamesa_storage', label: 'La Mesa Storage', description: 'A deep freeze storage.', type: 'storage', zone: 'La Mesa', street: 'Popular St, La Mesa', price: 45000, garage: 0, size: 60, listing: 'open', realtor: 'None', distance: 640, mine: true },
        { id: 'forum_11', label: '11 Forum Dr', description: 'A cozy family home.', type: 'residential', zone: 'Chamberlain Hills', street: '11 Forum Dr, Chamberlain Hills', price: 296000, garage: 2, size: 110, listing: 'open', realtor: 'None', distance: 1200 },
        { id: 'grove_4', label: '4 Grove St', description: 'A classic on Grove Street.', type: 'residential', zone: 'Davis', street: '4 Grove St, Davis', price: 342000, garage: 2, size: 138, listing: 'open', realtor: 'None', distance: 980 },
        { id: 'eclipse_31', label: 'Eclipse Towers Apt 31', description: 'A luxurious apartment.', type: 'apartment', zone: 'Rockford Hills', street: 'Eclipse Towers Apt 31, Rockford Hills', price: 8056000, garage: 8, size: 480, listing: 'auction', realtor: 'None', distance: 2001 },
    ],
};

export const ERR = {
    funds: 'Not enough money in your bank account.',
    sold: 'Someone already bought this property.',
    limit: 'You own the maximum number of properties.',
    slow: 'One moment…',
    notfound: 'No phone found with that number.',
    self: 'That’s your own number.',
    owner: 'You don’t own this property.',
    disabled: 'Selling back is disabled on this server.',
    nolocation: 'This property has no location.',
};

export function useProperties() {
    return useNpFetch('phone:np:prop:list', {}, MOCK);
}

export function usePropertyActions(reload) {
    const dispatch = useDispatch();
    const toast = (body) => dispatch(pushToast({ title: 'Property', body }));
    return {
        buy: async (p) => {
            const ok = await dispatch(
                openDialog({
                    title: `Buy ${p.label}?`,
                    message: `${money(p.price)} will be taken from your bank account.`,
                    buttons: [
                        { text: 'Cancel', style: 'cancel', value: false },
                        { text: 'Buy', style: 'default', value: true },
                    ],
                }),
            );
            if (!ok) return false;
            const r = await npCall('phone:np:prop:buy', { id: p.id }, { ok: true });
            toast(r.ok ? `You bought ${p.label}!` : ERR[r.reason] || 'Purchase failed.');
            if (r.ok) reload();
            return r.ok;
        },
        sell: async (p, pct) => {
            const ok = await dispatch(
                openDialog({
                    title: `Sell ${p.label}?`,
                    message: `You’ll get ${money(Math.floor((p.price * pct) / 100))} (${pct}% of the price). Keyholders lose access.`,
                    buttons: [
                        { text: 'Cancel', style: 'cancel', value: false },
                        { text: 'Sell', style: 'destructive', value: true },
                    ],
                }),
            );
            if (!ok) return false;
            const r = await npCall('phone:np:prop:sell', { id: p.id }, { ok: true, amount: 0 });
            toast(r.ok ? `Sold for ${money(r.amount)}.` : ERR[r.reason] || 'Could not sell.');
            if (r.ok) reload();
            return r.ok;
        },
        locate: async (p) => {
            const r = await npCall('phone:np:prop:locate', { id: p.id }, { ok: true });
            toast(r.ok ? 'Waypoint set.' : ERR[r.reason] || 'No location.');
        },
    };
}

export function KeysSheet({ property, onClose }) {
    const [data, reload] = useNpFetch('phone:np:prop:keys', { id: property.id }, { ok: true, keys: [{ cid: 'X', name: 'Marta Lamb' }] });
    const [number, setNumber] = useState('');
    const [err, setErr] = useState('');
    const give = async () => {
        const r = await npCall('phone:np:prop:giveKey', { id: property.id, number }, { ok: true });
        if (r.ok) {
            setNumber('');
            setErr('');
            reload();
        } else setErr(r.reason === 'limit' ? 'Too many keyholders.' : ERR[r.reason] || 'Could not give a key.');
    };
    const take = async (cid) => {
        await npCall('phone:np:prop:removeKey', { id: property.id, cid }, { ok: true });
        reload();
    };
    return (
        <Sheet title="Keyholders" sub={property.label} onClose={onClose}>
            {data === null ? (
                <Spinner />
            ) : !data.ok || data.keys.length === 0 ? (
                <Empty title="Nobody else has a key" />
            ) : (
                <div className="npk-list">
                    {data.keys.map((k) => (
                        <div key={k.cid} className="npk-row">
                            <span className="npk-row__main npk-row__title">{k.name}</span>
                            <button className="npk-ibtn" onClick={() => take(k.cid)} aria-label="Remove key">
                                <FaIcon icon={faTrash} />
                            </button>
                        </div>
                    ))}
                </div>
            )}
            <Field label="Give a key (phone number)" value={number} max={24} onChange={setNumber} onEnter={give} />
            <Msg>{err}</Msg>
            <Btn className="npk-btn--block" disabled={!number.replace(/\D/g, '')} onClick={give}>
                Give Key
            </Btn>
        </Sheet>
    );
}
