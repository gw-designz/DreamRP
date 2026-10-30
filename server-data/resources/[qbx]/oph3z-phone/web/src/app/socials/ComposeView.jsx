import { useRef, useState } from 'react';
import { useDispatch } from 'react-redux';
import { faImage, faPaperPlane, faCamera, faXmark } from '@fortawesome/free-solid-svg-icons';
import FaIcon from '../../np/FaIcon';
import { fetchNui } from '../../utils/fetchNui';
import { pushToast } from '../../store/slices/toastSlice';
import { openApp } from '../../store/slices/phoneSlice';
import { setShareTo } from '../../store/slices/messagesSlice';
import { setPendingCompose } from '../../store/slices/xSlice';
import PhotoPickerSheet from '../mail/PhotoPickerSheet';
import { SHeader, MenuButton } from './parts';
import { SAvatar } from './PostCard';
import { MAX_POST } from './socialsUtil';
import { replyError } from './ThreadView';

const MAX_MEDIA = 4;

export default function ComposeView({ me, initialMedia, onMenu, onPosted }) {
    const dispatch = useDispatch();
    const [text, setText] = useState('');
    const [media, setMedia] = useState(initialMedia || []);
    const [picking, setPicking] = useState(false);
    const [busy, setBusy] = useState(false);
    const [error, setError] = useState('');
    const taRef = useRef(null);

    const len = text.length;
    const can = (text.trim().length > 0 || media.length > 0) && len <= MAX_POST && !busy;

    const submit = async () => {
        if (!can) return;
        setBusy(true);
        setError('');
        const r = await fetchNui('phone:x:post', { text: text.trim(), media }, { ok: true });
        setBusy(false);
        if (r && r.ok) {
            setText('');
            setMedia([]);
            dispatch(pushToast({ title: 'Socials', body: 'Posted.' }));
            onPosted();
        } else {
            setError(replyError(r));
        }
    };

    const camera = () => {
        dispatch(setPendingCompose({ replyTo: null }));
        dispatch(setShareTo('x'));
        dispatch(openApp('camera'));
    };

    return (
        <div className="sc-screen">
            <SHeader
                left={<MenuButton onClick={onMenu} />}
                title="New Thread"
                right={
                    <>
                        <button
                            className="sc-sqbtn"
                            onClick={() => setPicking(true)}
                            disabled={media.length >= MAX_MEDIA}
                            aria-label="Add image"
                        >
                            <FaIcon icon={faImage} />
                        </button>
                        <button
                            className={`sc-plainbtn${can ? ' is-ready' : ''}`}
                            disabled={!can}
                            onClick={submit}
                            aria-label="Post"
                        >
                            {busy ? <span className="sc-spinner sc-spinner--sm" /> : <FaIcon icon={faPaperPlane} />}
                        </button>
                    </>
                }
            />
            <div className="sc-scroll sc-compose">
                <div className="sc-compose__box" onClick={() => taRef.current && taRef.current.focus()}>
                    <SAvatar account={me} size="1.65em" />
                    <textarea
                        ref={taRef}
                        value={text}
                        maxLength={MAX_POST}
                        placeholder="What's on your mind?"
                        onChange={(e) => {
                            setText(e.target.value);
                            if (error) setError('');
                        }}
                    />
                </div>
                {media.length > 0 && (
                    <div className="sc-compose__media">
                        {media.map((m, i) => (
                            <span key={i} className="sc-thumb sc-thumb--lg">
                                {m.type === 'video' ? (
                                    <video src={m.url} muted playsInline preload="metadata" />
                                ) : (
                                    <img src={m.thumb || m.url} alt="" />
                                )}
                                <button onClick={() => setMedia((l) => l.filter((_, j) => j !== i))} aria-label="Remove">
                                    <FaIcon icon={faXmark} />
                                </button>
                            </span>
                        ))}
                    </div>
                )}
                <div className="sc-compose__foot">
                    <button className="sc-compose__cam" onClick={camera} disabled={media.length >= MAX_MEDIA}>
                        <FaIcon icon={faCamera} /> Camera
                    </button>
                    <span className={`sc-compose__count${len > MAX_POST - 20 ? ' is-low' : ''}`}>
                        {len} / {MAX_POST}
                    </span>
                </div>
                {error && <div className="sc-compose__err">{error}</div>}
            </div>
            {picking && (
                <PhotoPickerSheet
                    selected={[]}
                    onClose={() => setPicking(false)}
                    onDone={(items) => {
                        setMedia((l) => [...l, ...items].slice(0, MAX_MEDIA));
                        setPicking(false);
                    }}
                />
            )}
        </div>
    );
}
