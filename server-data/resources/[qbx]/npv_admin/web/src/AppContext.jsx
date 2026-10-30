import { createContext, useCallback, useContext, useEffect, useMemo, useRef, useState } from 'react'
import { closeUi, errorText, rpc } from './services/nui.js'

const Ctx = createContext(null)
export const useApp = () => useContext(Ctx)

/** Register an Escape handler; the most recently mounted one wins. Return true when handled. */
export function useEscape(handler, active = true) {
  const { escStack } = useApp()
  const ref = useRef(handler)
  ref.current = handler
  useEffect(() => {
    if (!active) return undefined
    const fn = () => ref.current?.()
    escStack.current.push(fn)
    return () => { escStack.current = escStack.current.filter((x) => x !== fn) }
  }, [active, escStack])
}

export function AppProvider({ session, escStack, children }) {
  const [toasts, setToasts] = useState([])
  const [modal, setModal] = useState(null)
  const toastId = useRef(0)

  const toast = useCallback((text, kind = 'info') => {
    const id = ++toastId.current
    setToasts((t) => [...t.slice(-3), { id, text, kind }])
    setTimeout(() => setToasts((t) => t.filter((x) => x.id !== id)), 3600)
  }, [])

  const confirm = useCallback((opts) => new Promise((resolve) => setModal({ ...opts, resolve })), [])
  const closeModal = (result) => { modal?.resolve(result); setModal(null) }

  // Escape closes a modal first, then whichever panel registered last.
  useEffect(() => {
    if (!modal) return undefined
    const fn = () => { modal.resolve(false); setModal(null); return true }
    escStack.current.push(fn)
    return () => { escStack.current = escStack.current.filter((x) => x !== fn) }
  }, [modal, escStack])

  const has = useCallback((perm) => !!session && (session.perms.includes('*') || session.perms.includes(perm)), [session])

  /** Run a registry command through the server. Resolves to the response. */
  const run = useCallback(async (cmd, args = {}, { skipConfirm = false, targetName } = {}) => {
    if (cmd.confirm && !skipConfirm) {
      const yes = await confirm({
        title: cmd.label,
        body: targetName ? `${cmd.desc}\n\nTarget: ${targetName}` : cmd.desc,
        confirmLabel: 'Confirm',
        danger: true,
      })
      if (!yes) return { ok: false, error: 'cancelled' }
    }
    const res = await rpc('command.run', { id: cmd.id, args })
    if (res.ok) toast(res.message || `${cmd.label} done`, 'ok')
    else toast(errorText(res.error), 'error')
    return res
  }, [confirm, toast])

  const value = useMemo(() => ({ session, toast, confirm, run, has, escStack, closeUi }), [session, toast, confirm, run, has])

  return (
    <Ctx.Provider value={value}>
      {children}
      <div className="toasts">
        {toasts.map((t) => <div key={t.id} className={`toast ${t.kind}`}>{t.text}</div>)}
      </div>
      {modal && (
        <div className="modal-wrap" onMouseDown={(e) => { if (e.target === e.currentTarget) closeModal(false) }}>
          <div className="modal">
            <h3 className="display">{modal.title}</h3>
            <p style={{ whiteSpace: 'pre-line' }}>{modal.body}</p>
            <div className="row">
              <button className="btn" onClick={() => closeModal(false)}>Cancel</button>
              <button className={`btn ${modal.danger ? 'danger' : 'accent'}`} onClick={() => closeModal(true)} autoFocus>{modal.confirmLabel || 'OK'}</button>
            </div>
          </div>
        </div>
      )}
    </Ctx.Provider>
  )
}
