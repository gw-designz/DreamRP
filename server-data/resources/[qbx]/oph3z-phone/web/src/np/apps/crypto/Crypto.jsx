// Crypto (LCN exchange). Prices / balances come from server/app/crypto; buying and selling
// move real bank money there, so this screen only shows quotes and sends requests.
import { useEffect, useMemo, useRef, useState } from 'react';
import { useDispatch } from 'react-redux';
import {
    faHouse,
    faLayerGroup,
    faChartLine,
    faUser,
    faUpload,
    faDownload,
    faRightLeft,
    faCookieBite,
    faSeedling,
    faBurger,
    faGasPump,
    faCar,
    faVoicemail,
    faCoins,
    faXmark,
    faChevronDown,
    faDeleteLeft,
    faBitcoinSign,
} from '@fortawesome/free-solid-svg-icons';
import FaIcon from '../../FaIcon';
import { pushToast } from '../../../store/slices/toastSlice';
import { NpApp, TabBar, SearchBox, Empty, Spinner, Splash, useSplash, Field, Msg, npCall, useNpFetch, useBack, money, ago } from '../../ui/kit';
import './crypto.css';

const ICONS = { cookie: faCookieBite, seedling: faSeedling, burger: faBurger, gas: faGasPump, car: faCar, wifi: faVoicemail };
const TABS = [
    { id: 'home', icon: faHouse, label: 'Home' },
    { id: 'wallet', icon: faLayerGroup, label: 'Portfolio' },
    { id: 'chart', icon: faChartLine, label: 'Markets' },
];
const ERR = {
    funds: 'Not enough money in your bank account.',
    coins: 'You don’t have that many coins.',
    amount: 'Enter a valid amount.',
    notfound: 'No phone found with that number.',
    self: 'You can’t send coins to yourself.',
    slow: 'One moment…',
};
const hist = (base) => Array.from({ length: 24 }, (_, i) => +(base * (0.9 + 0.2 * Math.abs(Math.sin(i / 3)))).toFixed(2));
const MOCK = {
    ok: true,
    name: 'qweqeqe qwewqeq',
    balance: 6194,
    fee: 1,
    minPurchase: 10,
    holdings: { octn: 1.25, sbn: 4 },
    coins: [
        { id: 'sbn', label: 'SnackBits', symbol: 'SBN', icon: 'cookie', price: 123.46, change: 2.1, history: hist(123) },
        { id: 'bean', label: 'BeanToken', symbol: 'BEAN', icon: 'seedling', price: 257.68, change: -1.2, history: hist(257) },
        { id: 'grl', label: 'GrillCoin', symbol: 'GRL', icon: 'burger', price: 334.09, change: 0.4, history: hist(334) },
        { id: 'octn', label: 'Octane', symbol: 'OCTN', icon: 'gas', price: 500, change: 5.3, history: hist(500) },
        { id: 'driv', label: 'DrivCoin', symbol: 'DRIV', icon: 'car', price: 449.33, change: -3.4, history: hist(449) },
        { id: 'wzn', label: 'WizNet', symbol: 'WZN', icon: 'wifi', price: 99.33, change: 1.1, history: hist(99) },
    ],
};

const CoinIcon = ({ c }) => (
    <span className="ncr-coin__ico">
        <FaIcon icon={ICONS[c.icon] || faCoins} />
    </span>
);
const fmtAmt = (n) => (Number(n) || 0).toLocaleString('en-US', { maximumFractionDigits: 4 });

export default function Crypto() {
    const [splash] = useSplash(1000);
    const [tab, setTab] = useState('home');
    const [action, setAction] = useState(null); // { kind: buy|sell|send, coin }
    const [q, setQ] = useState('');
    const [chartCoin, setChartCoin] = useState(null);
    const [data, reload, setData] = useNpFetch('phone:np:crypto:home', {}, MOCK);

    useBack(() => {
        if (action) return setAction(null), true;
        if (tab !== 'home') return setTab('home'), true;
        return false;
    });

    if (splash)
        return (
            <NpApp className="ncr">
                <Splash
                    bg="#7612f3"
                    className="ncr-splash"
                    glyph={<FaIcon icon={faBitcoinSign} className="ncr-splash__ghost" />}
                    icon={faBitcoinSign}
                    title="LCN"
                    tagline="CRYPTO EXCHANGE"
                />
            </NpApp>
        );

    const coins = data && data.ok ? data.coins : [];
    const n = q.trim().toLowerCase();
    const filtered = coins.filter((c) => !n || `${c.label} ${c.symbol}`.toLowerCase().includes(n));
    const apply = (r) => setData((d) => ({ ...d, holdings: r.holdings || d.holdings, balance: r.balance ?? d.balance }));

    let body;
    if (data === null) body = <Spinner />;
    else if (!data.ok) body = <Empty title="Exchange unavailable" action="Retry" onAction={reload} />;
    else if (action) body = <Trade data={data} action={action} onClose={() => setAction(null)} onDone={apply} />;
    else if (tab === 'home')
        body = (
            <div className="ncr-page">
                <div className="ncr-head">
                    <span className="ncr-avatar">
                        <FaIcon icon={faUser} />
                    </span>
                    <span className="ncr-welcome">
                        <em>Welcome back,</em>
                        <b>{data.name}</b>
                    </span>
                    <SearchBox value={q} onChange={setQ} className="ncr-search" />
                </div>
                <div className="ncr-actions">
                    <button onClick={() => setAction({ kind: 'buy', coin: coins[0] && coins[0].id })}>
                        <FaIcon icon={faUpload} />
                        <span>Purchase</span>
                    </button>
                    <button onClick={() => setAction({ kind: 'sell', coin: firstHeld(data) })}>
                        <FaIcon icon={faDownload} />
                        <span>Withdraw</span>
                    </button>
                    <button onClick={() => setAction({ kind: 'send', coin: firstHeld(data) })}>
                        <FaIcon icon={faRightLeft} />
                        <span>Transfer</span>
                    </button>
                </div>
                <div className="ncr-h">
                    <b>Trending</b>
                    <button onClick={() => setTab('chart')}>See All</button>
                </div>
                <div className="ncr-list">
                    {filtered.map((c) => (
                        <button key={c.id} className="ncr-coin" onClick={() => setAction({ kind: 'buy', coin: c.id })}>
                            <CoinIcon c={c} />
                            <span className="ncr-coin__main">
                                <b>{c.label}</b>
                                <em>{c.symbol}</em>
                            </span>
                            <span className="ncr-coin__price">{money(c.price, true).replace('.00', '')}</span>
                        </button>
                    ))}
                    {filtered.length === 0 && <Empty title="No coins match" />}
                </div>
            </div>
        );
    else if (tab === 'wallet') body = <Portfolio data={data} onTrade={setAction} />;
    else body = <Markets coins={coins} sel={chartCoin || (coins[0] && coins[0].id)} onSel={setChartCoin} onBuy={(id) => setAction({ kind: 'buy', coin: id })} />;

    return (
        <NpApp theme="dark" className="ncr">
            <div className="ncr-stage">{body}</div>
            {!action && <TabBar variant="bubble" tabs={TABS} active={tab} onChange={setTab} />}
        </NpApp>
    );
}

function firstHeld(data) {
    const id = Object.keys(data.holdings || {})[0];
    return id || (data.coins[0] && data.coins[0].id);
}

function Portfolio({ data, onTrade }) {
    const [hist] = useNpFetch('phone:np:crypto:history', {}, { ok: true, items: [] });
    const rows = data.coins.filter((c) => (data.holdings[c.id] || 0) > 0);
    const total = rows.reduce((a, c) => a + data.holdings[c.id] * c.price, 0);
    return (
        <div className="ncr-page">
            <div className="ncr-title">Portfolio</div>
            <div className="ncr-total">
                <em>Total value</em>
                <b>{money(total, true)}</b>
                <span>Bank balance {money(data.balance)}</span>
            </div>
            <div className="ncr-list">
                {rows.length === 0 && <Empty title="You don’t own any coins yet" body="Use Purchase to buy some." />}
                {rows.map((c) => (
                    <div key={c.id} className="ncr-coin">
                        <CoinIcon c={c} />
                        <span className="ncr-coin__main">
                            <b>
                                {fmtAmt(data.holdings[c.id])} {c.symbol}
                            </b>
                            <em>{money(data.holdings[c.id] * c.price, true)}</em>
                        </span>
                        <button className="ncr-mini" onClick={() => onTrade({ kind: 'sell', coin: c.id })}>
                            Withdraw
                        </button>
                        <button className="ncr-mini" onClick={() => onTrade({ kind: 'send', coin: c.id })}>
                            Send
                        </button>
                    </div>
                ))}
                {hist && hist.ok && hist.items.length > 0 && <div className="ncr-h"><b>Activity</b></div>}
                {hist &&
                    hist.ok &&
                    hist.items.map((t) => (
                        <div key={t.id} className="ncr-tx">
                            <span>
                                {{ buy: 'Bought', sell: 'Withdrew', sent: 'Sent', received: 'Received' }[t.kind] || t.kind} {fmtAmt(t.amount)} {String(t.coin).toUpperCase()}
                            </span>
                            <em>
                                {t.usd ? money(t.usd) + ' · ' : ''}
                                {ago(t.ts)}
                            </em>
                        </div>
                    ))}
            </div>
        </div>
    );
}

function Spark({ values }) {
    const pts = values && values.length > 1 ? values : [0, 0];
    const min = Math.min(...pts);
    const max = Math.max(...pts);
    const span = max - min || 1;
    const d = pts.map((v, i) => `${(i / (pts.length - 1)) * 100},${40 - ((v - min) / span) * 36 - 2}`).join(' ');
    const up = pts[pts.length - 1] >= pts[0];
    return (
        <svg viewBox="0 0 100 40" preserveAspectRatio="none" className="ncr-spark">
            <polyline points={d} fill="none" stroke={up ? '#3dd68c' : '#ff5a6a'} strokeWidth="1.4" vectorEffect="non-scaling-stroke" />
        </svg>
    );
}

function Markets({ coins, sel, onSel, onBuy }) {
    const c = coins.find((x) => x.id === sel) || coins[0];
    if (!c) return <Empty title="No coins configured" />;
    return (
        <div className="ncr-page">
            <div className="ncr-title">Markets</div>
            <div className="ncr-chart">
                <div className="ncr-chart__top">
                    <CoinIcon c={c} />
                    <span>
                        <b>{c.label}</b>
                        <em>{c.symbol}</em>
                    </span>
                    <span className="ncr-chart__price">
                        <b>{money(c.price, true)}</b>
                        <em className={c.change >= 0 ? 'is-up' : 'is-down'}>
                            {c.change >= 0 ? '+' : ''}
                            {c.change}%
                        </em>
                    </span>
                </div>
                <Spark values={c.history} />
                <button className="ncr-buy" onClick={() => onBuy(c.id)}>
                    Buy {c.symbol}
                </button>
            </div>
            <div className="ncr-list">
                {coins.map((x) => (
                    <button key={x.id} className={`ncr-coin${x.id === c.id ? ' is-on' : ''}`} onClick={() => onSel(x.id)}>
                        <CoinIcon c={x} />
                        <span className="ncr-coin__main">
                            <b>{x.label}</b>
                            <em className={x.change >= 0 ? 'is-up' : 'is-down'}>
                                {x.change >= 0 ? '+' : ''}
                                {x.change}%
                            </em>
                        </span>
                        <span className="ncr-coin__price">{money(x.price, true)}</span>
                    </button>
                ))}
            </div>
        </div>
    );
}

const KEYS = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '', '0', 'del'];

function Trade({ data, action, onClose, onDone }) {
    const dispatch = useDispatch();
    const [coin, setCoin] = useState(action.coin);
    const [kind] = useState(action.kind);
    const [value, setValue] = useState('');
    const [number, setNumber] = useState('');
    const [picking, setPicking] = useState(false);
    const [busy, setBusy] = useState(false);
    const [err, setErr] = useState('');
    const c = data.coins.find((x) => x.id === coin) || data.coins[0];
    const held = (data.holdings && data.holdings[c.id]) || 0;
    const usd = Number(value) || 0; // buy / sell: dollars
    const amountFromUsd = c.price > 0 ? usd / c.price : 0;
    const sendAmount = Number(value) || 0; // send: coins
    const title = { buy: 'Purchase', sell: 'Withdraw', send: 'Transfer' }[kind];

    const press = (k) => {
        setErr('');
        if (k === 'del') return setValue((v) => v.slice(0, -1));
        if (!k) return;
        if (kind === 'send' && k === '0' && value === '') return setValue('0.');
        setValue((v) => (v + k).slice(0, 9));
    };

    const total = useMemo(() => {
        const f = (data.fee || 0) / 100;
        if (kind === 'buy') return { left: money(usd), right: `${fmtAmt(amountFromUsd * (1 - f))} ${c.symbol}` };
        if (kind === 'sell') return { left: `${fmtAmt(amountFromUsd)} ${c.symbol}`, right: money(Math.floor(usd * (1 - f))) };
        return { left: `${fmtAmt(sendAmount)} ${c.symbol}`, right: money(sendAmount * c.price, true) };
    }, [kind, usd, amountFromUsd, sendAmount, c, data.fee]);

    const submit = async () => {
        setBusy(true);
        let r;
        if (kind === 'buy') r = await npCall('phone:np:crypto:buy', { coin: c.id, usd }, { ok: true, amount: amountFromUsd });
        else if (kind === 'sell') r = await npCall('phone:np:crypto:sell', { coin: c.id, amount: Math.min(held, amountFromUsd) }, { ok: true, usd });
        else r = await npCall('phone:np:crypto:transfer', { coin: c.id, amount: sendAmount, number }, { ok: true });
        setBusy(false);
        if (!r.ok) return setErr(ERR[r.reason] || 'That didn’t go through.');
        onDone(r);
        dispatch(
            pushToast({
                title: 'LCN',
                body: kind === 'buy' ? `Bought ${fmtAmt(r.amount)} ${c.symbol}.` : kind === 'sell' ? `Withdrew ${money(r.usd)} to your bank.` : `Sent ${fmtAmt(sendAmount)} ${c.symbol}.`,
            }),
        );
        onClose();
    };

    // physical keyboard: digits / . / Backspace drive the keypad (it owns those keys)
    const pressRef = useRef(press);
    pressRef.current = press;
    useEffect(() => {
        const onKey = (e) => {
            const tag = e.target && e.target.tagName;
            if (tag === 'INPUT' || tag === 'TEXTAREA') return;
            if (/^[0-9]$/.test(e.key)) pressRef.current(e.key);
            else if (e.key === 'Backspace') pressRef.current('del');
            else if (e.key === '.') setValue((v) => (v.includes('.') ? v : (v || '0') + '.'));
            else return;
            e.preventDefault();
        };
        window.addEventListener('keydown', onKey);
        return () => window.removeEventListener('keydown', onKey);
    }, []);

    const canSubmit = kind === 'send' ? sendAmount > 0 && sendAmount <= held && number.replace(/\D/g, '') : usd >= (kind === 'buy' ? data.minPurchase || 1 : 1);

    return (
        <div className="ncr-page ncr-trade">
            <div className="ncr-trade__head">
                <b>{title}</b>
                <button className="npk-round npk-round--sm" onClick={onClose} aria-label="Close">
                    <FaIcon icon={faXmark} />
                </button>
            </div>
            <button className="ncr-picker" onClick={() => setPicking((v) => !v)}>
                <CoinIcon c={c} />
                <span>
                    <b>{c.label}</b>
                    <em>{kind === 'buy' ? money(c.price, true) : `${fmtAmt(held)} ${c.symbol} owned`}</em>
                </span>
                <FaIcon icon={faChevronDown} />
            </button>
            {picking && (
                <div className="ncr-pick">
                    {data.coins
                        .filter((x) => kind === 'buy' || (data.holdings[x.id] || 0) > 0)
                        .map((x) => (
                            <button
                                key={x.id}
                                onClick={() => {
                                    setCoin(x.id);
                                    setPicking(false);
                                    setValue('');
                                }}
                            >
                                <CoinIcon c={x} /> {x.label}
                            </button>
                        ))}
                </div>
            )}
            <div className="ncr-amount">{kind === 'send' ? `${value || '0'} ${c.symbol}` : `$${Number(value || 0).toLocaleString()}`}</div>
            <div className="ncr-totalrow">
                <span>
                    <b>Total</b>
                    <em>{kind === 'buy' ? 'You’ll get' : kind === 'sell' ? 'You’ll receive' : 'Worth'}</em>
                </span>
                <span className="ncr-totalrow__r">
                    <b>{total.left}</b>
                    <em>{total.right}</em>
                </span>
            </div>
            {kind === 'send' && <Field value={number} onChange={setNumber} max={24} placeholder="Recipient phone number" className="ncr-to" />}
            <div className="ncr-keys" data-np-keys="own">
                {KEYS.map((k, i) => (
                    <button key={i} disabled={!k} onClick={() => press(k)} className={k ? '' : 'is-blank'}>
                        {k === 'del' ? <FaIcon icon={faDeleteLeft} /> : k}
                    </button>
                ))}
            </div>
            {kind === 'send' && (
                <button className="ncr-dot" onClick={() => !value.includes('.') && setValue((v) => (v || '0') + '.')}>
                    Add decimal point
                </button>
            )}
            <Msg>{err}</Msg>
            <button className="ncr-complete" disabled={!canSubmit || busy} onClick={submit}>
                {busy ? 'Processing…' : `Complete ${title}`}
            </button>
        </div>
    );
}
