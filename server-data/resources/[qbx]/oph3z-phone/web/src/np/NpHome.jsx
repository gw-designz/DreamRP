import { useEffect, useMemo } from 'react';
import { useDispatch, useSelector } from 'react-redux';
import './NpHome.css';
import { openApp, setLaunchTab } from '../store/slices/phoneSlice';
import { reconcile, saveHome, appIsInstalled } from '../store/slices/homeSlice';
import { useAvailableApps } from '../app/useAvailableApps';
import { fetchNui } from '../utils/fetchNui';
import { playSound } from './sound';
import { usePhoneClock } from './usePhoneClock';
import { NpAppIcon, DOCK_GLYPHS } from './npIcons';
import FaIcon from './FaIcon';

const unread = (items, id) => items.reduce((a, n) => a + (!n.read && n.app === id ? 1 : 0), 0);

// Opens an app id from the home grid or dock. `contacts` is the Phone app's Contacts tab;
// entries with a bridge (clientEvent / command in Config.Apps) hand off to another resource.
export function launchApp(dispatch, entry) {
    if (!entry) return;
    playSound('open');
    if (entry.bridge) {
        fetchNui('phone:np:bridge', { id: entry.id }, { ok: true });
        return;
    }
    if (entry.id === 'contacts') {
        dispatch(setLaunchTab('contacts'));
        dispatch(openApp('call'));
        return;
    }
    dispatch(openApp(entry.id));
}

// The home grid and dock entries, shared by the NoPixel and iPhone Duo home screens.
export function useHomeApps() {
    const dispatch = useDispatch();
    const { list } = useAvailableApps();
    const layout = useSelector((s) => s.apps.layout);
    const home = useSelector((s) => s.home);
    const external = useSelector((s) => s.apps.external);

    // Keep the saved home layout in sync so App Store installs / uninstalls keep working.
    const idsKey = list.map((a) => a.id).join(',');
    useEffect(() => {
        dispatch(reconcile({ apps: list }));
        dispatch(saveHome());
        // eslint-disable-next-line react-hooks/exhaustive-deps
    }, [idsKey]);

    return useMemo(() => {
        const rootish = { home, apps: { external } };
        const extra = {};
        for (const e of layout) extra[e.id] = e;
        const visible = list.filter((a) => {
            // Store-gated and third-party apps only show once installed.
            if (a.store || a.external) return appIsInstalled(rootish, a.id);
            return true;
        });
        const decorate = (a) => ({
            ...a,
            bridge: !!(extra[a.id] && (extra[a.id].clientEvent || extra[a.id].command)),
        });
        return {
            grid: visible.filter((a) => a.place !== 'dock' && a.place !== 'hidden').map(decorate),
            dock: list.filter((a) => a.place === 'dock').map(decorate),
        };
    }, [list, layout, home, external]);
}

export default function NpHome() {
    const dispatch = useDispatch();
    const zone = useSelector((s) => s.phone.zone);
    const showLocation = useSelector((s) => s.phone.ui.showLocation);
    const clock = usePhoneClock();
    const { grid, dock } = useHomeApps();

    return (
        <div className="np-home">
            <div className="np-home__clock">
                <span className="np-home__ghost" aria-hidden>
                    {clock}
                </span>
                <span className="np-home__time">{clock}</span>
            </div>

            {showLocation && zone ? (
                <div className="np-home__zone">
                    <span>{zone}</span>
                </div>
            ) : (
                <div className="np-home__zone np-home__zone--empty" />
            )}

            <div className="np-home__grid">
                {grid.map((a) => (
                    <HomeTile key={a.id} app={a} onOpen={() => launchApp(dispatch, a)} />
                ))}
            </div>

            <nav className="np-dock">
                {dock.map((a) => (
                    <DockButton key={a.id} app={a} onOpen={() => launchApp(dispatch, a)} />
                ))}
            </nav>
        </div>
    );
}

function HomeTile({ app, onOpen }) {
    const count = useSelector((s) => unread(s.notifications.items, app.id));
    const dl = useSelector((s) => s.home.downloads[app.id]);
    const downloading = dl != null;
    return (
        <button
            className={`np-app${downloading ? ' is-downloading' : ''}`}
            onClick={downloading ? undefined : onOpen}
            data-app={app.id}
        >
            <span className="np-app__icon">
                <NpAppIcon id={app.id} iconUrl={app.external ? app.icon : null} label={app.label} />
                {downloading && (
                    <span className="np-app__dl">
                        <span style={{ width: `${Math.round(dl * 100)}%` }} />
                    </span>
                )}
                {!downloading && count > 0 && (
                    <span className="np-app__badge">{count > 99 ? '99+' : count}</span>
                )}
            </span>
            <span className="np-app__label">{app.label}</span>
        </button>
    );
}

function DockButton({ app, onOpen }) {
    const target = app.id === 'contacts' ? 'call' : app.id;
    const count = useSelector((s) =>
        app.id === 'contacts' ? 0 : unread(s.notifications.items, target),
    );
    const glyph = DOCK_GLYPHS[app.id];
    return (
        <button className="np-dock__btn" onClick={onOpen} aria-label={app.label}>
            {typeof glyph === 'function' ? (
                glyph()
            ) : glyph ? (
                <FaIcon icon={glyph} />
            ) : (
                <span className="np-dock__letter">{(app.label || '?').charAt(0)}</span>
            )}
            {count > 0 && <span className="np-dock__badge" />}
        </button>
    );
}
