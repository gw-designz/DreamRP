import { useCallback, useEffect, useLayoutEffect, useRef, useState } from 'react'
import type { SpawnLocation } from '@/types'
import { useLocale } from '@/hooks/useLocale'
import { cn } from '@/lib/utils'
import { MinusIcon, PlusIcon } from 'lucide-react'
import { SpawnIcon } from './SpawnIcon'
import mapImage from '@/assets/gta-map.jpg'

interface SpawnMapProps {
  locations: SpawnLocation[]
  selectedId: string | null
  onSelect: (id: string) => void
  onConfirm: (id: string) => void
}

/** The atlas is 8192 units square; the bundled image is a scaled copy of it. */
const ATLAS = 8192

/** World metres to atlas units (the usual GTA V atlas fit). */
function toAtlas(x: number, y: number) {
  return { u: (0.02072 * x + 117.3) * 32, v: (-0.0205 * y + 172.8) * 32 }
}

/** u/v: atlas point at the screen centre; s: screen px per atlas unit, at 1080p */
interface View {
  u: number
  v: number
  s: number
}

// Opens on Los Santos with the rest of the island running off the top, as in the reference.
const HOME: View = { u: 4000, v: 5000, s: 0.2 }
const MIN_S = 0.12
const MAX_S = 1.4
const FLY_MS = 450
// Markers closer than this on screen are drawn as one, with a count.
const CLUSTER_PX = 40

export function SpawnMap({ locations, selectedId, onSelect, onConfirm }: SpawnMapProps) {
  const { t } = useLocale()
  const wrapRef = useRef<HTMLDivElement>(null)
  const [size, setSize] = useState({ w: window.innerWidth, h: window.innerHeight })
  const [view, setViewState] = useState<View>(HOME)
  const viewRef = useRef(view)
  const flight = useRef<number | null>(null)
  const unit = size.h / 1080

  const setView = useCallback((next: View) => {
    const s = Math.min(MAX_S, Math.max(MIN_S, next.s))
    const clamped = {
      s,
      u: Math.min(ATLAS, Math.max(0, next.u)),
      v: Math.min(ATLAS, Math.max(0, next.v)),
    }
    viewRef.current = clamped
    setViewState(clamped)
  }, [])

  const stopFlight = () => {
    if (flight.current !== null) cancelAnimationFrame(flight.current)
    flight.current = null
  }

  const flyTo = useCallback(
    (to: View) => {
      stopFlight()
      const from = viewRef.current
      const start = performance.now()
      const step = (now: number) => {
        const k = Math.min(1, (now - start) / FLY_MS)
        const e = 1 - Math.pow(1 - k, 3)
        setView({
          u: from.u + (to.u - from.u) * e,
          v: from.v + (to.v - from.v) * e,
          s: from.s + (to.s - from.s) * e,
        })
        flight.current = k < 1 ? requestAnimationFrame(step) : null
      }
      flight.current = requestAnimationFrame(step)
    },
    [setView],
  )

  useEffect(() => stopFlight, [])

  useLayoutEffect(() => {
    const el = wrapRef.current
    if (!el) return
    const ro = new ResizeObserver(() => setSize({ w: el.clientWidth, h: el.clientHeight }))
    ro.observe(el)
    return () => ro.disconnect()
  }, [])

  const scale = view.s * unit
  const toScreen = (u: number, v: number) => ({
    x: size.w / 2 + (u - view.u) * scale,
    y: size.h / 2 + (v - view.v) * scale,
  })

  // Only move the map when the pick is off screen (or under the list).
  const selected = locations.find((loc) => loc.id === selectedId)
  useEffect(() => {
    if (!selected?.coords) return
    const { u, v } = toAtlas(selected.coords.x, selected.coords.y)
    const cur = viewRef.current
    const k = cur.s * (wrapRef.current?.clientHeight ?? 1080) / 1080
    const w = wrapRef.current?.clientWidth ?? 1920
    const h = wrapRef.current?.clientHeight ?? 1080
    const x = w / 2 + (u - cur.u) * k
    const y = h / 2 + (v - cur.v) * k
    if (x > 440 * (h / 1080) && x < w - 80 && y > 80 && y < h - 120) return
    flyTo({ ...cur, u, v })
  }, [selected, flyTo])

  const drag = useRef<{ x: number; y: number; id: number } | null>(null)

  const onPointerDown = (e: React.PointerEvent) => {
    if (e.button !== 0) return
    stopFlight()
    drag.current = { x: e.clientX, y: e.clientY, id: e.pointerId }
    e.currentTarget.setPointerCapture(e.pointerId)
  }

  const onPointerMove = (e: React.PointerEvent) => {
    const d = drag.current
    if (!d || d.id !== e.pointerId) return
    const cur = viewRef.current
    const k = cur.s * unit
    setView({ ...cur, u: cur.u - (e.clientX - d.x) / k, v: cur.v - (e.clientY - d.y) / k })
    d.x = e.clientX
    d.y = e.clientY
  }

  const onPointerUp = (e: React.PointerEvent) => {
    if (drag.current?.id === e.pointerId) drag.current = null
  }

  // Zoom about a screen point, so what is under it stays put.
  const zoomAt = useCallback(
    (factor: number, px: number, py: number, animated: boolean) => {
      const cur = viewRef.current
      const s = Math.min(MAX_S, Math.max(MIN_S, cur.s * factor))
      const k0 = cur.s * unit
      const k1 = s * unit
      const u = cur.u + (px - size.w / 2) / k0 - (px - size.w / 2) / k1
      const v = cur.v + (py - size.h / 2) / k0 - (py - size.h / 2) / k1
      if (animated) flyTo({ u, v, s })
      else {
        stopFlight()
        setView({ u, v, s })
      }
    },
    [unit, size, flyTo, setView],
  )

  useEffect(() => {
    const el = wrapRef.current
    if (!el) return
    const onWheel = (e: WheelEvent) => {
      e.preventDefault()
      const rect = el.getBoundingClientRect()
      zoomAt(Math.exp(-e.deltaY * 0.0015), e.clientX - rect.left, e.clientY - rect.top, false)
    }
    el.addEventListener('wheel', onWheel, { passive: false })
    return () => el.removeEventListener('wheel', onWheel)
  }, [zoomAt])

  // Group markers that would overlap; the selected one always stands alone on top.
  const markers: { pos: { x: number; y: number }; locs: SpawnLocation[] }[] = []
  for (const loc of locations) {
    if (!loc.coords) continue
    const { u, v } = toAtlas(loc.coords.x, loc.coords.y)
    const pos = toScreen(u, v)
    const near =
      loc.id !== selectedId &&
      markers.find(
        (m) => !m.locs.some((l) => l.id === selectedId) && Math.hypot(m.pos.x - pos.x, m.pos.y - pos.y) < CLUSTER_PX * unit,
      )
    if (near) near.locs.push(loc)
    else markers.push({ pos, locs: [loc] })
  }

  const imgPos = toScreen(0, 0)

  return (
    <div className="ryn-map" ref={wrapRef}>
      <div
        className="ryn-map__surface"
        onPointerDown={onPointerDown}
        onPointerMove={onPointerMove}
        onPointerUp={onPointerUp}
        onPointerCancel={onPointerUp}
      >
        <img
          src={mapImage}
          alt=""
          draggable={false}
          className="ryn-map__image"
          style={{
            width: ATLAS * scale,
            height: ATLAS * scale,
            transform: `translate(${imgPos.x}px, ${imgPos.y}px)`,
          }}
        />
      </div>

      <div className="ryn-map__markers">
        {markers.map(({ pos, locs }) => {
          if (pos.x < -40 || pos.y < -40 || pos.x > size.w + 40 || pos.y > size.h + 40) return null
          const lead = locs[0]
          const active = locs.some((l) => l.id === selectedId)
          const cluster = locs.length > 1
          return (
            <button
              key={lead.id}
              type="button"
              className={cn('ryn-marker', active && 'ryn-marker--active')}
              style={{ left: pos.x, top: pos.y }}
              aria-label={cluster ? locs.map((l) => l.label).join(', ') : lead.label}
              title={cluster ? locs.map((l) => l.label).join('\n') : lead.label}
              onClick={() => {
                if (cluster) zoomAt(2, pos.x, pos.y, true)
                else onSelect(lead.id)
              }}
              onDoubleClick={() => !cluster && onConfirm(lead.id)}
            >
              <span className="ryn-marker__diamond">
                <SpawnIcon icon={cluster ? 'layers' : lead.icon} className="ryn-marker__icon" />
              </span>
              {cluster && <span className="ryn-marker__count">{locs.length}</span>}
            </button>
          )
        })}
      </div>

      <div className="ryn-map-zoom" data-animate="spawn-zoom">
        <button
          type="button"
          className="ryn-map-zoom__btn ryn-map-zoom__btn--in"
          aria-label={t('mapZoomIn')}
          onClick={() => zoomAt(1.5, size.w / 2, size.h / 2, true)}
        >
          <PlusIcon className="size-4" strokeWidth={2.75} />
        </button>
        <button
          type="button"
          className="ryn-map-zoom__btn"
          aria-label={t('mapZoomOut')}
          onClick={() => zoomAt(1 / 1.5, size.w / 2, size.h / 2, true)}
        >
          <MinusIcon className="size-4" strokeWidth={2.75} />
        </button>
      </div>
    </div>
  )
}
