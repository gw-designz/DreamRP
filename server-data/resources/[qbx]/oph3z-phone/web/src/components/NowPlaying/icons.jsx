const S = ({ size = 24, children, fill = 'none', stroke = 'currentColor', sw = 2, ...p }) => (
    <svg
        width={size}
        height={size}
        viewBox="0 0 24 24"
        fill={fill}
        stroke={stroke}
        strokeWidth={sw}
        strokeLinecap="round"
        strokeLinejoin="round"
        aria-hidden
        {...p}
    >
        {children}
    </svg>
);

export const PlayIcon = (p) => (
    <S {...p} fill="currentColor" stroke="none">
        <path d="M7 4.5v15l13-7.5z" />
    </S>
);

export const PauseIcon = (p) => (
    <S {...p} fill="currentColor" stroke="none">
        <rect x="6" y="5" width="4" height="14" rx="1" />
        <rect x="14" y="5" width="4" height="14" rx="1" />
    </S>
);

export const NextIcon = (p) => (
    <S {...p} fill="currentColor" stroke="none">
        <path d="M5 5v14l10-7z" />
        <rect x="17" y="5" width="3" height="14" rx="1" />
    </S>
);

export const PrevIcon = (p) => (
    <S {...p} fill="currentColor" stroke="none">
        <path d="M19 5v14L9 12z" />
        <rect x="4" y="5" width="3" height="14" rx="1" />
    </S>
);

export const NoteIcon = (p) => (
    <S {...p}>
        <path d="M9 18V5l12-2v13" />
        <circle cx="6" cy="18" r="3" />
        <circle cx="18" cy="16" r="3" />
    </S>
);

export const Waveform = ({ size = 18, on = true }) => (
    <span className={`np-wave${on ? ' is-on' : ''}`} style={{ height: size }} aria-hidden>
        <i />
        <i />
        <i />
        <i />
    </span>
);