// Home-screen icon art for every app id, in the NoPixel style:
// rounded-square tile, glossy gradient background, one centred glyph.
import {
    faBuildingColumns,
    faBusinessTime,
    faCalendar,
    faWarehouse,
    faCarSide,
    faIdCard,
    faImage,
    faHouse,
    faBuilding,
    faKey,
    faGear,
    faMapLocationDot,
    faClock,
    faEnvelope,
    faCalculator,
    faStore,
    faPhone,
    faMessage,
    faAddressBook,
    faCamera,
    faPeopleGroup,
    faBug,
    faCalendarDays,
} from '@fortawesome/free-solid-svg-icons';
import FaIcon from './FaIcon';

const CryptoGlyph = () => (
    <svg viewBox="0 0 100 100" className="np-glyph-svg">
        <rect x="8" y="8" width="84" height="84" rx="14" fill="none" stroke="currentColor" strokeWidth="7" opacity="0.9" />
        <path d="M66 33A24 24 0 1 0 66 67" fill="none" stroke="currentColor" strokeWidth="12" strokeLinecap="round" />
        <path d="M80 14l6 14-15 1z" fill="currentColor" />
        <path d="M20 86l-6-14 15-1z" fill="currentColor" />
    </svg>
);

const NewsGlyph = () => (
    <svg viewBox="0 0 100 60" className="np-glyph-svg np-glyph-svg--news">
        <rect x="0" y="12" width="56" height="34" fill="#d0021b" />
        <text x="28" y="38.5" textAnchor="middle" fontFamily="'Barlow Condensed', Arial, sans-serif" fontWeight="800" fontSize="26" fill="#fff">
            NEWS
        </text>
        <rect x="60" y="13" width="40" height="5" fill="#111" />
        <rect x="60" y="22.5" width="40" height="5" fill="#111" />
        <rect x="60" y="32" width="40" height="5" fill="#111" />
        <rect x="60" y="41.5" width="40" height="5" fill="#111" />
    </svg>
);

const ScooterGlyph = () => (
    <svg viewBox="0 0 100 100" className="np-glyph-svg">
        <g fill="none" stroke="currentColor" strokeWidth="7" strokeLinecap="round">
            <path d="M60 14h16" />
            <path d="M69 15L78 68" />
            <path d="M28 72h46" />
        </g>
        <circle cx="24" cy="74" r="10" fill="none" stroke="currentColor" strokeWidth="7" />
        <circle cx="80" cy="74" r="10" fill="none" stroke="currentColor" strokeWidth="7" />
    </svg>
);

const LemonGlyph = () => (
    <svg viewBox="0 0 100 100" className="np-glyph-svg">
        <circle cx="48" cy="54" r="34" fill="none" stroke="currentColor" strokeWidth="9" />
        <path d="M58 22c4-10 14-14 24-12-2 10-10 16-20 16" fill="currentColor" />
    </svg>
);

const SocialsGlyph = () => (
    <svg viewBox="0 0 100 100" className="np-glyph-svg">
        <defs>
            <linearGradient id="np-soc-g" x1="0" y1="0" x2="0" y2="1">
                <stop offset="0" stopColor="#4fc3ff" />
                <stop offset="1" stopColor="#1e88e5" />
            </linearGradient>
        </defs>
        <path d="M14 22a12 12 0 0 1 12-12h48a12 12 0 0 1 12 12v34a12 12 0 0 1-12 12H40L22 84v-16a12 12 0 0 1-8-11z" fill="url(#np-soc-g)" />
        <rect x="30" y="31" width="40" height="7" rx="3.5" fill="#fff" />
        <rect x="30" y="45" width="26" height="7" rx="3.5" fill="#fff" />
    </svg>
);

const PropertyGlyph = () => (
    <span className="np-dual">
        <FaIcon icon={faHouse} />
        <FaIcon icon={faBuilding} />
    </span>
);

const EventsGlyph = () => (
    <span className="np-badged">
        <FaIcon icon={faCalendarDays} />
        <span className="np-badged__b">
            <FaIcon icon={faClock} />
        </span>
    </span>
);

const fa = (icon) => () => <FaIcon icon={icon} />;

const DARK = 'linear-gradient(160deg, #3a3d42 0%, #1c1e21 100%)';
const MUTED = '#c5c9ce';

// bg = tile background, color = glyph colour, Glyph = renderer, scale = glyph size vs tile.
export const NP_ICONS = {
    wallet: { bg: 'linear-gradient(170deg, #5af06f 0%, #12a02e 100%)', color: '#fff', Glyph: fa(faBuildingColumns) },
    business: { bg: 'linear-gradient(170deg, #1e3fa8 0%, #3c8cff 100%)', color: '#fff', Glyph: fa(faBusinessTime) },
    calendar: { bg: DARK, color: MUTED, Glyph: fa(faCalendar), scale: 0.48 },
    greybook: { bg: 'linear-gradient(170deg, #ffffff 0%, #e8eef0 100%)', color: '#1ba39c', Glyph: fa(faPeopleGroup), scale: 0.6 },
    crypto: { bg: 'linear-gradient(160deg, #3a0f7a 0%, #8b2cf5 100%)', color: '#fff', Glyph: CryptoGlyph, scale: 0.66 },
    garage: { bg: DARK, color: MUTED, Glyph: fa(faWarehouse) },
    government: { bg: 'linear-gradient(170deg, #5b9bff 0%, #2f63e8 100%)', color: '#fff', Glyph: fa(faBuildingColumns), scale: 0.6 },
    guber: { bg: 'linear-gradient(170deg, #3d7fe0 0%, #1b4a9c 100%)', color: '#fff', Glyph: fa(faCarSide), scale: 0.62 },
    marketplace: { bg: 'linear-gradient(150deg, #c8f23a 0%, #f2ea2a 100%)', color: '#0d0d0d', Glyph: LemonGlyph, scale: 0.62 },
    licenses: { bg: DARK, color: '#e9ecef', Glyph: fa(faIdCard) },
    news: { bg: '#fff', color: '#111', Glyph: NewsGlyph, scale: 0.84 },
    photos: { bg: DARK, color: MUTED, Glyph: fa(faImage), scale: 0.5 },
    property: { bg: 'linear-gradient(170deg, #9a6bff 0%, #5a3ee6 100%)', color: '#fff', Glyph: PropertyGlyph, scale: 0.66 },
    realestate: { bg: 'linear-gradient(150deg, #ef5b84 0%, #4a2462 100%)', color: '#fff', Glyph: fa(faKey) },
    scoote: { bg: 'linear-gradient(170deg, #31d4d8 0%, #68eaf2 100%)', color: '#0b0b0b', Glyph: ScooterGlyph, scale: 0.6 },
    settings: { bg: 'linear-gradient(170deg, #cfe6ff 0%, #9fc9f7 100%)', color: '#060606', Glyph: fa(faGear) },
    twexa: { bg: '#fff', color: '#fff', Glyph: SocialsGlyph, scale: 0.72 },
    roach: { bg: 'linear-gradient(170deg, #e2efff 0%, #a9cdf6 100%)', color: '#111', Glyph: fa(faBug), scale: 0.58 },
    calculator: { bg: DARK, color: MUTED, Glyph: fa(faCalculator), scale: 0.46 },
    events: { bg: 'linear-gradient(170deg, #67a7ff 0%, #7a3cf0 100%)', color: '#fff', Glyph: EventsGlyph, scale: 0.6 },
    maps: { bg: 'linear-gradient(170deg, #22c3a0 0%, #0f7e8c 100%)', color: '#fff', Glyph: fa(faMapLocationDot) },
    clock: { bg: DARK, color: '#ff9f0a', Glyph: fa(faClock) },
    mail: { bg: 'linear-gradient(170deg, #48a8ff 0%, #1462d6 100%)', color: '#fff', Glyph: fa(faEnvelope), scale: 0.5 },
    appstore: { bg: 'linear-gradient(170deg, #3d9cff 0%, #1659e0 100%)', color: '#fff', Glyph: fa(faStore), scale: 0.5 },
    call: { bg: 'linear-gradient(170deg, #45e05f 0%, #109a2c 100%)', color: '#fff', Glyph: fa(faPhone), scale: 0.5 },
    message: { bg: 'linear-gradient(170deg, #45e05f 0%, #109a2c 100%)', color: '#fff', Glyph: fa(faMessage), scale: 0.5 },
    camera: { bg: DARK, color: MUTED, Glyph: fa(faCamera), scale: 0.5 },
    contacts: { bg: 'linear-gradient(170deg, #d4d7dc 0%, #9a9fa7 100%)', color: '#fff', Glyph: fa(faAddressBook), scale: 0.5 },
};

const ApertureGlyph = () => (
    <svg viewBox="0 0 24 24" className="fa-svg" fill="none" stroke="currentColor" strokeWidth="2">
        <circle cx="12" cy="12" r="9.5" />
        <path d="M12 2.5l4.2 7.3M21.3 9.5l-8.4 0M19 18.5l-4.2-7.3M12 21.5l-4.2-7.3M2.7 14.5h8.4M5 5.5l4.2 7.3" />
    </svg>
);

// Dock glyphs (no tile, muted grey glyph only).
export const DOCK_GLYPHS = {
    call: faPhone,
    message: faMessage,
    contacts: faAddressBook,
    appstore: faStore,
    camera: ApertureGlyph,
};

export function NpAppIcon({ id, iconUrl, label }) {
    const def = NP_ICONS[id];
    if (!def) {
        // Third-party / unknown app: use its own image, or a neutral letter tile.
        return (
            <span className="np-icon np-icon--img" style={{ background: DARK }}>
                {iconUrl ? <img src={iconUrl} alt="" /> : <span className="np-icon__letter">{(label || id || '?').charAt(0)}</span>}
            </span>
        );
    }
    const { bg, color, Glyph, scale = 0.56 } = def;
    return (
        <span className="np-icon" style={{ background: bg, color, '--glyph': scale }}>
            <span className="np-icon__glyph">
                <Glyph />
            </span>
        </span>
    );
}
