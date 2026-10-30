import { useState } from 'react';
import { action } from '../api';
import { Icon } from '../icons';
import { useAction } from './useAction';
import type { PhonePhoto, Photo } from './types';
import { shortDate } from './types';

type Tab = 'card' | 'phone';
type Props = { start: Tab; slotsLeft: number; onAttach: (photos: Photo[]) => void; onClose: () => void; notify: (text: string, error?: boolean) => void };

/** A photo tile that shows a spinner until its picture has loaded. */
export function Thumb({ url, label, selected, onClick, children }: { url: string; label: string; selected?: boolean; onClick?: () => void; children?: React.ReactNode }) {
  const [state, setState] = useState<'loading' | 'ready' | 'failed'>('loading');
  return <button type="button" className={`mb-thumb ${selected ? 'selected' : ''}`} onClick={onClick}>
    {state !== 'failed' && <img src={url} alt="" draggable={false} onLoad={() => setState('ready')} onError={() => setState('failed')} style={{ opacity: state === 'ready' ? 1 : 0 }} />}
    {state === 'loading' && <span className="mb-spinner"><Icon name="spinner" size={20} className="spin" /></span>}
    {state === 'failed' && <span className="mb-spinner"><Icon name="image" size={22} /></span>}
    <small>{label}</small>
    {selected && <span className="mb-check"><Icon name="check" size={13} stroke={3} /></span>}
    {children}
  </button>;
}

export function MediaBrowser({ start, slotsLeft, onAttach, onClose, notify }: Props) {
  const [tab, setTab] = useState<Tab>(start);
  const [album, setAlbum] = useState('all');
  const [picked, setPicked] = useState<string[]>([]);
  const [busy, setBusy] = useState(false);
  const card = useAction<Photo[]>('newsPhotos', r => r.photos);
  const phone = useAction<PhonePhoto[]>('newsPhoneGallery', r => r.photos);

  const list: { key: string; url: string; at: number }[] = tab === 'card'
    ? (card.data || []).filter(p => album === 'all' || p.origin === album).map(p => ({ key: String(p.id), url: p.url, at: p.at }))
    : (phone.data || []).map(p => ({ key: p.url, url: p.url, at: p.at }));
  const source = tab === 'card' ? card : phone;
  const toggle = (key: string) => setPicked(current => current.includes(key) ? current.filter(k => k !== key)
    : current.length >= slotsLeft ? (notify(`Only ${slotsLeft} more photo${slotsLeft === 1 ? '' : 's'} fit on this article.`, true), current) : [...current, key]);

  async function attach() {
    if (tab === 'card') {
      onAttach((card.data || []).filter(p => picked.includes(String(p.id))));
      return;
    }
    setBusy(true);
    const reply = await action('newsImport', { urls: picked });
    setBusy(false);
    if (!reply.ok) return notify(reply.error || 'Those photos could not be copied.', true);
    const all: Photo[] = reply.photos;
    onAttach(reply.ids.map((id: number) => all.find(p => p.id === id)).filter(Boolean));
  }

  return <div className="mb-overlay" onPointerDown={event => { if (event.target === event.currentTarget) onClose(); }}>
    <section className="mb-dialog" role="dialog" aria-label="Media browser">
      <header>
        <span className="mb-title"><Icon name="image" size={16} />Media Browser</span>
        <button className={tab === 'card' ? 'on' : ''} onClick={() => { setTab('card'); setPicked([]); setAlbum('all'); }}><Icon name="card" size={15} />Memory card</button>
        <button className={tab === 'phone' ? 'on' : ''} onClick={() => { setTab('phone'); setPicked([]); setAlbum('all'); }}><Icon name="phone" size={15} />Phone gallery</button>
        <button className="mb-close" aria-label="Close" onClick={onClose}><Icon name="close" size={18} /></button>
      </header>
      <div className="mb-bar">
        <span>Album</span>
        <select value={album} onChange={event => setAlbum(event.target.value)} aria-label="Album">
          <option value="all">All photos</option>
          {tab === 'card' && <><option value="camera">Camera</option><option value="phone">From phone</option></>}
        </select>
        <span>{list.length} photo{list.length === 1 ? '' : 's'}</span>
      </div>
      <div className="mb-grid">
        {list.map(item => <Thumb key={item.key} url={item.url} label={shortDate(item.at)} selected={picked.includes(item.key)} onClick={() => toggle(item.key)} />)}
        {source.loading && !source.data && Array.from({ length: 10 }, (_, i) => <span key={i} className="mb-thumb ghost"><span className="mb-spinner"><Icon name="spinner" size={20} className="spin" /></span></span>)}
        {source.error && <p className="mb-empty">{source.error}</p>}
        {source.data && !list.length && <p className="mb-empty">{tab === 'card' ? 'Your memory card is empty. Take some photos with the Camera app.' : 'Your phone gallery is empty.'}</p>}
      </div>
      <footer>
        <span>{picked.length} selected · {slotsLeft - picked.length} slots left</span>
        <em>{tab === 'phone' ? 'Phone photos are copied to your memory card when attached.' : 'Photos print beside the story.'}</em>
        <button className="nw-ghost" onClick={onClose}>Cancel</button>
        <button className="nw-blue" disabled={!picked.length || busy} onClick={() => void attach()}><Icon name="clip" size={15} />Attach {picked.length}</button>
      </footer>
    </section>
  </div>;
}
