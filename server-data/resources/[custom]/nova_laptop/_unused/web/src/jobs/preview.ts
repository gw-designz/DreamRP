// Browser-only demonstration. None of these identities or job changes reach FiveM.
import type { Business, JobApplication, JobRules, JobStatus, JobsReply, JobsSnapshot, Vacancy } from './types';
import { activeStatuses } from './types';
const KEY = 'nova-jobs-preview-v1', RESIDENT = 'preview-resident';
const business: Business = { name: 'mechanic', label: "Benny's Original Motor Works", grades: [{ level: 0, label: 'Apprentice', pay: 150 }, { level: 1, label: 'Technician', pay: 200 }] };
const rules: JobRules = {
  categories: ['Automotive', 'Hospitality', 'Retail', 'Transport', 'Public service', 'Professional', 'Other'],
  employmentTypes: ['Full-time', 'Part-time', 'Contract'], maxOpenings: 50, maxQuestions: 4,
  maxActiveApplications: 5, reapplyCooldownSeconds: 3600, lifetimeDays: 30,
  limits: { title: 80, location: 100, description: 2500, requirements: 1500, question: 180, answer: 600, cover: 1800, experience: 1200, availability: 240, contact: 80, message: 500, internalNote: 1200 }
};
type Application = JobApplication & { applicantKey: string };
type Store = { revision: number; role: 'resident' | 'boss'; residentJob: JobsSnapshot['viewer']['currentJob']; listings: Vacancy[]; applications: Application[]; receipts: Record<string, string> };
function fresh(): Store {
  const definitions = [
    ['mechanic', business.label, 'Workshop technician', 'Automotive', 'Full-time', 'Strawberry, Los Santos', 150, 'Apprentice', 3,
      'A great workshop starts with great people. Join our small team and help keep Los Santos moving.\n\nYou will diagnose faults, service customer vehicles, prepare repair estimates and keep your bay ready for the next job. We offer practical training and room to progress.',
      'A valid driving licence\nA careful approach to customer vehicles\nReliable availability and a willingness to learn'],
    ['beanmachine', 'Bean Machine', 'Barista & café team member', 'Hospitality', 'Part-time', 'Vespucci Boulevard', 110, 'Barista', 2,
      'Make someone’s morning. We are looking for a friendly team member to prepare drinks, welcome regulars and keep the café running smoothly.\n\nExperience helps, but a good attitude matters more. Training is provided.',
      'Friendly customer service\nComfortable with busy shifts\nEvening or weekend availability'],
    ['taxi', 'Downtown Cab Co.', 'City driver', 'Transport', 'Contract', 'East Vinewood', 120, 'Driver', 4,
      'Know the city and enjoy meeting people? Join our driver team to provide a dependable cab service across Los Santos.\n\nPick up passengers, keep your vehicle clean and make every journey a good one.',
      'Full driving licence\nSafe driving record\nGood knowledge of the city'],
    ['burgershot', 'Burger Shot', 'Kitchen crew', 'Hospitality', 'Full-time', 'Del Perro', 105, 'Crew member', 2,
      'Join the team behind the counter. We need a dependable crew member to prepare orders, keep the kitchen organised and serve customers with care.\n\nBring your energy. We will teach you the rest.',
      'Teamwork and good communication\nRespect for food hygiene\nAvailability for rotating shifts'],
    ['ambulance', 'Pillbox Medical', 'Trainee paramedic', 'Public service', 'Full-time', 'Pillbox Hill', 180, 'Trainee', 2,
      'Start a career supporting the people of Los Santos. Our supervised training programme covers patient care, emergency response and working as part of a medical team.',
      'A calm approach under pressure\nStrong communication skills\nAvailable for training sessions'],
    ['realestate', 'Dynasty 8', 'Property assistant', 'Professional', 'Part-time', 'Rockford Hills', 160, 'Assistant', 1,
      'Help people find their place in the city. Support our agents with viewings, organise appointments and provide clear updates to customers.',
      'Organised and punctual\nConfident speaking with customers\nFull driving licence']
  ] as const;
  const listings: Vacancy[] = definitions.map((d, i) => ({
    id: 'preview_vacancy_' + i, revision: 1, job: d[0], company: d[1], title: d[2], category: d[3], employment: d[4],
    location: d[5], pay: d[6], gradeLabel: d[7], grade: 0, openings: d[8], available: d[8],
    description: d[9], requirements: d[10], questions: ['What makes you a good fit for this role?'],
    status: 'open', createdAt: Date.now() - (i + 1) * 3600000, updatedAt: Date.now(), expiresAt: Date.now() + 30 * 86400000,
    stats: { applications: 0, pending: 0, hired: 0, reserved: 0 }
  }));
  const applicants = [
    ['Maya Bennett', 'I have spent the last year working in a local garage and would love to join a team that takes pride in its work.', 'Vehicle servicing, customer estimates and parts ordering.', 'Weekdays after 6pm; weekends flexible.'],
    ['Marcus Reed', 'I enjoy practical work and helping customers. I am looking for a steady role where I can build my skills.', 'Delivery driving and basic vehicle maintenance.', 'Monday to Friday, afternoons and evenings.'],
    ['Sofia Chen', 'I am an experienced technician with a careful approach to diagnostics and a strong focus on customer service.', 'Three years of engine diagnostics and bodywork.', 'Most evenings and Saturday mornings.']
  ];
  const applications: Application[] = applicants.map((a, i) => ({
    id: 'preview_application_' + i, revision: 1, listingId: listings[0].id, job: 'mechanic', company: business.label,
    title: listings[0].title, grade: 0, gradeLabel: 'Apprentice', applicantName: a[0], applicantKey: 'preview_candidate_' + i,
    contact: '555-01' + (21 + i), cover: a[1], experience: a[2], availability: a[3],
    answers: [{ question: listings[0].questions[0], answer: 'I am reliable, enjoy learning and work well with other people.' }],
    status: i === 2 ? 'shortlisted' : 'submitted', createdAt: Date.now() - (i + 2) * 3600000, updatedAt: Date.now(),
    previousJob: { name: 'unemployed', grade: 0, label: 'Unemployed' },
    timeline: [{ status: 'submitted', actor: a[0], message: 'Application submitted.', at: Date.now() - (i + 2) * 3600000 }]
  }));
  return { revision: 1, role: 'resident', residentJob: { name: 'unemployed', grade: 0, label: 'Unemployed' }, listings, applications, receipts: {} };
}
function save(s: Store) { localStorage.setItem(KEY, JSON.stringify(s)); }
function load(): Store { try { return JSON.parse(localStorage.getItem(KEY) || 'null') || fresh(); } catch { return fresh(); } }
function snapshot(s: Store): JobsSnapshot {
  const boss = s.role === 'boss';
  s.listings.forEach(l => {
    const apps = s.applications.filter(a => a.listingId === l.id);
    l.stats = { applications: apps.length, pending: apps.filter(a => ['submitted', 'shortlisted'].includes(a.status)).length,
      hired: apps.filter(a => a.status === 'hired').length, reserved: apps.filter(a => ['hired', 'hiring', 'pending_start', 'needs_attention'].includes(a.status)).length };
    l.available = Math.max(0, l.openings - l.stats.reserved);
  });
  const personal = s.applications.filter(a => a.applicantKey === (boss ? 'preview-boss' : RESIDENT));
  const owned = boss ? s.applications.filter(a => a.job === 'mechanic') : [];
  return structuredClone({
    revision: s.revision, serverTime: Date.now(), viewer: { name: boss ? 'Jordan Hayes' : 'Alex Morgan', framework: 'preview',
      currentJob: boss ? { name: 'mechanic', label: business.label, grade: 4 } : s.residentJob, canApply: true, business: boss ? business : null },
    listings: s.listings.filter(l => l.status === 'open' && l.available > 0), myApplications: personal.map(a => ({ ...a, internalNote: undefined })),
    companyListings: boss ? s.listings.filter(l => l.job === 'mechanic') : [], applications: owned,
    notifications: personal.filter(a => a.notice).map(a => a.notice!), rules,
    stats: { live: s.listings.filter(l => boss && l.job === 'mechanic' && l.status === 'open').length,
      pending: owned.filter(a => ['submitted', 'shortlisted'].includes(a.status)).length, hired: owned.filter(a => a.status === 'hired').length }
  });
}
function change(app: Application, status: JobStatus, actor: string, message: string) {
  app.status = status; app.revision++; app.updatedAt = Date.now();
  app.timeline.push({ status, actor, message, at: Date.now() });
}
function notify(app: Application, title: string, body: string) {
  app.notice = { id: app.id + '_' + app.revision, applicationId: app.id, title, body, at: Date.now(), read: false };
}
export function previewJobs(action: string, input: Record<string, unknown>): JobsReply {
  const s = load(), data = snapshot(s), actor = data.viewer.name, key = s.role === 'boss' ? 'preview-boss' : RESIDENT;
  const fail = (error: string): JobsReply => ({ ok: false, error });
  const finish = (message: string): JobsReply => { s.revision++; s.receipts[String(input.requestId)] = message; const jobs = snapshot(s); save(s); return { ok: true, message, jobs }; };
  if (action === 'jobsSnapshot') { save(s); return { ok: true, jobs: data }; }
  if (action === 'jobsPreviewRole') { s.role = input.role === 'boss' ? 'boss' : 'resident'; return finish('Preview role changed.'); }
  if (s.receipts[String(input.requestId)]) return { ok: true, jobs: data, replayed: true, message: s.receipts[String(input.requestId)] };
  const app = s.applications.find(a => a.id === input.id);
  if (['jobsReview', 'jobsNote', 'jobsWithdraw'].includes(action) && (!app || app.revision !== input.revision)) return fail('Application changed. Refresh before continuing.');
  if (action === 'jobsSaveListing') {
    if (s.role !== 'boss') return fail('Only a business boss can post vacancies.');
    const existing = s.listings.find(l => l.id === input.id);
    if (input.id && (!existing || existing.revision !== input.revision || existing.job !== 'mechanic')) return fail('Vacancy changed. Refresh first.');
    const grade = business.grades.find(g => g.level === Number(input.grade));
    if (!grade) return fail('Invalid hiring grade.');
    if (existing && existing.stats.applications && existing.grade !== grade.level) return fail('Grade is locked after applications are received.');
    if (existing && Number(input.openings) < existing.stats.reserved) return fail('Openings cannot be below hired or reserved slots.');
    const listing: Vacancy = { ...(existing || {} as Vacancy), id: existing?.id || String(input.requestId), revision: (existing?.revision || 0) + 1,
      job: 'mechanic', company: business.label, title: String(input.title).trim(), location: String(input.location).trim(), category: String(input.category),
      employment: String(input.employment), description: String(input.description).trim(), requirements: String(input.requirements).trim(),
      questions: input.questions as string[], grade: grade.level, gradeLabel: grade.label, pay: grade.pay, openings: Number(input.openings),
      available: Number(input.openings), status: existing?.status || 'open', createdAt: existing?.createdAt || Date.now(), updatedAt: Date.now(),
      expiresAt: Date.now() + 30 * 86400000, stats: existing?.stats || { applications: 0, pending: 0, hired: 0, reserved: 0 } };
    if (!existing) s.listings.unshift(listing); else Object.assign(existing, listing);
    return finish(existing ? 'Vacancy updated.' : 'Your vacancy is live.');
  }
  if (action === 'jobsListingState') {
    const listing = s.listings.find(l => l.id === input.id);
    if (!listing || s.role !== 'boss' || listing.job !== 'mechanic' || listing.revision !== input.revision) return fail('You cannot update this vacancy.');
    if (input.status === 'open' && listing.available <= 0) return fail('Increase openings before publishing.');
    listing.status = input.status as Vacancy['status']; listing.revision++; listing.updatedAt = Date.now();
    if (input.status === 'closed') s.applications.filter(a => a.listingId === listing.id && ['submitted', 'shortlisted'].includes(a.status)).forEach(a => {
      change(a, 'rejected', actor, 'The employer closed this vacancy.'); notify(a, 'Vacancy closed', 'The employer closed applications for ' + a.title + '.');
    });
    return finish('Vacancy ' + input.status + '.');
  }
  if (action === 'jobsApply') {
    const listing = s.listings.find(l => l.id === input.listingId);
    if (!listing || listing.status !== 'open' || listing.available <= 0 || listing.revision !== input.revision) return fail('This vacancy changed or closed.');
    if (input.consent !== true || data.viewer.currentJob.name === listing.job) return fail('Confirm the job change, or choose another business.');
    if (s.applications.some(a => a.listingId === listing.id && a.applicantKey === key && activeStatuses.includes(a.status))) return fail('You already applied to this vacancy.');
    const application: Application = { id: String(input.requestId), revision: 1, listingId: listing.id, job: listing.job, title: listing.title,
      company: listing.company, grade: listing.grade, gradeLabel: listing.gradeLabel, applicantName: actor, applicantKey: key,
      contact: String(input.contact), cover: String(input.cover), experience: String(input.experience), availability: String(input.availability),
      answers: listing.questions.map((question, i) => ({ question, answer: (input.answers as string[])[i] })),
      previousJob: data.viewer.currentJob, createdAt: Date.now(), updatedAt: Date.now(), status: 'submitted',
      timeline: [{ status: 'submitted', actor, message: 'Application submitted.', at: Date.now() }] };
    notify(application, 'Application received', listing.company + ' received your application for ' + listing.title + '.');
    s.applications.unshift(application); return finish('Application sent. Track it in My applications.');
  }
  if (action === 'jobsWithdraw' && app) {
    if (app.applicantKey !== key || !['submitted', 'shortlisted', 'pending_start'].includes(app.status)) return fail('This application cannot be withdrawn.');
    change(app, 'withdrawn', actor, 'Withdrawn by applicant.'); notify(app, 'Application withdrawn', 'Your application was withdrawn.'); return finish('Application withdrawn.');
  }
  if (action === 'jobsReview' && app) {
    if (s.role !== 'boss' || app.job !== 'mechanic' || !['submitted', 'shortlisted'].includes(app.status)) return fail('You cannot review this application.');
    app.decisionMessage = String(input.message || '');
    if (input.decision === 'accept') {
      const listing = s.listings.find(l => l.id === app.listingId)!;
      if (listing.available <= 0) return fail('All openings are filled or reserved.');
      change(app, 'hired', actor, app.decisionMessage || 'Application accepted. Job assigned.');
      if (app.applicantKey === RESIDENT) s.residentJob = { name: app.job, label: app.company, grade: app.grade };
      notify(app, 'You have been hired', 'You now work for ' + app.company + ' as ' + app.gradeLabel + '. ' + app.decisionMessage);
      if (listing.available === 1) listing.status = 'filled';
      return finish('Applicant hired. Their framework job is assigned.');
    }
    change(app, input.decision as JobStatus, actor, app.decisionMessage || 'Application updated.');
    notify(app, input.decision === 'shortlisted' ? 'You have been shortlisted' : 'Application update',
      app.company + (input.decision === 'shortlisted' ? ' shortlisted you for ' : ' declined your application for ') + app.title + '. ' + app.decisionMessage);
    return finish(input.decision === 'shortlisted' ? 'Applicant shortlisted.' : 'Application declined and applicant notified.');
  }
  if (action === 'jobsNote' && app) {
    if (s.role !== 'boss' || app.job !== 'mechanic') return fail('You cannot access this application.');
    app.internalNote = String(input.note); app.revision++; return finish('Internal note saved.');
  }
  if (action === 'jobsReadNotices') {
    s.applications.filter(a => a.applicantKey === key && a.notice && (input.ids as string[]).includes(a.notice.id)).forEach(a => { a.notice!.read = true; });
    return finish('Notifications marked as read.');
  }
  return fail('Unsupported preview action.');
}
