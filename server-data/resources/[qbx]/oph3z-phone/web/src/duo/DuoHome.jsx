import { useEffect, useMemo, useRef, useState } from 'react';
import { useDispatch, useSelector } from 'react-redux';
import './DuoHome.css';
import { launchApp, useHomeApps } from '../np/NpHome';
import { NpAppIcon } from '../np/npIcons';
import { usePhoneClock } from '../np/usePhoneClock';
import { useNow } from '../hooks/useNow';
import { weekdayName } from '../i18n/dateNames';

const ROWS = 6;
const WIDGET_CELLS = 8; // two 2×2 widgets at the top of the first page

const unread = (items, id) => items.reduce((a, n) => a + (!n.read && n.app === id ? 1 : 0), 0);

// iOS-style home screen: paged icon grid with widgets on page one and a glass dock.
// Folded = 4 columns (iPhone), unfolded = 6 columns with the widgets in the corner (iPad-like).
export default function DuoHome() {
    const dispatch = useDispatch();
    const folded = useSelector((s) => s.phone.folded);
    const { grid, dock } = useHomeApps();
    const cols = folded ? 4 : 6;

    const pages = useMemo(() => {
        const out = [];
        const first = cols * ROWS - WIDGET_CELLS;
        out.push(grid.slice(0, first));
        for (let i = first; i < grid.length; i += cols * ROWS) out.push(grid.slice(i, i + cols * ROWS));
        return out;
    }, [grid, cols]);

    const byId = useMemo(() => {
        const m = {};
        for (const a of grid) m[a.id] = a;
        for (const a of dock) m[a.id] = a;
        return m;
    }, [grid, dock]);
    const open = (id) => byId[id] && launchApp(dispatch, byId[id]);

    const pager = usePager(pages.length, cols);

    return (
        <div className="duo-home" style={{ '--cols': cols, '--rows': ROWS }}>
            <div className="duo-home__pager" {...pager.bind}>
                {pages.map((apps, i) => (
                    <div className="duo-page" key={i}>
                        {i === 0 && (
                            <>
                                <CalendarWidget onOpen={byId.calendar ? () => open('calendar') : null} />
                                <ClockWidget onOpen={byId.clock ? () => open('clock') : null} />
                            </>
                        )}
                        {apps.map((a) => (
                            <DuoTile key={a.id} app={a} onOpen={() => launchApp(dispatch, a)} />
                        ))}
                    </div>
                ))}
            </div>

            <div className="duo-home__dots">
                {pages.length > 1 &&
                    pages.map((_, i) => (
                        <button
                            key={i}
                            className={`duo-home__dot${i === pager.page ? ' is-active' : ''}`}
                            onClick={() => pager.go(i)}
                            aria-label={`Page ${i + 1}`}
                            data-sound="none"
                        />
                    ))}
            </div>

            <nav className="duo-dock">
                {dock.map((a) => (
                    <DuoTile key={a.id} app={a} dock onOpen={() => launchApp(dispatch, a)} />
                ))}
            </nav>
        </div>
    );
}

// Horizontal paging over a scroll-snap container: mouse wheel, drag and the page dots.
// It stays a real scroll container so arrow-key focus (useNpKeys) scrolls pages into view.
function usePager(count, cols) {
    const ref = useRef(null);
    const [page, setPage] = useState(0);
    const drag = useRef(null);
    const wheelAt = useRef(0);

    const go = (i) => {
        const el = ref.current;
        if (!el) return;
        const next = Math.max(0, Math.min(count - 1, i));
        el.scrollTo({ left: next * el.clientWidth, behavior: 'smooth' });
    };

    // Re-paginating on fold / unfold: start again from the first page.
    useEffect(() => {
        if (ref.current) ref.current.scrollLeft = 0;
        setPage(0);
    }, [cols]);

    const bind = {
        ref,
        onScroll: (e) => {
            const el = e.currentTarget;
            setPage(Math.round(el.scrollLeft / Math.max(1, el.clientWidth)));
        },
        onWheel: (e) => {
            const d = Math.abs(e.deltaX) > Math.abs(e.deltaY) ? e.deltaX : e.deltaY;
            if (Math.abs(d) < 4 || Date.now() - wheelAt.current < 380) return;
            wheelAt.current = Date.now();
            go(page + (d > 0 ? 1 : -1));
        },
        onPointerDown: (e) => {
            if (e.button !== 0 || count < 2) return;
            drag.current = { x: e.clientX, left: ref.current.scrollLeft, moved: false, t: Date.now() };
        },
        onPointerMove: (e) => {
            const d = drag.current;
            if (!d) return;
            const dx = e.clientX - d.x;
            if (!d.moved && Math.abs(dx) < 6) return;
            if (!d.moved) {
                d.moved = true;
                ref.current.classList.add('is-dragging');
                ref.current.setPointerCapture(e.pointerId);
            }
            ref.current.scrollLeft = d.left - dx;
        },
        onPointerUp: (e) => {
            const d = drag.current;
            drag.current = null;
            if (!d || !d.moved) return;
            const el = ref.current;
            el.classList.remove('is-dragging');
            const dx = e.clientX - d.x;
            const fast = Math.abs(dx) / Math.max(1, Date.now() - d.t) > 0.35;
            const from = Math.round(d.left / el.clientWidth);
            const by = Math.abs(dx) > el.clientWidth * 0.25 || fast ? (dx < 0 ? 1 : -1) : 0;
            go(from + by);
            // swallow the click that ends a swipe
            const stop = (ev) => ev.stopPropagation();
            el.addEventListener('click', stop, { capture: true, once: true });
            setTimeout(() => el.removeEventListener('click', stop, { capture: true }), 0);
        },
    };
    bind.onPointerCancel = bind.onPointerUp;

    return { bind, page, go };
}

export function DuoIcon({ app }) {
    // Built-in apps with artwork use it; everything else gets a generated tile.
    if (app.icon && app.id !== 'contacts') {
        return (
            <span className="duo-icon duo-icon--img">
                <img src={app.icon} alt="" />
            </span>
        );
    }
    return (
        <span className="duo-icon">
            <NpAppIcon id={app.id} iconUrl={app.external ? app.icon : null} label={app.label} />
        </span>
    );
}

function DuoTile({ app, dock, onOpen }) {
    const target = app.id === 'contacts' ? 'call' : app.id;
    const count = useSelector((s) =>
        app.id === 'contacts' ? 0 : unread(s.notifications.items, target),
    );
    const dl = useSelector((s) => s.home.downloads[app.id]);
    const downloading = dl != null;
    return (
        <button
            className={`duo-tile${dock ? ' duo-tile--dock' : ''}${downloading ? ' is-downloading' : ''}`}
            onClick={downloading ? undefined : onOpen}
            data-app={app.id}
            aria-label={app.label}
        >
            <span className="duo-tile__icon">
                <DuoIcon app={app} />
                {downloading && (
                    <span className="duo-tile__dl">
                        <span style={{ width: `${Math.round(dl * 100)}%` }} />
                    </span>
                )}
                {!downloading && count > 0 && (
                    <span className="duo-tile__badge">{count > 99 ? '99+' : count}</span>
                )}
            </span>
            {!dock && <span className="duo-tile__label">{app.label}</span>}
        </button>
    );
}

// Weekday / day from the same source as the clock (Config.UI.TimeSource).
function usePhoneDate() {
    const source = useSelector((s) => s.phone.ui.timeSource);
    const game = useSelector((s) => s.phone.time);
    const now = useNow();
    if (source === 'game') return { weekday: Number(game.weekday) || 0, day: Number(game.day) || 1 };
    return { weekday: now.getDay(), day: now.getDate() };
}

function Widget({ className, label, onOpen, children }) {
    return (
        <div className="duo-widget-cell">
            <button
                className={`duo-widget ${className}`}
                onClick={onOpen || undefined}
                disabled={!onOpen}
                aria-label={label}
            >
                {children}
            </button>
            <span className="duo-tile__label">{label}</span>
        </div>
    );
}

function CalendarWidget({ onOpen }) {
    const { weekday, day } = usePhoneDate();
    return (
        <Widget className="duo-widget--calendar" label="Calendar" onOpen={onOpen}>
            <span className="duo-cal__weekday">{weekdayName(weekday)}</span>
            <span className="duo-cal__day">{day}</span>
            <span className="duo-cal__empty">No events today</span>
        </Widget>
    );
}

function ClockWidget({ onOpen }) {
    const clock = usePhoneClock();
    const zone = useSelector((s) => s.phone.zone);
    const showLocation = useSelector((s) => s.phone.ui.showLocation);
    const [time, suffix] = clock.split(' ');
    return (
        <Widget className="duo-widget--clock" label="Clock" onOpen={onOpen}>
            <span className="duo-clk__city">
                <svg viewBox="0 0 24 24" className="duo-clk__arrow" aria-hidden>
                    <path d="M20.5 3.5 3.8 10.4c-.8.3-.7 1.4.1 1.6l6.6 1.5 1.5 6.6c.2.8 1.3.9 1.6.1z" />
                </svg>
                Los Santos
            </span>
            <span className="duo-clk__time">
                {time}
                {suffix && <small>{suffix}</small>}
            </span>
            <span className="duo-clk__zone">{showLocation && zone ? zone : 'Local time'}</span>
        </Widget>
    );
}
