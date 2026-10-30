import { useEffect, useRef, useState } from 'react';
import type { PointerEvent as ReactPointerEvent } from 'react';
import { action } from '../api';
import { Icon } from '../icons';
import { useAction } from './useAction';
import type { Article, Articles, Draft, Layout, Me } from './types';
import { LAYOUT_NAMES, SLOTS } from './types';

type Props = { me: Me; notify: (text: string, error?: boolean) => void };
const ordinal = (day: number) => day % 100 >= 11 && day % 100 <= 13 ? 'TH' : ['TH', 'ST', 'ND', 'RD'][day % 10] || 'TH';
/** "SEPTEMBER 10TH, 2026" */
const today = () => {
  const now = new Date();
  return `${now.toLocaleDateString('en-US', { month: 'long' }).toUpperCase()} ${now.getDate()}${ordinal(now.getDate())}, ${now.getFullYear()}`;
};

export function MagazineEditor({ me, notify }: Props) {
  const remote = useAction<{ draft: Draft; next: number }>('newsDraft', r => ({ draft: r.draft, next: r.nextVolume }));
  const lists = useAction<Articles>('newsArticles', r => r.articles);
  const [draft, setDraft] = useState<Draft | null>(null);
  const [page, setPage] = useState(0);
  const [zoom, setZoom] = useState(0.9);
  const [picked, setPicked] = useState<number | null>(null);
  const [drag, setDrag] = useState<{ article: Article; x: number; y: number } | null>(null);
  const [publishing, setPublishing] = useState(false);
  const [column, setColumn] = useState<Article | null>(null);
  const root = useRef<HTMLDivElement>(null);
  const dirty = useRef(false);
  const editable = me.perms.edit;

  useEffect(() => { if (remote.data && !dirty.current) setDraft(remote.data.draft); }, [remote.data]);
  // Saved a moment after each change, so the next editor sees the same draft.
  useEffect(() => {
    if (!draft || !dirty.current || !editable) return;
    const timer = window.setTimeout(async () => {
      const reply = await action('newsSaveDraft', { draft });
      if (reply.ok) dirty.current = false; else notify(reply.error || 'The draft did not save.', true);
    }, 700);
    return () => window.clearTimeout(timer);
  }, [draft]);

  const all = [...(lists.data?.columns || []), ...(lists.data?.approved || [])];
  const byId = (id: number | false) => id === false ? null : all.find(a => a.id === id) || null;
  const placed = new Set(draft?.pages.flatMap(p => p.slots).filter((id): id is number => id !== false));
  const current = draft?.pages[page];

  function change(next: Draft) { dirty.current = true; setDraft(next); }
  function updatePage(update: Partial<Draft['pages'][number]>) {
    if (!draft || !current) return;
    const pages = draft.pages.map((p, i) => i === page ? { ...p, ...update } : p);
    change({ ...draft, pages });
  }
  function setLayout(layout: Layout) {
    if (!current) return;
    updatePage({ layout, slots: Array.from({ length: SLOTS[layout] }, (_, n) => current.slots[n] ?? false) });
  }
  function place(slot: number, id: number | false) {
    if (!draft || !current || !editable) return;
    // An article sits in one slot only: moving it empties where it was.
    const pages = draft.pages.map((p, i) => ({ ...p, slots: p.slots.map((s, n) => i === page && n === slot ? id : (id !== false && s === id ? false : s)) }));
    change({ ...draft, pages }); setPicked(null);
  }
  function addPage() {
    if (!draft || draft.pages.length >= 24) return;
    change({ ...draft, pages: [...draft.pages, { section: '', layout: 'feature-left', slots: [false, false] }] }); setPage(draft.pages.length);
  }
  function deletePage() {
    if (!draft || draft.pages.length <= 1) return;
    change({ ...draft, pages: draft.pages.filter((_, i) => i !== page) }); setPage(Math.max(0, page - 1));
  }

  // Dragging an article onto a slot, done with the pointer so it also works on the laptop prop.
  function startDrag(event: ReactPointerEvent, article: Article) {
    if (!editable || event.button !== 0) return;
    const box = root.current!.getBoundingClientRect(), scale = box.width / root.current!.offsetWidth;
    const startX = event.clientX, startY = event.clientY;
    let moved = false;
    const at = (e: PointerEvent) => ({ x: (e.clientX - box.left) / scale, y: (e.clientY - box.top) / scale });
    const move = (e: PointerEvent) => {
      if (!moved && Math.hypot(e.clientX - startX, e.clientY - startY) < 6) return;
      moved = true; setDrag({ article, ...at(e) });
    };
    const up = (e: PointerEvent) => {
      window.removeEventListener('pointermove', move); window.removeEventListener('pointerup', up);
      setDrag(null);
      if (!moved) { setPicked(picked === article.id ? null : article.id); return; }
      const slot = (document.elementFromPoint(e.clientX, e.clientY) as HTMLElement | null)?.closest<HTMLElement>('[data-slot]');
      if (slot) place(Number(slot.dataset.slot), article.id);
    };
    window.addEventListener('pointermove', move); window.addEventListener('pointerup', up);
  }

  async function review(article: Article, approve: boolean) {
    const reply = await action('newsReview', { id: article.id, approve });
    if (!reply.ok) return notify(reply.error || 'Could not review that article.', true);
    notify(approve ? 'Approved. It is ready to place.' : 'Rejected. It moved to the trash.'); void lists.reload();
  }

  if (!me.staff) return <div className="mz-app"><div className="nw-locked"><Icon name="lock" size={34} /><h2>Magazine Editor</h2><p>The magazine desk is for Weazel News staff.</p></div></div>;
  if (!draft || !current) return <div className="mz-app"><div className="nw-locked"><Icon name="spinner" size={28} className="spin" /><p>{remote.error || 'Opening the magazine…'}</p></div></div>;

  const card = (article: Article, kind: 'column' | 'approved' | 'pending') => <div key={article.id}
    className={`mz-card ${picked === article.id ? 'picked' : ''} ${placed.has(article.id) ? 'placed' : ''} ${kind}`}
    onPointerDown={kind !== 'pending' ? event => startDrag(event, article) : undefined}>
    <span className="mz-card-icon"><Icon name={kind === 'column' ? 'article' : kind === 'pending' ? 'clock' : 'writer'} size={16} /></span>
    <div><strong>{article.headline}</strong><small>{kind === 'column' ? 'LIFEINVADER Staff' : article.author}{placed.has(article.id) ? ' · Placed' : ''}</small>
      {kind === 'pending' && <p>{article.body.slice(0, 120)}{article.body.length > 120 ? '…' : ''}</p>}</div>
    {kind === 'column' && editable && <button aria-label="Edit column" onPointerDown={event => event.stopPropagation()} onClick={() => setColumn(article)}><Icon name="edit" size={14} /></button>}
    {kind === 'pending' && me.perms.review && <span className="mz-review">
      <button className="ok" aria-label="Approve" onClick={() => void review(article, true)}><Icon name="approve" size={17} /></button>
      <button className="no" aria-label="Reject" onClick={() => void review(article, false)}><Icon name="reject" size={17} /></button></span>}
  </div>;

  return <div className="mz-app" ref={root}>
    <header className="mz-top">
      <span className="mz-logo">LIFEINVADER.</span>
      <span className="mz-desk"><b>LIFEINVADER</b><b>MAGAZINE</b><small>MAGAZINE<br />DESK</small></span>
      <input className="mz-input" disabled={!editable} value={current.section} maxLength={40} onChange={event => updatePage({ section: event.target.value })}
        placeholder={page === 0 ? 'Section name (page 1 = cover)' : 'Section name'} aria-label="Section name" />
      <input className="mz-input title" disabled={!editable} value={draft.title} maxLength={60} onChange={event => change({ ...draft, title: event.target.value })} placeholder="Issue title" aria-label="Issue title" />
      <small className="mz-label">LAYOUT</small>
      <select className="mz-select" disabled={!editable} value={current.layout} onChange={event => setLayout(event.target.value as Layout)} aria-label="Layout">
        {(Object.keys(SLOTS) as Layout[]).map(l => <option key={l} value={l}>{LAYOUT_NAMES[l]}</option>)}</select>
      <span className="mz-pager">
        <button aria-label="Previous page" disabled={page === 0} onClick={() => setPage(page - 1)}><Icon name="left" size={16} /></button>
        <span><small>Page</small>{page + 1}/{draft.pages.length}</span>
        <button aria-label="Next page" disabled={page >= draft.pages.length - 1} onClick={() => setPage(page + 1)}><Icon name="right" size={16} /></button>
        <button aria-label="Add page" disabled={!editable || draft.pages.length >= 24} onClick={addPage}><Icon name="plus" size={16} /></button>
        <button aria-label="Delete page" disabled={!editable || draft.pages.length <= 1} onClick={deletePage}><Icon name="trash" size={15} /></button>
      </span>
      <button className="mz-publish" disabled={!me.perms.publish} onClick={() => setPublishing(true)}>PUBLISH</button>
    </header>

    <div className="mz-work">
      <div className="mz-canvas">
        <div className="mz-sheet" style={{ transform: `scale(${zoom})` }}>
          <span className="mz-side-tab">{(current.section || (page === 0 ? 'Features' : 'Inside')).toUpperCase()}</span>
          <div className="mz-sheet-head">
            {page === 0 ? <span className="mz-banner">FRONT PAGE = THIS PAGE’S FEATURE: ITS TITLE + FIRST PHOTO PRINT AS THE COVER</span> : <h3>{current.section || 'Untitled section'}</h3>}
            <small>NO. {remote.data?.next ?? '–'} · {today()}</small>
          </div>
          <div className={`mz-slots layout-${current.layout}`}>
            {current.slots.map((id, slot) => {
              const article = byId(id);
              return <div key={slot} data-slot={slot} className={`mz-slot ${article ? 'filled' : ''} ${slot === 0 ? 'lead' : ''} ${picked != null && !article ? 'ready' : ''}`}
                onClick={() => { if (picked != null) place(slot, picked); }}>
                {article ? <>
                  {article.photos[0] && <img src={article.photos[0]} alt="" draggable={false} />}
                  <div><h4>{article.headline}</h4><small>By {article.author}</small><p>{article.body}</p></div>
                  {editable && <button className="mz-unplace" aria-label="Remove from page" onClick={event => { event.stopPropagation(); place(slot, false); }}><Icon name="close" size={13} stroke={2.5} /></button>}
                </> : id !== false ? <span className="mz-missing">This article is no longer available.</span>
                  : <span className="mz-drop"><Icon name="plus" size={22} stroke={1.4} />{picked != null ? 'PLACE HERE' : 'DROP ARTICLE'}</span>}
              </div>;
            })}
          </div>
        </div>
        <div className="mz-zoom">
          <button aria-label="Zoom out" onClick={() => setZoom(Math.max(0.5, +(zoom - 0.1).toFixed(1)))}><Icon name="minimize" size={15} /></button>
          <span>{Math.round(zoom * 100)}%</span>
          <button aria-label="Zoom in" onClick={() => setZoom(Math.min(1.2, +(zoom + 0.1).toFixed(1)))}><Icon name="plus" size={15} /></button>
          <button aria-label="Fit" onClick={() => setZoom(0.9)}><Icon name="expand" size={14} /></button>
        </div>
      </div>

      <aside className="mz-panel">
        <h3><i />ARTICLES</h3>
        {!editable && <p className="mz-note">Your group cannot edit the magazine.</p>}
        {picked != null && <p className="mz-note">Click a slot on the page to place it, or drag it there.</p>}
        <div className="mz-list">
          <small>STAFF COLUMNS ({lists.data?.columns.length ?? 0})</small>
          {lists.data?.columns.map(a => card(a, 'column'))}
          <small>APPROVED ({lists.data?.approved.length ?? 0})</small>
          {lists.data?.approved.map(a => card(a, 'approved'))}
          {lists.data && !lists.data.approved.length && <p className="mz-note">Approved stories from Weazel Writer show up here.</p>}
          {(lists.data?.pending.length ?? 0) > 0 && <><small>AWAITING REVIEW ({lists.data!.pending.length})</small>{lists.data!.pending.map(a => card(a, 'pending'))}</>}
        </div>
      </aside>
    </div>

    {drag && <div className="mz-ghost" style={{ left: drag.x + 12, top: drag.y + 10 }}><Icon name="article" size={14} />{drag.article.headline}</div>}
    {publishing && <PublishDialog draft={draft} next={remote.data?.next ?? 1} onClose={() => setPublishing(false)} onDone={async title => {
      const reply = await action('newsPublish', { title });
      if (!reply.ok) { notify(reply.error || 'The issue did not publish.', true); return; }
      notify('Published. It is on the newsstand now.'); setPublishing(false); dirty.current = false; setPage(0);
      await Promise.all([remote.reload(), lists.reload()]);
    }} />}
    {column && <ColumnDialog article={column} onClose={() => setColumn(null)} onSave={async body => {
      const reply = await action('newsColumn', { id: column.id, body });
      if (!reply.ok) { notify(reply.error || 'The column did not save.', true); return; }
      notify('Column saved.'); setColumn(null); void lists.reload();
    }} />}
  </div>;
}

function PublishDialog({ draft, next, onClose, onDone }: { draft: Draft; next: number; onClose: () => void; onDone: (title: string) => Promise<void> }) {
  const [title, setTitle] = useState(draft.title);
  const [busy, setBusy] = useState(false);
  const filled = draft.pages.reduce((n, p) => n + p.slots.filter(s => s !== false).length, 0);
  return <div className="ns-modal" onPointerDown={event => { if (event.target === event.currentTarget) onClose(); }}>
    <section className="ns-print-dialog" role="dialog" aria-label="Publish issue">
      <header><span className="ns-print-icon"><Icon name="newsstand" size={18} /></span><div><strong>Publish Vol. {next}</strong><small>{draft.pages.length} page{draft.pages.length === 1 ? '' : 's'} · {filled} article{filled === 1 ? '' : 's'}</small></div>
        <button aria-label="Close" onClick={onClose}><Icon name="close" size={18} /></button></header>
      <label className="mz-publish-title"><span>Issue title</span><input autoFocus maxLength={60} value={title} onChange={event => setTitle(event.target.value)} placeholder={`Issue ${next}`} /></label>
      <p>The issue goes on the newsstand for everyone to read and print. Placed stories leave the approved list, and the editor starts a fresh draft.</p>
      <footer><button className="ns-cancel" onClick={onClose}>Cancel</button>
        <button className="ns-go red" disabled={busy} onClick={async () => { setBusy(true); await onDone(title); setBusy(false); }}><Icon name="send" size={15} />Publish</button></footer>
    </section>
  </div>;
}

function ColumnDialog({ article, onClose, onSave }: { article: Article; onClose: () => void; onSave: (body: string) => Promise<void> }) {
  const [body, setBody] = useState(article.body);
  return <div className="ns-modal" onPointerDown={event => { if (event.target === event.currentTarget) onClose(); }}>
    <section className="ns-print-dialog wide" role="dialog" aria-label="Edit staff column">
      <header><span className="ns-print-icon"><Icon name="article" size={18} /></span><div><strong>{article.headline}</strong><small>Staff column</small></div>
        <button aria-label="Close" onClick={onClose}><Icon name="close" size={18} /></button></header>
      <textarea className="mz-column-text" maxLength={1000} value={body} onChange={event => setBody(event.target.value)} />
      <footer><span className="mz-count">{body.length}/1000</span><button className="ns-cancel" onClick={onClose}>Cancel</button>
        <button className="ns-go red" disabled={!body.trim()} onClick={() => void onSave(body)}><Icon name="check" size={15} />Save column</button></footer>
    </section>
  </div>;
}
