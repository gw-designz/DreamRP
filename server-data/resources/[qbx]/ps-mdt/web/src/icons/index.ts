import icons from "./icons.generated.json";

type IconData = { body: string; viewBox: string };
const ICONS = icons as Record<string, IconData>;

function escapeText(s: string): string {
	return s.replace(/[&<>"']/g, (c) => `&#${c.charCodeAt(0)};`);
}

/**
 * Markup for an icon, used as `{@html ico("search")}` inside a
 * `<span class="material-icons">`. Names are the Material icon names the MDT
 * already uses; mapped ones render as bundled Solar (Iconify) SVGs, anything
 * else (e.g. award/category icons picked in settings) falls back to the
 * Material ligature so it still renders.
 */
export function ico(name: string | null | undefined): string {
	if (!name) return "";
	const icon = ICONS[name];
	if (!icon) return escapeText(name);
	return `<svg class="ico" xmlns="http://www.w3.org/2000/svg" viewBox="${icon.viewBox}" aria-hidden="true">${icon.body}</svg>`;
}

export function hasIcon(name: string): boolean {
	return name in ICONS;
}
