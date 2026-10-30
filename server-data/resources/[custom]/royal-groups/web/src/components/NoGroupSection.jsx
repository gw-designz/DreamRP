import React from 'react';
import useStore from '../state/store';
import { HugeiconsIcon } from '@hugeicons/react';
import { UserGroupIcon } from '@hugeicons/core-free-icons';

const NoGroupSection = () => {
    const { createGroup, busy } = useStore();

    return (
        <div className="gg-card flex flex-col gap-[12px] p-[16px]">
            <span className="gg-heading text-[12px] tracking-[0.14em] text-white/45">Your Group</span>
            <p className="text-[13px] text-white/40">
                You are not in a group. Create one and invite the players around you.
            </p>
            <button
                disabled={!!busy}
                onClick={() => createGroup()}
                className="gg-btn-primary gg-heading flex items-center justify-center gap-[8px] py-[10px] text-[12px] text-white disabled:opacity-40"
            >
                <HugeiconsIcon icon={UserGroupIcon} className="h-[16px] w-[16px] text-main" />
                Create Group
            </button>
        </div>
    );
};

export default NoGroupSection;