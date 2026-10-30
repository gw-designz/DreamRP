// Appearance data + helpers for freemode NPCs. Slot ids follow the RAGE wiki "Clothes" page.
// Item names come from root-cause/v-clothingnames (data/clothing.json, drawable -> name).
import clothing from '../../data/clothing.json'
import presetList from '../../data/presets.json'

export const FREEMODE = ['mp_m_freemode_01', 'mp_f_freemode_01']
export const isFreemode = (model) => FREEMODE.includes(model)
export const genderOf = (model) => (model === 'mp_f_freemode_01' ? 'f' : 'm')

// Clothing components (SetPedComponentVariation). Hair (2) is edited on the Hair tab.
export const COMPONENTS = [
  { id: 11, label: 'Tops', key: 'c11' },
  { id: 8, label: 'Undershirts', key: 'c8' },
  { id: 3, label: 'Torso / arms', key: 'c3' },
  { id: 4, label: 'Legs', key: 'c4' },
  { id: 6, label: 'Shoes', key: 'c6' },
  { id: 7, label: 'Accessories', key: 'c7' },
  { id: 1, label: 'Masks', key: 'c1' },
  { id: 5, label: 'Bags & parachutes', key: 'c5' },
  { id: 9, label: 'Body armor', key: 'c9' },
  { id: 10, label: 'Decals', key: 'c10' },
]
// Props (SetPedPropIndex).
export const PROPS = [
  { id: 0, label: 'Hats', key: 'p0' },
  { id: 1, label: 'Glasses', key: 'p1' },
  { id: 2, label: 'Ears', key: 'p2' },
  { id: 6, label: 'Watches', key: 'p6' },
  { id: 7, label: 'Bracelets', key: 'p7' },
]

export const FACE_FEATURES = [
  'Nose width', 'Nose peak height', 'Nose peak length', 'Nose bone height', 'Nose peak lowering', 'Nose bone twist',
  'Eyebrow height', 'Eyebrow depth', 'Cheekbone height', 'Cheekbone width', 'Cheek width', 'Eye opening',
  'Lip thickness', 'Jaw width', 'Jaw length', 'Chin height', 'Chin length', 'Chin width', 'Chin hole', 'Neck thickness',
]

// kind: which colour palette an overlay uses ('hair' | 'makeup' | null)
export const OVERLAYS = [
  { id: 0, label: 'Blemishes', kind: null },
  { id: 1, label: 'Facial hair', kind: 'hair' },
  { id: 2, label: 'Eyebrows', kind: 'hair' },
  { id: 3, label: 'Ageing', kind: null },
  { id: 4, label: 'Makeup', kind: 'makeup' },
  { id: 5, label: 'Blush', kind: 'makeup' },
  { id: 6, label: 'Complexion', kind: null },
  { id: 7, label: 'Sun damage', kind: null },
  { id: 8, label: 'Lipstick', kind: 'makeup' },
  { id: 9, label: 'Moles & freckles', kind: null },
  { id: 10, label: 'Chest hair', kind: 'hair' },
  { id: 11, label: 'Body blemishes', kind: null },
]

export const EYE_COLORS = [
  'Green', 'Emerald', 'Light Blue', 'Ocean Blue', 'Light Brown', 'Dark Brown', 'Hazel', 'Dark Gray', 'Light Gray', 'Pink', 'Yellow',
  'Purple', 'Blackout', 'Shades of Gray', 'Tequila Sunrise', 'Atomic', 'Warp', 'ECola', 'Space Ranger', 'Ying Yang', 'Bullseye',
  'Lizard', 'Dragon', 'Extra Terrestrial', 'Goat', 'Smiley', 'Possessed', 'Demon', 'Infected', 'Alien', 'Undead', 'Zombie',
]

// Heritage "parents": 0-20 male faces, 21-41 female faces, 42-45 special.
export const PARENTS = [
  'Benjamin', 'Daniel', 'Joshua', 'Noah', 'Andrew', 'Juan', 'Alex', 'Isaac', 'Evan', 'Ethan', 'Vincent', 'Angel', 'Diego', 'Adrian',
  'Gabriel', 'Michael', 'Santiago', 'Kevin', 'Louis', 'Samuel', 'Anthony',
  'Hannah', 'Audrey', 'Jasmine', 'Giselle', 'Amelia', 'Isabella', 'Zoe', 'Ava', 'Camila', 'Violet', 'Sophia', 'Evelyn', 'Nicole',
  'Ashley', 'Gracie', 'Brianna', 'Natalie', 'Olivia', 'Elizabeth', 'Charlotte', 'Emma', 'Claude', 'Niko', 'John', 'Misty',
]

/** Name of a clothing drawable, or '' when the dump has no label for it. */
export function itemName(model, key, drawable) {
  const list = clothing[genderOf(model)]?.[key]
  return (list && list[drawable]) || ''
}
/** How many drawables the name list knows about (a floor when the game has not reported counts). */
export const knownCount = (model, key) => clothing[genderOf(model)]?.[key]?.length || 0
export const namedIndexes = (model, key) => (clothing[genderOf(model)]?.[key] || []).map((n, i) => (n ? i : -1)).filter((i) => i >= 0)

/** Presets for a model (clone before use). */
export const presetsFor = (model) => presetList.filter((p) => p.gender === genderOf(model))

/** A freshly placed MP ped starts in the first ("Casual") preset so it is never blank or undressed. */
export function defaultAppearance(model) {
  return JSON.parse(JSON.stringify(presetsFor(model)[0].appearance))
}

const rint = (a, b) => a + Math.floor(Math.random() * (b - a + 1))
const rflt = (a, b) => +(a + Math.random() * (b - a)).toFixed(2)
const pick = (arr) => arr[Math.floor(Math.random() * arr.length)]

export function randomFace(app, model) {
  const male = genderOf(model) === 'm'
  const lo = male ? 0 : 21
  const hi = male ? 20 : 41
  return {
    ...app,
    blend: { s1: rint(lo, hi), s2: rint(lo, hi), k1: rint(lo, hi), k2: rint(lo, hi), sm: rflt(0.15, 0.85), km: rflt(0.15, 0.85) },
    face: Array.from({ length: 20 }, () => rflt(-0.4, 0.4)),
  }
}

/** Random look using only named items (so it picks real shop clothes) within the counts the game reports. */
export function randomLook(app, model, info) {
  const limit = (key, id) => (info?.drawables?.[id] ?? knownCount(model, key))
  const choose = (key, id, fallback) => {
    const ok = namedIndexes(model, key).filter((i) => i < limit(key, id))
    return ok.length ? pick(ok) : fallback
  }
  const male = genderOf(model) === 'm'
  const next = randomFace(app, model)
  next.hair = { s: choose('c2', 2, 0), t: 0, c: rint(0, 20), h: rint(0, 20) }
  next.eye = rint(0, 11)
  next.overlays = { ...next.overlays, 2: { i: rint(0, 33), o: 1, c: next.hair.c, c2: 0 } }
  if (male) next.overlays[1] = Math.random() < 0.5 ? { i: rint(0, 28), o: rflt(0.5, 1), c: next.hair.c, c2: 0 } : { i: 255, o: 1, c: 0, c2: 0 }
  next.comps = {
    ...next.comps,
    11: { d: choose('c11', 11, 0), t: rint(0, 2) },
    8: Math.random() < 0.4 ? { d: choose('c8', 8, 15), t: 0 } : { d: 15, t: 0 },
    4: { d: choose('c4', 4, 0), t: rint(0, 1) },
    6: { d: choose('c6', 6, 0), t: rint(0, 1) },
  }
  next.autoTorso = true
  return next
}

export const clone = (o) => JSON.parse(JSON.stringify(o))
