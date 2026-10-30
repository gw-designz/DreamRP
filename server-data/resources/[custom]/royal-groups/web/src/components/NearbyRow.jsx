import React from 'react';
import useStore from '../state/store';
import { HugeiconsIcon } from '@hugeicons/react';
import { Add01Icon } from '@hugeicons/core-free-icons';

const distanceLabel = (m) => (m == null ? null : m < 1 ? 'here' : m < 1000 ? `${Math.round(m)}m` : `${(m / 1000).toFixed(1)}km`);

const NearbyRow = ({ player }) => {
    const { invitePlayer, busy } = useStore();

    return (
        <div className="gg-row flex items-center justify-between gap-[12px] px-[16px] py-[11px]">
            <span className="min-w-0 truncate text-[14px] font-bold text-white">{player.name}</span>
            <div className="flex shrink-0 items-center gap-[14px]">

                <button
                    disabled={!!busy}
                    title="Invite to group"
                    onClick={() => invitePlayer(player)}
                    className="gg-icon-btn disabled:opacity-25"
                >
                    <HugeiconsIcon icon={Add01Icon} className="h-[18px] w-[18px]" />
                </button>
            </div>
        </div>
    );
};

export default NearbyRow;