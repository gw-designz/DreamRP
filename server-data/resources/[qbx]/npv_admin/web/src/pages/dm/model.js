// Shared scenario data helpers + ready-made templates.

export const uid = (prefix = 'o') => `${prefix}${Date.now().toString(36)}${Math.random().toString(36).slice(2, 6)}`

export const KIND_LABEL = { object: 'Object', npc: 'NPC', trigger: 'Trigger box', interactive: 'Interactive', storage: 'Storage', rope: 'Rappel rope', trolley: 'Trolley', door: 'Locked door' }

export function newObject(kind, { model, label, coords, size, length, trolley, door }) {
  const base = { id: uid(), kind, model, label: label || model || KIND_LABEL[kind], coords }
  if (kind === 'npc') return { ...base, role: '', anim: '', ai: 'statue', dialogue: null, voice: '', greet: false, chatter: 0, chatNpcs: true, patrol: [] }
  if (kind === 'door') {
    const d = door || {}
    return {
      ...base, openAngle: d.openAngle ?? 90, openDir: 'toward', relock: 0, ...(d.world ? { world: true, hash: d.hash, anchor: d.anchor } : {}),
      thermite: { enabled: true, item: 'thermite', burn: 10, game: 'skill', difficulty: 3, ...(d.thermite || {}) },
      hack: { enabled: true, item: '', game: 'skill', difficulty: 3, ...(d.hack || {}) },
    }
  }
  if (kind === 'trolley') {
    const t = trolley || {}
    return {
      ...base, ttype: t.id || 'custom', emptyModel: t.emptyModel || '', stacks: t.stacks ?? 8, seconds: t.seconds ?? 6, prompt: t.prompt || 'Grab',
      anim: t.anim || 'cash', reward: { mode: 'money', account: 'cash', item: '', min: 1000, max: 2000, ...(t.reward || {}) },
    }
  }
  if (kind === 'rope') return { id: base.id, kind, label: label || 'Rappel rope', coords, length: length || 20, prompt: 'Rappel down' }
  if (kind === 'trigger') return { id: base.id, kind, label: label || 'Trigger box', coords, size: size || { x: 3, y: 3, z: 3 } }
  if (kind === 'interactive') return { ...base, prompt: 'Use', cooldown: 0 }
  if (kind === 'storage') return { ...base, slots: 30, weight: 50000, loot: [] }
  return base
}

export function newScript(objectId) {
  return { id: uid('s'), name: 'New script', when: { type: objectId ? 'use' : 'spawn', objectId: objectId || undefined }, blocks: [] }
}

export const emptyDialogue = () => ({ nodes: { start: { id: 'start', text: 'Hello', replies: [] } } })

export const counts = (def) => {
  let people = 0
  let objects = 0
  for (const o of def.objects) { if (o.kind === 'npc') people++; else objects++ }
  return { objects, people }
}

// --- ready-made scenarios -----------------------------------------------------------------------
// Built around where the staff member stands and faces (coords = { x, y, z, h } from the game).
// Only features the server really runs are used: props, people with idle/dialogue, storage, locks,
// trigger boxes, signals, police alerts, item rewards.
const round = (n) => +n.toFixed(3)
/** A point `fwd` metres ahead of and `right` metres to the right of the staff member. */
const rel = (c, fwd, right = 0, turn = 0) => {
  const r = (c.h * Math.PI) / 180
  return {
    x: round(c.x - Math.sin(r) * fwd + Math.cos(r) * right),
    y: round(c.y + Math.cos(r) * fwd + Math.sin(r) * right),
    z: c.z,
    h: (((c.h + turn) % 360) + 360) % 360,
  }
}
const prop = (kind, model, label, coords, extra = {}) => ({ ...newObject(kind, { model, label, coords }), ...extra })
const person = (model, label, coords, extra = {}) => ({ ...newObject('npc', { model, label, coords }), ...extra })
const zone = (label, coords, size) => newObject('trigger', { label, coords, size })
const script = (name, when, blocks) => ({ id: uid('s'), name, when, blocks })
const reply = (label, target, triggers = []) => ({ id: uid('r'), label, target, roles: [], triggers })

export const TEMPLATES = [
  {
    id: 'holdup',
    name: 'Convenience store hold-up',
    desc: 'A clerk you can talk into emptying the till or opening the safe behind the counter, and a silent alarm at the door.',
    build: (c) => {
      const clerk = person('mp_m_shopkeep_01', 'Clerk', rel(c, 4, 0, 180), { role: 'Store clerk', anim: 'impatient' })
      const counter = prop('object', 'prop_table_03', 'Counter', rel(c, 3, 0, 180))
      const safe = prop('storage', 'prop_ld_int_safe_01', 'Safe', rel(c, 6, 2, 180), { loot: [{ item: 'money', count: 5000, chance: 100 }] })
      const door = zone('Door', rel(c, -1, 0), { x: 3, y: 3, z: 3 })
      clerk.dialogue = { nodes: {
        start: { id: 'start', text: 'Take whatever you want, just do not hurt me!', replies: [
          reply('Open the safe.', 'n1', [{ t: 'signal', name: 'open_safe' }]),
          reply('Empty the till.', 'n2', [{ t: 'give_item', item: 'money', count: 800 }]),
          reply('Never mind.', 'n3'),
        ] },
        n1: { id: 'n1', text: 'Okay, okay. It is open.', replies: [] },
        n2: { id: 'n2', text: 'That is everything in the till.', replies: [] },
        n3: { id: 'n3', text: 'Then please leave.', replies: [] },
      } }
      return {
        objects: [clerk, counter, safe, door],
        scripts: [
          script('Lock the safe', { type: 'spawn' }, [{ t: 'lock', objectId: safe.id, locked: true }]),
          script('Open the safe', { type: 'signal', signal: 'open_safe' }, [{ t: 'lock', objectId: safe.id, locked: false }, { t: 'notify', to: 'near', text: 'The safe clicks open.' }]),
          script('Silent alarm', { type: 'enter', objectId: door.id }, [{ t: 'limit', max: 1 }, { t: 'police_alert', text: 'Silent alarm: store hold-up' }]),
        ],
      }
    },
  },
  {
    id: 'druglab',
    name: 'Drug lab',
    desc: 'Work tables with product to search, two guards on their feet, and a warning when someone walks in.',
    build: (c) => {
      const guards = [
        person('g_m_y_mexgoon_01', 'Guard', rel(c, 5, -2, 180), { ai: 'npc', anim: 'guard' }),
        person('g_m_y_mexgoon_01', 'Guard', rel(c, 5, 2, 180), { ai: 'npc', anim: 'armscrossed' }),
      ]
      const door = zone('Entrance', rel(c, 0, 0), { x: 4, y: 3, z: 3 })
      return {
        objects: [
          ...guards,
          prop('object', 'prop_table_03', 'Cook table', rel(c, 4, -3, 90)),
          prop('object', 'prop_table_03', 'Cutting table', rel(c, 4, 3, 90)),
          prop('storage', 'prop_weed_pallet', 'Product pallet', rel(c, 7, -3)),
          prop('storage', 'prop_coke_block_01', 'Product blocks', rel(c, 7, 3)),
          door,
        ],
        scripts: [script('Door warning', { type: 'enter', objectId: door.id }, [{ t: 'limit', max: 1 }, { t: 'notify', to: 'near', text: 'Someone is at the door!' }])],
      }
    },
  },
  {
    id: 'hideout',
    name: 'Gang hideout',
    desc: 'Four gang members hanging about, with a gun case and a bag of cash to search.',
    build: (c) => ({
      objects: [
        person('g_m_y_ballaeast_01', 'Lookout', rel(c, 4, -3, 180), { ai: 'npc', anim: 'phone' }),
        person('g_m_y_ballaeast_01', 'Smoker', rel(c, 4, 3, 180), { ai: 'npc', anim: 'smoking' }),
        person('g_m_y_ballaeast_01', 'Drinker', rel(c, 7, -2, 180), { ai: 'npc', anim: 'drinking' }),
        person('g_m_y_ballaeast_01', 'Hangout', rel(c, 7, 2, 180), { ai: 'npc', anim: 'hangout' }),
        prop('storage', 'prop_box_guncase_01a', 'Gun case', rel(c, 6, 0)),
        prop('storage', 'prop_money_bag_01', 'Cash bag', rel(c, 8, 4), { loot: [{ item: 'money', count: 3000, chance: 100 }] }),
      ],
      scripts: [],
    }),
  },
  {
    id: 'checkpoint',
    name: 'Police checkpoint',
    desc: 'A road block: barriers, cones and two officers checking cars.',
    build: (c) => ({
      objects: [
        ...[-4.5, -1.5, 1.5, 4.5].map((r) => prop('object', 'prop_barrier_work06a', 'Barrier', rel(c, 6, r))),
        ...[-6, -2, 2, 6].map((r) => prop('object', 'prop_cone_float_1', 'Cone', rel(c, 3, r))),
        person('s_m_y_cop_01', 'Officer', rel(c, 8, -2, 180), { anim: 'copidle' }),
        person('s_m_y_cop_01', 'Officer', rel(c, 8, 2, 180), { anim: 'copidle' }),
      ],
      scripts: [],
    }),
  },
  {
    id: 'cache',
    name: 'Weapons cache',
    desc: 'Two locked military crates. Use the laptop to open them for ten minutes; it also alerts the police.',
    build: (c) => {
      const crateA = prop('storage', 'prop_mil_crate_01', 'Crate A', rel(c, 6, -1.5))
      const crateB = prop('storage', 'prop_mil_crate_01', 'Crate B', rel(c, 6, 1.5))
      const laptop = prop('interactive', 'prop_laptop_01a', 'Laptop', rel(c, 3, 0), { prompt: 'Hack laptop', cooldown: 0 })
      return {
        objects: [crateA, crateB, laptop, person('s_m_y_swat_01', 'Guard', rel(c, 9, 0, 180), { anim: 'guard' })],
        scripts: [
          script('Lock crates', { type: 'spawn' }, [{ t: 'lock', objectId: crateA.id, locked: true }, { t: 'lock', objectId: crateB.id, locked: true }]),
          script('Laptop', { type: 'use', objectId: laptop.id }, [
            { t: 'limit', max: 1 },
            { t: 'lock', objectId: crateA.id, locked: false }, { t: 'lock', objectId: crateB.id, locked: false },
            { t: 'notify', to: 'near', text: 'The crates unlock for ten minutes.' },
            { t: 'police_alert', text: 'Weapons cache breached' },
            { t: 'repeat', n: 10, blocks: [{ t: 'wait', ms: 60000 }] },
            { t: 'lock', objectId: crateA.id, locked: true }, { t: 'lock', objectId: crateB.id, locked: true },
            { t: 'notify', to: 'near', text: 'The crates lock again.' },
          ]),
        ],
      }
    },
  },
  {
    id: 'vault',
    name: 'Vault heist',
    desc: 'A security panel that opens the vault safe, a bag of gold inside, an alarm that calls the police, and two guards.',
    build: (c) => {
      const panel = prop('interactive', 'prop_ld_keypad_01', 'Security panel', rel(c, 2, -2), { prompt: 'Override panel' })
      const safe = prop('storage', 'prop_ld_int_safe_01', 'Vault safe', rel(c, 7, 0, 180), { loot: [{ item: 'money', count: 25000, chance: 100 }] })
      return {
        objects: [
          panel, safe,
          prop('storage', 'prop_money_bag_01', 'Gold bag', rel(c, 8, 2.5)),
          person('s_m_m_security_01', 'Guard', rel(c, 5, -4, 180), { ai: 'npc', anim: 'guard' }),
          person('s_m_m_security_01', 'Guard', rel(c, 5, 4, 180), { ai: 'npc', anim: 'armscrossed' }),
        ],
        scripts: [
          script('Lock vault', { type: 'spawn' }, [{ t: 'lock', objectId: safe.id, locked: true }]),
          script('Panel', { type: 'use', objectId: panel.id }, [
            { t: 'limit', max: 1 }, { t: 'lock', objectId: safe.id, locked: false },
            { t: 'notify', to: 'near', text: 'The vault door unlocks.' }, { t: 'signal', name: 'alarm' },
          ]),
          script('Alarm', { type: 'signal', signal: 'alarm' }, [{ t: 'police_alert', text: 'Vault alarm' }]),
        ],
      }
    },
  },
  {
    id: 'crash',
    name: 'Crash site',
    desc: 'Wreckage props with a briefcase to search and a line of text for whoever arrives first.',
    build: (c) => {
      const area = zone('Crash area', rel(c, 5, 0), { x: 10, y: 10, z: 4 })
      return {
        objects: [
          prop('object', 'prop_barrel_01a', 'Barrel', rel(c, 4, -2)),
          prop('object', 'prop_barrel_01a', 'Barrel', rel(c, 6, 2)),
          prop('object', 'prop_barrier_work06a', 'Barrier', rel(c, 3, -4, 90)),
          prop('object', 'prop_barrier_work06a', 'Barrier', rel(c, 3, 4, 90)),
          prop('storage', 'prop_ld_case_01', 'Briefcase', rel(c, 5, 0), { loot: [{ item: 'money', count: 1500, chance: 100 }] }),
          area,
        ],
        scripts: [script('First to arrive', { type: 'enter', objectId: area.id }, [{ t: 'limit', max: 1 }, { t: 'notify', to: 'player', text: 'You spot a briefcase in the wreckage.' }])],
      }
    },
  },
]

export const templateStats = (t) => {
  // Counts shown on the card are taken from a real build, so they can never drift from the template.
  const d = t.build({ x: 0, y: 0, z: 0, h: 0 })
  const c = counts(d)
  return { things: c.objects, people: c.people, scripts: d.scripts.length }
}
