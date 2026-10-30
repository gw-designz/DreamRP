import { dialogueClose, dialogueReply } from '../services/nui.js'

/** Always-visible staff badges (top right), like the reference. */
export function HudBadges({ hud }) {
  if (!hud.adminMode && !hud.scriptsRunning) return null
  return (
    <div className="hud">
      {hud.adminMode && <div className="badge">Admin mode</div>}
      {hud.scriptsRunning && <div className="badge">✦ Advanced<small>Scripts running</small></div>}
    </div>
  )
}

/** Player-facing NPC conversation. Everything shown here came from the server. */
export function DialogueView({ view }) {
  return (
    <div className="dialogue">
      <header>
        <div className="display">{view.name}</div>
        {view.role ? <small>{view.role}</small> : null}
      </header>
      <div className="text">{view.text}</div>
      <div className="replies">
        {view.replies.map((r) => (
          <button key={r.id} onClick={() => dialogueReply(r.id)}>{r.label}</button>
        ))}
        <button className="leave" onClick={() => dialogueClose()}>Leave</button>
      </div>
    </div>
  )
}

/** Bottom-right key hints, e.g. "LMB Grab / BACKSPACE Stop". Shown while a player interaction needs them. */
export function KeyHints({ items }) {
  return (
    <div className="keyhints">
      {items.map((h) => (
        <div key={h.key + h.label} className={'kh' + (h.dim ? ' dim' : '')}>
          <span className="kcap">{h.key === 'BACKSPACE'
            ? <svg width="17" height="13" viewBox="0 0 24 18" fill="none" stroke="currentColor" strokeWidth="2.4" strokeLinejoin="round" strokeLinecap="round"><path d="M8 1h13a2 2 0 0 1 2 2v12a2 2 0 0 1-2 2H8L1 9z" /><path d="M12 6l6 6M18 6l-6 6" /></svg>
            : h.key}</span>
          <span className="klab">{h.label}</span>
        </div>
      ))}
    </div>
  )
}

export function Narrate({ text }) {
  return <div className="narrate">{text}</div>
}

export function Announce({ text }) {
  return (
    <div className="announce">
      <div className="display">Announcement</div>
      <div>{text}</div>
    </div>
  )
}
