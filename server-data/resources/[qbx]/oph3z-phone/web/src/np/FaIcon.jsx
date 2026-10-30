// Renders a Font Awesome icon definition as inline SVG (no icon font, no runtime lib).
// Definitions come from @fortawesome/free-*-svg-icons: { icon: [w, h, _, _, path] }.
export default function FaIcon({ icon, className = '', style, title }) {
    if (!icon || !icon.icon) return null;
    const [w, h, , , path] = icon.icon;
    const paths = Array.isArray(path) ? path : [path];
    return (
        <svg
            className={`fa-svg ${className}`}
            viewBox={`0 0 ${w} ${h}`}
            style={style}
            fill="currentColor"
            aria-hidden={title ? undefined : true}
            role={title ? 'img' : undefined}
        >
            {title && <title>{title}</title>}
            {paths.map((d, i) => (
                <path key={i} d={d} opacity={paths.length > 1 && i === 0 ? 0.4 : undefined} />
            ))}
        </svg>
    );
}
