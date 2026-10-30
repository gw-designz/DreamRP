// UI sounds: hover / click / enter / back. The page only names a kind; the Lua client plays the
// matching GTA frontend sound from Config.Sounds. Does nothing outside FiveM.
import { client, inGame } from './nui.js'

const INTERACTIVE = 'button, select, [role="switch"], .cmd, .sc, .pobj, .prow, .card, .tile, .dpill'
const MIN_GAP = { hover: 45, click: 30, enter: 30, back: 30 }
const lastPlayed = {}

export function play(kind) {
  if (!inGame) return
  const now = performance.now()
  if (now - (lastPlayed[kind] || 0) < MIN_GAP[kind]) return
  lastPlayed[kind] = now
  client('sound', { kind })
}

const usable = (el) => el && !el.disabled && el.getAttribute('aria-disabled') !== 'true'

export function initSounds() {
  let hovered = null
  document.addEventListener('mouseover', (e) => {
    const el = e.target.closest?.(INTERACTIVE) || null
    if (el === hovered) return
    hovered = el
    if (usable(el)) play('hover')
  })
  document.addEventListener('mouseleave', () => { hovered = null })
  document.addEventListener('click', (e) => {
    const el = e.target.closest?.(INTERACTIVE)
    if (usable(el)) play('click')
  })
  document.addEventListener('keydown', (e) => {
    if (e.repeat) return
    const tag = e.target?.tagName
    if (e.key === 'Enter' && tag !== 'TEXTAREA') play('enter')
    else if (e.key === 'Escape') play('back')
    else if ((e.key === 'ArrowUp' || e.key === 'ArrowDown') && tag !== 'SELECT') play('hover')
  })
}
