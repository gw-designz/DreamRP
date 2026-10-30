/* The news business in the browser preview: the same replies as server/news.lua, kept in memory. */
import type { Response } from '../types';
import type { Article, Draft, FeedItem, Group, Issue, IssuePage, Me, Perm, Photo, StaffMember } from './types';
import { SLOTS } from './types';

const DAY = 86400000;
const t0 = Date.now();
const scene = (a: string, b: string, label: string) => 'data:image/svg+xml;utf8,' + encodeURIComponent(
  `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 320 240"><defs><linearGradient id="g" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="${a}"/><stop offset="1" stop-color="${b}"/></linearGradient></defs><rect width="320" height="240" fill="url(#g)"/><circle cx="250" cy="60" r="26" fill="#fff6"/><path d="M0 190 L70 120 L130 170 L200 100 L320 200 L320 240 L0 240Z" fill="#0004"/><text x="16" y="226" font-family="Arial" font-size="15" fill="#fffc">${label}</text></svg>`);

const PERMS: Perm[] = ['write', 'review', 'edit', 'publish', 'print', 'staff', 'pay'];
const me: Me = { cid: 'PS1001', name: 'Percival Small', staff: true, onJob: true, owner: true, onDuty: false, groupId: 0, perms: Object.fromEntries(PERMS.map(p => [p, true])) as Me['perms'] };
let balance = -36438;
const groups: Group[] = [{ id: 1, name: 'Employee', description: 'Default role for employees', permissions: ['write', 'print'], builtin: true, members: 0 }];
const names = ['Aaron Carter', 'Alice Liddell', 'Bogg Dann', 'Caleb Anderson', 'Camille Leone', 'Delver Lee', 'Eddie Marsh', 'Fiona Grey'];
const staff: StaffMember[] = [
  { cid: me.cid, name: me.name, owner: true, groupId: 0, since: t0 - 2 * DAY, online: true, onDuty: false, you: true },
  ...names.map((name, i) => ({ cid: `C${i}`, name, owner: false, groupId: 1, since: t0 - (i % 2) * DAY, online: i % 3 === 0, onDuty: i === 3, you: false }))
];
let photos: Photo[] = [
  ['#3b4b5c', '#a8754a', 'Vespucci pier'], ['#22313f', '#6b8fb3', 'Courthouse'], ['#4a2c2a', '#d77a61', 'Clothing store'],
  ['#1f3b2d', '#76a87b', 'Mirror Park'], ['#2e2a44', '#8c7ae6', 'Night shift'], ['#3d3d3d', '#b0b0b0', 'Pillbox'],
].map(([a, b, label], i) => ({ id: i + 1, url: scene(a, b, label), origin: 'camera' as const, at: t0 - i * DAY / 3 }));
const phone = [['#5a3e2b', '#f0c27b', 'Sunset'], ['#203a43', '#2c5364', 'Del Perro'], ['#41295a', '#2f0743', 'Club'], ['#134e5e', '#71b280', 'Golf']]
  .map(([a, b, label], i) => ({ url: scene(a, b, label), at: t0 - (i + 1) * DAY }));
let articles: Article[] = [
  { id: 1, headline: 'Broke, desperate clown resorts to robbing clothing store', body: 'Having trouble getting booked for children’s birthdays, and not getting paid to lurk in parks, this broke and desperate clown has resorted to robbing hard working local businesses. Are clowns compatible with society? You be the judge.', photos: [photos[2]!.url], author: 'Aaron Carter', status: 'approved', at: t0 - DAY },
  { id: 2, headline: 'Hospital turned crime scene as clown chlamydia overburdens staff', body: 'Pillbox staff were seen overwhelmed as a wave of clown-related admissions filled every bed on the second floor.', photos: [photos[5]!.url], author: 'Alice Liddell', status: 'approved', at: t0 - DAY },
  { id: 3, headline: 'New Gruppe Sechs fleet and staff spotted outside courthouse', body: 'A very expensive fleet of armored trucks was seen lined up outside the courthouse this morning.', photos: [photos[1]!.url], author: 'Bogg Dann', status: 'pending', at: t0 - 3600000 },
  { id: 4, headline: 'Mayor gives obese man CPR for 40 minutes until EMS arrives', body: 'A tough man and a tough situation. The mayor kept going until help arrived.', photos: [], author: 'Caleb Anderson', status: 'pending', at: t0 - 7200000 },
  { id: 5, headline: 'Would you like a side of ass with that burger?', body: 'Local pimps and prostitutes take advantage of the space in front of a popular burger joint.', photos: [], author: me.name, status: 'rejected', at: t0 - 2 * DAY, mine: true },
  ...['Recent Jailings', 'Current Tax Rates', 'Upcoming Elections', 'Recent Election Results', 'Weather Forecast', 'Classifieds']
    .map((headline, i) => ({ id: 100 + i, headline, body: 'Edit this staff column in the magazine editor.', photos: [], author: 'LIFEINVADER Staff', status: 'column' as const, at: t0 })),
];
let feed: FeedItem[] = [
  { id: 2, kind: 'issue', text: 'published Vol. 1: LSBN Magazine - Ed: 1', actor: me.name, at: t0 - DAY },
  { id: 1, kind: 'article', text: 'submitted "Broke, desperate clown resorts to robbing clothing store" for review', actor: 'Aaron Carter', at: t0 - 2 * DAY },
];
let draft: Draft = { title: '', pages: [{ section: 'Cover', layout: 'feature-left', slots: [false, false] }] };
const firstIssue: IssuePage[] = [
  { section: 'Cover', layout: 'feature-left', items: [{ headline: articles[0]!.headline, body: articles[0]!.body, photos: articles[0]!.photos, author: 'Aaron Carter' }, { headline: articles[1]!.headline, body: articles[1]!.body, photos: articles[1]!.photos, author: 'Alice Liddell' }] },
  { section: "What's going on?", layout: 'three', items: [{ headline: 'New Gruppe Sechs fleet and staff spotted outside courthouse', body: articles[2]!.body, photos: articles[2]!.photos, author: 'Bogg Dann' }, { headline: 'Mayor gives obese man CPR for 40 minutes until EMS arrives', body: articles[3]!.body, photos: [], author: 'Caleb Anderson' }, { headline: 'Would you like a side of ass with that burger?', body: articles[4]!.body, photos: [], author: me.name }] },
];
let issues: Issue[] = [
  { id: 1, volume: 1, title: 'LSBN Magazine - Ed: 1', cover: articles[0]!.photos[0]!, at: t0 - DAY, by: me.name, pages: firstIssue },
];
let nextId = 200;
const post = (kind: string, text: string) => { feed = [{ id: ++nextId, kind, text, actor: me.name, at: Date.now() }, ...feed]; };
const company = () => ({ label: 'News', balance, staff: staff.length, onDuty: staff.filter(s => s.onDuty).length, groups: groups.length });
const ownerGroup: Group = { id: 0, name: 'Owner', description: 'Every permission, set by citizen ID in config.lua', permissions: PERMS, builtin: true, owner: true,
  members: 1, holders: [{ cid: me.cid, name: me.name }] };
const counted = () => [ownerGroup, ...groups.map(g => ({ ...g, members: staff.filter(s => s.groupId === g.id).length }))];
const mine = (a: Article) => ({ ...a, mine: a.author === me.name });

export function previewNews(name: string, input: Record<string, any>): Response {
  switch (name) {
    case 'newsBoot': return { ok: true, me, company: company() };
    case 'newsFeed': return { ok: true, feed, company: company() };
    case 'newsStaff': return { ok: true, staff, groups: counted() };
    case 'newsGroups': return { ok: true, groups: counted(), permissions: [
      { id: 'write', section: 'Weazel Writer', label: 'Write articles', description: 'Employee can write articles and submit them for review' },
      { id: 'review', section: 'Weazel Writer', label: 'Review articles', description: 'Employee can approve, reject and restore submitted articles' },
      { id: 'edit', section: 'Magazine', label: 'Edit the magazine', description: 'Employee can lay out pages and edit staff columns' },
      { id: 'publish', section: 'Magazine', label: 'Publish issues', description: 'Employee can publish the magazine to the newsstand' },
      { id: 'print', section: 'Magazine', label: 'Print copies', description: 'Employee can print copies of published issues' },
      { id: 'staff', section: 'Business', label: 'Manage staff', description: 'Employee can add and remove staff and move them between groups' },
      { id: 'pay', section: 'Business', label: 'Pay staff', description: 'Employee can pay staff from the company account' }] };
    case 'newsHire': {
      const id = Number(input.serverId);
      if (!id) return { ok: false, error: 'Nobody with that ID is in the city.' };
      staff.push({ cid: `N${id}`, name: `Resident #${id}`, owner: false, groupId: 1, since: Date.now(), online: true, onDuty: false, you: false });
      post('staff', `added Resident #${id} as a friend`); return { ok: true };
    }
    case 'newsFire': { const i = staff.findIndex(s => s.cid === input.cid && !s.owner); if (i >= 0) staff.splice(i, 1); return { ok: true }; }
    case 'newsSetGroup': { const s = staff.find(m => m.cid === input.cid); if (s) s.groupId = Number(input.groupId); return { ok: true }; }
    case 'newsSaveGroup': {
      const existing = groups.find(g => g.id === input.id);
      if (existing) Object.assign(existing, existing.builtin ? { permissions: input.permissions } : { name: input.name, description: input.description, permissions: input.permissions });
      else groups.push({ id: ++nextId, name: input.name || 'New group', description: input.description || '', permissions: input.permissions || [], builtin: false, members: 0 });
      return { ok: true, id: existing?.id ?? nextId };
    }
    case 'newsDeleteGroup': { const i = groups.findIndex(g => g.id === input.id && !g.builtin); if (i >= 0) groups.splice(i, 1); staff.forEach(s => { if (s.groupId === input.id) s.groupId = 1; }); return { ok: true }; }
    case 'newsDuty': me.onDuty = !me.onDuty; staff[0]!.onDuty = me.onDuty; return { ok: true, onDuty: me.onDuty };
    case 'newsWallet': return { ok: true, balance };
    case 'newsPay': {
      const amount = Math.floor(Number(input.amount));
      if (!(amount > 0)) return { ok: false, error: 'Pay between $1 and $25000.' };
      if (balance < amount) return { ok: false, error: 'The company account cannot cover that.' };
      balance -= amount; return { ok: true, balance };
    }
    case 'newsPhotos': return { ok: true, photos, capacity: 60 };
    case 'newsPhoneGallery': return { ok: true, photos: phone };
    case 'newsImport': {
      const ids: number[] = [];
      for (const url of input.urls || []) {
        let found = photos.find(p => p.url === url);
        if (!found) { found = { id: ++nextId, url, origin: 'phone', at: Date.now() }; photos = [found, ...photos]; }
        ids.push(found.id);
      }
      return { ok: true, ids, photos };
    }
    case 'newsDeletePhoto': photos = photos.filter(p => p.id !== input.id); return { ok: true, photos };
    case 'newsArticles': return { ok: true, articles: {
      mine: articles.filter(a => a.author === me.name && ['pending', 'approved', 'published', 'rejected'].includes(a.status)).map(mine),
      pending: articles.filter(a => a.status === 'pending').map(mine),
      approved: articles.filter(a => a.status === 'approved').map(mine),
      columns: articles.filter(a => a.status === 'column').map(mine) } };
    case 'newsSubmit': {
      if (!input.headline?.trim()) return { ok: false, error: 'Give the story a headline of up to 75 characters.' };
      if (!input.body?.trim()) return { ok: false, error: 'Write the story first. It can be up to 1,000 characters.' };
      const urls = (input.photos || []).map((id: number) => photos.find(p => p.id === id)?.url).filter(Boolean);
      articles.push({ id: ++nextId, headline: input.headline, body: input.body, photos: urls, author: me.name, status: 'pending', at: Date.now() });
      post('article', `submitted "${input.headline}" for review`); return { ok: true, id: nextId };
    }
    case 'newsReview': { const a = articles.find(x => x.id === input.id); if (a) { a.status = input.approve ? 'approved' : 'rejected'; a.reviewer = me.name; } return { ok: true }; }
    case 'newsColumn': { const a = articles.find(x => x.id === input.id); if (a) a.body = input.body; return { ok: true }; }
    case 'newsTrashList': return { ok: true, articles: articles.filter(a => a.status === 'trashed' || a.status === 'rejected').map(mine) };
    case 'newsTrash': { const a = articles.find(x => x.id === input.id); if (a) a.status = 'trashed'; return { ok: true }; }
    case 'newsRestore': { const a = articles.find(x => x.id === input.id); if (a) a.status = 'pending'; return { ok: true }; }
    case 'newsPurge': articles = articles.filter(a => a.id !== input.id); return { ok: true };
    case 'newsDraft': return { ok: true, draft: structuredClone(draft), nextVolume: issues.length + 1 };
    case 'newsSaveDraft': draft = structuredClone(input.draft); return { ok: true };
    case 'newsPublish': {
      const pages: IssuePage[] = draft.pages.map(page => ({ section: page.section, layout: page.layout, items: Array.from({ length: SLOTS[page.layout] }, (_, n) => {
        const a = articles.find(x => x.id === page.slots[n]);
        return a ? { headline: a.headline, body: a.body, photos: a.photos, author: a.author } : false;
      }) }));
      const lead = pages[0]?.items[0];
      if (!lead) return { ok: false, error: 'Put an article in the first slot of the cover page.' };
      const volume = issues.length + 1;
      issues = [{ id: ++nextId, volume, title: input.title || draft.title || `Issue ${volume}`, cover: lead.photos[0] || null, at: Date.now(), by: me.name, pages }, ...issues];
      articles.forEach(a => { if (draft.pages.some(p => p.slots.includes(a.id)) && a.status === 'approved') a.status = 'published'; });
      draft = { title: '', pages: [{ section: 'Cover', layout: 'feature-left', slots: [false, false] }] };
      post('issue', `published Vol. ${volume}: ${issues[0]!.title}`); return { ok: true, issue: nextId };
    }
    case 'newsIssues': return { ok: true, issues: issues.map(({ pages: _pages, ...summary }) => summary) };
    case 'newsIssue': { const issue = issues.find(i => i.id === input.id); return issue ? { ok: true, issue } : { ok: false, error: 'That issue no longer exists.' }; }
    case 'newsPrint': return { ok: true, seconds: Number(input.copies) * 3 };
    case 'newsPlacePrinter': return { ok: true };
  }
  return { ok: false, error: 'Unknown action.' };
}
