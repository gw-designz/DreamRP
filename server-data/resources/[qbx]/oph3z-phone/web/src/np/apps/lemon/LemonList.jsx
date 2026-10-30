// Lemon List: classified ads on the built-in marketplace backend (server/app/marketplace).
import { useEffect, useState } from 'react';
import { useDispatch } from 'react-redux';
import { faPhone, faPlus, faMessage, faTrash } from '@fortawesome/free-solid-svg-icons';
import FaIcon from '../../FaIcon';
import { setResumeThread } from '../../../store/slices/messagesSlice';
import { openApp } from '../../../store/slices/phoneSlice';
import { digitsOf } from '../../../store/slices/contactsSlice';
import { openDialog } from '../../../store/slices/dialogSlice';
import { NpApp, Panel, BigHeader, Body, SearchBox, Chips, Empty, Spinner, Sheet, Field, Btn, Msg, npCall, useNpFetch, useNpConfig, ago } from '../../ui/kit';
import './lemon.css';

const MOCK_CATS = [
    { id: 'mechanic', label: 'Mechanic' },
    { id: 'services', label: 'Services' },
    { id: 'food', label: 'Food' },
    { id: 'taxi', label: 'Taxi' },
    { id: 'government', label: 'Government' },
];
const MOCK_ADS = [
    { id: 1, category: 'mechanic', title: 'wqe', desc: 'Mobile mechanic, any car, any place.', isMine: true, createdAt: Date.now() / 1000 - 600, seller: { name: 'Raptox Doe', number: '555-0142' } },
    { id: 2, category: 'services', title: 'Swqeqw', desc: 'Need a driver? Call me.', isMine: false, createdAt: Date.now() / 1000 - 3600, seller: { name: 'Marta Lamb', number: '555-0177' } },
];
const ERR = { limit: 'You already have the maximum number of ads.', title: 'Write something for your ad.', bad: 'Could not post this ad.' };

export default function LemonList() {
    const dispatch = useDispatch();
    const cats = useNpConfig('lemon', MOCK_CATS) || MOCK_CATS;
    const [cat, setCat] = useState('all');
    const [q, setQ] = useState('');
    const [query, setQuery] = useState('');
    const [open, setOpen] = useState(null);
    const [posting, setPosting] = useState(false);

    useEffect(() => {
        const t = setTimeout(() => setQuery(q), 250);
        return () => clearTimeout(t);
    }, [q]);

    const [data, reload, setData] = useNpFetch('phone:market:feed', { category: cat, q: query }, { ok: true, listings: MOCK_ADS });
    const labelOf = (id) => (cats.find((c) => c.id === id) || {}).label || (id ? id[0].toUpperCase() + id.slice(1) : '');

    const remove = async (ad) => {
        const ok = await dispatch(
            openDialog({
                title: 'Delete ad?',
                message: ad.title,
                buttons: [
                    { text: 'Cancel', style: 'cancel', value: false },
                    { text: 'Delete', style: 'destructive', value: true },
                ],
            }),
        );
        if (!ok) return;
        const r = await npCall('phone:market:delete', { id: ad.id });
        if (r.ok) {
            setOpen(null);
            setData((d) => (d && d.listings ? { ...d, listings: d.listings.filter((l) => l.id !== ad.id) } : d));
        }
    };

    const message = (number) => {
        dispatch(setResumeThread(digitsOf(number)));
        dispatch(openApp('message'));
    };

    return (
        <NpApp theme="dark" className="nll">
            <Panel>
                <BigHeader title="Lemon List" color="#f5c518" />
                <div className="nll-tools">
                    <SearchBox value={q} onChange={setQ} placeholder="Search ads" />
                    <Chips items={[{ id: 'all', label: 'All' }, ...cats]} value={cat} onChange={setCat} className="nll-chips" />
                </div>
                <Body>
                    {data === null ? (
                        <Spinner />
                    ) : !data.ok ? (
                        <Empty title="Couldn’t load ads" action="Retry" onAction={reload} />
                    ) : data.listings.length === 0 ? (
                        <Empty title="No ads here yet" body="Be the first to post one." />
                    ) : (
                        <div className="npk-list">
                            {data.listings.map((ad) => (
                                <button key={ad.id} className="nll-ad" onClick={() => setOpen(ad)}>
                                    <span className="nll-ad__top">
                                        <b>{ad.seller && ad.seller.name}</b>
                                        <em>{labelOf(ad.category)}</em>
                                    </span>
                                    <span className="nll-ad__text">{ad.desc || ad.title}</span>
                                    <span className="nll-ad__bottom">
                                        <span>
                                            <FaIcon icon={faPhone} /> {ad.seller && ad.seller.number}
                                        </span>
                                        {ad.isMine ? <i>Your Ad</i> : <small>{ago(ad.createdAt)}</small>}
                                    </span>
                                </button>
                            ))}
                        </div>
                    )}
                </Body>
                <button className="nll-post" onClick={() => setPosting(true)}>
                    <FaIcon icon={faPlus} /> Post an Ad
                </button>
            </Panel>

            {open && (
                <Sheet title={open.seller && open.seller.name} sub={labelOf(open.category)} onClose={() => setOpen(null)}>
                    <div className="nll-full">{open.desc || open.title}</div>
                    <div className="nll-actions">
                        {open.allowCalls !== false && (
                            <Btn onClick={() => fetchCall(open.seller && open.seller.number)}>
                                <FaIcon icon={faPhone} /> Call
                            </Btn>
                        )}
                        {open.allowMsg !== false && (
                            <Btn kind="muted" onClick={() => message(open.seller && open.seller.number)}>
                                <FaIcon icon={faMessage} /> Message
                            </Btn>
                        )}
                        {open.isMine && (
                            <Btn kind="danger" onClick={() => remove(open)}>
                                <FaIcon icon={faTrash} /> Delete
                            </Btn>
                        )}
                    </div>
                </Sheet>
            )}
            {posting && (
                <PostAd
                    cats={cats}
                    onClose={() => setPosting(false)}
                    onPosted={() => {
                        setPosting(false);
                        reload();
                    }}
                />
            )}
        </NpApp>
    );
}

function fetchCall(number) {
    if (number) npCall('phone:call:start', { number }, {});
}

function PostAd({ cats, onClose, onPosted }) {
    const [cat, setCat] = useState(cats[0] ? cats[0].id : 'services');
    const [text, setText] = useState('');
    const [busy, setBusy] = useState(false);
    const [err, setErr] = useState('');
    const submit = async () => {
        if (!text.trim()) return setErr(ERR.title);
        setBusy(true);
        const r = await npCall('phone:market:create', { category: cat, title: text.trim().slice(0, 80), desc: text.trim(), allowCalls: true, allowMsg: true, media: [] }, { ok: true });
        setBusy(false);
        if (r.ok) onPosted();
        else setErr(ERR[r.reason] || ERR.bad);
    };
    return (
        <Sheet title="Post an Ad" sub="Your name and number are shown on the ad" onClose={onClose}>
            <Chips items={cats} value={cat} onChange={setCat} className="nll-chips nll-chips--wrap" />
            <Field label="Ad text" value={text} max={255} counter area onChange={setText} autoFocus />
            <Msg>{err}</Msg>
            <Btn className="npk-btn--block nll-btn" busy={busy} onClick={submit}>
                Post Ad
            </Btn>
        </Sheet>
    );
}
