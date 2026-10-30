import { useSelector } from 'react-redux';
import { useNow } from '../hooks/useNow';

// One clock for the status bar and the home screen.
// Config.UI.TimeSource: 'real' = the player's local clock (the phone's original behaviour),
// 'game' = GTA world time pushed every second by client/main.lua (phone:time).
export function usePhoneClock() {
    const source = useSelector((s) => s.phone.ui.timeSource);
    const h24 = useSelector((s) => s.phone.ui.clock24h);
    const game = useSelector((s) => s.phone.time);
    const now = useNow();

    const hours = source === 'game' ? Number(game.hours) || 0 : now.getHours();
    const minutes = source === 'game' ? Number(game.minutes) || 0 : now.getMinutes();
    return formatClock(hours, minutes, h24);
}

export function formatClock(hours, minutes, h24 = false) {
    const mm = String(minutes).padStart(2, '0');
    if (h24) return `${String(hours).padStart(2, '0')}:${mm}`;
    const suffix = hours >= 12 ? 'PM' : 'AM';
    const h = hours % 12 === 0 ? 12 : hours % 12;
    return `${h}:${mm} ${suffix}`;
}
