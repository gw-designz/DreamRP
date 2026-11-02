import { useLayoutEffect, useRef, useState, type ReactNode } from 'react'
import type { Character, PedAnchor, PedAnchors } from '@/types'
import { getCharacterForSlot } from '@/lib/characters'
import { CharacterCard } from './CharacterCard'
import { CharacterNameplate } from './CharacterNameplate'
import { SlotSkeleton } from './SlotSkeleton'
import { cn } from '@/lib/utils'

interface CharacterDockProps {
  characters: Character[]
  slots: number[]
  activeSlot: number
  /** Heads on screen, by slot: those cards float over their ped instead of sitting in the row. */
  anchors?: PedAnchors
  loading?: boolean
  lastPlayedCitizenId?: string | null
  hidden?: boolean
  photoModeEnabled?: boolean
  onSelectSlot: (slotIndex: number) => void
  onPlay: (character: Character) => void
  onDelete: (character: Character) => void
  onInfo: (character: Character) => void
  onPhotoMode: () => void
  onCreate: (slotIndex: number) => void
}

// Room kept between a floating card and the screen edge.
const EDGE = 16

/** Pins its card above a screen point, kept fully on screen. */
function AnchoredCard({ anchor, active, children }: { anchor: PedAnchor; active: boolean; children: ReactNode }) {
  const ref = useRef<HTMLDivElement>(null)
  const [size, setSize] = useState({ w: 262, h: 120 })

  useLayoutEffect(() => {
    const el = ref.current
    if (!el) return
    const ro = new ResizeObserver(() => setSize({ w: el.offsetWidth, h: el.offsetHeight }))
    ro.observe(el)
    return () => ro.disconnect()
  }, [])

  const vw = window.innerWidth
  const vh = window.innerHeight
  const left = Math.min(vw - size.w / 2 - EDGE, Math.max(size.w / 2 + EDGE, anchor.x * vw))
  const top = Math.min(vh - EDGE, Math.max(size.h + EDGE, anchor.y * vh))

  return (
    <div ref={ref} className={cn('ryn-card-anchor', active && 'ryn-card-anchor--active')} style={{ left, top }}>
      {children}
    </div>
  )
}

export function CharacterDock({
  characters,
  slots,
  activeSlot,
  anchors = {},
  loading = false,
  lastPlayedCitizenId,
  hidden = false,
  photoModeEnabled = false,
  onSelectSlot,
  onPlay,
  onDelete,
  onInfo,
  onPhotoMode,
  onCreate,
}: CharacterDockProps) {
  const activeCharacter = getCharacterForSlot(characters, activeSlot)
  const floating = loading ? [] : slots.filter((slot) => anchors[slot])
  const docked = loading ? slots : slots.filter((slot) => !anchors[slot])

  const nameplate = (
    <CharacterNameplate
      character={activeCharacter}
      slotIndex={activeSlot}
      isLastPlayed={!!activeCharacter && activeCharacter.citizenid === lastPlayedCitizenId}
      photoModeEnabled={photoModeEnabled}
      onPlay={activeCharacter ? () => onPlay(activeCharacter) : undefined}
      onInfo={activeCharacter ? () => onInfo(activeCharacter) : undefined}
      onDelete={activeCharacter ? () => onDelete(activeCharacter) : undefined}
      onPhotoMode={onPhotoMode}
      onCreate={() => onCreate(activeSlot)}
    />
  )

  const renderSlot = (slotIndex: number) => {
    if (slotIndex === activeSlot) return nameplate
    const character = getCharacterForSlot(characters, slotIndex)
    return (
      <CharacterCard
        character={character}
        slotIndex={slotIndex}
        isActive={false}
        onSelect={onSelectSlot}
        onPlay={character ? () => onPlay(character) : undefined}
        onDelete={character ? () => onDelete(character) : undefined}
        onInfo={character ? () => onInfo(character) : undefined}
        onCreate={() => onCreate(slotIndex)}
      />
    )
  }

  return (
    <div className={cn('ryn-dock-wrap', hidden && 'ryn-dock-wrap--hidden')}>
      {floating.map((slotIndex) => (
        <AnchoredCard key={slotIndex} anchor={anchors[slotIndex]} active={slotIndex === activeSlot}>
          {renderSlot(slotIndex)}
        </AnchoredCard>
      ))}

      {/* Slots whose ped is out of view wait in a row along the bottom. */}
      {docked.length > 0 && (
        <div className="ryn-dock" data-animate="dock">
          <div className="ryn-dock__rail">
            {loading
              ? slots.map((slotIndex) => <SlotSkeleton key={slotIndex} />)
              : docked.map((slotIndex) => (
                  <div key={slotIndex} className="ryn-dock__slot">
                    {renderSlot(slotIndex)}
                  </div>
                ))}
          </div>
        </div>
      )}
    </div>
  )
}
