import { useEffect, useState } from 'react';
import './keyhints.css';

export type KeyHint = { key: string; label: string };

/** The key hints in the bottom right, set by the client's Hints.draw. Drawn like my-hud's controls bar. */
export function KeyHints() {
  const [hints, setHints] = useState<KeyHint[] | null>(null);
  useEffect(() => {
    const message = (event: MessageEvent) => {
      if (event.data?.type === 'hints') setHints(Array.isArray(event.data.hints) && event.data.hints.length ? event.data.hints : null);
    };
    window.addEventListener('message', message);
    return () => window.removeEventListener('message', message);
  }, []);
  if (!hints) return null;
  return <div className="kh-bar">
    {hints.map((hint, i) => <div key={i} className="kh-prompt"><span className="kh-glyph">{hint.key}</span><span className="kh-label">{hint.label}</span></div>)}
  </div>;
}
