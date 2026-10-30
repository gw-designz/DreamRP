import { fetchNui } from './fetchNui';

export type UiSound = 'hover' | 'click' | 'drop';

// Minimum time between two plays of the same sound, so quickly sweeping the cursor doesn't spam the client
const MIN_INTERVAL: Record<UiSound, number> = { hover: 50, click: 0, drop: 0 };
const lastPlayed: Partial<Record<UiSound, number>> = {};

/** Asks the client to play the matching native GTA frontend sound (mapped in client.lua). */
export const playSound = (sound: UiSound) => {
  const now = Date.now();

  if (now - (lastPlayed[sound] ?? 0) < MIN_INTERVAL[sound]) return;

  lastPlayed[sound] = now;
  fetchNui('uiSound', sound).catch(() => {});
};
