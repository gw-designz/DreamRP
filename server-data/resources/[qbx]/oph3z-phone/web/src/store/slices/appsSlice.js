import { createSlice } from '@reduxjs/toolkit';

// Fallback layout (browser preview / before Lua sends Config.Apps). Mirrors config.lua.
const DEFAULT_LAYOUT = [
    { id: 'wallet', label: 'Bank', place: 'grid', enabled: true },
    { id: 'business', label: 'Business', place: 'grid', enabled: true },
    { id: 'calendar', label: 'Calendar', place: 'grid', enabled: true },
    { id: 'greybook', label: 'Grey Book', place: 'grid', enabled: true },
    { id: 'crypto', label: 'Crypto', place: 'grid', enabled: true },
    { id: 'garage', label: 'Garage', place: 'grid', enabled: true },
    { id: 'government', label: 'Government', place: 'grid', enabled: true },
    { id: 'guber', label: 'Guber', place: 'grid', enabled: true },
    { id: 'marketplace', label: 'Lemon List', place: 'grid', enabled: true },
    { id: 'licenses', label: 'Licenses', place: 'grid', enabled: true },
    { id: 'news', label: 'Weazel', place: 'grid', enabled: true },
    { id: 'photos', label: 'Gallery', place: 'grid', enabled: true },
    { id: 'property', label: 'Property', place: 'grid', enabled: true },
    { id: 'realestate', label: 'Real Estate', place: 'grid', enabled: true },
    { id: 'scoote', label: 'Scoot-E', place: 'grid', enabled: true },
    { id: 'settings', label: 'Settings', place: 'grid', enabled: true },
    { id: 'twexa', label: 'Socials', place: 'grid', enabled: true },
    { id: 'roach', label: 'Roach', place: 'grid', enabled: true },
    { id: 'calculator', label: 'Calculator', place: 'grid', enabled: true },
    { id: 'events', label: 'Events', place: 'grid', enabled: true },
    { id: 'maps', label: 'Maps', place: 'grid', enabled: true },
    { id: 'clock', label: 'Clock', place: 'grid', enabled: true },
    { id: 'mail', label: 'Mail', place: 'grid', enabled: true },
    { id: 'call', label: 'Phone', place: 'dock', enabled: true },
    { id: 'message', label: 'Messages', place: 'dock', enabled: true },
    { id: 'contacts', label: 'Contacts', place: 'dock', enabled: true },
    { id: 'appstore', label: 'Store', place: 'dock', enabled: true },
    { id: 'camera', label: 'Camera', place: 'dock', enabled: true },
];

const initialState = {
    layout: DEFAULT_LAYOUT,
    external: [],
};

const appsSlice = createSlice({
    name: 'apps',
    initialState,
    reducers: {
        setLayout(state, action) {
            if (Array.isArray(action.payload) && action.payload.length)
                state.layout = action.payload;
        },
        setExternalApps(state, action) {
            state.external = Array.isArray(action.payload) ? action.payload : [];
        },
    },
});

export const { setLayout, setExternalApps } = appsSlice.actions;

export const selectExternalApp = (id) => (state) =>
    state.apps.external.find((a) => a.id === id) || null;

export default appsSlice.reducer;