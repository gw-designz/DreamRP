import { useSelector } from 'react-redux';
import './ControlLegend.css';

const EnterGlyph = () => (
    <svg viewBox="0 0 24 24" className="np-legend__svg">
        <path
            d="M19 5v7.5H7.5"
            fill="none"
            stroke="currentColor"
            strokeWidth="2.6"
            strokeLinecap="square"
        />
        <path d="M9.5 8.5 5 12.5l4.5 4z" fill="currentColor" />
    </svg>
);

const BackGlyph = () => (
    <svg viewBox="0 0 24 24" className="np-legend__svg">
        <path d="M20 12H8" fill="none" stroke="currentColor" strokeWidth="2.6" />
        <path d="M10 7.5 4.5 12l5.5 4.5z" fill="currentColor" />
    </svg>
);

function Row({ cap, wide, label }) {
    return (
        <div className="np-legend__row">
            <span className={`np-legend__cap${wide ? ' np-legend__cap--wide' : ''}`}>{cap}</span>
            <span className="np-legend__label">{label}</span>
        </div>
    );
}

export default function ControlLegend() {
    const ui = useSelector((s) => s.phone.ui);
    const folded = useSelector((s) => s.phone.folded);
    const hints = useSelector((s) => s.settings.hints);
    if (!ui.legend || hints === false) return null;
    const keys = ui.keys || {};
    return (
        <div className="np-legend" aria-hidden>
            {ui.foldable && (
                <Row cap={keys.fold || 'T'} label={folded ? 'UNFOLD' : 'FOLD'} />
            )}
            <Row cap={keys.home || 'Y'} label="HOME" />
            <Row cap={<EnterGlyph />} label="SELECT" />
            <Row cap={<BackGlyph />} label="BACK" />
            <Row cap="ESC" wide label="CLOSE" />
        </div>
    );
}
