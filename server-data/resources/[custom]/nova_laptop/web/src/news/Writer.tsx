import { useEffect, useState } from 'react';
import { action } from '../api';
import { Icon } from '../icons';
import { MediaBrowser, Thumb } from './MediaBrowser';
import { useAction } from './useAction';
import type { Article, Me, Photo } from './types';
import { ago } from './types';

const HEADLINE = 75, BODY = 1000, ATTACHMENTS = 20;
const STORE = 'nova-weazel-writer';
type Draft = { headline: string; body: string; photos: Photo[] };
const empty: Draft = { headline: '', body: '', photos: [] };

function load(): Draft {
  try { return { ...empty, ...JSON.parse(localStorage.getItem(STORE) || 'null') }; } catch { return empty; }
}

const STATUS: Record<string, string> = { pending: 'In review', approved: 'Approved', published: 'Published', rejected: 'Rejected' };

export function Writer({ me, notify }: { me: Me; notify: (text: string, error?: boolean) => void }) {
  const [draft, setDraft] = useState<Draft>(load);
  const [browser, setBrowser] = useState<'card' | 'phone' | null>(null);
  const [side, setSide] = useState<'attachments' | 'stories'>('attachments');
  const [busy, setBusy] = useState(false);
  const stories = useAction<Article[]>('newsArticles', r => r.articles.mine);
  useEffect(() => { try { localStorage.setItem(STORE, JSON.stringify(draft)); } catch { /* the draft lasts this session */ } }, [draft]);

  const words = draft.body.trim() ? draft.body.trim().split(/\s+/).length : 0;
  const isEmpty = !draft.headline && !draft.body && !draft.photos.length;
  const today = new Date().toLocaleDateString('en-US', { weekday: 'long', month: 'long', day: 'numeric', year: 'numeric' }).toUpperCase();

  async function submit() {
    setBusy(true);
    const reply = await action('newsSubmit', { headline: draft.headline, body: draft.body, photos: draft.photos.map(p => p.id) });
    setBusy(false);
    if (!reply.ok) return notify(reply.error || 'The story could not be submitted.', true);
    setDraft(empty); notify('Submitted for review. An editor will take a look.'); setSide('stories'); void stories.reload();
  }

  if (!me.perms.write) return <div className="nw-app"><div className="nw-locked"><Icon name="lock" size={34} /><h2>Weazel Writer</h2>
    <p>{me.staff ? 'Your group cannot write articles. Ask the owner for the permission.' : 'The article desk is for Weazel News staff.'}</p></div></div>;

  return <div className="nw-app">
    <header className="nw-toolbar">
      <span className="nw-brand"><Icon name="writer" size={16} />Weazel Writer</span>
      <button onClick={() => setBrowser('card')}><Icon name="card" size={15} />Memory card</button>
      <button onClick={() => setBrowser('phone')}><Icon name="phone" size={15} />Phone gallery</button>
      <button disabled={isEmpty} onClick={() => setDraft(empty)}><Icon name="eraser" size={15} />Clear</button>
      <span className="nw-state">{busy ? 'SENDING' : isEmpty ? 'EMPTY' : 'DRAFT'}</span>
      <button className="nw-blue" disabled={busy || !draft.headline.trim() || !draft.body.trim()} onClick={() => void submit()}><Icon name="send" size={15} />Submit for review</button>
    </header>
    <div className="nw-desk">
      <div className="nw-paper-wrap">
        <article className="nw-paper">
          <div className="nw-masthead"><span>WEAZEL NEWS · COPY DESK</span><span>{today}</span></div>
          <textarea className="nw-headline" rows={2} value={draft.headline} placeholder="Headline" aria-label="Headline" maxLength={HEADLINE}
            onChange={event => setDraft({ ...draft, headline: event.target.value.replace(/\n/g, ' ') })} />
          <div className="nw-byline"><span>By {me.name || 'Weazel News staff'}</span></div>
          <textarea className="nw-body" value={draft.body} aria-label="Story" maxLength={BODY}
            placeholder="Start typing your story. Keep it tight - the editor will cut anything past 1,000 characters."
            onChange={event => setDraft({ ...draft, body: event.target.value })} />
        </article>
      </div>
      <aside className="nw-side">
        <div className="nw-side-tabs">
          <button className={side === 'attachments' ? 'on' : ''} onClick={() => setSide('attachments')}>ATTACHMENTS <em>{draft.photos.length}/{ATTACHMENTS}</em></button>
          <button className={side === 'stories' ? 'on' : ''} onClick={() => setSide('stories')}>MY STORIES <em>{stories.data?.length ?? 0}</em></button>
        </div>
        {side === 'attachments' ? <>
          {draft.photos.length ? <div className="nw-attachments">
            {draft.photos.map((photo, i) => <Thumb key={photo.id} url={photo.url} label={i === 0 ? 'Cover' : `#${i + 1}`}>
              <span className="nw-remove" role="button" aria-label="Remove photo" onClick={event => { event.stopPropagation(); setDraft({ ...draft, photos: draft.photos.filter(p => p.id !== photo.id) }); }}><Icon name="close" size={12} stroke={2.6} /></span>
            </Thumb>)}
            {draft.photos.length < ATTACHMENTS && <button className="nw-add-photo" onClick={() => setBrowser('card')}><Icon name="plus" size={20} /></button>}
          </div> : <button className="nw-drop" onClick={() => setBrowser('card')}><Icon name="image" size={26} /><span>No photos attached. Click to browse your memory card.</span></button>}
          <p className="nw-hint">Photos print beside the story. The first one becomes the cover if this article leads an issue.</p>
        </> : <div className="nw-stories">
          {stories.data?.map(story => <div className="nw-story" key={story.id}><strong>{story.headline}</strong>
            <small><span className={`nw-pill ${story.status}`}>{STATUS[story.status] || story.status}</span>{ago(story.at)}{story.reviewer ? ` · ${story.reviewer}` : ''}</small></div>)}
          {stories.data && !stories.data.length && <p className="nw-hint">Stories you submit show up here with what the editors decided.</p>}
        </div>}
      </aside>
    </div>
    <footer className="nw-status">
      <span>Headline {draft.headline.length}/{HEADLINE}</span><span>Body {draft.body.length}/{BODY}</span><span>{words} words</span>
      <span className="nw-ready">{busy ? 'Sending…' : 'Ready'}</span>
    </footer>
    {browser && <MediaBrowser start={browser} slotsLeft={ATTACHMENTS - draft.photos.length} notify={notify} onClose={() => setBrowser(null)}
      onAttach={photos => { setDraft(current => ({ ...current, photos: [...current.photos, ...photos.filter(p => !current.photos.some(c => c.id === p.id))].slice(0, ATTACHMENTS) })); setBrowser(null); }} />}
  </div>;
}
