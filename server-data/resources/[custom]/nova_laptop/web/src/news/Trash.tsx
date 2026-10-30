import { useState } from 'react';
import { action } from '../api';
import { Icon } from '../icons';
import { useAction } from './useAction';
import type { Article, Me } from './types';
import { ago } from './types';

export function Trash({ me, notify }: { me: Me; notify: (text: string, error?: boolean) => void }) {
  const list = useAction<Article[]>('newsTrashList', r => r.articles);
  const [busy, setBusy] = useState(false);
  async function run(name: string, article: Article, done: string) {
    setBusy(true);
    const reply = await action(name, { id: article.id });
    setBusy(false);
    if (!reply.ok) return notify(reply.error || 'That did not work.', true);
    notify(done); void list.reload();
  }
  return <div className="tr-app">
    <header className="tr-bar"><Icon name="trash" size={16} /><strong>Trash</strong>
      <span>{me.perms.review ? 'Rejected and deleted stories from the whole newsroom.' : 'Your rejected and deleted stories.'}</span></header>
    <div className="tr-list">
      {list.data?.map(article => <div className="tr-row" key={article.id}>
        <span className="tr-icon"><Icon name="article" size={18} /></span>
        <div><strong>{article.headline}</strong><small>{article.status === 'rejected' ? `Rejected${article.reviewer ? ` by ${article.reviewer}` : ''}` : 'Deleted'} · {article.author} · {ago(article.at)}</small></div>
        <button disabled={busy} onClick={() => void run('newsRestore', article, 'Restored. It is waiting for review again.')}><Icon name="restore" size={14} />Restore</button>
        <button className="danger" disabled={busy} onClick={() => void run('newsPurge', article, 'Deleted for good.')}><Icon name="close" size={14} />Delete forever</button>
      </div>)}
      {list.data && !list.data.length && <div className="tr-empty"><Icon name="trash" size={40} /><h3>Trash is empty</h3><p>Rejected stories land here. Restore one to send it back for review.</p></div>}
      {list.error && <p className="mb-empty">{list.error}</p>}
    </div>
  </div>;
}
