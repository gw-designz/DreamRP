import { useEffect, useMemo, useRef, useState } from 'react'
import type { SpawnLocation, SpawnWorldInfo } from '@/types'
import { fetchNui } from '@/hooks/useNui'
import {
  ArrowLeftIcon,
  CloudFogIcon,
  CloudIcon,
  CloudLightningIcon,
  CloudRainIcon,
  ClockIcon,
  GhostIcon,
  MapPinIcon,
  SnowflakeIcon,
  SunIcon,
  type LucideIcon,
} from 'lucide-react'
import { useLocale } from '@/hooks/useLocale'
import { cn } from '@/lib/utils'
import { playUiSound } from '@/lib/sounds'
import { animateSpawnChoiceSelect, animateSpawnEntrance } from '@/lib/animations'
import { SpawnMap } from './SpawnMap'
import { SpawnIcon } from './SpawnIcon'
import { BrandMark } from './SelectHeader'

interface SpawnSelectorProps {
  locations: SpawnLocation[]
  world?: SpawnWorldInfo | null
  logo?: string
  serverName?: string
  onConfirm: (locationId: string) => void
  onCancel: () => void
}

type SpawnCategory = 'last' | 'housing' | 'public' | 'job'

function getCategory(location: SpawnLocation): SpawnCategory {
  if (location.group === 'last' || location.group === 'housing' || location.group === 'public' || location.group === 'job') {
    return location.group
  }
  if (location.id === 'lastLocation') return 'last'
  if (location.id.startsWith('housing:')) return 'housing'
  return 'public'
}

const categoryOrder: SpawnCategory[] = ['last', 'public', 'job', 'housing']

const weatherIcons: Record<SpawnWorldInfo['weather'], LucideIcon> = {
  clear: SunIcon,
  clouds: CloudIcon,
  rain: CloudRainIcon,
  thunder: CloudLightningIcon,
  fog: CloudFogIcon,
  snow: SnowflakeIcon,
  halloween: GhostIcon,
}

const weatherKeys = {
  clear: 'weatherClear',
  clouds: 'weatherClouds',
  rain: 'weatherRain',
  thunder: 'weatherThunder',
  fog: 'weatherFog',
  snow: 'weatherSnow',
  halloween: 'weatherHalloween',
} as const

export function SpawnSelector({ locations, world, logo, serverName, onConfirm, onCancel }: SpawnSelectorProps) {
  const { t } = useLocale()
  const rootRef = useRef<HTMLDivElement>(null)
  const choiceRefs = useRef<Map<string, HTMLButtonElement>>(new Map())

  const ordered = useMemo(
    () => categoryOrder.flatMap((category) => locations.filter((loc) => getCategory(loc) === category)),
    [locations],
  )

  const [selectedId, setSelectedId] = useState<string | null>(ordered[0]?.id ?? null)
  const selected = useMemo(() => ordered.find((loc) => loc.id === selectedId) ?? null, [ordered, selectedId])

  useEffect(() => {
    if (!ordered.some((loc) => loc.id === selectedId)) setSelectedId(ordered[0]?.id ?? null)
  }, [ordered, selectedId])

  useEffect(() => {
    if (!rootRef.current) return
    const frame = requestAnimationFrame(() => {
      if (rootRef.current) animateSpawnEntrance(rootRef.current)
    })
    return () => cancelAnimationFrame(frame)
  }, [])

  // The camera still flies there behind the map, so the area is streamed in by spawn time.
  useEffect(() => {
    if (!selected?.coords) return
    const timer = window.setTimeout(() => {
      fetchNui('previewSpawn', { coords: selected.coords }).catch(() => {})
    }, 0)
    return () => window.clearTimeout(timer)
  }, [selected])

  useEffect(() => {
    if (!selectedId) return
    choiceRefs.current.get(selectedId)?.scrollIntoView({ block: 'nearest', behavior: 'smooth' })
  }, [selectedId])

  const selectLocation = (id: string) => {
    if (id === selectedId) return
    setSelectedId(id)
    playUiSound('slotSelect')
    const el = choiceRefs.current.get(id)
    if (el) animateSpawnChoiceSelect(el)
  }

  useEffect(() => {
    const onKeyDown = (e: KeyboardEvent) => {
      if (e.key === 'Escape') {
        e.preventDefault()
        onCancel()
        return
      }
      if (ordered.length === 0) return
      const index = Math.max(0, ordered.findIndex((loc) => loc.id === selectedId))
      if (e.key === 'ArrowDown') {
        e.preventDefault()
        selectLocation(ordered[(index + 1) % ordered.length].id)
      } else if (e.key === 'ArrowUp') {
        e.preventDefault()
        selectLocation(ordered[(index - 1 + ordered.length) % ordered.length].id)
      } else if (e.key === 'Enter' && selectedId) {
        e.preventDefault()
        onConfirm(selectedId)
      }
    }
    window.addEventListener('keydown', onKeyDown)
    return () => window.removeEventListener('keydown', onKeyDown)
  })

  const WeatherIcon = weatherIcons[world?.weather ?? 'clear'] ?? SunIcon

  return (
    <div ref={rootRef} className="ryn-spawn-screen" data-animate="spawn-panel">
      <SpawnMap locations={ordered} selectedId={selectedId} onSelect={selectLocation} onConfirm={onConfirm} />

      <header className="ryn-spawn-title" data-animate="spawn-title">
        <BrandMark logo={logo} serverName={serverName} />
        <div>
          <h1>
            {t('spawnTitleLead')} <em>{t('spawnTitleAccent')}</em>
          </h1>
          <p>{t('spawnCount', { count: ordered.length })}</p>
        </div>
      </header>

      <aside className="ryn-spawn-rail" data-animate="spawn-rail">
        {ordered.length === 0 ? (
          <div className="ryn-spawn-empty">
            <MapPinIcon className="size-5" strokeWidth={1.75} />
            <p>{t('noSpawnLocationsTitle')}</p>
            <span>{t('noSpawnLocationsBody')}</span>
          </div>
        ) : (
          ordered.map((loc, index) => {
            const active = loc.id === selectedId
            return (
              <button
                key={loc.id}
                ref={(el) => {
                  if (el) choiceRefs.current.set(loc.id, el)
                  else choiceRefs.current.delete(loc.id)
                }}
                type="button"
                data-animate="spawn-choice"
                className={cn('ryn-spawn-choice', active && 'ryn-spawn-choice--active')}
                onClick={() => selectLocation(loc.id)}
                onDoubleClick={() => onConfirm(loc.id)}
                aria-pressed={active}
              >
                <span className="ryn-spawn-choice__icon">
                  <SpawnIcon icon={loc.icon} className="size-4" />
                </span>
                <span className="ryn-spawn-choice__title">{loc.label}</span>
                <span className="ryn-spawn-choice__index">{String(index + 1).padStart(2, '0')}</span>
              </button>
            )
          })
        )}
      </aside>

      <button type="button" className="ryn-spawn-back" data-animate="spawn-back" onClick={onCancel}>
        <ArrowLeftIcon className="size-4" strokeWidth={2.25} />
        {t('returnToCharacters')}
      </button>

      <div className="ryn-spawn-panel" data-animate="spawn-actions">
        {world && (
          <div className="ryn-spawn-panel__world">
            <span>
              <ClockIcon className="size-3.5" strokeWidth={2.5} />
              {world.time}
            </span>
            <span>
              <WeatherIcon className="size-3.5" strokeWidth={2.5} />
              {t(weatherKeys[world.weather] ?? 'weatherClear')}
            </span>
          </div>
        )}
        <p className="ryn-spawn-panel__eyebrow">{t('spawnSelected')}</p>
        <p className="ryn-spawn-panel__title">{selected?.label ?? t('noSpawnLocations')}</p>
        {selected?.description && <p className="ryn-spawn-panel__meta">{selected.description}</p>}
        <button
          type="button"
          className="ryn-spawn-panel__go"
          disabled={!selectedId}
          onClick={() => selectedId && onConfirm(selectedId)}
        >
          <span>{t('spawnHere')}</span>
          <kbd>Enter</kbd>
        </button>
      </div>
    </div>
  )
}
