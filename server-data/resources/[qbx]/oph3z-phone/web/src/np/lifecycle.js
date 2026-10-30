// Phone open/close/fold transitions. Lua owns NUI focus; this only sequences the visuals so
// a close always releases focus immediately while the slide-out animation finishes on its own.
import { fetchNui } from '../utils/fetchNui';
import { setPhase, setFolded } from '../store/slices/phoneSlice';
import { applySetting } from '../store/slices/settingsSlice';

export const CLOSE_MS = 240;

let closeTimer = null;

// notifyLua=true when the UI starts the close (Esc / Backspace on home); false when Lua
// already closed the phone and just told us to hide.
export const beginClose =
    ({ notifyLua, onDone }) =>
    (dispatch, getState) => {
        const { phone } = getState();
        if (!phone.visible || phone.phase === 'closing') return;
        if (notifyLua) fetchNui('phone:close', {}, {});
        dispatch(setPhase('closing'));
        clearTimeout(closeTimer);
        closeTimer = setTimeout(() => {
            closeTimer = null;
            onDone && onDone();
        }, CLOSE_MS);
    };

export const cancelClose = () => (dispatch) => {
    if (closeTimer) {
        clearTimeout(closeTimer);
        closeTimer = null;
    }
    dispatch(setPhase('open'));
};

export const toggleFold = () => (dispatch, getState) => {
    const { phone } = getState();
    if (!phone.ui.foldable || phone.phase !== 'open' || !phone.visible) return;
    const next = !phone.folded;
    dispatch(setFolded(next));
    dispatch(applySetting({ key: 'folded', value: next }));
    fetchNui('phone:saveSettings', { folded: next }, { ok: true });
};
