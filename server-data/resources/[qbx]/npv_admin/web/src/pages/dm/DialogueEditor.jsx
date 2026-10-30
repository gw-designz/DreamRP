import { useMemo, useRef, useState } from 'react'
import { useEscape } from '../../AppContext.jsx'
import { Icon, NumberInput } from '../../components/ui.jsx'
import { emptyDialogue, uid } from './model.js'

const NODE_W = 250
const NODE_H = 140
const GAP_X = 70
const GAP_Y = 130

// Server-supported reply triggers (server/scripts.lua: Scripts.SanitizeTrigger).
const TRIGGERS = [
  { t: 'signal', label: 'Script signal', color: '#f29c3a', make: () => ({ t: 'signal', name: 'alarm' }) },
  { t: 'give_item', label: 'Give item', color: '#b36ee0', make: () => ({ t: 'give_item', item: '', count: 1 }) },
  { t: 'take_item', label: 'Consume item', color: '#e35d5d', make: () => ({ t: 'take_item', item: '', count: 1 }) },
  { t: 'teleport', label: 'Teleport', color: '#e0c33a', make: () => ({ t: 'teleport', x: 0, y: 0, z: 0, h: 0 }) },
  { t: 'police_alert', label: 'Police alert', color: '#4a8df0', make: () => ({ t: 'police_alert', text: 'Suspicious activity' }) },
]

/** Lay the tree out by depth; each node gets a column by subtree width. Pure function of the data. */
function layout(nodes) {
  const pos = {}
  const edges = []
  const seen = new Set()
  let cursor = 0
  const place = (id, depth) => {
    if (seen.has(id) || !nodes[id]) return null
    seen.add(id)
    const kids = nodes[id].replies.map((r) => ({ r, child: r.target && nodes[r.target] && !seen.has(r.target) ? place(r.target, depth + 1) : null }))
    const placed = kids.filter((k) => k.child !== null)
    let x
    if (placed.length === 0) { x = cursor; cursor += NODE_W + GAP_X }
    else x = (placed[0].child + placed[placed.length - 1].child) / 2
    pos[id] = { x, y: depth * (NODE_H + GAP_Y) }
    for (const { r } of kids) if (r.target && nodes[r.target]) edges.push({ from: id, to: r.target, reply: r })
    return x
  }
  place('start', 0)
  // Orphans (unreachable nodes) are still shown, to the right.
  for (const id of Object.keys(nodes)) if (!seen.has(id)) { place(id, 0) }
  return { pos, edges }
}

export default function DialogueEditor({ npc, roles, onChange, onClose }) {
  const [dlg, setDlg] = useState(() => structuredClone(npc.dialogue || emptyDialogue()))
  const [label, setLabel] = useState(npc.label)
  const [role, setRole] = useState(npc.role || '')
  const [selReply, setSelReply] = useState(null) // { node, reply }
  const [zoom, setZoom] = useState(1)
  const [pan, setPan] = useState({ x: 120, y: 60 })
  const drag = useRef(null)

  const done = () => { onChange({ dialogue: dlg, label: label || npc.label, role }); onClose() }
  useEscape(() => { onClose(); return true })

  const { pos, edges } = useMemo(() => layout(dlg.nodes), [dlg])
  const mutate = (fn) => setDlg((d) => { const c = structuredClone(d); fn(c.nodes); return c })

  const addReply = (nodeId) => {
    const rid = uid('r')
    const nid = uid('n')
    mutate((nodes) => {
      nodes[nid] = { id: nid, text: '', replies: [] }
      nodes[nodeId].replies.push({ id: rid, label: 'New reply', target: nid, roles: [], triggers: [] })
    })
    setSelReply({ node: nodeId, reply: rid })
  }

  const deleteBranch = (nodeId, replyId) => {
    mutate((nodes) => {
      const reply = nodes[nodeId].replies.find((r) => r.id === replyId)
      nodes[nodeId].replies = nodes[nodeId].replies.filter((r) => r.id !== replyId)
      // Remove the target subtree only when nothing else points at it.
      const removeIfOrphan = (id) => {
        if (!id || id === 'start' || !nodes[id]) return
        const stillUsed = Object.values(nodes).some((n) => n.id !== id && n.replies.some((r) => r.target === id))
        if (stillUsed) return
        const kids = nodes[id].replies.map((r) => r.target)
        delete nodes[id]
        kids.forEach(removeIfOrphan)
      }
      removeIfOrphan(reply?.target)
    })
    setSelReply(null)
  }

  const selected = selReply && dlg.nodes[selReply.node]?.replies.find((r) => r.id === selReply.reply)
  const patchReply = (patch) => mutate((nodes) => Object.assign(nodes[selReply.node].replies.find((r) => r.id === selReply.reply), patch))
  const nodeLabel = (id) => (id === 'start' ? 'Start' : (dlg.nodes[id]?.text || '(empty)').slice(0, 28))

  const onDown = (e) => { if (e.target.closest('.dnode, .dpill')) return; drag.current = { x: e.clientX - pan.x, y: e.clientY - pan.y } }
  const onMove = (e) => { if (drag.current) setPan({ x: e.clientX - drag.current.x, y: e.clientY - drag.current.y }) }
  const onUp = () => { drag.current = null }

  const fit = () => {
    const xs = Object.values(pos).map((p) => p.x)
    const width = (Math.max(...xs) - Math.min(...xs)) + NODE_W
    const z = Math.max(0.4, Math.min(1, 1200 / width))
    setZoom(z); setPan({ x: 60 - Math.min(...xs) * z, y: 50 })
  }

  return (
    <div className="full">
      <div className="fbar">
        <div style={{ display: 'flex', gap: 14, alignItems: 'center' }}>
          <Icon name="message" size={20} />
          <span className="label">Dialogue</span>
          <span className="label">Name</span>
          <input className="input sm" style={{ width: 200 }} value={label} maxLength={60} onChange={(e) => setLabel(e.target.value)} />
          <span className="label">Role</span>
          <input className="input sm" style={{ width: 200 }} value={role} placeholder="—" maxLength={60} onChange={(e) => setRole(e.target.value)} />
        </div>
        <div style={{ display: 'flex', gap: 8 }}>
          <button className="btn accent" onClick={done}>Done</button>
          <button className="btn" onClick={onClose}>Cancel</button>
        </div>
      </div>

      <div className="dlg-main">
        <div className="dlg-canvas" onMouseDown={onDown} onMouseMove={onMove} onMouseUp={onUp} onMouseLeave={onUp}>
          <div className="dlg-tools">
            <button className="btn sm icon" onClick={() => setZoom((z) => Math.max(0.4, +(z - 0.1).toFixed(2)))}>−</button>
            <span className="btn sm" style={{ pointerEvents: 'none' }}>{Math.round(zoom * 100)}%</span>
            <button className="btn sm icon" onClick={() => setZoom((z) => Math.min(1.6, +(z + 0.1).toFixed(2)))}>+</button>
            <button className="btn sm" onClick={fit}>Fit</button>
          </div>
          <div className="dlg-legend">
            {TRIGGERS.map((t) => <span key={t.t}><i style={{ display: 'inline-block', width: 8, height: 8, borderRadius: 4, background: t.color, marginRight: 5 }} />{t.label}</span>)}
          </div>

          <div style={{ position: 'absolute', left: 0, top: 0, transform: `translate(${pan.x}px, ${pan.y}px) scale(${zoom})`, transformOrigin: '0 0' }}>
            <svg style={{ position: 'absolute', left: 0, top: 0, overflow: 'visible', pointerEvents: 'none' }} width="1" height="1">
              {edges.map((e) => {
                const a = pos[e.from]; const b = pos[e.to]
                if (!a || !b) return null
                const x1 = a.x + NODE_W / 2; const y1 = a.y + NODE_H; const x2 = b.x + NODE_W / 2; const y2 = b.y
                const my = (y1 + y2) / 2
                const sel = selReply?.reply === e.reply.id
                return <path key={e.reply.id} d={`M${x1},${y1} C${x1},${my} ${x2},${my} ${x2},${y2}`} fill="none" stroke={sel ? '#2ed3f1' : 'rgba(46,211,241,0.55)'} strokeWidth={sel ? 3 : 2} />
              })}
            </svg>
            {edges.map((e) => {
              const a = pos[e.from]; const b = pos[e.to]
              if (!a || !b) return null
              const x = (a.x + b.x) / 2 + NODE_W / 2; const y = (a.y + NODE_H + b.y) / 2
              return <button key={e.reply.id} className={`dpill ${selReply?.reply === e.reply.id ? 'sel' : ''}`} style={{ left: x, top: y }} onClick={() => setSelReply({ node: e.from, reply: e.reply.id })}>{e.reply.label || '(no text)'}</button>
            })}
            {Object.values(dlg.nodes).map((n) => {
              const p = pos[n.id]
              if (!p) return null
              return (
                <div key={n.id} className={`dnode ${n.id === 'start' ? 'start' : ''}`} style={{ left: p.x, top: p.y, height: NODE_H }}>
                  <header><Icon name={n.id === 'start' ? 'play' : 'message'} size={12} /> {n.id === 'start' ? 'Start' : 'Message'}</header>
                  <textarea value={n.text} maxLength={300} placeholder="What does the NPC say?" onChange={(e) => mutate((nodes) => { nodes[n.id].text = e.target.value })} />
                  <footer style={{ position: 'absolute', bottom: 0, left: 0, right: 0 }}>
                    <span>{n.replies.length} {n.replies.length === 1 ? 'reply' : 'replies'}</span>
                    <button className="btn sm" disabled={n.replies.length >= 8} onClick={() => addReply(n.id)}>+ Reply</button>
                  </footer>
                </div>
              )
            })}
          </div>
        </div>

        <div className="dside">
          {!selected && <div className="muted" style={{ lineHeight: 1.5 }}>Click a reply pill to edit it. “+ Reply” on a message adds a choice for the player and the message it leads to.</div>}
          {selected && (
            <>
              <h3 className="display">Reply</h3>
              <span className="label">The choice the player taps</span>
              <input className="input sm" style={{ margin: '4px 0 2px' }} value={selected.label} maxLength={80} placeholder="e.g. Ask about the job" onChange={(e) => patchReply({ label: e.target.value })} />
              <div className="muted" style={{ fontSize: 12, marginBottom: 10 }}>After “{nodeLabel(selReply.node)}”</div>

              <span className="label">Jump target</span>
              <select className="select sm" style={{ margin: '4px 0 12px' }} value={selected.jump || ''} onChange={(e) => patchReply({ jump: e.target.value || undefined })}>
                <option value="">↓ Continue normally</option>
                <option value="end">✕ End the conversation</option>
                {Object.keys(dlg.nodes).map((id) => <option key={id} value={id}>{id === 'start' ? '↺ Back to start' : `→ ${nodeLabel(id)}`}</option>)}
              </select>

              <span className="label">Who sees this reply</span>
              <div style={{ display: 'flex', gap: 4, flexWrap: 'wrap', margin: '4px 0 12px' }}>
                <button className={`chip ${selected.roles.length === 0 ? 'on' : ''}`} onClick={() => patchReply({ roles: [] })}>Everyone</button>
                {roles.map((r) => (
                  <button key={r.id} className={`chip ${selected.roles.includes(r.id) ? 'on' : ''}`} onClick={() => patchReply({ roles: selected.roles.includes(r.id) ? selected.roles.filter((x) => x !== r.id) : [...selected.roles, r.id] })}>{r.label}</button>
                ))}
              </div>

              <span className="label">⚡ Triggers</span>
              <div className="trlist" style={{ margin: '4px 0' }}>
                {selected.triggers.map((t, i) => {
                  const meta = TRIGGERS.find((m) => m.t === t.t)
                  const set = (patch) => patchReply({ triggers: selected.triggers.map((x, k) => (k === i ? { ...x, ...patch } : x)) })
                  return (
                    <div className="tr" key={i} style={{ borderLeft: `3px solid ${meta.color}` }}>
                      <b>{meta.label}</b>
                      {t.t === 'signal' && <input className="input" value={t.name} onChange={(e) => set({ name: e.target.value.replace(/[^\w\-. ]/g, '') })} />}
                      {(t.t === 'give_item' || t.t === 'take_item') && <><input className="input" placeholder="item" value={t.item} onChange={(e) => set({ item: e.target.value.replace(/[^\w-]/g, '') })} /><NumberInput className="input" style={{ width: 60, flex: 'none' }} value={t.count} min={1} max={1000} onChange={(n) => set({ count: n })} /></>}
                      {t.t === 'police_alert' && <input className="input" value={t.text} onChange={(e) => set({ text: e.target.value })} />}
                      {t.t === 'teleport' && ['x', 'y', 'z'].map((k) => <NumberInput key={k} className="input" style={{ width: 62, flex: 'none' }} value={t[k]} onChange={(n) => set({ [k]: n })} />)}
                      <button className="btn sm icon danger" onClick={() => patchReply({ triggers: selected.triggers.filter((_, k) => k !== i) })}><Icon name="close" size={11} /></button>
                    </div>
                  )
                })}
              </div>
              <div className="trgrid">
                {TRIGGERS.map((t) => <button key={t.t} disabled={selected.triggers.length >= 6} onClick={() => patchReply({ triggers: [...selected.triggers, t.make()] })}>+ {t.label}</button>)}
              </div>

              <button className="btn danger block" style={{ marginTop: 18 }} onClick={() => deleteBranch(selReply.node, selReply.reply)}><Icon name="trash" size={13} /> Delete this reply branch</button>
            </>
          )}
        </div>
      </div>
    </div>
  )
}
