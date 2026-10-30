// Weazel News (server/app/news). Reporters (Config.News.Jobs) see the pencil to publish.
import { useState } from 'react';
import { useDispatch } from 'react-redux';
import { faPen, faArrowLeft, faTrash } from '@fortawesome/free-solid-svg-icons';
import FaIcon from '../../FaIcon';
import { openDialog } from '../../../store/slices/dialogSlice';
import { NpApp, Body, Spinner, Empty, Chips, Field, Toggle, Msg, Splash, useSplash, npCall, useNpFetch, useBack, useStatusTone, ago, mdy } from '../../ui/kit';
import './news.css';

const now = Math.floor(Date.now() / 1000);
const CATS = [
    { id: 'crime', label: 'Crime' },
    { id: 'city', label: 'City' },
    { id: 'business', label: 'Business' },
    { id: 'sports', label: 'Sports' },
    { id: 'weather', label: 'Weather' },
];
const MOCK = {
    ok: true,
    canPublish: true,
    categories: CATS,
    articles: [
        { id: 3, category: 'weather', headline: 'Heat wave expected to hit Sandy Shores', image: '', author: 'Lacey Jonas', ts: now - 5 * 3600 },
        { id: 2, category: 'city', headline: 'City Hall opens new license office hours', author: 'Lacey Jonas', ts: now - 4 * 3600 },
        { id: 1, category: 'crime', headline: 'Shootout near Legion Square leaves two injured', author: 'Lacey Jonas', ts: now - 3 * 3600 },
    ],
};
const ERR = { denied: 'Only Weazel News staff can publish.', short: 'Write a headline and a story.', slow: 'Wait a moment before publishing again.', category: 'Pick a category.' };

export default function News() {
    const [splash] = useSplash(1000);
    const [cat, setCat] = useState('all');
    const [view, setView] = useState(null); // { id } | 'new'
    const [data, reload] = useNpFetch('phone:np:news:list', { category: cat }, MOCK);
    useStatusTone(splash ? 'light' : 'dark');
    useBack(() => (view ? (setView(null), true) : false));

    if (splash)
        return (
            <NpApp theme="light" className="nnw">
                <Splash bg="#d42a2a" className="nnw-splash" title="NEWS" tagline="Confirming your prejudices" glyph={<span className="nnw-splash__top">WEAZEL</span>} />
            </NpApp>
        );

    const cats = (data && data.ok && data.categories && data.categories.length ? data.categories : CATS) || CATS;
    const labelOf = (id) => (cats.find((c) => c.id === id) || {}).label || id;

    if (view === 'new') return <Compose cats={cats} onBack={() => setView(null)} onDone={() => (setView(null), reload())} />;
    if (view) return <Article id={view.id} labelOf={labelOf} onBack={() => setView(null)} onDeleted={() => (setView(null), reload())} />;

    return (
        <NpApp theme="light" className="nnw">
            <div className="nnw-bar">
                <span className="nnw-logo">
                    <i>WEAZEL</i> NEWS
                </span>
                <span className="nnw-live">
                    <span /> LIVE
                </span>
                {data && data.ok && data.canPublish && (
                    <button className="nnw-pen" onClick={() => setView('new')} aria-label="New article">
                        <FaIcon icon={faPen} />
                    </button>
                )}
            </div>
            <Chips items={[{ id: 'all', label: 'All' }, ...cats]} value={cat} onChange={setCat} className="nnw-chips" />
            <Body>
                {data === null ? (
                    <Spinner />
                ) : !data.ok ? (
                    <Empty title="Couldn’t load the news" action="Retry" onAction={reload} />
                ) : data.articles.length === 0 ? (
                    <Empty title="No stories yet" />
                ) : (
                    data.articles.map((a, i) => (
                        <button key={a.id} className={`nnw-card${i === 0 ? ' is-lead' : ''}`} onClick={() => setView({ id: a.id })}>
                            {i === 0 && <span className="nnw-img" style={a.image ? { backgroundImage: `url("${a.image}")` } : undefined} />}
                            <span className="nnw-card__body">
                                <em>
                                    {a.breaking && <b className="nnw-breaking">BREAKING</b>}
                                    {labelOf(a.category).toUpperCase()}
                                </em>
                                <b>{a.headline}</b>
                                <small>
                                    {a.author} · {ago(a.ts)}
                                </small>
                            </span>
                        </button>
                    ))
                )}
            </Body>
        </NpApp>
    );
}

function Article({ id, labelOf, onBack, onDeleted }) {
    const dispatch = useDispatch();
    const [data] = useNpFetch('phone:np:news:get', { id }, { ok: true, article: { ...MOCK.articles[0], body: 'Temperatures are set to climb past 110°F this weekend. Stay hydrated.', canDelete: true } });
    const remove = async () => {
        const ok = await dispatch(
            openDialog({
                title: 'Delete this article?',
                buttons: [
                    { text: 'Cancel', style: 'cancel', value: false },
                    { text: 'Delete', style: 'destructive', value: true },
                ],
            }),
        );
        if (!ok) return;
        const r = await npCall('phone:np:news:delete', { id }, { ok: true });
        if (r.ok) onDeleted();
    };
    const a = data && data.ok && data.article;
    return (
        <NpApp theme="light" className="nnw">
            <div className="nnw-bar nnw-bar--sub">
                <button className="npk-round" onClick={onBack} aria-label="Back" data-np-back="">
                    <FaIcon icon={faArrowLeft} />
                </button>
                <span className="nnw-logo">
                    <i>WEAZEL</i> NEWS
                </span>
                {a && a.canDelete && (
                    <button className="npk-round" onClick={remove} aria-label="Delete">
                        <FaIcon icon={faTrash} />
                    </button>
                )}
            </div>
            <Body>
                {data === null ? (
                    <Spinner />
                ) : !a ? (
                    <Empty title="This story was removed" />
                ) : (
                    <article className="nnw-article">
                        {a.image && <img src={a.image} alt="" />}
                        <em>{labelOf(a.category).toUpperCase()}</em>
                        <h1>{a.headline}</h1>
                        <small>
                            {a.author} · {mdy(a.ts)}
                        </small>
                        <p>{a.body}</p>
                    </article>
                )}
            </Body>
        </NpApp>
    );
}

function Compose({ cats, onBack, onDone }) {
    const [cat, setCat] = useState(cats[0] ? cats[0].id : 'city');
    const [headline, setHeadline] = useState('');
    const [image, setImage] = useState('');
    const [body, setBody] = useState('');
    const [breaking, setBreaking] = useState(false);
    const [busy, setBusy] = useState(false);
    const [err, setErr] = useState('');
    const ready = headline.trim().length >= 5 && body.trim().length >= 10;
    const publish = async () => {
        if (image && !/^https?:\/\//i.test(image)) return setErr('Image URL must start with http(s)://');
        setBusy(true);
        const r = await npCall('phone:np:news:publish', { category: cat, headline, image, body, breaking }, { ok: true });
        setBusy(false);
        if (r.ok) onDone();
        else setErr(ERR[r.reason] || 'Could not publish.');
    };
    return (
        <NpApp theme="light" className="nnw">
            <div className="nnw-bar nnw-bar--sub">
                <button className="npk-round" onClick={onBack} aria-label="Back" data-np-back="">
                    <FaIcon icon={faArrowLeft} />
                </button>
                <span className="nnw-title">New Article</span>
            </div>
            <Body className="nnw-form">
                <Chips items={cats} value={cat} onChange={setCat} className="nnw-chips nnw-chips--wrap" />
                <Field value={headline} max={120} placeholder="Headline" onChange={setHeadline} />
                <Field value={image} max={512} placeholder="Image URL (optional)" onChange={setImage} />
                <Field value={body} max={6000} placeholder="Write the story..." area onChange={setBody} className="nnw-story" />
                <div className="nnw-breakrow">
                    <span>Breaking news</span>
                    <Toggle on={breaking} onChange={setBreaking} />
                </div>
                <Msg>{err}</Msg>
                <button className="nnw-publish" disabled={!ready || busy} onClick={publish}>
                    {busy ? 'Publishing…' : 'Publish'}
                </button>
            </Body>
        </NpApp>
    );
}
