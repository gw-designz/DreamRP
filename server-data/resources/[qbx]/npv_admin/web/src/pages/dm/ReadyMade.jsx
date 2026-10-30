import { useMemo, useState } from 'react'
import { useEscape } from '../../AppContext.jsx'
import { Icon } from '../../components/ui.jsx'
import { TEMPLATES, templateStats } from './model.js'

/** Centred modal listing ready-made scenarios; "Place here" builds one where the staff member stands. */
export default function ReadyMade({ onPlace, onClose }) {
  const [busy, setBusy] = useState(null)
  const stats = useMemo(() => Object.fromEntries(TEMPLATES.map((t) => [t.id, templateStats(t)])), [])
  useEscape(() => { onClose(); return true })

  const place = async (t) => {
    setBusy(t.id)
    const ok = await onPlace(t)
    setBusy(null)
    if (ok) onClose()
  }

  return (
    <div className="modal-wrap" onMouseDown={(e) => { if (e.target === e.currentTarget) onClose() }}>
      <div className="rm">
        <h3 className="display">Ready-made scenarios</h3>
        <p>Builds one around where you stand, facing the way you face, as a new draft. Look it over and change what you like, then switch it live.</p>
        <div className="rm-list">
          {TEMPLATES.map((t) => (
            <div key={t.id} className="rm-item">
              <div className="rm-body">
                <div className="rm-name">{t.name}</div>
                <div className="rm-desc">{t.desc}</div>
                <div className="rm-chips">
                  <span className="chip">{stats[t.id].things} things</span>
                  {stats[t.id].people > 0 && <span className="chip">{stats[t.id].people} {stats[t.id].people === 1 ? 'person' : 'people'}</span>}
                  {stats[t.id].scripts > 0 && <span className="chip scripts">{stats[t.id].scripts} scripts</span>}
                </div>
              </div>
              <button className="btn accent" disabled={!!busy} onClick={() => place(t)}><Icon name="target" size={14} /> {busy === t.id ? 'Placing…' : 'Place here'}</button>
            </div>
          ))}
        </div>
        <div className="rm-foot"><button className="btn light" onClick={onClose}>Done</button></div>
      </div>
    </div>
  )
}
