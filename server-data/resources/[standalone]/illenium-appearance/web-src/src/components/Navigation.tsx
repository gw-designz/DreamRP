import React from 'react';
import { KeyCap } from './ui';

export const MAIN_TABS = [
  'FACE & BODY',
  'FACE ADJUSTMENTS',
  'OVERLAYS',
  'HAIR',
  'APPAREL',
  'TATTOOS'
];

export default function Navigation({
  tabs = MAIN_TABS,
  activeMainTab,
  onSelectTab
}: {
  tabs?: string[];
  activeMainTab: number;
  onSelectTab: (idx: number, tab: string) => void;
}) {
  if (tabs.length === 0) return null;
  const showQandE = tabs.length > 1;

  const step = (dir: number) => {
    const next = Math.min(Math.max(activeMainTab + dir, 0), tabs.length - 1);
    if (next !== activeMainTab) onSelectTab(next, tabs[next]);
  };

  return (
    <div className="flex items-center gap-3 pointer-events-auto">
      {showQandE && (
        <button type="button" onClick={() => step(-1)} className="np-panel w-[50px] h-[50px] flex items-center justify-center cursor-pointer">
          <KeyCap>Q</KeyCap>
        </button>
      )}

      {tabs.map((tab, index) => (
        <button
          key={tab}
          type="button"
          onClick={() => onSelectTab(index, tab)}
          className={`
            h-[50px] px-6 font-np font-bold italic text-[24px] uppercase leading-none transition-colors cursor-pointer
            ${activeMainTab === index
              ? 'bg-white text-black'
              : 'np-panel text-white hover:bg-[var(--np-panel-hover)]'}
          `}
        >
          {tab}
        </button>
      ))}

      {showQandE && (
        <button type="button" onClick={() => step(1)} className="np-panel w-[50px] h-[50px] flex items-center justify-center cursor-pointer">
          <KeyCap>E</KeyCap>
        </button>
      )}
    </div>
  );
}
