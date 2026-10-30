// Config.UI.HomeStyle: 'duo' (iPhone Duo foldable), 'nopixel' or 'ios'.
export const isDuo = (homeStyle) => homeStyle === 'duo';

// The iPhone-looking skins use the original iOS app screens (registry `ios` variants).
export const usesIosApps = (homeStyle) => homeStyle === 'ios' || homeStyle === 'duo';

// Titanium finishes for the Duo frame (Config.UI.Finish).
export const FINISHES = ['natural', 'black', 'white', 'desert'];
export const finishOf = (v) => (FINISHES.includes(v) ? v : 'natural');

// Wallpaper shown until the player picks their own in Settings.
export const DUO_WALLPAPER = 'duoAurora';
