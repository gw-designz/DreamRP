import React, { useState } from 'react';
import { motion } from 'framer-motion';
import useStore from '../state/store';
import { HugeiconsIcon } from '@hugeicons/react';
import GroupSection from './GroupSection';
import NoGroupSection from './NoGroupSection';
import NearbySection from './NearbySection';
import {
    UserGroupIcon, 
    IdentityCardIcon, 
    Tick02Icon,
} from '@hugeicons/core-free-icons';

const Groups = () => {
    const { group, me, isLeader, setNickname, hide } = useStore();
    const [editing, setEditing] = useState(false);
    const [draft, setDraft] = useState('');

    const openNickname = () => {
        const self = group?.members.find((m) => m.id === me?.id);
        setDraft(self?.nickname ?? '');
        setEditing((e) => !e);
    };

    const submitNickname = () => {
        setNickname(draft.trim());
        setEditing(false);
    };

    return (
        <motion.div
            initial={{ opacity: 0, x: 32, y: '-50%' }}
            animate={{ opacity: 1, x: 0, y: '-50%' }}
            exit={{ opacity: 0, x: 32, y: '-50%' }}
            transition={{ duration: 0.24, ease: 'easeOut' }}
            onContextMenu={(e) => { e.preventDefault(); hide(); }}
            style={{ transformPerspective: 3800 }}
            className="gg-panel fixed right-[42px] top-1/2 flex w-[470px] flex-col gap-[14px] p-[18px] font-display"
        >
            <div className="flex items-center justify-between gap-[12px]">
                <div className="flex items-center gap-[10px]">
                    <HugeiconsIcon icon={UserGroupIcon} className="h-[24px] w-[24px] text-main" />
                    <h1 className="gg-heading text-[18px] leading-none text-white">Group Menu</h1>
                </div>

                <button
                    onClick={openNickname}
                    className={`gg-pill gg-heading flex items-center gap-[7px] px-[14px] py-[7px] text-[11px] text-white/85 disabled:opacity-30 ${editing ? 'active' : ''}`}
                >
                    <HugeiconsIcon icon={IdentityCardIcon} className="h-[15px] w-[15px]" />
                    Nickname
                </button>
            </div>

            {editing && (
                <div className="gg-field flex items-center gap-[10px] px-[14px] py-[9px]">
                    <input
                        autoFocus
                        value={draft}
                        maxLength={20}
                        onChange={(e) => setDraft(e.target.value)}
                        onKeyDown={(e) => e.key === 'Enter' && submitNickname()}
                        placeholder="Nickname shown to your group"
                        className="w-full bg-transparent text-[14px] font-semibold text-white placeholder:text-white/30 focus:outline-none"
                    />
                    <button onClick={submitNickname} className="gg-icon-btn shrink-0 hover:!text-main">
                        <HugeiconsIcon icon={Tick02Icon} className="h-[18px] w-[18px]" />
                    </button>
                </div>
            )}

            {group ? <GroupSection /> : <NoGroupSection />}

            {isLeader() && <NearbySection />}
        </motion.div>
    );
};

export default Groups;
