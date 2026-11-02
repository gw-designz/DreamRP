import type { Character } from '@/types'

export function getCharacterForSlot(characters: Character[], slotIndex: number): Character | undefined {
  const byCid = characters.find((c) => (c.cid ?? c.slot) === slotIndex)
  if (byCid) return byCid
  return characters[slotIndex - 1]
}

export function getLastPlayedCitizenId(characters: Character[]): string | null {
  return getLastPlayedCharacter(characters)?.citizenid ?? null
}

export function getLastPlayedCharacter(characters: Character[]): Character | null {
  let latest: Character | null = null
  let latestTime = 0

  for (const character of characters) {
    if (!character.last_played) continue
    const raw = character.last_played
    const time = typeof raw === 'number' ? raw : Date.parse(raw) || Number(raw) || 0
    if (!Number.isNaN(time) && time >= latestTime) {
      latestTime = time
      latest = character
    }
  }

  return latest
}

export type LastOnlineBadge = { kind: 'new' } | { kind: 'relative'; key: string; count: number }

/** Relative last-online badge for dock slots. */
export function getLastOnlineBadge(character?: Character): LastOnlineBadge | null {
  if (!character) return null

  const playtime = character.playtime ?? 0
  if (!character.last_played && playtime <= 0) {
    return { kind: 'new' }
  }

  if (!character.last_played) return null

  const raw = character.last_played
  const time = typeof raw === 'number' ? raw : Date.parse(String(raw).replace(' ', 'T'))
  if (!Number.isFinite(time)) {
    return playtime <= 0 ? { kind: 'new' } : null
  }

  const diffMs = Math.max(0, Date.now() - time)
  const minute = 60_000
  const hour = 60 * minute
  const day = 24 * hour
  const week = 7 * day

  if (diffMs < hour) return { kind: 'relative', key: 'badgeJustNow', count: 0 }
  if (diffMs < day) {
    return { kind: 'relative', key: 'badgeHoursAgo', count: Math.max(1, Math.floor(diffMs / hour)) }
  }
  if (diffMs < week) {
    return { kind: 'relative', key: 'badgeDaysAgo', count: Math.max(1, Math.floor(diffMs / day)) }
  }
  return { kind: 'relative', key: 'badgeWeeksAgo', count: Math.max(1, Math.floor(diffMs / week)) }
}

/** Slots the dock shows: every occupied slot, then the first free one (if any) as "New Character". */
export function getDockSlots(characters: Character[], slotLimit: number): number[] {
  const slots: number[] = []
  let firstEmpty: number | null = null
  for (let slot = 1; slot <= slotLimit; slot++) {
    if (getCharacterForSlot(characters, slot)) slots.push(slot)
    else if (firstEmpty === null) firstEmpty = slot
  }
  if (firstEmpty !== null) slots.push(firstEmpty)
  return slots
}

function parseDate(raw: string | number): number {
  if (typeof raw === 'number') return raw
  const numeric = Number(raw)
  if (Number.isFinite(numeric) && /^\d+$/.test(raw)) return numeric
  return Date.parse(String(raw).replace(' ', 'T'))
}

/** "Nov 23, 2000" from the stored birthdate, or the raw value when it does not parse. */
export function formatBirthdate(raw: string | undefined, locale: string): string | null {
  if (!raw) return null
  const match = /^(\d{4})-(\d{2})-(\d{2})/.exec(raw)
  const date = match ? new Date(Number(match[1]), Number(match[2]) - 1, Number(match[3])) : new Date(raw)
  if (Number.isNaN(date.getTime())) return raw
  return date.toLocaleDateString(locale, { month: 'short', day: 'numeric', year: 'numeric' })
}

export type LastPlayedLabel =
  | { key: 'playedNever' | 'playedToday' | 'playedYesterday' }
  | { key: 'playedDaysAgo'; count: number }
  | { key: 'playedOn'; date: string }

export function getLastPlayedLabel(character: Character, locale: string): LastPlayedLabel {
  if (!character.last_played) return { key: 'playedNever' }
  const time = parseDate(character.last_played)
  if (!Number.isFinite(time)) return { key: 'playedNever' }

  const startOfToday = new Date()
  startOfToday.setHours(0, 0, 0, 0)
  const day = 24 * 60 * 60 * 1000
  const daysAgo = Math.ceil((startOfToday.getTime() - time) / day)

  if (daysAgo <= 0) return { key: 'playedToday' }
  if (daysAgo === 1) return { key: 'playedYesterday' }
  if (daysAgo < 7) return { key: 'playedDaysAgo', count: daysAgo }
  return {
    key: 'playedOn',
    date: new Date(time).toLocaleDateString(locale, { month: 'short', day: 'numeric' }),
  }
}
