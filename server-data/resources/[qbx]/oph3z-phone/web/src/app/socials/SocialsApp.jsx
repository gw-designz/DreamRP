// Socials — the NoPixel-style social app. It is a new front end for the existing Twexa
// backend (server/app/twexa), so accounts, posts, likes, reposts, follows and notifications
// are the same data; it is registered under the `twexa` app id for that reason.
import { useCallback, useEffect, useMemo, useState } from 'react';
import { useDispatch, useSelector } from 'react-redux';
import { faHouse, faBell, faCirclePlus, faMagnifyingGlass, faUser } from '@fortawesome/free-solid-svg-icons';
import FaIcon from '../../np/FaIcon';
import './Socials.css';
import { loadSession, clearCapture, clearPendingCompose } from '../../store/slices/xSlice';
import { clearNotifsFor } from '../../store/slices/notificationsSlice';
import { clearDeliver } from '../../store/slices/airdropSlice';
import { useBack, useTabKeys } from '../../np/ui/kit';
import { SocialsNavContext } from './SocialsNav';
import FeedView from './FeedView';
import ThreadView from './ThreadView';
import ComposeView from './ComposeView';
import { NotifsView, SearchView, ProfileView, FollowListView, EditProfileView, ListView } from './OtherViews';
import { JoinScreen, MenuView, RelationsView } from './SocialsMenu';
import { SocialsLogo } from './parts';

const TABS = ['home', 'notifs', 'compose', 'search', 'profile'];
const TAB_ICONS = { home: faHouse, notifs: faBell, compose: faCirclePlus, search: faMagnifyingGlass, profile: faUser };
const SPLASH_MS = 650;

export default function SocialsApp() {
    const dispatch = useDispatch();
    const me = useSelector((s) => s.x.me);
    const loaded = useSelector((s) => s.x.loaded);
    const capture = useSelector((s) => s.x.capture);
    const pendingCompose = useSelector((s) => s.x.pendingCompose);
    const deliver = useSelector((s) => s.airdrop.deliver);
    const unreadNotifs = useSelector((s) => s.notifications.items.reduce((a, n) => a + (!n.read && n.app === 'twexa' ? 1 : 0), 0));

    const [splash, setSplash] = useState(true);
    const [tab, setTab] = useState('home');
    const [stack, setStack] = useState([]);
    const [reloadToken, setReloadToken] = useState(0);
    const [composeMedia, setComposeMedia] = useState(null);
    const [composeKey, setComposeKey] = useState(0);

    useEffect(() => {
        dispatch(loadSession());
        dispatch(clearNotifsFor({ app: 'twexa' }));
        const t = setTimeout(() => setSplash(false), SPLASH_MS);
        return () => clearTimeout(t);
    }, [dispatch]);

    const bump = useCallback(() => setReloadToken((n) => n + 1), []);
    const push = useCallback((view) => setStack((s) => [...s, view]), []);
    const pop = useCallback(() => setStack((s) => s.slice(0, -1)), []);
    const goTab = useCallback((id) => {
        setStack([]);
        setTab(id);
    }, []);

    // Photo taken from Compose → Camera comes back here.
    useEffect(() => {
        if (pendingCompose && me) {
            setComposeMedia(capture ? [{ url: capture.url, type: capture.type }] : null);
            setComposeKey((k) => k + 1);
            goTab('compose');
            dispatch(clearPendingCompose());
            dispatch(clearCapture());
        }
    }, [pendingCompose, capture, me, goTab, dispatch]);

    // Profile shared via ShareDrop.
    useEffect(() => {
        if (deliver && deliver.appId === 'twexa' && me) {
            const handle = deliver.payload && deliver.payload.handle;
            dispatch(clearDeliver());
            if (handle) push({ name: 'profile', target: { handle } });
        }
    }, [deliver, me, push, dispatch]);

    // Backspace walks our own stack first, then returns to the feed. Q / E cycle the bottom bar.
    useBack(() => {
        if (!me) return false;
        if (stack.length) return pop(), true;
        if (tab !== 'home') return setTab('home'), true;
        return false;
    });
    useTabKeys(TABS, stack.length ? null : tab, goTab, !!me);

    const nav = useMemo(
        () => ({
            openPost: (id, opts) => push({ name: 'post', id, reply: !!(opts && opts.reply) }),
            openProfile: (target) => {
                if (target && me && String(target.id) === String(me.id)) goTab('profile');
                else push({ name: 'profile', target: target || {} });
            },
            openTopic: (tag) => push({ name: 'topic', tag }),
            openFollowList: (target) => push({ name: 'follows', target }),
        }),
        [push, goTab, me],
    );

    if (splash || !loaded) return <Splash />;
    if (!me) return <JoinScreen />;

    const openMenu = () => push({ name: 'menu' });

    const renderTab = () => {
        switch (tab) {
            case 'notifs':
                return <NotifsView onMenu={openMenu} />;
            case 'compose':
                return (
                    <ComposeView
                        key={composeKey}
                        me={me}
                        initialMedia={composeMedia}
                        onMenu={openMenu}
                        onPosted={() => {
                            setComposeMedia(null);
                            bump();
                            goTab('home');
                        }}
                    />
                );
            case 'search':
                return <SearchView onMenu={openMenu} />;
            case 'profile':
                return <ProfileView me={me} reloadToken={reloadToken} onMenu={openMenu} onEdit={() => push({ name: 'edit' })} />;
            default:
                return null;
        }
    };

    const renderView = (v) => {
        if (v.name === 'post') return <ThreadView key={`p${v.id}`} id={v.id} me={me} focusReply={v.reply} onBack={pop} onChanged={bump} />;
        if (v.name === 'profile')
            return <ProfileView target={v.target} me={me} reloadToken={reloadToken} onBack={pop} onEdit={() => push({ name: 'edit' })} onChanged={bump} />;
        if (v.name === 'topic')
            return <ListView title={`#${v.tag}`} endpoint="phone:x:topic" payload={{ tag: v.tag }} me={me} empty="No posts with this tag" onBack={pop} />;
        if (v.name === 'bookmarks') return <ListView title="Bookmarks" endpoint="phone:x:bookmarks" me={me} empty="Bookmarked posts show up here." onBack={pop} />;
        if (v.name === 'follows') return <FollowListView target={v.target} onBack={pop} />;
        if (v.name === 'menu') return <MenuView me={me} onBack={pop} onOpen={push} />;
        if (v.name === 'relations') return <RelationsView type={v.type} onBack={pop} onChanged={bump} />;
        if (v.name === 'edit')
            return (
                <EditProfileView
                    me={me}
                    onBack={pop}
                    onSaved={() => {
                        pop();
                        bump();
                    }}
                />
            );
        return null;
    };

    const top = stack[stack.length - 1];
    const activeIcon = top ? null : tab;

    return (
        <SocialsNavContext.Provider value={nav}>
            <div className="sc-app">
                <div className="sc-body">
                    {/* The home feed stays mounted so its scroll position survives threads/tabs. */}
                    <div className={`sc-layer${tab !== 'home' || top ? ' is-hidden' : ''}`}>
                        <FeedView me={me} reloadToken={reloadToken} onMenu={openMenu} onCompose={() => goTab('compose')} />
                    </div>
                    {tab !== 'home' && !top && <div className="sc-layer sc-layer--in">{renderTab()}</div>}
                    {top && (
                        <div className="sc-layer sc-layer--in" key={stack.length}>
                            {renderView(top)}
                        </div>
                    )}
                </div>

                <nav className="sc-nav">
                    <span className="sc-nav__key" aria-hidden>
                        Q
                    </span>
                    {TABS.map((id) => (
                        <button key={id} className={`sc-nav__btn sc-nav__btn--${id}${activeIcon === id ? ' is-on' : ''}`} onClick={() => goTab(id)} aria-label={id}>
                            <FaIcon icon={TAB_ICONS[id]} />
                            {id === 'notifs' && unreadNotifs > 0 && <span className="sc-nav__dot" />}
                        </button>
                    ))}
                    <span className="sc-nav__key" aria-hidden>
                        E
                    </span>
                </nav>
            </div>
        </SocialsNavContext.Provider>
    );
}

function Splash() {
    return (
        <div className="sc-app sc-splash">
            <SocialsLogo />
        </div>
    );
}
