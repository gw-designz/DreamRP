import { useEffect, useState } from 'react';
import { action } from '../api';
import { Icon } from '../icons';
import { IssuePageView } from './IssueView';
import { useAction } from './useAction';
import type { Issue, IssueSummary, Me } from './types';
import { longDate } from './types';

export function Newsstand({ me, notify }: { me: Me; notify: (text: string, error?: boolean) => void }) {
  const issues = useAction<IssueSummary[]>('newsIssues', r => r.issues);
  const [open, setOpen] = useState<Issue | null>(null);
  const [page, setPage] = useState(0);
  const [printing, setPrinting] = useState(false);

  async function read(summary: IssueSummary) {
    const reply = await action('newsIssue', { id: summary.id });
    if (!reply.ok) return notify(reply.error || 'That issue could not be opened.', true);
    setOpen(reply.issue); setPage(0);
  }

  if (open) return <div className="ns-app">
    <header className="ns-bar">
      <button className="ns-back" onClick={() => setOpen(null)}><Icon name="back" size={15} />Back to issues</button>
      <strong>Vol. {open.volume}</strong><span>{open.title} · {longDate(open.at)}</span>
      {me.perms.print && <button className="ns-print" onClick={() => setPrinting(true)}><Icon name="printer" size={15} />Print copies</button>}
    </header>
    <IssueReader issue={open} page={page} setPage={setPage} />
    {printing && <PrintDialog issue={open} notify={notify} onClose={() => setPrinting(false)} />}
  </div>;

  return <div className="ns-app">
    <header className="ns-bar">
      <span className="ns-title"><Icon name="newsstand" size={16} />Newsstand</span><span>Every published issue of LifeInvader Magazine.</span>
      <em className="ns-count">{issues.data?.length ?? 0} ISSUE{issues.data?.length === 1 ? '' : 'S'}</em>
      <button className="ns-refresh" onClick={() => void issues.reload()}><Icon name="refresh" size={14} className={issues.loading ? 'spin' : ''} />Refresh</button>
    </header>
    <div className="ns-grid">
      {issues.data?.map(issue => <button key={issue.id} className="ns-issue" onClick={() => void read(issue)}
        style={issue.cover ? { backgroundImage: `linear-gradient(180deg, #c8102ecc, #8d0b20ee), url("${issue.cover}")` } : undefined}>
        <small>LIFEINVADER MAGAZINE</small><h2>{issue.title}</h2><span>VOL. {issue.volume} · {longDate(issue.at)}</span>
      </button>)}
      {issues.data && !issues.data.length && <div className="ns-empty"><Icon name="newsstand" size={36} /><h3>Nothing on the stand yet</h3><p>Lay out an issue in the Magazine Editor and publish it.</p></div>}
    </div>
  </div>;
}

/** The pages of an issue with arrows to turn them; also used for printed copies. */
export function IssueReader({ issue, page, setPage }: { issue: Issue; page: number; setPage: (page: number) => void }) {
  useEffect(() => {
    const keys = (event: KeyboardEvent) => {
      if (event.key === 'ArrowRight') setPage(Math.min(issue.pages.length - 1, page + 1));
      if (event.key === 'ArrowLeft') setPage(Math.max(0, page - 1));
    };
    window.addEventListener('keydown', keys);
    return () => window.removeEventListener('keydown', keys);
  }, [issue, page, setPage]);
  return <div className="ns-reader">
    <button className="ns-turn" aria-label="Previous page" disabled={page === 0} onClick={() => setPage(page - 1)}><Icon name="left" size={26} /></button>
    <IssuePageView issue={issue} index={page} />
    <button className="ns-turn" aria-label="Next page" disabled={page >= issue.pages.length - 1} onClick={() => setPage(page + 1)}><Icon name="right" size={26} /></button>
    <span className="ns-page-no">Page {page + 1} of {issue.pages.length}</span>
  </div>;
}

function PrintDialog({ issue, notify, onClose }: { issue: Issue; notify: (text: string, error?: boolean) => void; onClose: () => void }) {
  const [copies, setCopies] = useState(1);
  const [busy, setBusy] = useState(false);
  const [noPrinter, setNoPrinter] = useState(false);
  async function print() {
    setBusy(true);
    const reply = await action('newsPrint', { id: issue.id, copies });
    setBusy(false);
    if (reply.noPrinter) return setNoPrinter(true);
    if (!reply.ok) return notify(reply.error || 'The printer did not respond.', true);
    notify(`Printing ${copies} cop${copies === 1 ? 'y' : 'ies'}. Ready in about ${reply.seconds} seconds.`); onClose();
  }
  return <div className="ns-modal" onPointerDown={event => { if (event.target === event.currentTarget) onClose(); }}>
    <section className="ns-print-dialog" role="dialog" aria-label="Print copies">
      <header><span className="ns-print-icon"><Icon name="printer" size={18} /></span><div><strong>Print copies</strong><small>Vol. {issue.volume} · {issue.title}</small></div>
        <button aria-label="Close" onClick={onClose}><Icon name="close" size={18} /></button></header>
      <div className="ns-copies"><span>Copies</span>
        <button disabled={copies <= 1} onClick={() => setCopies(copies - 1)}><Icon name="minimize" size={16} /></button>
        <b>{copies}</b>
        <button disabled={copies >= 10} onClick={() => setCopies(copies + 1)}><Icon name="plus" size={16} /></button></div>
      <div className="ns-quick"><span>Quick pick</span>{[1, 3, 5, 10].map(n => <button key={n} className={copies === n ? 'on' : ''} onClick={() => setCopies(n)}>{n}</button>)}</div>
      <p>Copies come out of the printer beside you into its output tray, one sheet of paper each from its paper tray (Load paper on the printer). Each copy takes a few seconds.</p>
      {noPrinter && <div className="ns-no-printer"><Icon name="printer" size={18} /><span>There is no printer here. Set one down beside you, then print again.</span>
        <button disabled={busy} onClick={async () => {
          setBusy(true);
          const reply = await action('newsPlacePrinter');
          setBusy(false);
          if (!reply.ok) notify(reply.error || 'The printer could not be set down.', true);
        }}><Icon name="plus" size={14} />Place printer</button></div>}
      <footer><button className="ns-cancel" onClick={onClose}>Cancel</button>
        <button className="ns-go" disabled={busy} onClick={() => void print()}><Icon name="printer" size={15} />Print {copies} cop{copies === 1 ? 'y' : 'ies'}</button></footer>
    </section>
  </div>;
}
