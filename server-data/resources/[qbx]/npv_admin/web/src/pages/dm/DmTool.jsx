import { useCallback, useEffect, useMemo, useRef, useState } from 'react'
import { useApp, useEscape } from '../../AppContext.jsx'
import { Icon } from '../../components/ui.jsx'
import { client, closeUi, errorText, inGame, rpc } from '../../services/nui.js'
import ScenarioList from './ScenarioList.jsx'
import ScenarioEditor from './ScenarioEditor.jsx'
import DmActions from './DmActions.jsx'
import ScriptEditor from './ScriptEditor.jsx'
import DialogueEditor from './DialogueEditor.jsx'
import ReadyMade from './ReadyMade.jsx'
import AppearancePanel from './AppearancePanel.jsx'
import { defaultAppearance, isFreemode } from './appearance.js'
import { newObject } from './model.js'

const snapshot = (d) => (d ? JSON.stringify({ n: d.name, d: d.definition }) : '')
const slim = (o) => ({ id: o.id, kind: o.kind, model: o.model, label: o.label, coords: o.coords, size: o.size, anim: o.anim, patrol: o.patrol, length: o.length, appearance: o.appearance, world: o.world })

export default function DmTool({ visible, placing, edit }) {
  const { session, toast, confirm, has } = useApp()
  const [tab, setTab] = useState('builder')
  const [advanced, setAdvanced] = useState(() => { try { return localStorage.getItem('npv_adv') !== '0' } catch { return true } })
  const [labels, setLabels] = useState(true)
  const [peek, setPeek] = useState(false)
  const [list, setList] = useState([])
  const [summary, setSummary] = useState(null)
  const [loading, setLoading] = useState(false)
  const [draft, setDraft] = useState(null)
  const [saved, setSaved] = useState('')
  const [selId, setSelId] = useState(null)
  const [scriptsOpen, setScriptsOpen] = useState(false)
  const [dialogueFor, setDialogueFor] = useState(null)
  const [readyOpen, setReadyOpen] = useState(false)
  const [dressing, setDressing] = useState(null) // object id of the NPC being dressed
  const pending = useRef(null)

  const toggleAdvanced = useCallback(() => setAdvanced((a) => { try { localStorage.setItem('npv_adv', a ? '0' : '1') } catch { /* storage unavailable */ } return !a }), [])
  const dirty = useMemo(() => !!draft && snapshot(draft) !== saved, [draft, saved])

  const refresh = useCallback(async () => {
    setLoading(true)
    const res = await rpc('dm.list')
    setLoading(false)
    if (res.ok) { setList(res.data.scenarios); setSummary(res.data.summary) }
    else toast(errorText(res.error), 'error')
  }, [toast])

  useEffect(() => { if (visible) refresh() }, [visible, refresh])

  // Dev preview only (never in FiveM): ?view=dm&tab=actions&open=sc_10&sel=o1&scripts=1&dialogue=o1
  useEffect(() => {
    if (inGame) return
    const p = new URLSearchParams(window.location.search)
    if (p.get('tab')) setTab(p.get('tab'))
    if (p.get('ready')) setReadyOpen(true)
    if (p.get('open')) rpc('dm.get', { id: p.get('open') }).then((r) => {
      if (!r.ok) return
      setDraft(r.data); setSaved(snapshot(r.data)); setSelId(p.get('sel'))
      if (p.get('scripts')) setScriptsOpen(true)
      if (p.get('dialogue')) setDialogueFor(p.get('dialogue'))
      if (p.get('dress')) setDressing(p.get('dress'))
    })
  }, [])

  // Opened from an "Edit" prompt in the world: load that scenario and select the object.
  useEffect(() => {
    if (!edit) return undefined
    let alive = true
    ;(async () => {
      if (draft && draft.id === edit.sid) { setTab('builder'); setSelId(edit.oid); return }
      if (draft && dirty) {
        const yes = await confirm({ title: 'Unsaved changes', body: `Discard unsaved changes to “${draft.name}”?`, confirmLabel: 'Discard', danger: true })
        if (!yes || !alive) return
      }
      const res = await rpc('dm.get', { id: edit.sid })
      if (!alive) return
      if (!res.ok) return toast(errorText(res.error), 'error')
      const d = res.data
      d.definition = { objects: d.definition.objects || [], scripts: d.definition.scripts || [] }
      setTab('builder'); setDraft(d); setSaved(snapshot(d)); setSelId(edit.oid)
    })()
    return () => { alive = false }
  }, [edit?.n]) // eslint-disable-line react-hooks/exhaustive-deps

  // ---- draft editing ---------------------------------------------------------------------------
  const setDef = useCallback((fn) => setDraft((d) => (d ? { ...d, definition: fn(d.definition) } : d)), [])
  const patchObject = useCallback((id, patch) => setDef((def) => ({ ...def, objects: def.objects.map((o) => (o.id === id ? { ...o, ...(typeof patch === 'function' ? patch(o) : patch) } : o)) })), [setDef])
  const removeObject = useCallback((id) => {
    setDef((def) => ({
      ...def,
      objects: def.objects.filter((o) => o.id !== id),
      // Scripts that pointed at the deleted object fall back to "any object" so they stay valid.
      scripts: def.scripts.map((s) => (s.when.objectId === id ? { ...s, when: { ...s.when, objectId: undefined } } : s)),
    }))
    setSelId((s) => (s === id ? null : s))
  }, [setDef])

  const openScenario = useCallback(async (id) => {
    if (draft && draft.id !== id && dirty) {
      const yes = await confirm({ title: 'Unsaved changes', body: `Discard unsaved changes to “${draft.name}”?`, confirmLabel: 'Discard', danger: true })
      if (!yes) return
    }
    const res = await rpc('dm.get', { id })
    if (!res.ok) return toast(errorText(res.error), 'error')
    const d = res.data
    d.definition = { objects: d.definition.objects || [], scripts: d.definition.scripts || [] }
    setDraft(d)
    setSaved(snapshot(d))
    setSelId(null)
  }, [draft, dirty, confirm, toast])

  const closeDraft = useCallback(async () => {
    if (dirty) {
      const yes = await confirm({ title: 'Unsaved changes', body: 'Close without saving?', confirmLabel: 'Close', danger: true })
      if (!yes) return
    }
    setDraft(null); setSaved(''); setSelId(null)
    client('editor.stop')
  }, [dirty, confirm])

  const save = useCallback(async () => {
    if (!draft) return
    const res = await rpc('dm.save', { id: draft.id, name: draft.name, definition: draft.definition })
    if (!res.ok) return toast(errorText(res.error), 'error')
    const next = { ...draft, version: res.data.version }
    setDraft(next)
    setSaved(snapshot(next))
    toast(`Saved (v${res.data.version})`, 'ok')
    refresh()
  }, [draft, toast, refresh])

  const revert = useCallback(() => {
    try {
      const s = JSON.parse(saved)
      setDraft((d) => ({ ...d, name: s.n, definition: s.d }))
      setSelId(null)
    } catch { /* snapshot is always valid JSON */ }
  }, [saved])

  // ---- world editor sync -------------------------------------------------------------------------
  useEffect(() => {
    if (!visible && !placing) return undefined
    if (!draft) { client('editor.stop'); return undefined }
    const t = setTimeout(() => client('editor.sync', { objects: draft.definition.objects.map(slim), selected: selId }), 60)
    return () => clearTimeout(t)
  }, [draft?.definition.objects, selId, visible, placing, draft?.id]) // eslint-disable-line react-hooks/exhaustive-deps

  useEffect(() => { client('editor.labels', { on: labels }) }, [labels])
  // Build mode: clear the screen blur so the world is visible.
  useEffect(() => { if (visible) client('blur', { on: !peek && !dressing }) }, [peek, dressing, visible])

  // ---- placement ------------------------------------------------------------------------------------
  useEffect(() => {
    const onPlaced = (e) => {
      const d = e.detail
      if (d.active || !pending.current) return
      const job = pending.current
      pending.current = null
      if (!d.result) return
      if (job.patrolFor) {
        patchObject(job.patrolFor, (o) => ({ patrol: [...(o.patrol || []), { x: d.result.x, y: d.result.y, z: d.result.z }] }))
      } else if (job.moveId && job.world) {
        const { hash, ax, ay, az, ...c } = d.result
        patchObject(job.moveId, { coords: c, hash, anchor: { x: ax, y: ay, z: az } })
      } else if (job.moveId) {
        patchObject(job.moveId, { coords: d.result })
      } else if (job.world) {
        // An existing map / MLO door the staff member aimed at.
        const { hash, ax, ay, az, ...c } = d.result
        const obj = newObject('door', { label: job.label, coords: c, door: { ...job.door, world: true, hash, anchor: { x: ax, y: ay, z: az } } })
        setDef((def) => ({ ...def, objects: [...def.objects, obj] }))
        setSelId(obj.id)
      } else {
        const obj = newObject(job.kind, { model: job.model, label: job.label, coords: d.result, size: job.size, length: job.length, trolley: job.trolley, door: job.door })
        // MP freemode peds start dressed (the Casual preset) so they are never blank.
        if (job.kind === 'npc' && isFreemode(job.model)) obj.appearance = defaultAppearance(job.model)
        setDef((def) => ({ ...def, objects: [...def.objects, obj] }))
        setSelId(obj.id)
      }
    }
    window.addEventListener('npv:placement', onPlaced)
    return () => window.removeEventListener('npv:placement', onPlaced)
  }, [patchObject, setDef])

  const startPlace = useCallback(async (spec) => {
    if (!draft) return toast('Open a scenario first', 'warn')
    const lim = session.limits
    const def = draft.definition
    if (!spec.moveId && spec.kind !== 'patrol') {
      if (def.objects.length >= lim.ObjectsPerScenario) return toast('Object limit reached for this scenario', 'error')
      if (spec.kind === 'npc' && def.objects.filter((o) => o.kind === 'npc').length >= lim.PeoplePerScenario) return toast('People limit reached for this scenario', 'error')
    }
    const res = await client('editor.place', { kind: spec.kind, model: spec.model, size: spec.size, length: spec.length, world: spec.world })
    if (!res.ok || res.data?.ok === false) return toast(errorText(res.data?.error || res.error), 'error')
    pending.current = spec
  }, [draft, session.limits, toast])

  // ---- scenario list actions ------------------------------------------------------------------------
  const create = useCallback(async (name, definition) => {
    const res = await rpc('dm.create', { name })
    if (!res.ok) { toast(errorText(res.error), 'error'); return null }
    if (definition) {
      const s = await rpc('dm.save', { id: res.data.id, name, definition })
      if (!s.ok) toast(errorText(s.error), 'error')
    }
    await refresh()
    await openScenario(res.data.id)
    return res.data.id
  }, [refresh, openScenario, toast])

  const toggleLive = useCallback(async (s) => {
    if (draft?.id === s.id && dirty && s.status !== 'live') { toast('Save your changes first — Spawn uses the saved version', 'warn'); return }
    const res = await rpc('dm.setLive', { id: s.id, live: s.status !== 'live' })
    if (!res.ok) return toast(errorText(res.error), 'error')
    toast(s.status === 'live' ? 'Scenario disabled' : 'Scenario is live', 'ok')
    refresh()
    if (draft?.id === s.id) setDraft((d) => ({ ...d, status: s.status === 'live' ? 'draft' : 'live' }))
  }, [draft, dirty, refresh, toast])

  const duplicate = useCallback(async (s) => {
    const res = await rpc('dm.duplicate', { id: s.id })
    if (!res.ok) return toast(errorText(res.error), 'error')
    toast('Duplicated', 'ok'); refresh()
  }, [refresh, toast])

  const remove = useCallback(async (s) => {
    const yes = await confirm({ title: 'Delete scenario', body: `Delete “${s.name}”? Its placed objects, scripts and dialogue are removed for good.`, confirmLabel: 'Delete', danger: true })
    if (!yes) return
    const res = await rpc('dm.delete', { id: s.id })
    if (!res.ok) return toast(errorText(res.error), 'error')
    if (draft?.id === s.id) { setDraft(null); setSaved(''); client('editor.stop') }
    toast('Deleted', 'ok'); refresh()
  }, [confirm, draft, refresh, toast])

  const importById = useCallback(async (number) => {
    const res = await rpc('dm.import', { number })
    if (!res.ok) return toast(errorText(res.error), 'error')
    toast('Imported as a new draft', 'ok'); refresh()
  }, [refresh, toast])

  // Escape order: nudge/peek -> editors are full-screen and register their own handlers.
  useEscape(() => {
    if (peek) { setPeek(false); return true }
    return false
  }, visible && peek)

  const liveInList = draft && list.find((s) => s.id === draft.id)?.status === 'live'
  const view = { ...draft, status: liveInList ? 'live' : 'draft' }

  if (!visible) return null

  return (
    <div className={`dm ${peek ? 'peek' : ''} ${dressing ? 'appedit' : ''}`}>
      <div className="scrim" />
      {!peek && (
        <>
          <div className="topbar">
            <button className={tab === 'builder' ? 'on' : ''} onClick={() => setTab('builder')}>Scenario builder</button>
            <button className={tab === 'actions' ? 'on' : ''} onClick={() => setTab('actions')}>DM actions</button>
          </div>
          <div className="toprt">
            <button className={advanced ? 'on' : ''} onClick={toggleAdvanced}><Icon name="code" size={15} /> Advanced</button>
            <button className={labels ? 'on' : ''} onClick={() => setLabels((l) => !l)}><Icon name="eye" size={15} /> Labels</button>
            <button disabled={!draft} onClick={() => setPeek(true)} title="Hide the menu to see the world and nudge the selected object"><Icon name="move" size={15} /> Build</button>
            <button onClick={() => closeUi()}><Icon name="close" size={15} /></button>
          </div>
        </>
      )}

      {!peek && tab === 'builder' && (
        <div className="dm-body">
          <ScenarioList
            list={list} loading={loading} currentId={draft?.id} canPublish={has('dm.publish')}
            onOpen={openScenario} onCreate={create} onImport={importById} onToggleLive={toggleLive}
            onDuplicate={duplicate} onDelete={remove} onOpenReady={() => setReadyOpen(true)}
          />
          <ScenarioEditor
            draft={draft ? view : null} dirty={dirty} summary={summary} limits={session.limits} catalog={session.catalog}
            advanced={advanced} selId={selId} setSelId={setSelId}
            onRename={(name) => setDraft((d) => ({ ...d, name }))}
            onPatch={patchObject} onRemove={removeObject} setDef={setDef}
            onPlace={startPlace} onSave={save} onRevert={revert} onClose={closeDraft}
            onOpenScripts={() => setScriptsOpen(true)} onOpenDialogue={(id) => setDialogueFor(id)} onDress={(id) => setDressing(id)}
          />
        </div>
      )}

      {!peek && tab === 'actions' && <DmActions className="dm-body actions" session={session} />}

      {peek && draft && <NudgeBar draft={draft} selId={selId} onPatch={patchObject} onBack={() => setPeek(false)} onPlace={startPlace} />}

      {dressing && draft && (() => {
        const npc = draft.definition.objects.find((o) => o.id === dressing)
        return npc ? <AppearancePanel npc={npc} onChange={(appearance) => patchObject(npc.id, { appearance })} onClose={() => setDressing(null)} /> : null
      })()}

      {readyOpen && (
        <ReadyMade onClose={() => setReadyOpen(false)} onPlace={async (t) => {
          const res = await client('coords.get', { mode: 'stand' })
          if (!res.ok || !res.data) { toast('Could not read where you are standing', 'error'); return false }
          return !!(await create(t.name, t.build(res.data)))
        }} />
      )}

      {scriptsOpen && draft && (
        <ScriptEditor definition={draft.definition} setDef={setDef} title={draft.name} scenarioId={draft.id} live={!!liveInList} scenarioDirty={dirty}
          advanced={advanced} onToggleAdvanced={toggleAdvanced} focusObject={selId} onClose={() => setScriptsOpen(false)} />
      )}
      {dialogueFor && draft && (() => {
        const obj = draft.definition.objects.find((o) => o.id === dialogueFor)
        return obj ? (
          <DialogueEditor npc={obj} roles={session.catalog.roles} onChange={(patch) => patchObject(obj.id, patch)} onClose={() => setDialogueFor(null)} />
        ) : null
      })()}
    </div>
  )
}

/** "Build" mode: menu hidden so the world is visible; nudge the selected object with buttons. */
function NudgeBar({ draft, selId, onPatch, onBack, onPlace }) {
  const [step, setStep] = useState(0.25)
  const obj = draft.definition.objects.find((o) => o.id === selId)
  const move = (axis, dir) => onPatch(selId, (o) => ({ coords: { ...o.coords, [axis]: +(o.coords[axis] + dir * (axis === 'h' ? step * 20 : step)).toFixed(3) } }))
  const ground = async () => {
    if (!obj) return
    const r = await client('coords.ground', { x: obj.coords.x, y: obj.coords.y, z: obj.coords.z })
    if (r.ok && typeof r.data === 'number') onPatch(selId, (o) => ({ coords: { ...o.coords, z: +r.data.toFixed(3) } }))
  }
  return (
    <div className="nudge">
      <span className="display" style={{ fontSize: 18 }}>{obj ? obj.label : 'Nothing selected'}</span>
      <div className="grp"><span className="lbl">Step</span>
        {[0.05, 0.25, 1, 5].map((s) => <button key={s} className={`btn sm ${step === s ? 'active' : ''}`} onClick={() => setStep(s)}>{s}</button>)}
      </div>
      {obj && (
        <>
          {[['x', 'X'], ['y', 'Y'], ['z', 'Z'], ['h', 'Rot']].map(([ax, lb]) => (
            <div className="grp" key={ax}><span className="lbl">{lb}</span>
              <button className="btn sm" onClick={() => move(ax, -1)}>−</button>
              <button className="btn sm" onClick={() => move(ax, 1)}>+</button>
            </div>
          ))}
          <button className="btn sm" onClick={ground}>Ground</button>
          <button className="btn sm" onClick={() => onPlace({ kind: obj.kind, model: obj.model, size: obj.size, moveId: obj.id, world: obj.world })}>Re-aim</button>
        </>
      )}
      <button className="btn sm accent" onClick={onBack}>Show menu</button>
    </div>
  )
}
