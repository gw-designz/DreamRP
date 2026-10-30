// One chat (direct number or group gid) in the NoPixel style. Uses the existing messages /
// groups thunks, so delivery, read state, live locations and payments behave as before.
import { useEffect, useRef, useState } from 'react';
import { useDispatch, useSelector } from 'react-redux';
import {
    faPhone,
    faPaperclip,
    faPaperPlane,
    faImage,
    faLocationDot,
    faTowerBroadcast,
    faPlay,
    faPause,
    faUserPlus,
} from '@fortawesome/free-solid-svg-icons';
import FaIcon from '../../FaIcon';
import { fetchNui } from '../../../utils/fetchNui';
import {
    openThread,
    setActive,
    sendMessage,
    sendLocation,
    stopLive,
    settleNegotiation,
    declineNegotiation,
} from '../../../store/slices/messagesSlice';
import { openGroup, setActiveGroup, sendGroupMessage, sendGroupLocation, stopGroupLive } from '../../../store/slices/groupsSlice';
import { digitsOf, setContactFocus } from '../../../store/slices/contactsSlice';
import { clearNotifsFor } from '../../../store/slices/notificationsSlice';
import { setLightbox } from '../../../store/slices/photosSlice';
import { pushToast } from '../../../store/slices/toastSlice';
import PhotoPickerSheet from '../../../app/mail/PhotoPickerSheet';
import { Avatar, call } from './PhoneSuite';
import { hm, money } from '../../ui/kit';

const dayLabel = (ts) => {
    const d = new Date(ts * 1000);
    const today = new Date();
    const y = new Date();
    y.setDate(today.getDate() - 1);
    if (d.toDateString() === today.toDateString()) return 'Today';
    if (d.toDateString() === y.toDateString()) return 'Yesterday';
    return d.toLocaleDateString(undefined, { month: 'short', day: 'numeric', year: 'numeric' });
};

export default function Conversation({ number, gid, onBack }) {
    const dispatch = useDispatch();
    const isGroup = !!gid;
    const selfNumber = digitsOf(useSelector((s) => s.contacts.number));
    const conv = useSelector((s) => (isGroup ? s.groups.byGid[gid] : s.messages.byNumber[number]));
    const contacts = useSelector((s) => s.contacts.contacts);
    const thread = useSelector((s) => s.messages.threads.find((t) => (isGroup ? t.gid === gid : t.number === number)));
    const [text, setText] = useState('');
    const [menu, setMenu] = useState(false);
    const [picking, setPicking] = useState(false);
    const listRef = useRef(null);

    useEffect(() => {
        if (isGroup) {
            dispatch(openGroup(gid));
            dispatch(setActiveGroup(gid));
            return () => dispatch(setActiveGroup(null));
        }
        dispatch(openThread(number));
        dispatch(setActive(number));
        dispatch(clearNotifsFor({ number }));
        return () => dispatch(setActive(null));
    }, [number, gid, isGroup, dispatch]);

    const items = (conv && conv.items) || [];
    useEffect(() => {
        const el = listRef.current;
        if (el) el.scrollTop = el.scrollHeight;
    }, [items.length]);

    const contact = !isGroup && contacts.find((c) => digitsOf(c.number) === digitsOf(number));
    const name = isGroup ? (conv && conv.name) || (thread && thread.name) || 'Group' : (contact && contact.name) || (thread && thread.name) || number;
    const avatar = isGroup ? conv && conv.photo : (contact && contact.img) || (thread && thread.avatar);
    const sub = isGroup ? `Group · ${(conv && conv.members && conv.members.length) || 0} members` : 'Direct Message';

    const send = (payload) => (isGroup ? dispatch(sendGroupMessage(gid, payload)) : dispatch(sendMessage(number, payload)));

    const submit = () => {
        const body = text.trim();
        if (!body) return;
        setText('');
        send({ type: 'text', body });
    };

    const shareLocation = async (live) => {
        setMenu(false);
        const res = isGroup
            ? await dispatch(sendGroupLocation(gid, { live, duration: live ? 600 : 0 }))
            : await dispatch(sendLocation(number, { live, duration: live ? 600 : 0 }));
        if (!res) dispatch(pushToast({ title: 'Messages', body: 'Could not share your location.' }));
    };

    const openLocation = (m) => {
        const meta = m.meta || {};
        if (typeof meta.x === 'number') {
            fetchNui('phone:maps:waypoint', { x: meta.x, y: meta.y }, {});
            dispatch(pushToast({ title: 'GPS', body: 'Waypoint set.' }));
        }
    };

    let lastDay = null;

    return (
        <div className="nph-conv">
            <div className="nph-conv__head">
                <button className="npk-round" onClick={onBack} aria-label="Back" data-np-back="">
                    <svg viewBox="0 0 24 24" width="1em" height="1em">
                        <path d="M14.5 5.5 8 12l6.5 6.5" fill="none" stroke="currentColor" strokeWidth="2.6" />
                    </svg>
                </button>
                <Avatar name={name} src={avatar} />
                <div className="nph-conv__who">
                    <div className="nph-conv__name">{name}</div>
                    <div className="nph-conv__sub">{sub}</div>
                </div>
                {!isGroup && !contact && (
                    <button className="npk-round" onClick={() => dispatch(setContactFocus({ number }))} aria-label="Add contact">
                        <FaIcon icon={faUserPlus} />
                    </button>
                )}
                {!isGroup && (
                    <button className="npk-round" onClick={() => call(number)} aria-label="Call">
                        <FaIcon icon={faPhone} />
                    </button>
                )}
            </div>

            <div className="nph-conv__list" ref={listRef}>
                {items.length === 0 && <div className="nph-conv__empty">Say hello 👋</div>}
                {items.map((m) => {
                    const out = isGroup ? (m.from && selfNumber ? m.from === selfNumber : !!m.mine) : m.dir === 'out';
                    const day = dayLabel(m.ts);
                    const sep = day !== lastDay;
                    lastDay = day;
                    if (m.type === 'system')
                        return (
                            <div key={m.id} className="nph-sys">
                                {m.body}
                            </div>
                        );
                    return (
                        <div key={m.id}>
                            {sep && <div className="nph-day">{day}</div>}
                            <div className={`nph-msg${out ? ' is-out' : ''}${m.pending ? ' is-pending' : ''}`}>
                                {isGroup && !out && <div className="nph-msg__from">{m.senderName || m.from}</div>}
                                <MsgBody
                                    m={m}
                                    out={out}
                                    selfNumber={selfNumber}
                                    onLocation={openLocation}
                                    onStopLive={() =>
                                        isGroup
                                            ? dispatch(stopGroupLive(gid, m.meta && m.meta.sid, m.id))
                                            : dispatch(stopLive(number, m.meta && m.meta.sid, m.id))
                                    }
                                    onPay={() => dispatch(settleNegotiation(number, m.id))}
                                    onDecline={() => dispatch(declineNegotiation(number, m.id))}
                                    onImage={(url) => dispatch(setLightbox(url))}
                                />
                                <div className="nph-msg__meta">
                                    {hm(m.ts)}
                                    {out && <span> ✓</span>}
                                </div>
                            </div>
                        </div>
                    );
                })}
            </div>

            {menu && (
                <div className="nph-attach">
                    <button onClick={() => (setMenu(false), setPicking(true))}>
                        <FaIcon icon={faImage} /> Photo
                    </button>
                    <button onClick={() => shareLocation(false)}>
                        <FaIcon icon={faLocationDot} /> Location
                    </button>
                    <button onClick={() => shareLocation(true)}>
                        <FaIcon icon={faTowerBroadcast} /> Live location
                    </button>
                </div>
            )}

            <div className="nph-input">
                <input
                    value={text}
                    maxLength={1000}
                    placeholder="Type a message..."
                    onChange={(e) => setText(e.target.value)}
                    onKeyDown={(e) => {
                        if (e.key === 'Enter') {
                            e.preventDefault();
                            submit();
                        }
                    }}
                />
                <button className={`nph-input__clip${menu ? ' is-on' : ''}`} onClick={() => setMenu((v) => !v)} aria-label="Attach">
                    <FaIcon icon={faPaperclip} />
                </button>
                <button className="nph-input__send" onClick={submit} disabled={!text.trim()} aria-label="Send">
                    <FaIcon icon={faPaperPlane} />
                </button>
            </div>

            {picking && (
                <PhotoPickerSheet
                    selected={[]}
                    onClose={() => setPicking(false)}
                    onDone={(list) => {
                        setPicking(false);
                        list.slice(0, 4).forEach((p) => send({ type: p.type === 'video' ? 'video' : 'image', body: p.url }));
                    }}
                />
            )}
        </div>
    );
}

function MsgBody({ m, out, selfNumber, onLocation, onStopLive, onPay, onDecline, onImage }) {
    const meta = m.meta || {};
    if (m.type === 'location') {
        const live = !!meta.sid && meta.live;
        return (
            <button className="nph-loc" onClick={() => onLocation(m)}>
                <span className="nph-loc__map">
                    <FaIcon icon={faLocationDot} />
                </span>
                <span className="nph-loc__label">
                    <FaIcon icon={faLocationDot} /> {live ? 'Live location' : meta.label || 'Shared location'}
                    {live && out && (
                        <span
                            className="nph-loc__stop"
                            onClick={(e) => {
                                e.stopPropagation();
                                onStopLive();
                            }}
                        >
                            Stop
                        </span>
                    )}
                </span>
            </button>
        );
    }
    if (m.type === 'image' || m.type === 'gif') {
        return (
            <button className="nph-img" onClick={() => onImage(m.body)}>
                <img src={m.body} alt="" />
            </button>
        );
    }
    if (m.type === 'video') return <video className="nph-img" src={m.body} controls playsInline preload="metadata" />;
    if (m.type === 'voice') return <Voice src={m.body} />;
    if (m.type === 'money' || m.type === 'request') {
        const amt = meta.amount || Number(m.body) || 0;
        const status = meta.status || 'pending';
        const canAct = m.type === 'request' && status === 'pending' && !out && meta.payer === selfNumber;
        return (
            <div className="nph-cash">
                <div className="nph-cash__label">{m.type === 'money' ? (out ? 'You sent' : 'You received') : out ? 'You requested' : 'Payment request'}</div>
                <div className="nph-cash__amt">{money(amt)}</div>
                {m.type === 'request' && <div className="nph-cash__status">{status}</div>}
                {canAct && (
                    <div className="nph-cash__btns">
                        <button onClick={onPay}>Pay</button>
                        <button onClick={onDecline}>Decline</button>
                    </div>
                )}
            </div>
        );
    }
    if (m.type === 'contact') return <div className="nph-text">📇 {meta.name || m.body} {meta.number ? `· ${meta.number}` : ''}</div>;
    return <div className="nph-text">{m.body}</div>;
}

function Voice({ src }) {
    const ref = useRef(null);
    const [on, setOn] = useState(false);
    return (
        <div className="nph-voice">
            <button
                onClick={() => {
                    const a = ref.current;
                    if (!a) return;
                    if (a.paused) a.play().catch(() => {});
                    else a.pause();
                }}
            >
                <FaIcon icon={on ? faPause : faPlay} />
            </button>
            <span>Voice message</span>
            <audio ref={ref} src={src} onPlay={() => setOn(true)} onPause={() => setOn(false)} onEnded={() => setOn(false)} />
        </div>
    );
}
