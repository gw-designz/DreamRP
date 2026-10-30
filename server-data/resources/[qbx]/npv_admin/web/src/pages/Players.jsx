import { useEffect, useMemo, useState } from 'react'
import { useApp } from '../AppContext.jsx'
import CommandForm from '../components/CommandForm.jsx'
import { Spinner } from '../components/ui.jsx'
import { errorText, rpc } from '../services/nui.js'

const fmt = (n) => (n == null ? '—' : `$${Number(n).toLocaleString()}`)

export default function Players({ query, session, players, setPlayers }) {
  const { run, toast, has } = useApp()
  const [selId, setSelId] = useState(null)
  const [detail, setDetail] = useState(null)
  const [loading, setLoading] = useState(false)
  const [form, setForm] = useState(null)
  const [sort, setSort] = useState('id')

  // Refresh the directory while this tab is open.
  useEffect(() => {
    let alive = true
    const load = async () => {
      const res = await rpc('players.list')
      if (alive && res.ok) setPlayers(res.data)
      else if (alive && res.error) toast(errorText(res.error), 'error')
    }
    load()
    const t = setInterval(load, 5000)
    return () => { alive = false; clearInterval(t) }
  }, [setPlayers, toast])

  const loadDetail = async (id) => {
    setLoading(true)
    const res = await rpc('players.details', { id })
    setLoading(false)
    if (res.ok) setDetail(res.data)
    else { setDetail(null); toast(errorText(res.error), 'error') }
  }

  useEffect(() => { if (selId != null) loadDetail(selId) }, [selId])

  const list = useMemo(() => {
    const q = query.trim().toLowerCase()
    const out = players.filter((p) => !q || String(p.id) === q || p.name.toLowerCase().includes(q) || (p.character || '').toLowerCase().includes(q))
    return out.sort((a, b) => (sort === 'ping' ? b.ping - a.ping : sort === 'name' ? a.name.localeCompare(b.name) : a.id - b.id))
  }, [players, query, sort])

  const actions = session.commands.filter((c) => c.args?.some((a) => a.name === 'target'))

  const act = async (cmd) => {
    const extra = (cmd.args || []).filter((a) => a.name !== 'target')
    if (extra.length) { setForm(form?.id === cmd.id ? null : cmd); return }
    await run(cmd, { target: selId }, { targetName: detail?.name })
    loadDetail(selId)
  }

  return (
    <div className="players">
      <div className="ptable">
        <div className="prow head">
          <button onClick={() => setSort('id')}>ID</button>
          <button style={{ textAlign: 'left' }} onClick={() => setSort('name')}>Player</button>
          <span>Character</span><span>Job</span>
          <button onClick={() => setSort('ping')}>Ping</button><span>Status</span>
        </div>
        {list.length === 0 && <div className="empty">No players match.</div>}
        {list.map((p) => (
          <button key={p.id} className={`prow ${selId === p.id ? 'sel' : ''}`} onClick={() => { setSelId(p.id); setForm(null) }}>
            <span className="id">{p.id}</span>
            <span>{p.name}</span>
            <span>{p.character || '—'}</span>
            <span>{p.job ? `${p.job}${p.jobGrade != null ? ` (${p.jobGrade})` : ''}` : '—'}</span>
            <span>{p.ping}ms</span>
            <span className={p.dead ? 'dead' : ''}>{p.dead ? 'Down' : p.staff || 'OK'}</span>
          </button>
        ))}
      </div>

      <div className="pdetail">
        {selId == null && <div className="empty">Select a player to see details and actions.</div>}
        {selId != null && loading && !detail && <div className="empty"><Spinner /></div>}
        {selId != null && detail && (
          <>
            <h2 className="display">{detail.character || detail.name}</h2>
            <div className="muted">[{detail.id}] {detail.name}{detail.citizenid ? ` · ${detail.citizenid}` : ''}</div>
            <dl className="kv">
              <dt>Job</dt><dd>{detail.job ? `${detail.job} (${detail.jobGrade ?? 0})` : '—'}</dd>
              <dt>Health / Armor</dt><dd>{detail.health != null ? `${Math.max(0, detail.health - 100)} / ${detail.armor}` : '—'}</dd>
              <dt>Ping</dt><dd>{detail.ping}ms</dd>
              <dt>Bucket</dt><dd>{detail.bucket}</dd>
              {detail.coords && <><dt>Position</dt><dd>{`${detail.coords.x.toFixed(1)}, ${detail.coords.y.toFixed(1)}, ${detail.coords.z.toFixed(1)}`}</dd></>}
              {detail.vehicle && <><dt>Vehicle</dt><dd>{detail.vehicle.plate}</dd></>}
              {detail.money && <><dt>Cash / Bank</dt><dd>{fmt(detail.money.cash)} / {fmt(detail.money.bank)}</dd></>}
              {detail.identifiers && <><dt>Identifiers</dt><dd>{detail.identifiers.join('\n')}</dd></>}
            </dl>

            <div className="label">Actions</div>
            <div className="actions">
              {actions.map((c) => (
                <button key={c.id} className={`btn sm ${form?.id === c.id ? 'active' : ''} ${['ban', 'kick'].includes(c.id) ? 'danger' : ''}`} onClick={() => act(c)} title={c.desc}>{c.label.replace(' Player', '')}</button>
              ))}
            </div>
            {form && (
              <div style={{ marginBottom: 12 }}>
                <CommandForm key={form.id + selId} cmd={form} preset={{ target: selId }} runLabel={form.label} onRun={async (args) => {
                  const res = await run(form, args, { targetName: detail.name })
                  if (res.ok) { setForm(null); loadDetail(selId) }
                }} />
              </div>
            )}

            <div className="label" style={{ marginTop: 14 }}>Moderation history</div>
            {(detail.notes || []).length === 0 && <div className="muted" style={{ padding: '6px 0' }}>No notes or warnings.</div>}
            {(detail.notes || []).map((n) => (
              <div key={n.id} className="note"><small>{n.kind.toUpperCase()} · {n.staff_name} · {String(n.created_at).slice(0, 10)}</small>{n.text}</div>
            ))}
          </>
        )}
      </div>
    </div>
  )
}
