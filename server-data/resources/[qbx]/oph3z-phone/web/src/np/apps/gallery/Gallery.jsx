// Gallery: the phone's photos/videos (photos slice + server/app/photos). Places groups shots
// by the zone they were taken in (stored since this edition; older shots show as "Unknown").
import { useEffect, useMemo, useState } from 'react';
import { useDispatch, useSelector } from 'react-redux';
import { faImages, faHeart, faLocationDot, faTrash, faXmark, faMobileScreen, faShareNodes, faPlay } from '@fortawesome/free-solid-svg-icons';
import FaIcon from '../../FaIcon';
import { loadPhotos, togglePhotoFavorite, deletePhotos } from '../../../store/slices/photosSlice';
import { saveSetting } from '../../../store/slices/settingsSlice';
import { openShare } from '../../../store/slices/airdropSlice';
import { openDialog } from '../../../store/slices/dialogSlice';
import { pushToast } from '../../../store/slices/toastSlice';
import { NpApp, Panel, BigHeader, Body, Empty, useBack, mdy } from '../../ui/kit';
import './gallery.css';

const TABS = [
    { id: 'photos', label: 'Photos', icon: faImages },
    { id: 'favorites', label: 'Favorites', icon: faHeart },
    { id: 'places', label: 'Places', icon: faLocationDot },
];

export default function Gallery() {
    const dispatch = useDispatch();
    const loaded = useSelector((s) => s.photos.loaded);
    const items = useSelector((s) => s.photos.items);
    const [tab, setTab] = useState('photos');
    const [place, setPlace] = useState(null);
    const [view, setView] = useState(null);

    useEffect(() => {
        if (!loaded) dispatch(loadPhotos());
    }, [loaded, dispatch]);

    useBack(() => {
        if (view) return setView(null), true;
        if (place) return setPlace(null), true;
        return false;
    });

    const sorted = useMemo(() => [...items].sort((a, b) => (b.ts || 0) - (a.ts || 0)), [items]);
    const favs = sorted.filter((p) => p.favorite);
    const places = useMemo(() => {
        const map = new Map();
        for (const p of sorted) {
            const k = p.place || 'Unknown';
            if (!map.has(k)) map.set(k, []);
            map.get(k).push(p);
        }
        return [...map.entries()];
    }, [sorted]);

    const list = tab === 'favorites' ? favs : tab === 'places' && place ? (places.find(([k]) => k === place) || [null, []])[1] : sorted;

    return (
        <NpApp theme="dark" className="npg">
            <Panel>
                <BigHeader title="Gallery" sub={`${items.length} Photos · ${favs.length} Favorites`} />
                <div className="npg-tabs">
                    {TABS.map((t) => (
                        <button
                            key={t.id}
                            className={`npg-tab${tab === t.id ? ' is-on' : ''}`}
                            onClick={() => {
                                setTab(t.id);
                                setPlace(null);
                            }}
                        >
                            <FaIcon icon={t.icon} /> {t.label}
                        </button>
                    ))}
                </div>
                <Body>
                    {!loaded ? null : tab === 'places' && !place ? (
                        places.length === 0 ? (
                            <Empty title="No places yet" body="Photos you take are grouped by where you took them." />
                        ) : (
                            <div className="npg-places">
                                {places.map(([k, ps]) => (
                                    <button key={k} className="npg-place" onClick={() => setPlace(k)}>
                                        <Thumb p={ps[0]} />
                                        <span className="npg-place__label">
                                            <b>{k}</b>
                                            <em>{ps.length} photo{ps.length === 1 ? '' : 's'}</em>
                                        </span>
                                    </button>
                                ))}
                            </div>
                        )
                    ) : list.length === 0 ? (
                        <Empty title={tab === 'favorites' ? 'No favorites yet' : 'No photos yet'} body="Use the Camera to take photos and videos." />
                    ) : (
                        <>
                            {place && (
                                <button className="npg-back" onClick={() => setPlace(null)}>
                                    ‹ {place}
                                </button>
                            )}
                            <div className="npg-grid">
                                {list.map((p) => (
                                    <button key={p.id} className="npg-cell" onClick={() => setView(p)}>
                                        <Thumb p={p} />
                                        {p.favorite && <FaIcon icon={faHeart} className="npg-fav" />}
                                    </button>
                                ))}
                            </div>
                        </>
                    )}
                </Body>
            </Panel>
            {view && <Viewer photo={items.find((x) => x.id === view.id) || view} onClose={() => setView(null)} />}
        </NpApp>
    );
}

function Thumb({ p }) {
    if (!p) return <span className="npg-thumb" />;
    if (p.type === 'video')
        return (
            <span className="npg-thumb">
                {p.thumb ? <img src={p.thumb} alt="" loading="lazy" /> : <video src={p.url} muted preload="metadata" />}
                <FaIcon icon={faPlay} className="npg-play" />
            </span>
        );
    return (
        <span className="npg-thumb">
            <img src={p.url} alt="" loading="lazy" />
        </span>
    );
}

function Viewer({ photo, onClose }) {
    const dispatch = useDispatch();
    const remove = async () => {
        const ok = await dispatch(
            openDialog({
                title: 'Delete photo?',
                message: 'This can’t be undone.',
                buttons: [
                    { text: 'Cancel', style: 'cancel', value: false },
                    { text: 'Delete', style: 'destructive', value: true },
                ],
            }),
        );
        if (ok) {
            await dispatch(deletePhotos([photo.id]));
            onClose();
        }
    };
    return (
        <div className="npg-viewer" onClick={onClose}>
            <div className="npg-viewer__top" onClick={(e) => e.stopPropagation()}>
                <span>
                    {photo.place || 'Photo'}
                    <em>{mdy(photo.ts)}</em>
                </span>
                <button onClick={onClose} aria-label="Close">
                    <FaIcon icon={faXmark} />
                </button>
            </div>
            <div className="npg-viewer__stage" onClick={(e) => e.stopPropagation()}>
                {photo.type === 'video' ? <video src={photo.url} controls autoPlay playsInline /> : <img src={photo.url} alt="" />}
            </div>
            <div className="npg-viewer__bar" onClick={(e) => e.stopPropagation()}>
                <button className={photo.favorite ? 'is-on' : ''} onClick={() => dispatch(togglePhotoFavorite(photo.id, !photo.favorite))}>
                    <FaIcon icon={faHeart} />
                    <span>Favorite</span>
                </button>
                <button onClick={() => dispatch(openShare({ kind: 'photos', photos: [{ url: photo.url, type: photo.type, thumb: photo.thumb, duration: photo.duration }] }))}>
                    <FaIcon icon={faShareNodes} />
                    <span>Share</span>
                </button>
                {photo.type !== 'video' && (
                    <button
                        onClick={() => {
                            dispatch(saveSetting('wallpaper', photo.url));
                            dispatch(pushToast({ title: 'Gallery', body: 'Wallpaper updated.' }));
                        }}
                    >
                        <FaIcon icon={faMobileScreen} />
                        <span>Wallpaper</span>
                    </button>
                )}
                <button onClick={remove}>
                    <FaIcon icon={faTrash} />
                    <span>Delete</span>
                </button>
            </div>
        </div>
    );
}
