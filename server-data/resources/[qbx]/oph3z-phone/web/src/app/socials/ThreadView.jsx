import { useCallback, useEffect, useRef, useState } from 'react';
import { useDispatch } from 'react-redux';
import { faImage, faPaperPlane, faXmark } from '@fortawesome/free-solid-svg-icons';
import FaIcon from '../../np/FaIcon';
import { fetchNui } from '../../utils/fetchNui';
import { pushToast } from '../../store/slices/toastSlice';
import PhotoPickerSheet from '../mail/PhotoPickerSheet';
import { SHeader, BackButton, Loading, StateMsg, PostList } from './parts';
import { SAvatar, RichText, PostMedia, ActionRow, usePostActions } from './PostCard';
import { patchPosts, dropPost, threadDate, fmtCount, MAX_POST } from './socialsUtil';
import { useSocialsNav } from './SocialsNav';
import { MOCK_THREAD } from './mockSocials';

export default function ThreadView({ id, me, focusReply, onBack, onChanged }) {
    const [data, setData] = useState(null);
    const [nonce, setNonce] = useState(0);
    const inputRef = useRef(null);

    useEffect(() => {
        let alive = true;
        fetchNui('phone:x:thread', { id }, MOCK_THREAD).then((r) => {
            if (!alive) return;
            if (r && r.ok) setData({ post: r.post, ancestors: r.ancestors || [], replies: r.replies || [] });
            else setData(r && r.reason === 'gone' ? 'gone' : false);
        });
        return () => {
            alive = false;
        };
    }, [id, nonce]);

    useEffect(() => {
        if (focusReply && data && data.post && inputRef.current) inputRef.current.focus();
    }, [focusReply, data]);

    const patchMain = useCallback(
        (pid, patch) =>
            setData((d) => {
                if (!d || typeof d !== 'object') return d;
                const post = String(d.post.id) === String(pid) ? { ...d.post, ...patch } : d.post;
                return {
                    post,
                    ancestors: patchPosts(d.ancestors, pid, patch),
                    replies: patchPosts(d.replies, pid, patch),
                };
            }),
        [],
    );

    const removed = useCallback(
        (pid) => {
            if (data && data.post && String(data.post.id) === String(pid)) {
                onChanged && onChanged();
                onBack();
                return;
            }
            setData((d) =>
                d && typeof d === 'object'
                    ? {
                          ...d,
                          post: { ...d.post, replyCount: Math.max(0, (d.post.replyCount || 0) - 1) },
                          replies: dropPost(d.replies, pid),
                      }
                    : d,
            );
        },
        [data, onBack, onChanged],
    );

    return (
        <div className="sc-screen">
            <SHeader left={<BackButton onClick={onBack} />} title="Thread Post" />
            <div className="sc-scroll sc-scroll--thread">
                {data === null && <Loading />}
                {data === false && (
                    <StateMsg title="Couldn’t load this thread" action="Retry" onAction={() => setNonce((n) => n + 1)} />
                )}
                {data === 'gone' && <StateMsg title="This post was deleted" />}
                {data && typeof data === 'object' && (
                    <>
                        {data.ancestors.length > 0 && (
                            <PostList items={data.ancestors} me={me} onPatch={patchMain} onRemoved={removed} />
                        )}
                        <MainPost post={data.post} me={me} onPatch={patchMain} onRemoved={removed} inputRef={inputRef} />
                        <PostList
                            items={data.replies}
                            me={me}
                            onPatch={patchMain}
                            onRemoved={removed}
                            showDelete
                            empty="No replies yet"
                        />
                    </>
                )}
            </div>
            {data && typeof data === 'object' && (
                <ReplyComposer
                    me={me}
                    parentId={data.post.id}
                    inputRef={inputRef}
                    onPosted={() => {
                        setNonce((n) => n + 1);
                        onChanged && onChanged();
                    }}
                />
            )}
        </div>
    );
}

function MainPost({ post, me, onPatch, onRemoved, inputRef }) {
    const nav = useSocialsNav();
    const actions = usePostActions(post, onPatch, onRemoved);
    return (
        <>
            <article className="sc-main">
                <div className="sc-main__head">
                    <button
                        className="sc-card__avatar"
                        onClick={() => nav.openProfile({ id: post.author && post.author.id })}
                        aria-label="Profile"
                    >
                        <SAvatar account={post.author} />
                    </button>
                    <div className="sc-main__who">
                        <div className="sc-main__name">{post.author && post.author.name}</div>
                        <div className="sc-main__handle">@{post.author && post.author.handle}</div>
                    </div>
                </div>
                <div className="sc-main__content">
                    {post.text ? (
                        <div className="sc-main__text">
                            <RichText text={post.text} />
                        </div>
                    ) : null}
                    <PostMedia media={post.media} />
                    <div className="sc-main__date">{threadDate(post.createdAt)}</div>
                </div>
                <div className="sc-main__stats">
                    <span>
                        <b>{fmtCount(post.repostCount)}</b> Reposts
                    </span>
                    <span>
                        <b>{fmtCount(post.likeCount)}</b> Likes
                    </span>
                    <span>
                        <b>{fmtCount(post.viewCount)}</b> Views
                    </span>
                </div>
            </article>
            <div className="sc-card sc-card--actions">
                <ActionRow
                    post={post}
                    me={me}
                    actions={actions}
                    showDelete
                    onComment={() => inputRef.current && inputRef.current.focus()}
                />
            </div>
        </>
    );
}

function ReplyComposer({ me, parentId, inputRef, onPosted }) {
    const dispatch = useDispatch();
    const [text, setText] = useState('');
    const [media, setMedia] = useState([]);
    const [picking, setPicking] = useState(false);
    const [busy, setBusy] = useState(false);
    const can = (text.trim() || media.length) && !busy && text.length <= MAX_POST;

    const send = async () => {
        if (!can) return;
        setBusy(true);
        const r = await fetchNui('phone:x:post', { text: text.trim(), media, parentId }, { ok: true });
        setBusy(false);
        if (r && r.ok) {
            setText('');
            setMedia([]);
            onPosted();
        } else {
            dispatch(pushToast({ title: 'Socials', body: replyError(r) }));
        }
    };

    return (
        <div className="sc-reply">
            {media.length > 0 && (
                <div className="sc-reply__media">
                    {media.map((m, i) => (
                        <span key={i} className="sc-thumb">
                            <img src={m.thumb || m.url} alt="" />
                            <button onClick={() => setMedia((l) => l.filter((_, j) => j !== i))} aria-label="Remove">
                                <FaIcon icon={faXmark} />
                            </button>
                        </span>
                    ))}
                </div>
            )}
            <div className="sc-reply__box">
                <SAvatar account={me} />
                <input
                    ref={inputRef}
                    value={text}
                    maxLength={MAX_POST}
                    placeholder="Reply to this post"
                    onChange={(e) => setText(e.target.value)}
                    onKeyDown={(e) => {
                        if (e.key === 'Enter') {
                            e.preventDefault();
                            send();
                        }
                    }}
                />
                <button
                    className="sc-reply__img"
                    onClick={() => setPicking(true)}
                    disabled={media.length >= 4}
                    aria-label="Add image"
                >
                    <FaIcon icon={faImage} />
                </button>
                <button className={`sc-reply__send${busy ? ' is-busy' : ''}`} disabled={!can} onClick={send} aria-label="Send">
                    <FaIcon icon={faPaperPlane} />
                </button>
            </div>
            {picking && (
                <PhotoPickerSheet
                    selected={[]}
                    photosOnly
                    onClose={() => setPicking(false)}
                    onDone={(items) => {
                        setMedia((l) => [...l, ...items].slice(0, 4));
                        setPicking(false);
                    }}
                />
            )}
        </div>
    );
}

export function replyError(r) {
    if (r && r.reason === 'cooldown') return 'Slow down — wait a moment before posting again.';
    if (r && r.reason === 'empty') return 'Write something first.';
    return 'Could not post. Try again.';
}
