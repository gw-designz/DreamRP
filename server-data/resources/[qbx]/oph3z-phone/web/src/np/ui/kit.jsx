// Shared building blocks for the NoPixel-style apps (themes, headers, splash, Q/E tab bars,
// sheets, form fields, data hooks). Every app under np/apps uses these so they stay consistent.
import { useCallback, useEffect, useRef, useState } from 'react';
import { useDispatch } from 'react-redux';
import FaIcon from '../FaIcon';
import { setStatusTone } from '../../store/slices/phoneSlice';
import { fetchNui } from '../../utils/fetchNui';
import './kit.css';

/* ------------------------------------------------------------------ data */

export async function npCall(endpoint, data = {}, mock = { ok: true }) {
    const r = await fetchNui(endpoint, data, mock);
    return r && typeof r === 'object' ? r : { ok: false, reason: 'error' };
}

// [data, reload, setData]. data: null = loading, {ok:false,...} = failed.
export function useNpFetch(endpoint, payload, mock, deps = []) {
    const [data, setData] = useState(null);
    const [nonce, setNonce] = useState(0);
    const key = JSON.stringify(payload || {});
    useEffect(() => {
        let alive = true;
        npCall(endpoint, payload || {}, mock).then((r) => alive && setData(r));
        return () => {
            alive = false;
        };
        // eslint-disable-next-line react-hooks/exhaustive-deps
    }, [endpoint, key, nonce, ...deps]);
    const reload = useCallback(() => setNonce((n) => n + 1), []);
    return [data, reload, setData];
}

// Config values for an app from config.lua (client/app/nopixel: phone:np:config).
// Returns null while loading, the mock in the browser preview.
export function useNpConfig(key, mock) {
    const [cfg] = useNpFetch('phone:np:config', { key }, { ok: true, value: mock });
    if (cfg === null) return null;
    return cfg && cfg.ok && cfg.value != null ? cfg.value : mock;
}

/* ------------------------------------------------------------------ format */

export const money = (n, cents = false) => {
    const v = Number(n) || 0;
    return `$${v.toLocaleString('en-US', {
        minimumFractionDigits: cents ? 2 : 0,
        maximumFractionDigits: cents ? 2 : 2,
    })}`;
};

export function ago(ts) {
    if (!ts) return '';
    const s = Math.max(0, Math.floor(Date.now() / 1000) - ts);
    if (s < 60) return 'just now';
    if (s < 3600) return `${Math.floor(s / 60)}m ago`;
    if (s < 86400) return `${Math.floor(s / 3600)}h ago`;
    return `${Math.floor(s / 86400)}d ago`;
}

const pad = (n) => String(n).padStart(2, '0');
export const mdy = (ts) => {
    if (!ts) return '';
    const d = new Date(ts * 1000);
    return `${pad(d.getMonth() + 1)}-${pad(d.getDate())}-${d.getFullYear()}`;
};
export const hm = (ts) => {
    if (!ts) return '';
    const d = new Date(ts * 1000);
    const h = d.getHours();
    return `${h % 12 === 0 ? 12 : h % 12}:${pad(d.getMinutes())} ${h >= 12 ? 'PM' : 'AM'}`;
};
export const initials = (name) =>
    (
        String(name || '?')
            .trim()
            .split(/\s+/)
            .map((w) => w[0])
            .join('')
            .slice(0, 2) || '?'
    ).toUpperCase();

/* ------------------------------------------------------------------ keys */

// Q / E (np:tab from useNpKeys) cycle through `ids`.
export function useTabKeys(ids, active, onChange, enabled = true) {
    const ref = useRef();
    ref.current = { ids, active, onChange, enabled };
    useEffect(() => {
        const h = (e) => {
            const { ids: list, active: cur, onChange: set, enabled: on } = ref.current;
            if (!on || !list || !list.length) return;
            const i = Math.max(0, list.indexOf(cur));
            set(list[(i + (e.detail > 0 ? 1 : -1) + list.length) % list.length]);
        };
        window.addEventListener('np:tab', h);
        return () => window.removeEventListener('np:tab', h);
    }, []);
}

// Backspace: return true from the handler when it consumed the key. Handlers form a stack:
// higher priority first, then the most recently mounted, and the first one that returns true
// wins (so a sheet closes before the screen behind it navigates back).
const backStack = [];
let backSeq = 0;
let backBound = false;

function onBackEvent(e) {
    const order = [...backStack].sort((a, b) => b.priority - a.priority || b.seq - a.seq);
    for (const entry of order) {
        if (entry.ref.current && entry.ref.current()) {
            e.preventDefault();
            return;
        }
    }
}

export function useBack(handler, priority = 0) {
    const ref = useRef(handler);
    ref.current = handler;
    useEffect(() => {
        if (!backBound) {
            window.addEventListener('np:back', onBackEvent);
            backBound = true;
        }
        const entry = { ref, priority, seq: ++backSeq };
        backStack.push(entry);
        return () => {
            const i = backStack.indexOf(entry);
            if (i >= 0) backStack.splice(i, 1);
        };
    }, [priority]);
}

// Status bar / home indicator colour for the current screen: 'dark' glyphs or 'light' glyphs.
export function useStatusTone(tone) {
    const dispatch = useDispatch();
    useEffect(() => {
        dispatch(setStatusTone(tone || null));
    }, [tone, dispatch]);
}

/* ------------------------------------------------------------------ layout */

export function NpApp({ theme = 'dark', className = '', style, children }) {
    return (
        <div className={`npk npk--${theme} ${className}`} style={style}>
            {children}
        </div>
    );
}

// Big uppercase title with the faded duplicate behind it, plus the dark caption strip.
export function BigHeader({ title, sub, right, color }) {
    return (
        <div className="npk-big">
            <div className="npk-big__row">
                <h1 className="npk-big__title" style={color ? { color } : undefined}>
                    <span className="npk-big__ghost" aria-hidden>
                        {title}
                    </span>
                    {title}
                </h1>
                {right && <div className="npk-big__right">{right}</div>}
            </div>
            {sub != null && <div className="npk-big__sub">{sub}</div>}
        </div>
    );
}

export function TopBar({ title, sub, onBack, right, className = '' }) {
    return (
        <div className={`npk-top ${className}`}>
            {onBack && (
                <button className="npk-round" onClick={onBack} aria-label="Back" data-np-back="">
                    <svg viewBox="0 0 24 24" width="1em" height="1em">
                        <path d="M14.5 5.5 8 12l6.5 6.5" fill="none" stroke="currentColor" strokeWidth="2.6" />
                    </svg>
                </button>
            )}
            <div className="npk-top__titles">
                <div className="npk-top__title">{title}</div>
                {sub && <div className="npk-top__sub">{sub}</div>}
            </div>
            {right && <div className="npk-top__right">{right}</div>}
        </div>
    );
}

export function Body({ children, className = '', pad = true, innerRef }) {
    return (
        <div ref={innerRef} className={`npk-body${pad ? ' npk-body--pad' : ''} ${className}`}>
            {children}
        </div>
    );
}

// Rounded inner panel used by Garage / Licenses / Calls / Settings.
export function Panel({ children, className = '' }) {
    return <div className={`npk-panel ${className}`}>{children}</div>;
}

/* ------------------------------------------------------------------ splash */

export function useSplash(ms = 900) {
    const [on, setOn] = useState(true);
    useEffect(() => {
        const t = setTimeout(() => setOn(false), ms);
        return () => clearTimeout(t);
    }, [ms]);
    return [on, () => setOn(false)];
}

export function Splash({ bg, icon, glyph, title, tagline, children, className = '', titleStyle }) {
    return (
        <div className={`npk-splash ${className}`} style={{ background: bg }}>
            <div className="npk-splash__inner">
                {glyph}
                {icon && <FaIcon icon={icon} className="npk-splash__icon" />}
                {title && (
                    <div className="npk-splash__title" style={titleStyle}>
                        {title}
                    </div>
                )}
                {tagline && <div className="npk-splash__tag">{tagline}</div>}
                {children}
            </div>
        </div>
    );
}

/* ------------------------------------------------------------------ tab bar */

export function Keycap({ k }) {
    return <span className="npk-key">{k}</span>;
}

// variant: 'bubble' (raised coloured bubble) | 'circle' (soft circle) | 'label' (icon + text)
export function TabBar({ tabs, active, onChange, variant = 'bubble', keys = true, className = '' }) {
    useTabKeys(
        tabs.filter((t) => !t.disabled).map((t) => t.id),
        active,
        onChange,
    );
    return (
        <nav className={`npk-tabs npk-tabs--${variant} ${className}`}>
            {keys && <Keycap k="Q" />}
            <div className="npk-tabs__items">
                {tabs.map((t) => (
                    <button
                        key={t.id}
                        className={`npk-tab${active === t.id ? ' is-on' : ''}`}
                        onClick={() => !t.disabled && onChange(t.id)}
                        disabled={t.disabled}
                        aria-label={t.label || t.id}
                    >
                        <span className="npk-tab__ico">
                            {t.icon && <FaIcon icon={t.icon} />}
                            {t.badge ? <span className="npk-tab__dot" /> : null}
                        </span>
                        {variant === 'label' && <span className="npk-tab__label">{t.label}</span>}
                    </button>
                ))}
            </div>
            {keys && <Keycap k="E" />}
        </nav>
    );
}

/* ------------------------------------------------------------------ bits */

export function Spinner() {
    return (
        <div className="npk-state">
            <span className="npk-spin" />
        </div>
    );
}

export function Empty({ title, body, icon, action, onAction }) {
    return (
        <div className="npk-state">
            {icon && <FaIcon icon={icon} className="npk-state__icon" />}
            {title && <b>{title}</b>}
            {body && <span>{body}</span>}
            {action && (
                <button className="npk-btn npk-btn--sm" onClick={onAction}>
                    {action}
                </button>
            )}
        </div>
    );
}

// Loading / error wrapper around a useNpFetch result.
export function Loaded({ data, children, onRetry }) {
    if (data === null) return <Spinner />;
    if (!data || data.ok === false)
        return (
            <Empty
                title={data && data.reason === 'unsupported' ? 'Not available on this server' : 'Couldn’t load'}
                body={data && data.message}
                action={onRetry ? 'Retry' : null}
                onAction={onRetry}
            />
        );
    return children(data);
}

export function Btn({ children, kind = 'primary', className = '', busy, ...rest }) {
    return (
        <button className={`npk-btn npk-btn--${kind} ${className}`} disabled={busy || rest.disabled} {...rest}>
            {busy ? <span className="npk-spin npk-spin--sm" /> : children}
        </button>
    );
}

export function IconBtn({ icon, className = '', ...rest }) {
    return (
        <button className={`npk-ibtn ${className}`} {...rest}>
            <FaIcon icon={icon} />
        </button>
    );
}

export function Field({ label, value, onChange, max, area, placeholder, type = 'text', counter, autoFocus, className = '', onEnter }) {
    const props = {
        value: value ?? '',
        maxLength: max,
        placeholder,
        autoFocus,
        onChange: (e) => onChange(e.target.value),
    };
    return (
        <label className={`npk-field ${className}`}>
            {label && (
                <span className="npk-field__label">
                    {label}
                    {counter && max ? (
                        <em>
                            {' '}
                            ({String(value || '').length}/{max})
                        </em>
                    ) : null}
                </span>
            )}
            {area ? (
                <textarea {...props} />
            ) : (
                <input
                    {...props}
                    type={type}
                    onKeyDown={(e) => {
                        if (e.key === 'Enter' && onEnter) {
                            e.preventDefault();
                            onEnter();
                        }
                    }}
                />
            )}
        </label>
    );
}

export function SearchBox({ value, onChange, placeholder = 'Search', className = '' }) {
    return (
        <label className={`npk-search ${className}`}>
            <svg viewBox="0 0 24 24" width="1em" height="1em">
                <circle cx="10.5" cy="10.5" r="6.5" fill="none" stroke="currentColor" strokeWidth="2.6" />
                <path d="m15.5 15.5 5 5" stroke="currentColor" strokeWidth="2.6" strokeLinecap="round" />
            </svg>
            <input value={value} placeholder={placeholder} onChange={(e) => onChange(e.target.value)} />
        </label>
    );
}

export function Chips({ items, value, onChange, className = '' }) {
    return (
        <div className={`npk-chips ${className}`}>
            {items.map((c) => {
                const id = typeof c === 'string' ? c : c.id;
                const label = typeof c === 'string' ? c : c.label;
                return (
                    <button key={id} className={`npk-chip${value === id ? ' is-on' : ''}`} onClick={() => onChange(id)}>
                        {label}
                    </button>
                );
            })}
        </div>
    );
}

export function Toggle({ on, onChange, disabled }) {
    return (
        <button
            className={`npk-toggle${on ? ' is-on' : ''}`}
            onClick={() => !disabled && onChange(!on)}
            disabled={disabled}
            role="switch"
            aria-checked={!!on}
        >
            <span />
        </button>
    );
}

export function Sheet({ title, sub, onClose, children, className = '' }) {
    useBack(() => {
        onClose && onClose();
        return true;
    }, 5);
    return (
        <div className="npk-sheet" onClick={onClose}>
            <div className={`npk-sheet__panel ${className}`} onClick={(e) => e.stopPropagation()}>
                {(title || onClose) && (
                    <div className="npk-sheet__head">
                        <div>
                            <div className="npk-sheet__title">{title}</div>
                            {sub && <div className="npk-sheet__sub">{sub}</div>}
                        </div>
                        {onClose && (
                            <button className="npk-round npk-round--sm" onClick={onClose} aria-label="Close">
                                <svg viewBox="0 0 24 24" width="1em" height="1em">
                                    <path d="M6 6l12 12M18 6 6 18" stroke="currentColor" strokeWidth="2.8" strokeLinecap="round" />
                                </svg>
                            </button>
                        )}
                    </div>
                )}
                {children}
            </div>
        </div>
    );
}

export function Bar({ label, value, color }) {
    const v = Math.max(0, Math.min(100, Math.round(Number(value) || 0)));
    return (
        <div className="npk-bar">
            <div className="npk-bar__top">
                <span>{label}</span>
                <span>{v}%</span>
            </div>
            <div className="npk-bar__track">
                <span style={{ width: `${v}%`, background: color }} />
            </div>
        </div>
    );
}

export function Msg({ kind = 'error', children }) {
    if (!children) return null;
    return <div className={`npk-msg npk-msg--${kind}`}>{children}</div>;
}
