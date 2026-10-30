// Thin bridge to the Lua side. In FiveM every call becomes an NUI callback that the client
// forwards to the server (which authorises it). Outside FiveM (vite dev) the mock is used
// purely for UI development.
import * as mock from './mock.js'

export const inGame = typeof window.GetParentResourceName === 'function'
const resource = inGame ? window.GetParentResourceName() : 'npv_admin'

const TIMEOUT = 12000

async function post(endpoint, body) {
  const request = fetch(`https://${resource}/${endpoint}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json; charset=UTF-8' },
    body: JSON.stringify(body ?? {}),
  }).then((r) => r.json())
  const timeout = new Promise((resolve) => setTimeout(() => resolve({ ok: false, error: 'timeout' }), TIMEOUT))
  try {
    return await Promise.race([request, timeout])
  } catch {
    return { ok: false, error: 'request_failed' }
  }
}

/** Server RPC. Always resolves to { ok, data?, error?, message? }. */
export function rpc(name, payload) {
  return inGame ? post('rpc', { name, payload }) : mock.rpc(name, payload)
}

/** Client-side helper (coordinates, placement, clipboard...). Resolves to { ok, data?, error? }. */
export function client(name, payload) {
  return inGame ? post('client', { name, payload }) : mock.client(name, payload)
}

export function closeUi() {
  return inGame ? post('close') : Promise.resolve({ ok: true })
}

export function dialogueReply(id) {
  return inGame ? post('dialogue:reply', { id }) : mock.dialogueReply(id)
}

export function dialogueClose() {
  return inGame ? post('dialogue:close') : Promise.resolve({ ok: true })
}

export function onMessage(handler) {
  const fn = (e) => e.data && e.data.action && handler(e.data.action, e.data.data)
  window.addEventListener('message', fn)
  return () => window.removeEventListener('message', fn)
}

/** Human-readable text for the error codes the server returns. */
const ERRORS = {
  no_permission: 'You do not have permission to do that.',
  rate_limited: 'Slow down — too many requests.',
  player_offline: 'That player is no longer online.',
  higher_rank: 'You cannot do that to a higher-ranked staff member.',
  not_found: 'That no longer exists.',
  not_implemented: 'This command is not implemented on the server.',
  server_error: 'Server error — check the server console.',
  timeout: 'The server did not answer in time.',
  too_many_objects: 'Too many objects in this scenario.',
  too_many_people: 'Too many people in this scenario.',
  too_many_scenarios: 'You have reached the scenario limit.',
  world_load_exceeded: 'The world render load limit would be exceeded.',
  unknown_model: 'That model does not exist.',
  bad_model: 'Invalid model name.',
  bad_coords: 'Invalid coordinates.',
  duplicate_object_id: 'Duplicate object ID.',
}
export const errorText = (code) => ERRORS[code] || (code ? `Failed: ${String(code).replace(/_/g, ' ')}` : 'Something went wrong.')
