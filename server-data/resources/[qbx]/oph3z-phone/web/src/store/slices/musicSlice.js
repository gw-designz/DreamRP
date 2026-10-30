import { createSlice } from '@reduxjs/toolkit';

const initialState = {
    appId: null,
    title: '',
    artist: '',
    artwork: null,
    playing: false,
    position: 0,
    duration: 0,
    hasNext: false,
    hasPrev: false,
};

const musicSlice = createSlice({
    name: 'music',
    initialState,
    reducers: {
        setNowPlaying(state, action) {
            const d = action.payload;
            if (!d || !d.title) return initialState;
            return {
                appId: d.appId || null,
                title: d.title || '',
                artist: d.artist || '',
                artwork: d.artwork || null,
                playing: !!d.playing,
                position: d.position || 0,
                duration: d.duration || 0,
                hasNext: !!d.hasNext,
                hasPrev: !!d.hasPrev,
            };
        },
        setTrack(state, action) {
            return { ...state, ...(action.payload || {}) };
        },
        setPlaying(state, action) {
            state.playing = !!action.payload;
        },
        togglePlaying(state) {
            if (state.title) state.playing = !state.playing;
        },
        setPosition(state, action) {
            state.position = action.payload || 0;
        },
        clearTrack() {
            return initialState;
        },
    },
});

export const { setNowPlaying, setTrack, setPlaying, togglePlaying, setPosition, clearTrack } =
    musicSlice.actions;
export default musicSlice.reducer;