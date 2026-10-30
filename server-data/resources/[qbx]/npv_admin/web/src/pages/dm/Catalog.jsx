import { useEffect, useMemo, useRef, useState } from 'react'
import { Icon, NumberInput } from '../../components/ui.jsx'

const PLACE_AS = [
  { id: 'object', label: 'Object' },
  { id: 'storage', label: 'Storage' },
  { id: 'npc', label: 'NPC' },
  { id: 'interactive', label: 'Interactive object' },
  { id: 'rope', label: 'Rappel rope' },
  { id: 'trolley', label: 'Trolley' },
  { id: 'door', label: 'Locked door' },
  { id: 'trigger', label: 'Trigger box' },
]

const PAGE = 72
const ALL_SHELF = '__all'

// Thumbnails. Peds come from gtahash.com/peds, then the FiveM docs (docs.fivem.net/docs/game-references/ped-models/);
// props from gtahash.com/objects, then the Sky-Systems gallery. Needs internet on the player's machine; when no
// source has an image, an icon is shown.
const thumbUrls = (kind, model) => (kind === 'npc'
  ? [`https://cdn.gtahash.com/peds/thumbs/${model}.webp`, `https://docs.fivem.net/peds/${model}.webp`]
  : [`https://cdn.gtahash.com/objects/thumbs/${model}.webp`, `https://cdn.sky-systems.net/props/${model}.png`])

function Thumb({ kind, model }) {
  const urls = thumbUrls(kind, model)
  const [tried, setTried] = useState(0) // how many sources have failed so far
  useEffect(() => setTried(0), [model])
  if (tried >= urls.length) return kind === 'npc' ? <Icon name="user" size={50} stroke={1.2} /> : <Icon name="box" size={46} stroke={1.2} />
  return <img className="pedimg" src={urls[tried]} alt="" decoding="async" referrerPolicy="no-referrer" draggable={false} onError={() => setTried((n) => n + 1)} />
}

// Every GTA V prop (~21k names, LOD variants removed) and ped (~1.1k) model name. Each list is loaded once, on demand.
const modelCache = { props: null, peds: null }
const modelPending = {}
function useAllModels(which) {
  const [, rerender] = useState(0)
  useEffect(() => {
    if (!which || modelCache[which]) return undefined
    let alive = true
    modelPending[which] = modelPending[which]
      || (which === 'peds' ? import('../../data/peds.json') : import('../../data/props.json')).then((m) => { modelCache[which] = m.default; return m.default })
    modelPending[which].then(() => { if (alive) rerender((n) => n + 1) })
    return () => { alive = false }
  }, [which])
  return which ? modelCache[which] : null
}

export default function Catalog({ catalog, onPlace, disabled }) {
  const [kind, setKind] = useState(() => (PLACE_AS.some((p) => p.id === new URLSearchParams(window.location.search).get('kind')) ? new URLSearchParams(window.location.search).get('kind') : 'object'))
  const [search, setSearch] = useState(() => new URLSearchParams(window.location.search).get('q') || '')
  const [custom, setCustom] = useState('')
  const [size, setSize] = useState({ x: 3, y: 3, z: 3 })
  const [ropeLength, setRopeLength] = useState(20)
  const [shelf, setShelf] = useState('')
  const [limit, setLimit] = useState(PAGE)
  const sentinel = useRef(null)

  const isProp = ['object', 'storage', 'interactive'].includes(kind)
  const which = kind === 'npc' ? 'peds' : isProp ? 'props' : null // which "everything" list this tab can search
  const allList = useAllModels(which)
  const noun = which === 'peds' ? 'peds' : 'props'
  const source = kind === 'npc' ? catalog.npcs : catalog.objects
  const shelves = useMemo(() => [...new Set(source.map((e) => e.group))], [source])
  useEffect(() => { setShelf(''); setLimit(PAGE) }, [kind])
  useEffect(() => { setLimit(PAGE) }, [search, shelf])

  const q = search.trim().toLowerCase()
  const items = useMemo(() => {
    const featured = source.filter((e) => (!shelf || shelf === ALL_SHELF || e.group === shelf) && (!q || e.label.toLowerCase().includes(q) || e.id.toLowerCase().includes(q)))
    if (!which || !allList) return featured
    // The full list is searched whenever there is a query, or when "All props / All peds" is chosen.
    if (shelf && shelf !== ALL_SHELF) return featured
    if (!q && shelf !== ALL_SHELF) return featured
    const have = new Set(featured.map((e) => e.id))
    const more = []
    for (const id of allList) {
      if (q && !id.includes(q.replace(/\s+/g, '_'))) continue
      if (!have.has(id)) more.push({ id, label: id, group: `All ${noun}` })
    }
    return [...featured, ...more]
  }, [source, shelf, q, which, allList, noun])

  const shown = items.slice(0, limit)

  // Load the next page when the end of the grid scrolls into view.
  useEffect(() => {
    const el = sentinel.current
    if (!el || shown.length >= items.length) return undefined
    const obs = new IntersectionObserver((entries) => { if (entries[0].isIntersecting) setLimit((l) => l + PAGE) }, { rootMargin: '400px' })
    obs.observe(el)
    return () => obs.disconnect()
  }, [shown.length, items.length])

  const place = (model, label) => onPlace({ kind, model, label })

  return (
    <>
      <div className="placeas">
        <span className="label" style={{ marginRight: 6 }}>Place as</span>
        {PLACE_AS.map((p) => <button key={p.id} className={`chip ${kind === p.id ? 'on' : ''}`} onClick={() => setKind(p.id)}>{p.label}</button>)}
      </div>

      {kind === 'trigger' && (
        <div className="cat">
          <p className="muted" style={{ maxWidth: 640, lineHeight: 1.5 }}>
            An invisible box. Scripts can react when a player walks into it or leaves it — alarms, area messages, locking and unlocking things. Set its size, then aim and place it.
          </p>
          <div className="two" style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 160px)', gap: 8, margin: '12px 0' }}>
            {['x', 'y', 'z'].map((ax) => (
              <div key={ax}><span className="label">{ax === 'z' ? 'Height' : ax === 'x' ? 'Width' : 'Depth'} (m)</span>
                <NumberInput value={size[ax]} min={0.5} max={ax === 'z' ? 50 : 100} onChange={(n) => setSize((s) => ({ ...s, [ax]: n }))} />
              </div>
            ))}
          </div>
          <button className="btn accent" disabled={disabled} onClick={() => onPlace({ kind: 'trigger', label: 'Trigger box', size })}><Icon name="target" size={14} /> Aim and place</button>
        </div>
      )}

      {kind === 'rope' && (
        <div className="cat">
          <p className="muted" style={{ maxWidth: 680, lineHeight: 1.5 }}>
            A rope players can rappel down. Aim at the spot where the rope is tied off (the top edge of a roof or ledge), set how long it is, and place it. Players get a “Rappel down” prompt there: <b>S</b> goes down, <b>W</b> goes up, <b>Backspace</b> lets go, and they land when they reach the bottom.
          </p>
          <div style={{ width: 200, margin: '12px 0' }}>
            <span className="label">Rope length (m)</span>
            <NumberInput value={ropeLength} min={3} max={150} onChange={setRopeLength} />
          </div>
          <button className="btn accent" disabled={disabled} onClick={() => onPlace({ kind: 'rope', label: 'Rappel rope', length: ropeLength })}><Icon name="target" size={14} /> Aim and place</button>
        </div>
      )}

      {kind === 'trolley' && (
        <div className="cat">
          <p className="muted" style={{ maxWidth: 700, lineHeight: 1.5 }}>
            Heist trolleys players can grab from. Pick a type, aim and place it, then set what each grab pays (cash, gold bars, diamonds…), how many grabs it holds and how long each takes in its properties.
          </p>
          <div className="cards" style={{ maxWidth: 940 }}>
            {(catalog.trolleys || []).map((t) => (
              <button key={t.id} className="card" disabled={disabled} onClick={() => onPlace({ kind: 'trolley', model: t.model, label: t.label, trolley: t })} title={t.model}>
                <span className="art"><Thumb kind="prop" model={t.model} /></span>
                <span className="cl">{t.label}</span>
              </button>
            ))}
          </div>
          <p className="muted" style={{ fontSize: 12.5 }}>Any other prop can be turned into a trolley too: place it, then use a custom model in its properties.</p>
        </div>
      )}

      {kind === 'door' && (
        <div className="cat">
          <p className="muted" style={{ maxWidth: 700, lineHeight: 1.5 }}>
            A door that stays shut until it is opened. Players can plant <b>thermite</b> or <b>hack</b> the panel to get through (you choose which, what they need, and the minigame), or a script can open it. Pick one, aim and place it, then set how it swings and how it unlocks in its properties.
          </p>
          <div className="cards" style={{ maxWidth: 940 }}>
            {(catalog.doors?.Presets || []).map((d) => (
              <button key={d.id} className="card" disabled={disabled} title={d.model}
                onClick={() => onPlace({ kind: 'door', model: d.model, label: d.label, door: { openAngle: d.openAngle, thermite: catalog.doors?.Thermite, hack: catalog.doors?.Hack } })}>
                <span className="art"><Thumb kind="prop" model={d.model} /></span>
                <span className="cl">{d.label}</span>
              </button>
            ))}
          </div>
          <div style={{ margin: '14px 0 4px', padding: '12px 14px', background: 'var(--bg-input)', maxWidth: 700, display: 'flex', gap: 14, alignItems: 'center' }}>
            <div style={{ flex: 1 }}>
              <div className="display" style={{ fontSize: 17 }}>A door that is already in the map (an MLO, a building)</div>
              <div className="muted" style={{ fontSize: 12.5, lineHeight: 1.45, marginTop: 4 }}>Nothing new is placed: you point at the real door in the world and it becomes lockable, with the same thermite / hack settings.</div>
            </div>
            <button className="btn accent" disabled={disabled} onClick={() => onPlace({ kind: 'door', world: true, label: 'Map door', door: { thermite: catalog.doors?.Thermite, hack: catalog.doors?.Hack } })}><Icon name="target" size={14} /> Pick a door</button>
          </div>
          <p className="muted" style={{ fontSize: 12.5 }}>Any prop with hinges can be a door: place a normal object, or type its model name below.</p>
          <div className="customrow">
            <input className="input sm" placeholder="Custom door model name" value={custom} onChange={(e) => setCustom(e.target.value.replace(/[^\w]/g, ''))} />
            <button className="btn" disabled={!custom || disabled} onClick={() => onPlace({ kind: 'door', model: custom, label: 'Locked door', door: { openAngle: 90, thermite: catalog.doors?.Thermite, hack: catalog.doors?.Hack } })}>Aim and place</button>
          </div>
        </div>
      )}

      {kind !== 'trigger' && kind !== 'rope' && kind !== 'trolley' && kind !== 'door' && (
        <>
          <div className="searchline">
            <input className="input sm" placeholder={`Search ${allList ? allList.length.toLocaleString() : 'all'} ${noun}…`} value={search} onChange={(e) => setSearch(e.target.value)} />
            <select className="select sm" value={shelf} onChange={(e) => setShelf(e.target.value)}>
              <option value="">Featured shelves</option>
              <option value={ALL_SHELF}>All {noun}{allList ? ` (${allList.length.toLocaleString()})` : ''}</option>
              {shelves.map((g) => <option key={g} value={g}>{g}</option>)}
            </select>
          </div>
          <div className="cat">
            {which && !q && shelf !== ALL_SHELF && <div className="muted" style={{ fontSize: 12.5, padding: '0 0 8px' }}>Showing featured {noun}. Type to search every GTA V {kind === 'npc' ? 'ped' : 'prop'}{allList ? ` (${allList.length.toLocaleString()})` : ''}, or choose “All {noun}”.</div>}
            {which && q && !allList && <div className="muted" style={{ fontSize: 12.5, padding: '0 0 8px' }}>Loading the full {kind === 'npc' ? 'ped' : 'prop'} list…</div>}
            {items.length === 0 && <div className="empty">No models match “{search}”. Use a custom model below.</div>}
            <div className="cards">
              {shown.map((m) => (
                <button key={m.id} className={`card ${kind === 'npc' ? 'npc' : ''}`} disabled={disabled} onClick={() => place(m.id, m.label)} title={m.id}>
                  <span className="art"><Thumb kind={kind === 'npc' ? 'npc' : 'prop'} model={m.id} /></span>
                  <span className="cl">{m.label}</span>
                </button>
              ))}
            </div>
            {shown.length < items.length && <div ref={sentinel} className="muted" style={{ textAlign: 'center', padding: 12, fontSize: 12 }}>Showing {shown.length.toLocaleString()} of {items.length.toLocaleString()}…</div>}
            <div className="customrow">
              <input className="input sm" placeholder="Custom model name, e.g. prop_cash_pile_01" value={custom} onChange={(e) => setCustom(e.target.value.replace(/[^\w]/g, ''))} />
              <button className="btn" disabled={!custom || disabled} onClick={() => place(custom, custom)}>Aim and place</button>
            </div>
          </div>
        </>
      )}
    </>
  )
}
