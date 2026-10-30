import { useEffect, useMemo, useState } from 'react';
import { action } from '../api';
import { Icon } from '../icons';
import { useAction } from './useAction';
import type { Company, FeedItem, Group, Me, Perm, Permission, StaffMember } from './types';
import { ago, initials, longDate, money } from './types';

type Page = 'feed' | 'friends' | 'groups' | 'wallet';
type Props = { me: Me; company: Company; reloadBoot: () => Promise<void>; notify: (text: string, error?: boolean) => void; logOut: () => void };

const ADS = [
  { icon: 'chicken', name: 'Cluckin’ Bell', text: 'Now hiring. No questions asked. No questions answered.' },
  { icon: 'gun', name: 'Ammu-Nation', text: 'Buy one, get one free. Background checks sold separately.' },
  { icon: 'soda', name: 'Sprunk', text: 'Now with 12% more sugar than legally advisable.' },
];
const TRENDS = ['#WeazelNews', '#LosSantos', '#BreakingNews', '#LifeInvaderLeaks'];

export function Portal({ me, company, reloadBoot, notify, logOut }: Props) {
  const [page, setPage] = useState<Page>('feed');
  const [search, setSearch] = useState('');
  const [payTo, setPayTo] = useState('');
  const staff = useAction<{ staff: StaffMember[]; groups: Group[] }>('newsStaff', r => ({ staff: r.staff, groups: r.groups }), page);
  const [busy, setBusy] = useState(false);
  const group = staff.data?.groups.find(g => g.id === me.groupId);

  async function run(name: string, input: Record<string, unknown>, done?: string) {
    if (busy) return false;
    setBusy(true);
    const reply = await action(name, input);
    setBusy(false);
    if (!reply.ok) { notify(reply.error || 'That did not work.', true); return false; }
    if (done) notify(done);
    await Promise.all([staff.reload(), reloadBoot()]);
    return reply;
  }

  if (!me.staff) return <div className="li-app li-locked">
    <TopBar me={me} search="" setSearch={() => undefined} go={() => undefined} logOut={logOut} />
    <div className="li-locked-card"><span className="li-logo-square">Li</span><h2>LifeInvader for Business</h2>
      <p>The {company.label} staff portal is for {company.label} staff only.<br />Ask the owner to add you as a friend.</p>
      <button className="li-button" onClick={logOut}><Icon name="logout" size={15} />Log out</button></div>
  </div>;

  return <div className="li-app">
    <TopBar me={me} search={search} setSearch={text => { setSearch(text); if (text) setPage('friends'); }} go={setPage} logOut={logOut} />
    <div className="li-body">
      <aside className="li-side">
        <div className="li-profile"><span className="li-avatar">{initials(me.name)}<i className={me.onDuty ? 'on' : ''} /></span>
          <div><strong>{me.name}</strong><small>{me.owner ? 'Owner' : group?.name || 'Staff'}</small></div></div>
        <nav>
          {([['feed', 'home', 'News Feed', null], ['friends', 'friends', 'Friends', company.staff], ['groups', 'groups', 'Groups', company.groups], ['wallet', 'wallet', 'Wallet', null]] as const)
            .map(([id, icon, label, count]) => <button key={id} className={page === id ? 'selected' : ''} onClick={() => { setPage(id); setSearch(''); }}>
              <span className="li-nav-icon"><Icon name={icon} size={17} /></span>{label}{count != null && <em>{count}</em>}</button>)}
        </nav>
        <div className="li-status">
          <small>YOUR STATUS</small>
          <span><i className={me.onDuty ? 'on' : ''} />{me.onDuty ? 'On duty' : 'Off duty'}</span>
          <button className="li-button" disabled={busy || me.onJob === false} title={me.onJob === false ? 'Clocking in needs the news job.' : undefined}
            onClick={() => void run('newsDuty', {}, me.onDuty ? 'You clocked out.' : 'You clocked in.')}>
            <Icon name={me.onDuty ? 'logout' : 'login'} size={14} />{me.onDuty ? 'Clock out' : 'Clock in'}</button>
        </div>
        <p className="li-fine">LifeInvader for Business. Your data is our data. Terms apply to you, not to us.</p>
      </aside>

      <main className="li-main">
        {page === 'feed' && <Feed me={me} company={company} group={group} />}
        {page === 'friends' && <Friends me={me} list={staff.data} loading={staff.loading} search={search} busy={busy} run={run}
          pay={cid => { setPayTo(cid); setPage('wallet'); }} />}
        {page === 'groups' && <Groups me={me} notify={notify} onChange={() => { void staff.reload(); void reloadBoot(); }} />}
        {page === 'wallet' && <WalletPage me={me} staff={staff.data?.staff || []} payTo={payTo} notify={notify} reloadBoot={reloadBoot} />}
      </main>

      <aside className="li-right">
        <small className="li-label">SPONSORED</small>
        {ADS.map(ad => <div className="li-ad" key={ad.name}><span><Icon name={ad.icon} size={22} /></span><div><strong>{ad.name}</strong><p>{ad.text}</p></div></div>)}
        <small className="li-label">TRENDING</small>
        {TRENDS.map(tag => <div className="li-trend" key={tag}><span>{tag}</span><Icon name="trend" size={14} /></div>)}
        <small className="li-label">PAGE INFO</small>
        <div className="li-page-info"><span><Icon name="building" size={14} />Media / News Company</span><span><Icon name="globe" size={14} />Los Santos</span>
          <span><Icon name="friends" size={14} />{company.staff} friends · {company.onDuty} on duty</span></div>
      </aside>
    </div>
  </div>;
}

function TopBar({ me, search, setSearch, go, logOut }: { me: Me; search: string; setSearch: (text: string) => void; go: (page: Page) => void; logOut: () => void }) {
  return <header className="li-top">
    <span className="li-brand"><span className="li-logo-square">Li</span>lifeinvader</span>
    <label className="li-search"><Icon name="search" size={15} /><input value={search} onChange={event => setSearch(event.target.value)} placeholder="Search people you barely know" aria-label="Search staff" /></label>
    <nav className="li-top-icons">
      <button aria-label="News feed" onClick={() => go('feed')}><Icon name="home" size={19} /></button>
      <button aria-label="Friends" onClick={() => go('friends')}><Icon name="friends" size={19} /></button>
      <button aria-label="Notifications" onClick={() => go('feed')}><Icon name="bell" size={19} /><i /></button>
    </nav>
    <span className="li-top-user"><span className="li-avatar small">{initials(me.name)}</span>{me.name}</span>
    <button className="li-logout" onClick={logOut}><Icon name="logout" size={15} />Log out</button>
  </header>;
}

// ── news feed ──────────────────────────────────────────────────────────

const CAN: [Perm, string][] = [['staff', 'Add and remove staff'], ['staff', 'Move people between groups'], ['write', 'Write articles in Weazel Writer'],
  ['review', 'Approve and reject submitted articles'], ['edit', 'Lay out the magazine'], ['publish', 'Publish issues to the newsstand'],
  ['print', 'Print copies of published issues'], ['pay', 'Pay staff from the company account']];

function Feed({ me, company, group }: { me: Me; company: Company; group?: Group }) {
  const feed = useAction<FeedItem[]>('newsFeed', r => r.feed);
  const [liked, setLiked] = useState(true);
  const allowed = CAN.filter(([perm]) => me.perms[perm]);
  return <div className="li-scroll">
    <section className="li-card li-page">
      <div className="li-cover" />
      <div className="li-page-head">
        <span className="li-page-logo">{company.label[0]?.toUpperCase()}</span>
        <div><h2>{company.label}</h2><p>Media / News Company · Los Santos · {company.staff} friends</p></div>
        <button className={`li-chip ${liked ? 'liked' : ''}`} onClick={() => setLiked(!liked)}><Icon name="portal" size={14} />{liked ? 'Liked' : 'Like'}</button>
        <button className="li-chip"><Icon name="friends" size={14} />Friends</button>
      </div>
      <div className="li-stats">
        <span><b>{company.staff}</b><small><Icon name="friends" size={12} />STAFF</small></span>
        <span><b className="green">{company.onDuty}</b><small><Icon name="clock" size={12} />ON DUTY</small></span>
        <span><b>{company.groups}</b><small><Icon name="groups" size={12} />GROUPS</small></span>
        <span><b>{money(company.balance)}</b><small><Icon name="bank" size={12} />COMPANY ACCOUNT</small></span>
      </div>
    </section>
    <section className="li-card li-composer">
      <div><span className="li-avatar">{initials(me.name)}</span><span className="li-fake-input">What’s on your mind, {me.name.split(' ')[0]}?</span></div>
      <p><Icon name="lock" size={13} />Posting here is disabled by corporate. Write your stories in Weazel Writer.</p>
    </section>
    <section className="li-card li-post">
      <header><span className="li-page-logo small">{company.label[0]?.toUpperCase()}</span><div><strong>{company.label}</strong><small>Pinned · Staff only · <Icon name="globe" size={11} /></small></div><span className="li-pinned"><Icon name="pin" size={12} />Pinned</span></header>
      <p>Welcome to the Weazel News staff portal, {me.name.split(' ')[0]}.</p>
      <p>{me.owner ? 'As the owner you can:' : `With your current group${group ? ` (${group.name})` : ''} you can:`}</p>
      <ul>{allowed.length ? allowed.map(([, text]) => <li key={text}><Icon name="approve" size={15} />{text}</li>) : <li className="none">Nothing yet. Ask the owner to add permissions to your group.</li>}</ul>
    </section>
    {feed.data?.map(item => <section className="li-card li-post" key={item.id}>
      <header><span className="li-avatar">{initials(item.actor)}</span><div><strong>{item.actor}</strong><small>{ago(item.at)} · Staff only</small></div></header>
      <p>{item.actor.split(' ')[0]} {item.text}.</p>
    </section>)}
    {feed.data && !feed.data.length && <p className="li-empty">Nothing has happened yet. Write a story to get things going.</p>}
  </div>;
}

// ── friends (staff) ────────────────────────────────────────────────────

function Friends({ me, list, loading, search, busy, run, pay }: { me: Me; list: { staff: StaffMember[]; groups: Group[] } | null; loading: boolean; search: string;
  busy: boolean; run: (name: string, input: Record<string, unknown>, done?: string) => Promise<unknown>; pay: (cid: string) => void }) {
  const [filter, setFilter] = useState<'all' | 'duty'>('all');
  const [adding, setAdding] = useState(false);
  const [id, setId] = useState('');
  const shown = (list?.staff || []).filter(s => (filter === 'all' || s.onDuty) && s.name.toLowerCase().includes(search.toLowerCase()));
  return <div className="li-scroll">
    <section className="li-card li-list-head">
      <h2>Friends</h2><span>{list?.staff.length ?? 0} people work here</span>
      <div className="li-toggle"><button className={filter === 'all' ? 'on' : ''} onClick={() => setFilter('all')}>All</button><button className={filter === 'duty' ? 'on' : ''} onClick={() => setFilter('duty')}>On duty</button></div>
      {me.perms.staff && <button className="li-button" onClick={() => setAdding(!adding)}><Icon name="plus" size={15} />Add Friend</button>}
    </section>
    {adding && <form className="li-card li-add" onSubmit={async event => { event.preventDefault(); if (await run('newsHire', { serverId: Number(id) }, 'Friend added.')) { setId(''); setAdding(false); } }}>
      <Icon name="friends" size={18} /><span>Add someone in the city by their ID</span>
      <input autoFocus inputMode="numeric" value={id} onChange={event => setId(event.target.value.replace(/\D/g, '').slice(0, 5))} placeholder="Server ID" aria-label="Server ID" />
      <button className="li-button" disabled={!id || busy}>Add</button><button type="button" className="li-ghost" onClick={() => setAdding(false)}>Cancel</button>
    </form>}
    <section className="li-card li-people">
      {loading && !list && <p className="li-empty">Loading staff…</p>}
      {shown.map(member => <div className="li-person" key={member.cid}>
        <span className="li-avatar dark">{initials(member.name)}<i className={member.onDuty ? 'on' : member.online ? 'idle' : ''} /></span>
        <div className="li-person-name"><strong>{member.name}{member.owner && <em className="owner"><Icon name="crown" size={12} />Owner</em>}{member.you && <em>You</em>}</strong>
          <small>{member.onDuty ? 'On duty' : member.online ? 'Off duty' : 'Away'} · Friends since {longDate(member.since)}</small></div>
        {member.owner ? <span className="li-role owner">Owner</span>
          : me.perms.staff ? <select aria-label={`${member.name}'s group`} disabled={busy} value={member.groupId ?? ''} onChange={event => void run('newsSetGroup', { cid: member.cid, groupId: Number(event.target.value) }, 'Group changed.')}>
            {list?.groups.filter(g => !g.owner).map(g => <option key={g.id} value={g.id}>{g.name}</option>)}</select>
          : <span className="li-role">{list?.groups.find(g => g.id === member.groupId)?.name || 'Staff'}</span>}
        {me.perms.pay && <button className="li-ghost" onClick={() => pay(member.cid)}><Icon name="pay" size={14} />Pay</button>}
        {me.perms.staff && !member.owner && !member.you && <button className="li-outline" disabled={busy} onClick={() => void run('newsFire', { cid: member.cid }, `${member.name} was unfriended.`)}><Icon name="close" size={14} />Unfriend</button>}
      </div>)}
      {list && !shown.length && <p className="li-empty">{search ? `Nobody called “${search}” works here.` : 'Nobody is on duty right now.'}</p>}
    </section>
  </div>;
}

// ── groups ─────────────────────────────────────────────────────────────

function Groups({ me, notify, onChange }: { me: Me; notify: (text: string, error?: boolean) => void; onChange: () => void }) {
  const data = useAction<{ groups: Group[]; permissions: Permission[] }>('newsGroups', r => ({ groups: r.groups, permissions: r.permissions }));
  const [selected, setSelected] = useState<number | 'new' | null>(null);
  const [form, setForm] = useState({ name: '', description: '', permissions: [] as Perm[] });
  const [busy, setBusy] = useState(false);
  const groups = data.data?.groups || [];
  const current = selected === 'new' ? null : groups.find(g => g.id === (selected ?? groups[0]?.id));
  const sections = useMemo(() => {
    const out: Record<string, Permission[]> = {};
    for (const p of data.data?.permissions || []) (out[p.section] ||= []).push(p);
    return out;
  }, [data.data]);
  useEffect(() => {
    if (selected === 'new') setForm({ name: '', description: '', permissions: [] });
    else if (current) setForm({ name: current.name, description: current.description, permissions: current.permissions });
  }, [selected, current?.id, data.data]);

  async function save() {
    setBusy(true);
    const reply = await action('newsSaveGroup', { id: current?.id, ...form });
    setBusy(false);
    if (!reply.ok) return notify(reply.error || 'Could not save the group.', true);
    notify('Group saved.'); setSelected(reply.id); await data.reload(); onChange();
  }
  async function remove() {
    if (!current) return;
    setBusy(true);
    const reply = await action('newsDeleteGroup', { id: current.id });
    setBusy(false);
    if (!reply.ok) return notify(reply.error || 'Could not delete the group.', true);
    notify('Group deleted. Its members moved to the built-in group.'); setSelected(null); await data.reload(); onChange();
  }
  const editable = me.owner && !current?.owner;
  return <div className="li-groups">
    <section className="li-card li-group-list">
      <header><h2>Groups</h2>{me.owner && <button className="li-button" onClick={() => setSelected('new')}><Icon name="plus" size={15} />New</button>}</header>
      {groups.map(g => <button key={g.id} className={current?.id === g.id && selected !== 'new' ? 'selected' : ''} onClick={() => setSelected(g.id)}>
        <span className={`li-group-icon ${g.owner ? 'owner' : ''}`}><Icon name={g.owner ? 'crown' : g.builtin ? 'lock' : 'groups'} size={16} /></span><span><strong>{g.name}</strong><small>{g.members} member{g.members === 1 ? '' : 's'}</small></span></button>)}
      {selected === 'new' && <button className="selected"><span className="li-group-icon"><Icon name="plus" size={16} /></span><span><strong>{form.name || 'New group'}</strong><small>Not saved yet</small></span></button>}
    </section>
    <section className="li-card li-group-edit li-scroll">
      <header><h2>{selected === 'new' ? 'New group' : current?.name || 'Group'}</h2>{current?.builtin && <span className="li-badge"><Icon name={current.owner ? 'crown' : 'lock'} size={12} />{current.owner ? 'Owner group' : 'Built-in group'}</span>}</header>
      <div className="li-fields">
        <label><small>NAME</small><input value={form.name} disabled={!editable || current?.builtin} maxLength={40} onChange={event => setForm({ ...form, name: event.target.value })} placeholder="Group name" /></label>
        <label><small>DESCRIPTION</small><input value={form.description} disabled={!editable || current?.builtin} maxLength={120} onChange={event => setForm({ ...form, description: event.target.value })} placeholder="What this group is for" /></label>
      </div>
      {current?.owner ? <div className="li-note li-owners">
        <p>Owners have every permission. They are set by citizen ID in <b>config.lua</b> (<code>Config.News.Owners</code>), and the news job's boss grade is an owner too.</p>
        {current.holders?.length ? <ul>{current.holders.map(h => <li key={h.cid}><Icon name="crown" size={13} /><strong>{h.name || 'Unknown character'}</strong><code>{h.cid}</code></li>)}</ul>
          : <p>No citizen IDs are listed yet.</p>}
      </div> : <>
        {current?.builtin && <p className="li-note">Everyone who clocks in lands in the {current.name} group. Whatever you tick here applies to all new staff.</p>}
        {!me.owner && <p className="li-note">Only the owner can change groups.</p>}
      </>}
      {Object.entries(sections).map(([section, perms]) => <div className="li-perm-section" key={section}>
        <small><Icon name={section === 'Business' ? 'building' : section === 'Magazine' ? 'magazine' : 'writer'} size={13} />{section.toUpperCase()}</small>
        {perms.map(p => <label key={p.id} className="li-perm"><input type="checkbox" disabled={!editable} checked={form.permissions.includes(p.id)}
          onChange={event => setForm({ ...form, permissions: event.target.checked ? [...form.permissions, p.id] : form.permissions.filter(x => x !== p.id) })} />
          <span><strong>{p.label}</strong><small>{p.description}</small></span></label>)}
      </div>)}
      {editable && <footer>{current && !current.builtin && <button className="li-outline" disabled={busy} onClick={() => void remove()}><Icon name="trash" size={14} />Delete group</button>}
        <button className="li-button" disabled={busy || !form.name.trim()} onClick={() => void save()}><Icon name="check" size={15} />Save group</button></footer>}
    </section>
  </div>;
}

// ── wallet ─────────────────────────────────────────────────────────────

function WalletPage({ me, staff, payTo, notify, reloadBoot }: { me: Me; staff: StaffMember[]; payTo: string; notify: (text: string, error?: boolean) => void; reloadBoot: () => Promise<void> }) {
  const wallet = useAction<number | null>('newsWallet', r => r.balance);
  const [to, setTo] = useState(payTo || me.cid);
  const [amount, setAmount] = useState('');
  const [note, setNote] = useState('');
  const [busy, setBusy] = useState(false);
  const [session, setSession] = useState<{ name: string; amount: number; note: string; at: number }[]>([]);
  useEffect(() => { if (payTo) setTo(payTo); }, [payTo]);
  async function send() {
    const value = Math.floor(Number(amount));
    const person = staff.find(s => s.cid === to);
    setBusy(true);
    const reply = await action('newsPay', { cid: to, amount: value, note });
    setBusy(false);
    if (!reply.ok) return notify(reply.error || 'The payment failed.', true);
    wallet.setData(reply.balance);
    setSession(list => [{ name: person?.name || to, amount: value, note, at: Date.now() }, ...list]);
    setAmount(''); setNote(''); notify(`Paid ${money(value)} to ${person?.name || 'staff'}.`); void reloadBoot();
  }
  return <div className="li-wallet">
    <div className="li-wallet-left">
      <section className="li-account"><span><Icon name="bank" size={26} /></span><div><small>COMPANY ACCOUNT</small><strong>{money(wallet.data)}</strong></div>
        <button onClick={() => void wallet.reload()}><Icon name="refresh" size={14} className={wallet.loading ? 'spin' : ''} />Refresh</button></section>
      <section className="li-card li-pay">
        <h3>Pay staff</h3>
        {!me.perms.pay && <p className="li-note">Your group cannot pay staff.</p>}
        <label><small>RECIPIENT</small><select value={to} disabled={!me.perms.pay} onChange={event => setTo(event.target.value)}>
          {staff.map(s => <option key={s.cid} value={s.cid}>{s.name} · {s.owner ? 'Owner' : s.online ? 'In the city' : 'Away'}</option>)}</select></label>
        <div className="li-pay-row">
          <label><small>AMOUNT</small><input inputMode="numeric" disabled={!me.perms.pay} value={amount} onChange={event => setAmount(event.target.value.replace(/\D/g, '').slice(0, 6))} placeholder="500" /></label>
          <label><small>NOTE</small><input disabled={!me.perms.pay} value={note} maxLength={60} onChange={event => setNote(event.target.value)} placeholder="Weekly pay, bonus" /><em>Shows up on their bank statement.</em></label>
        </div>
        <div className="li-quick">{[250, 500, 1000, 2500].map(v => <button key={v} disabled={!me.perms.pay} onClick={() => setAmount(String(v))}>{money(v)}</button>)}
          <button className="li-button" disabled={!me.perms.pay || busy || !amount || !to} onClick={() => void send()}><Icon name="send" size={14} />Send</button></div>
      </section>
    </div>
    <section className="li-card li-session">
      <h3>This session</h3>
      {session.length ? session.map(p => <div key={p.at} className="li-payment"><span className="li-avatar dark small">{initials(p.name)}</span><div><strong>{p.name}</strong><small>{p.note || 'No note'} · {ago(p.at)}</small></div><b>-{money(p.amount)}</b></div>)
        : <div className="li-session-empty"><Icon name="receipt" size={30} /><strong>No payments yet</strong><p>Payments you send while this page is open show up here.</p></div>}
    </section>
  </div>;
}
