// DEV ONLY: stands in for the Lua side when the page is opened in a normal browser (vite dev /
// screenshots). It is never used inside FiveM (see inGame in nui.js).
const ok = (data, message) => ({ ok: true, data, message })
const fail = (error) => ({ ok: false, error })
const wait = (ms = 80) => new Promise((r) => setTimeout(r, ms))

const commands = [
  { id: 'admin_mode', label: 'Admin Mode', desc: 'Toggle admin mode for the player', category: 'user', perm: 'self', toggle: true, key: 'L' },
  { id: 'admin_car', label: 'Admin Car', desc: 'Add the vehicle you are in to your garage', category: 'vehicles', perm: 'vehicles' },
  { id: 'dm_tool', label: 'DM Tool', desc: 'Add or remove the DM Tool button in your radial menu', category: 'utility', perm: 'dm', toggle: true },
  { id: 'revive_range', label: 'Revive In Range', desc: 'Revive every player within 10 metres of you.', category: 'players', perm: 'players.heal' },
  { id: 'announce', label: 'Announce', desc: "A message on everyone's screen", category: 'utility', perm: 'players.moderate', args: [{ name: 'message', type: 'text', label: 'Message', max: 200 }, { name: 'seconds', type: 'number', label: 'Seconds', min: 2, max: 30, default: 8 }] },
  { id: 'ban', label: 'Ban Player', desc: 'Ban a player for a while, or for good', category: 'players', perm: 'players.ban', confirm: true, args: [{ name: 'target', type: 'player' }, { name: 'duration', type: 'duration' }, { name: 'reason', type: 'text', label: 'Reason' }] },
  { id: 'bring', label: 'Bring Player', desc: 'Bring a player to you', category: 'players', perm: 'players.teleport', args: [{ name: 'target', type: 'player' }] },
  { id: 'change_model', label: 'Change Model', desc: "Change a player's character model", category: 'players', perm: 'players.moderate', args: [{ name: 'target', type: 'player' }, { name: 'model', type: 'model', label: 'Ped model' }] },
  { id: 'change_my_model', label: 'Change My Model', desc: 'Change your own character model', category: 'user', perm: 'self', args: [{ name: 'model', type: 'model', label: 'Ped model' }] },
  { id: 'clean_vehicle', label: 'Clean Vehicle', desc: 'Wash the vehicle you are in, or the closest one', category: 'utility', perm: 'vehicles' },
  { id: 'clear_area', label: 'Clear Area', desc: 'Remove vehicles, people or objects around you', category: 'utility', perm: 'world', confirm: true, args: [{ name: 'what', type: 'select', label: 'What', options: ['vehicles', 'people', 'objects'], default: 'vehicles' }, { name: 'radius', type: 'number', label: 'Radius (m)', min: 2, max: 100, default: 20 }] },
  { id: 'clear_wanted', label: 'Clear Wanted Level', desc: 'Remove the stars from yourself', category: 'user', perm: 'self' },
  { id: 'cloak', label: 'Cloak', desc: 'Hide yourself from other players', category: 'user', perm: 'self', toggle: true, key: 'DELETE' },
  { id: 'copy_coords', label: 'Copy Coords', desc: 'Copy where you stand, ready to paste', category: 'utility', perm: 'self', args: [{ name: 'format', type: 'select', label: 'Format', options: ['vector4', 'vector3', 'json'], default: 'vector4' }] },
  { id: 'delete_closest_object', label: 'Delete Closest Object', desc: 'Delete the prop nearest to you', category: 'utility', perm: 'world', confirm: true },
  { id: 'noclip', label: 'Noclip', desc: 'Fly through the world', category: 'user', perm: 'self', toggle: true, key: 'F2' },
]

const npcs = [
  ['mp_m_shopkeep_01', 'Shop Clerk', 'Civilians'], ['a_m_y_business_01', 'Business Man', 'Civilians'], ['s_m_y_cop_01', 'Cop', 'Law'],
  ['g_m_y_ballaeast_01', 'Ballas', 'Gangs'], ['g_m_y_famca_01', 'Families', 'Gangs'], ['g_m_y_korean_01', 'Korean Gang', 'Gangs'],
  ['mp_m_freemode_01', 'MP Male', 'Freemode'], ['mp_f_freemode_01', 'MP Female', 'Freemode'], ['g_m_m_armboss_01', 'Armenian Boss', 'Gangs'], ['a_c_shepherd', 'Shepherd Dog', 'Animals'], ['a_c_rottweiler', 'Rottweiler', 'Animals'],
].map(([id, label, group]) => ({ id, label, group }))
const objects = [
  ['prop_box_wood02a_pu', 'Wooden Crate', 'Containers'], ['prop_ld_int_safe_01', 'Safe', 'Containers'], ['prop_barrier_work06a', 'Roadwork Barrier', 'Street'],
  ['prop_bench_01a', 'Bench', 'Street'], ['prop_laptop_01a', 'Laptop', 'Electronics'], ['prop_money_bag_01', 'Money Bag', 'Loot'],
].map(([id, label, group]) => ({ id, label, group }))
const anims = [
  ['Idle', 'impatient', 'Impatient'], ['Idle', 'phone', 'On Phone'], ['Idle', 'hangout', 'Hang Out'], ['Idle', 'map', 'Reading Map'],
  ['Leisure', 'smoking', 'Smoking'], ['Leisure', 'drinking', 'Drinking'], ['Work', 'clipboard', 'Clipboard'], ['Guard', 'guard', 'Guard (Arms Crossed)'],
].map(([group, id, label]) => ({ group, id, label }))

const session = {
  rank: { name: 'owner', label: 'Owner', level: 100 }, perms: ['*'], commands, id: 1, name: 'Dev',
  catalog: { doors: { MaxDistance: 6, Thermite: { item: 'thermite', burn: 10, game: 'skill', difficulty: 3 }, Hack: { item: '', game: 'skill', difficulty: 3 }, Presets: [
    { id: 'fleeca', label: 'Fleeca vault door', model: 'v_ilev_gb_vauldr', openAngle: -90 },
    { id: 'heistsec', label: 'Heist security door', model: 'hei_prop_heist_sec_door', openAngle: 90 },
    { id: 'pacific', label: 'Pacific vault door', model: 'v_ilev_bk_vaultdoor', openAngle: -90 },
    { id: 'vaultgate', label: 'Vault gate', model: 'v_ilev_cbankvaulgate01', openAngle: 90 },
    { id: 'prison', label: 'Prison gate', model: 'prop_gate_prison_01', openAngle: 90 },
    { id: 'cell', label: 'Cell gate', model: 'v_ilev_ph_cellgate', openAngle: 90 },
    { id: 'police', label: 'Police door', model: 'v_ilev_ph_gendoor002', openAngle: 90 },
  ] }, moneyTypes: ['cash', 'bank', 'crypto'], trolleys: [
    { id: 'cash', label: 'Cash trolley', prompt: 'Grab the cash', model: 'hei_prop_hei_cash_trolly_01', emptyModel: 'hei_prop_hei_cash_trolly_03', stacks: 8, seconds: 6, anim: 'cash', reward: { mode: 'money', account: 'cash', item: '', min: 1500, max: 3500 } },
    { id: 'gold', label: 'Gold trolley', prompt: 'Grab the gold', model: 'ch_prop_gold_trolly_01a', emptyModel: 'ch_prop_gold_trolly_01c', stacks: 6, seconds: 7, anim: 'gold', reward: { mode: 'item', account: 'cash', item: 'goldbar', min: 1, max: 3 } },
    { id: 'diamonds', label: 'Diamond trolley', prompt: 'Grab the diamonds', model: 'ch_prop_diamond_trolly_01a', emptyModel: 'ch_prop_diamond_trolly_01c', stacks: 6, seconds: 7, anim: 'gold', reward: { mode: 'item', account: 'cash', item: 'diamond', min: 1, max: 4 } },
    { id: 'cocaine', label: 'Cocaine trolley', prompt: 'Grab the cocaine', model: 'imp_prop_impexp_coke_trolly', emptyModel: '', stacks: 5, seconds: 7, anim: 'gold', reward: { mode: 'item', account: 'cash', item: 'coke_brick', min: 1, max: 2 } },
  ], hacks: [{ id: 'skill', label: 'Skill check (ox_lib)' }, { id: 'timing', label: 'Timing Check' }, { id: 'sequence', label: 'Sequence Recall' }, { id: 'signal_lock', label: 'Signal Lock' }, { id: 'circuit_route', label: 'Circuit Routing' }, { id: 'pin_tension', label: 'Pin & Tension (lockpick)' }, { id: 'wave_match', label: 'Wave Match' }], npcs, objects, anims, roles: [{ id: 'civilian', label: 'Civilians' }, { id: 'police', label: 'Police' }, { id: 'ems', label: 'EMS' }] },
  limits: { ObjectsPerScenario: 600, PeoplePerScenario: 60, WorldRenderLoad: 2200 }, dmKey: 'L',
}
export const mockSession = session

const players = [
  { id: 1, name: 'Dev', character: 'Alex Mercer', citizenid: 'ABC12345', ping: 24, job: 'Police', jobGrade: 3, bucket: 0, staff: 'Owner' },
  { id: 4, name: 'Whale', character: 'Marcus Cole', citizenid: 'QWE98765', ping: 61, job: 'Unemployed', jobGrade: 0, bucket: 0 },
  { id: 7, name: 'Kira', character: 'Elena Park', citizenid: 'ZXC55555', ping: 38, job: 'EMS', jobGrade: 2, bucket: 0 },
]

let seq = 11
const scenarios = [
  { id: 'sc_10', number: 10, name: 'TEST', owner: 'Bablu Plays', status: 'draft', version: 1, objectCount: 2, mine: true, definition: { objects: [
    { id: 'o1', kind: 'npc', model: 'mp_m_freemode_01', label: 'Shop Clerk', role: '', anim: 'smoking', ai: 'statue', coords: { x: 287.5, y: -1271.5, z: 28.441, h: 90 }, dialogue: { nodes: {
      start: { id: 'start', text: 'Hello', replies: [{ id: 'r1', label: 'Whats up?', target: 'n1', roles: [], triggers: [] }, { id: 'r2', label: 'Any work?', target: 'n2', roles: ['police'], triggers: [{ t: 'signal', name: 'alarm' }] }] },
      n1: { id: 'n1', text: 'Whats', replies: [] }, n2: { id: 'n2', text: 'Not today.', replies: [] } } } },
    { id: 'o9', kind: 'door', model: 'v_ilev_gb_vauldr', label: 'Vault door', openAngle: -90, relock: 0, thermite: { enabled: true, item: 'thermite', burn: 10, game: 'skill', difficulty: 3 }, hack: { enabled: true, item: 'laptop', game: 'signal_lock', difficulty: 4 }, coords: { x: 292, y: -1268, z: 28.4, h: 0 } },
    { id: 'o10', kind: 'door', world: true, hash: -1212951353, label: 'Back office door', openRatio: 1, relock: 0, anchor: { x: 291, y: -1266, z: 29 }, thermite: { enabled: false, item: 'thermite', burn: 10, game: 'skill', difficulty: 3 }, hack: { enabled: true, item: 'laptop', game: 'skill', difficulty: 3 }, coords: { x: 291, y: -1266, z: 28.4, h: 90 } },
    { id: 'o2', kind: 'trolley', model: 'ch_prop_gold_trolly_01a', label: 'Gold trolley', ttype: 'gold', emptyModel: 'ch_prop_gold_trolly_01c', stacks: 6, seconds: 7, prompt: 'Grab the gold', anim: 'gold', reward: { mode: 'item', account: 'cash', item: 'goldbar', min: 1, max: 3 }, coords: { x: 290, y: -1270, z: 28.4, h: 0 } },
  ], scripts: [] } },
  { id: 'sc_8', number: 8, name: 'VAULT HEIST', owner: 'Bablu Plays', status: 'live', version: 4, objectCount: 2, mine: true, definition: {
    objects: [
      { id: 'o1', kind: 'trigger', label: 'Security panel', coords: { x: 255, y: 220, z: 106, h: 0 }, size: { x: 2, y: 2, z: 3 } },
      { id: 'o2', kind: 'storage', model: 'prop_ld_int_safe_01', label: 'Vault safe', coords: { x: 258, y: 225, z: 106, h: 90 }, slots: 30, weight: 50000, loot: [{ item: 'money', count: 5000, chance: 100 }, { item: 'goldbar', count: 4, chance: 50 }, { item: 'notanitem', count: 1, chance: 100 }] },
    ],
    scripts: [{ id: 's1', name: 'Panel', when: { type: 'enter', objectId: 'o1' }, blocks: [
      { t: 'hack', name: 'Key Matrix', game: 'signal_lock', difficulty: 4, blocks: [
        { t: 'lock', objectId: 'o2', locked: false }, { t: 'notify', to: 'near', text: 'The vault door unlocks.' }, { t: 'signal', name: 'alarm' },
      ], failBlocks: [{ t: 'signal', name: 'alarm' }] },
    ] }, { id: 's2', name: 'Alarm', when: { type: 'signal', signal: 'alarm' }, blocks: [{ t: 'police_alert', text: 'Vault alarm' }] }],
  } },
]
const summary = () => ({ live: scenarios.filter((s) => s.status === 'live').length, objects: 5, people: 0, worldLoad: 5, worldLoadCap: 2200 })

export async function rpc(name, p = {}) {
  await wait()
  switch (name) {
    case 'session': return ok(session)
    case 'players.list': return ok(players)
    case 'players.details': return ok({ ...players.find((x) => x.id === p.id), health: 200, armor: 0, coords: { x: 215.2, y: -810.1, z: 30.7, h: 90 }, money: { cash: 1200, bank: 54000 }, identifiers: ['license:aaaabbbbcccc', 'discord:123456789'], notes: [] })
    case 'command.run': return ok(null, 'Done')
    case 'dm.list': return ok({ scenarios: scenarios.map(({ definition, ...rest }) => ({ ...rest, objectCount: definition.objects.length })), summary: summary() })
    case 'dm.get': { const s = scenarios.find((x) => x.id === p.id); return s ? ok({ ...s, canEdit: true }) : fail('not_found') }
    case 'dm.create': { const id = `sc_${seq}`; scenarios.unshift({ id, number: seq++, name: p.name, owner: 'Dev', status: 'draft', version: 1, mine: true, definition: { objects: [], scripts: [] } }); return ok({ id }) }
    case 'dm.save': { const s = scenarios.find((x) => x.id === p.id); if (!s) return fail('not_found'); s.definition = p.definition; if (p.name) s.name = p.name; s.version++; return ok({ version: s.version }) }
    case 'dm.delete': { const i = scenarios.findIndex((x) => x.id === p.id); if (i >= 0) scenarios.splice(i, 1); return ok() }
    case 'dm.duplicate': { const s = scenarios.find((x) => x.id === p.id); const id = `sc_${seq}`; scenarios.unshift({ ...s, id, number: seq++, name: `${s.name} copy`, status: 'draft' }); return ok({ id }) }
    case 'dm.import': return fail('not_found')
    case 'dm.setLive': { const s = scenarios.find((x) => x.id === p.id); if (s) s.status = p.live ? 'live' : 'draft'; return ok() }
    case 'dm.action': return ok(null)
    case 'dm.running': return ok([])
    case 'dm.scriptInfo': return ok({ live: true, vars: { alarm_count: 2 }, runs: { s1: { count: 3, last: Math.floor(Date.now() / 1000) - 42 } }, now: Math.floor(Date.now() / 1000) })
    case 'dm.resetVars': case 'dm.runScript': return ok()
    case 'dm.items': return ok([['money', 'Cash'], ['water', 'Water'], ['lockpick', 'Lockpick'], ['goldbar', 'Gold Bar'], ['sandwich', 'Sandwich']].map(([name, label]) => ({ name, label })))
    case 'dm.refillLoot': return ok(null, 'Refilled 1 storage(s)')
    case 'dm.libraryList': return ok([])
    case 'dm.librarySave': return ok()
    default: return fail('unknown_rpc')
  }
}

export async function client(name, p = {}) {
  await wait(30)
  if (name === 'coords.get') return ok({ x: 215.2, y: -810.1, z: 29.7, h: 90 })
  if (name === 'appearance.info') return ok({ drawables: { 1: 200, 2: 80, 3: 200, 4: 200, 5: 100, 6: 160, 7: 200, 8: 220, 9: 30, 10: 20, 11: 600 }, props: { 0: 250, 1: 40, 2: 20, 6: 20, 7: 10 }, overlays: { 0: 24, 1: 29, 2: 34, 3: 15, 4: 75, 5: 7, 6: 12, 7: 11, 8: 10, 9: 18, 10: 17, 11: 12 }, hairColors: 64, makeupColors: 64 })
  if (name === 'appearance.textures') return ok(6)
  if (name === 'appearance.forced') return ok({ torso: 4 })
  if (name === 'appearance.camera') return ok(true)
  if (name === 'appearance.mine' || name === 'appearance.nearby') return ok({ model: 'mp_m_freemode_01', appearance: { blend: { s1: 3, s2: 8, k1: 3, k2: 8, sm: 0.5, km: 0.5 }, face: Array(20).fill(0.1), overlays: {}, hair: { s: 4, t: 0, c: 2, h: 2 }, eye: 2, comps: { 11: { d: 70, t: 1 }, 4: { d: 1, t: 0 }, 6: { d: 0, t: 0 } }, props: {}, autoTorso: true } })
  if (name === 'coords.ground') return ok(29.7)
  if (name === 'editor.place') {
    // Simulate the in-world placement result so the UI flow can be exercised in a browser.
    setTimeout(() => window.postMessage({ action: 'placement', data: { active: false, kind: p.kind, result: { x: 214 + Math.random() * 6, y: -808 + Math.random() * 6, z: 29.7, h: 90 } } }, '*'), 400)
  }
  return ok(true)
}

export async function dialogueReply() { return { ok: true } }
