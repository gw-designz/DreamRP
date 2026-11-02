import type { Character } from '@/types'
import { formatPlaytime, getFullName } from '@/hooks/useNui'
import { useLocale } from '@/hooks/useLocale'
import { formatBirthdate, getLastPlayedLabel } from '@/lib/characters'
import { cn } from '@/lib/utils'
import {
  BriefcaseIcon,
  CameraIcon,
  InfoIcon,
  PlayIcon,
  PlusIcon,
  Trash2Icon,
} from 'lucide-react'

interface CharacterNameplateProps {
  character?: Character
  slotIndex: number
  isLastPlayed?: boolean
  photoModeEnabled?: boolean
  onPlay?: () => void
  onInfo?: () => void
  onDelete?: () => void
  onPhotoMode?: () => void
  onCreate?: () => void
}

function initials(character: Character) {
  const first = character.charinfo.firstname?.[0] ?? ''
  const last = character.charinfo.lastname?.[0] ?? ''
  return `${first}${last}`.toUpperCase() || '?'
}

/** The selected character, as a tag floating over their ped. */
export function CharacterNameplate({
  character,
  slotIndex,
  isLastPlayed,
  photoModeEnabled = false,
  onPlay,
  onInfo,
  onDelete,
  onPhotoMode,
  onCreate,
}: CharacterNameplateProps) {
  const { t, locale } = useLocale()
  const slot = String(slotIndex).padStart(2, '0')

  const frame = (
    <>
      <span className="ryn-plate__corner ryn-plate__corner--tl" aria-hidden />
      <span className="ryn-plate__corner ryn-plate__corner--tr" aria-hidden />
      <span className="ryn-plate__corner ryn-plate__corner--bl" aria-hidden />
      <span className="ryn-plate__corner ryn-plate__corner--br" aria-hidden />
      <span className="ryn-plate__tab">
        {t('slotLabel')} <b>{slot}</b>
      </span>
    </>
  )

  if (!character) {
    return (
      <div className="ryn-plate ryn-plate--new">
        {frame}
        <div className="ryn-plate__main">
          <span className="ryn-plate__avatar ryn-plate__avatar--new" aria-hidden>
            <span className="ryn-plate__avatar-inner">
              <PlusIcon className="size-5" strokeWidth={2.75} />
            </span>
          </span>
          <div className="ryn-plate__text">
            <h3 className="ryn-plate__name">{t('newCharacter')}</h3>
            <p className="ryn-plate__job">{t('newCharacterHint')}</p>
          </div>
        </div>
        <button type="button" className="ryn-plate__play" onClick={onCreate}>
          <span>
            <PlusIcon className="size-3.5" strokeWidth={3} />
            {t('createCharacter')}
          </span>
          <kbd>Enter</kbd>
        </button>
      </div>
    )
  }

  const portrait = character.scene_data?.portrait
  const grade = character.job?.grade?.name
  const job = [character.job?.label ?? t('unemployed'), grade].filter(Boolean).join(' · ')
  const born = formatBirthdate(character.charinfo.birthdate, locale) ?? t('notAvailable')
  const last = getLastPlayedLabel(character, locale)
  const played =
    last.key === 'playedDaysAgo'
      ? t('playedDaysAgo', { count: last.count })
      : last.key === 'playedOn'
        ? last.date
        : t(last.key)

  const tools = [
    { key: 'info', label: t('info'), icon: InfoIcon, onClick: onInfo, show: true },
    { key: 'photo', label: t('photoMode'), icon: CameraIcon, onClick: onPhotoMode, show: photoModeEnabled },
    { key: 'delete', label: t('delete'), icon: Trash2Icon, onClick: onDelete, show: true, danger: true },
  ].filter((tool) => tool.show)

  return (
    <div className="ryn-plate" onDoubleClick={onPlay}>
      {frame}

      <div className="ryn-plate__main">
        <span className="ryn-plate__avatar" aria-hidden>
          <span className="ryn-plate__avatar-inner">
            {portrait ? <img src={portrait} alt="" /> : <b>{initials(character)}</b>}
          </span>
        </span>

        <div className="ryn-plate__text">
          <span className="ryn-plate__id">
            {character.citizenid}
            {isLastPlayed && <i>{t('lastPlayed')}</i>}
          </span>
          <h3 className="ryn-plate__name">{getFullName(character.charinfo)}</h3>
          <p className="ryn-plate__job">
            <BriefcaseIcon className="size-3" strokeWidth={2.25} />
            {job}
          </p>
        </div>

        <div className="ryn-plate__tools">
          {tools.map(({ key, label, icon: Icon, onClick, danger }) => (
            <button
              key={key}
              type="button"
              className={cn('ryn-plate__tool', danger && 'ryn-plate__tool--danger')}
              aria-label={label}
              title={label}
              onClick={onClick}
            >
              <Icon className="size-3.5" strokeWidth={2.25} />
            </button>
          ))}
        </div>
      </div>

      <dl className="ryn-plate__stats">
        <div>
          <dt>{t('born')}</dt>
          <dd>{born}</dd>
        </div>
        <div>
          <dt>{t('lastSeen')}</dt>
          <dd>{played}</dd>
        </div>
        <div>
          <dt>{t('played')}</dt>
          <dd>{formatPlaytime(character.playtime)}</dd>
        </div>
      </dl>

      <button type="button" className="ryn-plate__play" onClick={onPlay}>
        <span>
          <PlayIcon className="size-3.5" strokeWidth={0} fill="currentColor" />
          {t('playCharacter')}
        </span>
        <kbd>Enter</kbd>
      </button>
    </div>
  )
}
