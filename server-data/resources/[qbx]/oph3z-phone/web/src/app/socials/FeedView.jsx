import { useCallback, useEffect, useRef, useState } from 'react';
import { useSelector } from 'react-redux';
import { faPenToSquare, faArrowUp } from '@fortawesome/free-solid-svg-icons';
import FaIcon from '../../np/FaIcon';
import { fetchNui } from '../../utils/fetchNui';
import { SHeader, MenuButton, PostList } from './parts';
import { patchPosts, dropPost } from './socialsUtil';
import { MOCK_FEED } from './mockSocials';

const TABS = [
    { id: 'foryou', label: 'All' },
    { id: 'following', label: 'Following' },
];

export default function FeedView({ me, reloadToken, onMenu, onCompose }) {
    const liveTick = useSelector((s) => s.x.liveTick);
    const freshTick = useSelector((s) => s.x.freshTick);
    const [tab, setTab] = useState('foryou');
    const [items, setItems] = useState(null);
    const [nonce, setNonce] = useState(0);
    const seenFresh = useRef(freshTick);
    const scrollRef = useRef(null);

    useEffect(() => {
        let alive = true;
        setItems((cur) => (cur && cur.length ? cur : null));
        fetchNui('phone:x:feed', { tab }, { ok: true, items: tab === 'foryou' ? MOCK_FEED : [] }).then(
            (r) => {
                if (!alive) return;
                setItems(r && r.ok ? r.items || [] : false);
                seenFresh.current = freshTick;
            },
        );
        return () => {
            alive = false;
        };
        // freshTick is intentionally not a dependency: new posts show a pill instead.
        // eslint-disable-next-line react-hooks/exhaustive-deps
    }, [tab, reloadToken, liveTick, nonce]);

    const switchTab = (id) => {
        if (id === tab) return;
        setItems(null);
        setTab(id);
        if (scrollRef.current) scrollRef.current.scrollTop = 0;
    };

    const onPatch = useCallback((id, patch) => setItems((l) => patchPosts(l, id, patch)), []);
    const onRemoved = useCallback((id) => setItems((l) => dropPost(l, id)), []);

    const hasFresh = freshTick > seenFresh.current;
    const idx = TABS.findIndex((t) => t.id === tab);

    return (
        <div className="sc-screen">
            <SHeader
                centered
                left={<MenuButton onClick={onMenu} />}
                title="Socials"
                right={
                    <button className="sc-sqbtn sc-sqbtn--blue" onClick={onCompose} aria-label="New post">
                        <FaIcon icon={faPenToSquare} />
                    </button>
                }
            />
            <div className="sc-tabs" style={{ '--tabs': TABS.length, '--tab': idx }}>
                {TABS.map((t) => (
                    <button
                        key={t.id}
                        className={`sc-tabs__tab${tab === t.id ? ' is-on' : ''}`}
                        onClick={() => switchTab(t.id)}
                    >
                        {t.label}
                    </button>
                ))}
                <span className="sc-tabs__bar" />
            </div>

            <div className="sc-scroll" ref={scrollRef}>
                {hasFresh && (
                    <button
                        className="sc-fresh"
                        onClick={() => {
                            if (scrollRef.current) scrollRef.current.scrollTop = 0;
                            setNonce((n) => n + 1);
                        }}
                    >
                        <FaIcon icon={faArrowUp} /> New posts
                    </button>
                )}
                <PostList
                    items={items}
                    me={me}
                    onPatch={onPatch}
                    onRemoved={onRemoved}
                    onRetry={() => {
                        setItems(null);
                        setNonce((n) => n + 1);
                    }}
                    empty={
                        tab === 'following'
                            ? 'Posts from people you follow show up here.'
                            : 'No posts yet. Be the first!'
                    }
                />
            </div>
        </div>
    );
}
