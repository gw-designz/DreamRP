import { createSlice } from '@reduxjs/toolkit';
import { fetchNui } from '../../utils/fetchNui';

// Defaults mirror Config.UI in config.lua; the real values arrive with phone:setVisible.
export const DEFAULT_UI = {
    homeStyle: 'duo', // 'duo' (iPhone Duo foldable) | 'nopixel' | 'ios'
    finish: 'natural', // Duo titanium: natural | black | white | desert
    lockScreen: false, // NoPixel phones open straight to the home screen
    foldable: true,
    startFolded: true,
    legend: true,
    phoneSetup: true, // first-open setup (bank provider) until settings.bank is set
    sounds: false, // GTA frontend UI sounds (Config.UI.Sounds)
    timeSource: 'real',
    clock24h: false,
    showLocation: true,
    keys: { fold: 'T', home: 'Y', tabLeft: 'Q', tabRight: 'E' },
};

const initialState = {
    visible: false,
    // 'open' while shown, 'closing' while the slide-out animation plays.
    phase: 'open',
    folded: true,
    ui: DEFAULT_UI,
    zone: '',
    statusTone: null, // 'light' | 'dark' override set by the open app (np/ui/kit useStatusTone)
    locked: true,
    activeApp: null,
    flashlightOn: false,
    controlCenterOpen: false,
    launchTab: null,
    identity: { number: '', numberRaw: '', citizenid: '', name: '', email: '', avatar: '' },
    time: {
        useGameTime: true,
        hours: 11,
        minutes: 34,
        day: 7,
        month: 6,
        weekday: 3,
        year: 2025,
        weather: 0,
        temperature: 70,
        tempUnit: 'F',
    },
};

const phoneSlice = createSlice({
    name: 'phone',
    initialState,
    reducers: {
        setVisible(state, action) {
            state.visible = action.payload;
            state.phase = 'open';
            if (action.payload) {
                state.locked = !!state.ui.lockScreen && state.locked;
            } else {
                state.locked = !!state.ui.lockScreen;
                state.activeApp = null;
                state.flashlightOn = false;
                state.controlCenterOpen = false;
            }
        },
        setPhase(state, action) {
            state.phase = action.payload;
        },
        setUi(state, action) {
            const p = action.payload || {};
            state.ui = { ...state.ui, ...p, keys: { ...state.ui.keys, ...(p.keys || {}) } };
        },
        setFolded(state, action) {
            state.folded = !!action.payload;
        },
        setZone(state, action) {
            state.zone = action.payload || '';
        },
        setFlashlight(state, action) {
            state.flashlightOn = action.payload;
        },
        setControlCenter(state, action) {
            state.controlCenterOpen = !!action.payload;
        },
        toggleControlCenter(state) {
            state.controlCenterOpen = !state.controlCenterOpen;
        },
        lock(state) {
            state.locked = true;
            state.activeApp = null;
            state.controlCenterOpen = false;
        },
        unlock(state) {
            state.locked = false;
        },
        openApp(state, action) {
            state.activeApp = action.payload;
            state.statusTone = null;
        },
        closeApp(state) {
            state.activeApp = null;
            state.statusTone = null;
        },
        setStatusTone(state, action) {
            state.statusTone = action.payload || null;
        },
        setLaunchTab(state, action) {
            state.launchTab = action.payload;
        },
        setIdentity(state, action) {
            state.identity = { ...state.identity, ...(action.payload || {}) };
        },
        setTime(state, action) {
            state.time = { ...state.time, ...action.payload };
        },
    },
});

export const {
    setVisible,
    setPhase,
    setUi,
    setFolded,
    setZone,
    setStatusTone,
    lock,
    unlock,
    openApp,
    closeApp,
    setTime,
    setFlashlight,
    setControlCenter,
    toggleControlCenter,
    setLaunchTab,
    setIdentity,
} = phoneSlice.actions;

export const saveProfileName = (name) => async (dispatch) => {
    const clean = (name || '').trim();
    if (!clean) return;
    dispatch(setIdentity({ name: clean }));
    await fetchNui('phone:profile:setName', { name: clean }, clean);
};

export const saveAvatar = (url) => async (dispatch) => {
    const clean = (url || '').trim();
    dispatch(setIdentity({ avatar: clean }));
    await fetchNui('phone:profile:setAvatar', { url: clean }, clean);
};

export default phoneSlice.reducer;