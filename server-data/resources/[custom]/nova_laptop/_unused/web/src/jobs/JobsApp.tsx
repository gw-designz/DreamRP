import { useCallback, useEffect, useRef, useState } from 'react';
import type { CSSProperties, ReactNode } from 'react';
import { action, isPreview } from '../api';
import { Icon } from '../icons';
import { useAutoRefresh } from '../useAutoRefresh';
import { activeStatuses, statusLabels } from './types';
import type { Business, JobApplication, JobRules, JobStatus, JobsReply, JobsSnapshot, Vacancy } from './types';
import './jobs.css';

type Page = 'browse' | 'mine' | 'inbox' | 'desk' | 'listings' | 'applicants';
const list = <T,>(value: T[] | unknown): T[] => Array.isArray(value) ? value : [];
const normalize = (s: JobsSnapshot): JobsSnapshot => ({
  ...s, viewer: { ...s.viewer, business: s.viewer.business ? { ...s.viewer.business, grades: list(s.viewer.business.grades) } : null },
  listings: list<Vacancy>(s.listings).map(v => ({ ...v, questions: list(v.questions) })),
  companyListings: list<Vacancy>(s.companyListings).map(v => ({ ...v, questions: list(v.questions) })),
  myApplications: list<JobApplication>(s.myApplications).map(a => ({ ...a, answers: list(a.answers), timeline: list(a.timeline) })),
  applications: list<JobApplication>(s.applications).map(a => ({ ...a, answers: list(a.answers), timeline: list(a.timeline) })),
  notifications: list(s.notifications)
});
const cash = (value: number) => value.toLocaleString('en-US', { style: 'currency', currency: 'USD', maximumFractionDigits: 0 });
const date = (value: number) => new Date(value).toLocaleString('en-GB', { day: 'numeric', month: 'short', hour: '2-digit', minute: '2-digit' });
const initials = (name: string) => name.split(/\s+/).map(n => n[0]).filter(Boolean).slice(0, 2).join('');
const colors = ['#7760cf', '#c78351', '#4a929e', '#c97683', '#597cae', '#628d65'];
function Brand({ name, job, small = false }: { name: string; job: string; small?: boolean }) {
  const index = Array.from(job).reduce((n, c) => n + c.charCodeAt(0), 0) % colors.length;
  return <span className={'job-brand ' + (small ? 'small' : '')} style={{ '--company-color': colors[index] } as CSSProperties}>{initials(name.replace(/['’]s\b/g, ''))}</span>;
}
function Badge({ status }: { status: string }) { return <span className={'job-badge ' + status}><i />{statusLabels[status as JobStatus] || (status.charAt(0).toUpperCase() + status.slice(1))}</span>; }
function Empty({ icon = 'jobs', title, children }: { icon?: string; title: string; children: ReactNode }) {
  return <div className="jobs-empty"><span><Icon name={icon} size={30} /></span><h2>{title}</h2><p>{children}</p></div>;
}
function Modal({ title, subtitle, busy, close, children, wide = false }: { title: string; subtitle?: string; busy: boolean; close: () => void; children: ReactNode; wide?: boolean }) {
  const ref = useRef<HTMLDivElement>(null);
  useEffect(() => { ref.current?.querySelector<HTMLElement>('input,textarea,select,button')?.focus(); }, []);
  return <div className="jobs-modal-shade"><div ref={ref} className={'jobs-modal ' + (wide ? 'wide' : '')} role="dialog" aria-modal="true" aria-label={title}>
    <header><div><h2>{title}</h2>{subtitle && <p>{subtitle}</p>}</div><button disabled={busy} aria-label="Close Jobs Hub dialog" onClick={close}><Icon name="close" size={19} /></button></header>{children}
  </div></div>;
}
type Run = (name: string, payload: Record<string, unknown>) => Promise<JobsReply | null>;

export function JobsApp({ active, live, serverName }: { active: boolean; live: boolean; serverName: string }) {
  const [data, setData] = useState<JobsSnapshot | null>(null), [page, setPage] = useState<Page>('browse');
  const [search, setSearch] = useState(''), [category, setCategory] = useState('All categories'), [employment, setEmployment] = useState('Any schedule');
  const [selected, setSelected] = useState(''), [selectedApp, setSelectedApp] = useState(''), [appFilter, setAppFilter] = useState('all'), [vacancyFilter, setVacancyFilter] = useState('');
  const [loading, setLoading] = useState(true), [busy, setBusy] = useState(false), [error, setError] = useState(''), [toast, setToast] = useState('');
  const [connectionError, setConnectionError] = useState('');
  const [applyTo, setApplyTo] = useState<Vacancy | null>(null), [editor, setEditor] = useState<{ listing?: Vacancy } | null>(null);
  const [confirm, setConfirm] = useState<{ title: string; body: string; button: string; action: () => Promise<void> } | null>(null);
  const busyRef = useRef(false), mounted = useRef(true), sequence = useRef(0), latest = useRef<JobsSnapshot | null>(null);
  const apply = useCallback((next: JobsSnapshot) => {
    if (latest.current && latest.current.revision > next.revision) return;
    latest.current = normalize(next); setData(latest.current);
  }, []);
  useEffect(() => { mounted.current = true; return () => { mounted.current = false; }; }, []);
  const refresh = useCallback(async () => {
    if (busyRef.current) return;
    const seq = ++sequence.current, result = await action('jobsSnapshot');
    if (!mounted.current || seq !== sequence.current) return;
    setLoading(false);
    if (result.ok && result.jobs) { apply(result.jobs); setConnectionError(''); }
    else setConnectionError(result.error || 'Jobs Hub could not connect.');
  }, [apply]);
  useAutoRefresh(live, refresh, 'jobsChanged');
  useEffect(() => { if (!toast) return; const t = setTimeout(() => setToast(''), 4200); return () => clearTimeout(t); }, [toast]);
  useEffect(() => {
    if (!active || (!applyTo && !editor && !confirm)) return;
    const keys = (event: KeyboardEvent) => {
      if (event.key === 'Escape') {
        event.preventDefault(); event.stopImmediatePropagation();
        if (!busyRef.current) { setApplyTo(null); setEditor(null); setConfirm(null); }
      }
      if (event.key === 'Tab') {
        const controls = Array.from(document.querySelectorAll<HTMLElement>('.jobs-modal button:not(:disabled), .jobs-modal input:not(:disabled), .jobs-modal textarea:not(:disabled), .jobs-modal select:not(:disabled)'));
        const first = controls[0], last = controls[controls.length - 1];
        if (!first) return;
        if (!document.activeElement?.closest('.jobs-modal') || (!event.shiftKey && document.activeElement === last) || (event.shiftKey && document.activeElement === first)) {
          event.preventDefault(); (event.shiftKey ? last : first).focus();
        }
      }
    };
    window.addEventListener('keydown', keys, true); return () => window.removeEventListener('keydown', keys, true);
  }, [active, applyTo, editor, confirm]);
  const run: Run = async (name, payload) => {
    if (busyRef.current) return null;
    busyRef.current = true; setBusy(true); sequence.current++; setError('');
    const result = await action(name, { requestId: crypto.randomUUID(), ...payload });
    busyRef.current = false;
    if (!mounted.current) return null;
    setBusy(false);
    if (result.jobs) apply(result.jobs);
    if (result.ok) setToast(result.message || 'Saved.');
    else { setError(result.error || 'The change was not confirmed.'); void refresh(); }
    return result;
  };
  const business = data?.viewer.business;
  useEffect(() => { if (data && !business && ['desk', 'listings', 'applicants'].includes(page)) setPage('browse'); }, [data, business, page]);
  const filtered = data?.listings.filter(v => (category === 'All categories' || category === v.category) &&
    (employment === 'Any schedule' || employment === v.employment) && (v.title + ' ' + v.company + ' ' + v.location).toLowerCase().includes(search.toLowerCase())) || [];
  const selectedVacancy = filtered.find(v => v.id === selected) || filtered[0];
  const apps = (page === 'mine' ? data?.myApplications : data?.applications)?.filter(a => (appFilter === 'all' || a.status === appFilter) &&
    (!vacancyFilter || a.listingId === vacancyFilter) && (a.applicantName + ' ' + a.title + ' ' + a.company).toLowerCase().includes(search.toLowerCase())) || [];
  const selectedApplication = apps.find(a => a.id === selectedApp) || apps[0];
  const unread = data?.notifications.filter(n => !n.read).length || 0;
  const navigate = (next: Page) => { setPage(next); setSearch(''); setAppFilter('all'); setVacancyFilter(''); };
  const showApplications = (id: string) => { navigate('applicants'); setVacancyFilter(id); };
  const changeListing = (v: Vacancy, status: string) => {
    if (status === 'closed') setConfirm({ title: 'Close this vacancy?', body: 'Outstanding applications will be declined and applicants notified. Already accepted hires will still complete.', button: 'Close vacancy', action: async () => {
      const result = await run('jobsListingState', { id: v.id, revision: v.revision, status }); if (result?.ok) setConfirm(null);
    } });
    else void run('jobsListingState', { id: v.id, revision: v.revision, status });
  };
  return <div className="jobs-hub">
    <aside className="jobs-sidebar">
      <div className="jobs-wordmark"><span><Icon name="jobs" size={21} /></span><strong>jobs<span>hub</span></strong></div>
      <p className="jobs-sidebar-label">YOUR WORKING LIFE</p>
      <nav aria-label="Jobs Hub navigation">
        {[{ id: 'browse', icon: 'search', label: 'Find work' }, { id: 'mine', icon: 'clipboard', label: 'My applications' }, { id: 'inbox', icon: 'bell', label: 'Inbox' }].map(n =>
          <button key={n.id} className={page === n.id ? 'selected' : ''} onClick={() => navigate(n.id as Page)}><Icon name={n.icon} size={17} />{n.label}{n.id === 'inbox' && unread > 0 && <small>{unread}</small>}</button>)}
        {business && <><p className="jobs-sidebar-label employer-label">EMPLOYER WORKSPACE</p>{[{ id: 'desk', icon: 'grid', label: 'Hiring desk' }, { id: 'listings', icon: 'jobs', label: 'Your vacancies' }, { id: 'applicants', icon: 'people', label: 'Applications' }].map(n =>
          <button key={n.id} className={page === n.id ? 'selected' : ''} onClick={() => navigate(n.id as Page)}><Icon name={n.icon} size={17} />{n.label}{n.id === 'applicants' && !!data?.stats.pending && <small>{data.stats.pending}</small>}</button>)}</>}
      </nav>
      <div className="jobs-sidebar-bottom"><div className="jobs-sidebar-note"><Icon name={business ? 'building' : 'accepted'} size={21} /><strong>{business ? business.label : 'Good work starts here.'}</strong><p>{business ? 'Manage vacancies and build your team.' : 'Apply directly. Hear back in your inbox.'}</p></div><div className="jobs-profile"><span>{initials(data?.viewer.name || 'Resident')}</span><div><strong>{data?.viewer.name || 'Resident'}</strong><small>{business ? 'Business owner' : data?.viewer.currentJob.label || 'Resident'}</small></div></div></div>
    </aside>
    <main className="jobs-main">
      <header className="jobs-topbar"><div><span className="jobs-connection" />{serverName} <i>/</i> {business && ['desk','listings','applicants'].includes(page) ? 'Employer workspace' : 'Careers'}</div>
        {isPreview && <label className="jobs-preview-role">Preview as<select aria-label="Jobs preview role" disabled={busy} value={business ? 'boss' : 'resident'} onChange={async e => { const role = e.target.value; const result = await run('jobsPreviewRole', { role }); if (result?.ok) navigate(role === 'boss' ? 'desk' : 'browse'); }}><option value="resident">Resident</option><option value="boss">Business owner</option></select></label>}
      </header>
      {(error || connectionError) && <div className="jobs-error" role="alert"><Icon name="info" size={16} /><span>{error || connectionError}</span><button aria-label="Dismiss Jobs Hub error" onClick={() => { setError(''); setConnectionError(''); }}><Icon name="close" size={15} /></button></div>}
      {loading && !data ? <Empty title="Loading Jobs Hub…" icon="clock">Finding vacancies and checking your applications.</Empty> : !data ? <Empty title="We couldn’t connect." icon="wifi">{connectionError || error}</Empty> : <>
        <div className="jobs-page-heading"><div><p>{page === 'browse' ? 'OPPORTUNITIES IN YOUR CITY' : page === 'desk' ? 'YOUR BUSINESS, YOUR PEOPLE' : page === 'inbox' ? 'KEEP UP TO DATE' : 'JOBS HUB'}</p><h1>{({ browse: 'Find your next role.', mine: 'My applications', inbox: 'Your inbox', desk: 'Hiring desk', listings: 'Your vacancies', applicants: 'Review applications' })[page]}</h1></div>
          {business && ['desk','listings','applicants'].includes(page) ? <button className="jobs-primary" disabled={busy || !business.grades.length} onClick={() => setEditor({})}><Icon name="plus" size={16} />Post a vacancy</button> : <span className="jobs-heading-caption">{page === 'browse' ? data.listings.length + ' open vacancies' : page === 'mine' ? data.myApplications.length + ' applications' : unread + ' unread updates'}</span>}
        </div>
        {!data.viewer.canApply && <div className="jobs-framework-note"><Icon name="info" size={16} />Job applications require QBCore, QBox, or ESX. The current server is standalone.</div>}
        {page === 'browse' && <>
          <div className="jobs-filters"><label className="jobs-search"><Icon name="search" size={16} /><input aria-label="Search vacancies" placeholder="Job title, business or workplace" value={search} onChange={e => setSearch(e.target.value)} /></label>
            <select aria-label="Job category" value={category} onChange={e => setCategory(e.target.value)}>{['All categories', ...data.rules.categories].map(v => <option key={v}>{v}</option>)}</select>
            <select aria-label="Work schedule" value={employment} onChange={e => setEmployment(e.target.value)}>{['Any schedule', ...data.rules.employmentTypes].map(v => <option key={v}>{v}</option>)}</select>
          </div>
          <div className="jobs-board"><section className="jobs-vacancy-list" aria-label="Vacancies"><div className="jobs-list-caption"><strong>{filtered.length} opportunities</strong><span>Newest first</span></div>
            {filtered.map(v => <button className={'vacancy-card ' + (selectedVacancy?.id === v.id ? 'selected' : '')} key={v.id} onClick={() => setSelected(v.id)}>
              <div className="vacancy-card-top"><Brand name={v.company} job={v.job} small /><span><strong>{v.company}</strong><small>{v.location}</small></span><Icon name="right" size={15} /></div>
              <h2>{v.title}</h2><div className="vacancy-tags"><span>{v.category}</span><span>{v.employment}</span></div><footer><strong>{v.pay > 0 ? cash(v.pay) : 'Contact employer'}<small>{v.pay > 0 ? ' / paycheck' : ''}</small></strong><span>{v.available} {v.available === 1 ? 'opening' : 'openings'}</span></footer>
            </button>)}
            {!filtered.length && <Empty title="No matching vacancies." icon="search">Try another search, category or schedule.</Empty>}
          </section>
          {selectedVacancy ? <VacancyDetail vacancy={selectedVacancy} data={data} busy={busy} apply={() => setApplyTo(selectedVacancy)} showMine={() => navigate('mine')} /> :
            <section className="vacancy-detail"><Empty title="Your next opportunity will appear here.">Businesses post new roles as their teams grow. Check back soon.</Empty></section>}
          </div>
        </>}
        {(page === 'mine' || page === 'applicants') && <>
          <div className="jobs-filters application-filters"><label className="jobs-search"><Icon name="search" size={16} /><input aria-label="Search applications" placeholder={page === 'mine' ? 'Search your applications' : 'Search applicant or role'} value={search} onChange={e => setSearch(e.target.value)} /></label>
            <select aria-label="Application status" value={appFilter} onChange={e => setAppFilter(e.target.value)}><option value="all">All statuses</option>{Object.entries(statusLabels).map(([id,label]) => <option value={id} key={id}>{label}</option>)}</select>
            {page === 'applicants' && <select aria-label="Filter by vacancy" value={vacancyFilter} onChange={e => setVacancyFilter(e.target.value)}><option value="">All vacancies</option>{data.companyListings.map(v => <option value={v.id} key={v.id}>{v.title}</option>)}</select>}
          </div>
          <div className="jobs-board application-board"><section className="jobs-vacancy-list" aria-label="Applications"><div className="jobs-list-caption"><strong>{apps.length} applications</strong><span>Newest first</span></div>
            {apps.map(a => <button className={'application-card ' + (selectedApplication?.id === a.id ? 'selected' : '')} key={a.id} onClick={() => setSelectedApp(a.id)}>
              <div><span className="candidate-avatar">{page === 'mine' ? <Icon name="jobs" size={20} /> : initials(a.applicantName)}</span><span><strong>{page === 'mine' ? a.title : a.applicantName}</strong><small>{page === 'mine' ? a.company : a.title}</small></span></div><footer><Badge status={a.status} /><small>{date(a.createdAt)}</small></footer>
            </button>)}
            {!apps.length && <Empty title={page === 'mine' ? 'No applications yet.' : 'No applications to show.'} icon="clipboard">{page === 'mine' ? 'Find a role you like and send your first application.' : 'Publish a vacancy or try another filter.'}</Empty>}
          </section>
          <section className="application-detail">{selectedApplication ? <ApplicationDetail key={selectedApplication.id} app={selectedApplication} employer={page === 'applicants'} busy={busy} business={business} limits={data.rules.limits} run={run} confirm={setConfirm} closeConfirm={() => setConfirm(null)} /> : <Empty title="Select an application." icon="clipboard">Application details and updates will appear here.</Empty>}</section></div>
        </>}
        {page === 'inbox' && <div className="jobs-inbox jobs-scroll"><div className="inbox-toolbar"><p>Application updates stay here</p><button className="jobs-secondary" disabled={busy || !unread} onClick={() => void run('jobsReadNotices', { ids: data.notifications.filter(n => !n.read).slice(0,100).map(n => n.id) })}><Icon name="check" size={15} />Mark all read</button></div>
          {data.notifications.length ? [...data.notifications].sort((a,b) => b.at - a.at).map(n => <button className={'job-notification ' + (n.read ? '' : 'unread')} key={n.id} onClick={async () => { if (!n.read) await run('jobsReadNotices', { ids: [n.id] }); navigate('mine'); setSelectedApp(n.applicationId); }}>
            <span className="notification-glyph"><Icon name={n.title.includes('hired') ? 'accepted' : 'bell'} size={22} /></span><div><strong>{n.title}{!n.read && <i />}</strong><p>{n.body}</p><small>{date(n.at)}</small></div><Icon name="right" size={17} />
          </button>) : <Empty title="You’re all caught up." icon="bell">Application acknowledgements and decisions will appear here.</Empty>}
        </div>}
        {business && (page === 'desk' || page === 'listings') && <div className="jobs-employer jobs-scroll">
          {page === 'desk' && <><div className="employer-summary"><div><span><Icon name="jobs" size={17} />Live vacancies</span><strong>{data.stats.live}</strong><small>Open for applications</small></div><div><span><Icon name="people" size={17} />Awaiting review</span><strong>{data.stats.pending}</strong><small>Applicants ready to meet you</small></div><div><span><Icon name="accepted" size={17} />People hired</span><strong>{data.stats.hired}</strong><small>Confirmed job assignments</small></div></div>
            <div className="hiring-intro"><div><span className="hiring-intro-icon"><Icon name="building" size={24} /></span><div><h3>A good team starts with a conversation.</h3><p>Review experience, shortlist applicants and welcome your next colleague.</p></div></div><button className="jobs-secondary" onClick={() => navigate('applicants')}>Review applications<Icon name="right" size={15} /></button></div></>}
          {!business.grades.length && <div className="jobs-framework-note">No employee hiring grades are configured for this business. Ask server staff to configure approved hiring grades.</div>}
          <div className="jobs-section-heading"><h2>{page === 'desk' ? 'Your vacancies' : business.label}</h2><span>{data.companyListings.length} listings</span></div>
          {data.companyListings.length ? <div className="vacancy-table"><div className="vacancy-table-head"><span>Role / workplace</span><span>Applicants</span><span>Openings</span><span>Status</span><span>Manage</span></div>{data.companyListings.map(v => <div className="vacancy-table-row" key={v.id}>
            <button className="vacancy-role-link" onClick={() => showApplications(v.id)}><strong>{v.title}</strong><small>{v.location} · {v.gradeLabel}</small></button><button className="applicant-count" onClick={() => showApplications(v.id)}>{v.stats.applications}<small>{v.stats.pending} to review</small></button><span><strong>{v.available}</strong><small>of {v.openings} available</small></span><Badge status={v.status} /><div className="vacancy-actions"><button disabled={busy} aria-label={'Edit ' + v.title} title="Edit vacancy" onClick={() => setEditor({ listing: v })}><Icon name="sliders" size={16} /></button>
              {v.status === 'open' ? <button disabled={busy} onClick={() => changeListing(v, 'paused')}>Pause</button> : <button disabled={busy || v.available <= 0} onClick={() => changeListing(v, 'open')}>Publish</button>}
              {v.status !== 'closed' && <button className="vacancy-close" disabled={busy} aria-label={'Close vacancy ' + v.title} title="Close vacancy" onClick={() => changeListing(v, 'closed')}><Icon name="close" size={15} /></button>}
            </div></div>)}</div> : <Empty title="Make your first hire." icon="building">Post a vacancy with a clear description, the role’s requirements and a few questions for applicants.</Empty>}
          <div className="jobs-employer-footer"><Icon name="shield" size={15} /><p>Hiring uses your business’s approved employee grades. Salaries come from the server’s job settings.</p></div>
        </div>}
      </>}
    </main>
    {toast && <div className="jobs-toast" role="status"><Icon name="check" size={17} /><span>{toast}</span><button aria-label="Dismiss Jobs Hub notification" onClick={() => setToast('')}><Icon name="close" size={15} /></button></div>}
    {applyTo && data && <ApplyForm vacancy={applyTo} rules={data.rules} name={data.viewer.name} currentJob={data.viewer.currentJob.label} busy={busy} run={run} close={() => setApplyTo(null)} complete={() => { setApplyTo(null); navigate('mine'); }} />}
    {editor && business && data && <ListingForm listing={editor.listing} business={business} rules={data.rules} busy={busy} run={run} close={() => setEditor(null)} complete={() => { setEditor(null); navigate('listings'); }} />}
    {confirm && <Modal title={confirm.title} busy={busy} close={() => setConfirm(null)}><div className="jobs-confirm-body"><Icon name="info" size={28} /><p>{confirm.body}</p>{error && <p className="form-error" role="alert">{error}</p>}</div><footer className="jobs-form-footer"><button className="jobs-secondary" disabled={busy} onClick={() => setConfirm(null)}>Go back</button><button className="jobs-primary" disabled={busy} onClick={() => void confirm.action()}>{busy ? 'Saving…' : confirm.button}</button></footer></Modal>}
  </div>;
}

function VacancyDetail({ vacancy: v, data, busy, apply, showMine }: { vacancy: Vacancy; data: JobsSnapshot; busy: boolean; apply: () => void; showMine: () => void }) {
  const mine = data.myApplications.filter(a => a.listingId === v.id).sort((a,b) => b.createdAt - a.createdAt)[0];
  const applied = !!mine && (activeStatuses.includes(mine.status) || mine.status === 'hired');
  const cooldown = !!mine && data.serverTime - mine.updatedAt < data.rules.reapplyCooldownSeconds * 1000;
  const alreadyEmployed = data.viewer.currentJob.name === v.job;
  return <section className="vacancy-detail"><div className="vacancy-detail-scroll jobs-scroll">
    <div className="vacancy-company-heading"><Brand name={v.company} job={v.job} /><div><strong>{v.company}</strong><span><Icon name="pin" size={13} />{v.location}</span></div><span className="job-verified"><Icon name="shield" size={13} />In-city business</span></div>
    <h2>{v.title}</h2><div className="vacancy-tags detail-tags"><span>{v.employment}</span><span>{v.category}</span><span>{v.available} {v.available === 1 ? 'opening' : 'openings'}</span></div>
    <div className="vacancy-facts"><div><Icon name="wallet" size={17} /><span>Salary<strong>{v.pay > 0 ? cash(v.pay) + ' / paycheck' : 'Not configured'}</strong></span></div><div><Icon name="jobs" size={17} /><span>Starting role<strong>{v.gradeLabel}</strong></span></div></div>
    <div className="vacancy-description"><h3>About the role</h3><p>{v.description}</p>{v.requirements && <><h3>What we’re looking for</h3><ul>{v.requirements.split('\n').filter(Boolean).map((line,i) => <li key={i}>{line.replace(/^[-•]\s*/, '')}</li>)}</ul></>}
      {!!v.questions.length && <div className="application-tip"><Icon name="clipboard" size={19} /><p><strong>A little about you</strong>This employer has {v.questions.length} {v.questions.length === 1 ? 'question' : 'questions'} for applicants. You’ll answer them with your application.</p></div>}
    </div><div className="vacancy-posted">Posted {date(v.createdAt)} · Closes {new Date(v.expiresAt).toLocaleDateString('en-GB', { day: 'numeric', month: 'short' })}</div>
  </div><footer className="vacancy-apply-bar"><div><strong>{applied ? 'Your application is on file' : alreadyEmployed ? 'You already work here' : 'Interested in the role?'}</strong><small>{applied ? statusLabels[mine.status] : alreadyEmployed ? 'Speak to your boss about progression.' : cooldown ? 'You can reapply after the cooldown.' : 'Apply directly to the employer.'}</small></div><button className="jobs-primary" disabled={busy || (!applied && (!data.viewer.canApply || alreadyEmployed || cooldown))} onClick={applied ? showMine : apply}>{applied ? 'View application' : 'Apply now'}<Icon name="right" size={15} /></button></footer></section>;
}

function ApplicationDetail({ app, employer, busy, business, limits, run, confirm, closeConfirm }: { app: JobApplication; employer: boolean; busy: boolean; business?: Business | null; limits: Record<string, number>; run: Run;
  confirm: (value: { title: string; body: string; button: string; action: () => Promise<void> }) => void; closeConfirm: () => void }) {
  const [message, setMessage] = useState(''), [note, setNote] = useState(app.internalNote || ''), [formError, setFormError] = useState('');
  useEffect(() => setNote(app.internalNote || ''), [app.internalNote]);
  const reviewable = ['submitted', 'shortlisted'].includes(app.status), canHire = !!business?.grades.some(g => g.level === app.grade) && business.name === app.job;
  const decide = async (decision: string) => {
    const result = await run('jobsReview', { id: app.id, revision: app.revision, decision, message });
    if (result?.ok) { setMessage(''); closeConfirm(); } else if (result) setFormError(result.error || 'Decision could not be saved.');
  };
  return <>
    <div className="application-detail-scroll jobs-scroll"><div className="candidate-heading"><span className="candidate-avatar large">{initials(app.applicantName)}</span><div><p>{employer ? 'APPLICATION FOR ' + app.title.toUpperCase() : app.company}</p><h2>{employer ? app.applicantName : app.title}</h2><small>Applied {date(app.createdAt)}</small></div></div><Badge status={app.status} />
      {app.status === 'hired' && <div className="application-outcome hired"><Icon name="accepted" size={22} /><div><strong>{employer ? 'Job assigned successfully' : 'Welcome to the team.'}</strong><p>{app.company} · {app.gradeLabel}</p></div></div>}
      {app.status === 'pending_start' && <div className="application-outcome"><Icon name="clock" size={22} /><div><strong>Accepted. Waiting for character login.</strong><p>The job will be assigned when the applicant is online.</p></div></div>}
      {app.assignmentIssue && <div className="jobs-framework-note"><Icon name="info" size={17} />{app.assignmentIssue}</div>}
      <div className="applicant-facts"><div><span>In-game contact</span><strong>{app.contact}</strong></div><div><span>Availability</span><strong>{app.availability}</strong></div><div><span>Job when applying</span><strong>{app.previousJob.label}</strong></div><div><span>Starting role</span><strong>{app.gradeLabel}</strong></div></div>
      <div className="application-copy"><h3>Introduction</h3><p>{app.cover}</p>{app.experience && <><h3>Experience</h3><p>{app.experience}</p></>}{app.answers.map((a,i) => <div className="application-answer" key={i}><h3>{a.question}</h3><p>{a.answer}</p></div>)}</div>
      <div className="application-timeline"><h3>Application timeline</h3>{[...app.timeline].reverse().map((entry,i) => <div key={i}><i /><span><strong>{statusLabels[entry.status]}</strong><p>{entry.message}</p><small>{entry.actor} · {date(entry.at)}</small></span></div>)}</div>
      {employer && <div className="employer-private-note"><label htmlFor="review-note"><Icon name="shield" size={14} />Private team note</label><textarea id="review-note" aria-label="Private team note" maxLength={limits.internalNote} rows={3} placeholder="Only bosses of this business can read this." value={note} disabled={busy} onChange={e => setNote(e.target.value)} /><button className="jobs-secondary" disabled={busy || note === (app.internalNote || '')} onClick={async () => { const r = await run('jobsNote', { id: app.id, revision: app.revision, note }); if (!r?.ok) setFormError(r?.error || 'Note was not saved.'); }}>Save private note</button></div>}
      <p className="application-reference">Application reference: {app.id}</p>
    </div>
    {employer && reviewable && <footer className="application-review-bar"><label>Message to applicant <small>Optional</small><textarea aria-label="Message to applicant" placeholder="A welcome message, next steps or feedback…" maxLength={limits.message} rows={2} value={message} disabled={busy} onChange={e => setMessage(e.target.value)} /></label>
      {formError && <p className="form-error" role="alert">{formError}</p>}
      <div><button className="jobs-danger" disabled={busy || !canHire} onClick={() => confirm({ title: 'Decline this application?', body: app.applicantName + ' will receive your decision and message in their inbox.', button: 'Decline application', action: () => decide('rejected') })}>Decline</button><button className="jobs-secondary" disabled={busy || !canHire || app.status === 'shortlisted'} onClick={() => void decide('shortlisted')}>Shortlist</button><button className="jobs-primary" disabled={busy || !canHire} onClick={() => confirm({ title: 'Hire ' + app.applicantName + '?', body: 'Accepting assigns ' + app.company + ' — ' + app.gradeLabel + ' as their active job. Offline applicants receive the job at their next login. The applicant will be notified.', button: 'Accept & hire', action: () => decide('accept') })}><Icon name="accepted" size={16} />Accept & hire</button></div>
    </footer>}
    {!employer && ['submitted','shortlisted','pending_start'].includes(app.status) && <footer className="application-withdraw-bar"><p>You can withdraw before the job is assigned.</p><button className="jobs-secondary" disabled={busy} onClick={() => confirm({ title: 'Withdraw this application?', body: 'The employer will no longer be able to hire you from this application.', button: 'Withdraw application', action: async () => {
      const result = await run('jobsWithdraw', { id: app.id, revision: app.revision }); if (result?.ok) closeConfirm();
    } })}>Withdraw application</button></footer>}
  </>;
}

function validateText(value: string, max: number, min: number, name: string) {
  const bytes = new TextEncoder().encode(value.trim()).length;
  return bytes < min ? name + ' needs at least ' + min + ' characters.' : bytes > max ? name + ' is too long (' + max + ' UTF-8 bytes maximum).' : '';
}
function Field({ label, hint, children }: { label: string; hint?: string; children: ReactNode }) {
  return <label className="jobs-field"><span>{label}{hint && <small>{hint}</small>}</span>{children}</label>;
}
function ApplyForm({ vacancy, rules, name, currentJob, busy, run, close, complete }: { vacancy: Vacancy; rules: JobRules; name: string; currentJob: string; busy: boolean; run: Run; close: () => void; complete: () => void }) {
  const [contact, setContact] = useState(''), [cover, setCover] = useState(''), [experience, setExperience] = useState(''), [availability, setAvailability] = useState('');
  const [answers, setAnswers] = useState(vacancy.questions.map(() => '')), [consent, setConsent] = useState(false), [error, setError] = useState('');
  const request = useRef(crypto.randomUUID());
  async function submit() {
    const checks: [string, string, number][] = [[contact,'contact',2],[cover,'cover',20],[experience,'experience',0],[availability,'availability',3], ...answers.map(a => [a,'answer',1] as [string,string,number])];
    const invalid = checks.map(([v,key,min]) => validateText(v,rules.limits[key],min,key === 'cover' ? 'Introduction' : key)).find(Boolean);
    if (invalid || !consent) { setError(invalid || 'Confirm the job assignment before submitting.'); return; }
    const result = await run('jobsApply', { requestId: request.current, listingId: vacancy.id, revision: vacancy.revision, contact, cover, experience, availability, answers, consent });
    if (result?.ok) complete(); else if (result) setError(result.error || 'Application was not confirmed.');
  }
  return <Modal title="Apply for this role" subtitle={vacancy.title + ' · ' + vacancy.company} busy={busy} close={close} wide>
    <form onSubmit={e => { e.preventDefault(); void submit(); }}><div className="jobs-form-scroll jobs-scroll"><div className="applying-as"><span className="candidate-avatar">{initials(name)}</span><div><strong>{name}</strong><small>Applying as your current character · {currentJob}</small></div><Icon name="shield" size={20} /></div>
      <div className="jobs-form-grid"><Field label="In-game contact" hint="Phone or preferred contact"><input aria-label="In-game contact" required minLength={2} maxLength={rules.limits.contact} value={contact} disabled={busy} onChange={e => setContact(e.target.value)} placeholder="e.g. 555-0123" /></Field><Field label="Availability"><input aria-label="Availability" required minLength={3} maxLength={rules.limits.availability} value={availability} disabled={busy} onChange={e => setAvailability(e.target.value)} placeholder="Days and times you can work" /></Field></div>
      <Field label="Introduce yourself" hint="Tell the employer why you’re interested"><textarea aria-label="Introduce yourself" required minLength={20} rows={4} maxLength={rules.limits.cover} value={cover} disabled={busy} onChange={e => setCover(e.target.value)} placeholder="What would you bring to the team?" /></Field>
      <Field label="Relevant experience" hint="Optional"><textarea aria-label="Relevant experience" rows={3} maxLength={rules.limits.experience} value={experience} disabled={busy} onChange={e => setExperience(e.target.value)} placeholder="Previous work, practical skills or training" /></Field>
      {!!vacancy.questions.length && <div className="jobs-form-section"><Icon name="clipboard" size={17} /><h3>A few questions from the employer</h3></div>}
      {vacancy.questions.map((question,i) => <Field label={question} key={i}><textarea aria-label={'Employer question ' + (i+1)} required rows={2} maxLength={rules.limits.answer} disabled={busy} value={answers[i]} onChange={e => setAnswers(current => current.map((v,index) => index === i ? e.target.value : v))} /></Field>)}
      <label className="jobs-consent"><input type="checkbox" aria-label="Allow accepted job assignment" checked={consent} disabled={busy} onChange={e => setConsent(e.target.checked)} /><span>If accepted, make <strong>{vacancy.company} — {vacancy.gradeLabel}</strong> my active job. This can replace my current job.</span></label>
      <p className="jobs-form-privacy"><Icon name="shield" size={13} />Your application is visible to this business’s bosses and, if configured by the server, its recruitment Discord channel.</p>
      {error && <p className="form-error" role="alert">{error}</p>}</div><footer className="jobs-form-footer"><span>Updates arrive in your Jobs Hub inbox.</span><button type="button" className="jobs-secondary" disabled={busy} onClick={close}>Cancel</button><button className="jobs-primary" type="submit" disabled={busy || !consent}><Icon name="send" size={16} />{busy ? 'Sending…' : 'Send application'}</button></footer></form>
  </Modal>;
}

function ListingForm({ listing, business, rules, busy, run, close, complete }: { listing?: Vacancy; business: Business; rules: JobRules; busy: boolean; run: Run; close: () => void; complete: () => void }) {
  const [form, setForm] = useState({ title: listing?.title || '', location: listing?.location || '', category: listing?.category || rules.categories[0],
    employment: listing?.employment || rules.employmentTypes[0], grade: listing?.grade ?? business.grades[0]?.level ?? 0,
    openings: String(listing?.openings || 1), description: listing?.description || '', requirements: listing?.requirements || '',
    questions: listing?.questions.join('\n') || '' });
  const [error, setError] = useState(''), request = useRef(crypto.randomUUID());
  const set = (key: string, value: string | number) => { setForm(current => ({ ...current, [key]: value })); setError(''); };
  const grade = business.grades.find(g => g.level === Number(form.grade));
  async function submit() {
    const questions = form.questions.split('\n').map(q => q.trim()).filter(Boolean);
    const values: [string,string,number][] = [[form.title,'title',3],[form.location,'location',2],[form.description,'description',30],[form.requirements,'requirements',0], ...questions.map(q => [q,'question',3] as [string,string,number])];
    const invalid = values.map(([v,key,min]) => validateText(v,rules.limits[key],min,key)).find(Boolean);
    if (invalid || questions.length > rules.maxQuestions) { setError(invalid || 'Use no more than ' + rules.maxQuestions + ' questions.'); return; }
    const result = await run('jobsSaveListing', { ...form, id: listing?.id, revision: listing?.revision, grade: Number(form.grade), openings: Number(form.openings), questions, requestId: request.current });
    if (result?.ok) complete(); else if (result) setError(result.error || 'Vacancy was not confirmed.');
  }
  return <Modal title={listing ? 'Edit vacancy' : 'Post a vacancy'} subtitle={business.label + ' · Employer workspace'} busy={busy} close={close} wide>
    <form onSubmit={e => { e.preventDefault(); void submit(); }}><div className="jobs-form-scroll jobs-scroll">
      <Field label="Job title"><input aria-label="Job title" required minLength={3} maxLength={rules.limits.title} value={form.title} disabled={busy} onChange={e => set('title',e.target.value)} placeholder="e.g. Workshop technician" /></Field>
      <div className="jobs-form-grid"><Field label="Workplace"><input aria-label="Workplace" required minLength={2} maxLength={rules.limits.location} value={form.location} disabled={busy} onChange={e => set('location',e.target.value)} placeholder="Neighbourhood or business address" /></Field><Field label="Category"><select aria-label="Vacancy category" value={form.category} disabled={busy} onChange={e => set('category',e.target.value)}>{rules.categories.map(v => <option key={v}>{v}</option>)}</select></Field>
        <Field label="Employment type"><select aria-label="Employment type" disabled={busy} value={form.employment} onChange={e => set('employment',e.target.value)}>{rules.employmentTypes.map(v => <option key={v}>{v}</option>)}</select></Field><Field label="Openings"><input aria-label="Openings" type="number" min={Math.max(1,listing?.stats.reserved || 0)} max={rules.maxOpenings} step={1} required value={form.openings} disabled={busy} onChange={e => set('openings',e.target.value)} /></Field>
        <Field label="Hiring grade" hint={listing?.stats.applications ? 'Locked after applications' : 'Approved employee grades'}><select aria-label="Hiring grade" disabled={busy || !!listing?.stats.applications} value={form.grade} onChange={e => set('grade',Number(e.target.value))}>{business.grades.map(g => <option value={g.level} key={g.level}>{g.label}</option>)}</select></Field><div className="vacancy-salary-preview"><span>Salary</span><strong>{grade?.pay ? cash(grade.pay) + ' / paycheck' : 'Not configured'}</strong><small>Controlled by the server’s job settings.</small></div></div>
      <Field label="About the role" hint="Duties, team and what the job involves"><textarea aria-label="About the role" rows={4} required minLength={30} maxLength={rules.limits.description} disabled={busy} value={form.description} onChange={e => set('description',e.target.value)} placeholder="Give applicants a clear picture of the role." /></Field>
      <Field label="Requirements" hint="One requirement per line"><textarea aria-label="Requirements" rows={3} maxLength={rules.limits.requirements} disabled={busy} value={form.requirements} onChange={e => set('requirements',e.target.value)} placeholder="Skills, licences or availability you need" /></Field>
      <Field label="Application questions" hint={'Optional · one per line · maximum ' + rules.maxQuestions}><textarea aria-label="Application questions" rows={3} maxLength={rules.maxQuestions*(rules.limits.question+1)} disabled={busy} value={form.questions} onChange={e => set('questions',e.target.value)} placeholder="What would make you a good fit for our team?" /></Field>
      <p className="jobs-form-privacy"><Icon name="info" size={14} />Listings expire after {rules.lifetimeDays} days. You can pause, edit, or close them at any time. Existing applications retain their original answers.</p>{error && <p className="form-error" role="alert">{error}</p>}
    </div><footer className="jobs-form-footer"><span>{listing ? 'Changes apply to this vacancy.' : 'Your vacancy will be visible to residents.'}</span><button type="button" className="jobs-secondary" disabled={busy} onClick={close}>Cancel</button><button type="submit" className="jobs-primary" disabled={busy || !grade}>{busy ? 'Saving…' : listing ? 'Save vacancy' : 'Publish vacancy'}<Icon name="right" size={15} /></button></footer></form>
  </Modal>;
}
