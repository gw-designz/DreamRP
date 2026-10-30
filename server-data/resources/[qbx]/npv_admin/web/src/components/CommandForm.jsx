import { useState } from 'react'
import { NumberInput } from './ui.jsx'

const DURATIONS = [
  { label: '1 hour', value: 3600 },
  { label: '1 day', value: 86400 },
  { label: '3 days', value: 259200 },
  { label: '7 days', value: 604800 },
  { label: '30 days', value: 2592000 },
  { label: 'Permanent', value: 0 },
]

function initial(cmd, preset) {
  const v = { ...preset }
  for (const a of cmd.args || []) {
    if (v[a.name] !== undefined) continue
    if (a.default !== undefined) v[a.name] = a.default
    else if (a.type === 'duration') v[a.name] = 86400
    else v[a.name] = ''
  }
  return v
}

/** Renders the argument fields of a registry command. `preset` pre-fills (and hides) fields. */
export default function CommandForm({ cmd, players = [], preset = {}, onRun, busy, runLabel = 'Run' }) {
  const [values, setValues] = useState(() => initial(cmd, preset))
  const set = (name, v) => setValues((s) => ({ ...s, [name]: v }))
  const fields = (cmd.args || []).filter((a) => preset[a.name] === undefined)

  const missing = (cmd.args || []).some((a) => {
    if (a.optional) return false
    const v = values[a.name]
    if (a.type === 'number' || a.type === 'duration') return v === '' || v === undefined
    return v === '' || v === undefined || v === null
  })

  const submit = (e) => {
    e?.preventDefault()
    if (missing || busy) return
    onRun({ ...values })
  }

  return (
    <form className="cmdform" onSubmit={submit} onKeyDown={(e) => e.stopPropagation()}>
      {fields.map((a) => (
        <div key={a.name} className={`f ${a.type === 'text' ? 'wide' : ''}`}>
          <span className="label">{a.label || a.name}</span>
          {a.type === 'player' && (
            <select className="select sm" value={values[a.name]} onChange={(e) => set(a.name, e.target.value ? Number(e.target.value) : '')}>
              <option value="">{a.optional ? 'None' : 'Select player…'}</option>
              {players.map((p) => <option key={p.id} value={p.id}>{`[${p.id}] ${p.name}${p.character ? ` — ${p.character}` : ''}`}</option>)}
            </select>
          )}
          {a.type === 'text' && <input className="input sm" maxLength={a.max || 200} value={values[a.name]} onChange={(e) => set(a.name, e.target.value)} autoFocus={fields[0] === a} />}
          {a.type === 'name' && <input className="input sm" maxLength={a.max || 60} placeholder={a.label} value={values[a.name]} onChange={(e) => set(a.name, e.target.value.replace(/[^\w-]/g, ''))} autoFocus={fields[0] === a} />}
          {a.type === 'model' && <input className="input sm" placeholder="e.g. a_m_y_business_01" value={values[a.name]} onChange={(e) => set(a.name, e.target.value.trim())} />}
          {a.type === 'number' && <NumberInput value={values[a.name]} min={a.min} max={a.max} onChange={(n) => set(a.name, n)} />}
          {a.type === 'select' && (
            <select className="select sm" value={values[a.name]} onChange={(e) => set(a.name, e.target.value)}>
              {a.options.map((o) => <option key={o} value={o}>{o}</option>)}
            </select>
          )}
          {a.type === 'duration' && (
            <select className="select sm" value={values[a.name]} onChange={(e) => set(a.name, Number(e.target.value))}>
              {DURATIONS.map((d) => <option key={d.value} value={d.value}>{d.label}</option>)}
            </select>
          )}
        </div>
      ))}
      <button type="submit" className="btn accent" disabled={missing || busy}>{busy ? '…' : runLabel}</button>
    </form>
  )
}
