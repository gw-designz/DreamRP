import { useCallback, useEffect, useState } from 'react';
import { useDispatch } from 'react-redux';
import { faMagnifyingGlass, faHeart, faRetweet, faComment, faUserPlus, faAt } from '@fortawesome/free-solid-svg-icons';
import FaIcon from '../../np/FaIcon';
import { fetchNui } from '../../utils/fetchNui';
import { pushToast } from '../../store/slices/toastSlice';
import { setMe } from '../../store/slices/xSlice';
import { openDialog } from '../../store/slices/dialogSlice';
import { SHeader, MenuButton, BackButton, Loading, StateMsg, PostList } from './parts';
import { SAvatar } from './PostCard';
import { feedDate, fmtCount, patchPosts, dropPost } from './socialsUtil';
import { useSocialsNav } from './SocialsNav';
import { MOCK_NOTIFS, MOCK_PROFILE, MOCK_FEED } from './mockSocials';

const NOTIF_ICON = { like: faHeart, repost: faRetweet, reply: faComment, follow: faUserPlus, mention: faAt };

/* ---------------- notifications ---------------- */
export function NotifsView({ onMenu }) {
    const nav = useSocialsNav();
    const [items, setItems] = useState(null);
    const [nonce, setNonce] = useState(0);
    useEffect(() => {
        let alive = true;
        fetchNui('phone:x:notifs', {}, { ok: true, items: MOCK_NOTIFS }).then((r) => {
            if (alive) setItems(r && r.ok ? r.items || [] : false);
        });
        return () => {
            alive = false;
        };
    }, [nonce]);

    return (
        <div className="sc-screen">
            <SHeader left={<MenuButton onClick={onMenu} />} title="Notifications" />
            <div className="sc-scroll">
                {items === null && <Loading />}
                {items === false && <StateMsg title="Couldn’t load notifications" action="Retry" onAction={() => setNonce((n) => n + 1)} />}
                {items && !items.length && <StateMsg title="No notifications yet" body="Likes, replies and follows show up here." />}
                {items && items.length > 0 && (
                    <div className="sc-list">
                        {items.map((n) => (
                            <button
                                key={n.id}
                                className={`sc-row${n.read ? '' : ' is-unread'}`}
                                onClick={() =>
                                    n.postId ? nav.openPost(n.postId) : nav.openProfile({ id: n.actor && n.actor.id })
                                }
                            >
                                <span className={`sc-row__icon sc-row__icon--${n.type}`}>
                                    <FaIcon icon={NOTIF_ICON[n.type] || faHeart} />
                                </span>
                                <SAvatar account={n.actor} />
                                <span className="sc-row__text">
                                    <b>{n.actor ? n.actor.name : 'Someone'}</b> {n.verb}
                                </span>
                                <span className="sc-row__time">{feedDate(n.ts)}</span>
                            </button>
                        ))}
                    </div>
                )}
            </div>
        </div>
    );
}

/* ---------------- search ---------------- */
export function SearchView({ onMenu }) {
    const nav = useSocialsNav();
    const [q, setQ] = useState('');
    const [accounts, setAccounts] = useState([]);
    const [topics, setTopics] = useState(null);
    const [searching, setSearching] = useState(false);

    useEffect(() => {
        fetchNui('phone:x:topics', {}, { ok: true, topics: [{ tag: 'guber', count: 3 }, { tag: 'lossantos', count: 1 }] }).then(
            (r) => setTopics(r && r.ok ? r.topics || [] : []),
        );
    }, []);

    useEffect(() => {
        const query = q.trim();
        if (!query) {
            setAccounts([]);
            setSearching(false);
            return undefined;
        }
        setSearching(true);
        const t = setTimeout(() => {
            fetchNui('phone:x:search', { q: query }, { ok: true, accounts: [MOCK_PROFILE] }).then((r) => {
                setAccounts(r && r.ok ? r.accounts || [] : []);
                setSearching(false);
            });
        }, 300);
        return () => clearTimeout(t);
    }, [q]);

    return (
        <div className="sc-screen">
            <SHeader left={<MenuButton onClick={onMenu} />} title="Search" />
            <div className="sc-search">
                <FaIcon icon={faMagnifyingGlass} />
                <input value={q} placeholder="Search people" onChange={(e) => setQ(e.target.value)} />
            </div>
            <div className="sc-scroll">
                {q.trim() ? (
                    searching ? (
                        <Loading />
                    ) : accounts.length ? (
                        <div className="sc-list">
                            {accounts.map((a) => (
                                <AccountRow key={a.id} account={a} onOpen={() => nav.openProfile({ id: a.id })} />
                            ))}
                        </div>
                    ) : (
                        <StateMsg title="No people found" />
                    )
                ) : (
                    <>
                        <div className="sc-section">Trending</div>
                        {topics === null ? (
                            <Loading />
                        ) : topics.length ? (
                            <div className="sc-list">
                                {topics.map((t) => (
                                    <button key={t.tag} className="sc-row" onClick={() => nav.openTopic(t.tag)}>
                                        <span className="sc-row__text">
                                            <b>#{t.tag}</b>
                                            <small>{fmtCount(t.count)} posts</small>
                                        </span>
                                    </button>
                                ))}
                            </div>
                        ) : (
                            <StateMsg title="Nothing trending yet" />
                        )}
                    </>
                )}
            </div>
        </div>
    );
}

export function AccountRow({ account, onOpen }) {
    return (
        <button className="sc-row" onClick={onOpen}>
            <SAvatar account={account} />
            <span className="sc-row__text">
                <b>{account.name}</b>
                <small>@{account.handle}</small>
            </span>
            {account.followersCount != null && (
                <span className="sc-row__time">{fmtCount(account.followersCount)} followers</span>
            )}
        </button>
    );
}

/* ---------------- post lists (topic / bookmarks) ---------------- */
export function ListView({ title, endpoint, payload, mock, empty, me, onBack }) {
    const [items, setItems] = useState(null);
    const [nonce, setNonce] = useState(0);
    const key = JSON.stringify(payload || {});
    useEffect(() => {
        let alive = true;
        fetchNui(endpoint, payload || {}, { ok: true, items: mock || [] }).then((r) => {
            if (alive) setItems(r && r.ok ? r.items || [] : false);
        });
        return () => {
            alive = false;
        };
        // eslint-disable-next-line react-hooks/exhaustive-deps
    }, [endpoint, key, nonce]);
    const onPatch = useCallback((id, p) => setItems((l) => patchPosts(l, id, p)), []);
    const onRemoved = useCallback((id) => setItems((l) => dropPost(l, id)), []);
    return (
        <div className="sc-screen">
            <SHeader left={<BackButton onClick={onBack} />} title={title} />
            <div className="sc-scroll">
                <PostList
                    items={items}
                    me={me}
                    onPatch={(id, p) => {
                        onPatch(id, p);
                        if (endpoint === 'phone:x:bookmarks' && p.bookmarked === false) onRemoved(id);
                    }}
                    onRemoved={onRemoved}
                    empty={empty}
                    onRetry={() => setNonce((n) => n + 1)}
                />
            </div>
        </div>
    );
}

/* ---------------- profile ---------------- */
export function ProfileView({ target, me, reloadToken, onMenu, onBack, onEdit, onChanged }) {
    const nav = useSocialsNav();
    const dispatch = useDispatch();
    const [profile, setProfile] = useState(null);
    const [tab, setTab] = useState('posts');
    const [nonce, setNonce] = useState(0);
    const [busy, setBusy] = useState(false);
    const key = JSON.stringify(target || {});

    useEffect(() => {
        let alive = true;
        fetchNui('phone:x:profile', target || {}, { ok: true, profile: MOCK_PROFILE }).then((r) => {
            if (!alive) return;
            setProfile(r && r.ok ? r.profile : r && r.reason === 'notfound' ? 'missing' : false);
        });
        return () => {
            alive = false;
        };
        // eslint-disable-next-line react-hooks/exhaustive-deps
    }, [key, reloadToken, nonce]);

    const patch = useCallback(
        (id, p) =>
            setProfile((pr) =>
                pr && typeof pr === 'object'
                    ? { ...pr, posts: patchPosts(pr.posts, id, p), replies: patchPosts(pr.replies, id, p) }
                    : pr,
            ),
        [],
    );
    const removed = useCallback(
        (id) =>
            setProfile((pr) =>
                pr && typeof pr === 'object'
                    ? { ...pr, posts: dropPost(pr.posts, id), replies: dropPost(pr.replies, id) }
                    : pr,
            ),
        [],
    );

    const follow = async () => {
        if (busy || !profile || typeof profile !== 'object') return;
        setBusy(true);
        const on = !profile.isFollowing;
        const r = await fetchNui('phone:x:follow', { id: profile.id, on }, { ok: true, following: on, followersCount: profile.followersCount + (on ? 1 : -1) });
        setBusy(false);
        if (r && r.ok) setProfile((p) => ({ ...p, isFollowing: !!r.following, followersCount: r.followersCount }));
        else dispatch(pushToast({ title: 'Socials', body: 'Could not update follow.' }));
    };

    const relation = async (kind) => {
        if (!profile || typeof profile !== 'object') return;
        const field = kind === 'block' ? 'isBlocked' : 'isMuted';
        const on = !profile[field];
        if (kind === 'block' && on) {
            const ok = await dispatch(
                openDialog({
                    title: `Block @${profile.handle}?`,
                    message: 'They won’t see your posts and you won’t see theirs. Follows between you are removed.',
                    buttons: [
                        { text: 'Cancel', style: 'cancel', value: false },
                        { text: 'Block', style: 'destructive', value: true },
                    ],
                }),
            );
            if (!ok) return;
        }
        const r = await fetchNui(`phone:x:${kind}`, { id: profile.id, on }, { ok: true });
        if (r && r.ok) {
            setProfile((p) => ({ ...p, [field]: on, ...(kind === 'block' && on ? { isFollowing: false } : {}) }));
            onChanged && onChanged();
            dispatch(pushToast({ title: 'Socials', body: `${on ? (kind === 'block' ? 'Blocked' : 'Muted') : kind === 'block' ? 'Unblocked' : 'Unmuted'} @${profile.handle}` }));
        } else dispatch(pushToast({ title: 'Socials', body: 'That didn’t work.' }));
    };

    const header = (
        <SHeader
            left={onBack ? <BackButton onClick={onBack} /> : <MenuButton onClick={onMenu} />}
            title="Profile"
        />
    );

    if (profile === null || profile === false || profile === 'missing')
        return (
            <div className="sc-screen">
                {header}
                <div className="sc-scroll">
                    {profile === null && <Loading />}
                    {profile === false && <StateMsg title="Couldn’t load profile" action="Retry" onAction={() => setNonce((n) => n + 1)} />}
                    {profile === 'missing' && <StateMsg title="This account doesn’t exist" />}
                </div>
            </div>
        );

    const list = tab === 'posts' ? profile.posts : profile.replies;
    const tabs = [
        { id: 'posts', label: 'Posts' },
        { id: 'replies', label: 'Replies' },
    ];
    if (profile.isMe) tabs.push({ id: 'bookmarks', label: 'Saved' });
    const idx = tabs.findIndex((t) => t.id === tab);

    return (
        <div className="sc-screen">
            {header}
            <div className="sc-scroll">
                <div className="sc-profile">
                    <SAvatar account={profile} size="3.6em" />
                    <div className="sc-profile__id">
                        <div className="sc-profile__name">{profile.name}</div>
                        <div className="sc-profile__handle">@{profile.handle}</div>
                    </div>
                    {profile.isMe ? (
                        <button className="sc-pillbtn sc-pillbtn--ghost" onClick={onEdit}>
                            Edit
                        </button>
                    ) : (
                        <button
                            className={`sc-pillbtn${profile.isFollowing ? ' sc-pillbtn--ghost' : ''}`}
                            onClick={follow}
                            disabled={busy || profile.isBlocked || profile.blockedYou}
                        >
                            {profile.isFollowing ? 'Following' : 'Follow'}
                        </button>
                    )}
                    {!profile.isMe && (
                        <div className="sc-profile__rel">
                            <button onClick={() => relation('mute')}>{profile.isMuted ? 'Unmute' : 'Mute'}</button>
                            <button className="is-danger" onClick={() => relation('block')}>
                                {profile.isBlocked ? 'Unblock' : 'Block'}
                            </button>
                        </div>
                    )}
                    {profile.bio ? <div className="sc-profile__bio">{profile.bio}</div> : null}
                    <div className="sc-profile__counts">
                        <button onClick={() => nav.openFollowList({ id: profile.id, type: 'following', name: profile.name })}>
                            <b>{fmtCount(profile.followingCount)}</b> Following
                        </button>
                        <button onClick={() => nav.openFollowList({ id: profile.id, type: 'followers', name: profile.name })}>
                            <b>{fmtCount(profile.followersCount)}</b> Followers
                        </button>
                    </div>
                </div>
                <div className="sc-tabs sc-tabs--inline" style={{ '--tabs': tabs.length, '--tab': idx }}>
                    {tabs.map((t) => (
                        <button key={t.id} className={`sc-tabs__tab${tab === t.id ? ' is-on' : ''}`} onClick={() => setTab(t.id)}>
                            {t.label}
                        </button>
                    ))}
                    <span className="sc-tabs__bar" />
                </div>
                {profile.isBlocked || profile.blockedYou ? (
                    <StateMsg title={profile.isBlocked ? `You blocked @${profile.handle}` : 'You can’t see these posts'} />
                ) : tab === 'bookmarks' ? (
                    <BookmarkList me={me} />
                ) : (
                    <PostList
                        items={list || []}
                        me={me}
                        onPatch={patch}
                        onRemoved={removed}
                        showDelete={profile.isMe}
                        empty={tab === 'posts' ? 'No posts yet' : 'No replies yet'}
                    />
                )}
            </div>
        </div>
    );
}

function BookmarkList({ me }) {
    const [items, setItems] = useState(null);
    useEffect(() => {
        fetchNui('phone:x:bookmarks', {}, { ok: true, items: MOCK_FEED.filter((p) => p.bookmarked) }).then((r) =>
            setItems(r && r.ok ? r.items || [] : false),
        );
    }, []);
    return (
        <PostList
            items={items}
            me={me}
            onPatch={(id, p) =>
                setItems((l) => (p.bookmarked === false ? dropPost(l, id) : patchPosts(l, id, p)))
            }
            onRemoved={(id) => setItems((l) => dropPost(l, id))}
            empty="Bookmarked posts show up here."
        />
    );
}

/* ---------------- followers / following ---------------- */
export function FollowListView({ target, onBack }) {
    const nav = useSocialsNav();
    const [items, setItems] = useState(null);
    useEffect(() => {
        fetchNui('phone:x:followList', { id: target.id, type: target.type }, { ok: true, accounts: [] }).then((r) =>
            setItems(r && r.ok ? r.accounts || [] : false),
        );
    }, [target.id, target.type]);
    return (
        <div className="sc-screen">
            <SHeader left={<BackButton onClick={onBack} />} title={target.type === 'following' ? 'Following' : 'Followers'} />
            <div className="sc-scroll">
                {items === null && <Loading />}
                {items === false && <StateMsg title="Couldn’t load this list" />}
                {items && !items.length && <StateMsg title="Nobody here yet" />}
                {items && items.length > 0 && (
                    <div className="sc-list">
                        {items.map((a) => (
                            <AccountRow key={a.id} account={a} onOpen={() => nav.openProfile({ id: a.id })} />
                        ))}
                    </div>
                )}
            </div>
        </div>
    );
}

/* ---------------- edit profile ---------------- */
export function EditProfileView({ me, onBack, onSaved }) {
    const dispatch = useDispatch();
    const [form, setForm] = useState(null);
    const [busy, setBusy] = useState(false);
    const [err, setErr] = useState('');

    useEffect(() => {
        fetchNui('phone:x:profile', {}, { ok: true, profile: MOCK_PROFILE }).then((r) => {
            const p = (r && r.ok && r.profile) || me || {};
            setForm({ name: p.name || '', handle: p.handle || '', bio: p.bio || '', avatar: p.avatar || '' });
        });
    }, [me]);

    const save = async () => {
        if (!form || busy) return;
        if (form.avatar && !/^https?:\/\//i.test(form.avatar)) {
            setErr('Avatar must be an http(s) image link.');
            return;
        }
        setBusy(true);
        setErr('');
        const r = await fetchNui(
            'phone:x:editProfile',
            { name: form.name, handle: form.handle, bio: form.bio, avatar: form.avatar || false },
            { ok: true, me: { ...me, ...form } },
        );
        setBusy(false);
        if (r && r.ok) {
            if (r.me) dispatch(setMe(r.me));
            onSaved();
        } else {
            setErr(
                r && r.reason === 'taken'
                    ? 'That @handle is taken.'
                    : r && r.reason === 'handle'
                      ? 'Handles are 3–15 letters, numbers or _.'
                      : 'Could not save your profile.',
            );
        }
    };

    const field = (k, label, opts = {}) => (
        <label className="sc-field">
            <span>{label}</span>
            {opts.area ? (
                <textarea value={form[k]} maxLength={opts.max} onChange={(e) => setForm({ ...form, [k]: e.target.value })} />
            ) : (
                <input value={form[k]} maxLength={opts.max} placeholder={opts.ph} onChange={(e) => setForm({ ...form, [k]: e.target.value })} />
            )}
        </label>
    );

    return (
        <div className="sc-screen">
            <SHeader
                left={<BackButton onClick={onBack} />}
                title="Edit Profile"
                right={
                    <button className="sc-pillbtn" onClick={save} disabled={busy || !form}>
                        {busy ? 'Saving…' : 'Save'}
                    </button>
                }
            />
            <div className="sc-scroll sc-form">
                {!form ? (
                    <Loading />
                ) : (
                    <>
                        {field('name', 'Display name', { max: 40 })}
                        {field('handle', 'Handle', { max: 15 })}
                        {field('bio', 'Bio', { area: true, max: 160 })}
                        {field('avatar', 'Avatar image URL', { max: 500, ph: 'https://…' })}
                        {err && <div className="sc-compose__err">{err}</div>}
                    </>
                )}
            </div>
        </div>
    );
}
