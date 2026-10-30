import { useRef } from 'react';
import { useDispatch } from 'react-redux';
import {
    faHeart,
    faComment,
    faRetweet,
    faChartSimple,
    faBookmark as faBookmarkSolid,
    faTrash,
} from '@fortawesome/free-solid-svg-icons';
import { faBookmark } from '@fortawesome/free-regular-svg-icons';
import FaIcon from '../../np/FaIcon';
import { fetchNui } from '../../utils/fetchNui';
import { openDialog } from '../../store/slices/dialogSlice';
import { setLightbox } from '../../store/slices/photosSlice';
import { pushToast } from '../../store/slices/toastSlice';
import { initials, feedDate, fmtCount, tokenize } from './socialsUtil';
import { useSocialsNav } from './SocialsNav';

export function SAvatar({ account, size }) {
    return (
        <span className="sc-avatar" style={size ? { width: size, height: size } : undefined}>
            {account && account.avatar ? (
                <img src={account.avatar} alt="" />
            ) : (
                initials(account && account.name)
            )}
        </span>
    );
}

export function RichText({ text }) {
    const nav = useSocialsNav();
    return (
        <>
            {tokenize(text).map((t, i) =>
                t.type === 'text' ? (
                    <span key={i}>{t.value}</span>
                ) : (
                    <button
                        key={i}
                        className="sc-link"
                        onClick={(e) => {
                            e.stopPropagation();
                            if (t.type === 'mention') nav.openProfile({ handle: t.key });
                            else nav.openTopic(t.key);
                        }}
                    >
                        {t.value}
                    </button>
                ),
            )}
        </>
    );
}

export function PostMedia({ media }) {
    const dispatch = useDispatch();
    if (!media || !media.length) return null;
    const items = media.slice(0, 4);
    return (
        <div className={`sc-media sc-media--${items.length}`} onClick={(e) => e.stopPropagation()}>
            {items.map((m, i) =>
                m.type === 'video' ? (
                    <video key={i} src={m.url} poster={m.thumb} controls playsInline preload="metadata" />
                ) : (
                    <button key={i} className="sc-media__cell" onClick={() => dispatch(setLightbox(m.url))}>
                        <img src={m.url} alt="" loading="lazy" />
                    </button>
                ),
            )}
        </div>
    );
}

// Engagement toggles: optimistic UI, then the server's answer is applied (or reverted).
export function usePostActions(post, onPatch, onRemoved) {
    const dispatch = useDispatch();
    const busy = useRef({});

    const run = async (key, endpoint, optimistic, mock, apply) => {
        if (busy.current[key]) return;
        busy.current[key] = true;
        const prev = {};
        for (const k of Object.keys(optimistic)) prev[k] = post[k];
        onPatch(post.id, optimistic);
        const r = await fetchNui(endpoint, { id: post.id }, { ok: true, ...mock });
        busy.current[key] = false;
        if (r && r.ok) onPatch(post.id, apply(r));
        else {
            onPatch(post.id, prev);
            dispatch(pushToast({ title: 'Socials', body: 'Action failed, try again.' }));
        }
    };

    return {
        like: () => {
            const on = !post.liked;
            const count = Math.max(0, (post.likeCount || 0) + (on ? 1 : -1));
            run('like', 'phone:x:like', { liked: on, likeCount: count }, { liked: on, likeCount: count },
                (r) => ({ liked: !!r.liked, likeCount: r.likeCount }));
        },
        repost: () => {
            const on = !post.reposted;
            const count = Math.max(0, (post.repostCount || 0) + (on ? 1 : -1));
            run('repost', 'phone:x:repost', { reposted: on, repostCount: count }, { reposted: on, repostCount: count },
                (r) => ({ reposted: !!r.reposted, repostCount: r.repostCount }));
        },
        bookmark: () => {
            const on = !post.bookmarked;
            run('bookmark', 'phone:x:bookmark', { bookmarked: on }, { bookmarked: on },
                (r) => ({ bookmarked: !!r.bookmarked }));
        },
        remove: async () => {
            const ok = await dispatch(
                openDialog({
                    title: 'Delete post?',
                    message: 'This can’t be undone.',
                    buttons: [
                        { text: 'Cancel', style: 'cancel', value: false },
                        { text: 'Delete', style: 'destructive', value: true },
                    ],
                }),
            );
            if (!ok) return;
            const r = await fetchNui('phone:x:delete', { id: post.id }, { ok: true });
            if (r && r.ok) onRemoved && onRemoved(post.id);
            else dispatch(pushToast({ title: 'Socials', body: 'Could not delete that post.' }));
        },
    };
}

export function ActionRow({ post, me, actions, onComment, showDelete }) {
    const stop = (fn) => (e) => {
        e.stopPropagation();
        fn();
    };
    const mine = me && post.author && String(post.author.id) === String(me.id);
    return (
        <div className="sc-actions">
            <button className={`sc-act sc-act--like${post.liked ? ' is-on' : ''}`} onClick={stop(actions.like)}>
                <FaIcon icon={faHeart} />
                <span>{fmtCount(post.likeCount)}</span>
            </button>
            <button className="sc-act sc-act--reply" onClick={stop(onComment)}>
                <FaIcon icon={faComment} />
                <span>{fmtCount(post.replyCount)}</span>
            </button>
            <button
                className={`sc-act sc-act--repost${post.reposted ? ' is-on' : ''}`}
                onClick={stop(actions.repost)}
            >
                <FaIcon icon={faRetweet} />
                <span>{fmtCount(post.repostCount)}</span>
            </button>
            <span className="sc-act sc-act--views">
                <FaIcon icon={faChartSimple} />
                <span>{fmtCount(post.viewCount)}</span>
            </span>
            <span className="sc-act__end">
                <button
                    className={`sc-act sc-act--bm${post.bookmarked ? ' is-on' : ''}`}
                    onClick={stop(actions.bookmark)}
                    aria-label="Bookmark"
                >
                    <FaIcon icon={post.bookmarked ? faBookmarkSolid : faBookmark} />
                </button>
                {showDelete && mine && (
                    <button className="sc-act sc-act--del" onClick={stop(actions.remove)} aria-label="Delete">
                        <FaIcon icon={faTrash} />
                    </button>
                )}
            </span>
        </div>
    );
}

export default function PostCard({ post, me, onPatch, onRemoved, showDelete = false, compact = false }) {
    const nav = useSocialsNav();
    const actions = usePostActions(post, onPatch, onRemoved);
    return (
        <article className={`sc-card${post.repostBy ? ' has-banner' : ''}${compact ? ' is-compact' : ''}`}>
            {post.repostBy && (
                <div className="sc-card__banner">
                    <FaIcon icon={faRetweet} />
                    <span>{post.repostBy.name} reposted</span>
                </div>
            )}
            <div className="sc-card__main" data-nav="" onClick={() => nav.openPost(post.id)}>
                <button
                    className="sc-card__avatar"
                    onClick={(e) => {
                        e.stopPropagation();
                        nav.openProfile({ id: post.author && post.author.id });
                    }}
                    aria-label="Profile"
                >
                    <SAvatar account={post.author} />
                </button>
                <div className="sc-card__body">
                    <div className="sc-card__meta">
                        <span className="sc-card__name">{post.author && post.author.name}</span>
                        <span className="sc-card__handle">@{post.author && post.author.handle}</span>
                        <span className="sc-card__date">{feedDate(post.createdAt)}</span>
                    </div>
                    {post.text ? (
                        <div className="sc-card__text">
                            <RichText text={post.text} />
                        </div>
                    ) : null}
                    <PostMedia media={post.media} />
                </div>
            </div>
            <ActionRow
                post={post}
                me={me}
                actions={actions}
                showDelete={showDelete}
                onComment={() => nav.openPost(post.id, { reply: true })}
            />
        </article>
    );
}
