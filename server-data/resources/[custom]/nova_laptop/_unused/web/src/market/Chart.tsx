import { useId, useState } from 'react';
import type { Candle } from './types';
export const money = (cents: number, digits = 2) => (cents / 100).toLocaleString('en-US', { style: 'currency', currency: 'USD', minimumFractionDigits: digits, maximumFractionDigits: digits });
export const signedMoney = (cents: number) => `${cents >= 0 ? '+' : ''}${money(cents)}`;
export const percent = (value: number) => `${value >= 0 ? '+' : ''}${value.toFixed(2)}%`;

export function Sparkline({ values, positive }: { values: number[]; positive: boolean }) {
  if (!values.length) return <span className="spark-empty" />;
  const min = Math.min(...values), max = Math.max(...values), span = max - min || 1;
  const points = values.map((n, i) => `${i / Math.max(values.length - 1, 1) * 120},${30 - (n - min) / span * 26}`).join(' ');
  return <svg className={`sparkline ${positive ? 'positive' : 'negative'}`} viewBox="0 0 120 34" aria-hidden="true"><polyline points={points} fill="none" stroke="currentColor" strokeWidth="1.6" strokeLinejoin="round" strokeLinecap="round" /></svg>;
}

export function PriceChart({ candles, style, symbol }: { candles: Candle[]; style: 'line' | 'candles'; symbol: string }) {
  const id = useId().replace(/:/g, ''), [hover, setHover] = useState<number | null>(null);
  if (!candles.length) return <div className="chart-empty">Chart history will appear after the next market update.</div>;
  const W = 660, H = 180, left = 3, right = 62, top = 12, bottom = 28;
  const chartW = W - left - right, chartH = H - top - bottom;
  const low = Math.min(...candles.map(c => c.l)), high = Math.max(...candles.map(c => c.h));
  const padding = Math.max(10, (high - low) * .14), min = low - padding, max = high + padding;
  const x = (i: number) => left + i / Math.max(candles.length - 1, 1) * chartW;
  const y = (n: number) => top + (max - n) / (max - min) * chartH;
  const points = candles.map((c, i) => `${x(i)},${y(c.c)}`).join(' ');
  const positive = candles.at(-1)!.c >= candles[0].o;
  const last = candles.at(-1)!;
  const hoverIndex = hover == null ? null : Math.min(hover, candles.length - 1);
  const hovered = hoverIndex == null ? null : candles[hoverIndex];
  return <div className={`price-chart ${positive ? 'positive' : 'negative'}`}>
    <div className="chart-ohlc">{[['O', hovered?.o ?? last.o], ['H', hovered?.h ?? last.h], ['L', hovered?.l ?? last.l], ['C', hovered?.c ?? last.c]].map(([label, value]) => <span key={label}><i>{label}</i>{money(Number(value))}</span>)}</div>
    <svg role="img" aria-label={`${symbol} ${style} price chart`} viewBox={`0 0 ${W} ${H}`} onPointerLeave={() => setHover(null)} onPointerMove={event => {
      const box = event.currentTarget.getBoundingClientRect();
      const px = (event.clientX - box.x) / box.width * W;
      setHover(Math.max(0, Math.min(candles.length - 1, Math.round((px - left) / chartW * (candles.length - 1)))));
    }}>
      <defs><linearGradient id={`fill-${id}`} x1="0" y1="0" x2="0" y2="1"><stop offset="0" stopColor="currentColor" stopOpacity=".18" /><stop offset="1" stopColor="currentColor" stopOpacity="0" /></linearGradient></defs>
      {Array.from({ length: 4 }, (_, i) => { const price = max - (max - min) * i / 3, py = y(price); return <g key={i}><line className="chart-gridline" x1={left} y1={py} x2={W - right} y2={py} /><text className="chart-axis" x={W - right + 11} y={py + 3}>{money(price)}</text></g>; })}
      {style === 'line' ? <><polygon points={`${left},${top + chartH} ${points} ${W - right},${top + chartH}`} fill={`url(#fill-${id})`} /><polyline points={points} fill="none" stroke="currentColor" strokeWidth="2" strokeLinejoin="round" strokeLinecap="round" /></> : candles.map((c, i) => <g key={c.t} className={c.c >= c.o ? 'positive' : 'negative'}><line x1={x(i)} y1={y(c.h)} x2={x(i)} y2={y(c.l)} stroke="currentColor" strokeWidth="1" /><rect x={x(i) - Math.max(1, chartW / candles.length * .65) / 2} y={Math.min(y(c.o), y(c.c))} width={Math.max(1, chartW / candles.length * .65)} height={Math.max(1.2, Math.abs(y(c.c) - y(c.o)))} rx=".4" fill="currentColor" /></g>)}
      {Array.from({ length: 5 }, (_, i) => { const index = Math.round((candles.length - 1) * i / 4); return <text key={i} className="chart-axis" x={x(index)} y={H - 5} textAnchor={i === 0 ? 'start' : i === 4 ? 'end' : 'middle'}>{new Date(candles[index].t * 1000).toLocaleTimeString('en-GB', { hour: '2-digit', minute: '2-digit' })}</text>; })}
      {hoverIndex !== null && hovered && <><line x1={x(hoverIndex)} y1={top} x2={x(hoverIndex)} y2={top + chartH} className="chart-crosshair" /><circle cx={x(hoverIndex)} cy={y(hovered.c)} r="4" fill="currentColor" stroke="var(--invest-card)" strokeWidth="2" /></>}
    </svg>
    {hovered && <div className="chart-tooltip"><strong>{money(hovered.c)}</strong><span>{new Date(hovered.t * 1000).toLocaleString('en-GB', { day: '2-digit', month: 'short', hour: '2-digit', minute: '2-digit' })}</span></div>}
  </div>;
}
