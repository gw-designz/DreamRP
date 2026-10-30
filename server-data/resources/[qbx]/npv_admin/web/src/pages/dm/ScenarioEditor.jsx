import { useState } from 'react'
import { Icon } from '../../components/ui.jsx'
import { useApp } from '../../AppContext.jsx'
import { client, errorText, rpc } from '../../services/nui.js'
import Catalog from './Catalog.jsx'
import Properties from './Properties.jsx'
import { counts, uid } from './model.js'

const SHOW = [
  { id: 'all', label: 'All' }, { id: 'objects', label: 'Objects' }, { id: 'storage', label: 'Storage' },
  { id: 'npcs', label: 'NPCs' }, { id: 'interactive', label: 'Interactive' }, { id: 'ropes', label: 'Ropes' }, { id: 'trolleys', label: 'Trolleys' }, { id: 'doors', label: 'Doors' }, { id: 'triggers', label: 'Triggers' },
]
const GROUPS = [
  { id: 'npcs', label: 'NPCs', kinds: ['npc'] },
  { id: 'objects', label: 'Objects', kinds: ['object'] },
  { id: 'storage', label: 'Storage', kinds: ['storage'] },
  { id: 'interactive', label: 'Interactive', kinds: ['interactive'] },
  { id: 'ropes', label: 'Ropes', kinds: ['rope'] },
  { id: 'trolleys', label: 'Trolleys', kinds: ['trolley'] },
  { id: 'doors', label: 'Doors', kinds: ['door'] },
  { id: 'triggers', label: 'Triggers', kinds: ['trigger'] },
]

function Stat({ label, value, max, caption }) {
  const pct = Math.min(100, (value / max) * 100)
  return (
    <div className="stat">
      <div className="t"><span>{label}</span><span>{value} / {max}</span></div>
      <div className="bar"><i className={pct > 85 ? 'hot' : ''} style={{ width: `${pct}%` }} /></div>
      <div className="c">{caption}</div>
    </div>
  )
}

export default function ScenarioEditor({ draft, dirty, summary, limits, catalog, advanced, selId, setSelId, onRename, onPatch, onRemove, setDef, onPlace, onSave, onRevert, onClose, onOpenScripts, onOpenDialogue, onDress }) {
  const { toast } = useApp()
  const [tab, setTab] = useState('catalog')
  const [show, setShow] = useState('all')
  const [placedSearch, setPlacedSearch] = useState('')
  const [renaming, setRenaming] = useState(null) // { id, text } while a list row is being renamed

  // Renames take effect straight away; an empty name keeps the old one.
  const commitRename = (o) => {
    setRenaming((r) => {
      if (r && r.id === o.id) {
        const text = r.text.trim()
        if (text && text !== o.label) onPatch(o.id, { label: text })
      }
      return null
    })
  }

  if (!draft) {
    return <div className="col se"><div className="mutedbox" style={{ margin: 'auto' }}>Pick a scenario on the left, or create a new one.</div></div>
  }
  const c = counts(draft.definition)
  const sel = draft.definition.objects.find((o) => o.id === selId)
  const readOnly = draft.canEdit === false
  const placedTab = tab === 'placed' || !!sel

  return (
    <div className="col se">
      <div className="head">
        <input className="nameinput" value={draft.name} maxLength={60} disabled={readOnly} onChange={(e) => onRename(e.target.value)} />
        <span className={`chip ${draft.status === 'live' ? 'on' : ''}`}>{draft.status === 'live' ? 'Live' : 'Draft'} · v{draft.version}</span>
        {advanced && <button className="btn" onClick={onOpenScripts}><Icon name="code" size={14} /> Scripts ({draft.definition.scripts.length})</button>}
        <button className="btn" disabled={!dirty} onClick={onRevert}><Icon name="undo" size={14} /> Revert</button>
        <button className={`btn ${dirty ? 'accent' : ''}`} disabled={!dirty || readOnly} onClick={onSave}><Icon name="save" size={14} /> {dirty ? 'Save' : 'Saved'}</button>
        <button className="btn icon" onClick={onClose} aria-label="Close scenario"><Icon name="close" size={14} /></button>
      </div>

      <div className="stats">
        <Stat label="Scenario objects" value={c.objects} max={limits.ObjectsPerScenario} caption="In this scenario" />
        <Stat label="People" value={c.people} max={limits.PeoplePerScenario} caption="People standing in this scenario" />
        <Stat label="World render load" value={summary?.worldLoad ?? 0} max={limits.WorldRenderLoad} caption={`Things drawn by all live scenarios (cap ${limits.WorldRenderLoad})`} />
      </div>

      <div className="tabs2">
        <button className={!placedTab ? 'on' : ''} onClick={() => { setTab('catalog'); setSelId(null) }}>Catalog</button>
        <button className={placedTab ? 'on' : ''} onClick={() => setTab('placed')}>Placed ({draft.definition.objects.length})</button>
      </div>

      {!placedTab && <Catalog catalog={catalog} onPlace={onPlace} disabled={readOnly} />}

      {placedTab && (
        <>
          <div className="placeas">
            <span className="label" style={{ marginRight: 6 }}>Show</span>
            {SHOW.map((s) => <button key={s.id} className={`chip ${show === s.id ? 'on' : ''}`} onClick={() => setShow(s.id)}>{s.label}</button>)}
          </div>
          <div className="searchline" style={{ gridTemplateColumns: '1fr auto auto' }}>
            <input className="input sm" placeholder="Search placed objects…" value={placedSearch} onChange={(e) => setPlacedSearch(e.target.value)} />
            <button className="btn" onClick={async () => {
              const r = await client('coords.get', { mode: 'stand' })
              if (!r.ok || !r.data) return
              let best = null
              for (const o of draft.definition.objects) {
                const d = Math.hypot(o.coords.x - r.data.x, o.coords.y - r.data.y, o.coords.z - r.data.z)
                if (!best || d < best.d) best = { d, id: o.id }
              }
              if (best) setSelId(best.id)
            }}><Icon name="target" size={13} /> Edit nearest</button>
            <button className="btn" disabled={draft.status !== 'live' || !draft.definition.objects.some((o) => o.kind === 'storage')}
              title="Put every storage back to its configured contents (needs the scenario live and saved)"
              onClick={async () => {
                const res = await rpc('dm.refillLoot', { id: draft.id })
                toast(res.ok ? (res.message || 'Loot refilled') : errorText(res.error), res.ok ? 'ok' : 'error')
              }}><Icon name="undo" size={13} /> Refill loot</button>
          </div>
          <div className="placed">
            <div className="plist">
              {draft.definition.objects.length === 0 && <div className="empty">Nothing placed yet. Use the Catalog tab.</div>}
              {GROUPS.map((g) => {
                const rows = draft.definition.objects.filter((o) => g.kinds.includes(o.kind) && (show === 'all' || show === g.id)
                  && (!placedSearch.trim() || o.label.toLowerCase().includes(placedSearch.trim().toLowerCase()) || (o.model || '').toLowerCase().includes(placedSearch.trim().toLowerCase())))
                if (rows.length === 0) return null
                return (
                  <div key={g.id}>
                    <div className="grouphead">{g.label} ({rows.length})</div>
                    {rows.map((o) => (
                      <div key={o.id} className={`pobj ${selId === o.id ? 'sel' : ''}`} onClick={() => setSelId(o.id === selId ? null : o.id)} role="button" tabIndex={0}>
                        <Icon name={o.kind === 'npc' ? 'user' : o.kind === 'trigger' ? 'target' : o.kind === 'rope' ? 'down' : o.kind === 'door' ? 'lock' : 'box'} size={14} />
                        {renaming?.id === o.id ? (
                          <input
                            className="input sm rename" autoFocus maxLength={60} value={renaming.text}
                            onClick={(e) => e.stopPropagation()} onFocus={(e) => e.target.select()}
                            onChange={(e) => setRenaming({ id: o.id, text: e.target.value })}
                            onKeyDown={(e) => {
                              e.stopPropagation()
                              if (e.key === 'Enter') { commitRename(o) } else if (e.key === 'Escape') { setRenaming(null) }
                            }}
                            onBlur={() => commitRename(o)}
                          />
                        ) : (
                          <span className="n" title="Double-click to rename" onDoubleClick={(e) => { e.stopPropagation(); setRenaming({ id: o.id, text: o.label }) }}>{o.label}</span>
                        )}
                        <span className="m">{o.coords.x.toFixed(0)}, {o.coords.y.toFixed(0)}</span>
                        <span className="racts" onClick={(e) => e.stopPropagation()}>
                          <button className="btn sm icon" title="Rename" aria-label="Rename" onClick={() => setRenaming({ id: o.id, text: o.label })}><Icon name="edit" size={12} /></button>
                          <button className="btn sm" onClick={() => setSelId(o.id)}><Icon name="gear" size={11} /> Edit</button>
                          <button className="btn sm accent" onClick={() => onPlace({ kind: o.kind, model: o.model, size: o.size, length: o.length, moveId: o.id, world: o.world })}>{o.world ? 'Pick again' : 'Move'}</button>
                          <button className="btn sm icon" aria-label="Copy" onClick={() => setDef((def) => ({ ...def, objects: [...def.objects, { ...structuredClone(o), id: uid(), label: `${o.label} copy`, coords: { ...o.coords, x: +(o.coords.x + 1).toFixed(3) } }] }))}><Icon name="copy" size={12} /></button>
                          <button className="btn sm icon danger" aria-label="Delete" onClick={() => onRemove(o.id)}><Icon name="trash" size={12} /></button>
                        </span>
                      </div>
                    ))}
                  </div>
                )
              })}
            </div>
            <Properties
              obj={sel} catalog={catalog} advanced={advanced} onPatch={onPatch} onRemove={onRemove} onPlace={onPlace}
              onOpenDialogue={onOpenDialogue} onOpenScripts={onOpenScripts} onDress={onDress} setDef={setDef} onClose={() => setSelId(null)}
            />
          </div>
        </>
      )}
    </div>
  )
}
