// NoPixel phone suite: Contacts · Chats · Calls · Keypad in one app with a Q/E bottom bar.
// Built on the existing contacts / messages / groups slices, so calls, texts and groups use the
// same server callbacks as before. Registered for the `call` and `message` app ids.
import { useEffect, useMemo, useState } from 'react';
import { useDispatch, useSelector } from 'react-redux';
import {
    faAddressBook,
    faMessage,
    faPhone,
    faTableCells,
    faPlus,
    faUserGroup,
    faCirclePlus,
    faUserPlus,
    faArrowTrendDown,
    faArrowTrendUp,
    faDeleteLeft,
    faStar,
    faPen,
    faTrash,
    faVideo,
} from '@fortawesome/free-solid-svg-icons';
import FaIcon from '../../FaIcon';
import { fetchNui } from '../../../utils/fetchNui';
import { useNuiEvent } from '../../../hooks/useNuiEvent';
import { setLaunchTab } from '../../../store/slices/phoneSlice';
import {
    loadPhoneState,
    addContact,
    editContact,
    deleteContact,
    toggleFavorite,
    digitsOf,
    setContactFocus,
    clearEditorDraft,
} from '../../../store/slices/contactsSlice';
import {
    loadThreads,
    receiveIncoming,
    updateMessageStatus,
    updateLocation,
    setResumeThread,
} from '../../../store/slices/messagesSlice';
import {
    receiveGroupIncoming,
    setReadLocal,
    setReactionLocal,
    updateGroupLocation,
    removeGroup,
    setResumeGroup,
    createGroup,
} from '../../../store/slices/groupsSlice';
import { markNotifRead } from '../../../store/slices/notificationsSlice';
import { openDialog } from '../../../store/slices/dialogSlice';
import { playKeyTone } from '../../../utils/sound';
import {
    NpApp,
    Panel,
    BigHeader,
    Body,
    TabBar,
    SearchBox,
    Empty,
    Sheet,
    Field,
    Btn,
    Msg,
    ago,
    hm,
    initials,
    useBack,
} from '../../ui/kit';
import Conversation from './Conversation';
import './phone.css';

const TABS = [
    { id: 'contacts', icon: faAddressBook, label: 'Contacts' },
    { id: 'chats', icon: faMessage, label: 'Chats' },
    { id: 'calls', icon: faPhone, label: 'Calls' },
    { id: 'keypad', icon: faTableCells, label: 'Keypad' },
];
const LAUNCH = { favorites: 'contacts', contacts: 'contacts', recents: 'calls', keypad: 'keypad', chats: 'chats' };

export const call = (number, video = false) => {
    if (number) fetchNui('phone:call:start', { number, video }, {});
};

export function Avatar({ name, src, size }) {
    return (
        <span className="nph-av" style={size ? { width: size, height: size } : undefined}>
            {src ? <img src={src} alt="" /> : initials(name)}
        </span>
    );
}

function suiteFactory(initial) {
    function Suite() {
        return <PhoneSuite initial={initial} />;
    }
    Suite.displayName = `PhoneSuite(${initial})`;
    return Suite;
}
export const CallsApp = suiteFactory('calls');
export const ChatsApp = suiteFactory('chats');

export default function PhoneSuite({ initial = 'calls' }) {
    const dispatch = useDispatch();
    const launchTab = useSelector((s) => s.phone.launchTab);
    const resumeThread = useSelector((s) => s.messages.resumeThread);
    const resumeGroup = useSelector((s) => s.groups.resumeGroup);
    const focus = useSelector((s) => s.contacts.focus);
    const editorDraft = useSelector((s) => s.contacts.editorDraft);
    const loaded = useSelector((s) => s.contacts.loaded);
    const contacts = useSelector((s) => s.contacts.contacts);
    const unreadChats = useSelector((s) => s.messages.threads.reduce((a, t) => a + (t.unread || 0), 0));

    const [tab, setTab] = useState(initial);
    const [conv, setConv] = useState(null); // { number } | { gid }
    const [contact, setContact] = useState(null); // detail view: contact object
    const [editor, setEditor] = useState(null); // editor sheet: contact draft

    useEffect(() => {
        dispatch(loadPhoneState());
        dispatch(loadThreads());
    }, [dispatch]);

    useEffect(() => {
        if (!launchTab) return;
        setTab(LAUNCH[launchTab] || 'calls');
        setConv(null);
        setContact(null);
        dispatch(setLaunchTab(null));
    }, [launchTab, dispatch]);

    useEffect(() => {
        if (resumeThread) {
            setTab('chats');
            setConv({ number: resumeThread });
            dispatch(setResumeThread(null));
        }
    }, [resumeThread, dispatch]);

    useEffect(() => {
        if (resumeGroup) {
            setTab('chats');
            setConv({ gid: resumeGroup });
            dispatch(setResumeGroup(null));
        }
    }, [resumeGroup, dispatch]);

    // Hand-offs from other apps (e.g. "add contact" from a chat or listing).
    useEffect(() => {
        if (!focus || !loaded) return;
        const c = contacts.find((x) => digitsOf(x.number) === digitsOf(focus.number));
        setTab('contacts');
        setConv(null);
        if (c) setContact(c);
        else setEditor({ number: focus.number });
        dispatch(setContactFocus(null));
    }, [focus, loaded, contacts, dispatch]);

    useEffect(() => {
        if (!editorDraft) return;
        setEditor(editorDraft);
        dispatch(clearEditorDraft());
    }, [editorDraft, dispatch]);

    useEffect(() => {
        if (tab === 'calls') dispatch(markNotifRead({ app: 'call' }));
    }, [tab, dispatch]);

    useNuiEvent('phone:messages:incoming', (d) => dispatch(receiveIncoming(d)));
    useNuiEvent('phone:messages:update', (d) => d && dispatch(updateMessageStatus(d)));
    useNuiEvent('phone:messages:locupdate', (d) => d && dispatch(updateLocation(d)));
    useNuiEvent('phone:groups:incoming', (d) => dispatch(receiveGroupIncoming(d)));
    useNuiEvent('phone:groups:read', (d) => d && dispatch(setReadLocal(d)));
    useNuiEvent('phone:groups:react', (d) => d && dispatch(setReactionLocal({ ...d, emoji: d.emoji || '' })));
    useNuiEvent('phone:groups:locupdate', (d) => d && dispatch(updateGroupLocation(d)));
    useNuiEvent('phone:groups:removed', (d) => {
        if (!d || !d.gid) return;
        dispatch(removeGroup(d.gid));
        dispatch(loadThreads());
        setConv((c) => (c && c.gid === d.gid ? null : c));
    });

    useBack(() => {
        if (editor) {
            setEditor(null);
            return true;
        }
        if (conv) {
            setConv(null);
            dispatch(loadThreads());
            return true;
        }
        if (contact) {
            setContact(null);
            return true;
        }
        return false;
    });

    const goTab = (id) => {
        setTab(id);
        setConv(null);
        setContact(null);
    };

    const openChat = (number) => {
        setTab('chats');
        setContact(null);
        setConv({ number: digitsOf(number) || number });
    };

    let view;
    if (conv)
        view = (
            <Conversation
                key={conv.gid || conv.number}
                number={conv.number}
                gid={conv.gid}
                onBack={() => {
                    setConv(null);
                    dispatch(loadThreads());
                }}
            />
        );
    else if (contact)
        view = (
            <ContactView
                contact={contacts.find((c) => c.id === contact.id) || contact}
                onBack={() => setContact(null)}
                onMessage={openChat}
                onEdit={(c) => setEditor(c)}
            />
        );
    else if (tab === 'contacts') view = <ContactsTab onOpen={setContact} onAdd={() => setEditor({})} />;
    else if (tab === 'chats') view = <ChatsTab onOpen={setConv} />;
    else if (tab === 'calls') view = <CallsTab onAdd={(number) => setEditor({ number })} onKeypad={() => goTab('keypad')} />;
    else view = <KeypadTab onAdd={(number) => setEditor({ number })} />;

    return (
        <NpApp theme="dark" className="nph">
            <div className="nph__stage">{view}</div>
            <TabBar
                variant="circle"
                tabs={TABS.map((t) => (t.id === 'chats' ? { ...t, badge: unreadChats > 0 } : t))}
                active={tab}
                onChange={goTab}
            />
            {editor && <ContactEditor draft={editor} onClose={() => setEditor(null)} onSaved={(c) => c && setContact(c)} />}
        </NpApp>
    );
}

/* ---------------------------------------------------------------- contacts */

function ContactsTab({ onOpen, onAdd }) {
    const contacts = useSelector((s) => s.contacts.contacts);
    const myNumber = useSelector((s) => s.contacts.number);
    const [q, setQ] = useState('');
    const list = useMemo(() => {
        const needle = q.trim().toLowerCase();
        return [...contacts]
            .filter((c) => !needle || c.name.toLowerCase().includes(needle) || String(c.number).includes(needle))
            .sort((a, b) => (b.favorite ? 1 : 0) - (a.favorite ? 1 : 0) || a.name.localeCompare(b.name));
    }, [contacts, q]);

    return (
        <Panel>
            <BigHeader
                title="Contacts"
                sub={
                    <>
                        <span className="npk-grow">
                            {contacts.length} Contact{contacts.length === 1 ? '' : 's'}
                            {myNumber ? <em className="nph-me"> · My number {myNumber}</em> : null}
                        </span>
                        <button className="nph-subbtn" onClick={onAdd} aria-label="Add contact">
                            <FaIcon icon={faPlus} />
                        </button>
                    </>
                }
            />
            <div className="nph-searchwrap">
                <SearchBox value={q} onChange={setQ} />
            </div>
            <Body>
                {list.length === 0 ? (
                    <Empty title={q ? 'No matches' : 'No contacts yet'} action={q ? null : 'Add contact'} onAction={onAdd} />
                ) : (
                    <div className="npk-list">
                        {list.map((c) => (
                            <button key={c.id} className="npk-row nph-row" onClick={() => onOpen(c)}>
                                <Avatar name={c.name} src={c.img} />
                                <span className="npk-row__main">
                                    <span className="npk-row__title">{c.name}</span>
                                    <span className="npk-row__sub">{c.number}</span>
                                </span>
                                {c.favorite && <FaIcon icon={faStar} className="nph-star" />}
                            </button>
                        ))}
                    </div>
                )}
            </Body>
        </Panel>
    );
}

function ContactView({ contact, onBack, onMessage, onEdit }) {
    const dispatch = useDispatch();
    const remove = async () => {
        const ok = await dispatch(
            openDialog({
                title: 'Delete contact?',
                message: contact.name,
                buttons: [
                    { text: 'Cancel', style: 'cancel', value: false },
                    { text: 'Delete', style: 'destructive', value: true },
                ],
            }),
        );
        if (!ok) return;
        await dispatch(deleteContact(contact.id));
        onBack();
    };
    return (
        <Panel>
            <div className="nph-cv">
                <button className="npk-round nph-cv__back" onClick={onBack} aria-label="Back" data-np-back="">
                    <svg viewBox="0 0 24 24" width="1em" height="1em">
                        <path d="M14.5 5.5 8 12l6.5 6.5" fill="none" stroke="currentColor" strokeWidth="2.6" />
                    </svg>
                </button>
                <Avatar name={contact.name} src={contact.img} size="4.4em" />
                <div className="nph-cv__name">{contact.name}</div>
                <div className="nph-cv__num">{contact.number}</div>
                <div className="nph-cv__actions">
                    <button onClick={() => call(contact.number)}>
                        <FaIcon icon={faPhone} />
                        <span>Call</span>
                    </button>
                    <button onClick={() => call(contact.number, true)}>
                        <FaIcon icon={faVideo} />
                        <span>Video</span>
                    </button>
                    <button onClick={() => onMessage(contact.number)}>
                        <FaIcon icon={faMessage} />
                        <span>Message</span>
                    </button>
                </div>
                {contact.notes ? <div className="nph-cv__notes">{contact.notes}</div> : null}
                <div className="npk-list nph-cv__list">
                    <button className="npk-row" onClick={() => dispatch(toggleFavorite(contact.id, !contact.favorite))}>
                        <span className="npk-row__ico">
                            <FaIcon icon={faStar} />
                        </span>
                        <span className="npk-row__main npk-row__title">
                            {contact.favorite ? 'Remove from favourites' : 'Add to favourites'}
                        </span>
                    </button>
                    <button className="npk-row" onClick={() => onEdit(contact)}>
                        <span className="npk-row__ico">
                            <FaIcon icon={faPen} />
                        </span>
                        <span className="npk-row__main npk-row__title">Edit contact</span>
                    </button>
                    <button className="npk-row nph-danger" onClick={remove}>
                        <span className="npk-row__ico">
                            <FaIcon icon={faTrash} />
                        </span>
                        <span className="npk-row__main npk-row__title">Delete contact</span>
                    </button>
                </div>
            </div>
        </Panel>
    );
}

function ContactEditor({ draft, onClose, onSaved }) {
    const dispatch = useDispatch();
    const [form, setForm] = useState({ name: draft.name || '', number: draft.number || '', notes: draft.notes || '' });
    const [busy, setBusy] = useState(false);
    const [err, setErr] = useState('');
    const save = async () => {
        if (!form.name.trim() || !digitsOf(form.number)) {
            setErr('Enter a name and a phone number.');
            return;
        }
        setBusy(true);
        const res = draft.id
            ? await dispatch(editContact({ ...draft, ...form }))
            : await dispatch(addContact({ ...form, img: draft.img || '' }));
        setBusy(false);
        if (!res) {
            setErr('Could not save this contact.');
            return;
        }
        onSaved && onSaved(res && res.id ? res : null);
        onClose();
    };
    return (
        <Sheet title={draft.id ? 'Edit Contact' : 'New Contact'} onClose={onClose}>
            <div className="npk-form">
                <Field label="Name" value={form.name} max={40} onChange={(v) => setForm({ ...form, name: v })} autoFocus />
                <Field label="Phone number" value={form.number} max={24} onChange={(v) => setForm({ ...form, number: v })} />
                <Field label="Notes" value={form.notes} max={300} area onChange={(v) => setForm({ ...form, notes: v })} />
                <Msg>{err}</Msg>
                <Btn className="npk-btn--block" onClick={save} busy={busy}>
                    Save
                </Btn>
            </div>
        </Sheet>
    );
}

/* ---------------------------------------------------------------- chats */

const preview = (t) => {
    const mine = t.lastDir === 'out' ? 'You: ' : '';
    const label = {
        location: 'Shared a location',
        image: 'Sent a photo',
        video: 'Sent a video',
        gif: 'Sent a GIF',
        voice: 'Voice message',
        money: 'Sent money',
        request: 'Requested money',
        contact: 'Shared a contact',
        appshare: 'Shared an app',
    }[t.lastType];
    return mine + (label || t.lastBody || '');
};

function ChatsTab({ onOpen }) {
    const dispatch = useDispatch();
    const threads = useSelector((s) => s.messages.threads);
    const [q, setQ] = useState('');
    const [sheet, setSheet] = useState(null);
    const list = threads.filter((t) => !q.trim() || String(t.name || t.number).toLowerCase().includes(q.trim().toLowerCase()));

    return (
        <Panel>
            <BigHeader
                title="Chats"
                sub={
                    <>
                        <span className="npk-grow">
                            {threads.length} Chat{threads.length === 1 ? '' : 's'}
                        </span>
                        <button className="nph-subbtn" onClick={() => setSheet('group')} aria-label="New group">
                            <FaIcon icon={faUserGroup} />
                        </button>
                        <button className="nph-subbtn" onClick={() => setSheet('new')} aria-label="New chat">
                            <FaIcon icon={faCirclePlus} />
                        </button>
                    </>
                }
            />
            <div className="nph-searchwrap">
                <SearchBox value={q} onChange={setQ} />
            </div>
            <Body>
                <div className="npk-section nph-label">Chat Contacts</div>
                {list.length === 0 ? (
                    <Empty title={q ? 'No matches' : 'No conversations yet'} action={q ? null : 'Start a chat'} onAction={() => setSheet('new')} />
                ) : (
                    <div className="npk-list">
                        {list.map((t) => (
                            <button
                                key={t.isGroup ? `g:${t.gid}` : t.number}
                                className="npk-row nph-row"
                                onClick={() => onOpen(t.isGroup ? { gid: t.gid } : { number: t.number })}
                            >
                                <Avatar name={t.name || t.number} src={t.avatar} />
                                <span className="npk-row__main">
                                    <span className="npk-row__title">{t.name || t.number}</span>
                                    <span className="npk-row__sub">{preview(t)}</span>
                                </span>
                                <span className={`nph-time${t.unread ? ' is-unread' : ''}`}>
                                    {hm(t.lastTs)}
                                    {t.unread ? <i>{t.unread}</i> : null}
                                </span>
                            </button>
                        ))}
                    </div>
                )}
            </Body>
            {sheet === 'new' && (
                <NewChat
                    onClose={() => setSheet(null)}
                    onPick={(number) => {
                        setSheet(null);
                        onOpen({ number });
                    }}
                />
            )}
            {sheet === 'group' && (
                <NewGroupSheet
                    onClose={() => setSheet(null)}
                    onCreate={async (name, members) => {
                        const gid = await dispatch(createGroup({ name, members, photo: '' }));
                        if (gid) {
                            setSheet(null);
                            onOpen({ gid });
                        }
                        return !!gid;
                    }}
                />
            )}
        </Panel>
    );
}

function NewChat({ onClose, onPick }) {
    const contacts = useSelector((s) => s.contacts.contacts);
    const [num, setNum] = useState('');
    return (
        <Sheet title="New Chat" onClose={onClose}>
            <Field label="Phone number" value={num} max={24} onChange={setNum} autoFocus onEnter={() => digitsOf(num) && onPick(digitsOf(num))} />
            <Btn className="npk-btn--block" disabled={!digitsOf(num)} onClick={() => onPick(digitsOf(num))}>
                Message
            </Btn>
            {contacts.length > 0 && <div className="npk-section">Contacts</div>}
            <div className="npk-list">
                {contacts.map((c) => (
                    <button key={c.id} className="npk-row" onClick={() => onPick(digitsOf(c.number))}>
                        <Avatar name={c.name} src={c.img} />
                        <span className="npk-row__main">
                            <span className="npk-row__title">{c.name}</span>
                            <span className="npk-row__sub">{c.number}</span>
                        </span>
                    </button>
                ))}
            </div>
        </Sheet>
    );
}

function NewGroupSheet({ onClose, onCreate }) {
    const contacts = useSelector((s) => s.contacts.contacts);
    const [name, setName] = useState('');
    const [picked, setPicked] = useState([]);
    const [busy, setBusy] = useState(false);
    const [err, setErr] = useState('');
    const toggle = (n) => setPicked((p) => (p.includes(n) ? p.filter((x) => x !== n) : [...p, n]));
    return (
        <Sheet title="New Group" sub="Pick at least two contacts" onClose={onClose}>
            <Field label="Group name" value={name} max={30} onChange={setName} />
            <div className="npk-list">
                {contacts.map((c) => {
                    const n = digitsOf(c.number);
                    return (
                        <button key={c.id} className={`npk-row nph-pick${picked.includes(n) ? ' is-on' : ''}`} onClick={() => toggle(n)}>
                            <Avatar name={c.name} src={c.img} />
                            <span className="npk-row__main npk-row__title">{c.name}</span>
                            <span className="nph-check" />
                        </button>
                    );
                })}
                {contacts.length === 0 && <Empty title="Add contacts first" />}
            </div>
            <Msg>{err}</Msg>
            <Btn
                className="npk-btn--block"
                busy={busy}
                disabled={!name.trim() || picked.length < 2}
                onClick={async () => {
                    setBusy(true);
                    const ok = await onCreate(name.trim(), picked);
                    setBusy(false);
                    if (!ok) setErr('Could not create the group.');
                }}
            >
                Create Group
            </Btn>
        </Sheet>
    );
}

/* ---------------------------------------------------------------- calls */

function CallsTab({ onAdd, onKeypad }) {
    const recents = useSelector((s) => s.contacts.recents);
    const contacts = useSelector((s) => s.contacts.contacts);
    const nameOf = (r) => {
        const c = contacts.find((x) => digitsOf(x.number) === digitsOf(r.number));
        return c ? c.name : r.name || r.number;
    };
    const known = (r) => contacts.some((x) => digitsOf(x.number) === digitsOf(r.number));

    return (
        <Panel>
            <BigHeader
                title="Calls"
                sub={
                    <>
                        <span className="npk-grow">
                            {recents.length} Call{recents.length === 1 ? '' : 's'}
                        </span>
                        <button className="nph-subbtn" onClick={onKeypad} aria-label="Keypad">
                            <FaIcon icon={faTableCells} />
                        </button>
                    </>
                }
            />
            <Body>
                {recents.length === 0 ? (
                    <Empty title="No recent calls" />
                ) : (
                    <div className="npk-list">
                        {recents.map((r) => {
                            const kind = r.missed ? 'Missed' : r.direction === 'out' ? 'Outgoing' : 'Incoming';
                            return (
                                <div key={r.id} className="npk-row nph-row nph-call" role="button" onClick={() => call(r.number, !!r.video)}>
                                    <span className={`nph-dir${r.missed ? ' is-missed' : ''}`}>
                                        <FaIcon icon={r.direction === 'out' ? faArrowTrendUp : faArrowTrendDown} />
                                    </span>
                                    <span className="npk-row__main">
                                        <span className={`npk-row__title${r.missed ? ' nph-missed' : ''}`}>{nameOf(r)}</span>
                                        <span className="npk-row__sub">
                                            {kind}
                                            {r.video ? ' · Video' : ''}
                                        </span>
                                    </span>
                                    <span className="npk-row__end">
                                        {ago(r.ts)}
                                        {!known(r) && (
                                            <button
                                                className="nph-addbtn"
                                                onClick={(e) => {
                                                    e.stopPropagation();
                                                    onAdd(r.number);
                                                }}
                                                aria-label="Add contact"
                                            >
                                                <FaIcon icon={faUserPlus} />
                                            </button>
                                        )}
                                    </span>
                                </div>
                            );
                        })}
                    </div>
                )}
            </Body>
        </Panel>
    );
}

/* ---------------------------------------------------------------- keypad */

const KEYS = [
    ['1', ''],
    ['2', 'ABC'],
    ['3', 'DEF'],
    ['4', 'GHI'],
    ['5', 'JKL'],
    ['6', 'MNO'],
    ['7', 'PQRS'],
    ['8', 'TUV'],
    ['9', 'WXYZ'],
    ['*', ''],
    ['0', '+'],
    ['#', ''],
];

function KeypadTab({ onAdd }) {
    const [num, setNum] = useState('');
    const press = (k) => {
        playKeyTone(k);
        setNum((n) => (n + k).slice(0, 20));
    };
    const back = () => setNum((n) => n.slice(0, -1));

    useEffect(() => {
        const onKey = (e) => {
            const tag = e.target && e.target.tagName;
            if (tag === 'INPUT' || tag === 'TEXTAREA') return;
            if (/^[0-9*#]$/.test(e.key)) {
                e.preventDefault();
                press(e.key);
            } else if (e.key === 'Backspace') {
                e.preventDefault();
                back();
            } else if (e.key === 'Enter') {
                e.preventDefault();
                setNum((n) => {
                    if (n) call(n);
                    return n;
                });
            }
        };
        window.addEventListener('keydown', onKey);
        return () => window.removeEventListener('keydown', onKey);
    }, []);

    return (
        <Panel className="nph-keypad">
            <div data-np-keys="own" style={{ display: 'contents' }}>
                <BigHeader title="Keypad" sub="Dial a number" />
                <div className={`nph-dial${num ? '' : ' is-empty'}`}>{num || '555-0000'}</div>
                {num && (
                    <button className="nph-addnum" onClick={() => onAdd(num)}>
                        Add to contacts
                    </button>
                )}
                <div className="nph-keys">
                    {KEYS.map(([k, sub]) => (
                        <button key={k} className="nph-key" onClick={() => press(k)}>
                            <b>{k}</b>
                            {sub && <span>{sub}</span>}
                        </button>
                    ))}
                    <span />
                    <button className="nph-key nph-key--call" onClick={() => num && call(num)} aria-label="Call">
                        <FaIcon icon={faPhone} />
                    </button>
                    <button className="nph-key nph-key--del" onClick={back} aria-label="Delete">
                        <FaIcon icon={faDeleteLeft} />
                    </button>
                </div>
            </div>
        </Panel>
    );
}
