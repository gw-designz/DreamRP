import { faBars, faArrowLeft, faCommentDots } from '@fortawesome/free-solid-svg-icons';
import FaIcon from '../../np/FaIcon';
import PostCard from './PostCard';

export function SocialsLogo({ size }) {
    return (
        <div className="sc-splash__logo" style={size ? { fontSize: size } : undefined}>
            <FaIcon icon={faCommentDots} />
            <span>Socials</span>
        </div>
    );
}

export function MenuButton({ onClick }) {
    return (
        <button className="sc-sqbtn" onClick={onClick} aria-label="Menu">
            <FaIcon icon={faBars} />
        </button>
    );
}

export function BackButton({ onClick }) {
    return (
        <button className="sc-sqbtn" onClick={onClick} aria-label="Back" data-np-back="">
            <FaIcon icon={faArrowLeft} />
        </button>
    );
}

// Header row under the status bar. `centered` = Socials feed style, else title sits left.
export function SHeader({ left, title, right, centered = false }) {
    return (
        <header className={`sc-header${centered ? ' is-centered' : ''}`}>
            <div className="sc-header__left">{left}</div>
            <div className="sc-header__title">{title}</div>
            <div className="sc-header__right">{right}</div>
        </header>
    );
}

export function Loading() {
    return (
        <div className="sc-state">
            <span className="sc-spinner" />
        </div>
    );
}

export function StateMsg({ title, body, action, onAction }) {
    return (
        <div className="sc-state">
            <div className="sc-state__title">{title}</div>
            {body && <div className="sc-state__body">{body}</div>}
            {action && (
                <button className="sc-pillbtn" onClick={onAction}>
                    {action}
                </button>
            )}
        </div>
    );
}

// items: null = loading, false = failed, [] = empty.
export function PostList({ items, me, onPatch, onRemoved, empty, onRetry, showDelete }) {
    if (items === null) return <Loading />;
    if (items === false)
        return (
            <StateMsg
                title="Couldn’t load posts"
                body="Check your connection and try again."
                action="Retry"
                onAction={onRetry}
            />
        );
    if (!items.length) return <StateMsg title={empty || 'Nothing here yet'} />;
    return (
        <div className="sc-list">
            {items.map((p, i) => (
                <PostCard
                    key={`${p.id}-${p.repostBy ? `r${p.repostBy.id}` : 'o'}-${i}`}
                    post={p}
                    me={me}
                    onPatch={onPatch}
                    onRemoved={onRemoved}
                    showDelete={showDelete}
                />
            ))}
        </div>
    );
}
