// Notification panel (tap the status-bar clock). Lists the phone's stored notifications;
// tapping one opens its app, the bell toggles notifications on/off.
import { useDispatch, useSelector } from 'react-redux';
import { faBellSlash, faBell, faXmark, faTrash } from '@fortawesome/free-solid-svg-icons';
import FaIcon from './FaIcon';
import { NpAppIcon } from './npIcons';
import { setCenterOpen, openRoute, clearNotification } from '../store/slices/notificationsSlice';
import { saveSetting } from '../store/slices/settingsSlice';
import { ago, useBack } from './ui/kit';
import './NpNotifications.css';

const APP_ICON = { airdrop: 'photos', system: 'settings' };

export default function NpNotifications() {
    const dispatch = useDispatch();
    const open = useSelector((s) => s.notifications.centerOpen);
    const items = useSelector((s) => s.notifications.items);
    const muted = useSelector((s) => s.settings.notifMaster === false);
    const labels = useSelector((s) => s.apps.layout);

    useBack(() => {
        if (!open) return false;
        dispatch(setCenterOpen(false));
        return true;
    }, 10);

    if (!open) return null;
    const labelOf = (id) => (labels.find((a) => a.id === id) || {}).label || id;

    return (
        <div className="npn" onClick={() => dispatch(setCenterOpen(false))}>
            <div className="npn__panel" onClick={(e) => e.stopPropagation()}>
                <div className="npn__head">
                    <span>Notifications</span>
                    <button
                        className={`npn__btn${muted ? ' is-on' : ''}`}
                        onClick={() => dispatch(saveSetting('notifMaster', muted))}
                        title={muted ? 'Notifications off' : 'Turn notifications off'}
                    >
                        <FaIcon icon={muted ? faBellSlash : faBell} />
                    </button>
                    {items.length > 0 && (
                        <button className="npn__btn" onClick={() => dispatch(clearNotification())} title="Clear all">
                            <FaIcon icon={faTrash} />
                        </button>
                    )}
                    <button className="npn__btn" onClick={() => dispatch(setCenterOpen(false))} aria-label="Close">
                        <FaIcon icon={faXmark} />
                    </button>
                </div>
                <div className="npn__list">
                    {items.length === 0 && <div className="npn__empty">You’re all caught up.</div>}
                    {items.map((n) => (
                        <button
                            key={n.id}
                            className={`npn__item${n.read ? '' : ' is-unread'}`}
                            onClick={() => dispatch(openRoute(n.route, n.id))}
                        >
                            <span className="npn__icon">
                                <NpAppIcon id={APP_ICON[n.app] || n.app} label={labelOf(n.app)} />
                            </span>
                            <span className="npn__main">
                                <span className="npn__title">{n.title || labelOf(n.app)}</span>
                                <span className="npn__body">{n.body}</span>
                            </span>
                            <span className="npn__time">{ago(n.ts)}</span>
                        </button>
                    ))}
                </div>
                <div className="npn__grab" />
            </div>
        </div>
    );
}
