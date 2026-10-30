import { useEffect, useRef, useState } from 'react'

// Small inline icon set (stroke icons, 24px grid).
const PATHS = {
  star: 'M12 3.5l2.6 5.5 6 .8-4.4 4.2 1.1 6-5.3-2.9-5.3 2.9 1.1-6L3.4 9.8l6-.8z',
  chevron: 'M6 9l6 6 6-6',
  chevronUp: 'M6 15l6-6 6 6',
  folder: 'M3 6.5h6l2 2.5h10v9.5H3z',
  users: 'M9 11a3 3 0 100-6 3 3 0 000 6zM3 19c0-3 2.7-5 6-5s6 2 6 5M16 11a2.5 2.5 0 100-5M17.5 14.5c2 .5 3.5 2 3.5 4.5',
  gear: 'M12 15a3 3 0 100-6 3 3 0 000 6zM19 12l2-1.2-1.6-2.8-2.3.6a7 7 0 00-1.6-.9L15 5.2h-3.2l-.5 2.5a7 7 0 00-1.6.9l-2.3-.6L5.8 10.8 7.8 12l-.1 1.2 2 1.2.1 1.4 2.4.6a7 7 0 001.6.9l.5 2.4H17l.5-2.4a7 7 0 001.6-.9l2.3.6 1.6-2.8-2-1.2z',
  user: 'M12 12a4 4 0 100-8 4 4 0 000 8zM4.5 20c.5-3.5 3.5-5.5 7.5-5.5s7 2 7.5 5.5',
  keyboard: 'M3 7h18v10H3zM6.5 10.5h1M10 10.5h1M13.5 10.5h1M17 10.5h1M7 14h10',
  grid: 'M4 4h6v6H4zM14 4h6v6h-6zM4 14h6v6H4zM14 14h6v6h-6z',
  list: 'M4 6h16M4 12h16M4 18h16',
  search: 'M11 18a7 7 0 100-14 7 7 0 000 14zM20 20l-4-4',
  close: 'M5 5l14 14M19 5L5 19',
  plus: 'M12 5v14M5 12h14',
  trash: 'M5 7h14M9 7V4h6v3M7 7l1 13h8l1-13M10 11v6M14 11v6',
  copy: 'M8 8h11v12H8zM5 16V4h11',
  share: 'M7 12a2 2 0 100-.01M17 6a2 2 0 100-.01M17 18a2 2 0 100-.01M8.8 11l6.4-4M8.8 13l6.4 4',
  play: 'M7 4.5v15l12-7.5z',
  code: 'M9 7l-5 5 5 5M15 7l5 5-5 5',
  eye: 'M2 12s4-7 10-7 10 7 10 7-4 7-10 7S2 12 2 12zM12 15a3 3 0 100-6 3 3 0 000 6z',
  up: 'M12 19V5M6 11l6-6 6 6',
  down: 'M12 5v14M6 13l6 6 6-6',
  check: 'M5 12.5l4.5 4.5L19 7.5',
  minus: 'M5 12h14',
  move: 'M12 3v18M3 12h18M12 3l-3 3M12 3l3 3M12 21l-3-3M12 21l3-3M3 12l3-3M3 12l3 3M21 12l-3-3M21 12l-3 3',
  pin: 'M12 21s6-5.5 6-11a6 6 0 10-12 0c0 5.5 6 11 6 11zM12 12a2 2 0 100-4',
  bolt: 'M13 3L5 13h6l-1 8 8-10h-6z',
  flag: 'M6 21V4M6 5h11l-2 4 2 4H6',
  message: 'M4 5h16v11H9l-5 4z',
  save: 'M5 4h12l3 3v13H5zM8 4v5h8V4M8 20v-6h8v6',
  undo: 'M9 7L4 12l5 5M4 12h10a6 6 0 010 8',
  target: 'M12 21a9 9 0 100-18 9 9 0 000 18zM12 16a4 4 0 100-8 4 4 0 000 8zM12 12v0',
  skull: 'M12 3a8 8 0 00-5 14v3h10v-3a8 8 0 00-5-14zM9 12h.01M15 12h.01M10.5 17v2M13.5 17v2',
  flame: 'M12 3c1 4 5 5 5 10a5 5 0 01-10 0c0-2 1-3 2-4 0 2 1 3 2 3 0-3-1-5 1-9z',
  car: 'M4 14l2-5h12l2 5v4h-3v-2H7v2H4zM7.5 13.5h.01M16.5 13.5h.01',
  heart: 'M12 20s-8-5-8-11a4.5 4.5 0 018-2.5A4.5 4.5 0 0120 9c0 6-8 11-8 11z',
  gift: 'M4 10h16v10H4zM3 7h18v3H3zM12 7v13M12 7c-2-3-5-3-5-1s3 1 5 1zm0 0c2-3 5-3 5-1s-3 1-5 1z',
  sun: 'M12 16a4 4 0 100-8 4 4 0 000 8zM12 2v3M12 19v3M2 12h3M19 12h3M5 5l2 2M17 17l2 2M19 5l-2 2M7 17l-2 2',
  lock: 'M6 11h12v9H6zM8.5 11V8a3.5 3.5 0 017 0v3',
  walk: 'M13 4.5a1.5 1.5 0 100-.01M11 8l-2 5 3 2v5M11 8l4 2 2 4M9 13l-3 1',
  alert: 'M12 3l10 18H2zM12 10v5M12 18v.01',
  box: 'M3 8l9-5 9 5v8l-9 5-9-5zM3 8l9 5 9-5M12 13v8',
  speaker: 'M4 9v6h4l5 4V5L8 9zM16 9a4 4 0 010 6',
  edit: 'M4 20h4L19 9l-4-4L4 16zM13.5 6.5l4 4',
}

export function Icon({ name, size = 16, stroke = 1.8, fill = 'none', style }) {
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" fill={fill} stroke="currentColor" strokeWidth={stroke} strokeLinecap="round" strokeLinejoin="round" style={style} aria-hidden>
      <path d={PATHS[name] || PATHS.box} />
    </svg>
  )
}

export function Toggle({ on, onChange, label }) {
  return <button className={`toggle ${on ? 'on' : ''}`} role="switch" aria-checked={on} aria-label={label} onClick={() => onChange(!on)} />
}

export function Spinner() {
  return <span className="spin" />
}

/** Chip group where exactly one value is selected. */
export function Segmented({ options, value, onChange }) {
  return (
    <div className="seg">
      {options.map((o) => (
        <button key={o.value} className={value === o.value ? 'on' : ''} onClick={() => onChange(o.value)}>{o.label}</button>
      ))}
    </div>
  )
}

/** Number field that keeps the typed text while editing and commits valid numbers. */
export function NumberInput({ value, onChange, step = 1, min, max, className = 'input sm', ...rest }) {
  const [text, setText] = useState(String(value ?? ''))
  const focused = useRef(false)
  useEffect(() => { if (!focused.current) setText(String(value ?? '')) }, [value])
  return (
    <input
      {...rest}
      className={className}
      inputMode="decimal"
      value={text}
      onFocus={() => { focused.current = true }}
      onBlur={() => { focused.current = false; setText(String(value ?? '')) }}
      onChange={(e) => {
        setText(e.target.value)
        const n = Number(e.target.value)
        if (e.target.value.trim() !== '' && Number.isFinite(n) && (min == null || n >= min) && (max == null || n <= max)) onChange(n)
      }}
      onWheel={(e) => e.currentTarget.blur()}
    />
  )
}

export function KeyCap({ children }) {
  return (
    <span style={{ display: 'inline-flex', minWidth: 22, height: 22, padding: '0 6px', alignItems: 'center', justifyContent: 'center', background: 'var(--bg-input-light)', color: 'var(--text-on-light)', fontFamily: 'var(--font-display)', fontStyle: 'italic', fontWeight: 700, fontSize: 12, textTransform: 'uppercase' }}>
      {children}
    </span>
  )
}
