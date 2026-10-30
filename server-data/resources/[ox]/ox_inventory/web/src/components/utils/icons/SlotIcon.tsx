import React from 'react';

const ICONS: Record<string, React.ReactNode> = {
  radio: (
    <>
      <rect x="7" y="8" width="10" height="13" rx="2" />
      <path d="M10 8V3M10 12h4M10 15h4" />
    </>
  ),
  tablet: (
    <>
      <rect x="6" y="3" width="12" height="18" rx="2" />
      <path d="M11 18h2" />
    </>
  ),
  idcard: (
    <>
      <rect x="3" y="6" width="18" height="12" rx="1.5" />
      <path d="M6 10h5M6 13h3M14 10h4M14 13h4" />
    </>
  ),
  bag: (
    <>
      <path d="M4 10c0-2 2-3 4-3h8c2 0 4 1 4 3v8H4z" />
      <path d="M9 7V5h6v2M4 13h16" />
    </>
  ),
  key: (
    <>
      <circle cx="8" cy="15" r="3.5" />
      <path d="M10.5 12.5L19 4M16 7l2 2M14 9l2 2" />
    </>
  ),
  parachute: <path d="M3 11a9 8 0 0 1 18 0H3zM3 11l8 9M21 11l-8 9M12 11v9" />,
  cards: (
    <>
      <rect x="4" y="9" width="14" height="9" rx="1.5" transform="rotate(-15 11 13)" />
      <path d="M8 6l10 3" />
    </>
  ),
  mask: (
    <>
      <path d="M4 5c5 1 11 1 16 0v6c0 5-3 8-8 8s-8-3-8-8V5z" />
      <path d="M8 10h2M14 10h2M9 15c2 1.5 4 1.5 6 0" />
    </>
  ),
  hat: <path d="M3 17h18M6 17c0-6 1-9 6-9s6 3 6 9M6 13.5h12" />,
  glasses: (
    <>
      <circle cx="7" cy="14" r="3.5" />
      <circle cx="17" cy="14" r="3.5" />
      <path d="M10.5 13.5h3M3.5 13L5 8M20.5 13L19 8" />
    </>
  ),
  glove: <path d="M8 21v-5l-3-4V8l2 1V4h2v5h1V3h2v6h1V5h2v6h1V8h2v7l-3 3v3z" />,
};

const SlotIcon: React.FC<{ name: string }> = ({ name }) => (
  <svg
    className="inventory-slot-placeholder"
    xmlns="http://www.w3.org/2000/svg"
    viewBox="0 0 24 24"
    fill="none"
    stroke="currentColor"
    strokeWidth="1.6"
    strokeLinecap="round"
    strokeLinejoin="round"
  >
    {ICONS[name]}
  </svg>
);

export default SlotIcon;
