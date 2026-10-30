// Calendar: month grid with personal (and optionally shared) events. Q / E move between months.
import { useMemo, useState } from 'react';
import { faUserGroup, faPlus, faChevronLeft, faChevronRight, faTrash, faClock } from '@fortawesome/free-solid-svg-icons';
import FaIcon from '../../FaIcon';
import { NpApp, BigHeader, Sheet, Field, Btn, Msg, Toggle, Empty, Keycap, npCall, useNpFetch, useTabKeys, useBack } from '../../ui/kit';
import './calendar.css';

const MONTHS = ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'];
const LONG = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
const DAYS = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
const pad = (n) => String(n).padStart(2, '0');
const key = (y, m, d) => `${y}-${pad(m + 1)}-${pad(d)}`;

export default function Calendar() {
    const today = new Date();
    const [year, setYear] = useState(today.getFullYear());
    const [month, setMonth] = useState(today.getMonth());
    const [sel, setSel] = useState(key(today.getFullYear(), today.getMonth(), today.getDate()));
    const [showShared, setShowShared] = useState(true);
    const [adding, setAdding] = useState(false);
    const mockDay = key(today.getFullYear(), today.getMonth(), Math.min(28, today.getDate() + 3));
    const [data, reload] = useNpFetch(
        'phone:np:cal:month',
        { year, month: month + 1 },
        { ok: true, events: [{ id: 1, title: 'Court hearing', note: 'Bring the paperwork.', day: mockDay, time: '18:30', mine: true }] },
    );

    const go = (delta) => {
        let m = month + delta;
        let y = year;
        if (m < 0) (m = 11), (y -= 1);
        if (m > 11) (m = 0), (y += 1);
        setMonth(m);
        setYear(y);
    };
    useTabKeys(['prev', 'cur', 'next'], 'cur', (id) => go(id === 'next' ? 1 : -1));
    useBack(() => (adding ? (setAdding(false), true) : false));

    const events = useMemo(() => ((data && data.ok && data.events) || []).filter((e) => showShared || e.mine), [data, showShared]);
    const byDay = useMemo(() => {
        const m = {};
        for (const e of events) (m[e.day] = m[e.day] || []).push(e);
        return m;
    }, [events]);

    const first = new Date(year, month, 1).getDay();
    const daysIn = new Date(year, month + 1, 0).getDate();
    const prevDays = new Date(year, month, 0).getDate();
    const cells = [];
    for (let i = 0; i < 42; i++) {
        const d = i - first + 1;
        if (d < 1) cells.push({ d: prevDays + d, out: true });
        else if (d > daysIn) cells.push({ d: d - daysIn, out: true });
        else cells.push({ d, k: key(year, month, d), dow: i % 7 });
    }
    const todayKey = key(today.getFullYear(), today.getMonth(), today.getDate());
    const selEvents = byDay[sel] || [];

    const remove = async (id) => {
        const r = await npCall('phone:np:cal:delete', { id }, { ok: true });
        if (r.ok) reload();
    };

    return (
        <NpApp theme="dark" className="ncl">
            <BigHeader
                title="Calendar"
                right={
                    <>
                        <button className={`ncl-round${showShared ? ' is-on' : ''}`} onClick={() => setShowShared((v) => !v)} title="Show shared events">
                            <FaIcon icon={faUserGroup} />
                        </button>
                        <button className="ncl-round" onClick={() => setAdding(true)} aria-label="Add event">
                            <FaIcon icon={faPlus} />
                        </button>
                    </>
                }
            />
            <div className="ncl-body">
                <div className="ncl-month">
                    <b>
                        {LONG[month]} {year}
                    </b>
                    <button className="ncl-round ncl-round--sm" onClick={() => go(-1)} aria-label="Previous month">
                        <FaIcon icon={faChevronLeft} />
                    </button>
                    <button className="ncl-round ncl-round--sm" onClick={() => go(1)} aria-label="Next month">
                        <FaIcon icon={faChevronRight} />
                    </button>
                </div>
                <div className="ncl-grid">
                    {DAYS.map((d) => (
                        <span key={d} className="ncl-dow">
                            {d}
                        </span>
                    ))}
                    {cells.map((c, i) =>
                        c.out ? (
                            <span key={i} className="ncl-cell is-out">
                                {pad(c.d)}
                            </span>
                        ) : (
                            <button
                                key={i}
                                className={`ncl-cell${c.dow === 0 || c.dow === 6 ? ' is-weekend' : ''}${c.k === todayKey ? ' is-today' : ''}${c.k === sel ? ' is-sel' : ''}`}
                                onClick={() => setSel(c.k)}
                            >
                                {pad(c.d)}
                                {byDay[c.k] && <i />}
                            </button>
                        ),
                    )}
                </div>
                <div className="ncl-list">
                    {selEvents.length === 0 ? (
                        <Empty title="Nothing planned" body="Tap + to add an event on this day." />
                    ) : (
                        selEvents.map((e) => (
                            <div key={e.id} className="ncl-event">
                                <span className="ncl-event__time">
                                    <FaIcon icon={faClock} /> {e.time || 'All day'}
                                </span>
                                <span className="ncl-event__main">
                                    <b>{e.title}</b>
                                    {e.note && <em>{e.note}</em>}
                                    {!e.mine && <small>Shared by {e.owner}</small>}
                                </span>
                                {e.mine && (
                                    <button onClick={() => remove(e.id)} aria-label="Delete">
                                        <FaIcon icon={faTrash} />
                                    </button>
                                )}
                            </div>
                        ))
                    )}
                </div>
            </div>
            <nav className="ncl-months">
                <Keycap k="Q" />
                {MONTHS.map((m, i) => (
                    <button key={m} className={i === month ? 'is-on' : ''} onClick={() => setMonth(i)}>
                        {m}
                    </button>
                ))}
                <Keycap k="E" />
            </nav>
            {adding && (
                <AddEvent
                    day={sel}
                    onClose={() => setAdding(false)}
                    onSaved={() => {
                        setAdding(false);
                        reload();
                    }}
                />
            )}
        </NpApp>
    );
}

function AddEvent({ day, onClose, onSaved }) {
    const [title, setTitle] = useState('');
    const [time, setTime] = useState('');
    const [note, setNote] = useState('');
    const [shared, setShared] = useState(false);
    const [busy, setBusy] = useState(false);
    const [err, setErr] = useState('');
    const save = async () => {
        if (time && !/^([01]\d|2[0-3]):[0-5]\d$/.test(time)) return setErr('Use a 24h time like 18:30.');
        setBusy(true);
        const r = await npCall('phone:np:cal:add', { title, time, note, day, shared }, { ok: true });
        setBusy(false);
        if (r.ok) onSaved();
        else setErr(r.reason === 'limit' ? 'Your calendar is full.' : 'Could not save this event.');
    };
    return (
        <Sheet title="New Event" sub={day} onClose={onClose}>
            <Field label="Title" value={title} max={60} onChange={setTitle} autoFocus />
            <Field label="Time (optional, 24h)" value={time} max={5} placeholder="18:30" onChange={setTime} />
            <Field label="Notes" value={note} max={300} area onChange={setNote} />
            <div className="ncl-shared">
                <span>
                    <b>Share with everyone</b>
                    <em>Shows on every player’s calendar</em>
                </span>
                <Toggle on={shared} onChange={setShared} />
            </div>
            <Msg>{err}</Msg>
            <Btn className="npk-btn--block" busy={busy} disabled={!title.trim()} onClick={save}>
                Add Event
            </Btn>
        </Sheet>
    );
}
