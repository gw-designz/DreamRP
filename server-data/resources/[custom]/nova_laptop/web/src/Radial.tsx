import { useEffect, useRef, useState } from 'react';
import { Icon } from './icons';
import { playSound } from './sounds';

/*
  A radial menu drawn the way codera-radialmenu draws its wheel (its sizes,
  colours and font), for the printer's options. The game opens it with a
  'radial' message and hears back through 'radialSelect' / 'radialClose'.
*/

export type RadialItem = { id: string; title: string; icon: string };

// codera-radialmenu's geometry, in the SVG's own units.
const RADIUS = 55, INNER = 23.5, SPACE = 2.35, SCALE = 4; // 4 px a unit: a 400 px holder

const point = (r: number, degrees: number) => {
  const a = degrees * Math.PI / 180;
  return `${(r * Math.sin(a)).toFixed(3)} ${(-r * Math.cos(a)).toFixed(3)}`;
};

/** A ring sector between two angles (degrees clockwise from the top). */
function sector(from: number, to: number) {
  const large = to - from > 180 ? 1 : 0;
  return `M${point(RADIUS, from)} A${RADIUS} ${RADIUS} 0 ${large} 1 ${point(RADIUS, to)} L${point(INNER, to)} A${INNER} ${INNER} 0 ${large} 0 ${point(INNER, from)} Z`;
}

function arc(r: number, from: number, to: number) {
  const large = to - from > 180 ? 1 : 0;
  return `M${point(r, from)} A${r} ${r} 0 ${large} 1 ${point(r, to)}`;
}

/** The mouse in the hint bar, with one button filled. */
function MouseHint({ button }: { button: 'left' | 'right' }) {
  return <svg className="radial-mouse" viewBox="0 0 24 24" aria-hidden="true">
    <rect x="6" y="3" width="12" height="18" rx="6" fill="none" stroke="currentColor" strokeWidth="1.8" />
    <path d={button === 'left' ? 'M12 3 A6 6 0 0 0 6 9 V11 H12 Z' : 'M12 3 A6 6 0 0 1 18 9 V11 H12 Z'} fill="currentColor" />
    <line x1="12" y1="3" x2="12" y2="11" stroke="currentColor" strokeWidth="1.4" />
  </svg>;
}

export function Radial({ items, onSelect: select, onClose: close }: { items: RadialItem[]; onSelect: (id: string) => void; onClose: () => void }) {
  const onSelect = (id: string) => { playSound('select'); select(id); };
  const onClose = () => { playSound('back'); close(); };
  const [hover, setHover] = useState<number | null>(null);
  const holder = useRef<HTMLDivElement>(null);
  const step = 360 / Math.max(1, items.length);
  // The first item sits at the top, the rest follow round to the left.
  const centreOf = (i: number) => ((-i * step) % 360 + 360) % 360;

  // A tick each time the pointer moves onto another item.
  useEffect(() => { if (hover != null) playSound('hover'); }, [hover]);

  useEffect(() => {
    const keys = (event: KeyboardEvent) => { if (event.key === 'Escape' || event.key === 'Backspace') { event.preventDefault(); onClose(); } };
    window.addEventListener('keydown', keys);
    return () => window.removeEventListener('keydown', keys);
  }, [onClose]);

  /** Which item the pointer is over: by its angle round the wheel, outside the middle. */
  function itemAt(x: number, y: number) {
    const box = holder.current?.getBoundingClientRect();
    if (!box) return null;
    const dx = (x - (box.left + box.width / 2)) / SCALE, dy = (y - (box.top + box.height / 2)) / SCALE;
    if (Math.hypot(dx, dy) < INNER) return null;
    const angle = (Math.atan2(dx, -dy) * 180 / Math.PI + 360) % 360;
    for (let i = 0; i < items.length; i++) {
      let off = Math.abs(angle - centreOf(i)) % 360;
      if (off > 180) off = 360 - off;
      if (off <= step / 2) return i;
    }
    return null;
  }

  const picked = hover != null ? items[hover] : null;
  return <div className="radial-stage" onContextMenu={event => { event.preventDefault(); onClose(); }}
    onMouseMove={event => setHover(itemAt(event.clientX, event.clientY))}
    onMouseDown={event => {
      if (event.button === 2) return;
      const i = itemAt(event.clientX, event.clientY);
      if (i != null) onSelect(items[i]!.id);
      else if (holder.current && Math.hypot(event.clientX - (holder.current.getBoundingClientRect().left + 200), event.clientY - (holder.current.getBoundingClientRect().top + 200)) < INNER * SCALE) onClose();
    }}>
    <div className="radial-holder" ref={holder}>
      <svg className="radial-menu" viewBox="-50 -50 100 100" width="400" height="400">
        {items.map((item, i) => {
          const centre = centreOf(i), from = centre - step / 2, to = centre + step / 2;
          const at = (r: number) => { const a = centre * Math.PI / 180; return { x: r * Math.sin(a), y: -r * Math.cos(a) }; };
          const label = at((INNER + RADIUS) / 2 + 1);
          return <g key={item.id} className={`radial-sector ${hover === i ? 'selected' : ''}`}>
            <path d={items.length === 1 ? `M0 ${-RADIUS} A${RADIUS} ${RADIUS} 0 1 1 0 ${RADIUS} A${RADIUS} ${RADIUS} 0 1 1 0 ${-RADIUS} Z M0 ${-INNER} A${INNER} ${INNER} 0 1 0 0 ${INNER} A${INNER} ${INNER} 0 1 0 0 ${-INNER} Z` : sector(from, to)} />
            <foreignObject x={label.x - 4} y={label.y - 8.5} width="8" height="8"><div className="radial-icon"><Icon name={item.icon} size={8} stroke={2.4} /></div></foreignObject>
            <text x={label.x} y={label.y + 6} textAnchor="middle">{item.title.toUpperCase()}</text>
          </g>;
        })}
        <circle className="radial-ring" r={RADIUS + 2.25} />
        {picked && hover != null && <>
          <path className="radial-selection" d={arc(RADIUS + 0.2, centreOf(hover) - step / 2, centreOf(hover) + step / 2)} />
          <path className="radial-centre-selection" d={arc(INNER - SPACE, centreOf(hover) - step / 2, centreOf(hover) + step / 2)} />
        </>}
        <g className="radial-centre" onMouseDown={event => { event.stopPropagation(); onClose(); }}>
          <circle r={INNER - SPACE} />
          <text textAnchor="middle" dominantBaseline="central">MENU</text>
        </g>
      </svg>
      <div className="radial-controls"><MouseHint button="left" /><span>SELECT</span><span className="radial-divider" /><MouseHint button="right" /><span>CLOSE</span></div>
    </div>
  </div>;
}
