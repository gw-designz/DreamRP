import React from 'react';
import { Check, ChevronDown, ChevronLeft, ChevronUp } from 'lucide-react';

// Shared building blocks for the NoPixel-style menu, so every screen uses the same
// header, cards, sections and tabs.

export function KeyCap({ children, className = '' }: { children: React.ReactNode; className?: string }) {
  return (
    <span
      className={`inline-flex items-center justify-center min-w-[24px] h-[24px] px-1 bg-white text-black rounded-[3px] font-np font-bold not-italic text-[14px] leading-none flex-shrink-0 ${className}`}
    >
      {children}
    </span>
  );
}

export function BackButton({ onClick }: { onClick: () => void }) {
  return (
    <button
      type="button"
      onClick={onClick}
      title="Back"
      className="w-9 h-9 bg-white text-black flex items-center justify-center hover:bg-zinc-200 transition-colors cursor-pointer flex-shrink-0"
    >
      <ChevronLeft className="w-6 h-6" strokeWidth={3} />
    </button>
  );
}

/** "< APPAREL  CLOTHING  TOPS" - grey root title followed by white breadcrumbs. */
export function PageHeader({ navPath, setNavPath }: { navPath: string[]; setNavPath: (path: string[]) => void }) {
  const [root, ...crumbs] = navPath;
  return (
    <div className="flex items-center gap-4 h-[56px] mb-2 whitespace-nowrap min-w-max">
      {navPath.length > 1 && <BackButton onClick={() => setNavPath(navPath.slice(0, -1))} />}
      <button
        type="button"
        onClick={() => navPath.length > 1 && setNavPath([root])}
        className={`np-title text-[54px] uppercase ${navPath.length > 1 ? 'cursor-pointer hover:text-white' : 'cursor-default'}`}
      >
        {root}
      </button>
      <div className="flex items-center gap-4 pt-2">
        {crumbs.map((seg, i) => {
          const isLast = i === crumbs.length - 1;
          return (
            <button
              key={`${seg}-${i}`}
              type="button"
              onClick={() => !isLast && setNavPath(navPath.slice(0, i + 2))}
              className={`font-np font-bold italic text-[24px] uppercase leading-none text-white ${isLast ? 'cursor-default' : 'cursor-pointer hover:text-white/70'}`}
            >
              {seg}
            </button>
          );
        })}
      </div>
    </div>
  );
}

export function PriceTag({ price, isFree }: { price: number; isFree?: boolean }) {
  return (
    <span className="flex items-center gap-[3px] flex-shrink-0 leading-none">
      <span className="w-[16px] h-[16px] flex items-center justify-center bg-[var(--np-cash)] text-black font-np font-bold not-italic text-[13px]">
        $
      </span>
      <span className="font-np font-bold italic text-[17px] text-[var(--np-cash)]">{isFree ? 'FREE' : price.toLocaleString()}</span>
    </span>
  );
}

/** Thumbnail tile: studio-grey picture, name + price strip, white count badge, cyan when worn. */
export function ItemCard({
  name,
  price,
  isFree,
  active,
  badge,
  onClick,
  children,
}: {
  name: string;
  price?: number;
  isFree?: boolean;
  active?: boolean;
  badge?: React.ReactNode;
  onClick?: () => void;
  children?: React.ReactNode;
}) {
  return (
    <button
      type="button"
      onClick={onClick}
      className="np-card group relative w-full aspect-[155/113] overflow-hidden cursor-pointer text-left outline-none"
    >
      <div className="absolute inset-0 flex items-center justify-center pt-1 pb-6 px-2">{children}</div>

      {badge !== undefined && badge !== null && (
        <span className="absolute top-1.5 right-1.5 min-w-[18px] h-[18px] px-1 bg-white text-black font-np font-bold text-[13px] leading-none flex items-center justify-center">
          {badge}
        </span>
      )}

      <div className="absolute inset-x-0 bottom-0 h-[24px] flex items-center justify-between gap-1.5 pl-2 pr-1.5 bg-gradient-to-t from-black/60 to-black/20">
        <span className="truncate font-np font-semibold text-[13px] text-white leading-none">{name}</span>
        {active ? (
          <Check className="w-4 h-4 flex-shrink-0 text-[var(--accent-color)]" strokeWidth={3} />
        ) : price !== undefined ? (
          <PriceTag price={price} isFree={isFree} />
        ) : null}
      </div>

      <span
        className={`absolute inset-0 pointer-events-none border-2 transition-colors ${
          active ? 'border-[var(--accent-color)]' : 'border-transparent group-hover:border-white'
        }`}
      />
    </button>
  );
}

/** White collapsible bar ("TEXTURES ^") with a dark body. */
export function Section({
  title,
  open,
  onToggle,
  right,
  children,
}: {
  title: string;
  open: boolean;
  onToggle?: () => void;
  right?: React.ReactNode;
  children?: React.ReactNode;
}) {
  return (
    <div className="flex flex-col">
      <button
        type="button"
        onClick={onToggle}
        className="h-[28px] flex items-center justify-between gap-2 px-3 bg-white text-black font-np font-bold italic text-[16px] uppercase leading-none cursor-pointer"
      >
        <span className="truncate">{title}</span>
        <span className="flex items-center gap-2">
          {right}
          {onToggle && (open ? <ChevronUp className="w-5 h-5" strokeWidth={2.5} /> : <ChevronDown className="w-5 h-5" strokeWidth={2.5} />)}
        </span>
      </button>
      {open && <div className="bg-black/45 p-1.5">{children}</div>}
    </div>
  );
}

/** Equal-width tab row used at the top of the customization panel. */
export function TabBar({ tabs, active, onSelect }: { tabs: string[]; active: string; onSelect: (tab: string) => void }) {
  return (
    <div className="flex gap-1">
      {tabs.map((tab) => (
        <button
          key={tab}
          type="button"
          onClick={() => onSelect(tab)}
          className={`flex-1 h-[36px] px-2 font-np font-bold italic text-[18px] uppercase leading-none truncate transition-colors cursor-pointer ${
            active === tab ? 'bg-white text-black' : 'np-panel text-white hover:bg-[var(--np-panel-hover)]'
          }`}
        >
          {tab}
        </button>
      ))}
    </div>
  );
}

/** Square icon button of the left-hand category columns. */
export function IconTile({
  active,
  title,
  onClick,
  children,
}: {
  active?: boolean;
  title?: string;
  onClick?: () => void;
  children: React.ReactNode;
}) {
  return (
    <button
      type="button"
      title={title}
      onClick={onClick}
      className={`w-[54px] h-[54px] flex items-center justify-center flex-shrink-0 transition-colors cursor-pointer ${
        active ? 'bg-white text-black' : 'np-panel text-white/40 hover:text-white hover:bg-[var(--np-panel-hover)]'
      }`}
    >
      {children}
    </button>
  );
}

export function titleCase(label: string) {
  return label.toLowerCase().replace(/(^|[\s&/-])([a-z])/g, (_, sep, ch) => sep + ch.toUpperCase());
}
