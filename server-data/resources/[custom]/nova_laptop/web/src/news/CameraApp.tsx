import { useState } from 'react';
import { action, isPreview, nui } from '../api';
import { Icon } from '../icons';
import { Thumb } from './MediaBrowser';
import { useAction } from './useAction';
import type { Me, Photo } from './types';
import { shortDate } from './types';

export function CameraApp({ me, notify }: { me: Me; notify: (text: string, error?: boolean) => void }) {
  // The server copies the phone's gallery onto the card each time this loads.
  const card = useAction<{ photos: Photo[]; capacity: number }>('newsPhotos', r => ({ photos: r.photos, capacity: r.capacity }));
  const [view, setView] = useState<Photo | null>(null);
  const [filter, setFilter] = useState<'all' | 'camera' | 'phone'>('all');
  const photos = (card.data?.photos || []).filter(p => filter === 'all' || p.origin === filter);

  async function remove(photo: Photo) {
    const reply = await action('newsDeletePhoto', { id: photo.id });
    if (!reply.ok) return notify(reply.error || 'The photo could not be deleted.', true);
    card.setData(data => data && { ...data, photos: reply.photos }); setView(null);
  }
  async function shoot() {
    if (isPreview) return notify('In game, the laptop closes and you raise the camera. Click to take a photo.');
    await nui('camera');
  }
  function pick(f: 'all' | 'camera' | 'phone') {
    setFilter(f);
    if (f !== 'camera') void card.reload();
  }

  return <div className="cm-app">
    <header className="cm-bar">
      <span className="cm-title"><Icon name="card" size={16} />Memory Card</span>
      <div className="cm-filter">{(['all', 'camera', 'phone'] as const).map(f => <button key={f} className={filter === f ? 'on' : ''} onClick={() => pick(f)}>{f === 'all' ? 'All photos' : f === 'camera' ? 'Camera' : 'From phone'}</button>)}</div>
      <span className="cm-space">{card.data ? `${card.data.photos.length} of ${card.data.capacity} used` : '…'}</span>
      <button className="cm-shoot" disabled={!me.staff} onClick={() => void shoot()}><Icon name="camera" size={16} />Take photos</button>
    </header>
    {card.data && <div className="cm-meter"><i style={{ width: `${Math.min(100, card.data.photos.length / card.data.capacity * 100)}%` }} /></div>}
    <div className="cm-grid">
      {photos.map(photo => <Thumb key={photo.id} url={photo.url} label={`${shortDate(photo.at)}${photo.origin === 'phone' ? ' · Phone' : ''}`} onClick={() => setView(photo)} />)}
      {card.data && !photos.length && (filter === 'phone'
        ? <div className="cm-empty"><Icon name="phone" size={38} /><h3>No phone photos</h3>
          <p>Photos you take with your phone's camera show up here.</p></div>
        : <div className="cm-empty"><Icon name="camera" size={38} /><h3>No photos yet</h3>
          <p>Press Take photos: the laptop closes and you raise the camera.<br />Click to snap, scroll to zoom, Esc to put it away.</p></div>)}
      {card.error && <p className="mb-empty">{card.error}</p>}
    </div>
    {view && <div className="cm-viewer" onPointerDown={event => { if (event.target === event.currentTarget) setView(null); }}>
      <figure><img src={view.url} alt="" draggable={false} /><figcaption>
        <span>{new Date(view.at).toLocaleString('en-US', { month: 'short', day: 'numeric', hour: 'numeric', minute: '2-digit' })} · {view.origin === 'phone' ? 'From phone · delete it on your phone to remove it' : 'Camera'}</span>
        {view.origin !== 'phone' && <button onClick={() => void remove(view)}><Icon name="trash" size={14} />Delete</button>}
        <button onClick={() => setView(null)}><Icon name="close" size={14} />Close</button></figcaption></figure>
    </div>}
  </div>;
}
