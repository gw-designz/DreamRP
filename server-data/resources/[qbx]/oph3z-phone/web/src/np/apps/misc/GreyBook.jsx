// Grey Book: an opt-in people directory (server/app/misc). List yourself with a title and bio
// so others can find and contact you.
import { useEffect, useState } from 'react';
import { useDispatch } from 'react-redux';
import { faPhone, faMessage, faPeopleGroup, faPen } from '@fortawesome/free-solid-svg-icons';
import FaIcon from '../../FaIcon';
import { setResumeThread } from '../../../store/slices/messagesSlice';
import { openApp } from '../../../store/slices/phoneSlice';
import { digitsOf } from '../../../store/slices/contactsSlice';
import { NpApp, Body, SearchBox, Spinner, Empty, Sheet, Field, Btn, Msg, Toggle, npCall, useNpFetch, initials } from '../../ui/kit';
import './greybook.css';

export default function GreyBook() {
    const dispatch = useDispatch();
    const [q, setQ] = useState('');
    const [query, setQuery] = useState('');
    const [editing, setEditing] = useState(false);
    useEffect(() => {
        const t = setTimeout(() => setQuery(q), 250);
        return () => clearTimeout(t);
    }, [q]);
    const [data, reload] = useNpFetch('phone:np:gb:list', { q: query }, {
        ok: true,
        myName: 'Raptox Doe',
        me: null,
        people: [
            { id: '1', name: 'Marta Lamb', title: 'Mechanic', bio: 'Mobile repairs, 24/7.', number: '555-0177' },
            { id: '2', name: 'Tess Lane', title: 'Lawyer', bio: 'Criminal defense.', number: '555-0199' },
        ],
    });

    const message = (number) => {
        dispatch(setResumeThread(digitsOf(number)));
        dispatch(openApp('message'));
    };

    return (
        <NpApp theme="light" className="ngy">
            <div className="ngy-head">
                <div className="ngy-head__row">
                    <span className="ngy-logo">
                        <FaIcon icon={faPeopleGroup} />
                    </span>
                    <h1>Grey Book</h1>
                    <button className="ngy-edit" onClick={() => setEditing(true)}>
                        <FaIcon icon={faPen} /> {data && data.ok && data.me ? 'My listing' : 'List me'}
                    </button>
                </div>
                <SearchBox value={q} onChange={setQ} placeholder="Search people or jobs" />
            </div>
            <Body>
                {data === null ? (
                    <Spinner />
                ) : !data.ok ? (
                    <Empty title="Couldn’t load the directory" action="Retry" onAction={reload} />
                ) : data.people.length === 0 ? (
                    <Empty icon={faPeopleGroup} title={query ? 'Nobody found' : 'The directory is empty'} body="Add yourself with “List me”." />
                ) : (
                    data.people.map((p) => (
                        <div key={p.id} className="ngy-card">
                            <span className="ngy-av">{initials(p.name)}</span>
                            <span className="ngy-main">
                                <b>
                                    {p.name}
                                    {p.mine ? ' (you)' : ''}
                                </b>
                                {p.title && <em>{p.title}</em>}
                                {p.bio && <small>{p.bio}</small>}
                            </span>
                            {p.number && !p.mine && (
                                <span className="ngy-actions">
                                    <button onClick={() => npCall('phone:call:start', { number: p.number }, {})} aria-label="Call">
                                        <FaIcon icon={faPhone} />
                                    </button>
                                    <button onClick={() => message(p.number)} aria-label="Message">
                                        <FaIcon icon={faMessage} />
                                    </button>
                                </span>
                            )}
                        </div>
                    ))
                )}
            </Body>
            {editing && data && data.ok && <EditListing me={data.me} name={data.myName} onClose={() => setEditing(false)} onSaved={() => (setEditing(false), reload())} />}
        </NpApp>
    );
}

function EditListing({ me, name, onClose, onSaved }) {
    const [title, setTitle] = useState((me && me.title) || '');
    const [bio, setBio] = useState((me && me.bio) || '');
    const [showNumber, setShowNumber] = useState(me ? !!me.number : true);
    const [err, setErr] = useState('');
    const save = async () => {
        const r = await npCall('phone:np:gb:save', { title, bio, showNumber }, { ok: true });
        if (r.ok) onSaved();
        else setErr('Could not save.');
    };
    const remove = async () => {
        await npCall('phone:np:gb:remove', {}, { ok: true });
        onSaved();
    };
    return (
        <Sheet title={me ? 'Your listing' : 'List yourself'} sub={`Shown as ${name}`} onClose={onClose}>
            <Field label="Title / profession" value={title} max={48} onChange={setTitle} autoFocus />
            <Field label="About you" value={bio} max={300} area onChange={setBio} />
            <div className="ngy-line">
                <span>Show my phone number</span>
                <Toggle on={showNumber} onChange={setShowNumber} />
            </div>
            <Msg>{err}</Msg>
            <Btn className="npk-btn--block" onClick={save}>
                Save
            </Btn>
            {me && (
                <Btn kind="danger" className="npk-btn--block" onClick={remove}>
                    Remove my listing
                </Btn>
            )}
        </Sheet>
    );
}
