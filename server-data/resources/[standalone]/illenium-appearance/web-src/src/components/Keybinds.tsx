import React from 'react';
import { KeyCap } from './ui';

const W = '#ffffff';

// Mouse with split top (left button / wheel / right button) over a U-shaped body; the part
// that does the action is filled.
const Mouse = ({ part }: { part: 'none' | 'left' | 'right' | 'wheel' | 'zoom' }) => (
  <svg viewBox="0 0 24 28" className="h-[26px] w-[22px] flex-shrink-0" fill="none" stroke={W} strokeWidth="1.5">
    <path d="M4 13.5V19a8 8 0 0 0 16 0v-5.5" />
    <path d="M4 12V7.5C4 6.1 5.1 5 6.5 5H9.8v7Z" fill={part === 'left' ? W : 'none'} />
    <path d="M20 12V7.5C20 6.1 18.9 5 17.5 5h-3.3v7Z" fill={part === 'right' ? W : 'none'} />
    <rect x="10.6" y="5.6" width="2.8" height="5.6" rx="1.4" fill={part === 'wheel' ? W : 'none'} />
    {part === 'zoom' && (
      <>
        <path d="M12 .6l2.4 2.6H9.6Z" fill={W} stroke="none" />
        <path d="M12 21.2l-2.4-2.8h4.8Z" fill={W} stroke="none" />
      </>
    )}
  </svg>
);

const DPad = () => (
  <svg viewBox="0 0 24 24" className="h-[24px] w-[24px] flex-shrink-0">
    <rect x="1" y="1" width="22" height="22" rx="2" fill={W} />
    <path d="M12 3.5l3 3.3H9zM12 20.5l-3-3.3h6zM3.5 12l3.3-3v6zM20.5 12l-3.3 3V9z" fill="#000" />
  </svg>
);

const EnterKey = () => (
  <svg viewBox="0 0 24 24" className="h-[24px] w-[24px] flex-shrink-0" fill="none">
    <rect x="1" y="1" width="22" height="22" rx="2" fill={W} />
    <path d="M17.5 12.5v4h-10" stroke="#000" strokeWidth="1.8" />
    <path d="M6.5 16.5l2.6-2.4v4.8Z" fill="#000" />
  </svg>
);

type Hint = { icon: React.ReactNode; label: string };

export default function Keybinds({ checkoutLabel, escLabel = 'EXIT' }: { checkoutLabel: string; escLabel?: string }) {
  const rows: Hint[][] = [
    [
      { icon: <Mouse part="none" />, label: 'MOVE CAMERA' },
      { icon: <Mouse part="right" />, label: 'ROTATE' },
      { icon: <Mouse part="zoom" />, label: 'ZOOM' },
      { icon: <Mouse part="left" />, label: 'FOCUS' },
    ],
    [
      { icon: <DPad />, label: 'MOVE' },
      { icon: <EnterKey />, label: 'SELECT' },
      { icon: <KeyCap>ESC</KeyCap>, label: escLabel },
      { icon: <KeyCap>TAB</KeyCap>, label: checkoutLabel },
    ],
  ];

  return (
    <div className="np-panel flex flex-col px-4">
      {rows.map((row, r) => (
        <div key={r} className={`flex items-center justify-between py-2.5 ${r > 0 ? 'border-t border-white/15' : ''}`}>
          {row.map((hint, i) => (
            <React.Fragment key={hint.label}>
              {i > 0 && <span className="font-np text-[20px] text-white/35 leading-none select-none">/</span>}
              <div className="flex items-center gap-2.5">
                {hint.icon}
                <span className="font-np font-bold italic text-[18px] text-white uppercase leading-none whitespace-nowrap">
                  {hint.label}
                </span>
              </div>
            </React.Fragment>
          ))}
        </div>
      ))}
    </div>
  );
}
