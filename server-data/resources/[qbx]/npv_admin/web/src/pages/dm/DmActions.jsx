import { useCallback, useEffect, useState } from 'react'
import { useApp } from '../../AppContext.jsx'
import { Icon, NumberInput } from '../../components/ui.jsx'
import { client, errorText, rpc } from '../../services/nui.js'

// Parameter kinds: text | number | slider { min, max, step, unit } | chips { options }
const secs = (def = 5, max = 30) => ({ name: 'seconds', type: 'number', label: 'Seconds', min: 1, max, default: def })

const GROUPS = [
  { id: 'Story & Screen', color: 'var(--g-player)', actions: [
    { id: 'narrate', label: 'Narrate', icon: 'message', desc: 'A line of story across the bottom of their screen.', params: [{ name: 'text', type: 'text', label: 'Text', max: 200 }, secs(6)] },
    { id: 'flash', label: 'Flash', icon: 'sun', desc: 'A white flash, like a flashbang.', params: [] },
    { id: 'black_screen', label: 'Black screen', icon: 'box', desc: 'Their screen goes black, then fades back.', params: [secs(4)] },
    { id: 'blur', label: 'Blur', icon: 'eye', desc: 'Their sight goes blurry for a moment.', params: [secs(5)] },
    { id: 'shake', label: 'Shake', icon: 'bolt', desc: 'Shakes their camera, like a blast nearby.', params: [secs(3)] },
    { id: 'sound', label: 'Sound', icon: 'speaker', desc: 'Plays a sound or an alarm at the spot.', params: [{ name: 'sound', type: 'chips', label: 'Sound', default: 'alarm', options: [['alarm', 'Alarm'], ['beep', 'Beep'], ['ding', 'Ding'], ['wasted', 'Wasted']] }] },
  ] },
  { id: 'Players', color: 'var(--accent)', actions: [
    { id: 'knock_down', label: 'Knock down', icon: 'walk', desc: 'They fall over for a few seconds.', params: [secs(5)] },
    { id: 'freeze', label: 'Freeze', icon: 'lock', desc: 'Stops them moving, or lets them go again.', params: [secs(10, 300)] },
    { id: 'bring_to_me', label: 'Bring to me', icon: 'pin', desc: 'Moves them to where you stand.', params: [] },
    { id: 'revive', label: 'Revive', icon: 'heart', desc: 'Brings them back if they are down.', params: [] },
    { id: 'heal', label: 'Heal', icon: 'heart', desc: 'Full health.', params: [] },
    { id: 'give_item', label: 'Give item', icon: 'gift', desc: 'Puts an item in their pockets.', params: [{ name: 'item', type: 'text', label: 'Item name', max: 50 }, { name: 'count', type: 'number', label: 'Amount', min: 1, max: 1000, default: 1 }] },
  ] },
  { id: 'World', color: 'var(--g-control)', actions: [
    { id: 'lightning', label: 'Lightning', icon: 'bolt', desc: 'A lightning strike over the whole city.', params: [] },
    { id: 'blackout', label: 'Blackout', icon: 'sun', desc: 'City lights off for some minutes (0 ends it). Car lights stay on.', params: [{ name: 'minutes', type: 'number', label: 'Minutes', min: 0, max: 30, default: 2 }] },
    { id: 'police_alert', label: 'Police alert', icon: 'alert', desc: 'Sends a call to police at the spot.', params: [{ name: 'text', type: 'text', label: 'Message', max: 100 }] },
    { id: 'spawn_vehicle', label: 'Spawn vehicle', icon: 'car', desc: 'A vehicle at the spot.', params: [{ name: 'model', type: 'text', label: 'Model', max: 40 }] },
    { id: 'clear_area', label: 'Clear the area', icon: 'trash', desc: 'Removes cars and people around the spot. Players and the cars they sit in stay.', params: [{ name: 'radius', type: 'slider', label: 'Radius', min: 2, max: 100, step: 1, default: 20, unit: 'm' }] },
  ] },
  { id: 'Danger', color: 'var(--g-npc)', actions: [
    { id: 'explosion', label: 'Explosion', icon: 'bolt', desc: 'One or more blasts at the spot.', params: [
      { name: 'kind', type: 'chips', label: 'Kind', default: 'grenade', options: [['grenade', 'Grenade'], ['molotov', 'Molotov'], ['rocket', 'Rocket'], ['car_blast', 'Car blast'], ['flame_jet', 'Flame jet'], ['water_jet', 'Water jet'], ['smoke', 'Smoke'], ['tear_gas', 'Tear gas'], ['flare', 'Flare'], ['gas_tank', 'Gas tank']] },
      { name: 'size', type: 'slider', label: 'Size', min: 0.1, max: 3, step: 0.1, default: 1 },
      { name: 'count', type: 'slider', label: 'How many', min: 1, max: 10, step: 1, default: 1 },
      { name: 'spread', type: 'slider', label: 'Spread', min: 0, max: 20, step: 1, default: 2, unit: 'm' },
    ] },
    { id: 'fire', label: 'Fire', icon: 'flame', desc: 'Starts a fire that spreads by itself.', params: [] },
  ] },
  { id: 'NPC waves', color: 'var(--ok)', actions: [
    { id: 'npc_wave', label: 'NPC wave', icon: 'skull', desc: 'A group of armed NPCs that go for the nearest player.', params: [
      { name: 'model', type: 'chips', label: 'Who', default: 'gang', options: [['gang', 'Gang'], ['cartel', 'Cartel'], ['swat', 'SWAT'], ['cop', 'Cops']] },
      { name: 'weapon', type: 'chips', label: 'Weapon', default: 'pistol', options: [['pistol', 'Pistol'], ['smg', 'SMG'], ['shotgun', 'Shotgun'], ['rifle', 'Rifle']] },
      { name: 'count', type: 'slider', label: 'How many', min: 1, max: 10, step: 1, default: 3 },
      { name: 'spread', type: 'slider', label: 'Spread', min: 1, max: 20, step: 1, default: 5, unit: 'm' },
    ] },
    { id: 'clear_waves', label: 'Clear waves', icon: 'close', desc: 'Removes every NPC wave at once.', params: [] },
  ] },
]

const ALL = GROUPS.flatMap((g) => g.actions.map((a) => ({ ...a, color: g.color })))
// Actions that happen at the spot and do not use the "who it reaches" setting.
const SPOT_ONLY = ['spawn_vehicle', 'police_alert', 'clear_area', 'fire', 'explosion', 'npc_wave', 'clear_waves']

const WHERE = [
  { id: 'stand', label: 'Where I stand', icon: 'pin', hint: 'Runs right where you are standing.' },
  { id: 'waypoint', label: 'My waypoint', icon: 'flag', hint: 'Runs at your map waypoint.' },
  { id: 'aim', label: 'Aim at a spot', icon: 'target', hint: 'Runs where your crosshair points when you press Run.' },
]

const defaultsOf = (a) => Object.fromEntries(a.params.filter((p) => p.default !== undefined).map((p) => [p.name, p.default]))

function Slider({ p, value, onChange }) {
  return (
    <div className="pslider">
      <div className="prow2"><span className="label">{p.label}</span><span className="pval">{value}{p.unit ? ` ${p.unit}` : ''}</span></div>
      <input type="range" min={p.min} max={p.max} step={p.step} value={value} onChange={(e) => onChange(Number(e.target.value))} />
    </div>
  )
}

export default function DmActions({ className }) {
  const { toast } = useApp()
  const [where, setWhere] = useState('stand')
  const [mode, setMode] = useState('near')
  const [radius, setRadius] = useState(30)
  const [target, setTarget] = useState('')
  const [players, setPlayers] = useState([])
  // ?action=explosion preselects a tile (handy for previews; harmless in game).
  const [action, setAction] = useState(() => ALL.find((a) => a.id === new URLSearchParams(window.location.search).get('action')) || ALL[0])
  const [values, setValues] = useState(() => defaultsOf(ALL.find((a) => a.id === new URLSearchParams(window.location.search).get('action')) || ALL[0]))
  const [running, setRunning] = useState([])
  const [busy, setBusy] = useState(false)
  const [lastSpot, setLastSpot] = useState(null)

  useEffect(() => {
    let alive = true
    const load = async () => {
      const [p, r] = await Promise.all([rpc('players.list'), rpc('dm.running')])
      if (!alive) return
      if (p.ok) setPlayers(p.data)
      if (r.ok) setRunning(r.data)
    }
    load()
    const t = setInterval(load, 2000)
    return () => { alive = false; clearInterval(t) }
  }, [])

  const pick = (a) => { setAction(a); setValues(defaultsOf(a)) }
  const set = (name, v) => setValues((s) => ({ ...s, [name]: v }))

  const needsWho = !SPOT_ONLY.includes(action.id)
  const reaches = mode === 'near' ? `Players near · ${radius} m` : mode === 'one' ? 'One player' : 'Everyone'
  const ready = action.params.every((p) => p.type !== 'text' || (values[p.name] || '').trim()) && (mode !== 'one' || !needsWho || target)

  const run = useCallback(async () => {
    setBusy(true)
    const c = await client('coords.get', { mode: where })
    if (!c.ok || !c.data) { setBusy(false); return toast(where === 'waypoint' ? 'Set a waypoint on the map first' : 'Could not read the position', 'error') }
    setLastSpot(c.data)
    const res = await rpc('dm.action', { action: action.id, coords: c.data, who: { mode, radius, target: target ? Number(target) : undefined }, params: values })
    setBusy(false)
    if (res.ok) toast(res.message || `${action.label} done`, 'ok')
    else toast(errorText(res.error), 'error')
  }, [where, action, mode, radius, target, values, toast])

  return (
    <div className={className}>
      <div className="col da-left">
        <h2 className="display">DM actions</h2>
        <div className="sect"><span className="label">Where</span></div>
        <div className="seg three">
          {WHERE.map((w) => (
            <button key={w.id} className={where === w.id ? 'on' : ''} onClick={() => setWhere(w.id)}><Icon name={w.icon} size={16} />{w.label}</button>
          ))}
        </div>
        <div className="muted" style={{ fontSize: 12, marginTop: 6 }}>{WHERE.find((w) => w.id === where).hint}</div>
        {lastSpot && <div style={{ fontSize: 12, marginTop: 2 }}>Last spot: {lastSpot.x.toFixed(1)}, {lastSpot.y.toFixed(1)}, {lastSpot.z.toFixed(1)}</div>}

        <div className="sect" style={{ marginTop: 22 }}><span className="label">Who it reaches</span></div>
        <div className="whochips">
          {[['near', 'Players near'], ['one', 'One player'], ['everyone', 'Everyone']].map(([id, l]) => <button key={id} className={mode === id ? 'on' : ''} onClick={() => setMode(id)}>{l}</button>)}
        </div>
        {mode === 'one' && (
          <select className="select sm" style={{ marginTop: 8 }} value={target} onChange={(e) => setTarget(e.target.value)}>
            <option value="">Select player…</option>
            {players.map((p) => <option key={p.id} value={p.id}>{`[${p.id}] ${p.name}`}</option>)}
          </select>
        )}
        {mode === 'near' && (
          <div className="sect">
            <div style={{ display: 'flex', justifyContent: 'space-between' }}><span className="label">How far</span><span style={{ color: 'var(--accent)' }} className="display">{radius} m</span></div>
            <input type="range" min={5} max={200} step={5} value={radius} onChange={(e) => setRadius(Number(e.target.value))} style={{ width: '100%', accentColor: 'var(--accent)' }} />
            <div className="muted" style={{ fontSize: 12 }}>Only matters for actions that reach players.</div>
          </div>
        )}

        <div className="sect"><span className="label">Running now</span></div>
        {running.length === 0 && <div className="muted" style={{ fontSize: 13 }}>Nothing running.</div>}
        {running.map((r) => (
          <div key={r.id} className="running"><span>{r.label} · {r.remaining}s</span><button className="btn sm danger" onClick={async () => { await rpc('dm.stopAction', { id: r.id }) }}>Stop</button></div>
        ))}
      </div>

      <div className="col da-mid">
        <div className="lead">Set things off live: pick an action, set it up, choose where and who, then run it.</div>
        {GROUPS.map((g) => (
          <div key={g.id}>
            <div className="gh">{g.id}</div>
            <div className="tiles">
              {g.actions.map((a) => (
                <button key={a.id} className={`tile ${action.id === a.id ? 'on' : ''}`} style={{ '--tc': g.color }} onClick={() => pick({ ...a, color: g.color })}>
                  <span className="ic"><Icon name={a.icon} size={18} /></span>
                  <span><b>{a.label}</b><span>{a.desc}</span></span>
                </button>
              ))}
            </div>
          </div>
        ))}
      </div>

      <div className="col da-right">
        <div className="hd">
          <span className="ic tile" style={{ '--tc': action.color, minHeight: 0, width: 44, height: 44, padding: 0, justifyContent: 'center', alignItems: 'center' }}><Icon name={action.icon} size={20} /></span>
          <div><h2 className="display" style={{ fontSize: 28 }}>{action.label}</h2><div className="muted" style={{ fontSize: 13 }}>{action.desc}</div></div>
        </div>

        {action.params.map((p) => {
          const v = values[p.name] ?? p.default
          if (p.type === 'slider') return <Slider key={p.name} p={p} value={v} onChange={(n) => set(p.name, n)} />
          return (
            <div key={p.name} style={{ marginBottom: 12 }}>
              <div style={{ display: 'flex', justifyContent: 'space-between' }}><span className="label">{p.label}</span>{p.type === 'text' && <span className="muted" style={{ fontSize: 10 }}>{(values[p.name] || '').length}/{p.max}</span>}</div>
              {p.type === 'chips' && (
                <div className="pchips">{p.options.map(([id, l]) => <button key={id} className={v === id ? 'on' : ''} onClick={() => set(p.name, id)}>{l}</button>)}</div>
              )}
              {p.type === 'text' && (action.id === 'narrate'
                ? <textarea className="textarea" rows={4} maxLength={p.max} value={values[p.name] || ''} onChange={(e) => set(p.name, e.target.value)} />
                : <input className="input" maxLength={p.max} value={values[p.name] || ''} onChange={(e) => set(p.name, e.target.value)} />)}
              {p.type === 'number' && <NumberInput className="input" value={v} min={p.min} max={p.max} onChange={(n) => set(p.name, n)} />}
            </div>
          )
        })}

        <div className="summary">
          <div>◎ {WHERE.find((w) => w.id === where).label}</div>
          <div className="muted">{needsWho ? `Reaches: ${reaches}` : 'Happens at the spot'}</div>
        </div>
        <button className="runbtn" disabled={!ready || busy} onClick={run}><Icon name="play" size={18} fill="currentColor" /> Run</button>
      </div>
    </div>
  )
}
