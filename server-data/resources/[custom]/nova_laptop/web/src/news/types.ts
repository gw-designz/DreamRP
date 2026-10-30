export type Perm = 'write' | 'review' | 'edit' | 'publish' | 'print' | 'staff' | 'pay';
export type Me = { cid: string; name: string; staff: boolean; onJob?: boolean; owner: boolean; onDuty: boolean; groupId: number | null; perms: Record<Perm, boolean> };
export type Company = { label: string; balance: number | null; staff: number; onDuty: number; groups: number };
export type FeedItem = { id: number; kind: string; text: string; actor: string; at: number };
export type StaffMember = { cid: string; name: string; owner: boolean; groupId: number | null; since: number; online: boolean; onDuty: boolean; you: boolean };
export type Permission = { id: Perm; section: string; label: string; description: string };
export type Group = { id: number; name: string; description: string; permissions: Perm[]; builtin: boolean; members: number;
  /** The Owner group: every permission, its holders named by citizen ID in config.lua. */
  owner?: boolean; holders?: { cid: string; name?: string }[] };
export type Photo = { id: number; url: string; origin: 'camera' | 'phone'; at: number };
export type PhonePhoto = { url: string; at: number };
export type ArticleStatus = 'pending' | 'approved' | 'rejected' | 'trashed' | 'published' | 'column';
export type Article = { id: number; headline: string; body: string; photos: string[]; author: string; status: ArticleStatus; at: number; mine?: boolean; reviewer?: string };
export type Articles = { mine: Article[]; pending: Article[]; approved: Article[]; columns: Article[] };
export type Layout = 'feature-left' | 'feature-right' | 'full' | 'three' | 'grid';
export type DraftPage = { section: string; layout: Layout; slots: (number | false)[] };
export type Draft = { title: string; pages: DraftPage[] };
export type IssueItem = { headline: string; body: string; photos: string[]; author: string } | false;
export type IssuePage = { section: string; layout: Layout; items: IssueItem[] };
export type IssueSummary = { id: number; volume: number; title: string; cover: string | null; at: number; by: string };
export type Issue = IssueSummary & { pages: IssuePage[] };

export const SLOTS: Record<Layout, number> = { 'feature-left': 2, 'feature-right': 2, full: 1, three: 3, grid: 4 };
export const LAYOUT_NAMES: Record<Layout, string> = { 'feature-left': 'Feature Left', 'feature-right': 'Feature Right', full: 'Full Page', three: 'Three Columns', grid: 'Grid of Four' };

export const money = (value: number | null | undefined) => value == null ? '—' : `$${value < 0 ? '-' : ''}${Math.abs(Math.round(value)).toLocaleString('en-US')}`;
export const shortDate = (at: number) => new Date(at).toLocaleDateString('en-US', { month: 'short', day: 'numeric' });
export const longDate = (at: number) => new Date(at).toLocaleDateString('en-US', { month: 'short', day: 'numeric', year: 'numeric' });
export const initials = (name: string) => name.split(/\s+/).filter(Boolean).slice(0, 2).map(part => part[0]!.toUpperCase()).join('') || '?';
export const ago = (at: number) => {
  const minutes = Math.round((Date.now() - at) / 60000);
  if (minutes < 1) return 'Just now';
  if (minutes < 60) return `${minutes}m`;
  if (minutes < 1440) return `${Math.round(minutes / 60)}h`;
  return shortDate(at);
};
