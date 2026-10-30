// Bank providers a player can pick in Phone Setup (settings.bank). The choice only changes
// the Bank app's branding and colours; the account behind it is the same Wallet backend.
export const BANKS = [
    {
        id: 'fleeca',
        name: 'Fleeca',
        lines: ['FLEECA', 'BANK'],
        tagline: 'Banking that grows with you',
        colors: { deep: '#0f5a32', base: '#1e8a4c', top: '#1a7d44', light: '#55c784', ink: '#0f4a2a', soft: '#54a878', search: 'rgba(8, 56, 30, 0.55)', glow: 'rgba(30, 138, 76, 0.45)' },
    },
    {
        id: 'pacific',
        name: 'Pacific',
        lines: ['PACIFIC', 'STANDARD'],
        tagline: 'The bank of Los Santos',
        colors: { deep: '#1d4f9c', base: '#3266bd', top: '#2c5fb4', light: '#3fa0e8', ink: '#1d3e78', soft: '#5a83c8', search: 'rgba(18, 48, 104, 0.55)', glow: 'rgba(50, 102, 189, 0.45)' },
    },
    {
        id: 'paleto',
        name: 'Paleto',
        lines: ['PALETO', 'BANK'],
        tagline: 'Blaine County’s hometown bank',
        colors: { deep: '#7e1419', base: '#bf2f37', top: '#ad252d', light: '#ef6a6e', ink: '#6e1217', soft: '#c85a60', search: 'rgba(84, 12, 16, 0.55)', glow: 'rgba(191, 47, 55, 0.45)' },
    },
];

export const DEFAULT_BANK = 'pacific';

export const isBank = (id) => BANKS.some((b) => b.id === id);

export const getBank = (id) => BANKS.find((b) => b.id === id) || BANKS.find((b) => b.id === DEFAULT_BANK);

// CSS custom properties consumed by bank.css and PhoneSetup.css.
export const bankVars = (bank) => {
    const c = bank.colors;
    return {
        '--bank-deep': c.deep,
        '--bank-base': c.base,
        '--bank-top': c.top,
        '--bank-light': c.light,
        '--bank-ink': c.ink,
        '--bank-soft': c.soft,
        '--bank-search': c.search,
        '--bank-glow': c.glow,
        '--accent': c.base,
    };
};

export function BankMark({ bank, className = '' }) {
    const c = bank.colors;
    if (bank.id === 'fleeca') {
        return (
            <svg viewBox="0 0 40 40" className={className}>
                <circle cx="20" cy="20" r="18" fill={c.deep} />
                <path d="M11 29C11 17 18 10 30 10 30 22 23 29 11 29z" fill={c.light} />
                <path d="M12.5 27.5 26 14" stroke="#fff" strokeWidth="2.4" strokeLinecap="round" />
            </svg>
        );
    }
    if (bank.id === 'paleto') {
        return (
            <svg viewBox="0 0 40 40" className={className}>
                <path d="M20 3 35 8v11c0 9-6.5 15.5-15 18C11.5 34.5 5 28 5 19V8z" fill={c.deep} />
                <path d="M20 9 28.5 24h-17z" fill={c.light} />
                <path d="M20 14 25 23h-10z" fill="#fff" />
                <path d="M18.5 24h3v5h-3z" fill="#fff" />
            </svg>
        );
    }
    return (
        <svg viewBox="0 0 40 40" className={className}>
            <path d="M20 2 38 20 20 38 2 20z" fill={c.deep} />
            <path d="M20 9 31 20 20 31 9 20z" fill={c.light} />
            <path d="M16 13h7a5 5 0 0 1 0 10h-3v5h-4z" fill="#fff" />
        </svg>
    );
}

export function BankLogo({ bank }) {
    return (
        <span className="bank-logo">
            <BankMark bank={bank} className="bank-logo__mark" />
            <span className="bank-logo__text">
                {bank.lines[0]}
                <br />
                {bank.lines[1]}
            </span>
        </span>
    );
}
