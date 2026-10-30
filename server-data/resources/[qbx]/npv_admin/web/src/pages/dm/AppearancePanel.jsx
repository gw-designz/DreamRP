import { useCallback, useEffect, useRef, useState } from 'react'
import { useApp, useEscape } from '../../AppContext.jsx'
import { Icon, NumberInput, Toggle } from '../../components/ui.jsx'
import { client } from '../../services/nui.js'
import {
  COMPONENTS, EYE_COLORS, FACE_FEATURES, OVERLAYS, PARENTS, PROPS, clone, defaultAppearance, itemName, knownCount, presetsFor,
  randomFace, randomLook,
} from './appearance.js'

const TABS = [
  { id: 'heritage', label: 'Heritage', focus: 'face' },
  { id: 'face', label: 'Face', focus: 'face' },
  { id: 'hair', label: 'Hair & eyes', focus: 'face' },
  { id: 'skin', label: 'Skin', focus: 'face' },
  { id: 'clothing', label: 'Clothing', focus: 'body' },
  { id: 'props', label: 'Props', focus: 'body' },
]

function Slider({ label, min, max, step, value, onChange, hint }) {
  return (
    <div className="aslider">
      <div className="arow"><span className="label">{label}</span><span className="aval">{Number(value).toFixed(step < 1 ? 2 : 0)}</span></div>
      <input type="range" min={min} max={max} step={step} value={value} onChange={(e) => onChange(Number(e.target.value))} />
      {hint && <small>{hint}</small>}
    </div>
  )
}

/** [-] number [+] with an optional readable name under it. */
function Stepper({ label, value, min, max, onChange, name, disabled, format }) {
  const set = (n) => onChange(Math.max(min, Math.min(max, n)))
  return (
    <div className={`astep ${disabled ? 'off' : ''}`}>
      <div className="arow"><span className="label">{label}</span><span className="aname">{name}</span></div>
      <div className="acontrols">
        <button className="btn sm icon" disabled={disabled || value <= min} onClick={() => set(value - 1)}>−</button>
        <NumberInput className="input sm" value={format ? format(value) : value} min={min} max={max} onChange={set} disabled={disabled} />
        <button className="btn sm icon" disabled={disabled || value >= max} onClick={() => set(value + 1)}>+</button>
        <span className="amax">/ {max}</span>
      </div>
    </div>
  )
}

/** Texture stepper that asks the game how many textures the chosen drawable has. */
function TextureStepper({ model, kind, slot, drawable, value, onChange, disabled }) {
  const [count, setCount] = useState(1)
  useEffect(() => {
    let alive = true
    client('appearance.textures', { model, kind, slot, drawable }).then((r) => { if (alive && r.ok && typeof r.data === 'number') setCount(r.data) })
    return () => { alive = false }
  }, [model, kind, slot, drawable])
  return <Stepper label="Texture" value={Math.min(value, count - 1)} min={0} max={Math.max(0, count - 1)} onChange={onChange} disabled={disabled} />
}

export default function AppearancePanel({ npc, onChange, onClose }) {
  const { toast } = useApp()
  const model = npc.model
  const original = useRef(clone(npc.appearance || defaultAppearance(model)))
  const [app, setApp] = useState(original.current)
  // ?amode=editor&atab=clothing opens a view directly (preview only)
  const params = new URLSearchParams(window.location.search)
  const [mode, setMode] = useState(params.get('amode') === 'editor' ? 'editor' : 'quick')
  const [tab, setTab] = useState(TABS.some((t) => t.id === params.get('atab')) ? params.get('atab') : 'heritage')
  const [info, setInfo] = useState(null)
  const drag = useRef(null)
  const lastSend = useRef(0)

  // Every change goes to the draft straight away, so the ped in the world updates live.
  useEffect(() => { onChange(app) }, [app]) // eslint-disable-line react-hooks/exhaustive-deps
  const update = useCallback((fn) => setApp((prev) => fn(clone(prev))), [])

  useEffect(() => {
    client('appearance.info', { model }).then((r) => { if (r.ok && r.data && !r.data.error) setInfo(r.data) })
  }, [model])

  // Camera on the ped while this panel is open.
  useEffect(() => {
    client('appearance.camera', { on: true, id: npc.id, focus: 'body' })
    return () => { client('appearance.camera', { on: false }) }
  }, [npc.id])
  useEffect(() => {
    const t = TABS.find((x) => x.id === tab)
    client('appearance.camera', { id: npc.id, focus: mode === 'quick' ? 'body' : t.focus })
  }, [tab, mode, npc.id])

  const cancel = () => { onChange(original.current); onClose() }
  useEscape(() => { cancel(); return true })

  // ---- camera: drag to rotate, wheel to zoom --------------------------------------------------
  const onDown = (e) => { drag.current = e.clientX }
  const onMove = (e) => {
    if (drag.current == null) return
    const now = performance.now()
    if (now - lastSend.current < 30) return
    lastSend.current = now
    const dx = e.clientX - drag.current
    drag.current = e.clientX
    client('appearance.camera', { id: npc.id, dx })
  }
  const onUp = () => { drag.current = null }
  const onWheel = (e) => client('appearance.camera', { id: npc.id, zoom: e.deltaY > 0 ? 1 : -1 })

  // ---- actions ------------------------------------------------------------------------------------
  const copyFrom = async (call, what) => {
    const r = await client(call)
    const d = r.ok ? r.data : null
    if (!d || d.error || !d.appearance) return toast(d?.error === 'none_nearby' ? 'No MP ped within 12 m' : `${what} is not an MP freemode ped`, 'error')
    if (d.model !== model) return toast(`That look is for ${d.model}; this NPC is ${model}`, 'error')
    setApp({ ...d.appearance, autoTorso: false })
    toast(`Copied ${what.toLowerCase()}`, 'ok')
  }
  const applyPreset = (p) => setApp(clone(p.appearance))

  const limit = (id, key) => info?.drawables?.[String(id)] ?? knownCount(model, key)
  const propLimit = (id, key) => info?.props?.[String(id)] ?? knownCount(model, key)
  const comp = (id) => app.comps[id] || { d: 0, t: 0 }
  const setComp = (id, patch) => update((a) => { a.comps[id] = { ...comp(id), ...patch }; return a })
  const prop = (id) => app.props[id] || { d: -1, t: 0 }
  const setProp = (id, patch) => update((a) => { a.props[id] = { ...prop(id), ...patch }; return a })
  const overlay = (id) => app.overlays[id] || { i: 255, o: 1, c: 0, c2: 0 }
  const setOverlay = (id, patch) => update((a) => { a.overlays[id] = { ...overlay(id), ...patch }; return a })

  const toggleAutoTorso = async (on) => {
    if (on) return update((a) => { a.autoTorso = true; return a })
    // Turning it off: start from the torso the game would have chosen, so the arms stay right.
    let torso
    for (const c of [8, 11]) {
      const r = await client('appearance.forced', { model, comp: c, drawable: comp(c).d, texture: comp(c).t })
      if (r.ok && r.data?.torso != null) torso = r.data.torso
    }
    update((a) => { a.autoTorso = false; a.comps[3] = { d: torso ?? 15, t: 0 }; return a })
  }

  const presets = presetsFor(model)

  // ---- tab contents ---------------------------------------------------------------------------------
  const heritage = (
    <>
      <div className="asect">Parents</div>
      {[['s1', 'Shape — mother'], ['s2', 'Shape — father'], ['k1', 'Skin — mother'], ['k2', 'Skin — father']].map(([k, l]) => (
        <div key={k} className="afield"><span className="label">{l}</span>
          <select className="select sm" value={app.blend[k]} onChange={(e) => update((a) => { a.blend[k] = Number(e.target.value); return a })}>
            {PARENTS.map((n, i) => <option key={i} value={i}>{i} · {n}</option>)}
          </select>
        </div>
      ))}
      <Slider label="Shape mix" min={0} max={1} step={0.01} value={app.blend.sm} hint="0 = first parent, 1 = second" onChange={(v) => update((a) => { a.blend.sm = v; return a })} />
      <Slider label="Skin mix" min={0} max={1} step={0.01} value={app.blend.km} hint="0 = first parent, 1 = second" onChange={(v) => update((a) => { a.blend.km = v; return a })} />
    </>
  )

  const face = (
    <>
      {FACE_FEATURES.map((name, i) => (
        <Slider key={name} label={name} min={-1} max={1} step={0.05} value={app.face[i] ?? 0} onChange={(v) => update((a) => { a.face[i] = v; return a })} />
      ))}
      <button className="btn sm" onClick={() => update((a) => { a.face = Array(20).fill(0); return a })}>Reset face</button>
    </>
  )

  const hair = (
    <>
      <Stepper label="Hair style" value={app.hair.s} min={0} max={Math.max(0, limit(2, 'c2') - 1)} name={itemName(model, 'c2', app.hair.s)} onChange={(v) => update((a) => { a.hair.s = v; return a })} />
      <TextureStepper model={model} kind="comp" slot={2} drawable={app.hair.s} value={app.hair.t} onChange={(v) => update((a) => { a.hair.t = v; return a })} />
      <Stepper label="Hair colour" value={app.hair.c} min={0} max={Math.max(0, (info?.hairColors ?? 64) - 1)} onChange={(v) => update((a) => { a.hair.c = v; return a })} />
      <Stepper label="Highlight colour" value={app.hair.h} min={0} max={Math.max(0, (info?.hairColors ?? 64) - 1)} onChange={(v) => update((a) => { a.hair.h = v; return a })} />
      <div className="afield"><span className="label">Eye colour</span>
        <select className="select sm" value={app.eye} onChange={(e) => update((a) => { a.eye = Number(e.target.value); return a })}>
          {EYE_COLORS.map((n, i) => <option key={n} value={i}>{i} · {n}</option>)}
        </select>
      </div>
    </>
  )

  const skin = (
    <>
      {OVERLAYS.map((o) => {
        const v = overlay(o.id)
        const max = Math.max(0, (info?.overlays?.[String(o.id)] ?? 20) - 1)
        const none = v.i === 255
        return (
          <div key={o.id} className="aoverlay">
            <Stepper label={o.label} value={none ? -1 : v.i} min={-1} max={max} name={none ? 'None' : ''} format={(n) => (n < 0 ? 0 : n)} onChange={(n) => setOverlay(o.id, { i: n < 0 ? 255 : n })} />
            {!none && <Slider label="Opacity" min={0} max={1} step={0.05} value={v.o} onChange={(n) => setOverlay(o.id, { o: n })} />}
            {!none && o.kind && <Stepper label="Colour" value={v.c} min={0} max={Math.max(0, (o.kind === 'hair' ? (info?.hairColors ?? 64) : (info?.makeupColors ?? 64)) - 1)} onChange={(n) => setOverlay(o.id, { c: n })} />}
          </div>
        )
      })}
    </>
  )

  const clothingTab = (
    <>
      <div className="afield row"><div><span className="label">Auto-fit arms</span><small>Lets the game pick the torso that matches the top and undershirt.</small></div><Toggle on={app.autoTorso !== false} onChange={toggleAutoTorso} label="Auto-fit arms" /></div>
      {COMPONENTS.map((c) => {
        const v = comp(c.id)
        const locked = c.id === 3 && app.autoTorso !== false
        return (
          <div key={c.id} className="agroup">
            <Stepper label={c.label} value={v.d} min={0} max={Math.max(0, limit(c.id, c.key) - 1)} name={itemName(model, c.key, v.d)} disabled={locked} onChange={(n) => setComp(c.id, { d: n, t: 0 })} />
            <TextureStepper model={model} kind="comp" slot={c.id} drawable={v.d} value={v.t} disabled={locked} onChange={(n) => setComp(c.id, { t: n })} />
          </div>
        )
      })}
    </>
  )

  const propsTab = (
    <>
      {PROPS.map((p) => {
        const v = prop(p.id)
        return (
          <div key={p.id} className="agroup">
            <Stepper label={p.label} value={v.d} min={-1} max={Math.max(-1, propLimit(p.id, p.key) - 1)} name={v.d < 0 ? 'None' : itemName(model, p.key, v.d)} onChange={(n) => setProp(p.id, { d: n, t: 0 })} />
            {v.d >= 0 && <TextureStepper model={model} kind="prop" slot={p.id} drawable={v.d} value={v.t} onChange={(n) => setProp(p.id, { t: n })} />}
          </div>
        )
      })}
    </>
  )

  const content = { heritage, face, hair, skin, clothing: clothingTab, props: propsTab }[tab]

  return (
    <>
      <div className="adrag" onMouseDown={onDown} onMouseMove={onMove} onMouseUp={onUp} onMouseLeave={onUp} onWheel={onWheel} />
      <div className="ahints"><span><Icon name="move" size={14} /> Rotate</span><span><Icon name="search" size={14} /> Zoom</span></div>

      <div className={`apanel ${mode === 'editor' ? 'wide' : ''}`}>
        <div className="ahead">
          <span className="aicon"><Icon name="user" size={18} /></span>
          <div><div className="display" style={{ fontSize: 22 }}>NPC appearance</div><small className="muted">{npc.label} · {model}</small></div>
          <button className="btn sm icon" onClick={cancel} aria-label="Cancel"><Icon name="close" size={14} /></button>
        </div>

        {mode === 'quick' && (
          <div className="abody">
            <div className="asect">Character look</div>
            <div className="arowbtns">
              <button className="btn sm" onClick={() => copyFrom('appearance.mine', 'My look')}><Icon name="user" size={12} /> Copy my look</button>
              <button className="btn sm" onClick={() => copyFrom('appearance.nearby', 'Nearby ped')}><Icon name="target" size={12} /> Copy nearby ped</button>
              <button className="btn sm" onClick={() => setMode('editor')}><Icon name="gear" size={12} /> Design in editor</button>
            </div>
            <div className="asect">Presets</div>
            <div className="apresets">
              {presets.map((p, n) => <button key={p.id} className="btn sm" title={p.name} onClick={() => applyPreset(p)}>{n} · {p.name}</button>)}
            </div>
          </div>
        )}

        {mode === 'editor' && (
          <>
            <div className="atabs">{TABS.map((t) => <button key={t.id} className={tab === t.id ? 'on' : ''} onClick={() => setTab(t.id)}>{t.label}</button>)}</div>
            <div className="abody">{content}</div>
          </>
        )}

        <div className="afoot">
          {mode === 'editor' && <button className="btn sm" onClick={() => setMode('quick')}>← Back</button>}
          <button className="btn sm" onClick={() => setApp((a) => randomLook(a, model, info))}><Icon name="bolt" size={12} /> Randomise</button>
          <button className="btn sm" onClick={() => setApp((a) => randomFace(a, model))}><Icon name="user" size={12} /> Randomise face</button>
          <span style={{ flex: 1 }} />
          <button className="btn sm" onClick={cancel}>Cancel</button>
          <button className="btn sm accent" onClick={onClose}>Save</button>
        </div>
      </div>
    </>
  )
}
