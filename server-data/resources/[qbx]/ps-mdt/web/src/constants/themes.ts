// Personal color themes, picked per officer in Preferences and kept in their
// browser storage. "department" means no override: the colors set in
// Management > Colors apply. The others keep the black / graphite plates and
// swap the accent (RGB triplets, as the --*-rgb variables take them).

export interface PersonalTheme {
	id: string;
	name: string;
	accent: string;
	accentText: string;
	buttonPrimary: string;
}

export const DEPARTMENT_THEME = "department";

export const PERSONAL_THEMES: PersonalTheme[] = [
	{ id: "red", name: "Red", accent: "255, 36, 58", accentText: "255, 128, 140", buttonPrimary: "200, 28, 46" },
	{ id: "blue", name: "Blue", accent: "59, 130, 246", accentText: "147, 197, 253", buttonPrimary: "37, 99, 235" },
	{ id: "green", name: "Green", accent: "34, 197, 94", accentText: "134, 239, 172", buttonPrimary: "22, 163, 74" },
	{ id: "pink", name: "Pink", accent: "255, 64, 160", accentText: "255, 160, 205", buttonPrimary: "219, 39, 119" },
	{ id: "purple", name: "Purple", accent: "168, 85, 247", accentText: "216, 180, 254", buttonPrimary: "126, 34, 206" },
	{ id: "orange", name: "Orange", accent: "255, 128, 0", accentText: "255, 190, 120", buttonPrimary: "234, 88, 12" },
	{ id: "gold", name: "Gold", accent: "250, 204, 21", accentText: "253, 230, 138", buttonPrimary: "202, 138, 4" },
	{ id: "cyan", name: "Cyan", accent: "6, 214, 230", accentText: "165, 243, 252", buttonPrimary: "8, 145, 178" },
	{ id: "white", name: "White", accent: "230, 232, 236", accentText: "255, 255, 255", buttonPrimary: "110, 114, 122" },
];

export const PERSONAL_BACKGROUND = { background: "12, 12, 14", cardBackground: "18, 18, 21" };

export function findPersonalTheme(id: string | null | undefined): PersonalTheme | undefined {
	return PERSONAL_THEMES.find((t) => t.id === id);
}
