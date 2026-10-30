import type { Issue, IssueItem } from './types';

const issueDate = (at: number) => new Date(at).toLocaleDateString('en-US', { month: 'long', day: 'numeric', year: 'numeric' }).toUpperCase();
const snippet = (text: string, length: number) => text.length > length ? text.slice(0, length).replace(/\s+\S*$/, '') + '…' : text;

/** One page of a published issue: page 0 is the cover. */
export function IssuePageView({ issue, index }: { issue: Issue; index: number }) {
  const page = issue.pages[index];
  if (!page) return null;
  if (index === 0) {
    const lead = page.items[0];
    const contents = issue.pages.flatMap((p, pageIndex) => p.items.map((item, slot) => ({ item, section: p.section, key: `${pageIndex}-${slot}` })))
      .filter(entry => entry.item && entry.item !== lead).slice(0, 6) as { item: Exclude<IssueItem, false>; section: string; key: string }[];
    const cover = issue.cover || (lead ? lead.photos[0] : null);
    return <div className="mz-page mz-cover" style={cover ? { backgroundImage: `url("${cover}")` } : undefined}>
      <header className="mz-masthead"><h1>LIFE<span>INVADER</span></h1><small>LOS SANTOS · {issueDate(issue.at)} · VOL. {issue.volume}</small></header>
      {contents.length > 0 && <aside className="mz-contents"><small>IN THIS ISSUE</small>
        {contents.map(({ item, section, key }) => <div key={key}><em>{(section || issue.title).toUpperCase()}</em><strong>{item.headline}</strong><p>{snippet(item.body, 110)}</p></div>)}
      </aside>}
      {lead && <footer className="mz-lead"><span className="mz-tag">{issue.title}</span><h2>{lead.headline}</h2><p>{snippet(lead.body, 220)}</p></footer>}
    </div>;
  }
  return <div className={`mz-page mz-inner layout-${page.layout}`}>
    <header className="mz-section"><h3>{page.section || 'Inside'}</h3><small>LIFEINVADER · VOL. {issue.volume} · PAGE {index + 1}</small></header>
    <div className="mz-items">
      {page.items.map((item, slot) => item ? <article key={slot} className={`mz-item ${slot === 0 ? 'lead' : ''}`}>
        {item.photos[0] && <img src={item.photos[0]} alt="" draggable={false} />}
        <h4>{item.headline}</h4><small>By {item.author}</small><p>{item.body}</p>
      </article> : <div key={slot} className="mz-item blank" />)}
    </div>
  </div>;
}
