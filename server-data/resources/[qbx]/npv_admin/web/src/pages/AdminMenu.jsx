import { useCallback, useEffect, useMemo, useRef, useState } from 'react'
import { useApp } from '../AppContext.jsx'
import { Icon } from '../components/ui.jsx'
import CommandForm from '../components/CommandForm.jsx'
import Players from './Players.jsx'
import { closeUi, rpc } from '../services/nui.js'

const CATEGORIES = [
  { id: 'all', label: 'All', icon: 'folder', sub: 'All commands' },
  { id: 'players', label: 'Players', icon: 'users', sub: 'Player commands' },
  { id: 'vehicles', label: 'Vehicles', icon: 'car', sub: 'Vehicle commands' },
  { id: 'teleport', label: 'Teleport', icon: 'pin', sub: 'Teleport commands' },
  { id: 'economy', label: 'Economy', icon: 'gift', sub: 'Money, items and jobs' },
  { id: 'utility', label: 'Utility', icon: 'gear', sub: 'Utility commands' },
  { id: 'user', label: 'User', icon: 'user', sub: 'Self commands' },
  { id: 'keybinds', label: 'Keybinds', icon: 'keyboard', sub: 'Keybinds' },
  { id: 'online', label: 'Online', icon: 'users', sub: 'Online players' },
]

const loadFavs = () => {
  try { return JSON.parse(localStorage.getItem('npv_favs') || '[]') } catch { return [] }
}
const saveFavs = (f) => {
  try { localStorage.setItem('npv_favs', JSON.stringify(f)) } catch { /* storage unavailable */ }
}

export default function AdminMenu({ adminMode = false, dmRadial = false }) {
  const { session, run, toast } = useApp()
  const [cat, setCat] = useState('all')
  const [query, setQuery] = useState('')
  const [sel, setSel] = useState(0)
  const [expanded, setExpanded] = useState(null)
  const [grid, setGrid] = useState(false)
  const [favs, setFavs] = useState(loadFavs)
  const [players, setPlayers] = useState([])
  const [busy, setBusy] = useState(false)
  const listRef = useRef(null)
  const searchRef = useRef(null)

  const needsPlayers = session.commands.some((c) => c.args?.some((a) => a.type === 'player'))
  useEffect(() => {
    if (!needsPlayers) return undefined
    let alive = true
    const load = async () => {
      const res = await rpc('players.list')
      if (alive && res.ok) setPlayers(res.data)
    }
    load()
    const t = setInterval(load, 8000)
    return () => { alive = false; clearInterval(t) }
  }, [needsPlayers])

  const commands = useMemo(() => {
    const q = query.trim().toLowerCase()
    let list = session.commands
    if (cat === 'keybinds') list = list.filter((c) => c.key)
    else if (cat !== 'all' && cat !== 'online') list = list.filter((c) => c.category === cat)
    if (q) list = list.filter((c) => c.label.toLowerCase().includes(q) || c.desc.toLowerCase().includes(q))
    return [...list].sort((a, b) => (favs.includes(b.id) - favs.includes(a.id)) || a.label.localeCompare(b.label))
  }, [session.commands, cat, query, favs])

  useEffect(() => { setSel(0); setExpanded(null) }, [cat, query])
  useEffect(() => {
    listRef.current?.querySelector('.cmd.sel')?.scrollIntoView({ block: 'nearest' })
  }, [sel, commands])

  const toggleFav = useCallback((id) => {
    setFavs((f) => {
      const next = f.includes(id) ? f.filter((x) => x !== id) : [...f, id]
      saveFavs(next)
      return next
    })
  }, [])

  const execute = useCallback(async (cmd, args = {}) => {
    setBusy(true)
    const targetName = args.target ? players.find((p) => p.id === args.target)?.name : undefined
    const res = await run(cmd, args, { targetName })
    setBusy(false)
    if (res.ok) {
      setExpanded(null)
      // Self-effects are meant to be used straight away, so get the menu out of the way.
      if (cmd.exec === 'client' && !['admin_mode', 'dm_tool'].includes(cmd.id)) closeUi()
    }
  }, [run, players])

  const activate = useCallback((cmd) => {
    if (cmd.args?.length) setExpanded((e) => (e === cmd.id ? null : cmd.id))
    else execute(cmd)
  }, [execute])

  useEffect(() => {
    const onKey = (e) => {
      const typing = ['INPUT', 'SELECT', 'TEXTAREA'].includes(document.activeElement?.tagName)
      if (typing && document.activeElement !== searchRef.current) return
      if (e.key === 'ArrowDown') { e.preventDefault(); setSel((s) => Math.min(commands.length - 1, s + 1)) }
      else if (e.key === 'ArrowUp') { e.preventDefault(); setSel((s) => Math.max(0, s - 1)) }
      else if (e.key === 'Enter' && commands[sel] && cat !== 'online') { e.preventDefault(); activate(commands[sel]) }
      else if (typing) return
      else if (e.key.toLowerCase() === 'f' && commands[sel]) toggleFav(commands[sel].id)
      else if (e.key.toLowerCase() === 'x') setGrid((g) => !g)
      else if (e.key.toLowerCase() === 'q' || e.key.toLowerCase() === 'e') {
        const i = CATEGORIES.findIndex((c) => c.id === cat)
        const d = e.key.toLowerCase() === 'e' ? 1 : -1
        setCat(CATEGORIES[(i + d + CATEGORIES.length) % CATEGORIES.length].id)
      }
    }
    window.addEventListener('keydown', onKey)
    return () => window.removeEventListener('keydown', onKey)
  }, [commands, sel, cat, activate, toggleFav])

  const current = CATEGORIES.find((c) => c.id === cat)

  return (
    <div className="admin">
      <div className="scrim" />
      <div className="shell">
        <div className="title">
          <h1 className="display">Admin</h1>
          <div className="display sub">{current.sub}</div>
        </div>
        <nav className="rail">
          {CATEGORIES.map((c) => (
            <button key={c.id} className={cat === c.id ? 'on' : ''} onClick={() => setCat(c.id)}>
              <Icon name={c.icon} size={18} fill={c.id === 'all' ? 'currentColor' : 'none'} /> {c.label}
            </button>
          ))}
        </nav>

        <div className="main">
          <div className="main-inner">
            <div className="searchrow">
              <div className="searchbox">
                <input ref={searchRef} className="input" placeholder={cat === 'online' ? 'Search players…' : 'Search commands…'} value={query} maxLength={100} onChange={(e) => setQuery(e.target.value)} autoFocus />
                <span className="count">{query.length}/100</span>
              </div>
              <button className="layoutbtn" title="Layout (X)" onClick={() => setGrid((g) => !g)}><Icon name={grid ? 'list' : 'grid'} size={18} fill={grid ? 'none' : 'currentColor'} /></button>
            </div>

            {cat === 'online' ? (
              <Players query={query} session={session} players={players} setPlayers={setPlayers} />
            ) : (
              <>
                <div className="count-label">{commands.length} commands</div>
                <div className={`cmdlist ${grid ? 'grid' : ''}`} ref={listRef}>
                  {commands.length === 0 && <div className="empty">No commands match “{query}”.</div>}
                  {commands.map((c, i) => (
                    <div key={c.id} className={`cmd ${i === sel ? 'sel' : ''}`} onMouseMove={() => i !== sel && setSel(i)}>
                      <button className={`star ${favs.includes(c.id) ? 'fav' : ''}`} onClick={() => toggleFav(c.id)} aria-label="Favourite">
                        <Icon name="star" size={14} fill="currentColor" stroke={1} />
                      </button>
                      <button className="body" onClick={() => activate(c)}>
                        <span>
                          <div className="name">{c.label}</div>
                          <div className="desc">{c.desc}</div>
                        </span>
                        <span className="meta">
                          {c.key && <span className="keycap">{c.key}</span>}
                          {c.id === 'admin_mode' && adminMode && <span className="status">Active</span>}
                          {c.id === 'dm_tool' && dmRadial && <span className="status">In radial</span>}
                          {c.args?.length ? <Icon name={expanded === c.id ? 'chevronUp' : 'chevron'} size={14} /> : <span style={{ width: 14, height: 8, border: '1.5px solid currentColor', borderRadius: 2, opacity: 0.6 }} />}
                        </span>
                      </button>
                      {expanded === c.id && (
                        <div className="expand">
                          <CommandForm cmd={c} players={players} busy={busy} onRun={(args) => execute(c, args)} />
                        </div>
                      )}
                    </div>
                  ))}
                </div>
              </>
            )}
          </div>
        </div>
      </div>

      <div className="hintbar">
        <span><span className="k">↑↓</span> Move</span>
        <span><span className="k">↵</span> Select</span>
        <span><span className="k">F</span> Favourite</span>
        <span><span className="k">Q</span>/<span className="k">E</span> Category</span>
        <span><span className="k">X</span> Layout</span>
        <span><span className="k">Esc</span> Close</span>
      </div>
    </div>
  )
}
