// Apps drawn on a light background (Socials and the NoPixel app shells); the status bar
// and home indicator switch to dark glyphs over them.
const LIGHT = new Set(['twexa', 'government', 'news', 'events', 'property', 'greybook']);

export const isLightApp = (id) => LIGHT.has(id);
