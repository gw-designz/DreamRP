import { useCallback, useEffect, useState } from 'react'
import { useApp, useEscape } from '../../AppContext.jsx'
import { Icon, NumberInput } from '../../components/ui.jsx'
import { errorText, rpc } from '../../services/nui.js'
import { newScript, uid } from './model.js'

// Only blocks the server runtime implements (server/scripts.lua). Keep both lists in sync.
const DM_ACTIONS = [
  ['narrate', 'Narrate'], ['flash', 'Flash'], ['black_screen', 'Black screen'], ['blur', 'Blur'], ['shake', 'Shake'],
  ['knock_down', 'Knock down'], ['freeze', 'Freeze'], ['heal', 'Heal'], ['revive', 'Revive'], ['lightning', 'Lightning'],
  ['blackout', 'Blackout'], ['police_alert', 'Police alert'], ['explosion', 'Explosion'], ['fire', 'Fire'], ['give_item', 'Give item'],
]

const GROUPS = [
  { id: 'Control', color: '#8a7a22', blocks: [
    { t: 'wait', label: 'Wait', icon: 'minus', make: () => ({ t: 'wait', ms: 1000 }) },
    { t: 'repeat', label: 'Repeat', icon: 'undo', make: () => ({ t: 'repeat', n: 2, blocks: [] }) },
    { t: 'if', label: 'If', icon: 'chevron', make: () => ({ t: 'if', name: 'counter', op: '>', value: 0, scope: 'shared', blocks: [], elseBlocks: [] }) },
    { t: 'limit', label: 'Use limit', icon: 'lock', make: () => ({ t: 'limit', max: 1 }) },
    { t: 'signal', label: 'Send signal', icon: 'bolt', make: () => ({ t: 'signal', name: 'alarm' }) },
    { t: 'stop', label: 'Stop', icon: 'close', make: () => ({ t: 'stop' }) },
  ] },
  { id: 'Variables', color: '#8b5a2b', blocks: [
    { t: 'set_var', label: 'Set variable', icon: 'minus', make: () => ({ t: 'set_var', name: 'counter', value: 0, scope: 'shared' }) },
    { t: 'change_var', label: 'Change variable', icon: 'plus', make: () => ({ t: 'change_var', name: 'counter', value: 1, scope: 'shared' }) },
  ] },
  { id: 'World', color: '#2f6f93', blocks: [
    { t: 'play_sound', label: 'Play sound', icon: 'speaker', make: () => ({ t: 'play_sound', to: 'near', name: 'CHECKPOINT_PERFECT', set: 'HUD_MINI_GAME_SOUNDSET' }) },
    { t: 'stop_sounds', label: 'Stop sounds', icon: 'speaker', make: () => ({ t: 'stop_sounds' }) },
    { t: 'lock_door', label: 'Lock / unlock door', icon: 'lock', make: () => ({ t: 'lock_door', doorId: 1, locked: false }) },
    { t: 'police_alert', label: 'Police alert', icon: 'alert', make: () => ({ t: 'police_alert', text: 'Suspicious activity' }) },
    { t: 'notify', label: 'Notify', icon: 'message', make: () => ({ t: 'notify', to: 'near', text: 'Something happens.' }) },
    { t: 'spawn_scenario', label: 'Spawn scenario', icon: 'play', make: () => ({ t: 'spawn_scenario', id: '' }) },
    { t: 'despawn_scenario', label: 'Despawn scenario', icon: 'close', make: () => ({ t: 'despawn_scenario', id: '' }) },
    { t: 'reset_scenario', label: 'Reset scenario', icon: 'undo', make: () => ({ t: 'reset_scenario', id: '' }) },
  ] },
  { id: 'Objects & locks', color: '#2f7a46', blocks: [
    { t: 'lock', label: 'Lock / unlock object', icon: 'lock', make: () => ({ t: 'lock', objectId: '', locked: false }) },
    { t: 'door_state', label: 'Open / close door', icon: 'lock', make: () => ({ t: 'door_state', objectId: '', open: true }) },
    { t: 'unlock_for', label: 'Unlock for…', icon: 'target', make: () => ({ t: 'unlock_for', objectId: '', seconds: 0 }) },
    { t: 'reset_object', label: 'Reset object', icon: 'undo', make: () => ({ t: 'reset_object', objectId: '' }) },
  ] },
  { id: 'Player', color: '#6a4fb0', blocks: [
    { t: 'teleport', label: 'Teleport player', icon: 'pin', make: () => ({ t: 'teleport', x: 0, y: 0, z: 0, h: 0 }) },
    { t: 'give_item', label: 'Give item', icon: 'gift', make: () => ({ t: 'give_item', item: '', count: 1 }) },
    { t: 'take_item', label: 'Take item', icon: 'down', make: () => ({ t: 'take_item', item: '', count: 1 }) },
    { t: 'hack', label: 'Hack', icon: 'keyboard', make: () => ({ t: 'hack', name: 'Key Matrix', game: 'skill', difficulty: 3, blocks: [], failBlocks: [] }) },
  ] },
  { id: 'NPC', color: '#a8434d', blocks: [
    { t: 'alert_npc', label: 'Alert NPC', icon: 'alert', make: () => ({ t: 'alert_npc', objectId: '' }) },
    { t: 'set_npc_route', label: 'Set NPC route', icon: 'walk', make: () => ({ t: 'set_npc_route', objectId: '', on: true }) },
  ] },
  { id: 'Vehicles', color: '#8d8a26', blocks: [
    { t: 'spawn_vehicle', label: 'Spawn vehicle', icon: 'car', make: () => ({ t: 'spawn_vehicle', model: 'police', objectId: '', tag: '' }) },
    { t: 'remove_vehicle', label: 'Remove vehicle', icon: 'close', make: () => ({ t: 'remove_vehicle', tag: '' }) },
  ] },
  { id: 'DM actions', color: '#23836f', blocks: [
    { t: 'dm_action', label: 'DM action', icon: 'bolt', make: () => ({ t: 'dm_action', action: 'narrate', to: 'near', text: 'Something happens.', seconds: 6 }) },
  ] },
]
const META = {}
for (const g of GROUPS) for (const b of g.blocks) META[b.t] = { ...b, color: g.color }

// Nested lists a block can contain, with the label shown above each.
const LISTS = {
  repeat: [['blocks', 'Do']],
  if: [['blocks', 'Then'], ['elseBlocks', 'Otherwise']],
  hack: [['blocks', 'Hacked'], ['failBlocks', 'Failed']],
}

const WHEN = [
  { value: 'spawn', label: 'When the scenario goes live', needsObject: false },
  { value: 'enter', label: 'When a player enters a trigger box', needsObject: true, kinds: ['trigger'] },
  { value: 'leave', label: 'When a player leaves a trigger box', needsObject: true, kinds: ['trigger'] },
  { value: 'use', label: 'When a player uses an object', needsObject: true, kinds: ['interactive', 'storage'] },
  { value: 'unlocked', label: 'When a door is unlocked', needsObject: true, kinds: ['door'] },
  { value: 'signal', label: 'When a signal is sent', needsObject: false },
]

// A path is an array like [2, 'blocks', 0] addressing blocks[2].blocks[0].
const getList = (blocks, listPath) => listPath.reduce((acc, k) => acc[k], blocks)
function update(blocks, listPath, fn) {
  const clone = structuredClone(blocks)
  fn(getList(clone, listPath))
  return clone
}
const lists = (b) => (LISTS[b.t] || []).map(([key]) => b[key] || [])
const blockCount = (blocks) => blocks.reduce((n, b) => n + 1 + lists(b).reduce((m, l) => m + blockCount(l), 0), 0)
const depthOf = (blocks) => (blocks.length ? 1 + Math.max(...blocks.map((b) => Math.max(0, ...lists(b).map(depthOf)))) : 0)
/** Worst case blocks per run: repeat multiplies, if/hack count the larger branch. */
const worstCase = (blocks) => blocks.reduce((n, b) => {
  if (b.t === 'repeat') return n + 1 + b.n * worstCase(b.blocks || [])
  if (b.t === 'if') return n + 1 + Math.max(worstCase(b.blocks || []), worstCase(b.elseBlocks || []))
  if (b.t === 'hack') return n + 1 + Math.max(worstCase(b.blocks || []), worstCase(b.failBlocks || []))
  return n + 1
}, 0)

const ago = (s) => (s < 60 ? `${s}s ago` : s < 3600 ? `${Math.floor(s / 60)}m ago` : `${Math.floor(s / 3600)}h ago`)

export default function ScriptEditor({ definition, setDef, title, scenarioId, live, scenarioDirty, advanced, onToggleAdvanced, focusObject, onClose }) {
  const { toast, confirm } = useApp()
  const scripts = definition.scripts
  const objects = definition.objects
  const [selId, setSelId] = useState(() => scripts.find((s) => s.when.objectId === focusObject)?.id || scripts[0]?.id || null)
  const committed = scripts.find((s) => s.id === selId) || null
  const [work, setWork] = useState(committed)
  const [target, setTarget] = useState([]) // list path new blocks are appended to
  const [library, setLibrary] = useState(null)
  const [info, setInfo] = useState(null)

  // Reload the working copy only when a different script is selected.
  useEffect(() => { setWork(committed ? structuredClone(committed) : null); setTarget([]) }, [selId]) // eslint-disable-line react-hooks/exhaustive-deps
  const dirty = !!work && !!committed && JSON.stringify(work) !== JSON.stringify(committed)

  const commit = useCallback(() => {
    if (!work) return
    setDef((def) => ({ ...def, scripts: def.scripts.map((s) => (s.id === work.id ? work : s)) }))
  }, [work, setDef])

  const close = () => { commit(); onClose() }
  useEscape(() => { close(); return true })

  const select = (id) => { if (id === selId) return; commit(); setSelId(id) }

  const patch = (p) => setWork((w) => ({ ...w, ...p }))
  const patchBlocks = (listPath, fn) => setWork((w) => ({ ...w, blocks: update(w.blocks, listPath, fn) }))

  const addScript = () => {
    commit()
    const s = newScript(focusObject)
    setDef((def) => ({ ...def, scripts: [...def.scripts, s] }))
    setSelId(s.id)
    setWork(structuredClone(s))
  }
  const deleteScript = async () => {
    const yes = await confirm({ title: 'Delete script', body: `Delete “${work.name}”?`, confirmLabel: 'Delete', danger: true })
    if (!yes) return
    const next = scripts.find((s) => s.id !== selId)?.id || null
    setDef((def) => ({ ...def, scripts: def.scripts.filter((s) => s.id !== selId) }))
    setSelId(next)
  }
  const toggleEnabled = (s) => {
    if (s.id === selId) { patch({ enabled: s.enabled === false }); setDef((def) => ({ ...def, scripts: def.scripts.map((x) => (x.id === s.id ? { ...x, enabled: s.enabled === false } : x)) })); return }
    setDef((def) => ({ ...def, scripts: def.scripts.map((x) => (x.id === s.id ? { ...x, enabled: s.enabled === false } : x)) }))
  }
  const addBlock = (meta) => patchBlocks(target, (list) => list.push(meta.make()))

  const saveToLibrary = async () => {
    const res = await rpc('dm.librarySave', { name: work.name, script: work })
    toast(res.ok ? 'Saved to library' : errorText(res.error), res.ok ? 'ok' : 'error')
  }
  const openLibrary = async () => {
    const res = await rpc('dm.libraryList')
    if (!res.ok) return toast(errorText(res.error), 'error')
    setLibrary(res.data)
  }
  const importFromLibrary = (entry) => {
    commit()
    const copy = { ...structuredClone(entry.script), id: uid('s') }
    setDef((def) => ({ ...def, scripts: [...def.scripts, copy] }))
    setSelId(copy.id)
    setLibrary(null)
  }
  const runNow = async (s) => {
    if (!live) return toast('Spawn the scenario first — scripts only run while it is live', 'warn')
    if (scenarioDirty || dirty) return toast('Save the scenario first — the test runs the saved version', 'warn')
    const res = await rpc('dm.runScript', { id: scenarioId, scriptId: s.id })
    toast(res.ok ? `Ran “${s.name}”` : errorText(res.error), res.ok ? 'ok' : 'error')
    refreshInfo()
  }

  // Live variables and run counts for the Cost / Variables panel.
  const refreshInfo = useCallback(async () => {
    const res = await rpc('dm.scriptInfo', { id: scenarioId })
    if (res.ok) setInfo(res.data)
  }, [scenarioId])
  useEffect(() => {
    refreshInfo()
    const t = setInterval(refreshInfo, 3000)
    return () => clearInterval(t)
  }, [refreshInfo])
  const resetVars = async () => {
    const res = await rpc('dm.resetVars', { id: scenarioId })
    toast(res.ok ? 'Variables reset' : errorText(res.error), res.ok ? 'ok' : 'error')
    refreshInfo()
  }

  const whenMeta = work && WHEN.find((w) => w.value === work.when.type)
  const objectChoices = work && whenMeta?.kinds ? objects.filter((o) => whenMeta.kinds.includes(o.kind)) : []
  const scopeLabel = work ? (objects.find((o) => o.id === work.when.objectId)?.label || 'the scenario') : ''
  const total = work ? blockCount(work.blocks) : 0
  const depth = work ? depthOf(work.blocks) : 0
  const stats = work && info?.runs?.[work.id]
  const vars = info?.vars ? Object.entries(info.vars) : []

  return (
    <div className="full">
      <div className="fbar sfbar">
        <div style={{ display: 'flex', gap: 12, alignItems: 'center' }}>
          <span style={{ color: 'var(--accent)' }}><Icon name="code" size={30} /></span>
          <div className="display"><h2>Scripts · {title}</h2><small>Showing {work ? scopeLabel : 'all scripts'} · {live ? 'live here' : 'not live'}</small></div>
        </div>
        <div style={{ display: 'flex', gap: 8 }}>
          <button className={`advpill ${advanced ? 'on' : ''}`} onClick={onToggleAdvanced}>✦ Advanced {advanced ? 'on' : 'off'}</button>
          <button className="donebtn" onClick={close}><Icon name="close" size={14} /> Done</button>
        </div>
      </div>

      <div className="se-wrap">
        <div className="se-col slist">
          <div className="slhead">
            <span className="label">Scripts ({scripts.length})</span>
            <span style={{ display: 'flex', gap: 4 }}>
              <button className="btn sm" onClick={openLibrary}>Library</button>
              <button className="btn sm" onClick={addScript}><Icon name="plus" size={11} /> New</button>
            </span>
          </div>
          {library && (
            <div style={{ marginBottom: 12, background: 'var(--bg-input)', padding: 8 }}>
              <div className="label">Library <button className="btn sm ghost" onClick={() => setLibrary(null)}>×</button></div>
              {library.length === 0 && <div className="muted" style={{ fontSize: 12 }}>The library is empty.</div>}
              {library.map((l) => <button key={l.id} className="si" onClick={() => importFromLibrary(l)}><b>{l.name}</b><span>by {l.owner_name}</span></button>)}
            </div>
          )}
          {scripts.length === 0 && <div className="empty">No scripts yet.</div>}
          {scripts.map((s) => (
            <div key={s.id} className={`si ${s.id === selId ? 'sel' : ''}`} onClick={() => select(s.id)} role="button" tabIndex={0}>
              <span className="sitext">
                <b>{(s.id === selId && work ? work.name : s.name)}</b>
                <span>{objects.find((o) => o.id === s.when.objectId)?.label || 'Scenario'} · {WHEN.find((w) => w.value === s.when.type)?.label}</span>
              </span>
              <button className={`dot ${s.enabled === false ? '' : 'on'}`} title={s.enabled === false ? 'Disabled — click to enable' : 'Enabled — click to disable'} onClick={(e) => { e.stopPropagation(); toggleEnabled(s) }} />
              <button className="runb" title="Run now (scenario must be live and saved)" onClick={(e) => { e.stopPropagation(); runNow(s) }}><Icon name="play" size={11} fill="currentColor" /></button>
            </div>
          ))}
        </div>

        <div className="se-col palette">
          {GROUPS.map((g) => (
            <div key={g.id}>
              <div className="pg">{g.id}</div>
              {g.blocks.map((b) => (
                <button key={b.t} className="pb" style={{ '--bc': g.color }} disabled={!work} onClick={() => addBlock(b)}><Icon name={b.icon} size={14} />{b.label}</button>
              ))}
            </div>
          ))}
        </div>

        <div className="se-col">
          {!work && <div className="mutedbox">Create or pick a script.</div>}
          {work && (
            <>
              <div className="sbar">
                <input className="nm" value={work.name} maxLength={40} onChange={(e) => patch({ name: e.target.value })} />
                <span className="muted" style={{ fontSize: 12 }}>on {scopeLabel}</span>
                <span className="muted" style={{ fontSize: 12 }}>{total}/200 blocks · depth {depth}/6</span>
                <button className="btn sm" disabled={!dirty} onClick={() => setWork(structuredClone(committed))}>Revert</button>
                <button className="btn sm" onClick={saveToLibrary}>Save to library</button>
                <button className="btn sm danger" onClick={deleteScript}><Icon name="trash" size={11} /> Delete</button>
                <button className="btn sm accent" onClick={() => { commit(); toast('Script saved to the scenario draft', 'ok') }}>Save</button>
              </div>

              <div className="when">
                <Icon name="flag" size={16} />
                <select className="select sm" style={{ width: 300 }} value={work.when.type} onChange={(e) => {
                  const type = e.target.value
                  const m = WHEN.find((w) => w.value === type)
                  const first = m.kinds ? objects.find((o) => m.kinds.includes(o.kind))?.id : undefined
                  patch({ when: { type, objectId: first, signal: type === 'signal' ? (work.when.signal || 'alarm') : undefined } })
                }}>
                  {WHEN.map((w) => <option key={w.value} value={w.value}>{w.label}</option>)}
                </select>
                {whenMeta.needsObject && (
                  <select className="select sm" style={{ width: 260 }} value={work.when.objectId || ''} onChange={(e) => patch({ when: { ...work.when, objectId: e.target.value || undefined } })}>
                    <option value="">Any matching object</option>
                    {objectChoices.map((o) => <option key={o.id} value={o.id}>This object ({o.label})</option>)}
                  </select>
                )}
                {work.when.type === 'signal' && (
                  <input className="input sm" style={{ width: 180 }} placeholder="signal name" value={work.when.signal || ''} onChange={(e) => patch({ when: { ...work.when, signal: e.target.value.replace(/[^\w\-. ]/g, '') } })} />
                )}
              </div>
              {whenMeta.needsObject && objectChoices.length === 0 && <div className="muted" style={{ margin: '0 0 8px', fontSize: 12.5 }}>Place a {whenMeta.kinds.join(' / ')} first — this event needs one.</div>}

              <BlockList blocks={work.blocks} path={[]} target={target} setTarget={setTarget} patchBlocks={patchBlocks} objects={objects} />
              {work.blocks.length === 0 && <div className="muted" style={{ padding: '14px 0' }}>Click a block on the left to add it. Blocks run from top to bottom.</div>}
              <div className="muted" style={{ fontSize: 12, marginTop: 10 }}>
                {target.length ? 'New blocks go inside the highlighted section.' : 'Click a block to put the next one after it.'}
                {target.length > 0 && <button className="btn sm ghost" style={{ marginLeft: 8 }} onClick={() => setTarget([])}>Back to top level</button>}
              </div>
            </>
          )}
        </div>

        <div className="se-col help">
          <h4>Cost</h4>
          <p>{work ? `Worst case per run: ${worstCase(work.blocks)} blocks · 0 database calls.` : '—'}<br />
            {!info?.live ? 'The scenario is not live, so nothing runs.' : stats ? `Ran ${stats.count} time${stats.count === 1 ? '' : 's'} since the scenario went live${stats.last ? ` · last ${ago(Math.max(0, info.now - stats.last))}` : ''}.` : 'No runs on the server since it started or this script was saved.'}</p>
          <div className="vhead"><h4 style={{ margin: 0 }}>Variables</h4>
            <span><button className="btn sm" onClick={refreshInfo}>Refresh</button> <button className="btn sm danger" disabled={!info?.live} onClick={resetVars}>Reset</button></span>
          </div>
          {!info?.live && <p>Spawn the scenario to see its variables.</p>}
          {info?.live && vars.length === 0 && <p>No values yet.</p>}
          {vars.map(([k, v]) => <div key={k} className="vrow"><span>{k}</span><b>{String(v)}</b></div>)}
          <h4>How it works</h4>
          <p>A script starts on its “when” event and runs its blocks top to bottom. Repeat, If and Hack run the blocks inside them.</p>
          <p>“This object” is the object the script is attached to, or the one that caused the event (the trigger box, the NPC…).</p>
          <p>Shared variables belong to the scenario; player ones belong to each character. They start over when the scenario is switched off.</p>
          <p>Text (notify, police alert, announce) can show a variable: <code>{'{{kills}}'}</code> is the shared value, <code>{'{{player.kills}}'}</code> the player’s own, <code>{'{{player.name}}'}</code> their name. Unset values show 0.</p>
          <p>Use limit is a counter: it stops the script once it has gone past that many times.</p>
          <p>“The player” is whoever set the script off. A script started by something else (a signal, going live) has no player — Hack fails and “the player” blocks do nothing.</p>
          <p>Scripts only run while the scenario is live and Advanced is switched on.</p>
        </div>
      </div>
    </div>
  )
}

function BlockList({ blocks, path, target, setTarget, patchBlocks, objects }) {
  const move = (i, d) => patchBlocks(path, (list) => { const j = i + d; if (j < 0 || j >= list.length) return; [list[i], list[j]] = [list[j], list[i]] })
  const remove = (i) => patchBlocks(path, (list) => list.splice(i, 1))
  const dup = (i) => patchBlocks(path, (list) => list.splice(i + 1, 0, structuredClone(list[i])))
  const edit = (i, p) => patchBlocks(path, (list) => Object.assign(list[i], p))
  const same = (a, b) => a.length === b.length && a.every((x, k) => x === b[k])

  return (
    <>
      {blocks.map((b, i) => {
        const meta = META[b.t]
        const nests = LISTS[b.t] || []
        const row = (
          <div className="blk" style={{ '--bc': meta.color }}>
            <Icon name={meta.icon} size={15} />
            <span className="bn">{meta.label}</span>
            <BlockFields b={b} edit={(p) => edit(i, p)} objects={objects} />
            <span className="spacer" />
            <button className="btn sm icon ghost" onClick={() => move(i, -1)} aria-label="Move up"><Icon name="up" size={13} /></button>
            <button className="btn sm icon ghost" onClick={() => move(i, 1)} aria-label="Move down"><Icon name="down" size={13} /></button>
            <button className="btn sm icon ghost" onClick={() => dup(i)} aria-label="Duplicate"><Icon name="copy" size={13} /></button>
            <button className="btn sm icon danger" onClick={() => remove(i)} aria-label="Delete"><Icon name="trash" size={13} /></button>
          </div>
        )
        if (nests.length === 0) return <div key={i}>{row}</div>
        return (
          <div key={i} className="blkgroup" style={{ '--bc': meta.color }}>
            {row}
            {nests.map(([key, label]) => {
              const p = [...path, i, key]
              return (
                <div key={key} className="nest">
                  <div className="nl">{label} <button className={same(target, p) ? 'here' : ''} onClick={() => setTarget(p)}>{same(target, p) ? '● adding here' : 'add blocks here'}</button></div>
                  <BlockList blocks={b[key] || []} path={p} target={target} setTarget={setTarget} patchBlocks={patchBlocks} objects={objects} />
                </div>
              )
            })}
          </div>
        )
      })}
    </>
  )
}

const slug = (v) => v.replace(/[^\w\-. ]/g, '')
const cleanId = (v) => v.replace(/[^\w-]/g, '')

function ObjectSelect({ value, onChange, objects, kinds }) {
  const list = kinds ? objects.filter((o) => kinds.includes(o.kind)) : objects
  return (
    <select className="select" value={value} onChange={(e) => onChange(e.target.value)}>
      <option value="">Choose…</option>
      {list.map((o) => <option key={o.id} value={o.id}>{o.label}</option>)}
    </select>
  )
}

// Hack: which minigame the player gets, and how hard. The skill check has levels 1-5; the minigames use
// the four presets (stored as 1, 2, 4, 5 so one number covers both).
const PRESET_CHOICES = [[1, 'Easy'], [2, 'Normal'], [4, 'Hard'], [5, 'Expert']]

function HackFields({ b, edit }) {
  const { session } = useApp()
  const games = session?.catalog?.hacks?.length ? session.catalog.hacks : [{ id: 'skill', label: 'Skill check (ox_lib)' }]
  const game = b.game || 'skill'
  const skill = game === 'skill'
  const known = games.some((g) => g.id === game)
  return (
    <>
      <input className="input" value={b.name} maxLength={40} onChange={(e) => edit({ name: slug(e.target.value) })} />
      <select className="select" style={{ minWidth: 200 }} value={game} onChange={(e) => {
        const next = e.target.value
        // keep the difficulty valid for the new kind (the minigames have no level 3)
        const d = next !== 'skill' && b.difficulty === 3 ? 2 : b.difficulty
        edit({ game: next, difficulty: d })
      }}>
        {!known && <option value={game}>{game} (not configured)</option>}
        {games.map((g) => <option key={g.id} value={g.id}>{g.label}</option>)}
      </select>
      <select className="select" value={b.difficulty} onChange={(e) => edit({ difficulty: Number(e.target.value) })}>
        {skill
          ? [1, 2, 3, 4, 5].map((d) => <option key={d} value={d}>difficulty {d}</option>)
          : PRESET_CHOICES.map(([v, l]) => <option key={v} value={v}>{l}</option>)}
      </select>
    </>
  )
}

function BlockFields({ b, edit, objects }) {
  const scope = (
    <select className="select" value={b.scope} onChange={(e) => edit({ scope: e.target.value })}>
      <option value="shared">shared</option><option value="player">player</option>
    </select>
  )
  const to = (
    <select className="select" value={b.to} onChange={(e) => edit({ to: e.target.value })}>
      <option value="player">the player</option><option value="near">everyone near</option><option value="everyone">everyone</option>
    </select>
  )
  switch (b.t) {
    case 'wait': return <><NumberInput className="input" value={b.ms} min={0} max={60000} onChange={(n) => edit({ ms: n })} /><span className="muted">ms</span></>
    case 'repeat': return <><NumberInput className="input" value={b.n} min={1} max={100} onChange={(n) => edit({ n })} /><span className="muted">times</span></>
    case 'limit': return <><span className="muted">stop after</span><NumberInput className="input" value={b.max} min={1} max={100000} onChange={(n) => edit({ max: n })} /><span className="muted">runs</span></>
    case 'signal': return <input className="input" value={b.name} onChange={(e) => edit({ name: slug(e.target.value) })} />
    case 'set_var':
    case 'change_var': return <>{scope}<input className="input" value={b.name} onChange={(e) => edit({ name: slug(e.target.value) })} /><span className="muted">{b.t === 'set_var' ? 'to' : 'by'}</span><NumberInput className="input" value={b.value} onChange={(n) => edit({ value: n })} /></>
    case 'if': return <>{scope}<input className="input" value={b.name} onChange={(e) => edit({ name: slug(e.target.value) })} />
      <select className="select" value={b.op} onChange={(e) => edit({ op: e.target.value })}>{['=', '!=', '>', '<', '>=', '<='].map((o) => <option key={o}>{o}</option>)}</select>
      <NumberInput className="input" value={b.value} onChange={(n) => edit({ value: n })} /></>
    case 'notify': return <>{to}<input className="input wide" maxLength={200} value={b.text} onChange={(e) => edit({ text: e.target.value })} /></>
    case 'police_alert': return <input className="input wide" maxLength={100} value={b.text} onChange={(e) => edit({ text: e.target.value })} />
    case 'play_sound': return <>{to}<input className="input" placeholder="sound name" value={b.name} onChange={(e) => edit({ name: cleanId(e.target.value) })} /><input className="input" placeholder="sound set" value={b.set} onChange={(e) => edit({ set: cleanId(e.target.value) })} /></>
    case 'stop_sounds': return <span className="muted">stops every sound scripts started</span>
    case 'lock_door': return <><select className="select" value={b.locked ? 'lock' : 'unlock'} onChange={(e) => edit({ locked: e.target.value === 'lock' })}><option value="unlock">unlock</option><option value="lock">lock</option></select>
      <span className="muted">ox_doorlock door ID</span><NumberInput className="input" value={b.doorId} min={1} max={100000} onChange={(n) => edit({ doorId: n })} /></>
    case 'spawn_scenario':
    case 'despawn_scenario':
    case 'reset_scenario': return <input className="input wide" placeholder="scenario ID (sc_…)" value={b.id} onChange={(e) => edit({ id: cleanId(e.target.value) })} />
    case 'lock': return <><select className="select" value={b.locked ? 'lock' : 'unlock'} onChange={(e) => edit({ locked: e.target.value === 'lock' })}><option value="unlock">unlock</option><option value="lock">lock</option></select>
      <ObjectSelect value={b.objectId} objects={objects} onChange={(v) => edit({ objectId: v })} /></>
    case 'door_state': return <><select className="select" value={b.open ? 'open' : 'close'} onChange={(e) => edit({ open: e.target.value === 'open' })}><option value="open">open</option><option value="close">close and lock</option></select>
      <ObjectSelect value={b.objectId} objects={objects} kinds={['door']} onChange={(v) => edit({ objectId: v })} /></>
    case 'unlock_for': return <><ObjectSelect value={b.objectId} objects={objects} onChange={(v) => edit({ objectId: v })} /><span className="muted">for the player, seconds (0 = until reset)</span><NumberInput className="input" value={b.seconds} min={0} max={86400} onChange={(n) => edit({ seconds: n })} /></>
    case 'reset_object': return <ObjectSelect value={b.objectId} objects={objects} onChange={(v) => edit({ objectId: v })} />
    case 'teleport': return <>{['x', 'y', 'z', 'h'].map((k) => <label key={k} className="muted" style={{ display: 'flex', gap: 4, alignItems: 'center' }}>{k.toUpperCase()}<NumberInput className="input" style={{ width: 90 }} value={b[k]} onChange={(n) => edit({ [k]: n })} /></label>)}</>
    case 'give_item':
    case 'take_item': return <><input className="input" placeholder="item name" value={b.item} onChange={(e) => edit({ item: cleanId(e.target.value) })} /><span className="muted">×</span><NumberInput className="input" value={b.count} min={1} max={1000} onChange={(n) => edit({ count: n })} /></>
    case 'hack': return <HackFields b={b} edit={edit} />
    case 'alert_npc': return <ObjectSelect value={b.objectId} objects={objects} kinds={['npc']} onChange={(v) => edit({ objectId: v })} />
    case 'set_npc_route': return <><select className="select" value={b.on ? 'on' : 'off'} onChange={(e) => edit({ on: e.target.value === 'on' })}><option value="on">start patrol</option><option value="off">stop patrol</option></select>
      <ObjectSelect value={b.objectId} objects={objects} kinds={['npc']} onChange={(v) => edit({ objectId: v })} /></>
    case 'spawn_vehicle': return <><input className="input" placeholder="model" value={b.model} onChange={(e) => edit({ model: cleanId(e.target.value) })} /><span className="muted">at</span>
      <ObjectSelect value={b.objectId} objects={objects} onChange={(v) => edit({ objectId: v })} /><input className="input" placeholder="tag (optional)" value={b.tag} onChange={(e) => edit({ tag: slug(e.target.value) })} /></>
    case 'remove_vehicle': return <input className="input" placeholder="tag (empty = all)" value={b.tag} onChange={(e) => edit({ tag: slug(e.target.value) })} />
    case 'dm_action': return <>
      <select className="select" value={b.action} onChange={(e) => edit({ action: e.target.value })}>{DM_ACTIONS.map(([id, l]) => <option key={id} value={id}>{l}</option>)}</select>
      {to}
      {['narrate', 'police_alert'].includes(b.action) && <input className="input wide" maxLength={200} value={b.text || ''} onChange={(e) => edit({ text: e.target.value })} />}
      {['narrate', 'black_screen', 'blur', 'shake', 'knock_down', 'freeze'].includes(b.action) && <><NumberInput className="input" value={b.seconds ?? 5} min={1} max={300} onChange={(n) => edit({ seconds: n })} /><span className="muted">s</span></>}
      {b.action === 'explosion' && <><NumberInput className="input" value={b.count ?? 1} min={1} max={5} onChange={(n) => edit({ count: n })} /><span className="muted">blasts</span></>}
      {b.action === 'blackout' && <><NumberInput className="input" value={b.minutes ?? 2} min={0} max={30} onChange={(n) => edit({ minutes: n })} /><span className="muted">min</span></>}
      {b.action === 'give_item' && <><input className="input" placeholder="item name" value={b.item || ''} onChange={(e) => edit({ item: cleanId(e.target.value) })} /><NumberInput className="input" value={b.count ?? 1} min={1} max={1000} onChange={(n) => edit({ count: n })} /></>}
    </>
    default: return null
  }
}

