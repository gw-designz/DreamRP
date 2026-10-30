import { useEffect, useState } from 'react'
import { useApp } from '../../AppContext.jsx'
import { Icon, NumberInput, Segmented, Toggle } from '../../components/ui.jsx'
import { client } from '../../services/nui.js'
import { KIND_LABEL, uid } from './model.js'
import { useItems } from './useItems.js'
import { defaultAppearance, isFreemode } from './appearance.js'

const CHATTER = [{ value: 0, label: 'Off' }, { value: 1, label: 'Rare' }, { value: 2, label: 'Sometimes' }, { value: 3, label: 'Often' }]

function AnimPicker({ anims, value, onPreview, onSave, onCancel }) {
  const groups = [...new Set(anims.map((a) => a.group))]
  const [pick, setPick] = useState(value)
  useEffect(() => { onPreview(pick) }, [pick]) // eslint-disable-line react-hooks/exhaustive-deps
  return (
    <div className="props">
      <h3 className="display">NPC animation</h3>
      <div className="sub">Click to preview in the world · Save to keep</div>
      <button className={`btn block ${pick === '' ? 'accent' : ''}`} style={{ marginBottom: 10 }} onClick={() => setPick('')}>None (standing)</button>
      {groups.map((g) => (
        <div key={g}>
          <div className="label" style={{ margin: '12px 0 4px' }}>{g}</div>
          <div className="anims">
            {anims.filter((a) => a.group === g).map((a) => (
              <button key={a.id} className={pick === a.id ? 'on' : ''} onClick={() => setPick(a.id)}>▸ {a.label}</button>
            ))}
          </div>
        </div>
      ))}
      <div className="btnrow" style={{ justifyContent: 'flex-end', marginTop: 16 }}>
        <button className="btn" onClick={onCancel}>Cancel</button>
        <button className="btn accent" onClick={() => onSave(pick)}>Save</button>
      </div>
    </div>
  )
}

/** Model field that checks the model exists in the game before accepting it. */
function ModelField({ value, onCommit }) {
  const { toast } = useApp()
  const [text, setText] = useState(value || '')
  useEffect(() => setText(value || ''), [value])
  const commit = async () => {
    const m = text.trim()
    if (!m || m === value) { setText(value || ''); return }
    const res = await client('model.valid', { model: m })
    if (res.ok && res.data === true) onCommit(m)
    else { toast(`Unknown model: ${m}`, 'error'); setText(value || '') }
  }
  return <input className="input sm" value={text} maxLength={60} onChange={(e) => setText(e.target.value.replace(/[^\w]/g, ''))} onBlur={commit} onKeyDown={(e) => e.key === 'Enter' && e.currentTarget.blur()} />
}

/** Starting contents of a storage: item, amount and drop chance. Filled whenever the scenario goes live or loot is refilled. */
function LootEditor({ loot, onChange }) {
  const items = useItems()
  const known = items ? new Map(items.map((i) => [i.name, i.label])) : null
  const patch = (i, p) => onChange(loot.map((e, k) => (k === i ? { ...e, ...p } : e)))
  return (
    <>
      <div className="sect">Contents</div>
      {loot.length === 0 && <small className="hint" style={{ marginTop: 0 }}>Empty. Add items that should be inside when the scenario goes live.</small>}
      {loot.map((e, i) => {
        const unknown = known && known.size > 0 && e.item && !known.has(e.item)
        return (
          <div key={i} className="lootrow">
            <div className="lootitem">
              <input className={`input sm ${unknown ? 'bad' : ''}`} list="npv-items" placeholder="item name" value={e.item} onChange={(ev) => patch(i, { item: ev.target.value.replace(/[^\w-]/g, '') })} />
              <small>{unknown ? 'Not an ox_inventory item' : known?.get(e.item) || ' '}</small>
            </div>
            <NumberInput value={e.count} min={1} max={10000} onChange={(n) => patch(i, { count: n })} />
            <span className="lootchance"><NumberInput value={e.chance ?? 100} min={1} max={100} onChange={(n) => patch(i, { chance: n })} />%</span>
            <button className="btn sm icon danger" aria-label="Remove item" onClick={() => onChange(loot.filter((_, k) => k !== i))}><Icon name="close" size={11} /></button>
          </div>
        )
      })}
      <datalist id="npv-items">{(items || []).map((i) => <option key={i.name} value={i.name}>{i.label}</option>)}</datalist>
      <div className="btnrow">
        <button className="btn sm accent" disabled={loot.length >= 40} onClick={() => onChange([...loot, { item: '', count: 1, chance: 100 }])}><Icon name="plus" size={12} /> Add item</button>
        {loot.length > 0 && <button className="btn sm" onClick={() => onChange([])}>Clear</button>}
      </div>
      <small className="hint">Amount is how many; the % is the chance each entry is put in on every fill. The stash is emptied and refilled each time the scenario goes live, so anything players took comes back.</small>
    </>
  )
}

/** Settings for a grabbable heist trolley: model swap, stacks, timing and exactly what each grab pays. */
function TrolleyEditor({ obj, set, catalog }) {
  const { toast } = useApp()
  const items = useItems()
  const [empty, setEmpty] = useState(obj.emptyModel || '')
  useEffect(() => setEmpty(obj.emptyModel || ''), [obj.emptyModel])
  const r = obj.reward || { mode: 'money', account: 'cash', item: '', min: 1, max: 1 }
  const setReward = (p) => set({ reward: { ...r, ...p } })
  const unknownItem = r.mode === 'item' && r.item && items && items.length > 0 && !items.some((i) => i.name === r.item)
  const commitEmpty = async () => {
    const m = empty.trim()
    if (m === (obj.emptyModel || '')) return
    if (!m) return set({ emptyModel: '' })
    const res = await client('model.valid', { model: m })
    if (res.ok && res.data === true) set({ emptyModel: m })
    else { toast('Unknown model: ' + m, 'error'); setEmpty(obj.emptyModel || '') }
  }
  const money = r.mode === 'money'
  const total = r.max * (obj.stacks || 1)
  return (
    <>
      <div className="sect">Trolley</div>
      <div className="fld"><span className="label">Empty model</span>
        <input className="input sm" value={empty} maxLength={60} placeholder="none — it disappears when empty" onChange={(e) => setEmpty(e.target.value.replace(/[^\w]/g, ''))} onBlur={commitEmpty} onKeyDown={(e) => e.key === 'Enter' && e.currentTarget.blur()} />
        <small>What it turns into once every stack has been taken.</small>
      </div>
      <div className="two">
        <div className="fld"><span className="label">Stacks</span><NumberInput value={obj.stacks || 1} min={1} max={100} onChange={(n) => set({ stacks: n })} /><small>Grabs before it is empty</small></div>
        <div className="fld"><span className="label">Seconds per grab</span><NumberInput value={obj.seconds || 6} min={2} max={30} onChange={(n) => set({ seconds: n })} /></div>
      </div>
      <div className="fld"><span className="label">Prompt</span><input className="input sm" maxLength={40} value={obj.prompt || ''} onChange={(e) => set({ prompt: e.target.value })} /></div>
      <div className="fld"><span className="label">Animation</span>
        <Segmented value={obj.anim || 'cash'} onChange={(v) => set({ anim: v })} options={[{ value: 'cash', label: 'Cash grab' }, { value: 'gold', label: 'Gold / valuables' }]} />
      </div>

      <div className="sect">Reward per grab</div>
      <Segmented value={r.mode} onChange={(v) => setReward({ mode: v })} options={[{ value: 'money', label: 'Money' }, { value: 'item', label: 'Item' }]} />
      {money ? (
        <div className="fld" style={{ marginTop: 10 }}><span className="label">Account</span>
          <select className="select sm" value={r.account} onChange={(e) => setReward({ account: e.target.value })}>
            {(catalog.moneyTypes || ['cash', 'bank']).map((t) => <option key={t} value={t}>{t}</option>)}
          </select>
        </div>
      ) : (
        <div className="fld" style={{ marginTop: 10 }}><span className="label">Item</span>
          <input className={'input sm ' + (unknownItem ? 'bad' : '')} list="npv-items" placeholder="item name, e.g. goldbar" value={r.item} onChange={(e) => setReward({ item: e.target.value.replace(/[^\w-]/g, '') })} />
          <datalist id="npv-items">{(items || []).map((i) => <option key={i.name} value={i.name}>{i.label}</option>)}</datalist>
          <small>{unknownItem ? 'Not an ox_inventory item — nothing would be paid.' : 'Any ox_inventory item.'}</small>
        </div>
      )}
      <div className="two">
        <div className="fld"><span className="label">{money ? 'Minimum ($)' : 'Minimum (amount)'}</span><NumberInput value={r.min} min={0} max={1000000} onChange={(n) => setReward({ min: n, max: Math.max(n, r.max) })} /></div>
        <div className="fld"><span className="label">{money ? 'Maximum ($)' : 'Maximum (amount)'}</span><NumberInput value={r.max} min={0} max={1000000} onChange={(n) => setReward({ max: n, min: Math.min(n, r.min) })} /></div>
      </div>
      <small className="hint">Each grab pays a random {money ? 'amount' : 'number of items'} between the two. A full trolley pays up to {money ? '$' + total.toLocaleString() : total.toLocaleString() + ' items'}. The server decides every payout.</small>
    </>
  )
}

const DIFFICULTIES = [[1, 'Easy'], [2, 'Normal'], [4, 'Hard'], [5, 'Expert']]

/** Minigame + difficulty picker used by both unlock methods. */
function GameFields({ value, onChange, games, allowNone }) {
  const game = value.game || 'skill'
  const skill = game === 'skill'
  return (
    <div className="two">
      <div className="fld"><span className="label">Minigame</span>
        <select className="select sm" value={game} onChange={(e) => {
          const next = e.target.value
          onChange({ game: next, difficulty: next !== 'skill' && value.difficulty === 3 ? 2 : value.difficulty })
        }}>
          {allowNone && <option value="none">None (just plant it)</option>}
          {games.map((g) => <option key={g.id} value={g.id}>{g.label}</option>)}
        </select>
      </div>
      {game !== 'none' && (
        <div className="fld"><span className="label">Difficulty</span>
          <select className="select sm" value={value.difficulty} onChange={(e) => onChange({ difficulty: Number(e.target.value) })}>
            {skill ? [1, 2, 3, 4, 5].map((d) => <option key={d} value={d}>{d}</option>) : DIFFICULTIES.map(([v, l]) => <option key={v} value={v}>{l}</option>)}
          </select>
        </div>
      )}
    </div>
  )
}

/** A locked door: how it swings, and how players can get it open. */
function DoorEditor({ obj, set, catalog }) {
  const items = useItems()
  const games = catalog.hacks?.length ? catalog.hacks : [{ id: 'skill', label: 'Skill check (ox_lib)' }]
  const t = obj.thermite || {}, h = obj.hack || {}
  const setT = (p) => set({ thermite: { ...t, ...p } })
  const setH = (p) => set({ hack: { ...h, ...p } })
  const unknown = (name) => name && items && items.length > 0 && !items.some((i) => i.name === name)
  return (
    <>
      <datalist id="npv-items">{(items || []).map((i) => <option key={i.name} value={i.name}>{i.label}</option>)}</datalist>
      <div className="sect">Door</div>
      <div className="two">
        <div className="fld"><span className="label">Swings open by (degrees)</span><NumberInput value={obj.openAngle ?? 90} min={-180} max={180} onChange={(n) => set({ openAngle: n })} /><small>{(obj.openDir || 'toward') === 'fixed' ? 'A minus number swings it the other way.' : 'How far it swings.'}</small></div>
        <div className="fld"><span className="label">Locks again after (sec)</span><NumberInput value={obj.relock || 0} min={0} max={3600} onChange={(n) => set({ relock: n })} /><small>0 = stays open until reset.</small></div>
      </div>

      {(
        <div className="fld"><span className="label">Swing direction</span>
          <Segmented value={obj.openDir || 'toward'} onChange={(v) => set({ openDir: v })} options={[{ value: 'toward', label: 'Toward the player' }, { value: 'away', label: 'Away from them' }, { value: 'fixed', label: 'Fixed' }]} />
          <small>Toward / away is worked out from where the player who unlocked it stands. Fixed always uses the angle above.</small>
        </div>
      )}

      <div className="sect">Thermite</div>
      <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}><Toggle on={t.enabled !== false} onChange={(v) => setT({ enabled: v })} label="Players can burn through it with thermite" /><span>Players can burn through it with thermite</span></div>
      {t.enabled !== false && (
        <>
          <div className="two" style={{ marginTop: 8 }}>
            <div className="fld"><span className="label">Item used up</span>
              <input className={'input sm ' + (unknown(t.item) ? 'bad' : '')} list="npv-items" placeholder="none needed" value={t.item || ''} onChange={(e) => setT({ item: e.target.value.replace(/[^\w-]/g, '') })} />
              <small>{unknown(t.item) ? 'Not an ox_inventory item.' : 'Taken when they plant it. Empty = free.'}</small>
            </div>
            <div className="fld"><span className="label">Burn time (sec)</span><NumberInput value={t.burn ?? 10} min={3} max={60} onChange={(n) => setT({ burn: n })} /></div>
          </div>
          <GameFields value={t} onChange={setT} games={games} allowNone />
        </>
      )}

      <div className="sect">Hack</div>
      <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}><Toggle on={h.enabled !== false} onChange={(v) => setH({ enabled: v })} label="Players can hack the door panel" /><span>Players can hack the door panel</span></div>
      {h.enabled !== false && (
        <>
          <div className="fld" style={{ marginTop: 8 }}><span className="label">Item needed</span>
            <input className={'input sm ' + (unknown(h.item) ? 'bad' : '')} list="npv-items" placeholder="none needed" value={h.item || ''} onChange={(e) => setH({ item: e.target.value.replace(/[^\w-]/g, '') })} />
            <small>{unknown(h.item) ? 'Not an ox_inventory item.' : 'They must carry it, but it is not used up. Empty = no item needed.'}</small>
          </div>
          <GameFields value={h} onChange={setH} games={games} />
        </>
      )}
      {t.enabled === false && h.enabled === false && <small className="hint">With both switched off the door only opens from a script ("Open / close door") or by staff.</small>}
      <small className="hint">The "When a door is unlocked" script trigger runs whenever it opens.</small>
    </>
  )
}

export default function Properties({ obj, catalog, advanced, onPatch, onRemove, onPlace, onOpenDialogue, onOpenScripts, onDress, setDef, onClose }) {
  const { toast } = useApp()
  const [animOpen, setAnimOpen] = useState(false)
  const [original, setOriginal] = useState('')
  useEffect(() => setAnimOpen(false), [obj?.id])

  if (!obj) return <div className="props"><div className="mutedbox">Select an item from the list to edit it.</div></div>
  const set = (patch) => onPatch(obj.id, patch)
  const setCoord = (k, v) => set((o) => ({ coords: { ...o.coords, [k]: v } }))

  if (animOpen) {
    return (
      <AnimPicker
        anims={catalog.anims} value={obj.anim || ''}
        onPreview={(id) => set({ anim: id })}
        onSave={() => setAnimOpen(false)}
        onCancel={() => { set({ anim: original }); setAnimOpen(false) }}
      />
    )
  }

  const duplicate = () => {
    const copy = { ...structuredClone(obj), id: uid(), label: `${obj.label} copy`, coords: { ...obj.coords, x: +(obj.coords.x + 1).toFixed(3) } }
    setDef((def) => ({ ...def, objects: [...def.objects, copy] }))
  }
  const ground = async () => {
    const r = await client('coords.ground', { x: obj.coords.x, y: obj.coords.y, z: obj.coords.z })
    if (r.ok && typeof r.data === 'number') setCoord('z', +r.data.toFixed(3))
  }
  const goTo = async () => {
    const r = await client('teleport.self', obj.coords)
    if (!r.ok || r.data !== true) toast('Could not teleport', 'error')
  }
  const bring = async () => {
    const r = await client('coords.get', { mode: 'stand' })
    if (r.ok && r.data) set({ coords: { ...r.data, h: obj.coords.h } })
  }
  const hasDialogue = !!obj.dialogue
  const animLabel = catalog.anims.find((a) => a.id === obj.anim)?.label || 'None (standing)'
  const patrol = obj.patrol || []

  return (
    <div className="props">
      <div className="rowf">
        <div>
          <h3 className="display">{obj.label}</h3>
          <div className="sub">{KIND_LABEL[obj.kind]}{obj.world ? ' · existing map door' : obj.model ? ` · ${obj.model}` : ''}</div>
        </div>
        <button className="btn sm icon" onClick={onClose} aria-label="Deselect"><Icon name="close" size={14} /></button>
      </div>

      <div className="actrow">
        <button className="btn sm" onClick={goTo}><Icon name="play" size={12} /> Go to</button>
        {!obj.world && <button className="btn sm" onClick={bring}><Icon name="down" size={12} /> Bring</button>}
        <button className="btn sm accent" onClick={() => onPlace({ kind: obj.kind, model: obj.model, size: obj.size, length: obj.length, moveId: obj.id, world: obj.world })}><Icon name="move" size={12} /> {obj.world ? 'Pick again' : 'Move'}</button>
        {!obj.world && <button className="btn sm" onClick={duplicate}><Icon name="copy" size={12} /> Copy</button>}
        <button className="btn sm danger" onClick={() => onRemove(obj.id)}><Icon name="close" size={12} /> Delete</button>
      </div>

      <div className="sect">Setup</div>
      {obj.kind !== 'trigger' && obj.kind !== 'rope' && !obj.world && (
        <div className="fld"><span className="label">Model</span>
          <ModelField value={obj.model} onCommit={(m) => set({ model: m, ...(obj.kind === 'npc' && isFreemode(m) && !obj.appearance ? { appearance: defaultAppearance(m) } : {}) })} />
          <small>Any valid model name. It is checked against the game before it is accepted.</small>
        </div>
      )}
      <div className="fld"><span className="label">Name</span>
        <input className="input sm" maxLength={60} value={obj.label} onChange={(e) => set({ label: e.target.value })} />
        <small>Shown on world labels and in conversations.</small>
      </div>

      {obj.kind === 'npc' && (
        <>
          <div className="fld"><span className="label">Role</span>
            <input className="input sm" maxLength={60} value={obj.role || ''} placeholder="Shown under the name when players talk to it" onChange={(e) => set({ role: e.target.value })} />
          </div>
          <div className="fld rowf"><div><span className="label">Conversation</span><small>Branching dialogue tree</small></div>
            <button className="btn sm accent" onClick={() => onOpenDialogue(obj.id)}>{hasDialogue ? 'Edit' : 'Create'}</button>
          </div>
          {hasDialogue && <button className="btn sm danger" onClick={() => set({ dialogue: null })}>Remove conversation</button>}
          <div className="fld rowf"><div><span className="label">Appearance</span><small>{isFreemode(obj.model) ? 'Clothing, face, hair and look' : 'Only MP freemode peds (mp_m_freemode_01 / mp_f_freemode_01) can be dressed'}</small></div>
            {isFreemode(obj.model) && <button className="btn sm accent" onClick={() => onDress(obj.id)}><Icon name="user" size={12} /> Dress</button>}
          </div>
          <div className="fld"><span className="label">Idle</span>
            <button className="select" style={{ textAlign: 'left', height: 32 }} onClick={() => { setOriginal(obj.anim || ''); setAnimOpen(true) }}>{animLabel}</button>
          </div>

          <div className="sect">AI behaviour</div>
          <Segmented value={obj.ai || 'statue'} onChange={(v) => set({ ai: v })} options={[{ value: 'npc', label: 'AI NPC' }, { value: 'statue', label: 'Statue' }]} />
          <small className="hint">A statue stands where it was put, does its idle and can be talked to. It never fights. An AI NPC reacts to the world like a normal ped.</small>

          <div className="sect">Voice</div>
          <div className="fld"><span className="label">Voice</span>
            <input className="input sm" maxLength={40} value={obj.voice || ''} placeholder="Automatic" onChange={(e) => set({ voice: e.target.value.replace(/[^\w]/g, '') })} />
            <small>A GTA voice name, or empty for the model’s own.</small>
          </div>
          <Segmented value={obj.greet ? 'greet' : 'none'} onChange={(v) => set({ greet: v === 'greet' })} options={[{ value: 'greet', label: 'Greets players' }, { value: 'none', label: 'No greeting' }]} />
          <div className="fld" style={{ marginTop: 12 }}><span className="label">Chatter</span>
            <Segmented value={obj.chatter || 0} onChange={(v) => set({ chatter: v })} options={CHATTER} />
          </div>
          <Segmented value={obj.chatNpcs === false ? 'alone' : 'npcs'} onChange={(v) => set({ chatNpcs: v === 'npcs' })} options={[{ value: 'npcs', label: 'Chats with NPCs' }, { value: 'alone', label: 'Talks alone' }]} />
          <small className="hint">Greetings play when a player walks up (never from hostile NPCs). Chatter is the odd idle line; “chats with NPCs” only speaks when another ped is standing next to it.</small>

          <div className="sect">Patrol</div>
          {patrol.length === 0 && <small className="hint" style={{ marginTop: 0 }}>No route: it stands at its place. Add at least two points to make it walk a loop.</small>}
          {patrol.map((p, i) => (
            <div key={i} className="pt"><span>{i + 1}</span><span className="muted">{p.x.toFixed(1)}, {p.y.toFixed(1)}</span>
              <button className="btn sm icon danger" onClick={() => set({ patrol: patrol.filter((_, k) => k !== i) })} aria-label="Remove point"><Icon name="close" size={11} /></button>
            </div>
          ))}
          <div className="btnrow">
            <button className="btn sm accent" disabled={patrol.length >= 12} onClick={() => onPlace({ kind: 'patrol', patrolFor: obj.id })}><Icon name="target" size={12} /> Add patrol point</button>
            {patrol.length > 0 && <button className="btn sm" onClick={() => set({ patrol: [] })}>Clear route</button>}
          </div>
        </>
      )}

      {obj.kind === 'trigger' && (
        <div className="fld"><span className="label">Size (m)</span>
          <div className="two" style={{ gridTemplateColumns: 'repeat(3, 1fr)' }}>
            {[['x', 'Width'], ['y', 'Depth'], ['z', 'Height']].map(([k, l]) => (
              <div key={k}><small style={{ margin: '0 0 2px' }}>{l}</small><NumberInput value={obj.size[k]} min={0.5} max={k === 'z' ? 50 : 100} onChange={(n) => set({ size: { ...obj.size, [k]: n } })} /></div>
            ))}
          </div>
        </div>
      )}

      {obj.kind === 'trolley' && <TrolleyEditor obj={obj} set={set} catalog={catalog} />}

      {obj.kind === 'door' && <DoorEditor obj={obj} set={set} catalog={catalog} />}

      {obj.kind === 'rope' && (
        <>
          <div className="fld"><span className="label">Rope length (m)</span><NumberInput value={obj.length || 20} min={3} max={150} onChange={(n) => set({ length: n })} />
            <small>The rope hangs straight down from this point. Players land at the ground or the end of the rope.</small></div>
          <div className="fld"><span className="label">Prompt</span><input className="input sm" maxLength={40} value={obj.prompt || ''} onChange={(e) => set({ prompt: e.target.value })} /></div>
          <small className="hint">Rappel with S (down), W (up) and Backspace (let go). Point the rope's heading the way the player should face (toward the wall).</small>
        </>
      )}

      {obj.kind === 'interactive' && (
        <>
          <div className="fld"><span className="label">Prompt</span><input className="input sm" maxLength={40} value={obj.prompt || ''} onChange={(e) => set({ prompt: e.target.value })} /><small>The text shown on the interaction.</small></div>
          <div className="fld"><span className="label">Cooldown (s)</span><NumberInput value={obj.cooldown || 0} min={0} max={3600} onChange={(n) => set({ cooldown: n })} /></div>
        </>
      )}

      {obj.kind === 'storage' && (
        <>
          <div className="fld"><span className="label">Slots / weight (g)</span>
            <div className="two"><NumberInput value={obj.slots || 30} min={1} max={100} onChange={(n) => set({ slots: n })} /><NumberInput value={obj.weight || 50000} min={1000} max={500000} onChange={(n) => set({ weight: n })} /></div>
            <small>Needs ox_inventory. Players open it with the interact key; scripts can lock it.</small>
          </div>
          <LootEditor loot={obj.loot || []} onChange={(loot) => set({ loot })} />
        </>
      )}

      {advanced && (
        <div className="fld rowf"><div><span className="label">Scripts</span><small>What happens when this is used</small></div>
          <button className="btn sm" onClick={onOpenScripts}><Icon name="code" size={13} /> Scripts</button>
        </div>
      )}

      <div className="sect">Position</div>
      <div className="four">
        {[['x', 'X'], ['y', 'Y'], ['z', 'Z'], ['h', 'Heading']].map(([k, l]) => (
          <div key={k}><small style={{ margin: '0 0 2px', display: 'block' }}>{l}</small><NumberInput value={obj.coords[k]} step={0.1} onChange={(n) => setCoord(k, n)} /></div>
        ))}
      </div>
      <div className="btnrow"><button className="btn sm" onClick={ground}>Snap to ground</button></div>
    </div>
  )
}
