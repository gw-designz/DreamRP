import { fetchNui } from "@/utils/fetchNui";
import { NUI_EVENTS } from "@/constants/nuiEvents";
import { debugError } from "@/utils/debug";
import { DEPARTMENT_THEME, PERSONAL_BACKGROUND, findPersonalTheme } from "@/constants/themes";

export interface ColorConfig {
	accent: string;
	accentText: string;
	background: string;
	cardBackground: string;
	buttonPrimary: string;
}

const PREFERENCES_KEY = "ps-mdt-preferences";

// The officer's own theme from Preferences (saved with the rest of them).
function savedPersonalTheme(): string {
	try {
		const theme = JSON.parse(localStorage.getItem(PREFERENCES_KEY) || "{}").theme;
		return findPersonalTheme(theme) ? theme : DEPARTMENT_THEME;
	} catch {
		return DEPARTMENT_THEME;
	}
}

export function createSettingsService() {
	let colorConfig = $state<ColorConfig | null>(null);
	let isLoading = $state(false);
	let error = $state<string | null>(null);
	let personalTheme = $state(savedPersonalTheme());

	// Department colors first (Management > Colors, or the stylesheet defaults
	// when none are saved), then the officer's personal theme over them.
	function applyThemeColors(config: ColorConfig | null) {
		const root = document.documentElement;
		const set = (name: string, value: string | undefined, wrap: boolean) => {
			if (value) root.style.setProperty(name, wrap ? `rgb(${value})` : value);
			else root.style.removeProperty(name);
		};
		const personal = findPersonalTheme(personalTheme);
		const c = personal ? { ...PERSONAL_BACKGROUND, ...personal } : config;
		set("--accent-rgb", c?.accent, false);
		set("--accent-text-rgb", c?.accentText, false);
		set("--dark-bg", c?.background, true);
		set("--card-dark-bg", c?.cardBackground, true);
		set("--btn-primary", c?.buttonPrimary, true);
	}

	/** Shows a personal theme (or DEPARTMENT_THEME) without saving it. */
	function setPersonalTheme(id: string): void {
		personalTheme = findPersonalTheme(id) ? id : DEPARTMENT_THEME;
		applyThemeColors(colorConfig);
	}

	/** Back to whatever Preferences last saved. */
	function restoreSavedTheme(): void {
		setPersonalTheme(savedPersonalTheme());
	}

	applyThemeColors(null);

	async function loadColorConfig(): Promise<void> {
		if (isLoading) return;
		try {
			isLoading = true;
			error = null;
			const config = await fetchNui<ColorConfig | null>(
				NUI_EVENTS.SETTINGS.GET_COLOR_CONFIG,
				{},
				null,
			);

			if (config && config.accent) {
				colorConfig = config;
				applyThemeColors(config);
			}
		} catch (err) {
			error = "Failed to load color config";
			debugError("Failed to load color config:", err);
		} finally {
			isLoading = false;
		}
	}

	function setColorConfig(config: ColorConfig): void {
		colorConfig = config;
		applyThemeColors(config);
	}

	return {
		get colorConfig() {
			return colorConfig;
		},
		get isLoading() {
			return isLoading;
		},
		get error() {
			return error;
		},
		get personalTheme() {
			return personalTheme;
		},
		loadColorConfig,
		setColorConfig,
		setPersonalTheme,
		restoreSavedTheme,
	};
}

export const settingsService = createSettingsService();