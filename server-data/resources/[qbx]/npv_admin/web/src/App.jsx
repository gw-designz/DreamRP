import { useEffect, useRef, useState } from 'react'
import { AppProvider } from './AppContext.jsx'
import AdminMenu from './pages/AdminMenu.jsx'
import DmTool from './pages/dm/DmTool.jsx'
import { HudBadges, DialogueView, Narrate, Announce, KeyHints } from './components/Overlays.jsx'
import { closeUi, dialogueClose, inGame, onMessage } from './services/nui.js'
import { mockSession } from './services/mock.js'

function useStageScale() {
  const [fit, setFit] = useState({ scale: 1, x: 0, y: 0 })
  useEffect(() => {
    const update = () => {
      const scale = Math.min(window.innerWidth / 1920, window.innerHeight / 1080)
      setFit({ scale, x: (window.innerWidth - 1920 * scale) / 2, y: (window.innerHeight - 1080 * scale) / 2 })
    }
    update()
    window.addEventListener('resize', update)
    return () => window.removeEventListener('resize', update)
  }, [])
  return fit
}

export default function App() {
  const fit = useStageScale()
  const [open, setOpen] = useState(false)
  const [view, setView] = useState('admin')
  const [session, setSession] = useState(null)
  const [hud, setHud] = useState({ adminMode: false, scriptsRunning: false })
  const [dialogue, setDialogue] = useState(null)
  const [narrate, setNarrate] = useState(null)
  const [announce, setAnnounce] = useState(null)
  const [placing, setPlacing] = useState(null)
  const [editReq, setEditReq] = useState(null) // { sid, oid, n }: open the DM tool on this placed object
  const [keyhint, setKeyhint] = useState(() => (!inGame && new URLSearchParams(window.location.search).get('hints') ? { items: [{ key: 'LMB', label: 'Grab' }, { key: 'BACKSPACE', label: 'Stop' }] } : null))
  const [dmMounted, setDmMounted] = useState(false)
  const escStack = useRef([])

  useEffect(() => onMessage((action, data) => {
    switch (action) {
      case 'open':
        setSession(data.session)
        setView(data.view)
        if (data.view === 'dm') setDmMounted(true)
        setHud((h) => ({ ...h, adminMode: !!data.adminMode }))
        setEditReq(data.edit && data.edit.sid && data.edit.oid ? { sid: data.edit.sid, oid: data.edit.oid, n: Date.now() } : null)
        setOpen(true)
        break
      case 'close': setOpen(false); setPlacing(null); break
      case 'hud': setHud((h) => ({ ...h, ...data })); break
      case 'dialogue': setDialogue(data); break
      case 'keyhint': setKeyhint(data && Array.isArray(data.items) ? data : null); break
      case 'narrate': setNarrate(data); setTimeout(() => setNarrate(null), (data.seconds || 6) * 1000); break
      case 'announce': setAnnounce(data); setTimeout(() => setAnnounce(null), (data.seconds || 8) * 1000); break
      case 'placement':
        setPlacing(data.active ? data : null)
        window.dispatchEvent(new CustomEvent('npv:placement', { detail: data }))
        break
      default: break
    }
  }), [])

  // Browser-only preview: open straight into a view (?view=dm).
  useEffect(() => {
    if (inGame) return
    const params = new URLSearchParams(window.location.search)
    setSession(mockSession)
    setView(params.get('view') || 'admin')
    setHud({ adminMode: true, scriptsRunning: true })
    if (params.get('view') === 'dm') setDmMounted(true)
    setOpen(true)
  }, [])

  // Escape: let the innermost registered handler consume it, otherwise close the UI.
  useEffect(() => {
    const fn = (e) => {
      if (e.key !== 'Escape') return
      if (dialogue) { dialogueClose(); return }
      const stack = escStack.current
      for (let i = stack.length - 1; i >= 0; i--) {
        if (stack[i]() !== false) return
      }
      if (open) closeUi()
    }
    window.addEventListener('keydown', fn)
    return () => window.removeEventListener('keydown', fn)
  }, [open, dialogue])

  return (
    <div className="stage" style={{ transform: `translate(${fit.x}px, ${fit.y}px) scale(${fit.scale})` }}>
      <HudBadges hud={hud} />
      {announce && <Announce {...announce} />}
      {narrate && <Narrate {...narrate} />}
      {dialogue && <DialogueView view={dialogue} />}
      {keyhint && <KeyHints items={keyhint.items} />}
      <AppProvider session={session} escStack={escStack}>
        {open && session && view === 'admin' && <AdminMenu adminMode={hud.adminMode} dmRadial={hud.dmRadial} />}
        {dmMounted && session && <DmTool visible={open && view === 'dm' && !placing} placing={!!placing} edit={editReq} />}
        {open && placing && <PlacementHint kind={placing.kind} />}
      </AppProvider>
    </div>
  )
}

function PlacementHint({ kind }) {
  if (kind === 'worlddoor') {
    return (
      <div className="hintbar placement">
        <span><b>Aim</b> at the door</span><span><b>Enter</b> pick it</span><span><b>Backspace</b> cancel</span>
      </div>
    )
  }
  return (
    <div className="hintbar placement">
      <span><b>Aim</b> to position</span><span><b>Scroll</b> rotate</span><span><b>Q / E</b> height</span>
      <span><b>Enter</b> place {kind}</span><span><b>Backspace</b> cancel</span>
    </div>
  )
}
