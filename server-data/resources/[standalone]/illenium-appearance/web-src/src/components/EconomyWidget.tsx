import React from 'react';

export default function EconomyWidget({ cash, bank }: { cash: number, bank: number }) {
  return (
    <div className="flex gap-1.5 font-np font-bold italic text-[28px] leading-none text-black pointer-events-auto select-none">
      <div className="h-[50px] flex items-center gap-1 px-4 bg-[var(--np-cash)]">
        <span>$</span>
        <span>{cash.toLocaleString()}</span>
      </div>
      <div className="h-[50px] flex items-center gap-2 px-4 bg-[var(--np-bank)]">
        <svg viewBox="0 0 24 24" fill="currentColor" width="24" height="24" className="flex-shrink-0">
          <path d="M12 2L2 7H22L12 2ZM2 9V20H4V9H2ZM6 9V20H8V9H6ZM10 9V20H12V9H10ZM14 9V20H16V9H14ZM18 9V20H20V9H18ZM2 22H22V24H2V22Z" />
        </svg>
        <span>${bank.toLocaleString()}</span>
      </div>
    </div>
  );
}
