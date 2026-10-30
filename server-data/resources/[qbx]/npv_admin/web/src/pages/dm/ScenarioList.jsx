import { useMemo, useState } from 'react'
import { Icon } from '../../components/ui.jsx'
import { client } from '../../services/nui.js'

export default function ScenarioList({ list, loading, currentId, canPublish, onOpen, onCreate, onImport, onToggleLive, onDuplicate, onDelete, onOpenReady }) {
  const [name, setName] = useState('')
  const [importId, setImportId] = useState('')
  const [search, setSearch] = useState('')

  const filtered = useMemo(() => {
    const q = search.trim().toLowerCase()
    return list.filter((s) => !q || s.name.toLowerCase().includes(q) || s.owner.toLowerCase().includes(q) || String(s.number) === q.replace('#', ''))
  }, [list, search])

  const submitCreate = () => {
    const n = name.trim()
    if (!n) return
    onCreate(n)
    setName('')
  }

  return (
    <div className="col sl">
      <h2 className="display">Scenario builder</h2>
      <div className="row">
        <input className="input" placeholder="New scenario name" maxLength={60} value={name} onChange={(e) => setName(e.target.value)} onKeyDown={(e) => e.key === 'Enter' && submitCreate()} />
        <button className="plus" onClick={submitCreate} aria-label="Create scenario" disabled={!name.trim()}><Icon name="plus" size={18} /></button>
      </div>
      <div className="row">
        <input className="input" placeholder="Import by scenario ID…" value={importId} inputMode="numeric" onChange={(e) => setImportId(e.target.value.replace(/\D/g, ''))} onKeyDown={(e) => e.key === 'Enter' && importId && (onImport(Number(importId)), setImportId(''))} />
        <button className="btn" disabled={!importId} onClick={() => { onImport(Number(importId)); setImportId('') }}>Import</button>
      </div>
      <button className="ready" onClick={onOpenReady}><Icon name="bolt" size={14} /> Ready-made</button>

      <div className="listhead"><span>Scenarios</span><span>{list.length}</span></div>
      <input className="input sm" placeholder="Search scenarios by name, owner or ID…" value={search} onChange={(e) => setSearch(e.target.value)} />
      <div className="items">
        {loading && list.length === 0 && <div className="empty">Loading…</div>}
        {!loading && filtered.length === 0 && <div className="empty">{list.length ? 'No scenarios match.' : 'No scenarios yet. Create one above.'}</div>}
        {filtered.map((s) => (
          <div key={s.id} className={`sc ${currentId === s.id ? 'sel' : ''}`} onClick={() => onOpen(s.id)}>
            <span className={`dot ${s.status === 'live' ? 'live' : ''}`} />
            <div className="info">
              <div className="nm">{s.name}</div>
              <div className="meta">{s.status === 'live' ? 'Live' : 'Draft'} · by {s.owner} · #{s.number} · {s.objectCount} items</div>
            </div>
            <div className="acts" onClick={(e) => e.stopPropagation()}>
              {canPublish && (
                <button className={`btn sm ${s.status === 'live' ? '' : 'accent'}`} onClick={() => onToggleLive(s)}>{s.status === 'live' ? 'Disable' : 'Spawn'}</button>
              )}
              <button className="ib" title="Copy scenario ID" onClick={() => client('clipboard', { text: String(s.number) })}><Icon name="share" size={12} /></button>
              <button className="ib" title="Duplicate" onClick={() => onDuplicate(s)}><Icon name="copy" size={12} /></button>
              <button className="ib del" title="Delete" onClick={() => onDelete(s)}><Icon name="trash" size={12} /></button>
            </div>
          </div>
        ))}
      </div>
    </div>
  )
}
