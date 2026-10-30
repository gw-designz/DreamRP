export type JobStatus = 'submitted' | 'shortlisted' | 'pending_start' | 'hiring' | 'hired' | 'rejected' | 'withdrawn' | 'cancelled' | 'needs_attention';
export type Grade = { level: number; label: string; pay: number };
export type Business = { name: string; label: string; grades: Grade[] };
export type JobIdentity = { name: string; label: string; grade: number };
export type Vacancy = {
  id: string; revision: number; job: string; company: string; title: string; category: string;
  employment: string; location: string; description: string; requirements: string;
  grade: number; gradeLabel: string; pay: number; openings: number; available: number;
  questions: string[]; status: 'open' | 'paused' | 'closed' | 'filled' | 'expired';
  createdAt: number; updatedAt: number; expiresAt: number;
  stats: { applications: number; pending: number; hired: number; reserved: number };
};
export type JobNotice = { id: string; applicationId: string; title: string; body: string; at: number; read: boolean };
export type JobApplication = {
  id: string; revision: number; listingId: string; job: string; title: string; company: string;
  grade: number; gradeLabel: string; applicantName: string; contact: string; cover: string;
  experience: string; availability: string; answers: { question: string; answer: string }[];
  status: JobStatus; createdAt: number; updatedAt: number; previousJob: JobIdentity;
  timeline: { status: JobStatus; actor: string; message: string; at: number }[];
  decisionMessage?: string; internalNote?: string; assignmentIssue?: string; notice?: JobNotice;
};
export type JobRules = {
  categories: string[]; employmentTypes: string[]; maxOpenings: number; maxQuestions: number;
  maxActiveApplications: number; reapplyCooldownSeconds: number; lifetimeDays: number;
  limits: Record<string, number>;
};
export type JobsSnapshot = {
  revision: number; serverTime: number;
  viewer: { name: string; framework: string; currentJob: JobIdentity; canApply: boolean; business?: Business | null };
  listings: Vacancy[]; myApplications: JobApplication[]; companyListings: Vacancy[];
  applications: JobApplication[]; notifications: JobNotice[];
  stats: { pending: number; hired: number; live: number }; rules: JobRules;
};
export type JobsReply = { ok: boolean; error?: string; message?: string; jobs?: JobsSnapshot; replayed?: boolean };
export const statusLabels: Record<JobStatus, string> = {
  submitted: 'In review', shortlisted: 'Shortlisted', pending_start: 'Accepted · awaiting login',
  hiring: 'Assigning job', hired: 'Hired', rejected: 'Not selected', withdrawn: 'Withdrawn',
  cancelled: 'Cancelled', needs_attention: 'Staff attention'
};
export const activeStatuses: JobStatus[] = ['submitted', 'shortlisted', 'pending_start', 'hiring', 'needs_attention'];
