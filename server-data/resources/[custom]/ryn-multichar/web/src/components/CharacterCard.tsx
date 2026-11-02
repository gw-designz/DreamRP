import { useEffect, useRef } from 'react'
import type { Character } from '@/types'
import { getFullName } from '@/hooks/useNui'
import { useLocale } from '@/hooks/useLocale'
import { getLastPlayedLabel } from '@/lib/characters'
import { cn } from '@/lib/utils'
import { animateSlotSelect } from '@/lib/animations'
import {
  ContextMenu,
  ContextMenuItem,
  ContextMenuPopup,
  ContextMenuTrigger,
} from '@/components/ui/context-menu'
import { InfoIcon, PlayIcon, PlusIcon, Trash2Icon } from 'lucide-react'

interface CharacterCardProps {
  character?: Character
  slotIndex: number
  isActive: boolean
  onSelect: (slotIndex: number) => void
  onPlay?: () => void
  onDelete?: () => void
  onInfo?: () => void
  onCreate?: () => void
}

function initials(character: Character) {
  const first = character.charinfo.firstname?.[0] ?? ''
  const last = character.charinfo.lastname?.[0] ?? ''
  return `${first}${last}`.toUpperCase() || '?'
}

/** A slot in the bottom row: a small plate to pick; the picked one becomes the nameplate. */
export function CharacterCard({
  character,
  slotIndex,
  isActive,
  onSelect,
  onPlay,
  onDelete,
  onInfo,
  onCreate,
}: CharacterCardProps) {
  const { t, locale } = useLocale()
  const cardRef = useRef<HTMLButtonElement>(null)
  const prevActive = useRef(false)
  const slot = String(slotIndex).padStart(2, '0')

  useEffect(() => {
    if (isActive && !prevActive.current && cardRef.current) {
      animateSlotSelect(cardRef.current)
    }
    prevActive.current = isActive
  }, [isActive])

  const frame = (
    <>
      <span className="ryn-mini__corner ryn-mini__corner--tl" aria-hidden />
      <span className="ryn-mini__corner ryn-mini__corner--br" aria-hidden />
      <span className="ryn-mini__tab">
        {t('slotLabel')} <b>{slot}</b>
      </span>
    </>
  )

  if (!character) {
    return (
      <button
        ref={cardRef}
        type="button"
        className={cn('ryn-mini ryn-mini--new', isActive && 'ryn-mini--active')}
        aria-label={`${t('createCharacter')}, ${t('slot', { index: slotIndex })}`}
        onClick={() => onSelect(slotIndex)}
        onDoubleClick={onCreate}
      >
        {frame}
        <span className="ryn-mini__avatar ryn-mini__avatar--new" aria-hidden>
          <span className="ryn-mini__avatar-inner">
            <PlusIcon className="size-4" strokeWidth={3} />
          </span>
        </span>
        <span className="ryn-mini__text">
          <span className="ryn-mini__name">{t('newCharacter')}</span>
          <span className="ryn-mini__job">{t('newCharacterHint')}</span>
        </span>
      </button>
    )
  }

  const portrait = character.scene_data?.portrait
  const grade = character.job?.grade?.name
  const job = [character.job?.label ?? t('unemployed'), grade].filter(Boolean).join(' · ')
  const last = getLastPlayedLabel(character, locale)
  const seen =
    last.key === 'playedDaysAgo'
      ? t('playedDaysAgo', { count: last.count })
      : last.key === 'playedOn'
        ? last.date
        : t(last.key)

  return (
    <ContextMenu>
      <ContextMenuTrigger
        render={
          <button
            ref={cardRef}
            type="button"
            className={cn('ryn-mini', isActive && 'ryn-mini--active')}
            aria-label={`${getFullName(character.charinfo)}, ${t('slot', { index: slotIndex })}`}
            aria-pressed={isActive}
            onClick={() => onSelect(slotIndex)}
            onDoubleClick={onPlay}
          />
        }
      >
        {frame}
        <span className="ryn-mini__avatar" aria-hidden>
          <span className="ryn-mini__avatar-inner">
            {portrait ? <img src={portrait} alt="" /> : <b>{initials(character)}</b>}
          </span>
        </span>
        <span className="ryn-mini__text">
          <span className="ryn-mini__name">{getFullName(character.charinfo)}</span>
          <span className="ryn-mini__job">{job}</span>
          <span className="ryn-mini__seen">
            {t('lastSeen')} <b>{seen}</b>
          </span>
        </span>
      </ContextMenuTrigger>

      <ContextMenuPopup className="min-w-48 p-1">
        <ContextMenuItem onClick={onPlay}>
          <PlayIcon />
          {t('play')}
        </ContextMenuItem>
        <ContextMenuItem onClick={onInfo}>
          <InfoIcon />
          {t('info')}
        </ContextMenuItem>
        <ContextMenuItem variant="destructive" onClick={onDelete}>
          <Trash2Icon />
          {t('delete')}
        </ContextMenuItem>
      </ContextMenuPopup>
    </ContextMenu>
  )
}
