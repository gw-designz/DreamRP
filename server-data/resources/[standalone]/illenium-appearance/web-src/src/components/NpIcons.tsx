import React, { useId } from 'react';

// Solid glyphs redrawn to match the shop menu's icon set. All fill with currentColor so the
// white/black active states and the dimmed inactive tiles work like any other icon.

type IconProps = { className?: string };

const Svg = ({ className, children }: IconProps & { children: React.ReactNode }) => (
  <svg viewBox="0 0 24 24" fill="currentColor" className={`flex-shrink-0 ${className || ''}`} aria-hidden>
    {children}
  </svg>
);

/** Draws `children` with `cuts` punched out, so shapes get see-through gaps on any background. */
const Cut = ({ cuts, children }: { cuts: React.ReactNode; children: React.ReactNode }) => {
  const id = `np-cut-${useId().replace(/:/g, '')}`;
  return (
    <>
      <defs>
        <mask id={id} maskUnits="userSpaceOnUse" x="0" y="0" width="24" height="24">
          <rect width="24" height="24" fill="white" />
          <g fill="black" stroke="black">{cuts}</g>
        </mask>
      </defs>
      <g mask={`url(#${id})`}>{children}</g>
    </>
  );
};

export const IconTee = ({ className }: IconProps) => (
  <Svg className={className}>
    <path d="M8.6 3.2 3.7 5.2c-.5.2-.8.7-.7 1.2l.7 3.8h2.7v10c0 .4.3.7.7.7h9.8c.4 0 .7-.3.7-.7v-10h2.7l.7-3.8c.1-.5-.2-1-.7-1.2l-4.9-2c-.5 1.5-1.8 2.4-3.4 2.4S9.1 4.7 8.6 3.2Z" />
  </Svg>
);

export const IconLongSleeve = ({ className }: IconProps) => (
  <Svg className={className}>
    <path d="M8.4 3.2 6.9 3.8v16.7h10.2V3.8l-1.5-.6C15 4.6 13.7 5.4 12 5.4S9 4.6 8.4 3.2Z" />
    <path d="M6.1 4.1 4.3 4.9C3.2 5.4 2.6 6.4 2.6 7.6v11.4h3.5Z" />
    <path d="M17.9 4.1l1.8.8c1.1.5 1.7 1.5 1.7 2.7v11.4h-3.5Z" />
  </Svg>
);

/** Long-sleeve top with a "no" badge in the corner - takes the item off. */
export const IconRemoveClothing = ({ className }: IconProps) => (
  <Svg className={className}>
    <Cut cuts={<circle cx="18.2" cy="18.2" r="5.6" stroke="none" />}>
      <path d="M8 3.2 6.7 3.7v14.8h10.6V3.7L16 3.2c-.6 1.3-2.1 2.1-4 2.1S8.6 4.5 8 3.2Z" />
      <path d="M5.9 4l-1.7.8C3.2 5.3 2.6 6.2 2.6 7.3v9.6h3.3Z" />
      <path d="M18.1 4l1.7.8c1 .5 1.6 1.4 1.6 2.5v9.6h-3.3Z" />
    </Cut>
    <circle cx="18.2" cy="18.2" r="3.9" fill="none" stroke="currentColor" strokeWidth="1.3" />
    <path d="M15.5 15.5l5.4 5.4" stroke="currentColor" strokeWidth="1.3" />
  </Svg>
);

export const IconTank =({ className }: IconProps) => (
  <Svg className={className}>
    <path d="M7.8 2.5h1.4c.3 2.4 1.3 3.8 2.8 3.8s2.5-1.4 2.8-3.8h1.4l.4 4.6c.1 1.3 1.6 2.3 1.6 3.9v10.5H5.8V11c0-1.6 1.5-2.6 1.6-3.9Z" />
  </Svg>
);

export const IconShorts = ({ className }: IconProps) => (
  <Svg className={className}>
    <Cut cuts={<rect x="7" y="3" width="1.1" height="2.6" stroke="none" />}>
      <path d="M5.6 3h12.8v2.6H5.6Z" />
    </Cut>
    <path d="M5.6 6.6h12.8l1.2 12.4-6.2.5L12 11l-1.4 8.5-6.2-.5Z" />
  </Svg>
);

export const IconSneaker = ({ className }: IconProps) => (
  <Svg className={className}>
    <Cut
      cuts={
        <>
          <path d="M8.6 7.9l3.4 3.2" strokeWidth="1.3" fill="none" />
          <path d="M11.2 6l3.5 3.3" strokeWidth="1.3" fill="none" />
        </>
      }
    >
      <path d="M2.5 15.4v-4.6c0-.8.6-1.4 1.4-1.4h1.8l2.9-5.2c.4-.7 1.3-.8 1.8-.3l3.4 3.3c1.8 1.8 4.1 2.9 6.5 3.3.9.2 1.5.9 1.5 1.8v3.1Z" />
    </Cut>
    <Cut cuts={<path d="M7 16.4v3.2M12 16.4v3.2M17 16.4v3.2" strokeWidth=".9" fill="none" />}>
      <path d="M2.5 16.6h19v2.6h-19Z" />
    </Cut>
  </Svg>
);

export const IconScarf = ({ className }: IconProps) => (
  <Svg className={className}>
    <Cut cuts={<path d="M12.6 4.6l4.2 4.2" strokeWidth="1.3" fill="none" />}>
      <path d="M6.5 2h10v5.6L12.2 12H6.5Z" />
    </Cut>
    <g transform="rotate(40 8 16.5)">
      <path d="M5 13.4h6.4v3H5Z" />
      <path d="M5 17.2h1.6V21H5ZM7.4 17.2H9V21H7.4ZM9.8 17.2h1.6V21H9.8Z" />
    </g>
    <g transform="rotate(-40 16 16.5)">
      <path d="M12.6 13.4H19v3h-6.4Z" />
      <path d="M12.6 17.2h1.6V21h-1.6ZM15 17.2h1.6V21H15ZM17.4 17.2H19V21h-1.6Z" />
    </g>
  </Svg>
);

export const IconMitten = ({ className }: IconProps) => (
  <Svg className={className}>
    <Cut cuts={<path d="M15.1 8.6l-.5 3.4" strokeWidth="1.1" fill="none" />}>
      <path d="M11 2.2C8 2.2 6 4.4 6.2 7.4l.6 7.8h9.4l2.4-3.6c.7-1.1.4-2.6-.7-3.3-1-.6-2.3-.4-3 .5l-.3-2.2C14.3 4 12.9 2.2 11 2.2Z" />
    </Cut>
    <path d="M6.6 17h10v3.4h-10Z" />
  </Svg>
);

export const IconHeadGoggles = ({ className }: IconProps) => (
  <Svg className={className}>
    <Cut
      cuts={
        <>
          <rect x="8.9" y="5.1" width="13.2" height="7.2" rx="3.6" stroke="none" />
          <path d="M2 8.1h8" strokeWidth="1.3" fill="none" />
        </>
      }
    >
      <path d="M10.5 2C6.4 2 3.5 5 3.5 9c0 2.6 1.1 4.4 2.5 5.6V21h7.5v-2.4h1.9c1.1 0 1.9-.9 1.9-2v-2.2h1.5c.5 0 .8-.5.6-.9l-1.8-3.1C17.4 5.6 14.6 2 10.5 2Z" />
    </Cut>
    <Cut cuts={<rect x="12.2" y="7.6" width="6.6" height="2.2" rx="1.1" stroke="none" />}>
      <rect x="10" y="6.2" width="11" height="5" rx="2.5" />
    </Cut>
  </Svg>
);

export const IconWristwatch = ({ className }: IconProps) => (
  <Svg className={className}>
    <path d="M8.2 2h7.6l.8 4.2H7.4ZM7.4 17.8h9.2l-.8 4.2H8.2Z" />
    <path fillRule="evenodd" d="M12 5.4a6.6 6.6 0 1 1 0 13.2 6.6 6.6 0 0 1 0-13.2Zm0 2a4.6 4.6 0 1 0 0 9.2 4.6 4.6 0 0 0 0-9.2Z" />
    <path d="M11.3 8.6h1.4v3l1.9 1.6-.9 1-2.4-2Z" />
  </Svg>
);

export const IconBracelet = ({ className }: IconProps) => (
  <Svg className={className}>
    <path
      fillRule="evenodd"
      d="M2.5 10c0-2.5 4.3-4.4 9.5-4.4s9.5 1.9 9.5 4.4v4c0 2.5-4.3 4.4-9.5 4.4S2.5 16.5 2.5 14Zm2.5.2c0 1.3 3.1 2.4 7 2.4s7-1.1 7-2.4-3.1-2.4-7-2.4-7 1.1-7 2.4Z"
    />
  </Svg>
);
